#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
START_LINE="${AUTOCOMPLETE_LAB_TRACE_START_LINE:-0}"
REQUIRE_APP="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP:-}"

if [[ ! -f "$TRACE_PATH" ]]; then
  echo "trace log missing: $TRACE_PATH" >&2
  exit 1
fi

python3 - "$TRACE_PATH" "$START_LINE" "$REQUIRE_APP" <<'PY'
import json
import sys
from collections import Counter, defaultdict

path = sys.argv[1]
start_line = int(sys.argv[2] or "0")
require_app = sys.argv[3]
events = []
with open(path, "r", encoding="utf-8") as handle:
    for line_number, line in enumerate(handle, start=1):
        if line_number <= start_line:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise SystemExit(f"invalid JSONL: {error}") from error

if not events:
    raise SystemExit("trace slice is empty")

types = Counter(event.get("type", "") for event in events)
presented = [event for event in events if event.get("type") == "suggestionPresented"]
accepted = [event for event in events if event.get("type") == "suggestionAccepted"]
presented_by_id = {}
for event in presented:
    suggestion_id = event.get("suggestionID")
    if suggestion_id and suggestion_id not in presented_by_id:
        presented_by_id[suggestion_id] = event
accepted_ids = {event.get("suggestionID") for event in accepted if event.get("suggestionID")}
typed_through_ids = {
    event.get("suggestionID")
    for event in events
    if event.get("type") == "suggestionHidden"
    and event.get("outcome") == "typed-through"
    and event.get("suggestionID")
}
useful_suggestion_ids = accepted_ids.union(typed_through_ids)
presented_ids = set(presented_by_id.keys())
latencies = sorted(
    event["latencyMilliseconds"]
    for event in presented_by_id.values()
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
accept_by_app = defaultdict(lambda: [0, 0])
useful_by_mode = defaultdict(lambda: [0, 0])
useful_by_app = defaultdict(lambda: [0, 0])
for event in presented_by_id.values():
    accept_by_mode[event.get("requestMode") or "unknown"][1] += 1
    accept_by_app[event.get("appBundleIdentifier") or "unknown"][1] += 1
    useful_by_mode[event.get("requestMode") or "unknown"][1] += 1
    useful_by_app[event.get("appBundleIdentifier") or "unknown"][1] += 1
for suggestion_id in accepted_ids:
    event = presented_by_id.get(suggestion_id)
    if event:
        accept_by_mode[event.get("requestMode") or "unknown"][0] += 1
        accept_by_app[event.get("appBundleIdentifier") or "unknown"][0] += 1
for suggestion_id in useful_suggestion_ids:
    event = presented_by_id.get(suggestion_id)
    if event:
        useful_by_mode[event.get("requestMode") or "unknown"][0] += 1
        useful_by_app[event.get("appBundleIdentifier") or "unknown"][0] += 1

def normalized_suggestion(text):
    return " ".join((text or "").lower().split()).strip()

repeated_unaccepted = []
presented_by_signature = defaultdict(list)
for suggestion_id, event in presented_by_id.items():
    displayed = normalized_suggestion(event.get("displayedText") or event.get("cleanedVisibleText") or "")
    if not displayed:
        continue
    signature = (event.get("requestMode") or "unknown", displayed)
    presented_by_signature[signature].append(event)
for (mode, displayed), signature_events in presented_by_signature.items():
    unaccepted = [
        event for event in signature_events
        if event.get("suggestionID") not in useful_suggestion_ids
    ]
    if len(unaccepted) >= 3:
        app_counts = Counter(event.get("appBundleIdentifier") or "unknown" for event in unaccepted)
        top_app, top_app_count = app_counts.most_common(1)[0]
        repeated_unaccepted.append((
            len(unaccepted),
            mode,
            displayed,
            top_app,
            top_app_count,
            unaccepted[0].get("suggestionID") or "unknown"
        ))
repeated_unaccepted.sort(key=lambda item: (-item[0], item[1], item[2]))

print(f"Trace: {path}")
print(f"Start line: {start_line}")
print(f"Events: {len(events)}")
print(f"Presented: {len(presented_by_id)}")
print(f"Accepted keypresses: {len(accepted)}")
print(f"Accepted suggestions: {len(accepted_ids.intersection(presented_by_id.keys()))}")
print(f"Typed through: {len(typed_through_ids.intersection(presented_ids))}")
print(f"Typed over: {types['suggestionTypedOver']}")
print(f"Hidden ignored: {sum(1 for event in events if event.get('type') == 'suggestionHidden' and event.get('outcome') == 'ignored')}")
print(f"Suppressed: {types['suggestionSuppressed']}")
print(f"Insertion failures: {types['insertionFailed']}")
accept_rate = 0 if not presented_ids else round((len(accepted_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
useful_rate = 0 if not presented_ids else round((len(useful_suggestion_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
print(f"Accept rate: {accept_rate}%")
print(f"Useful rate: {useful_rate}%")
print(f"p50 latency: {percentile(latencies, 0.50)}")
print(f"p90 latency: {percentile(latencies, 0.90)}")
print("Accept rate by mode:")
for mode, (accepted_count, shown_count) in sorted(accept_by_mode.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {mode}: {rate}% ({accepted_count}/{shown_count})")
print("Accept rate by app:")
for app, (accepted_count, shown_count) in sorted(accept_by_app.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {app}: {rate}% ({accepted_count}/{shown_count})")
print("Useful rate by mode:")
for mode, (useful_count, shown_count) in sorted(useful_by_mode.items()):
    rate = 0 if shown_count == 0 else round((useful_count / shown_count) * 100)
    print(f"  {mode}: {rate}% ({useful_count}/{shown_count})")
print("Useful rate by app:")
for app, (useful_count, shown_count) in sorted(useful_by_app.items()):
    rate = 0 if shown_count == 0 else round((useful_count / shown_count) * 100)
    print(f"  {app}: {rate}% ({useful_count}/{shown_count})")
print("Suppressed by reason:")
suppressed_events = [
    event for event in events
    if event.get("type") == "suggestionSuppressed"
]
suppressed_reasons = Counter(
    event.get("reason") or "unknown"
    for event in suppressed_events
)
if suppressed_reasons:
    for reason, count in suppressed_reasons.most_common():
        print(f"  {reason}: {count}")
else:
    print("  none")
print("Suppressed by app:")
suppressed_apps = Counter(event.get("appBundleIdentifier") or "unknown" for event in suppressed_events)
if suppressed_apps:
    for app, count in suppressed_apps.most_common():
        print(f"  {app}: {count}")
else:
    print("  none")
print("Suppressed by mode:")
suppressed_modes = Counter(event.get("requestMode") or "unknown" for event in suppressed_events)
if suppressed_modes:
    for mode, count in suppressed_modes.most_common():
        print(f"  {mode}: {count}")
else:
    print("  none")
print("Top repeated unaccepted suggestions:")
if repeated_unaccepted:
    for count, mode, displayed, top_app, top_app_count, suggestion_id in repeated_unaccepted[:5]:
        print(f"  {count}x {mode}: {displayed} | app {top_app} {top_app_count}/{count} (example {suggestion_id})")
else:
    print("  none")

if require_app:
    app_events = [event for event in events if event.get("appBundleIdentifier") == require_app]
    app_presented = [event for event in presented if event.get("appBundleIdentifier") == require_app]
    app_accepted_ids = {
        event.get("suggestionID")
        for event in accepted
        if event.get("appBundleIdentifier") == require_app and event.get("suggestionID")
    }
    app_presented_ids = {
        event.get("suggestionID")
        for event in app_presented
        if event.get("suggestionID")
    }
    app_verified = [
        event for event in app_events
        if event.get("type") == "insertionVerified"
    ]
    app_failed = [
        event for event in app_events
        if event.get("type") == "insertionFailed"
    ]

    if not app_presented:
        missing.append(f"{require_app}: suggestionPresented")
    if not app_accepted_ids.intersection(app_presented_ids):
        missing.append(f"{require_app}: accepted suggestion")
    if not app_verified:
        missing.append(f"{require_app}: insertionVerified")
    if app_failed:
        missing.append(f"{require_app}: no insertionFailed")

if missing:
    raise SystemExit("missing required trace coverage: " + ", ".join(missing))
PY
