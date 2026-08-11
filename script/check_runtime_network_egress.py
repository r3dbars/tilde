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
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_APP_BINARY = ROOT_DIR / "dist/Tilde.app/Contents/MacOS/Tilde"
DEFAULT_SOCKET = Path.home() / "Library/Application Support/Tilde/ghost.sock"
DEFAULT_PROOF = ROOT_DIR / "dist/release-proof/runtime-socket-observation.json"


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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duration", type=float, default=20.0)
    parser.add_argument("--interval", type=float, default=0.25)
    parser.add_argument("--min-samples", type=int, default=2)
    parser.add_argument("--port", type=int, default=17872)
    parser.add_argument("--socket", type=Path, default=DEFAULT_SOCKET)
    parser.add_argument("--app-binary", type=Path, default=DEFAULT_APP_BINARY)
    parser.add_argument("--proof-out", type=Path, default=DEFAULT_PROOF)
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


def require_processes(args: argparse.Namespace) -> tuple[ProcessRow, ProcessRow, list[ProcessRow]]:
    rows = process_table()
    app_matches = [row for row in rows.values() if same_file(row.executable, args.app_binary)]
    if len(app_matches) != 1:
        raise RuntimeError(
            f"expected exactly one running Tilde from {args.app_binary}; found {len(app_matches)}"
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
    expected_server = args.app_binary.parent.parent / "Helpers/llama-server"
    if not same_file(server.executable, expected_server):
        raise RuntimeError(
            f"llama-server child is not the packaged helper at {expected_server}"
        )
    if f"--port {args.port}" not in server.command and f"--port={args.port}" not in server.command:
        raise RuntimeError(f"llama-server child is not configured for port {args.port}")

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
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=5) as response:
        payload = json.loads(response.read())
    if payload.get("status") != "ok":
        raise RuntimeError(f"llama-server health was not ok: {payload!r}")


def disposable_completion(socket_path: Path) -> int:
    request = {
        "v": 1,
        "context": "The architecture of the system means that we ",
        "app": "com.apple.TextEdit",
        "field": "synthetic-release-proof",
        "page": "",
    }
    final = ""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(60)
        client.connect(str(socket_path))
        client.sendall((json.dumps(request) + "\n").encode())
        buffer = b""
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                payload = json.loads(line)
                if not payload.get("partial"):
                    final = str(payload.get("suggestion", ""))
    if not final.strip():
        raise RuntimeError("disposable completion returned no final suggestion")
    return len(final)


def observe(
    pids: list[int], duration: float, interval: float
) -> tuple[int, set[str], list[str]]:
    sample_count = 0
    remotes: set[str] = set()
    failures: list[str] = []
    deadline = time.monotonic() + max(duration, 0.25)
    while time.monotonic() < deadline:
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
    failures: list[str] = []
    completion_chars = 0
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

        def run_observation() -> None:
            result.append(
                observe([app.pid, server.pid, *(row.pid for row in imes)], args.duration, args.interval)
            )

        observer = threading.Thread(target=run_observation, daemon=True)
        observer.start()
        try:
            health_check(args.port)
            completion_chars = disposable_completion(args.socket)
        except (OSError, TimeoutError, ValueError, json.JSONDecodeError, RuntimeError) as error:
            failures.append(str(error))
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

    summary = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "result": "fail" if failures else "pass",
        "observation_kind": "open-socket metadata via lsof; not packet capture",
        "app_pid": app.pid,
        "llama_server_pid": server.pid,
        "inline_ghost_ime_pids": [row.pid for row in imes],
        "samples": samples,
        "health_ok": not failures and completion_chars > 0,
        "disposable_completion_nonempty": completion_chars > 0,
        "disposable_completion_chars": completion_chars,
        "non_loopback_endpoints": sorted(remotes),
        "failures": failures,
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
    print(f"Observed Tilde {app.pid}, llama-server {server.pid}, InlineGhostIME {[row.pid for row in imes]}")
    print(f"Health: ok; disposable completion: nonempty ({completion_chars} chars)")
    print(f"Socket samples: {samples}; non-loopback endpoints: 0")
    print(f"Proof: {args.proof_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
