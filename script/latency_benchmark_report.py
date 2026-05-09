#!/usr/bin/env python3
import argparse
import json
import re
import statistics
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


DEFAULT_DIAGNOSTICS_LOG = Path.home() / "Library/Logs/AutocompleteLab/diagnostics.log"
DEFAULT_TRACE_LOG = Path.home() / "Library/Logs/AutocompleteLab/traces.jsonl"
DEFAULT_LINE_LIMIT = 5000
DEFAULT_LATE_VISIBLE_BUDGET_MS = 750
DEFAULT_EXPECTED_ASSET = "Qwen3.5-4B-4bit"

BETA_MIN_FIRST_VISIBLE_SAMPLES = 5
BETA_MIN_MODEL_SAMPLES = 5
BETA_MIN_EVENT_TAP_SAMPLES = 0
BETA_MIN_AX_SAMPLES = 1
BETA_MAX_FIRST_VISIBLE_P95_MS = 750
BETA_MAX_FIRST_VISIBLE_P99_MS = 750
BETA_MAX_FIRST_TOKEN_P95_MS = 650
BETA_MAX_TOTAL_GENERATION_P95_MS = 900
BETA_MAX_EVENT_TAP_P95_US = 8000
BETA_MAX_EVENT_TAP_MAX_US = 8000
BETA_MAX_AX_P95_MS = 90
BETA_MAX_AX_P99_MS = 120
BETA_MAX_AX_MAX_MS = None


@dataclass(frozen=True)
class Sample:
    value: int
    app: str
    profile: str
    mode: str
    source: str
    line: int
    label: str = ""


@dataclass(frozen=True)
class SummaryWindow:
    count: int
    p50: Optional[int]
    p90: Optional[int]
    p95: Optional[int]
    p99: Optional[int]
    maximum: Optional[int]
    source: str
    line: int


@dataclass(frozen=True)
class Suppression:
    app: str
    profile: str
    mode: str
    reason: str
    latency: Optional[int]
    line: int


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def metrics(values):
    if not values:
        return None
    return {
        "n": len(values),
        "min": min(values),
        "avg": round(statistics.mean(values)),
        "p50": percentile(values, 0.50),
        "p90": percentile(values, 0.90),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": max(values),
    }


def metric_line(label, samples, unit):
    values = [sample.value for sample in samples]
    summary = metrics(values)
    if summary is None:
        return f"{label}: no samples"
    return (
        f"{label}: n={summary['n']} min={summary['min']}{unit} "
        f"avg={summary['avg']}{unit} p50={summary['p50']}{unit} "
        f"p90={summary['p90']}{unit} p95={summary['p95']}{unit} "
        f"p99={summary['p99']}{unit} max={summary['max']}{unit}"
    )


def summary_window_line(label, windows, unit):
    if not windows:
        return f"{label}: no summary windows"

    total = sum(window.count for window in windows)
    p50 = compact_metric([window.p50 for window in windows])
    p90 = compact_metric([window.p90 for window in windows])
    p95 = compact_metric([window.p95 for window in windows])
    p99 = compact_metric([window.p99 for window in windows])
    maximum = compact_metric([window.maximum for window in windows])
    return (
        f"{label}: windows={len(windows)} samples={total} "
        f"p50Max={p50}{unit} p90Max={p90}{unit} p95Max={p95}{unit} "
        f"p99Max={p99}{unit} max={maximum}{unit}"
    )


def compact_metric(values):
    clean = [value for value in values if value is not None]
    if not clean:
        return "n/a"
    return str(max(clean))


def fields_from(parts):
    fields = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def int_value(value):
    if value is None or value == "none":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def metadata_value(event, key, fallback="unknown"):
    metadata = event.get("metadata") or {}
    value = metadata.get(key)
    if value is None or value == "":
        return fallback
    return str(value)


def event_app(event):
    return (
        event.get("appBundleIdentifier")
        or metadata_value(event, "app", "")
        or "unknown"
    )


def event_profile(event):
    return metadata_value(event, "behaviorProfile", "unknown")


def event_mode(event):
    return event.get("requestMode") or metadata_value(event, "requestMode", "unknown")


def line_slice(path, start_line, line_limit):
    if not path.exists():
        return []

    selected = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            stripped = line.strip()
            if stripped:
                selected.append((line_number, stripped))

    if line_limit > 0:
        selected = selected[-line_limit:]
    return selected


def parse_trace_log(path, start_line, line_limit, late_visible_budget_ms):
    first_visible = []
    first_token = []
    total_generation = []
    stale_late_suppressed = []
    late_visible = []
    seen_presented = set()
    seen_model = set()
    malformed = []

    for line_number, line in line_slice(path, start_line, line_limit):
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            malformed.append(f"{path}:{line_number} invalid trace JSON: {error.msg}")
            continue

        event_type = event.get("type")
        suggestion_id = event.get("suggestionID") or event.get("id") or f"line-{line_number}"
        app = event_app(event)
        profile = event_profile(event)
        mode = event_mode(event)
        metadata = event.get("metadata") or {}

        if event_type == "suggestionPresented":
            if suggestion_id in seen_presented:
                continue
            seen_presented.add(suggestion_id)
            latency = int_value(event.get("latencyMilliseconds"))
            if latency is None:
                continue
            sample = Sample(latency, app, profile, mode, "trace", line_number, suggestion_id)
            first_visible.append(sample)
            if latency > late_visible_budget_ms:
                late_visible.append(sample)
            continue

        if event_type == "modelResult":
            model_key = (suggestion_id, line_number)
            if model_key in seen_model:
                continue
            seen_model.add(model_key)

            token_latency = int_value(metadata.get("firstTokenLatencyMilliseconds"))
            if token_latency is not None:
                first_token.append(
                    Sample(token_latency, app, profile, mode, "trace", line_number, suggestion_id)
                )

            generation_latency = int_value(
                metadata.get("totalGenerationLatencyMilliseconds")
            )
            if generation_latency is None:
                generation_latency = int_value(event.get("latencyMilliseconds"))
            if generation_latency is not None:
                total_generation.append(
                    Sample(generation_latency, app, profile, mode, "trace", line_number, suggestion_id)
                )
            continue

        if event_type == "suggestionSuppressed":
            reason = str(event.get("reason") or metadata.get("reason") or "unknown")
            latency = int_value(event.get("latencyMilliseconds"))
            suppression = Suppression(app, profile, mode, reason, latency, line_number)
            if is_stale_late_suppression(suppression, late_visible_budget_ms, metadata):
                stale_late_suppressed.append(suppression)

    return {
        "first_visible": first_visible,
        "first_token": first_token,
        "total_generation": total_generation,
        "stale_late_suppressed": stale_late_suppressed,
        "late_visible": late_visible,
        "malformed": malformed,
    }


def is_stale_late_suppression(suppression, late_visible_budget_ms, metadata):
    reason = suppression.reason.lower()
    if "stale" in reason or "too-slow" in reason:
        return True
    if suppression.latency is not None and suppression.latency > late_visible_budget_ms:
        return True
    return any("too-slow" in str(value).lower() for value in metadata.values())


def parse_diagnostics_log(path, start_line, line_limit):
    presented = []
    first_token = []
    total_generation = []
    event_tap = []
    event_tap_windows = []
    event_tap_slow_markers = []
    event_tap_failures = []
    ax_windows = []
    ax_slow_markers = []
    ax_skips = []
    runtime_launches = []
    malformed = []
    seen_presented = set()

    for line_number, line in line_slice(path, start_line, line_limit):
        parts = line.split()
        if len(parts) < 2:
            continue
        event = parts[1]
        fields = fields_from(parts[2:])

        if event == "runtime-bootstrap":
            runtime_launches.append(
                {
                    "line": line_number,
                    "asset": fields.get("asset", "unknown"),
                    "candidate": fields.get("activeCandidate", "unknown"),
                    "nativeRuntimeAvailable": fields.get("nativeRuntimeAvailable", "unknown"),
                    "modelOverride": fields.get("modelOverride", ""),
                }
            )
            continue

        if event == "suggestion-presented":
            latency = int_value(fields.get("latencyMilliseconds"))
            if latency is None:
                continue
            key = fields.get("suggestionID") or fields.get("traceID") or f"line-{line_number}"
            if key in seen_presented:
                continue
            seen_presented.add(key)
            presented.append(
                Sample(
                    latency,
                    fields.get("app", "unknown"),
                    fields.get("behaviorProfile", "unknown"),
                    fields.get("requestMode", "unknown"),
                    "diagnostics",
                    line_number,
                    key,
                )
            )
            continue

        if event == "mlx-completion-timing":
            app = fields.get("app", "unknown")
            mode = fields.get("mode", "unknown")
            first = int_value(fields.get("firstChunkMilliseconds"))
            total = int_value(fields.get("totalMilliseconds"))
            if first is not None:
                first_token.append(
                    Sample(first, app, "unknown", mode, "diagnostics", line_number)
                )
            if total is not None:
                total_generation.append(
                    Sample(total, app, "unknown", mode, "diagnostics", line_number)
                )
            continue

        if event == "keyboard-event-tap-latency":
            duration = int_value(fields.get("durationMicros"))
            if duration is None:
                malformed.append(f"{path}:{line_number} keyboard-event-tap-latency missing durationMicros")
                continue
            event_tap.append(
                Sample(
                    duration,
                    "all-apps",
                    "all-profiles",
                    fields.get("decision", "unknown"),
                    "diagnostics",
                    line_number,
                    fields.get("key", "unknown"),
                )
            )
            continue

        if event == "keyboard-event-tap-latency-summary":
            event_tap_windows.append(summary_window(fields, "Micros", "diagnostics", line_number))
            continue

        if event == "keyboard-event-tap-latency-slow":
            event_tap_slow_markers.append(line_number)
            continue

        if event in {
            "keyboard-event-tap-disabled",
            "keyboard-event-tap-start-failed",
            "keyboard-event-tap-failed-closed",
        }:
            event_tap_failures.append(f"{line_number}:{event}:{fields.get('reason', 'unknown')}")
            continue

        if event == "focused-text-poll-latency-summary":
            ax_windows.append(summary_window(fields, "Milliseconds", "diagnostics", line_number))
            continue

        if event == "focused-text-poll-latency-slow":
            ax_slow_markers.append(line_number)
            continue

        if event in {"focused-text-poll-skipped", "focused-text-poll-skip-summary"}:
            ax_skips.append(f"{line_number}:{fields.get('reason', 'unknown')}")

    return {
        "presented": presented,
        "first_token": first_token,
        "total_generation": total_generation,
        "event_tap": event_tap,
        "event_tap_windows": event_tap_windows,
        "event_tap_slow_markers": event_tap_slow_markers,
        "event_tap_failures": event_tap_failures,
        "ax_windows": ax_windows,
        "ax_slow_markers": ax_slow_markers,
        "ax_skips": ax_skips,
        "runtime_launches": runtime_launches,
        "malformed": malformed,
    }


def summary_window(fields, suffix, source, line_number):
    return SummaryWindow(
        count=int_value(fields.get("count")) or 0,
        p50=int_value(fields.get(f"p50{suffix}")),
        p90=int_value(fields.get(f"p90{suffix}")),
        p95=int_value(fields.get(f"p95{suffix}")),
        p99=int_value(fields.get(f"p99{suffix}")),
        maximum=int_value(fields.get(f"max{suffix}")),
        source=source,
        line=line_number,
    )


def grouped(samples):
    groups = defaultdict(list)
    for sample in samples:
        groups[(sample.app, sample.profile)].append(sample)
    return sorted(groups.items(), key=lambda item: (item[0][0], item[0][1]))


def print_grouped(title, samples, unit):
    print(title)
    if not samples:
        print("  no samples")
        return
    for (app, profile), group in grouped(samples):
        print(f"  {app} / {profile}: {metric_line('', group, unit).lstrip(': ')}")


def print_report(args, trace_data, diagnostics_data):
    first_visible = trace_data["first_visible"] or diagnostics_data["presented"]
    first_token = trace_data["first_token"] or diagnostics_data["first_token"]
    total_generation = trace_data["total_generation"] or diagnostics_data["total_generation"]

    print("Latency benchmark report")
    print(f"Diagnostics log: {args.diagnostics_log}")
    print(f"Trace log: {args.trace_log}")
    print(f"Diagnostics start line: {args.diagnostics_start_line}")
    print(f"Trace start line: {args.trace_start_line}")
    print(f"Line limit: {args.line_limit if args.line_limit > 0 else 'all'}")
    print()
    print(metric_line("First visible / keystroke-to-visible", first_visible, "ms"))
    print(metric_line("First token", first_token, "ms"))
    print(metric_line("Total generation", total_generation, "ms"))
    print(runtime_proof_line(diagnostics_data["runtime_launches"]))
    print(metric_line("Event-tap overhead raw", diagnostics_data["event_tap"], "us"))
    print(summary_window_line("Event-tap overhead summaries", diagnostics_data["event_tap_windows"], "us"))
    print(summary_window_line("AX read latency summaries", diagnostics_data["ax_windows"], "ms"))
    print(
        "Stale/late suppression: "
        f"n={len(trace_data['stale_late_suppressed'])} "
        f"lateShown={len(trace_data['late_visible'])} "
        f"eventTapSlowMarkers={len(diagnostics_data['event_tap_slow_markers'])} "
        f"eventTapFailures={len(diagnostics_data['event_tap_failures'])} "
        f"axSlowMarkers={len(diagnostics_data['ax_slow_markers'])} "
        f"axSkips={len(diagnostics_data['ax_skips'])}"
    )
    print()
    print_grouped("First visible by app/profile", first_visible, "ms")
    print_grouped("First token by app/profile", first_token, "ms")
    print_grouped("Total generation by app/profile", total_generation, "ms")

    if trace_data["stale_late_suppressed"]:
        print()
        print("Stale/late suppressed by app/profile")
        buckets = defaultdict(int)
        for suppression in trace_data["stale_late_suppressed"]:
            buckets[(suppression.app, suppression.profile, suppression.reason)] += 1
        for (app, profile, reason), count in sorted(buckets.items()):
            print(f"  {app} / {profile} / {reason}: {count}")


def enforce_gate(args, trace_data, diagnostics_data):
    first_visible = trace_data["first_visible"] or diagnostics_data["presented"]
    first_token = trace_data["first_token"] or diagnostics_data["first_token"]
    total_generation = trace_data["total_generation"] or diagnostics_data["total_generation"]
    failures = []
    failures.extend(trace_data["malformed"])
    failures.extend(diagnostics_data["malformed"])
    enforce_runtime_asset(
        failures,
        diagnostics_data["runtime_launches"],
        args.expected_asset,
    )

    require_count(failures, "first-visible samples", first_visible, args.require_first_visible_samples)
    require_count(failures, "model timing samples", total_generation, args.require_model_samples)
    require_count(failures, "event-tap samples", diagnostics_data["event_tap"], args.require_event_tap_samples)
    require_count(failures, "AX read summary windows", diagnostics_data["ax_windows"], args.require_ax_samples)

    enforce_sample_percentile(failures, "first-visible global p95", first_visible, 0.95, args.max_first_visible_p95_ms, "ms")
    enforce_sample_percentile(failures, "first-visible global p99", first_visible, 0.99, args.max_first_visible_p99_ms, "ms")
    enforce_slice_percentile(
        failures,
        "first-visible app/profile p95",
        first_visible,
        0.95,
        args.max_first_visible_p95_ms,
        "ms",
        args.minimum_slice_samples,
    )
    enforce_slice_percentile(
        failures,
        "first-visible app/profile p99",
        first_visible,
        0.99,
        args.max_first_visible_p99_ms,
        "ms",
        args.minimum_slice_samples,
    )
    enforce_sample_percentile(failures, "first-token global p95", first_token, 0.95, args.max_first_token_p95_ms, "ms")
    enforce_sample_percentile(
        failures,
        "total-generation global p95",
        total_generation,
        0.95,
        args.max_total_generation_p95_ms,
        "ms",
    )
    enforce_sample_percentile(failures, "event-tap raw p95", diagnostics_data["event_tap"], 0.95, args.max_event_tap_p95_us, "us")
    enforce_sample_max(failures, "event-tap raw max", diagnostics_data["event_tap"], args.max_event_tap_max_us, "us")
    enforce_window_max(failures, "event-tap summary p95", diagnostics_data["event_tap_windows"], "p95", args.max_event_tap_p95_us, "us")
    enforce_window_max(failures, "event-tap summary max", diagnostics_data["event_tap_windows"], "maximum", args.max_event_tap_max_us, "us")
    enforce_window_max(failures, "AX summary p95", diagnostics_data["ax_windows"], "p95", args.max_ax_p95_ms, "ms")
    enforce_window_max(failures, "AX summary p99", diagnostics_data["ax_windows"], "p99", args.max_ax_p99_ms, "ms")
    enforce_window_max(failures, "AX summary max", diagnostics_data["ax_windows"], "maximum", args.max_ax_max_ms, "ms")

    for sample in trace_data["late_visible"]:
        failures.append(
            f"late visible suggestion line {sample.line} {sample.app}/{sample.profile} "
            f"{sample.mode} was {sample.value}ms; budget is {args.late_visible_budget_ms}ms"
        )

    if diagnostics_data["event_tap_slow_markers"]:
        failures.append(
            f"event-tap slow markers present at lines {', '.join(map(str, diagnostics_data['event_tap_slow_markers'][:5]))}"
        )

    if diagnostics_data["event_tap_failures"]:
        failures.append(
            "event-tap failure markers present: "
            + "; ".join(diagnostics_data["event_tap_failures"][:5])
        )

    if failures:
        shown = "; ".join(failures[:10])
        extra = len(failures) - 10
        if extra > 0:
            shown = f"{shown}; +{extra} more"
        raise SystemExit(f"latency beta gate failed: {shown}")

    print()
    print("Latency beta gate passed.")


def require_count(failures, label, samples, expected):
    if expected is None or expected <= 0:
        return
    actual = len(samples)
    if actual < expected:
        failures.append(f"expected at least {expected} {label}, found {actual}")


def runtime_proof_line(runtime_launches):
    if not runtime_launches:
        return "Runtime proof: no runtime-bootstrap events"

    latest = runtime_launches[-1]
    default_launches = [launch for launch in runtime_launches if is_default_launch(launch)]
    latest_default = default_launches[-1] if default_launches else None
    expected_asset_launches = [
        launch for launch in runtime_launches
        if launch["asset"] == DEFAULT_EXPECTED_ASSET
    ]
    latest_default_fields = (
        f"latestDefaultAsset={latest_default['asset']} "
        f"defaultCandidate={latest_default['candidate']} "
        f"defaultNativeRuntimeAvailable={latest_default['nativeRuntimeAvailable']} "
        f"latestDefaultLine={latest_default['line']} "
        if latest_default
        else "latestDefaultAsset=none "
    )
    return (
        "Runtime proof: "
        f"latestAsset={latest['asset']} "
        f"candidate={latest['candidate']} "
        f"nativeRuntimeAvailable={latest['nativeRuntimeAvailable']} "
        f"latestOverride={latest['modelOverride'] or 'none'} "
        f"{latest_default_fields}"
        f"defaultAssetLaunches={len(expected_asset_launches)} "
        f"latestLine={latest['line']}"
    )


def is_default_launch(launch):
    return not launch["modelOverride"]


def enforce_runtime_asset(failures, runtime_launches, expected_asset):
    if not expected_asset:
        return
    if not runtime_launches:
        failures.append(f"expected runtime-bootstrap asset {expected_asset}, found no launches")
        return

    default_launches = [launch for launch in runtime_launches if is_default_launch(launch)]
    if not default_launches:
        failures.append(
            f"expected default runtime-bootstrap asset {expected_asset}, found only overridden launches"
        )
        return

    latest = default_launches[-1]
    if latest["asset"] != expected_asset:
        failures.append(
            f"latest default runtime asset {latest['asset']} does not match expected {expected_asset}"
        )


def enforce_sample_percentile(failures, label, samples, fraction, maximum, unit):
    if maximum is None:
        return
    value = percentile([sample.value for sample in samples], fraction)
    if value is None:
        return
    if value > maximum:
        failures.append(f"{label} {value}{unit} exceeds {maximum}{unit}")


def enforce_slice_percentile(failures, label, samples, fraction, maximum, unit, minimum_slice_samples):
    if maximum is None:
        return
    for (app, profile), group in grouped(samples):
        if len(group) < minimum_slice_samples:
            continue
        value = percentile([sample.value for sample in group], fraction)
        if value is not None and value > maximum:
            failures.append(
                f"{label} {app}/{profile} {value}{unit} exceeds {maximum}{unit}"
            )


def enforce_sample_max(failures, label, samples, maximum, unit):
    if maximum is None or not samples:
        return
    value = max(sample.value for sample in samples)
    if value > maximum:
        failures.append(f"{label} {value}{unit} exceeds {maximum}{unit}")


def enforce_window_max(failures, label, windows, attr, maximum, unit):
    if maximum is None:
        return
    values = [getattr(window, attr) for window in windows]
    values = [value for value in values if value is not None]
    if not values:
        return
    value = max(values)
    if value > maximum:
        failures.append(f"{label} {value}{unit} exceeds {maximum}{unit}")


def optional_int_arg(value):
    if value is None:
        return None
    return int(value)


def should_enforce(args):
    if args.beta_gate:
        return True
    return any(
        value is not None
        for value in [
            args.require_first_visible_samples,
            args.require_model_samples,
            args.require_event_tap_samples,
            args.require_ax_samples,
            args.max_first_visible_p95_ms,
            args.max_first_visible_p99_ms,
            args.max_first_token_p95_ms,
            args.max_total_generation_p95_ms,
            args.max_event_tap_p95_us,
            args.max_event_tap_max_us,
            args.max_ax_p95_ms,
            args.max_ax_p99_ms,
            args.max_ax_max_ms,
            args.expected_asset,
        ]
    )


def main():
    parser = argparse.ArgumentParser(
        description="Report and gate Autocomplete Lab latency from diagnostics and redacted trace logs."
    )
    parser.add_argument("--diagnostics-log", default=str(DEFAULT_DIAGNOSTICS_LOG))
    parser.add_argument("--trace-log", default=str(DEFAULT_TRACE_LOG))
    parser.add_argument(
        "--diagnostics-start-line",
        type=int,
        default=0,
        help="ignore diagnostics lines at or before this 1-based line number",
    )
    parser.add_argument(
        "--trace-start-line",
        type=int,
        default=0,
        help="ignore trace lines at or before this 1-based line number",
    )
    parser.add_argument(
        "--line-limit",
        type=int,
        default=DEFAULT_LINE_LIMIT,
        help="use the latest N non-empty lines after the start line; 0 means all",
    )
    parser.add_argument("--beta-gate", action="store_true", help="fail unless private-beta latency budgets pass")
    parser.add_argument("--require-first-visible-samples", type=int)
    parser.add_argument("--require-model-samples", type=int)
    parser.add_argument("--require-event-tap-samples", type=int)
    parser.add_argument("--require-ax-samples", type=int)
    parser.add_argument("--minimum-slice-samples", type=int, default=1)
    parser.add_argument("--late-visible-budget-ms", type=int, default=DEFAULT_LATE_VISIBLE_BUDGET_MS)
    parser.add_argument("--max-first-visible-p95-ms", type=optional_int_arg)
    parser.add_argument("--max-first-visible-p99-ms", type=optional_int_arg)
    parser.add_argument("--max-first-token-p95-ms", type=optional_int_arg)
    parser.add_argument("--max-total-generation-p95-ms", type=optional_int_arg)
    parser.add_argument("--max-event-tap-p95-us", type=optional_int_arg)
    parser.add_argument("--max-event-tap-max-us", type=optional_int_arg)
    parser.add_argument("--max-ax-p95-ms", type=optional_int_arg)
    parser.add_argument("--max-ax-p99-ms", type=optional_int_arg)
    parser.add_argument("--max-ax-max-ms", type=optional_int_arg)
    parser.add_argument(
        "--expected-asset",
        help="fail when the latest runtime-bootstrap asset is different",
    )
    args = parser.parse_args()

    if args.beta_gate:
        args.require_first_visible_samples = (
            args.require_first_visible_samples or BETA_MIN_FIRST_VISIBLE_SAMPLES
        )
        args.require_model_samples = args.require_model_samples or BETA_MIN_MODEL_SAMPLES
        args.require_event_tap_samples = (
            args.require_event_tap_samples or BETA_MIN_EVENT_TAP_SAMPLES
        )
        args.require_ax_samples = args.require_ax_samples or BETA_MIN_AX_SAMPLES
        args.max_first_visible_p95_ms = (
            args.max_first_visible_p95_ms or BETA_MAX_FIRST_VISIBLE_P95_MS
        )
        args.max_first_visible_p99_ms = (
            args.max_first_visible_p99_ms or BETA_MAX_FIRST_VISIBLE_P99_MS
        )
        args.max_first_token_p95_ms = (
            args.max_first_token_p95_ms or BETA_MAX_FIRST_TOKEN_P95_MS
        )
        args.max_total_generation_p95_ms = (
            args.max_total_generation_p95_ms or BETA_MAX_TOTAL_GENERATION_P95_MS
        )
        args.max_event_tap_p95_us = args.max_event_tap_p95_us or BETA_MAX_EVENT_TAP_P95_US
        args.max_event_tap_max_us = args.max_event_tap_max_us or BETA_MAX_EVENT_TAP_MAX_US
        args.max_ax_p95_ms = args.max_ax_p95_ms or BETA_MAX_AX_P95_MS
        args.max_ax_p99_ms = args.max_ax_p99_ms or BETA_MAX_AX_P99_MS
        args.max_ax_max_ms = args.max_ax_max_ms or BETA_MAX_AX_MAX_MS
        args.expected_asset = args.expected_asset or DEFAULT_EXPECTED_ASSET

    diagnostics_path = Path(args.diagnostics_log).expanduser()
    trace_path = Path(args.trace_log).expanduser()
    args.diagnostics_log = str(diagnostics_path)
    args.trace_log = str(trace_path)

    if not diagnostics_path.exists() and not trace_path.exists():
        raise SystemExit(
            f"missing latency inputs: {diagnostics_path} and {trace_path}"
        )

    trace_data = parse_trace_log(
        trace_path,
        max(0, args.trace_start_line),
        max(0, args.line_limit),
        args.late_visible_budget_ms,
    )
    diagnostics_data = parse_diagnostics_log(
        diagnostics_path,
        max(0, args.diagnostics_start_line),
        max(0, args.line_limit),
    )

    print_report(args, trace_data, diagnostics_data)
    if should_enforce(args):
        enforce_gate(args, trace_data, diagnostics_data)


if __name__ == "__main__":
    main()
