#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional


DEFAULT_LITERT_REPO = "litert-community/gemma-4-E2B-it-litert-lm"
DEFAULT_LITERT_MODEL = "gemma-4-E2B-it.litertlm"
DEFAULT_MLX_MODEL = "mlx-community/gemma-4-E2B-it-4bit"


def repo_root() -> Path:
    explicit = os.environ.get("AUTOCOMPLETE_LAB_REPO_ROOT")
    if explicit:
        return Path(explicit).expanduser().resolve()

    return Path(__file__).resolve().parents[1]


def candidate_executable(env_key: str, names: list) -> Optional[str]:
    explicit = os.environ.get(env_key)
    if explicit and os.access(explicit, os.X_OK):
        return explicit

    root = repo_root()
    for name in names:
        local = root / ".venv" / "bin" / name
        if os.access(local, os.X_OK):
            return str(local)

        found = shutil.which(name)
        if found:
            return found

    return None


def prompt_text(payload: dict[str, str]) -> str:
    system = payload.get("system", "").strip()
    user = payload.get("user", "").strip()
    return f"{system}\n\nText before cursor:\n{user}\n\nReturn only the next words:"


def run_command(command: list[str], timeout: float) -> str:
    completed = subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"exit code {completed.returncode}")
    output = clean_runtime_stdout(completed.stdout)
    if not output:
        raise RuntimeError("empty output")
    return output


def clean_runtime_stdout(output: str) -> str:
    lines = []
    for line in output.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("Downloading ") and " from " in stripped:
            continue
        lines.append(stripped)

    return lines[-1] if lines else ""


def run_litert(prompt: str, max_tokens: int, timeout: float) -> str:
    executable = candidate_executable("AUTOCOMPLETE_LAB_LITERT_BIN", ["litert-lm"])
    if not executable:
        raise RuntimeError("litert-lm not installed")

    repo = os.environ.get("AUTOCOMPLETE_LAB_LITERT_REPO", DEFAULT_LITERT_REPO)
    model = os.environ.get("AUTOCOMPLETE_LAB_LITERT_MODEL", DEFAULT_LITERT_MODEL)
    return run_command(
        [
            executable,
            "run",
            f"--from-huggingface-repo={repo}",
            model,
            f"--prompt={prompt}",
        ],
        timeout=timeout,
    )


def run_mlx(prompt: str, max_tokens: int, timeout: float) -> str:
    executable = candidate_executable("AUTOCOMPLETE_LAB_MLX_BIN", ["mlx_lm.generate"])
    model = os.environ.get("AUTOCOMPLETE_LAB_MLX_MODEL", DEFAULT_MLX_MODEL)

    if executable:
        command = [
            executable,
            "--model",
            model,
            "--prompt",
            prompt,
            "--max-tokens",
            str(max_tokens),
            "--temp",
            "0.2",
        ]
    else:
        python = candidate_executable("AUTOCOMPLETE_LAB_PYTHON", ["python3"])
        if not python:
            raise RuntimeError("python3 not installed")

        command = [
            python,
            "-m",
            "mlx_lm.generate",
            "--model",
            model,
            "--prompt",
            prompt,
            "--max-tokens",
            str(max_tokens),
            "--temp",
            "0.2",
        ]

    return run_command(command, timeout=timeout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="Gemma 4 E2B")
    parser.add_argument("--max-tokens", type=int, default=16)
    parser.add_argument("--max-words", type=int, default=8)
    parser.add_argument("--reasoning", choices=["on", "off"], default="off")
    args = parser.parse_args()

    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        print(f"invalid prompt payload: {error}", file=sys.stderr)
        return 64

    prompt = prompt_text(payload)
    timeout = float(os.environ.get("AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT", "8"))
    backend = os.environ.get("AUTOCOMPLETE_LAB_RUNTIME_BACKEND", "auto").lower()

    errors = []
    backends = ["litert", "mlx"] if backend == "auto" else [backend]
    for candidate in backends:
        try:
            if candidate == "litert":
                print(run_litert(prompt, args.max_tokens, timeout))
                return 0
            if candidate == "mlx":
                print(run_mlx(prompt, args.max_tokens, timeout))
                return 0
            errors.append(f"{candidate}: unsupported backend")
        except Exception as error:
            errors.append(f"{candidate}: {error}")

    print("; ".join(errors), file=sys.stderr)
    return 70


if __name__ == "__main__":
    raise SystemExit(main())
