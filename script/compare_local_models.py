#!/usr/bin/env python3
from __future__ import annotations

import argparse
import statistics
from collections import defaultdict
from pathlib import Path


DEFAULT_DIAGNOSTICS_LOG = Path.home() / "Library/Logs/SteadyType/diagnostics.log"
DEFAULT_MODEL_ROOT = Path.home() / "Library/Application Support/SteadyType/Models"
DEFAULT_ALIASES = [
    "qwen3-0.6b",
    "qwen3-1.7b",
    "qwen35-4b",
    "qwen35-9b",
    "gemma-4-e4b",
    "gemma-4-e4b-it-optiq",
    "gemma-4-26b",
]
MODEL_PATHS = {
    "qwen3-0.6b": "Qwen3Small/MLX/qwen3-0.6b-4bit",
    "qwen3-1.7b": "Qwen3Medium/MLX/qwen3-1.7b-4bit",
    "qwen35-4b": "Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    "qwen35-9b": "Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    "gemma-4-e4b": "Gemma4E4B/MLX/gemma-4-e4b-4bit",
    "gemma-4-e4b-it-optiq": "Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    "gemma-4-26b": "Gemma4A4B/MLX/gemma-4-26b-a4b-it-4bit",
}
ASSET_ALIAS_HINTS = {
    "qwen3-0.6b": "qwen3-0.6b",
    "qwen3-1.7b": "qwen3-1.7b",
    "qwen3.5-4b": "qwen35-4b",
    "qwen3.5-9b": "qwen35-9b",
    "gemma-4-e4b-4bit": "gemma-4-e4b",
    "gemma-4-e4b-it-optiq": "gemma-4-e4b-it-optiq",
    "gemma-4-26b": "gemma-4-26b",
}


def fields_from(parts: list[str]) -> dict[str, str]:
    fields = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def int_field(fields: dict[str, str], key: str) -> int | None:
    value = fields.get(key)
    if value is None or value == "none":
        return None
    try:
        return int(value)
    except ValueError:
        return None


def percentile(values: list[int], fraction: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def directory_size_bytes(path: Path) -> int | None:
    if not path.exists():
        return None
    total = 0
    for child in path.rglob("*"):
        if child.is_file():
            try:
                total += child.stat().st_size
            except OSError:
                pass
    return total


def format_bytes(size: int | None) -> str:
    if size is None:
        return "missing"
    units = ["B", "KiB", "MiB", "GiB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def alias_for_bootstrap(fields: dict[str, str]) -> str:
    override = fields.get("modelOverride", "").strip().lower()
    if override:
        return override
    asset = fields.get("asset", "").strip().lower()
    for hint, alias in ASSET_ALIAS_HINTS.items():
        if hint in asset:
            return alias
    return "default"


def parse_diagnostics(path: Path, line_limit: int) -> tuple[list[str], dict[str, dict[str, list[int]]]]:
    if not path.exists():
        return [], {}
    rows = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            stripped = raw_line.strip()
            if stripped:
                rows.append((line_number, stripped))
    if line_limit > 0:
        rows = rows[-line_limit:]

    launches: list[str] = []
    timings: dict[str, dict[str, list[int]]] = defaultdict(lambda: defaultdict(list))
    current_alias = ""
    for line_number, line in rows:
        parts = line.split()
        if len(parts) < 2:
            continue
        event = parts[1]
        fields = fields_from(parts[2:])
        if event == "runtime-bootstrap":
            current_alias = alias_for_bootstrap(fields)
            override = fields.get("modelOverride") or "none"
            launches.append(
                "Runtime launch: "
                f"asset={fields.get('asset', 'unknown')} "
                f"candidate={fields.get('activeCandidate', 'unknown')} "
                f"native={fields.get('nativeRuntimeAvailable', 'unknown')} "
                f"override={override} line={line_number}"
            )
            continue
        if event == "mlx-model-load-succeeded" and current_alias:
            load = int_field(fields, "loadMilliseconds")
            if load is not None:
                timings[current_alias]["load"].append(load)
            continue
        if event == "runtime-warm-succeeded" and current_alias:
            warm = int_field(fields, "warmMilliseconds")
            if warm is not None:
                timings[current_alias]["warm"].append(warm)
            continue
        if event != "mlx-completion-timing" or not current_alias:
            continue
        first = int_field(fields, "firstChunkMilliseconds")
        total = int_field(fields, "totalMilliseconds") or int_field(fields, "generationMilliseconds")
        if first is not None:
            timings[current_alias]["first"].append(first)
        if total is not None:
            timings[current_alias]["total"].append(total)
    return launches, timings


def model_rows(model_root: Path, aliases: list[str]) -> list[tuple[str, bool, str]]:
    rows = []
    for alias in aliases:
        relative = MODEL_PATHS.get(alias)
        if not relative:
            rows.append((alias, False, "unknown alias"))
            continue
        path = model_root / relative
        rows.append((alias, path.exists(), format_bytes(directory_size_bytes(path))))
    return rows


def summary(values: list[int]) -> str:
    if not values:
        return "n=0"
    return (
        f"n={len(values)} avg={round(statistics.mean(values))}ms "
        f"p50={percentile(values, 0.50)}ms p95={percentile(values, 0.95)}ms "
        f"max={max(values)}ms"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare app-owned local model configs from redacted inventory and diagnostics metadata."
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--model-root", default=str(DEFAULT_MODEL_ROOT))
    parser.add_argument("--line-limit", type=int, default=5000)
    parser.add_argument("--models", nargs="+", default=DEFAULT_ALIASES)
    args = parser.parse_args()

    diagnostics_path = Path(args.diagnostics_log).expanduser()
    model_root = Path(args.model_root).expanduser()
    aliases = list(dict.fromkeys(args.models))
    launches, timings = parse_diagnostics(diagnostics_path, max(0, args.line_limit))

    print("Local model comparison")
    print(f"Diagnostics log: {diagnostics_path}")
    print(f"Model root: {model_root}")
    print("Privacy: metadata-only; no prompts, typed text, completions, screenshots, URLs, or paths from events are printed.")
    print()
    print("Supported local model assets")
    for alias, installed, size in model_rows(model_root, aliases):
        state = "installed" if installed else "missing"
        print(f"  {alias}: {state}, {size}")
    print()
    print("Runtime launches")
    if launches:
        for launch in launches:
            print(launch)
    else:
        print("Runtime launch: no runtime-bootstrap events")
    print()
    print("Timing matrix")
    for alias in aliases:
        load = timings.get(alias, {}).get("load", [])
        warm = timings.get(alias, {}).get("warm", [])
        first = timings.get(alias, {}).get("first", [])
        total = timings.get(alias, {}).get("total", [])
        print(
            f"  {alias}: modelLoad {summary(load)}; runtimeWarm {summary(warm)}; "
            f"firstToken {summary(first)}; totalGeneration {summary(total)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
