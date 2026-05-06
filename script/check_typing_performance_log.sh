#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
START_LINE="${AUTOCOMPLETE_LAB_LOG_START_LINE:-0}"
LINE_LIMIT="${AUTOCOMPLETE_LAB_TYPING_PERF_LOG_LINES:-0}"
MAX_SAMPLE_MICROS="${AUTOCOMPLETE_LAB_EVENT_TAP_MAX_MICROS:-8000}"
MAX_P95_MICROS="${AUTOCOMPLETE_LAB_EVENT_TAP_MAX_P95_MICROS:-8000}"
MAX_POLL_P95_MS="${AUTOCOMPLETE_LAB_FOCUSED_TEXT_POLL_MAX_P95_MS:-80}"
MAX_POLL_SAMPLE_MS="${AUTOCOMPLETE_LAB_FOCUSED_TEXT_POLL_MAX_MS:-120}"
REQUIRE_SAMPLES="${AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES:-0}"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "diagnostics log missing: $LOG_PATH" >&2
  exit 1
fi

python3 - "$LOG_PATH" "$START_LINE" "$LINE_LIMIT" "$MAX_SAMPLE_MICROS" "$MAX_P95_MICROS" "$MAX_POLL_P95_MS" "$MAX_POLL_SAMPLE_MS" "$REQUIRE_SAMPLES" <<'PY'
import sys

path = sys.argv[1]
start_line = int(sys.argv[2] or "0")
line_limit = int(sys.argv[3] or "0")
max_sample_micros = int(sys.argv[4])
max_p95_micros = int(sys.argv[5])
max_poll_p95_ms = int(sys.argv[6])
max_poll_sample_ms = int(sys.argv[7])
required_samples = int(sys.argv[8] or "0")


def fields_from(parts):
    fields = {}
    for part in parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key] = value
    return fields


def int_field(fields, key):
    value = fields.get(key)
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def metric_line(values):
    if not values:
        return "no samples"
    return (
        f"n={len(values)} p50={percentile(values, 0.50)}us "
        f"p95={percentile(values, 0.95)}us "
        f"p99={percentile(values, 0.99)}us max={max(values)}us"
    )


def line_label(item):
    return f"line {item['line']}"


with open(path, "r", encoding="utf-8", errors="ignore") as handle:
    selected = [
        (line_number, line.strip())
        for line_number, line in enumerate(handle, start=1)
        if line_number > start_line and line.strip()
    ]

if line_limit > 0:
    selected = selected[-line_limit:]

raw_samples = []
slow_markers = []
summaries = []
poll_slow_markers = []
poll_summaries = []
disabled_events = []

for line_number, line in selected:
    parts = line.split()
    if len(parts) < 2:
        continue

    event = parts[1]
    fields = fields_from(parts[2:])

    if event == "keyboard-event-tap-latency":
        duration = int_field(fields, "durationMicros")
        if duration is None:
            continue
        raw_samples.append(
            {
                "line": line_number,
                "duration": duration,
                "key": fields.get("key", "unknown"),
                "decision": fields.get("decision", "unknown"),
            }
        )
    elif event == "keyboard-event-tap-latency-slow":
        slow_markers.append(
            {
                "line": line_number,
                "duration": int_field(fields, "durationMicros"),
                "key": fields.get("key", "unknown"),
                "decision": fields.get("decision", "unknown"),
            }
        )
    elif event == "keyboard-event-tap-latency-summary":
        summary = {
            "line": line_number,
            "reason": fields.get("reason", "unknown"),
            "count": int_field(fields, "count") or 0,
            "p50": int_field(fields, "p50Micros"),
            "p95": int_field(fields, "p95Micros"),
            "p99": int_field(fields, "p99Micros"),
            "max": int_field(fields, "maxMicros"),
        }
        summaries.append(summary)
    elif event == "keyboard-event-tap-disabled":
        disabled_events.append(
            {
                "line": line_number,
                "reason": fields.get("reason", "unknown"),
            }
        )
    elif event == "focused-text-poll-latency-slow":
        poll_slow_markers.append(
            {
                "line": line_number,
                "duration": int_field(fields, "durationMilliseconds"),
            }
        )
    elif event == "focused-text-poll-latency-summary":
        poll_summaries.append(
            {
                "line": line_number,
                "count": int_field(fields, "count") or 0,
                "p50": int_field(fields, "p50Milliseconds"),
                "p95": int_field(fields, "p95Milliseconds"),
                "max": int_field(fields, "maxMilliseconds"),
            }
        )

raw_values = [item["duration"] for item in raw_samples]
summary_sample_count = sum(item["count"] for item in summaries)
total_sample_evidence = len(raw_samples) + summary_sample_count

print(f"Typing performance log: {path}")
print(f"Start line: {start_line}")
print(f"Scanned lines: {len(selected)}")
print(f"Raw event tap latency: {metric_line(raw_values)}")
print(
    "Latency summary windows: "
    f"n={len(summaries)} samples={summary_sample_count}"
)
if summaries:
    summary_p95 = [item["p95"] for item in summaries if item["p95"] is not None]
    summary_p99 = [item["p99"] for item in summaries if item["p99"] is not None]
    summary_max = [item["max"] for item in summaries if item["max"] is not None]
    print(f"Summary p95 max: {max(summary_p95) if summary_p95 else 'n/a'}us")
    print(f"Summary p99 max: {max(summary_p99) if summary_p99 else 'n/a'}us")
    print(f"Summary max: {max(summary_max) if summary_max else 'n/a'}us")
print(f"Slow latency markers: {len(slow_markers)}")
print(f"Tap disabled events: {len(disabled_events)}")
print(
    "Focused text poll windows: "
    f"n={len(poll_summaries)} samples={sum(item['count'] for item in poll_summaries)}"
)
if poll_summaries:
    poll_p95 = [item["p95"] for item in poll_summaries if item["p95"] is not None]
    poll_max = [item["max"] for item in poll_summaries if item["max"] is not None]
    print(f"Focused text poll p95 max: {max(poll_p95) if poll_p95 else 'n/a'}ms")
    print(f"Focused text poll max: {max(poll_max) if poll_max else 'n/a'}ms")
print(f"Focused text poll slow markers: {len(poll_slow_markers)}")

failures = []

if required_samples > 0 and total_sample_evidence < required_samples:
    failures.append(
        f"expected at least {required_samples} event tap latency samples, found {total_sample_evidence}"
    )

for item in raw_samples:
    if item["duration"] > max_sample_micros:
        failures.append(
            f"{line_label(item)} raw event tap latency {item['duration']}us exceeds {max_sample_micros}us"
        )

for item in summaries:
    if item["p95"] is not None and item["p95"] > max_p95_micros:
        failures.append(
            f"{line_label(item)} event tap p95 {item['p95']}us exceeds {max_p95_micros}us"
        )
    if item["max"] is not None and item["max"] > max_sample_micros:
        failures.append(
            f"{line_label(item)} event tap max {item['max']}us exceeds {max_sample_micros}us"
        )

for item in slow_markers:
    duration = item["duration"]
    duration_text = "unknown" if duration is None else f"{duration}us"
    failures.append(
        f"{line_label(item)} slow event tap latency marker {duration_text} key={item['key']} decision={item['decision']}"
    )

for item in poll_summaries:
    if item["p95"] is not None and item["p95"] > max_poll_p95_ms:
        failures.append(
            f"{line_label(item)} focused text poll p95 {item['p95']}ms exceeds {max_poll_p95_ms}ms"
        )
    if item["max"] is not None and item["max"] > max_poll_sample_ms:
        failures.append(
            f"{line_label(item)} focused text poll max {item['max']}ms exceeds {max_poll_sample_ms}ms"
        )

for item in poll_slow_markers:
    duration = item["duration"]
    duration_text = "unknown" if duration is None else f"{duration}ms"
    failures.append(
        f"{line_label(item)} slow focused text poll marker {duration_text}"
    )

for item in disabled_events:
    failures.append(
        f"{line_label(item)} event tap disabled reason={item['reason']}"
    )

if failures:
    shown = "; ".join(failures[:8])
    extra = len(failures) - 8
    if extra > 0:
        shown = f"{shown}; +{extra} more"
    raise SystemExit(f"typing performance guardrail failed: {shown}")

print("Typing performance log verified.")
PY
