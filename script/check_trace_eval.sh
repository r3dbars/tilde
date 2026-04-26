#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"

if [[ ! -f "$TRACE_PATH" ]]; then
  echo "trace log missing: $TRACE_PATH" >&2
  exit 1
fi

python3 - "$TRACE_PATH" <<'PY'
import json
import sys
from collections import Counter, defaultdict

path = sys.argv[1]
events = []
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise SystemExit(f"invalid JSONL: {error}") from error

if not events:
    raise SystemExit("trace log is empty")

types = Counter(event.get("type", "") for event in events)
presented = [event for event in events if event.get("type") == "suggestionPresented"]
accepted = [event for event in events if event.get("type") == "suggestionAccepted"]
presented_by_id = {event.get("suggestionID"): event for event in presented if event.get("suggestionID")}
accepted_ids = {event.get("suggestionID") for event in accepted if event.get("suggestionID")}
latencies = sorted(
    event["latencyMilliseconds"]
    for event in events
    if isinstance(event.get("latencyMilliseconds"), int)
)

def percentile(values, fraction):
    if not values:
        return "n/a"
    index = min(len(values) - 1, round((len(values) - 1) * fraction))
    return f"{values[index]}ms"

missing = []
if not presented:
    missing.append("suggestionPresented")
if not latencies:
    missing.append("latencyMilliseconds")

accept_by_mode = defaultdict(lambda: [0, 0])
for event in presented_by_id.values():
    accept_by_mode[event.get("requestMode") or "unknown"][1] += 1
for suggestion_id in accepted_ids:
    event = presented_by_id.get(suggestion_id)
    if event:
        accept_by_mode[event.get("requestMode") or "unknown"][0] += 1

print(f"Trace: {path}")
print(f"Events: {len(events)}")
print(f"Presented: {len(presented)}")
print(f"Accepted keypresses: {len(accepted)}")
print(f"Accepted suggestions: {len(accepted_ids.intersection(presented_by_id.keys()))}")
print(f"Typed over: {types['suggestionTypedOver']}")
print(f"Hidden ignored: {sum(1 for event in events if event.get('type') == 'suggestionHidden' and event.get('outcome') == 'ignored')}")
print(f"Insertion failures: {types['insertionFailed']}")
print(f"p50 latency: {percentile(latencies, 0.50)}")
print(f"p90 latency: {percentile(latencies, 0.90)}")
print("Accept rate by mode:")
for mode, (accepted_count, shown_count) in sorted(accept_by_mode.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {mode}: {rate}% ({accepted_count}/{shown_count})")

if missing:
    raise SystemExit("missing required trace coverage: " + ", ".join(missing))
PY
