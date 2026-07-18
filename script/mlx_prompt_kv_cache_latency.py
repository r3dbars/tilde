#!/usr/bin/env python3
"""Measure cold MLX prefill against an incremental prompt-KV-cache append.

The live product keeps a copyable prompt cache for a growing typing session. This
benchmark exercises the same MLX generate_step prompt_cache mechanism with safe,
synthetic continuation pairs, then reports aggregate timing only.

Privacy: prompts and generated tokens remain in memory. Stdout contains only
model/source, token counts, latency percentiles, memory, and hit counts. No raw
prompt or model output is written.
"""
from __future__ import annotations

import argparse
import importlib
import importlib.util
import json
import time
from pathlib import Path
from typing import Optional

ROOT_DIR = Path(__file__).resolve().parents[1]
_BATCH_PATH = ROOT_DIR / "script/local_completion_batch.py"
_SPEC = importlib.util.spec_from_file_location("local_completion_batch", _BATCH_PATH)
assert _SPEC and _SPEC.loader is not None
batch = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(batch)


def percentile(values: list[float], fraction: float) -> Optional[float]:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def common_prefix_count(left: list[int], right: list[int]) -> int:
    count = 0
    for left_token, right_token in zip(left, right):
        if left_token != right_token:
            break
        count += 1
    return count


def _round(value: Optional[float]) -> Optional[float]:
    return None if value is None else round(value, 1)


def _peak_memory_bytes(mx) -> Optional[int]:
    try:
        return int(mx.get_peak_memory())
    except Exception:  # noqa: BLE001 - optional measurement
        return None


def _chat_prompt(tokenizer, user_text: str) -> str:
    messages = [
        {
            "role": "system",
            "content": "Inline autocomplete. Return only a short continuation.",
        },
        {"role": "user", "content": user_text},
    ]
    try:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
            enable_thinking=False,
        )
    except TypeError:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )


def _prompt_pairs(tokenizer, count: int) -> list[tuple[list[int], list[int]]]:
    pairs = []
    for index in range(count):
        base = _chat_prompt(tokenizer, f"The next measured step {index} is")
        grown = _chat_prompt(tokenizer, f"The next measured step {index} is to")
        base_tokens = tokenizer.encode(base, add_special_tokens=False)
        grown_tokens = tokenizer.encode(grown, add_special_tokens=False)
        pairs.append((base_tokens, grown_tokens))
    return pairs


def _first_token_ms(generate_step, mx, model, tokens: list[int], prompt_cache, sampler) -> float:
    started = time.monotonic()
    generator = generate_step(
        mx.array(tokens),
        model,
        max_tokens=1,
        sampler=sampler,
        prompt_cache=prompt_cache,
    )
    try:
        next(generator)
    finally:
        generator.close()
    return (time.monotonic() - started) * 1000.0


def _copy_cache_item(mx, item):
    """Copy MLX cache state across KVCache and hybrid ArraysCache variants."""
    def copy_state(value):
        if value is None:
            return None
        if isinstance(value, tuple):
            return tuple(copy_state(item) for item in value)
        if isinstance(value, list):
            return [copy_state(item) for item in value]
        return mx.array(value)

    return type(item).from_state(copy_state(item.state), item.meta_state)


def measure(model_alias: str, pairs: int, reps: int, warmup: int) -> dict:
    mlx_lm = importlib.import_module("mlx_lm")
    generate_module = importlib.import_module("mlx_lm.generate")
    from mlx_lm.models import cache as cache_module
    import mlx.core as mx

    source, source_kind = batch.resolve_model_source(model_alias)
    load_started = time.monotonic()
    model, tokenizer = mlx_lm.load(source)
    load_ms = round((time.monotonic() - load_started) * 1000)
    prompt_pairs = _prompt_pairs(tokenizer, pairs)
    sampler = batch.make_sampler()

    cold_samples: list[float] = []
    warm_samples: list[float] = []
    base_token_counts: list[int] = []
    grown_token_counts: list[int] = []
    append_token_counts: list[int] = []
    cache_hit_pairs = 0

    for base_tokens, grown_tokens in prompt_pairs:
        prefix_count = common_prefix_count(base_tokens, grown_tokens)
        append_tokens = grown_tokens[prefix_count:]
        if prefix_count == 0 or not append_tokens:
            continue

        base_token_counts.append(len(base_tokens))
        grown_token_counts.append(len(grown_tokens))
        append_token_counts.append(len(append_tokens))
        cache_hit_pairs += 1

        for attempt in range(warmup + reps):
            if attempt >= warmup:
                cold_samples.append(
                    _first_token_ms(
                        generate_module.generate_step,
                        mx,
                        model,
                        grown_tokens,
                        cache_module.make_prompt_cache(model),
                        sampler,
                    )
                )

            base_cache = cache_module.make_prompt_cache(model)
            _first_token_ms(
                generate_module.generate_step,
                mx,
                model,
                base_tokens,
                base_cache,
                sampler,
            )
            warm_cache = [_copy_cache_item(mx, item) for item in base_cache]
            if attempt >= warmup:
                warm_samples.append(
                    _first_token_ms(
                        generate_module.generate_step,
                        mx,
                        model,
                        append_tokens,
                        warm_cache,
                        sampler,
                    )
                )
            mx.clear_cache()

    cold_p50 = percentile(cold_samples, 0.50)
    warm_p50 = percentile(warm_samples, 0.50)
    return {
        "model": model_alias,
        "source_kind": source_kind,
        "pairs": len(prompt_pairs),
        "cache_hit_pairs": cache_hit_pairs,
        "cache_hit_rate": _round((cache_hit_pairs / len(prompt_pairs)) * 100) if prompt_pairs else 0.0,
        "reps": reps,
        "warmup": warmup,
        "load_ms": load_ms,
        "base_prompt_tokens_p50": _round(percentile([float(value) for value in base_token_counts], 0.50)),
        "grown_prompt_tokens_p50": _round(percentile([float(value) for value in grown_token_counts], 0.50)),
        "append_tokens_p50": _round(percentile([float(value) for value in append_token_counts], 0.50)),
        "cold_first_token_ms_p50": _round(cold_p50),
        "cold_first_token_ms_p95": _round(percentile(cold_samples, 0.95)),
        "warm_append_first_token_ms_p50": _round(warm_p50),
        "warm_append_first_token_ms_p95": _round(percentile(warm_samples, 0.95)),
        "warm_speedup_ratio_p50": _round(cold_p50 / warm_p50) if cold_p50 and warm_p50 else None,
        "peak_memory_bytes": _peak_memory_bytes(mx),
    }


def self_test() -> int:
    assert common_prefix_count([1, 2, 3], [1, 2, 4]) == 2
    assert common_prefix_count([1], [2]) == 0
    assert percentile([10.0, 20.0], 0.5) == 15.0
    assert percentile([], 0.5) is None
    print("mlx_prompt_kv_cache_latency self-test: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="qwen3.5-4b")
    parser.add_argument("--pairs", type=int, default=3)
    parser.add_argument("--reps", type=int, default=2)
    parser.add_argument("--warmup", type=int, default=1)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    result = measure(
        model_alias=args.model,
        pairs=max(1, args.pairs),
        reps=max(1, args.reps),
        warmup=max(0, args.warmup),
    )
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
