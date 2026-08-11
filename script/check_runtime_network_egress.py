#!/usr/bin/env python3
"""Fail-closed runtime socket observation for a disposable Tilde completion.

This observes open sockets with lsof. It is deliberately not described as a
packet capture: a clean result means no non-loopback socket was visible during
the observation window, not that packet-level absence was proven.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import ipaddress
import json
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_APP_BINARY = ROOT_DIR / "dist/Tilde.app/Contents/MacOS/Tilde"
DEFAULT_PROOF = ROOT_DIR / "dist/release-proof/runtime-socket-observation.json"
LOCAL_HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))
SYNTHETIC_CONTEXT = "The architecture of the system means that we "
PROSE_SCAFFOLD = """The following are real documents being written by their authors, continued naturally.

Text: I wanted to follow up on our call from
Continuation: yesterday afternoon about the launch timeline.

Text: honestly the new setup is working better
Continuation: than I expected, we should keep it.

Text: The results suggest two things. First, the approach
Continuation: scales well beyond the original design load.


"""


@dataclass(frozen=True)
class ProcessRow:
    pid: int
    ppid: int
    command: str

    @property
    def executable(self) -> str:
        # macOS `ps args` does not quote executable paths, and the installed
        # input method lives under "Input Methods". Slice at the known binary
        # name so spaces in the path do not corrupt process identity.
        for name in ("InlineGhostIME", "llama-server", "Tilde"):
            marker = f"/{name}"
            marker_index = self.command.rfind(marker)
            if marker_index < 0:
                continue
            end = marker_index + len(marker)
            if end == len(self.command) or self.command[end].isspace():
                return self.command[:end]
        return self.command.split(maxsplit=1)[0] if self.command else ""

    @property
    def arguments(self) -> list[str]:
        executable = self.executable
        if not executable or not self.command.startswith(executable):
            return []
        # `ps args` is already flattened on macOS. The options validated here
        # have no whitespace-bearing values, so token splitting is intentional.
        return self.command[len(executable) :].split()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duration", type=float, default=20.0)
    parser.add_argument("--interval", type=float, default=0.25)
    parser.add_argument("--min-samples", type=int, default=2)
    parser.add_argument("--port", type=int, default=17872)
    parser.add_argument("--app-binary", type=Path, default=DEFAULT_APP_BINARY)
    parser.add_argument("--proof-out", type=Path, default=DEFAULT_PROOF)
    parser.add_argument(
        "--synthetic-helper-proof",
        action="store_true",
        help="require release-proof mode and omit all input-method observation",
    )
    parser.add_argument("--selftest", action="store_true")
    return parser.parse_args()


def process_table() -> dict[int, ProcessRow]:
    result = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,args="],
        text=True,
        capture_output=True,
        check=True,
    )
    rows: dict[int, ProcessRow] = {}
    for raw in result.stdout.splitlines():
        fields = raw.strip().split(maxsplit=2)
        if len(fields) != 3 or not fields[0].isdigit() or not fields[1].isdigit():
            continue
        row = ProcessRow(int(fields[0]), int(fields[1]), fields[2])
        rows[row.pid] = row
    return rows


def same_file(left: str, right: Path) -> bool:
    try:
        return Path(left).resolve() == right.resolve()
    except OSError:
        return False


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def option_values(row: ProcessRow, option: str) -> list[str]:
    values: list[str] = []
    for index, token in enumerate(row.arguments):
        if token == option:
            values.append(row.arguments[index + 1] if index + 1 < len(row.arguments) else "")
        elif token.startswith(option + "="):
            values.append(token[len(option) + 1 :])
    return values


def listener_endpoints(output: str) -> dict[int, set[str]]:
    listeners: dict[int, set[str]] = {}
    current_pid: int | None = None
    for field in output.splitlines():
        if field.startswith("p") and field[1:].isdigit():
            current_pid = int(field[1:])
            listeners.setdefault(current_pid, set())
        elif field.startswith("n") and current_pid is not None:
            listeners[current_pid].add(field[1:])
    return listeners


def owns_exact_loopback_listener(returncode: int, output: str, pid: int, port: int) -> bool:
    return returncode == 0 and listener_endpoints(output) == {
        pid: {f"127.0.0.1:{port}"}
    }


def require_owned_model(app_binary: Path, port: int) -> tuple[ProcessRow, ProcessRow]:
    rows = process_table()
    app_matches = [row for row in rows.values() if same_file(row.executable, app_binary)]
    if len(app_matches) != 1:
        raise RuntimeError(
            f"expected exactly one running Tilde from {app_binary}; found {len(app_matches)}"
        )
    app = app_matches[0]

    servers = [
        row
        for row in rows.values()
        if Path(row.executable).name == "llama-server" and row.ppid == app.pid
    ]
    if len(servers) != 1:
        raise RuntimeError(
            f"expected exactly one direct llama-server child of Tilde pid {app.pid}; found {len(servers)}"
        )
    server = servers[0]
    expected_server = app_binary.parent.parent / "Helpers/llama-server"
    if not same_file(server.executable, expected_server):
        raise RuntimeError(
            f"llama-server child is not the packaged helper at {expected_server}"
        )
    if option_values(server, "--port") != [str(port)]:
        raise RuntimeError(f"llama-server child is not configured for port {port}")
    if option_values(server, "--host") != ["127.0.0.1"]:
        raise RuntimeError("llama-server child is not configured for loopback only")
    listener = subprocess.run(
        [
            "lsof", "-nP", "-a", "-p", str(server.pid),
            f"-iTCP:{port}", "-sTCP:LISTEN", "-Fpn",
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if not owns_exact_loopback_listener(
        listener.returncode, listener.stdout, server.pid, port
    ):
        raise RuntimeError("packaged llama-server does not own the exact IPv4 loopback listener")
    return app, server


def require_processes(args: argparse.Namespace) -> tuple[ProcessRow, ProcessRow, list[ProcessRow]]:
    app, server = require_owned_model(args.app_binary, args.port)
    if args.synthetic_helper_proof:
        if app.arguments != ["--release-proof"]:
            raise RuntimeError("synthetic helper proof requires the app's exact --release-proof mode")
        return app, server, []
    rows = process_table()

    imes = [row for row in rows.values() if Path(row.executable).name == "InlineGhostIME"]
    if not imes:
        raise RuntimeError("InlineGhostIME is not running; select the input source and retry")
    packaged_ime = (
        args.app_binary.parent.parent
        / "Library/InlineGhostIME.app/Contents/MacOS/InlineGhostIME"
    )
    if not packaged_ime.is_file():
        raise RuntimeError(f"packaged InlineGhostIME is missing: {packaged_ime}")
    packaged_ime_sha = sha256(packaged_ime)
    mismatches = [
        row.executable
        for row in imes
        if not Path(row.executable).is_file() or sha256(Path(row.executable)) != packaged_ime_sha
    ]
    if mismatches:
        raise RuntimeError("running InlineGhostIME does not match the packaged input method")
    return app, server, imes


def remote_host(endpoint: str) -> str:
    value = endpoint.strip().split(" ", 1)[0]
    if value.startswith("[") and "]" in value:
        return value[1 : value.index("]")]
    if value.count(":") == 1:
        return value.rsplit(":", 1)[0]
    return value


def is_non_loopback(endpoint: str) -> bool:
    host = remote_host(endpoint).strip("[]").lower()
    if host in {"", "*", "localhost"}:
        return False
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return True
    return not (address.is_loopback or address.is_unspecified)


def lsof_remote_endpoints(pid: int) -> set[str]:
    result = subprocess.run(
        ["lsof", "-nP", "-a", "-p", str(pid), "-i"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode not in {0, 1}:
        raise RuntimeError(result.stderr.strip() or f"lsof failed for pid {pid}")
    remotes: set[str] = set()
    for line in result.stdout.splitlines():
        if "->" not in line:
            continue
        endpoint = line.split("->", 1)[1].split(" ", 1)[0]
        if is_non_loopback(endpoint):
            remotes.add(endpoint)
    return remotes


def health_check(port: int) -> None:
    with LOCAL_HTTP.open(f"http://127.0.0.1:{port}/health", timeout=5) as response:
        payload = json.loads(response.read())
    if payload.get("status") != "ok":
        raise RuntimeError(f"llama-server health was not ok: {payload!r}")


def model_request(context: str) -> dict[str, object]:
    return {
        "prompt": PROSE_SCAFFOLD + "Text: " + context.rstrip() + "\nContinuation:",
        "n_predict": 20,
        "temperature": 0,
        "cache_prompt": True,
        "stop": ["\n"],
        "stream": False,
    }


def disposable_completion(port: int) -> int:
    body = json.dumps(model_request(SYNTHETIC_CONTEXT), separators=(",", ":")).encode()
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/completion",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with LOCAL_HTTP.open(request, timeout=60) as response:
        if response.status != 200:
            raise RuntimeError(f"llama-server completion returned HTTP {response.status}")
        payload = json.loads(response.read())
    completion = payload.get("content")
    if not isinstance(completion, str) or not completion.strip():
        raise RuntimeError("direct synthetic model completion was empty or malformed")
    return len(completion)


def selftest() -> None:
    request = model_request(SYNTHETIC_CONTEXT)
    assert request["stream"] is False
    assert request["temperature"] == 0
    assert request["stop"] == ["\n"]
    assert request["n_predict"] == 20
    assert request["prompt"].endswith(
        "Text: The architecture of the system means that we\nContinuation:"
    )
    assert not is_non_loopback("127.0.0.1:17872")
    assert not is_non_loopback("[::1]:17872")
    assert is_non_loopback("203.0.113.1:443")
    server = ProcessRow(
        4242,
        4000,
        "/tmp/App With Spaces/llama-server --host=127.0.0.1 --port 17872",
    )
    assert server.executable == "/tmp/App With Spaces/llama-server"
    assert option_values(server, "--host") == ["127.0.0.1"]
    assert option_values(server, "--port") == ["17872"]
    assert option_values(
        ProcessRow(1, 0, "/tmp/llama-server --port 17872 --port 9999"),
        "--port",
    ) != ["17872"]
    assert option_values(
        ProcessRow(1, 0, "/tmp/llama-server --host 127.0.0.1 --host 0.0.0.0"),
        "--host",
    ) != ["127.0.0.1"]
    assert option_values(
        ProcessRow(1, 0, "/tmp/llama-server --port 178720"),
        "--port",
    ) != ["17872"]
    assert option_values(
        ProcessRow(1, 0, "/tmp/llama-server --note=--port=17872"),
        "--port",
    ) == []
    exact_listener = "p4242\nn127.0.0.1:17872\n"
    assert owns_exact_loopback_listener(0, exact_listener, 4242, 17872)
    assert not owns_exact_loopback_listener(0, "p4242\nn*:17872\n", 4242, 17872)
    assert not owns_exact_loopback_listener(0, "p4242\nn0.0.0.0:17872\n", 4242, 17872)
    assert not owns_exact_loopback_listener(0, "p4242\nn[::1]:17872\n", 4242, 17872)
    assert not owns_exact_loopback_listener(1, exact_listener, 4242, 17872)
    proof_app = ProcessRow(8, 1, "/tmp/Tilde.app/Contents/MacOS/Tilde --release-proof")
    assert proof_app.arguments == ["--release-proof"]
    print("selftest OK: fixed request, strict argv, and exact loopback listener")


def observe(
    pids: list[int], minimum_duration: float, interval: float, activity_done: threading.Event
) -> tuple[int, set[str], list[str]]:
    sample_count = 0
    remotes: set[str] = set()
    failures: list[str] = []
    deadline = time.monotonic() + max(minimum_duration, 0.25)
    while time.monotonic() < deadline or not activity_done.is_set():
        try:
            current = process_table()
            for pid in pids:
                if pid not in current:
                    raise RuntimeError(f"observed process exited: pid {pid}")
                remotes.update(lsof_remote_endpoints(pid))
            sample_count += 1
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            failures.append(str(error))
            break
        time.sleep(max(interval, 0.05))
    return sample_count, remotes, failures


def main() -> int:
    args = parse_args()
    if args.selftest:
        selftest()
        return 0
    failures: list[str] = []
    completion_chars = 0
    health_ok = False
    samples = 0
    remotes: set[str] = set()

    if shutil.which("lsof") is None:
        failures.append("lsof is unavailable; socket observation cannot run")

    try:
        app, server, imes = require_processes(args)
    except (OSError, subprocess.SubprocessError, RuntimeError) as error:
        failures.append(str(error))
        app = ProcessRow(0, 0, "")
        server = ProcessRow(0, 0, "")
        imes = []

    if not failures:
        result: list[tuple[int, set[str], list[str]]] = []
        activity_done = threading.Event()

        def run_observation() -> None:
            result.append(
                observe(
                    [app.pid, server.pid, *(row.pid for row in imes)],
                    args.duration,
                    args.interval,
                    activity_done,
                )
            )

        observer = threading.Thread(target=run_observation, daemon=True)
        observer.start()
        try:
            health_check(args.port)
            health_ok = True
            completion_chars = disposable_completion(args.port)
        except (OSError, TimeoutError, ValueError, json.JSONDecodeError, RuntimeError) as error:
            failures.append(str(error))
        finally:
            activity_done.set()
        observer.join()
        if result:
            samples, remotes, observation_failures = result[0]
            failures.extend(observation_failures)
        else:
            failures.append("socket observation did not complete")

    if samples < args.min_samples:
        failures.append(
            f"captured {samples} socket samples; require at least {args.min_samples}"
        )
    if remotes:
        failures.append("non-loopback sockets observed: " + ", ".join(sorted(remotes)))

    proves = [
        "the exact packaged Tilde process and its exact helper child were observed",
        "the helper returned a nonempty completion for the fixed synthetic prompt",
        "no non-loopback open socket was visible for the observed processes during the window",
    ]
    does_not_prove = [
        "packet-level absence of network traffic",
        "a Tilde-to-input-method Unix-socket request round trip",
        "inline rendering or acceptance in a real editor",
    ]
    input_method_observation = "matching running input method observed"
    if args.synthetic_helper_proof:
        input_method_observation = "not performed in non-mutating release-proof mode"
        does_not_prove.insert(1, "input-method installation, execution, or authentication")
    else:
        proves[0] += " with a matching running input method"

    summary = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "result": "fail" if failures else "pass",
        "observation_kind": "open-socket metadata via lsof; not packet capture",
        "app_pid": app.pid,
        "llama_server_pid": server.pid,
        "inline_ghost_ime_pids": [row.pid for row in imes],
        "input_method_observation": input_method_observation,
        "samples": samples,
        "health_ok": health_ok,
        "direct_synthetic_model_completion_nonempty": completion_chars > 0,
        "direct_synthetic_model_completion_chars": completion_chars,
        "non_loopback_endpoints": sorted(remotes),
        "failures": failures,
        "stimulation": (
            "direct POST to the exact packaged llama-server child over loopback "
            "using a fixed synthetic prompt"
        ),
        "proves": proves,
        "does_not_prove": does_not_prove,
        "privacy": "Only process/socket metadata and synthetic completion length are saved.",
    }
    args.proof_out.parent.mkdir(parents=True, exist_ok=True)
    args.proof_out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    if failures:
        print("Runtime socket observation: FAIL (not packet capture)", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        print(f"Proof: {args.proof_out}", file=sys.stderr)
        return 1

    print("Runtime socket observation: PASS (not packet capture)")
    if args.synthetic_helper_proof:
        print(f"Observed release-proof Tilde {app.pid} and llama-server {server.pid}; input method untouched")
    else:
        print(f"Observed Tilde {app.pid}, llama-server {server.pid}, InlineGhostIME {[row.pid for row in imes]}")
    print(f"Health: ok; direct synthetic model completion: nonempty ({completion_chars} chars)")
    print(f"Socket samples: {samples}; non-loopback endpoints: 0")
    print(f"Proof: {args.proof_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
