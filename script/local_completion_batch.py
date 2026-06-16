#!/usr/bin/env python3
"""Persistent batch runtime for local autocomplete quality/latency runs.

The per-row `local_completion_runtime.py` path spawns a fresh `mlx_lm.generate`
subprocess for every prompt, so it cold-loads the whole model 36+ times in a
single audit. That is why a blind audit could not finish even the first model in
two minutes. This script loads the model exactly once and streams every prompt
row through it, and it prefers the app's already-installed local asset directory
over a Hugging Face repo id so it never silently re-downloads multi-GB weights.

Privacy: like the rest of the audit harness, this keeps raw prompts and raw
model output in memory only. It reads disposable JSONL prompts on stdin and
writes one JSONL result per row on stdout. It never persists raw text.

Input (stdin), one JSON object per line:
    {"id": "row-1", "system": "...", "user": "...", "mode": "phrase",
     "template": "chat_instruct" | "raw_completion",
     "rawPrompt": "...", "promptIsBuilt": true, "max_tokens": 16}

Output (stdout), one JSON object per line:
    {"id": "row-1", "output": "...", "ok": true, "latency_ms": 123}
    {"id": "row-2", "ok": false, "error": "timed out after 45s"}
"""
from __future__ import annotations

import argparse
import importlib
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

# Reuse the exact prompt shaping the per-row runtime uses so batch and single
# paths produce identical prompts for the same payload.
import importlib.util

_RUNTIME_PATH = Path(__file__).with_name("local_completion_runtime.py")
_spec = importlib.util.spec_from_file_location("local_completion_runtime", _RUNTIME_PATH)
_runtime = importlib.util.module_from_spec(_spec)
assert _spec and _spec.loader is not None
_spec.loader.exec_module(_runtime)


# Local asset layout, kept in sync with download_mlx_model.py targets. Maps an
# audit/model alias to the installed directory relative to the SteadyType
# Application Support folder.
LOCAL_TARGET_BY_ALIAS = {
    "qwen35-4b": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    "qwen3.5-4b": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    "qwen35-9b": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    "qwen3.5-9b": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    "qwen3-1.7b": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    "qwen3-1.7b-base": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    "small-draft-1b": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    "qwen3-0.6b": "Models/Qwen3Small/MLX/qwen3-0.6b-4bit",
    "gemma-4-e2b": "Models/Gemma4E2B/MLX/gemma-4-e2b-mlx",
    "gemma-4-e4b": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    "gemma-4-e4b-it-optiq": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    "gemma-4-26b": "Models/Gemma4A4B/MLX/gemma-4-26b-a4b-it-4bit",
}

DEFAULT_SUPPORT_ROOT = Path.home() / "Library/Application Support/SteadyType"


def support_root() -> Path:
    explicit = os.environ.get("AUTOCOMPLETE_LAB_MODEL_ROOT")
    if explicit:
        # The audit passes the Models directory; accept either the Models dir or
        # its parent so callers do not have to care which one they hold.
        root = Path(explicit).expanduser()
        return root.parent if root.name == "Models" else root
    return DEFAULT_SUPPORT_ROOT


def installed_asset_path(alias: str) -> Optional[Path]:
    """Return the installed local asset directory for an alias, if it looks usable."""
    relative = LOCAL_TARGET_BY_ALIAS.get(alias.strip().lower())
    if not relative:
        return None
    path = support_root() / relative
    if not path.is_dir():
        return None
    has_config = (path / "config.json").is_file()
    has_weights = any(path.glob("*.safetensors"))
    if has_config and has_weights:
        return path
    return None


def resolve_model_source(alias: str) -> tuple[str, str]:
    """Resolve a model alias to a load target.

    Returns (source, kind) where kind is "local-asset" or "hf-repo". A local
    install is always preferred so the audit never triggers a fresh download.
    """
    explicit = os.environ.get("AUTOCOMPLETE_LAB_MLX_MODEL")
    if explicit:
        kind = "local-asset" if Path(explicit).expanduser().is_dir() else "hf-repo"
        return explicit, kind

    local = installed_asset_path(alias)
    if local is not None:
        return str(local), "local-asset"

    return _runtime.mlx_model_name(alias), "hf-repo"


def build_prompt(payload: dict, tokenizer) -> str:
    """Build the final string prompt for a payload, matching the per-row runtime."""
    template = _runtime.prompt_template(payload)
    user = _runtime.prompt_text(payload)
    system = _runtime.system_prompt_text(payload)

    if template == "raw_completion":
        return user

    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": user})

    # Match the app runtime: reasoning/thinking is always off for autocomplete.
    try:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
            enable_thinking=False,
        )
    except TypeError:
        # Older tokenizers do not accept enable_thinking.
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )


def make_greedy_sampler():
    """Return a temperature-0 sampler when the installed mlx_lm exposes one."""
    try:
        sample_utils = importlib.import_module("mlx_lm.sample_utils")
    except ImportError:
        return None
    make_sampler = getattr(sample_utils, "make_sampler", None)
    if make_sampler is None:
        return None
    try:
        return make_sampler(temp=0.0)
    except TypeError:
        return None


def generate_once(mlx_generate, model, tokenizer, prompt: str, max_tokens: int, sampler) -> str:
    kwargs = {"max_tokens": max_tokens, "verbose": False}
    if sampler is not None:
        kwargs["sampler"] = sampler
    try:
        return mlx_generate(model, tokenizer, prompt=prompt, **kwargs)
    except TypeError:
        # Very old signature: positional prompt, no sampler/verbose support.
        return mlx_generate(model, tokenizer, prompt, max_tokens)


def read_rows(stream) -> list[dict]:
    rows = []
    for line in stream:
        stripped = line.strip()
        if not stripped:
            continue
        rows.append(json.loads(stripped))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="qwen35-4b", help="Model alias for the run.")
    parser.add_argument(
        "--row-timeout",
        type=float,
        default=float(os.environ.get("AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT", "45")),
        help="Per-row wall-clock budget in seconds.",
    )
    parser.add_argument(
        "--print-source",
        action="store_true",
        help="Print the resolved model source and exit without loading.",
    )
    args = parser.parse_args()

    source, kind = resolve_model_source(args.model)
    if args.print_source:
        print(f"alias={args.model}")
        print(f"source={source}")
        print(f"kind={kind}")
        return 0

    try:
        mlx_lm = importlib.import_module("mlx_lm")
    except ImportError:
        print("mlx_lm is not installed in this python", file=sys.stderr)
        return 70

    load = getattr(mlx_lm, "load")
    mlx_generate = getattr(mlx_lm, "generate")

    load_started = time.monotonic()
    try:
        model, tokenizer = load(source)
    except Exception as error:  # noqa: BLE001 - surface any load failure cleanly
        print(f"failed to load model from {kind} {source}: {error}", file=sys.stderr)
        return 70
    load_ms = round((time.monotonic() - load_started) * 1000)
    sampler = make_greedy_sampler()

    print(
        f"loaded model source={kind} loadMilliseconds={load_ms}",
        file=sys.stderr,
    )

    rows = read_rows(sys.stdin)

    # MLX (0.31.x, the installed Metal build) binds the GPU stream to the thread
    # that first touches the device while loading, and raises "There is no
    # Stream(gpu, 0) in current thread." for generation on any other thread.
    # A worker-thread executor therefore cannot run a single generation, which
    # is why an earlier batch attempt could not finish even one row. Run each row
    # on the main thread and bound it with a SIGALRM wall-clock timer so a wedged
    # generation still fails its own row (exit 75) instead of hanging the batch.
    import signal
    import threading

    class _RowTimeout(Exception):
        pass

    def _on_row_timeout(signum, frame):  # noqa: ANN001 - POSIX signal handler signature
        raise _RowTimeout()

    use_alarm = hasattr(signal, "SIGALRM") and threading.current_thread() is threading.main_thread()
    if use_alarm:
        signal.signal(signal.SIGALRM, _on_row_timeout)

    exit_code = 0
    for row in rows:
        row_id = str(row.get("id") or "row")
        max_tokens = int(row.get("max_tokens") or 16)
        prompt = build_prompt(row, tokenizer)
        started = time.monotonic()
        if use_alarm:
            signal.setitimer(signal.ITIMER_REAL, max(0.0, float(args.row_timeout)))
        try:
            output = generate_once(mlx_generate, model, tokenizer, prompt, max_tokens, sampler)
        except _RowTimeout:
            # The one-shot itimer has already fired; nothing left to disarm.
            exit_code = 75
            print(json.dumps({"id": row_id, "ok": False, "error": f"timed out after {args.row_timeout}s"}))
            break
        except Exception as error:  # noqa: BLE001
            if use_alarm:
                signal.setitimer(signal.ITIMER_REAL, 0)
            print(json.dumps({"id": row_id, "ok": False, "error": str(error)}))
            sys.stdout.flush()
            continue
        if use_alarm:
            signal.setitimer(signal.ITIMER_REAL, 0)
        latency_ms = round((time.monotonic() - started) * 1000)
        print(json.dumps({"id": row_id, "output": output.strip(), "ok": True, "latency_ms": latency_ms}))
        sys.stdout.flush()

    if use_alarm:
        signal.setitimer(signal.ITIMER_REAL, 0)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
