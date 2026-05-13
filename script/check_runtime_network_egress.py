#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import ipaddress
import json
import os
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_PROCESS_NAME = "SteadyType"
DEFAULT_PROOF_DIR = ROOT_DIR / "docs" / "diagnostics" / "runs"
MODEL_SETUP_PHASES = {"model-setup", "model-download", "model-update"}
ALLOWED_MODEL_REMOTE_SUFFIXES = (
    "huggingface.co",
    ".huggingface.co",
    "hf.co",
    ".hf.co",
)


@dataclass(frozen=True)
class Endpoint:
    protocol: str
    local: str
    remote: str
    state: str
    sample_index: int

    @property
    def remote_host(self) -> str:
        return split_host_port(self.remote)[0]

    @property
    def safe_remote(self) -> str:
        host, port = split_host_port(self.remote)
        if not host:
            return "<none>"
        if port:
            return f"{host}:{port}"
        return host


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Observe SteadyType network sockets and prove local-only "
            "autocomplete has no unexpected runtime egress."
        )
    )
    parser.add_argument(
        "--pid",
        action="append",
        type=int,
        default=[],
        help="Process ID to observe. Can be passed more than once.",
    )
    parser.add_argument(
        "--process-name",
        default=DEFAULT_PROCESS_NAME,
        help="Process name used when --pid is omitted.",
    )
    parser.add_argument(
        "--phase",
        choices=["autocomplete", "model-setup", "model-download", "model-update"],
        default="autocomplete",
        help=(
            "autocomplete fails on any non-loopback remote endpoint. "
            "model-* phases record remote egress as allowed setup/update traffic."
        ),
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=20,
        help="Seconds to observe a live process.",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1,
        help="Seconds between live lsof samples.",
    )
    parser.add_argument(
        "--sample",
        type=Path,
        action="append",
        default=[],
        help="Read one or more saved lsof samples instead of observing a live process.",
    )
    parser.add_argument(
        "--proof-out",
        type=Path,
        help="Markdown proof path. Defaults to docs/diagnostics/runs when observing live.",
    )
    parser.add_argument(
        "--json-out",
        type=Path,
        help="Optional machine-readable proof path.",
    )
    parser.add_argument(
        "--no-proof",
        action="store_true",
        help="Do not write a Markdown proof artifact.",
    )
    parser.add_argument(
        "--activity-note",
        default="",
        help="Short privacy-safe note about what was happening during the observation.",
    )
    parser.add_argument(
        "--validate-proof",
        type=Path,
        help="Validate an existing JSON or Markdown no-egress proof instead of observing a process.",
    )
    parser.add_argument(
        "--max-proof-age-seconds",
        type=float,
        default=0,
        help="When validating, fail if generated_at is older than this many seconds. 0 disables age checks.",
    )
    parser.add_argument(
        "--now",
        default="",
        help="UTC timestamp used for validation tests. Defaults to the current time.",
    )
    parser.add_argument(
        "--diagnostics-log",
        type=Path,
        help="Diagnostics log used to reject no-egress proof captured before the latest app launch.",
    )
    parser.add_argument(
        "--require-newer-than-latest-launch",
        action="store_true",
        help="When validating, require generated_at to be newer than the latest diagnostics launch line.",
    )
    parser.add_argument(
        "--min-samples",
        type=int,
        default=1,
        help="When validating, require at least this many socket samples.",
    )
    parser.add_argument(
        "--expected-executable-sha256",
        default="",
        help="When validating, require the proof to contain this executable SHA-256.",
    )
    parser.add_argument(
        "--app-binary",
        type=Path,
        help="When validating, hash this app binary and require the proof to match it.",
    )
    return parser.parse_args()


def split_host_port(endpoint: str) -> tuple[str, str]:
    value = endpoint.strip()
    value = re.sub(r"\s+\([^)]*\)$", "", value)
    if not value or value == "*":
        return "", ""

    if value.startswith("["):
        match = re.match(r"^\[([^\]]+)\](?::([^:]+))?$", value)
        if match:
            return match.group(1), match.group(2) or ""

    if value.count(":") == 1:
        host, port = value.rsplit(":", 1)
        return host.strip("[]"), port

    return value.strip("[]"), ""


def is_loopback_or_wildcard(host: str) -> bool:
    normalized = host.strip().strip("[]").lower()
    if normalized in {"", "*", "localhost", "ip6-localhost"}:
        return True
    try:
        ip = ipaddress.ip_address(normalized)
    except ValueError:
        return False
    return ip.is_loopback or ip.is_unspecified


def parse_lsof_samples(sample_texts: list[str]) -> list[Endpoint]:
    endpoints: list[Endpoint] = []
    for sample_index, text in enumerate(sample_texts, start=1):
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("COMMAND "):
                continue

            protocol_match = re.search(r"\b(TCP|UDP)\b\s+(.+)$", stripped)
            if not protocol_match:
                continue

            protocol = protocol_match.group(1)
            name = protocol_match.group(2).strip()
            state_match = re.search(r"\(([^)]*)\)\s*$", name)
            state = state_match.group(1) if state_match else ""
            endpoint_text = re.sub(r"\s+\([^)]*\)$", "", name).strip()

            if "->" not in endpoint_text:
                continue

            local, remote = endpoint_text.split("->", 1)
            endpoints.append(
                Endpoint(
                    protocol=protocol,
                    local=local.strip(),
                    remote=remote.strip(),
                    state=state,
                    sample_index=sample_index,
                )
            )
    return endpoints


def remote_endpoints(endpoints: list[Endpoint]) -> list[Endpoint]:
    return [
        endpoint
        for endpoint in endpoints
        if not is_loopback_or_wildcard(endpoint.remote_host)
    ]


def is_allowed_model_remote(endpoint: Endpoint) -> bool:
    host = endpoint.remote_host.lower().strip(".")
    return any(
        host == suffix.lstrip(".") or host.endswith(suffix)
        for suffix in ALLOWED_MODEL_REMOTE_SUFFIXES
    )


def find_pids(process_name: str) -> list[int]:
    candidates: set[int] = set()
    commands = [
        ["pgrep", "-x", process_name],
        ["pgrep", "-f", f"/{process_name}.app/Contents/MacOS/{process_name}"],
    ]
    for command in commands:
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        if result.returncode not in {0, 1}:
            continue
        for line in result.stdout.splitlines():
            try:
                candidates.add(int(line.strip()))
            except ValueError:
                continue
    return sorted(candidates)


def capture_lsof(pid: int) -> str:
    result = subprocess.run(
        ["lsof", "-nP", "-a", "-p", str(pid), "-i"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode not in {0, 1}:
        raise RuntimeError(result.stderr.strip() or f"lsof failed for pid {pid}")
    return result.stdout


def process_exists(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_iso_datetime(value: object) -> dt.datetime:
    raw = str(value or "").strip().strip("`")
    if not raw:
        raise ValueError("missing timestamp")
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    parsed = dt.datetime.fromisoformat(raw)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def string_summary(value: str) -> str:
    return f"String({len(value)} chars)"


def process_details(pids: list[int]) -> list[dict[str, object]]:
    details: list[dict[str, object]] = []
    for pid in pids:
        result = subprocess.run(
            ["ps", "-p", str(pid), "-o", "command="],
            text=True,
            capture_output=True,
            check=False,
        )
        command = result.stdout.strip() if result.returncode == 0 else ""
        executable = ""
        executable_sha256 = ""
        if command:
            try:
                executable = shlex.split(command)[0]
            except ValueError:
                executable = command.split(" ", 1)[0]
            executable_path = Path(executable)
            if executable_path.is_file():
                executable_sha256 = sha256_file(executable_path)
        details.append({
            "pid": pid,
            "command_redacted": bool(command),
            "command_summary": string_summary(command) if command else "",
            "executable_name": Path(executable).name if executable else "",
            "executable_sha256": executable_sha256,
        })
    return details


def observe_live(pids: list[int], duration: float, interval: float) -> list[str]:
    if not pids:
        raise RuntimeError("no SteadyType process found; launch the app or pass --pid")

    samples: list[str] = []
    deadline = time.monotonic() + max(0.1, duration)
    while True:
        sample_parts = []
        for pid in pids:
            if not process_exists(pid):
                raise RuntimeError(f"observed process exited before proof completed: pid {pid}")
            sample_parts.append(capture_lsof(pid))
        samples.append("\n".join(sample_parts))
        if time.monotonic() >= deadline:
            break
        time.sleep(max(0.1, interval))
    return samples


def proof_path(args: argparse.Namespace) -> Path | None:
    if args.no_proof:
        return None
    if args.proof_out:
        return args.proof_out
    if args.sample:
        return None
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return DEFAULT_PROOF_DIR / f"runtime-network-egress-{timestamp}.md"


def build_summary(
    *,
    args: argparse.Namespace,
    pids: list[int],
    endpoints: list[Endpoint],
    unexpected: list[Endpoint],
    allowed_model: list[Endpoint],
    sample_count: int,
    passed: bool,
) -> dict[str, object]:
    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "phase": args.phase,
        "result": "pass" if passed else "fail",
        "process_name": args.process_name,
        "pids": pids,
        "processes": process_details(pids),
        "samples": sample_count,
        "network_assertion": (
            "No non-loopback remote endpoints during autocomplete."
            if args.phase == "autocomplete"
            else "Only allowlisted model setup/update endpoints are permitted."
        ),
        "remote_endpoint_count": len(remote_endpoints(endpoints)),
        "unexpected_remote_endpoint_count": len(unexpected),
        "allowed_model_endpoint_count": len(allowed_model),
        "unexpected_remote_endpoints": [endpoint.safe_remote for endpoint in unexpected],
        "allowed_model_endpoints": sorted({endpoint.safe_remote for endpoint in allowed_model}),
        "activity_note": string_summary(args.activity_note) if args.activity_note else "",
        "activity_note_chars": len(args.activity_note),
        "privacy_note": "No typed text, prompts, model output, screenshots, URLs, document names, or trace lines are captured.",
    }


def write_markdown(path: Path, summary: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Runtime Network Egress Proof",
        "",
        f"- Generated at: `{summary['generated_at']}`",
        f"- Phase: `{summary['phase']}`",
        f"- Result: `{summary['result']}`",
        f"- Process: `{summary['process_name']}`",
        f"- PIDs: `{', '.join(map(str, summary['pids'])) if summary['pids'] else 'sample-file'}`",
        f"- Samples: `{summary['samples']}`",
        f"- Assertion: {summary['network_assertion']}",
        f"- Remote endpoints observed: `{summary['remote_endpoint_count']}`",
        f"- Unexpected remote endpoints: `{summary['unexpected_remote_endpoint_count']}`",
        f"- Allowed model setup/update endpoints: `{summary['allowed_model_endpoint_count']}`",
    ]
    if summary["activity_note"]:
        lines.append(f"- Activity note: {summary['activity_note']}")
    processes = summary["processes"]
    if processes:
        for process in processes:
            if process["executable_name"]:
                lines.append(f"- Executable name: `{process['executable_name']}`")
            if process["executable_sha256"]:
                lines.append(f"- Executable SHA-256: `{process['executable_sha256']}`")
            if process["command_summary"]:
                lines.append(f"- Command line: `{process['command_summary']}`")
    lines.extend([
        "",
        "Privacy note: this proof stores only process/socket metadata. It does not store typed text, prompts, model output, screenshots, document names, URLs, or trace lines.",
    ])

    unexpected = summary["unexpected_remote_endpoints"]
    if unexpected:
        lines.extend(["", "Unexpected remote endpoints:", ""])
        lines.extend(f"- `{endpoint}`" for endpoint in unexpected)

    allowed_model = summary["allowed_model_endpoints"]
    if allowed_model:
        lines.extend(["", "Allowed model setup/update endpoints:", ""])
        lines.extend(f"- `{endpoint}`" for endpoint in allowed_model)

    path.write_text("\n".join(lines) + "\n")


def parse_markdown_proof(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8", errors="ignore")

    def field(label: str) -> str:
        pattern = rf"^- {re.escape(label)}:\s*`?([^`\n]+)`?"
        match = re.search(pattern, text, re.MULTILINE)
        return match.group(1).strip() if match else ""

    executable_hashes = re.findall(r"^- Executable SHA-256:\s*`?([0-9a-fA-F]+)`?", text, re.MULTILINE)
    unexpected = field("Unexpected remote endpoints")
    allowed_model = field("Allowed model setup/update endpoints")
    samples = field("Samples")
    return {
        "generated_at": field("Generated at"),
        "phase": field("Phase"),
        "result": field("Result"),
        "process_name": field("Process"),
        "samples": int(samples) if samples.isdigit() else 0,
        "unexpected_remote_endpoint_count": int(unexpected) if unexpected.isdigit() else 0,
        "allowed_model_endpoint_count": int(allowed_model) if allowed_model.isdigit() else 0,
        "processes": [{"executable_sha256": item.lower()} for item in executable_hashes],
    }


def load_proof_summary(path: Path) -> dict[str, object]:
    if not path.is_file():
        raise FileNotFoundError(f"missing no-egress proof: {path}")
    if path.suffix.lower() == ".json":
        return json.loads(path.read_text(encoding="utf-8"))
    return parse_markdown_proof(path)


def latest_launch_timestamp(path: Path) -> dt.datetime:
    if not path.is_file():
        raise FileNotFoundError(f"missing diagnostics log: {path}")

    latest = ""
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "launch accessibility=" in line:
            latest = line.split(maxsplit=1)[0]
    if not latest:
        raise ValueError(f"no launch accessibility= line found in diagnostics log: {path}")
    return parse_iso_datetime(latest)


def proof_executable_hashes(summary: dict[str, object]) -> set[str]:
    hashes: set[str] = set()
    raw_processes = summary.get("processes", [])
    if isinstance(raw_processes, list):
        for process in raw_processes:
            if isinstance(process, dict):
                value = str(process.get("executable_sha256", "")).strip().lower()
                if value:
                    hashes.add(value)
    direct = str(summary.get("executable_sha256", "")).strip().lower()
    if direct:
        hashes.add(direct)
    return hashes


def validate_proof(args: argparse.Namespace) -> int:
    failures: list[str] = []
    path = args.validate_proof
    assert path is not None

    try:
        summary = load_proof_summary(path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("Runtime network egress proof validation: FAIL", file=sys.stderr)
        print(f"- {error}", file=sys.stderr)
        return 1

    phase = str(summary.get("phase", "")).lower()
    result = str(summary.get("result", "")).lower()
    try:
        unexpected = int(summary.get("unexpected_remote_endpoint_count", 0))
    except (TypeError, ValueError):
        unexpected = -1
    try:
        samples = int(summary.get("samples", 0))
    except (TypeError, ValueError):
        samples = 0

    if phase != "autocomplete":
        failures.append(f"phase={phase or 'missing'} does not prove autocomplete no-egress")
    if result != "pass":
        failures.append(f"result={result or 'missing'} is not pass")
    if unexpected != 0:
        failures.append(f"unexpectedRemoteEndpoints={unexpected}")
    if samples < args.min_samples:
        failures.append(f"samples={samples} is below required minimum {args.min_samples}")

    generated_at: dt.datetime | None = None
    try:
        generated_at = parse_iso_datetime(summary.get("generated_at", ""))
    except ValueError as error:
        failures.append(f"generated_at is invalid: {error}")

    now = dt.datetime.now(dt.timezone.utc)
    if args.now:
        try:
            now = parse_iso_datetime(args.now)
        except ValueError as error:
            failures.append(f"--now is invalid: {error}")

    if generated_at is not None and args.max_proof_age_seconds > 0:
        age_seconds = (now - generated_at).total_seconds()
        if age_seconds < -300:
            failures.append(f"generated_at is in the future by {int(abs(age_seconds))}s")
        elif age_seconds > args.max_proof_age_seconds:
            failures.append(
                f"no-egress proof is stale: ageSeconds={int(age_seconds)} "
                f"maxAgeSeconds={int(args.max_proof_age_seconds)}"
            )

    if args.require_newer_than_latest_launch:
        if not args.diagnostics_log:
            failures.append("--require-newer-than-latest-launch needs --diagnostics-log")
        elif generated_at is not None:
            try:
                latest_launch = latest_launch_timestamp(args.diagnostics_log)
                if generated_at < latest_launch:
                    failures.append(
                        "no-egress proof is older than latest runtime launch "
                        f"(proofGeneratedAt={generated_at.isoformat(timespec='seconds')}; "
                        f"latestLaunch={latest_launch.isoformat(timespec='seconds')})"
                    )
            except (OSError, ValueError) as error:
                failures.append(str(error))

    expected_hash = args.expected_executable_sha256.strip().lower()
    if args.app_binary:
        if args.app_binary.is_file():
            expected_hash = sha256_file(args.app_binary)
        else:
            failures.append(f"missing app binary for executable hash check: {args.app_binary}")
    if expected_hash:
        proof_hashes = proof_executable_hashes(summary)
        if expected_hash not in proof_hashes:
            failures.append("proof executable SHA-256 does not match the expected app binary")

    if failures:
        print("Runtime network egress proof validation: FAIL", file=sys.stderr)
        print(f"Proof: {path}", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Runtime network egress proof validation: PASS")
    print(f"Proof: {path}")
    print(f"Generated at: {summary.get('generated_at', '')}")
    print(f"Samples: {samples}")
    print("Autocomplete no-egress proof is fresh enough for the current gate.")
    return 0


def main() -> int:
    args = parse_args()

    if args.validate_proof:
        return validate_proof(args)

    try:
        if args.sample:
            sample_texts = [path.read_text() for path in args.sample]
            pids = args.pid
        else:
            pids = args.pid or find_pids(args.process_name)
            sample_texts = observe_live(pids, args.duration, args.interval)
    except OSError as error:
        print(f"runtime network egress proof failed: {error}", file=sys.stderr)
        return 2
    except RuntimeError as error:
        print(f"runtime network egress proof failed: {error}", file=sys.stderr)
        return 2

    endpoints = parse_lsof_samples(sample_texts)
    remotes = remote_endpoints(endpoints)
    if args.phase in MODEL_SETUP_PHASES:
        allowed_model = [endpoint for endpoint in remotes if is_allowed_model_remote(endpoint)]
        unexpected = [endpoint for endpoint in remotes if not is_allowed_model_remote(endpoint)]
    else:
        allowed_model = []
        unexpected = remotes
    passed = not unexpected

    summary = build_summary(
        args=args,
        pids=pids,
        endpoints=endpoints,
        unexpected=unexpected,
        allowed_model=allowed_model,
        sample_count=len(sample_texts),
        passed=passed,
    )

    out_path = proof_path(args)
    if out_path is not None:
        write_markdown(out_path, summary)
        summary["proof_artifact"] = out_path.name

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    print(f"Runtime network egress proof: {'PASS' if passed else 'FAIL'}")
    print(f"Phase: {args.phase}")
    print(f"Samples: {len(sample_texts)}")
    print(f"Remote endpoints observed: {summary['remote_endpoint_count']}")
    print(f"Unexpected remote endpoints: {summary['unexpected_remote_endpoint_count']}")
    print(f"Allowed model setup/update endpoints: {summary['allowed_model_endpoint_count']}")
    if out_path is not None:
        print(f"Proof artifact: {out_path}")

    if unexpected:
        if args.phase in MODEL_SETUP_PHASES:
            print("Unexpected model setup/update egress:", file=sys.stderr)
        else:
            print("Unexpected autocomplete-time egress:", file=sys.stderr)
        for endpoint in unexpected:
            print(f"- {endpoint.safe_remote}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
