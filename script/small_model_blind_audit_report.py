#!/usr/bin/env python3
"""Build the small-model blind-audit decision table (quality + first-token latency).

For each (model, template) run, this drives the batch blind quality audit
(`local_quality_audit.py --batch`) and the first-token latency benchmark
(`first_token_latency.py`) over an external prompt set, then applies the
pre-registered promotion rule and prints a Markdown decision table.

Baseline note: the production default is Gemma 4 E4B (model_type `gemma4`), which
the installed `mlx_lm` cannot load, so it cannot be scored in this harness. The
in-harness reference is therefore `qwen3.5-4b` (same runtime, apples-to-apples),
with `gemma-3n-E4B-it` as a best-effort Gemma-family cross-check. Because the
rule's quality bar is defined against Gemma 4 E4B, a candidate that clears the
proxy bars is at most draft-lane eligible; the default does not change here.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_PROMPTS_PATH = ROOT_DIR / "docs/evals/small-model-blind-prompts-2026-06-12.jsonl"
DEFAULT_MODEL_ROOT = Path.home() / "Library/Application Support/SteadyType/Models"
OPT_IN_ENV = "AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT"

# The promotion rule is anchored to this reference because Gemma 4 E4B is not
# loadable by mlx_lm. Its best (native) template row is the decision anchor.
REFERENCE_ALIAS = "qwen35-4b"
REFERENCE_TEMPLATE = "chat_instruct"
QUALITY_MARGIN = 5  # candidate must be within this many points of the reference
LATENCY_FRACTION = 0.5  # candidate first-token p50 must be <= this * reference p50


@dataclass(frozen=True)
class Run:
    alias: str
    template: str
    relative_path: str
    role: str  # "reference" | "baseline" | "candidate"


# Two baselines + three small candidates, each small candidate under both
# templates so the chat-vs-raw effect is visible across models.
RUNS = [
    Run(REFERENCE_ALIAS, REFERENCE_TEMPLATE, "Qwen35FourB/MLX/Qwen3.5-4B-4bit", "reference"),
    Run("gemma-3n-e4b-it", "chat_instruct", "Gemma3nE4B/MLX/gemma-3n-E4B-it-lm-4bit", "baseline"),
    Run("qwen3-1.7b", "raw_completion", "Qwen3Medium/MLX/qwen3-1.7b-4bit", "candidate"),
    Run("qwen3-1.7b", "chat_instruct", "Qwen3Medium/MLX/qwen3-1.7b-4bit", "candidate"),
    Run("qwen3-0.6b", "raw_completion", "Qwen3Small/MLX/qwen3-0.6b-4bit", "candidate"),
    Run("qwen3-0.6b", "chat_instruct", "Qwen3Small/MLX/qwen3-0.6b-4bit", "candidate"),
    Run("gemma-3-1b-it", "raw_completion", "Gemma31B/MLX/gemma-3-1b-it-4bit", "candidate"),
    Run("gemma-3-1b-it", "chat_instruct", "Gemma31B/MLX/gemma-3-1b-it-4bit", "candidate"),
]


@dataclass
class Result:
    run: Run
    overall: Optional[int] = None
    relevance: Optional[int] = None
    p50: Optional[float] = None
    p95: Optional[float] = None
    peak_bytes: Optional[int] = None
    disk: str = "missing"
    note: str = ""


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
    return human_bytes(total)


def human_bytes(value: Optional[float]) -> str:
    if value is None:
        return "unknown"
    value = float(value)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if value < 1024 or unit == "GiB":
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{int(value)} GiB"


def candidate_python_with_module(module_name: str) -> Optional[str]:
    candidates = [
        str(Path.home() / "mlx-env" / "bin" / "python"),
        str(ROOT_DIR / ".venv" / "bin" / "python3"),
        "/opt/homebrew/bin/python3.14",
        "/opt/homebrew/bin/python3",
        sys.executable,
        shutil.which("python3") or "",
    ]
    seen = set()
    for candidate in candidates:
        if not candidate or candidate in seen or not os.access(candidate, os.X_OK):
            continue
        seen.add(candidate)
        completed = subprocess.run(
            [candidate, "-c", f"import {module_name}"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15, check=False,
        )
        if completed.returncode == 0:
            return candidate
    return None


def runtime_available() -> bool:
    return shutil.which("mlx_lm.generate") is not None or candidate_python_with_module("mlx_lm") is not None


def mlx_python() -> str:
    return candidate_python_with_module("mlx_lm") or sys.executable


def parse_score(output: str, label: str) -> Optional[int]:
    match = re.search(rf"^{re.escape(label)}:\s*(\d+)/100", output, flags=re.MULTILINE)
    return int(match.group(1)) if match else None


def _audit_env(model_root: Path) -> dict:
    env = os.environ.copy()
    env.setdefault(OPT_IN_ENV, "1")
    env.setdefault("AUTOCOMPLETE_LAB_RUNTIME_BACKEND", "mlx")
    # Point the persistent runtime at the installed assets so it loads the local
    # model directory instead of re-downloading by Hugging Face repo id.
    env.setdefault("AUTOCOMPLETE_LAB_MODEL_ROOT", str(model_root))
    return env


def run_quality(py: str, run: Run, prompts: Path, timeout: float, model_root: Path) -> tuple[Optional[int], Optional[int], str]:
    overall_timeout = 900.0 + timeout * 64
    try:
        completed = subprocess.run(
            [
                py, str(ROOT_DIR / "script" / "local_quality_audit.py"),
                "--input", str(prompts), "--generate", "--batch",
                "--model", run.alias, "--template", run.template, "--timeout", str(timeout),
            ],
            cwd=ROOT_DIR, env=_audit_env(model_root), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=overall_timeout, check=False,
        )
    except subprocess.TimeoutExpired:
        return None, None, f"quality timed out after {int(overall_timeout)}s"
    if completed.returncode != 0:
        reason = (completed.stderr or completed.stdout).strip().splitlines()[-1:]
        return None, None, reason[0] if reason else f"exit {completed.returncode}"
    return parse_score(completed.stdout, "Overall score"), parse_score(completed.stdout, "Relevance score"), "measured"


def run_latency(py: str, run: Run, prompts: Path, model_root: Path, reps: int) -> Optional[dict]:
    try:
        completed = subprocess.run(
            [
                py, str(ROOT_DIR / "script" / "first_token_latency.py"),
                "--model", run.alias, "--template", run.template,
                "--input", str(prompts), "--reps", str(reps),
            ],
            cwd=ROOT_DIR, env=_audit_env(model_root), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=1800, check=False,
        )
    except subprocess.TimeoutExpired:
        return None
    if completed.returncode != 0:
        return None
    for line in reversed(completed.stdout.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def decide(result: Result, reference: Optional[Result]) -> str:
    run = result.run
    if run.role == "reference":
        return "reference (in-harness proxy for Gemma 4 E4B)"
    if run.role == "baseline":
        return "baseline (Gemma-family cross-check)"
    if reference is None or None in (result.overall, result.p50, reference.overall, reference.p50):
        return "incomplete"
    quality_ok = result.overall >= reference.overall - QUALITY_MARGIN
    latency_ok = result.p50 <= LATENCY_FRACTION * reference.p50
    if quality_ok and latency_ok:
        return "meets proxy bars -> draft lane*"
    if latency_ok:
        return "latency win, quality miss -> draft/speculative"
    if quality_ok:
        return "quality ok, latency miss -> no"
    return "misses both -> no"


def quality_cell(result: Result) -> str:
    if result.overall is None:
        return result.note or "incomplete"
    return f"{result.overall}/100 / {result.relevance}/100"


def latency_cell(value: Optional[float]) -> str:
    return "—" if value is None else f"{value:.0f} ms"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the small-model blind-audit decision table.")
    parser.add_argument("--prompts", type=Path, default=DEFAULT_PROMPTS_PATH)
    parser.add_argument("--model-root", type=Path, default=DEFAULT_MODEL_ROOT)
    parser.add_argument("--run", action="store_true", help="Attempt generated quality + latency runs.")
    parser.add_argument("--timeout", type=float, default=45)
    parser.add_argument("--reps", type=int, default=3)
    parser.add_argument("--json-out", type=Path, default=None, help="Optional path to dump raw results as JSON.")
    args = parser.parse_args()

    can_run = runtime_available()
    py = mlx_python()
    prompts_label = (
        args.prompts.relative_to(ROOT_DIR) if args.prompts.is_relative_to(ROOT_DIR) else args.prompts
    )

    results: list[Result] = []
    for index, run in enumerate(RUNS, 1):
        path = args.model_root / run.relative_path
        result = Result(run=run, disk=directory_size(path))
        installed = path.exists()
        if not installed:
            result.note = "model asset missing"
        elif args.run and can_run:
            print(f"[{index}/{len(RUNS)}] {run.alias} / {run.template}: quality...", file=sys.stderr, flush=True)
            result.overall, result.relevance, result.note = run_quality(py, run, args.prompts, args.timeout, args.model_root)
            print(f"[{index}/{len(RUNS)}] {run.alias} / {run.template}: latency...", file=sys.stderr, flush=True)
            latency = run_latency(py, run, args.prompts, args.model_root, args.reps)
            if latency:
                result.p50 = latency.get("first_token_ms_p50")
                result.p95 = latency.get("first_token_ms_p95")
                result.peak_bytes = latency.get("peak_memory_bytes")
        elif args.run:
            result.note = "mlx_lm unavailable"
        results.append(result)

    reference = next(
        (r for r in results if r.run.alias == REFERENCE_ALIAS and r.run.template == REFERENCE_TEMPLATE),
        None,
    )

    print("# Small Model Blind Audit Decision Table")
    print()
    print(f"Prompt set: `{prompts_label}`")
    print(f"Runtime available: {'yes' if can_run else 'no'}")
    if not can_run:
        print("Run status: scaffolded only; `mlx_lm` is not installed in any candidate python.")
    elif not args.run:
        print("Run status: scaffolded only; pass `--run` to generate fresh quality + latency scores.")
    else:
        print(f"Run status: generated runs via `{py}`.")
    if reference and reference.overall is not None and reference.p50 is not None:
        print(
            f"Reference (`{REFERENCE_ALIAS}`/`{REFERENCE_TEMPLATE}`): overall {reference.overall}/100, "
            f"first-token p50 {reference.p50:.0f} ms. Quality bar >= {reference.overall - QUALITY_MARGIN}, "
            f"latency bar <= {LATENCY_FRACTION * reference.p50:.0f} ms."
        )
    print()
    print("| Model | Template | Quality (overall / relevance) | First-token p50 | p95 | Disk | Peak RAM | Decision |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for result in results:
        print(
            f"| `{result.run.alias}` | `{result.run.template}` | {quality_cell(result)} | "
            f"{latency_cell(result.p50)} | {latency_cell(result.p95)} | {result.disk} | "
            f"{human_bytes(result.peak_bytes)} | {decide(result, reference)} |"
        )

    print()
    print(
        f"Promotion gate (pre-registered): default only if blind-audit overall >= (Gemma 4 E4B - {QUALITY_MARGIN}) "
        f"and first-token p50 <= {int(LATENCY_FRACTION * 100)}% of Gemma's."
    )
    print(
        "* Gemma 4 E4B (model_type `gemma4`) cannot be loaded by mlx_lm, so the bar is evaluated against the "
        f"`{REFERENCE_ALIAS}` in-harness proxy. A candidate that clears the proxy bars is draft-lane eligible; "
        "the production default is not changed without a true Gemma 4 E4B measurement (Swift-runtime lane)."
    )

    if args.json_out:
        payload = [
            {
                "alias": r.run.alias, "template": r.run.template, "role": r.run.role,
                "overall": r.overall, "relevance": r.relevance,
                "first_token_ms_p50": r.p50, "first_token_ms_p95": r.p95,
                "peak_memory_bytes": r.peak_bytes, "disk": r.disk, "note": r.note,
                "decision": decide(r, reference),
            }
            for r in results
        ]
        args.json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"\nRaw results written to `{args.json_out}`.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nRun interrupted before all model rows completed.", file=sys.stderr)
        raise SystemExit(130)
