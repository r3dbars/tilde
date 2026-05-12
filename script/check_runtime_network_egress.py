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
import time
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_PROCESS_NAME = "SteadyType"
DEFAULT_PROOF_DIR = ROOT_DIR / "docs" / "diagnostics" / "runs"
MODEL_SETUP_PHASES = {"model-setup", "model-download", "model-update"}


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
            "command": command,
            "executable": executable,
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
            else "Remote endpoints are classified as model setup/update traffic, not autocomplete-time egress."
        ),
        "remote_endpoint_count": len(remote_endpoints(endpoints)),
        "unexpected_remote_endpoint_count": len(unexpected),
        "allowed_model_endpoint_count": len(allowed_model),
        "unexpected_remote_endpoints": [endpoint.safe_remote for endpoint in unexpected],
        "allowed_model_endpoints": sorted({endpoint.safe_remote for endpoint in allowed_model}),
        "activity_note": args.activity_note,
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
            if process["executable"]:
                lines.append(f"- Executable: `{process['executable']}`")
            if process["executable_sha256"]:
                lines.append(f"- Executable SHA-256: `{process['executable_sha256']}`")
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


def main() -> int:
    args = parse_args()

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
    allowed_model = remotes if args.phase in MODEL_SETUP_PHASES else []
    unexpected = [] if args.phase in MODEL_SETUP_PHASES else remotes
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
        summary["proof_path"] = str(out_path)

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
        print("Unexpected autocomplete-time egress:", file=sys.stderr)
        for endpoint in unexpected:
            print(f"- {endpoint.safe_remote}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
