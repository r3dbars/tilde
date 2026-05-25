#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import os
import re
import statistics
from pathlib import Path


DEFAULT_LOG = Path.home() / "Library/Logs/SteadyType/diagnostics.log"
DEFAULT_MODEL_ASSET = "Qwen3.5-4B-4bit"
DEFAULT_PHRASE_MAX_TOKENS = 14
DEFAULT_PROOF_MIN_SAMPLES = 5
DEFAULT_PROOF_P95_SHOWN_MS = 750
DEFAULT_PROOF_AVERAGE_SHOWN_MS = 700
DEFAULT_RESOURCE_MAX_CPU_PERCENT = 25.0
DEFAULT_RESOURCE_MAX_RSS_MB = 6144
DEFAULT_RESOURCE_MAX_RSS_GROWTH_MB = 512
DEFAULT_COLD_LOAD_MAX_MS = 30000
DEFAULT_WARM_SUCCEEDED_MAX_MS = 10000

BOOTSTRAP_RE = re.compile(
    r"^(?P<timestamp>\S+) runtime-bootstrap .*?\basset=(?P<asset>\S+)"
)
LAUNCH_RE = re.compile(r"^(?P<timestamp>\S+) launch\b(?P<fields>.*)$")
TIMING_RE = re.compile(
    r"^(?P<timestamp>\S+) mlx-completion-timing (?P<fields>.*)$"
)
PRESENTED_RE = re.compile(
    r"^(?P<timestamp>\S+) suggestion-presented (?P<fields>.*)$"
)
PROOF_MODE_RE = re.compile(
    r"^(?P<timestamp>\S+) app-proof-mode-started (?P<fields>.*)$"
)
MODEL_LOAD_RE = re.compile(
    r"^(?P<timestamp>\S+) (?P<event>mlx-model-load-succeeded|mlx-model-load-reused|mlx-model-load-failed|mlx-model-load-cancelled) (?P<fields>.*)$"
)
RUNTIME_WARM_RE = re.compile(
    r"^(?P<timestamp>\S+) (?P<event>runtime-warm-succeeded|runtime-warm-failed|runtime-warm-skipped|runtime-warm-cancelled) (?P<fields>.*)$"
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
        f"p99={percentile(values, 0.99)}ms "
        f"max={max(values)}ms"
    )


def resource_metric(values, unit, precision=0):
    if not values:
        return "no samples"

    summary = {
        "n": len(values),
        "min": min(values),
        "avg": statistics.mean(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "max": max(values),
    }
    if precision:
        return (
            f"n={summary['n']} min={summary['min']:.{precision}f}{unit} "
            f"avg={summary['avg']:.{precision}f}{unit} "
            f"p50={summary['p50']:.{precision}f}{unit} "
            f"p95={summary['p95']:.{precision}f}{unit} "
            f"max={summary['max']:.{precision}f}{unit}"
        )
    return (
        f"n={summary['n']} min={round(summary['min'])}{unit} "
        f"avg={round(summary['avg'])}{unit} "
        f"p50={round(summary['p50'])}{unit} "
        f"p95={round(summary['p95'])}{unit} "
        f"max={round(summary['max'])}{unit}"
    )


def rss_growth(values):
    return max(values) - min(values) if len(values) >= 2 else 0


def resource_samples_after_ready(launch):
    ready_timestamp = launch.get("readyTimestamp")
    if ready_timestamp is None:
        return launch["resourceSamples"]

    samples = []
    for sample in launch["resourceSamples"]:
        timestamp = parse_timestamp(sample.get("timestamp", ""))
        if timestamp is not None and timestamp >= ready_timestamp:
            samples.append(sample)
    return samples


def resource_line(launch):
    samples = launch["resourceSamples"]
    if not samples:
        return "resource samples: n=0"

    cpu_values = [sample["cpuPercent"] for sample in samples if sample.get("cpuPercent") is not None]
    rss_values = [sample["rssMB"] for sample in samples if sample.get("rssMB") is not None]
    post_ready_rss_values = [
        sample["rssMB"]
        for sample in resource_samples_after_ready(launch)
        if sample.get("rssMB") is not None
    ]
    model_load_delta = rss_growth(rss_values)
    post_ready_growth = rss_growth(post_ready_rss_values)
    return (
        f"resource samples: n={len(samples)} "
        f"cpu {resource_metric(cpu_values, '%', precision=1)} "
        f"rss {resource_metric(rss_values, 'MB')} "
        f"rssModelLoadDelta={model_load_delta}MB "
        f"rssPostReadyGrowth={post_ready_growth}MB"
    )


def field_value(fields, key):
    match = re.search(rf"\b{re.escape(key)}=(?P<value>\S+)", fields)
    if not match:
        return None
    return match.group("value")


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def int_field(fields, key):
    value = field_value(fields, key)
    if value is None or value == "none" or not value.isdigit():
        return None
    return int(value)


def float_field(fields, key):
    value = field_value(fields, key)
    if value is None or value == "none":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def parse_timestamp(value):
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_launches(lines):
    launches = []
    current = None
    pending_proof_app = None
    pending_proof_scenario = None
    pending_launch_timestamp = None
    pending_executable_sha256 = None

    for line in lines:
        launch_line = LAUNCH_RE.search(line)
        if launch_line:
            pending_launch_timestamp = parse_timestamp(launch_line.group("timestamp"))
            pending_executable_sha256 = field_value(
                launch_line.group("fields"),
                "executableSHA256",
            )

        proof_mode = PROOF_MODE_RE.search(line)
        if proof_mode:
            fields = proof_mode.group("fields")
            pending_proof_app = field_value(fields, "app")
            pending_proof_scenario = field_value(fields, "scenario")
            continue

        bootstrap = BOOTSTRAP_RE.search(line)
        if bootstrap:
            current = {
                "timestamp": bootstrap.group("timestamp"),
                "asset": bootstrap.group("asset"),
                "proofApp": pending_proof_app,
                "proofScenario": pending_proof_scenario,
                "executableSHA256": pending_executable_sha256,
                "timings": [],
                "presented": [],
                "modelLoads": [],
                "runtimeWarm": [],
                "launchToReady": [],
                "readyTimestamp": None,
                "resourceSamples": [],
            }
            launches.append(current)
            pending_proof_app = None
            pending_proof_scenario = None
            pending_executable_sha256 = None
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
                    "app": field_value(fields, "app"),
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

        model_load = MODEL_LOAD_RE.search(line)
        if model_load:
            fields = model_load.group("fields")
            current["modelLoads"].append(
                {
                    "timestamp": model_load.group("timestamp"),
                    "event": model_load.group("event"),
                    "duration": int_field(fields, "loadMilliseconds"),
                }
            )
            continue

        runtime_warm = RUNTIME_WARM_RE.search(line)
        if runtime_warm:
            fields = runtime_warm.group("fields")
            duration = int_field(fields, "warmMilliseconds")
            event = runtime_warm.group("event")
            current["runtimeWarm"].append(
                {
                    "timestamp": runtime_warm.group("timestamp"),
                    "event": event,
                    "duration": duration,
                }
            )
            timestamp = parse_timestamp(runtime_warm.group("timestamp"))
            if (
                event == "runtime-warm-succeeded"
                and timestamp is not None
                and pending_launch_timestamp is not None
            ):
                current["launchToReady"].append(
                    round((timestamp - pending_launch_timestamp).total_seconds() * 1000)
                )
                pending_launch_timestamp = None
                if current["readyTimestamp"] is None:
                    current["readyTimestamp"] = timestamp
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
                    "app": field_value(fields, "app"),
                    "traceID": field_value(fields, "traceID"),
                    "mode": mode,
                    "latency": latency,
                }
            )
            continue

        cpu_percent = float_field(line, "cpuPercent")
        rss_mb = int_field(line, "rssMB")
        if cpu_percent is not None or rss_mb is not None:
            current["resourceSamples"].append(
                {
                    "timestamp": line.split(maxsplit=1)[0] if line.split() else "",
                    "cpuPercent": cpu_percent,
                    "rssMB": rss_mb,
                }
            )

    return launches


def line_slice(path, start_line=0, end_line=None):
    selected = []
    with path.open(errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            if end_line is not None and line_number > end_line:
                break
            selected.append(line.rstrip("\n"))
    return selected


def env_line(name):
    value = os.environ.get(name)
    if not value:
        return 0
    try:
        line = int(value)
    except ValueError:
        raise SystemExit(f"{name} must be an integer line number, got {value!r}")
    if line < 0:
        raise SystemExit(f"{name} must be a non-negative line number, got {value!r}")
    return line


def env_end_line(name):
    value = os.environ.get(name)
    if not value:
        return None
    try:
        line = int(value)
    except ValueError:
        raise SystemExit(f"{name} must be an integer line number, got {value!r}")
    if line < 0:
        raise SystemExit(f"{name} must be a non-negative line number, got {value!r}")
    return line


def validate_end_line(start_line, end_line):
    if end_line is None:
        return None
    if end_line < start_line:
        raise SystemExit(f"end line {end_line} is before start line {start_line}")
    return end_line


def filter_samples_by_app(launches, required_app):
    if not required_app:
        return launches

    filtered = []
    for launch in launches:
        launch_copy = dict(launch)
        launch_copy["timings"] = [
            item for item in launch["timings"] if item.get("app") == required_app
        ]
        launch_copy["presented"] = [
            item for item in launch["presented"] if item.get("app") == required_app
        ]
        filtered.append(launch_copy)
    return filtered


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


def event_durations(launches, collection, event=None):
    return [
        item["duration"]
        for launch in launches
        for item in launch[collection]
        if item["duration"] is not None and (event is None or item["event"] == event)
    ]


def launch_to_ready_samples(launches):
    return [value for launch in launches for value in launch["launchToReady"]]


def resource_samples(launches):
    return [sample for launch in launches for sample in launch["resourceSamples"]]


def energy_risk(launch):
    score = 0
    reasons = []
    samples = launch["resourceSamples"]
    cpu_values = [sample["cpuPercent"] for sample in samples if sample.get("cpuPercent") is not None]
    rss_values = [sample["rssMB"] for sample in samples if sample.get("rssMB") is not None]
    cold_loads = [
        item["duration"]
        for item in launch["modelLoads"]
        if item["event"] == "mlx-model-load-succeeded" and item["duration"] is not None
    ]
    warm_succeeded = [
        item["duration"]
        for item in launch["runtimeWarm"]
        if item["event"] == "runtime-warm-succeeded" and item["duration"] is not None
    ]

    if cpu_values:
        cpu = max(cpu_values)
        if cpu > 35:
            score += 2
        elif cpu > 10:
            score += 1
        if cpu > 10:
            reasons.append(f"cpuMax={cpu:.1f}%")
    if rss_values:
        rss = max(rss_values)
        if rss > 8192:
            score += 2
        elif rss > 4096:
            score += 1
        if rss > 4096:
            reasons.append(f"rssMax={rss}MB")
    if cold_loads and max(cold_loads) > DEFAULT_COLD_LOAD_MAX_MS:
        score += 1
        reasons.append(f"coldLoadMax={max(cold_loads)}ms")
    if warm_succeeded and max(warm_succeeded) > DEFAULT_WARM_SUCCEEDED_MAX_MS:
        score += 1
        reasons.append(f"warmMax={max(warm_succeeded)}ms")

    if score >= 4:
        label = "high"
    elif score >= 2:
        label = "medium"
    else:
        label = "low"
    return label, reasons or ["no current resource risk markers"]


def print_launch(launch):
    proof = ""
    if launch.get("proofScenario"):
        proof = f" scenario={launch['proofScenario']}"
    elif launch.get("proofApp"):
        proof = f" proofApp={launch['proofApp']}"
    print(f"Launch: {launch['timestamp']} asset={launch['asset']}{proof}")
    cold_loads = [
        item["duration"]
        for item in launch["modelLoads"]
        if item["event"] == "mlx-model-load-succeeded" and item["duration"] is not None
    ]
    warm_reuse = [
        item["duration"]
        for item in launch["modelLoads"]
        if item["event"] == "mlx-model-load-reused" and item["duration"] is not None
    ]
    warm_succeeded = [
        item["duration"]
        for item in launch["runtimeWarm"]
        if item["event"] == "runtime-warm-succeeded" and item["duration"] is not None
    ]
    print(f"  {metric_line('app launch to ready', launch['launchToReady'])}")
    print(f"  {metric_line('cold model load', cold_loads)}")
    print(f"  {metric_line('warm model reuse', warm_reuse)}")
    print(f"  {metric_line('runtime warm succeeded', warm_succeeded)}")
    print(f"  {resource_line(launch)}")
    risk, reasons = energy_risk(launch)
    print(f"  energy risk: {risk} ({'; '.join(reasons)})")

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


def enforce_float_maximum(label, actual, maximum, unit):
    if maximum is None:
        return
    if actual is None:
        raise SystemExit(f"{label} missing")
    if actual > maximum:
        raise SystemExit(f"{label} too high: expected <= {maximum}{unit}, found {actual}{unit}")


def enforce_duration_maximum(label, values, maximum):
    if maximum is None:
        return
    if not values:
        raise SystemExit(f"{label} missing")
    actual = max(values)
    if actual > maximum:
        raise SystemExit(f"{label} too slow: expected <= {maximum}ms, found {actual}ms")


def enforce_resource_gate(launches, args):
    samples = resource_samples(launches)
    enforce_minimum("resource", len(samples), args.require_resource_samples)
    cpu_values = [sample["cpuPercent"] for sample in samples if sample.get("cpuPercent") is not None]
    rss_values = [sample["rssMB"] for sample in samples if sample.get("rssMB") is not None]
    post_ready_samples = [
        sample
        for launch in launches
        for sample in resource_samples_after_ready(launch)
    ]
    post_ready_rss_values = [
        sample["rssMB"] for sample in post_ready_samples if sample.get("rssMB") is not None
    ]
    enforce_float_maximum(
        "resource cpu max",
        max(cpu_values) if cpu_values else None,
        args.max_cpu_percent,
        "%",
    )
    enforce_float_maximum(
        "resource rss max",
        max(rss_values) if rss_values else None,
        args.max_rss_mb,
        "MB",
    )
    if args.max_rss_growth_mb is not None:
        growth_values = post_ready_rss_values if post_ready_rss_values else rss_values
        growth_label = "post-ready resource rss growth" if post_ready_rss_values else "resource rss growth"
        if len(growth_values) < 2:
            raise SystemExit("resource rss growth missing")
        growth = rss_growth(growth_values)
        if growth > args.max_rss_growth_mb:
            raise SystemExit(
                f"{growth_label} too high: expected <= {args.max_rss_growth_mb}MB, found {growth}MB"
            )


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
    parser = argparse.ArgumentParser(description="Summarize local SteadyType model latency logs.")
    parser.add_argument("--log", default=str(DEFAULT_LOG), help="diagnostics.log path")
    parser.add_argument("--latest", action="store_true", help="show only the latest model launch")
    parser.add_argument("--asset", help="show only launches whose asset contains this text")
    parser.add_argument(
        "--expected-executable-sha256",
        help="show only launches whose diagnostics launch line matches this executable hash",
    )
    parser.add_argument(
        "--app-binary",
        help="hash this app binary and show only matching diagnostics launches",
    )
    parser.add_argument(
        "--start-line",
        type=int,
        default=env_line("AUTOCOMPLETE_LAB_LOG_START_LINE"),
        help="ignore diagnostics lines at or before this 1-based line number",
    )
    parser.add_argument(
        "--end-line",
        type=int,
        default=env_end_line("AUTOCOMPLETE_LAB_LOG_END_LINE"),
        help="ignore diagnostics lines after this 1-based line number",
    )
    parser.add_argument(
        "--require-sample-app",
        help="fail unless the selected launch has enough timing and shown samples for this app bundle",
    )
    parser.add_argument(
        "--require-proof-scenario",
        help="fail unless the selected launch was tagged with this proof scenario",
    )
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
    parser.add_argument(
        "--require-cold-load-samples",
        type=int,
        help="fail unless selected launches include at least this many cold model load samples",
    )
    parser.add_argument(
        "--require-warm-succeeded-samples",
        type=int,
        help="fail unless selected launches include at least this many runtime warm success samples",
    )
    parser.add_argument(
        "--max-cold-load-ms",
        type=int,
        help="fail unless the selected cold model load max stays under this budget",
    )
    parser.add_argument(
        "--max-warm-succeeded-ms",
        type=int,
        help="fail unless the selected runtime warm max stays under this budget",
    )
    parser.add_argument(
        "--require-resource-samples",
        type=int,
        help="fail unless selected launches include at least this many CPU/RSS resource samples",
    )
    parser.add_argument("--max-cpu-percent", type=float)
    parser.add_argument("--max-rss-mb", type=int)
    parser.add_argument("--max-rss-growth-mb", type=int)
    args = parser.parse_args()
    args.end_line = validate_end_line(max(0, args.start_line), args.end_line)

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

    launches = parse_launches(
        line_slice(log_path, max(0, args.start_line), args.end_line)
    )
    if args.asset:
        launches = [launch for launch in launches if args.asset in launch["asset"]]
    expected_executable_sha256 = (args.expected_executable_sha256 or "").strip().lower()
    if args.app_binary:
        app_binary = Path(args.app_binary).expanduser()
        if not app_binary.is_file():
            raise SystemExit(f"missing app binary: {app_binary}")
        expected_executable_sha256 = sha256_file(app_binary)
    if expected_executable_sha256:
        launches = [
            launch
            for launch in launches
            if str(launch.get("executableSHA256") or "").lower() == expected_executable_sha256
        ]
    if args.require_proof_scenario:
        launches = [
            launch
            for launch in launches
            if launch.get("proofScenario") == args.require_proof_scenario
        ]
    if args.latest and launches:
        launches = [launches[-1]]

    if not launches:
        raise SystemExit("no matching model launches found")

    launches = filter_samples_by_app(launches, args.require_sample_app)

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
    cold_loads = event_durations(launches, "modelLoads", "mlx-model-load-succeeded")
    warm_succeeded = event_durations(launches, "runtimeWarm", "runtime-warm-succeeded")
    enforce_minimum("cold model load", len(cold_loads), args.require_cold_load_samples)
    enforce_minimum("runtime warm success", len(warm_succeeded), args.require_warm_succeeded_samples)
    enforce_duration_maximum("cold model load max", cold_loads, args.max_cold_load_ms)
    enforce_duration_maximum("runtime warm max", warm_succeeded, args.max_warm_succeeded_ms)
    enforce_resource_gate(launches, args)

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
