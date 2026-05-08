#!/usr/bin/env python3
import argparse
import re
import statistics
from pathlib import Path


DEFAULT_LOG = Path.home() / "Library/Logs/AutocompleteLab/diagnostics.log"
DEFAULT_MODEL_ASSET = "Qwen3.5-4B-4bit"
DEFAULT_PHRASE_MAX_TOKENS = 9
DEFAULT_PROOF_MIN_SAMPLES = 5
DEFAULT_PROOF_P95_SHOWN_MS = 750
DEFAULT_PROOF_AVERAGE_SHOWN_MS = 700

BOOTSTRAP_RE = re.compile(
    r"^(?P<timestamp>\S+) runtime-bootstrap .*?\basset=(?P<asset>\S+)"
)
TIMING_RE = re.compile(
    r"^(?P<timestamp>\S+) mlx-completion-timing (?P<fields>.*)$"
)
PRESENTED_RE = re.compile(
    r"^(?P<timestamp>\S+) suggestion-presented (?P<fields>.*)$"
)


def percentile(values, fraction):
    if not values:
        return None

    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def metric_line(label, values):
    if not values:
        return f"{label}: no samples"

    return (
        f"{label}: n={len(values)} min={min(values)}ms "
        f"avg={round(statistics.mean(values))}ms "
        f"p50={percentile(values, 0.50)}ms "
        f"p90={percentile(values, 0.90)}ms "
        f"p95={percentile(values, 0.95)}ms "
        f"max={max(values)}ms"
    )


def field_value(fields, key):
    match = re.search(rf"\b{re.escape(key)}=(?P<value>\S+)", fields)
    if not match:
        return None
    return match.group("value")


def int_field(fields, key):
    value = field_value(fields, key)
    if value is None or value == "none" or not value.isdigit():
        return None
    return int(value)


def parse_launches(lines):
    launches = []
    current = None

    for line in lines:
        bootstrap = BOOTSTRAP_RE.search(line)
        if bootstrap:
            current = {
                "timestamp": bootstrap.group("timestamp"),
                "asset": bootstrap.group("asset"),
                "timings": [],
                "presented": [],
            }
            launches.append(current)
            continue

        if current is None:
            continue

        timing = TIMING_RE.search(line)
        if timing:
            fields = timing.group("fields")
            mode = field_value(fields, "mode")
            generation = int_field(fields, "generationMilliseconds")
            total = int_field(fields, "totalMilliseconds")
            if mode is None or generation is None or total is None:
                continue

            current["timings"].append(
                {
                    "timestamp": timing.group("timestamp"),
                    "mode": mode,
                    "first": int_field(fields, "firstChunkMilliseconds"),
                    "generation": generation,
                    "session": int_field(fields, "sessionMilliseconds"),
                    "prompt": int_field(fields, "promptMilliseconds"),
                    "cleanup": int_field(fields, "cleanupMilliseconds"),
                    "total": total,
                    "maxTokens": int_field(fields, "maxTokens"),
                }
            )
            continue

        presented = PRESENTED_RE.search(line)
        if presented:
            fields = presented.group("fields")
            mode = field_value(fields, "requestMode")
            latency = int_field(fields, "latencyMilliseconds")
            if mode is None or latency is None:
                continue

            current["presented"].append(
                {
                    "timestamp": presented.group("timestamp"),
                    "traceID": field_value(fields, "traceID"),
                    "mode": mode,
                    "latency": latency,
                }
            )

    return launches


def first_presented_samples(presented):
    samples = []
    seen_trace_ids = set()
    for item in presented:
        trace_id = item.get("traceID")
        if trace_id:
            if trace_id in seen_trace_ids:
                continue
            seen_trace_ids.add(trace_id)
        samples.append(item)
    return samples


def print_launch(launch):
    print(f"Launch: {launch['timestamp']} asset={launch['asset']}")

    timings = launch["timings"]
    presented = first_presented_samples(launch["presented"])
    if not timings and not presented:
        print("  no timing samples yet")
        print("  try: type one short sentence in TextEdit or Codex, wait for a phrase suggestion, then rerun this report")
        print("  note: instant word-completion may bypass the model and only appear as shown latency")
        return

    modes = sorted({item["mode"] for item in timings} | {item["mode"] for item in presented})
    for mode in modes:
        mode_timings = [item for item in timings if item["mode"] == mode]
        mode_presented = [item for item in presented if item["mode"] == mode]
        first = [item["first"] for item in mode_timings if item["first"] is not None]
        prompt = [item["prompt"] for item in mode_timings if item["prompt"] is not None]
        session = [item["session"] for item in mode_timings if item["session"] is not None]
        generation = [item["generation"] for item in mode_timings]
        cleanup = [item["cleanup"] for item in mode_timings if item["cleanup"] is not None]
        total = [item["total"] for item in mode_timings]
        shown = [item["latency"] for item in mode_presented]
        token_budgets = sorted({item["maxTokens"] for item in mode_timings if item["maxTokens"] is not None})

        print(f"  {mode}")
        if token_budgets:
            print(f"    max tokens: {', '.join(map(str, token_budgets))}")
        print(f"    {metric_line('prompt build', prompt)}")
        print(f"    {metric_line('session build', session)}")
        print(f"    {metric_line('first token', first)}")
        print(f"    {metric_line('generation', generation)}")
        print(f"    {metric_line('cleanup', cleanup)}")
        print(f"    {metric_line('model total', total)}")
        print(f"    {metric_line('shown latency', shown)}")


def count_samples(launches, bucket):
    if bucket == "presented":
        return sum(len(first_presented_samples(launch[bucket])) for launch in launches)

    return sum(len(launch[bucket]) for launch in launches)


def mode_timing_samples(launches, mode):
    return [
        item
        for launch in launches
        for item in launch["timings"]
        if item["mode"] == mode
    ]


def mode_presented_samples(launches, mode):
    return [
        item
        for launch in launches
        for item in first_presented_samples(launch["presented"])
        if item["mode"] == mode
    ]


def enforce_minimum(label, actual, expected):
    if expected is None:
        return

    if actual < expected:
        raise SystemExit(
            f"not enough {label} samples: expected at least {expected}, found {actual}"
        )


def enforce_maximum(label, actual, maximum):
    if maximum is None:
        return

    if actual is None:
        raise SystemExit(f"{label} missing")

    if actual > maximum:
        raise SystemExit(f"{label} too slow: expected <= {maximum}ms, found {actual}ms")


def enforce_phrase_max_tokens(launches, expected):
    if expected is None:
        return

    token_budgets = sorted(
        {
            item["maxTokens"]
            for item in mode_timing_samples(launches, "phraseContinuation")
            if item["maxTokens"] is not None
        }
    )
    if expected not in token_budgets:
        found = ", ".join(map(str, token_budgets)) if token_budgets else "none"
        raise SystemExit(f"default phrase token budget mismatch: expected {expected}, found {found}")


def main():
    parser = argparse.ArgumentParser(description="Summarize local Autocomplete Lab model latency logs.")
    parser.add_argument("--log", default=str(DEFAULT_LOG), help="diagnostics.log path")
    parser.add_argument("--latest", action="store_true", help="show only the latest model launch")
    parser.add_argument("--asset", help="show only launches whose asset contains this text")
    parser.add_argument(
        "--default-model-proof",
        action="store_true",
        help="prove the latest Qwen3.5 4B default-model launch has enough phrase latency samples under target.",
    )
    parser.add_argument(
        "--require-timing-samples",
        type=int,
        help="fail unless the selected launches include at least this many model timing samples",
    )
    parser.add_argument(
        "--require-shown-samples",
        type=int,
        help="fail unless the selected launches include at least this many shown suggestion samples",
    )
    parser.add_argument(
        "--require-phrase-timing-samples",
        type=int,
        help="fail unless selected launches include at least this many phrase model timing samples",
    )
    parser.add_argument(
        "--require-phrase-shown-samples",
        type=int,
        help="fail unless selected launches include at least this many phrase shown-latency samples",
    )
    parser.add_argument(
        "--require-phrase-max-tokens",
        type=int,
        help="fail unless phrase model timings include this max token budget",
    )
    parser.add_argument(
        "--require-p95-shown-ms",
        type=int,
        help="fail unless phrase shown-latency p95 is at or below this threshold",
    )
    parser.add_argument(
        "--require-average-shown-ms",
        type=int,
        help="fail unless phrase shown-latency average is at or below this threshold",
    )
    args = parser.parse_args()

    if args.default_model_proof:
        args.latest = True
        args.asset = DEFAULT_MODEL_ASSET
        args.require_timing_samples = args.require_timing_samples or DEFAULT_PROOF_MIN_SAMPLES
        args.require_shown_samples = args.require_shown_samples or DEFAULT_PROOF_MIN_SAMPLES
        args.require_phrase_timing_samples = args.require_phrase_timing_samples or DEFAULT_PROOF_MIN_SAMPLES
        args.require_phrase_shown_samples = args.require_phrase_shown_samples or DEFAULT_PROOF_MIN_SAMPLES
        args.require_phrase_max_tokens = args.require_phrase_max_tokens or DEFAULT_PHRASE_MAX_TOKENS
        args.require_p95_shown_ms = args.require_p95_shown_ms or DEFAULT_PROOF_P95_SHOWN_MS
        args.require_average_shown_ms = args.require_average_shown_ms or DEFAULT_PROOF_AVERAGE_SHOWN_MS

    log_path = Path(args.log).expanduser()
    if not log_path.exists():
        raise SystemExit(f"diagnostics log missing: {log_path}")

    launches = parse_launches(log_path.read_text(errors="ignore").splitlines())
    if args.asset:
        launches = [launch for launch in launches if args.asset in launch["asset"]]
    if args.latest and launches:
        launches = [launches[-1]]

    if not launches:
        raise SystemExit("no matching model launches found")

    enforce_minimum(
        "model timing",
        count_samples(launches, "timings"),
        args.require_timing_samples,
    )
    enforce_minimum(
        "shown suggestion",
        count_samples(launches, "presented"),
        args.require_shown_samples,
    )
    phrase_timing = mode_timing_samples(launches, "phraseContinuation")
    phrase_shown = mode_presented_samples(launches, "phraseContinuation")
    enforce_minimum(
        "phrase model timing",
        len(phrase_timing),
        args.require_phrase_timing_samples,
    )
    enforce_minimum(
        "phrase shown suggestion",
        len(phrase_shown),
        args.require_phrase_shown_samples,
    )
    enforce_phrase_max_tokens(launches, args.require_phrase_max_tokens)

    phrase_shown_latencies = [item["latency"] for item in phrase_shown]
    enforce_maximum(
        "phrase shown p95",
        percentile(phrase_shown_latencies, 0.95),
        args.require_p95_shown_ms,
    )
    average_phrase_shown = (
        round(statistics.mean(phrase_shown_latencies)) if phrase_shown_latencies else None
    )
    enforce_maximum(
        "phrase shown average",
        average_phrase_shown,
        args.require_average_shown_ms,
    )

    for index, launch in enumerate(launches):
        if index:
            print()
        print_launch(launch)

    if args.default_model_proof:
        print()
        print(
            "Default model proof passed: "
            f"asset={DEFAULT_MODEL_ASSET} "
            f"phraseShownP95<={args.require_p95_shown_ms}ms "
            f"phraseShownAverage<={args.require_average_shown_ms}ms "
            f"phraseMaxTokens={args.require_phrase_max_tokens}"
        )


if __name__ == "__main__":
    main()
