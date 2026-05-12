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
DEFAULT_MODEL_NAME = "Qwen3.5 4B"
DEFAULT_MLX_MODEL = "mlx-community/Qwen3.5-4B-MLX-4bit"
MLX_MODEL_BY_NAME = {
    "gemma 4 e2b": "mlx-community/gemma-4-E2B-it-4bit",
    "gemma 4 e4b": "mlx-community/gemma-4-e4b-4bit",
    "qwen3 0.6b": "mlx-community/Qwen3-0.6B-4bit",
    "qwen3 1.7b": "mlx-community/Qwen3-1.7B-4bit",
    "qwen3.5 4b": "mlx-community/Qwen3.5-4B-MLX-4bit",
    "qwen3.5 9b": "mlx-community/Qwen3.5-9B-MLX-4bit",
}


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


def candidate_python_with_module(env_key: str, module_name: str) -> Optional[str]:
    explicit = os.environ.get(env_key)
    candidates = []
    if explicit:
        candidates.append(explicit)

    candidates.extend([
        str(repo_root() / ".venv" / "bin" / "python3"),
        "/opt/homebrew/bin/python3",
        "/opt/homebrew/bin/python3.14",
        sys.executable,
        shutil.which("python3") or "",
        "/usr/bin/python3",
    ])

    seen = set()
    for candidate in candidates:
        if not candidate or candidate in seen or not os.access(candidate, os.X_OK):
            continue
        seen.add(candidate)
        completed = subprocess.run(
            [candidate, "-c", f"import {module_name}"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
            check=False,
        )
        if completed.returncode == 0:
            return candidate

    return None


def mlx_model_name(requested_model: str) -> str:
    explicit = os.environ.get("AUTOCOMPLETE_LAB_MLX_MODEL")
    if explicit:
        return explicit

    key = requested_model.strip().lower()
    return MLX_MODEL_BY_NAME.get(key, DEFAULT_MLX_MODEL)


def prompt_text(payload: dict[str, str]) -> str:
    user = payload.get("user", "").strip()
    if bool(payload.get("promptIsBuilt") or payload.get("prompt_is_built")):
        return user

    mode = payload.get("mode", "").strip().lower()
    suffix = "Suffix:" if mode in {"word", "word_completion", "wordCompletion"} else "Next words:"
    return f"Before cursor:\n{user}\n\n{suffix}"


def system_prompt_text(payload: dict[str, str]) -> str:
    system = payload.get("system", "").strip()
    if bool(payload.get("promptIsBuilt") or payload.get("prompt_is_built")):
        return system

    mode = payload.get("mode", "").strip().lower()
    if mode in {"word", "word_completion", "wordCompletion"}:
        rules = [
            "Return only the missing suffix for the current word.",
            "No spaces, punctuation, explanation, labels, quotes, reasoning, or mention of the user.",
            "If the suffix is not obvious, return <NO_SUGGESTION>.",
        ]
    else:
        rules = [
            "Act as inline autocomplete, not as a chat assistant.",
            "Return exactly one short continuation after the Before cursor text.",
            "Prefer 3 to 5 useful words, or fewer when fewer words are enough.",
            "No explanation, labels, quotes, reasoning, or mention of the user.",
            "Never repeat the Before cursor text.",
            "Never suggest pressing Enter or Return, sending, submitting, clicking, running, or approving.",
            "When the text discusses Tab or acceptance behavior, continue the safety rule itself; never suggest accepting terms.",
            "Return <NO_SUGGESTION> for passwords, secrets, private fields, search fields, terminal punctuation, weak guesses, new topics, full-sentence answers, or list markers.",
        ]
    return "\n".join([system, *rules]).strip()


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
        lower = stripped.lower()
        if set(stripped) == {"="}:
            continue
        if stripped.startswith("Downloading ") and " from " in stripped:
            continue
        if lower.startswith((
            "calling `python -m mlx_lm.generate",
            "fetching ",
            "generation:",
            "peak memory:",
            "prompt:",
            "tokens per second:",
            "warning:",
        )):
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


def run_mlx(prompt: str, system_prompt: str, max_tokens: int, timeout: float, requested_model: str) -> str:
    executable = candidate_executable("AUTOCOMPLETE_LAB_MLX_BIN", ["mlx_lm.generate"])
    model = mlx_model_name(requested_model)

    if executable:
        command = [
            executable,
            "--model",
            model,
            "--prompt",
            prompt,
            "--system-prompt",
            system_prompt,
            "--max-tokens",
            str(max_tokens),
            "--temp",
            "0.0",
            "--verbose",
            "False",
        ]
    else:
        python = candidate_python_with_module("AUTOCOMPLETE_LAB_PYTHON", "mlx_lm")
        if not python:
            raise RuntimeError("mlx_lm is not installed in an available python")

        command = [
            python,
            "-m",
            "mlx_lm.generate",
            "--model",
            model,
            "--prompt",
            prompt,
            "--system-prompt",
            system_prompt,
            "--max-tokens",
            str(max_tokens),
            "--temp",
            "0.0",
            "--verbose",
            "False",
        ]

    return run_command(command, timeout=timeout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default=DEFAULT_MODEL_NAME)
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
    system_prompt = system_prompt_text(payload)
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
                print(run_mlx(prompt, system_prompt, args.max_tokens, timeout, args.model))
                return 0
            errors.append(f"{candidate}: unsupported backend")
        except Exception as error:
            errors.append(f"{candidate}: {error}")

    print("; ".join(errors), file=sys.stderr)
    return 70


if __name__ == "__main__":
    raise SystemExit(main())
