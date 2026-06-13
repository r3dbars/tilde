#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_PROMPTS_PATH = ROOT_DIR / "docs/evals/small-model-blind-prompts-2026-06-12.jsonl"
DEFAULT_MODEL_ROOT = Path.home() / "Library/Application Support/SteadyType/Models"
OPT_IN_ENV = "AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT"


@dataclass(frozen=True)
class Candidate:
    alias: str
    model: str
    template: str
    relative_path: str


CANDIDATES = [
    Candidate("qwen3-1.7b-base", "qwen3-1.7b-base", "raw_completion", "Qwen3Medium/MLX/qwen3-1.7b-4bit"),
    Candidate("qwen3-0.6b", "qwen3-0.6b", "raw_completion", "Qwen3Small/MLX/qwen3-0.6b-4bit"),
    Candidate("qwen35-4b", "qwen35-4b", "chat_instruct", "Qwen35FourB/MLX/Qwen3.5-4B-4bit"),
]


def directory_size(path: Path) -> str:
    if not path.exists():
        return "missing"
    total = 0
    for child in path.rglob("*"):
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                pass
    value = float(total)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if value < 1024 or unit == "GiB":
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{total} B"


def runtime_available() -> bool:
    if shutil.which("mlx_lm.generate"):
        return True
    if importlib.util.find_spec("mlx_lm") is not None:
        return True
    if candidate_python_with_module("mlx_lm") is not None:
        return True
    return False


def candidate_python_with_module(module_name: str) -> str | None:
    candidates = [
        str(ROOT_DIR / ".venv" / "bin" / "python3"),
        "/opt/homebrew/bin/python3",
        "/opt/homebrew/bin/python3.14",
        sys.executable,
        shutil.which("python3") or "",
        "/usr/bin/python3",
    ]
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


def parse_metric(output: str, label: str) -> str:
    match = re.search(rf"^{re.escape(label)}:\s*(\d+/100)", output, flags=re.MULTILINE)
    return match.group(1) if match else "unknown"


def run_quality(candidate: Candidate, prompts_path: Path, timeout: float) -> tuple[str, str, str]:
    env = os.environ.copy()
    env.setdefault(OPT_IN_ENV, "1")
    env.setdefault("AUTOCOMPLETE_LAB_RUNTIME_BACKEND", "mlx")
    completed = subprocess.run(
        [
            str(ROOT_DIR / "script" / "local_quality_audit.py"),
            "--input",
            str(prompts_path),
            "--generate",
            "--model",
            candidate.model,
            "--timeout",
            str(timeout),
        ],
        cwd=ROOT_DIR,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        reason = (completed.stderr or completed.stdout).strip().splitlines()[-1:]
        return "unknown", "unknown", reason[0] if reason else f"exit {completed.returncode}"
    return (
        parse_metric(completed.stdout, "Overall score"),
        parse_metric(completed.stdout, "Relevance score"),
        "measured",
    )


def decision_for(alias: str, quality: str, latency: str) -> str:
    if quality == "unknown" or latency == "unknown":
        return "no decision"
    if alias == "qwen35-4b":
        return "baseline"
    return "no decision"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the small-model blind audit decision table.")
    parser.add_argument("--prompts", type=Path, default=DEFAULT_PROMPTS_PATH)
    parser.add_argument("--model-root", type=Path, default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--run", action="store_true", help="Attempt generated local quality runs.")
    parser.add_argument("--timeout", type=float, default=45)
    args = parser.parse_args()

    can_run = runtime_available()
    print("# Small Model Blind Audit Decision Table")
    print()
    print(f"Prompt set: `{args.prompts.relative_to(ROOT_DIR) if args.prompts.is_relative_to(ROOT_DIR) else args.prompts}`")
    print(f"Runtime available: {'yes' if can_run else 'no'}")
    if not can_run:
        print("Run status: scaffolded only; `mlx_lm` is not installed in this shell.")
    elif not args.run:
        print("Run status: scaffolded only; pass `--run` to generate fresh local quality scores.")
    else:
        print("Run status: generated local quality attempted.")
    print()
    print("| Model | Template | Quality | Latency | Memory | Decision | Notes |")
    print("| --- | --- | --- | --- | --- | --- | --- |")

    for candidate in CANDIDATES:
        path = args.model_root / candidate.relative_path
        memory = directory_size(path)
        installed = path.exists()
        quality = "unknown"
        relevance = "unknown"
        note = "installed" if installed else "model asset missing"
        if args.run and can_run and installed:
            quality, relevance, note = run_quality(candidate, args.prompts, args.timeout)
        elif args.run and not can_run:
            note = "`mlx_lm` unavailable"
        decision = decision_for(candidate.alias, quality, "unknown")
        print(
            f"| `{candidate.alias}` | `{candidate.template}` | overall {quality}, relevance {relevance} | "
            f"unknown | {memory} | {decision} | {note} |"
        )

    print()
    print("Promotion gate: default only if blind-audit overall >= 4B score - 5 and first-token p50 <= 50% of 4B.")
    print("Draft/speculative gate: if quality misses but latency wins big, keep it out of default and test only as draft/speculative.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nRun interrupted before all model rows completed.", file=sys.stderr)
        raise SystemExit(130)
