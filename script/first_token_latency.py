#!/usr/bin/env python3
"""Measure first-token latency for a local MLX model on a disposable prompt set.

The batch runtime (`local_completion_batch.py`) reports *total* generation
latency, but the live product cares about **time to first token** (tokenize +
prefill + first decode step): that is the moment an inline suggestion can begin
to paint. This tool loads a model exactly once and, for each prompt row, measures
time-to-first-token via `mlx_lm.stream_generate` (1 warmup + N timed reps, taking
the per-prompt median), then reports p50/p95/p99 across the prompt set, plus peak
unified memory and model load time.

Prompts are built with the *same* code paths as the quality audit
(`local_quality_audit.row_payload` + `local_completion_batch.build_prompt`), so a
latency row is byte-identical to the quality row for the same model/template.

Privacy: like the rest of the audit harness, raw prompts and raw model output
stay in memory only. The single line written to stdout is an aggregate JSON
object (model id, percentiles, memory, counts) — never raw text.
"""
from __future__ import annotations

import argparse
import importlib
import importlib.util
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

ROOT_DIR = Path(__file__).resolve().parents[1]
OPT_IN_ENV = "AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT"
DEFAULT_PROMPTS = ROOT_DIR / "docs/evals/small-model-blind-prompts-2026-06-12.jsonl"


def _load_sibling(name: str):
    """Import a sibling script module by file path (mlx-free at import time)."""
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader is not None
    spec.loader.exec_module(module)
    return module


audit = _load_sibling("local_quality_audit")
batch = _load_sibling("local_completion_batch")


def percentile(values: list[float], fraction: float) -> Optional[float]:
    """Linear-interpolated percentile (numpy "linear" / type-7).

    Avoids round-half-to-even on the index, which would return the *faster*
    sample for an even-length set at fraction 0.5 (understating p50).
    """
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def _peak_memory_bytes(mx) -> Optional[int]:
    for owner in (mx, getattr(mx, "metal", None)):
        if owner is None:
            continue
        getter = getattr(owner, "get_peak_memory", None)
        if getter is None:
            continue
        try:
            return int(getter())
        except Exception:  # noqa: BLE001
            continue
    return None


def measure(
    model_alias: str,
    template: Optional[str],
    prompts_path: Path,
    reps: int,
    warmup: int,
    max_tokens: int,
) -> dict:
    rows = audit.read_rows(prompts_path)
    source, kind = batch.resolve_model_source(model_alias)

    mlx_lm = importlib.import_module("mlx_lm")
    import mlx.core as mx  # noqa: PLC0415 - lazy so --self-test needs no mlx
    from mlx_lm import stream_generate  # noqa: PLC0415

    load_started = time.monotonic()
    model, tokenizer = mlx_lm.load(source)
    load_ms = round((time.monotonic() - load_started) * 1000)
    sampler = batch.make_sampler()

    # Build prompts through the exact audit + batch shaping so the latency prompt
    # equals the quality prompt for this model/template.
    payloads = [audit.row_payload(row, model_alias, template) for row in rows]
    prompts = [batch.build_prompt(payload, tokenizer) for payload in payloads]
    prompt_char_counts = [len(prompt) for prompt in prompts]
    prompt_token_counts = [
        len(tokenizer.encode(prompt, add_special_tokens=False))
        for prompt in prompts
    ]

    def first_token_ms(prompt: str) -> float:
        started = time.monotonic()
        for _response in stream_generate(
            model, tokenizer, prompt=prompt, max_tokens=max_tokens, sampler=sampler
        ):
            return (time.monotonic() - started) * 1000.0
        # No token produced (degenerate); count the full wait.
        return (time.monotonic() - started) * 1000.0

    per_prompt_ms: list[float] = []
    for prompt in prompts:
        rep_ms: list[float] = []
        for attempt in range(warmup + reps):
            elapsed = first_token_ms(prompt)
            if attempt >= warmup:
                rep_ms.append(elapsed)
        if rep_ms:
            per_prompt_ms.append(percentile(rep_ms, 0.5))

    effective_template = template or audit.prompt_template_for_model(model_alias)
    return {
        "model": model_alias,
        "template": effective_template,
        "source_kind": kind,
        "prompts": len(per_prompt_ms),
        "reps": reps,
        "warmup": warmup,
        "max_tokens": max_tokens,
        "load_ms": load_ms,
        "prompt_chars_p50": _round(percentile([float(value) for value in prompt_char_counts], 0.50)),
        "prompt_chars_p95": _round(percentile([float(value) for value in prompt_char_counts], 0.95)),
        "prompt_tokens_p50": _round(percentile([float(value) for value in prompt_token_counts], 0.50)),
        "prompt_tokens_p95": _round(percentile([float(value) for value in prompt_token_counts], 0.95)),
        "first_token_ms_p50": _round(percentile(per_prompt_ms, 0.50)),
        "first_token_ms_p95": _round(percentile(per_prompt_ms, 0.95)),
        "first_token_ms_p99": _round(percentile(per_prompt_ms, 0.99)),
        "peak_memory_bytes": _peak_memory_bytes(mx),
    }


def _round(value: Optional[float]) -> Optional[float]:
    return None if value is None else round(value, 1)


def self_test() -> int:
    assert hasattr(batch, "make_sampler")

    # Percentile math.
    sample = [10.0, 20.0, 30.0, 40.0, 50.0]
    assert percentile(sample, 0.0) == 10.0
    assert percentile(sample, 0.5) == 30.0
    assert percentile(sample, 1.0) == 50.0
    assert percentile([], 0.5) is None
    # Even-length set: a true median interpolates (the round-half-to-even bug
    # would have returned the faster 10.0 here).
    assert percentile([10.0, 20.0], 0.5) == 15.0
    assert percentile([10.0, 20.0, 30.0, 40.0], 0.5) == 25.0

    # Prompts are byte-identical to the quality audit, and the template override
    # flows into the payload. raw_completion is buildable without a tokenizer.
    row = audit.AuditRow(
        row_id="probe",
        system="Inline autocomplete. Return only the continuation.",
        user="The trail map says the overlook is",
        mode="phrase",
        expected_terms=("half", "mile"),
        max_words=6,
        line_structure="plain",
    )
    raw_payload = audit.row_payload(row, "qwen3-1.7b", "raw_completion")
    assert raw_payload["template"] == "raw_completion"
    assert audit.RAW_COMPLETION_INSTRUCTION in raw_payload["rawPrompt"]
    raw_prompt = batch.build_prompt(raw_payload, tokenizer=None)
    assert raw_prompt == raw_payload["rawPrompt"]
    assert row.user in raw_prompt and "<" not in raw_prompt

    chat_payload = audit.row_payload(row, "qwen3-1.7b", "chat_instruct")
    assert chat_payload["template"] == "chat_instruct"
    assert "rawPrompt" not in chat_payload

    # Terminator truncation keeps a model from being scored on leaked control tokens.
    assert batch.truncate_at_terminator("hello there<end_of_turn> junk") == "hello there"

    print("first_token_latency self-test: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", help="Model alias, e.g. qwen3-1.7b")
    parser.add_argument(
        "--template",
        choices=["chat_instruct", "raw_completion"],
        default=None,
        help="Force a prompt template, overriding the per-model default.",
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_PROMPTS, help="JSONL disposable prompt set")
    parser.add_argument("--reps", type=int, default=3, help="Timed reps per prompt (median kept).")
    parser.add_argument("--warmup", type=int, default=1, help="Warmup reps per prompt (discarded).")
    parser.add_argument("--max-tokens", type=int, default=2, help="Generation cap; only the first token is timed.")
    parser.add_argument("--self-test", action="store_true", help="Run pure-logic self-test without loading a model.")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if os.environ.get(OPT_IN_ENV) != "1":
        print(f"first-token latency requires {OPT_IN_ENV}=1", file=sys.stderr)
        return 64
    if not args.model:
        print("--model is required unless --self-test is used", file=sys.stderr)
        return 64

    result = measure(
        model_alias=args.model,
        template=args.template,
        prompts_path=args.input,
        reps=args.reps,
        warmup=args.warmup,
        max_tokens=args.max_tokens,
    )
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
