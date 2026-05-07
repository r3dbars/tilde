#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
START_LINE="${AUTOCOMPLETE_LAB_TRACE_START_LINE:-0}"
END_LINE="${AUTOCOMPLETE_LAB_TRACE_END_LINE:-}"
REQUIRE_APP="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP:-}"
ENFORCE_PERFORMANCE="${AUTOCOMPLETE_LAB_TRACE_ENFORCE_PERFORMANCE:-0}"
MAX_PHRASE_PRESENTATIONS="${AUTOCOMPLETE_LAB_TRACE_MAX_PHRASE_PRESENTATIONS:-3}"
MAX_WORD_PRESENTATIONS="${AUTOCOMPLETE_LAB_TRACE_MAX_WORD_PRESENTATIONS:-1}"
MAX_PHRASE_VISIBLE_WORDS="${AUTOCOMPLETE_LAB_TRACE_MAX_PHRASE_VISIBLE_WORDS:-5}"
MAX_WORD_VISIBLE_WORDS="${AUTOCOMPLETE_LAB_TRACE_MAX_WORD_VISIBLE_WORDS:-1}"
REQUIRE_CONFIDENT_PLACEMENT="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT:-0}"
REQUIRE_VISUAL_EVIDENCE="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE:-0}"
MIN_USEFUL_RATE="${AUTOCOMPLETE_LAB_TRACE_MIN_USEFUL_RATE:-}"
MAX_REPEATED_UNACCEPTED="${AUTOCOMPLETE_LAB_TRACE_MAX_REPEATED_UNACCEPTED:-}"

if [[ ! -f "$TRACE_PATH" ]]; then
  echo "trace log missing: $TRACE_PATH" >&2
  exit 1
fi

python3 - "$TRACE_PATH" "$START_LINE" "$END_LINE" "$REQUIRE_APP" "$ENFORCE_PERFORMANCE" "$MAX_PHRASE_PRESENTATIONS" "$MAX_WORD_PRESENTATIONS" "$MAX_PHRASE_VISIBLE_WORDS" "$MAX_WORD_VISIBLE_WORDS" "$REQUIRE_CONFIDENT_PLACEMENT" "$REQUIRE_VISUAL_EVIDENCE" "$MIN_USEFUL_RATE" "$MAX_REPEATED_UNACCEPTED" <<'PY'
import json
import os
import sys
from collections import Counter, defaultdict

path = sys.argv[1]
start_line = int(sys.argv[2] or "0")
end_line = int(sys.argv[3]) if sys.argv[3] else None
require_app = sys.argv[4]
enforce_performance = sys.argv[5].lower() in {"1", "true", "yes", "on"}
max_phrase_presentations = int(sys.argv[6])
max_word_presentations = int(sys.argv[7])
max_phrase_visible_words = int(sys.argv[8])
max_word_visible_words = int(sys.argv[9])
require_confident_placement = sys.argv[10].lower() in {"1", "true", "yes", "on"}
require_visual_evidence = sys.argv[11].lower() in {"1", "true", "yes", "on"}
min_useful_rate = int(sys.argv[12]) if sys.argv[12] else None
max_repeated_unaccepted = int(sys.argv[13]) if sys.argv[13] else None
events = []
with open(path, "r", encoding="utf-8") as handle:
    for line_number, line in enumerate(handle, start=1):
        if line_number <= start_line:
            continue
        if end_line is not None and line_number > end_line:
            break
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
insertion_failed = [
    (index, event)
    for index, event in enumerate(events)
    if event.get("type") == "insertionFailed"
]
insertion_verified = [
    (index, event)
    for index, event in enumerate(events)
    if event.get("type") == "insertionVerified"
]
presented_by_id = {}
presentations_by_id = defaultdict(list)
for event in presented:
    suggestion_id = event.get("suggestionID")
    if suggestion_id:
        presentations_by_id[suggestion_id].append(event)
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

performance_failures = []
placement_failures = []
visual_evidence_failures = []
annoyance_failures = []
insertion_failures = []

def event_key(event):
    suggestion_id = event.get("suggestionID")
    if not suggestion_id:
        return None
    return (event.get("appBundleIdentifier") or "unknown", suggestion_id)

def truthy(value):
    return str(value).lower() in {"1", "true", "yes", "recovered"}

def is_recovered_insertion_failure(failed_index, failed_event):
    metadata = failed_event.get("metadata") or {}
    if truthy(failed_event.get("recovered")) or truthy(metadata.get("recovered")):
        return True

    key = event_key(failed_event)
    if not key:
        return False

    return any(
        verified_index > failed_index and event_key(verified_event) == key
        for verified_index, verified_event in insertion_verified
    )

recovered_insertion_failures = [
    event
    for index, event in insertion_failed
    if is_recovered_insertion_failure(index, event)
]
unrecovered_insertion_failures = [
    event
    for index, event in insertion_failed
    if not is_recovered_insertion_failure(index, event)
]

if unrecovered_insertion_failures:
    examples = []
    for event in unrecovered_insertion_failures[:5]:
        app = event.get("appBundleIdentifier") or "unknown"
        suggestion_id = event.get("suggestionID") or "unknown"
        reason = event.get("reason") or event.get("verificationResult") or "unknown"
        examples.append(f"{app}/{suggestion_id} ({reason})")
    extra = len(unrecovered_insertion_failures) - len(examples)
    if extra > 0:
        examples.append(f"{extra} more")
    insertion_failures.append(
        "unrecovered insertion failure: " + ", ".join(examples)
    )

if enforce_performance:
    for suggestion_id, suggestion_events in sorted(presentations_by_id.items()):
        first = suggestion_events[0]
        mode = first.get("requestMode") or "unknown"
        limit = max_word_presentations if mode == "wordCompletion" else max_phrase_presentations
        if len(suggestion_events) > limit:
            performance_failures.append(
                f"{suggestion_id}: {mode} presented {len(suggestion_events)} times (limit {limit})"
            )

    for event in presented:
        metadata = event.get("metadata") or {}
        visible_words = metadata.get("visibleWords")
        if visible_words is None:
            continue
        try:
            visible_words = int(visible_words)
        except (TypeError, ValueError):
            continue

        mode = event.get("requestMode") or "unknown"
        limit = max_word_visible_words if mode == "wordCompletion" else max_phrase_visible_words
        if visible_words > limit:
            performance_failures.append(
                f"{event.get('suggestionID') or 'unknown'}: {mode} showed {visible_words} words (limit {limit})"
            )

placement_bands = Counter()
self_healing_actions = Counter()
placement_health_reasons = Counter()
placement_self_healing_details = Counter()
visual_evidence_count = 0
panel_frame_issue_examples = []
inline_clipping_examples = []
stale_mismatch_examples = []

def metadata_for(event):
    metadata = event.get("metadata") or {}
    return metadata if isinstance(metadata, dict) else {}

def rect_from_text(value):
    if value is None:
        return None
    value = str(value).strip()
    if not value or value == "none":
        return None
    rect = {}
    for part in value.split(","):
        if "=" not in part:
            continue
        key, raw_number = part.split("=", 1)
        try:
            rect[key.strip()] = float(raw_number)
        except ValueError:
            return None
    required = {"x", "y", "w", "h"}
    if not required.issubset(rect):
        return None
    rect["maxX"] = rect["x"] + rect["w"]
    rect["maxY"] = rect["y"] + rect["h"]
    return rect

def effective_render_mode(event):
    metadata = metadata_for(event)
    return (
        metadata.get("placementEffectiveRenderMode")
        or metadata.get("effectiveRenderMode")
        or event.get("requestMode")
        or "unknown"
    )

def placement_health_reason(event):
    metadata = metadata_for(event)
    return metadata.get("placementHealthReason") or event.get("reason") or "unknown"

def append_limited(values, value, limit=5):
    if len(values) < limit:
        values.append(value)

def inline_clipping_summary(event):
    metadata = metadata_for(event)
    if effective_render_mode(event) != "inlineAdjacent":
        return None

    panel_rect = rect_from_text(metadata.get("suggestionPanelRect"))
    clipping_rect = rect_from_text(metadata.get("clippingRect"))
    if not panel_rect or not clipping_rect:
        return None

    try:
        visible_chars = int(metadata.get("visibleChars") or 0)
    except (TypeError, ValueError):
        visible_chars = 0
    minimum_width = min(72, max(24, visible_chars * 3))
    clipped_edges = []
    if panel_rect["x"] <= clipping_rect["x"] + 1:
        clipped_edges.append("left")
    if panel_rect["maxX"] >= clipping_rect["maxX"] - 1:
        clipped_edges.append("right")
    if panel_rect["y"] <= clipping_rect["y"] + 1:
        clipped_edges.append("top")
    if panel_rect["maxY"] >= clipping_rect["maxY"] - 1:
        clipped_edges.append("bottom")

    if panel_rect["w"] >= minimum_width and not clipped_edges:
        return None

    suggestion_id = event.get("suggestionID") or "unknown"
    app = event.get("appBundleIdentifier") or "unknown"
    reason_parts = []
    if panel_rect["w"] < minimum_width:
        reason_parts.append(f"narrow {int(panel_rect['w'])}px")
    if clipped_edges:
        reason_parts.append("edge " + "/".join(clipped_edges))
    return (
        f"{app}/{suggestion_id}: "
        + ", ".join(reason_parts)
        + f" panel={metadata.get('suggestionPanelRect')} clipping={metadata.get('clippingRect')}"
    )

def screenshot_path_issue(event):
    raw_path = event.get("screenshotPath")
    if raw_path is None or str(raw_path).strip() == "":
        return "missing screenshotPath"

    screenshot_path = os.path.expanduser(os.path.expandvars(str(raw_path).strip()))
    if not os.path.isfile(screenshot_path):
        return f"screenshotPath file missing: {screenshot_path}"
    try:
        if os.path.getsize(screenshot_path) <= 0:
            return f"screenshotPath file empty: {screenshot_path}"
    except OSError as error:
        return f"screenshotPath file unreadable: {screenshot_path} ({error})"

    return None

def visual_evidence_issues(event):
    metadata = event.get("metadata") or {}
    issues = []

    screenshot_issue = screenshot_path_issue(event)
    if screenshot_issue:
        issues.append(screenshot_issue)

    missing_geometry = []
    for key in ("anchorRect", "suggestionPanelRect", "screenshotCaptureRect"):
        value = metadata.get(key)
        if value is None or str(value).strip() in {"", "none"}:
            missing_geometry.append(key)

    if missing_geometry:
        issues.append("missing geometry: " + ", ".join(missing_geometry))

    value = metadata.get("placementConfidenceBand")
    if value is None or str(value).strip() in {"", "none"}:
        issues.append("missing placementConfidenceBand")

    return issues

for event in presented:
    metadata = metadata_for(event)
    band = metadata.get("placementConfidenceBand")
    action = metadata.get("placementSelfHealingAction")
    health_reason = metadata.get("placementHealthReason")

    if band:
        placement_bands[band] += 1
    if action:
        self_healing_actions[action] += 1
    if health_reason:
        placement_health_reasons[health_reason] += 1
    if action and action != "none":
        placement_self_healing_details[
            (
                f"{action} reason={health_reason or 'unknown'} "
                f"{metadata.get('placementRequestedRenderMode') or 'unknown'}"
                f"->{effective_render_mode(event)} "
                f"anchor={metadata.get('placementAnchorSource') or 'unknown'}"
            )
        ] += 1

    clipping_summary = inline_clipping_summary(event)
    if clipping_summary:
        append_limited(inline_clipping_examples, clipping_summary)

    if require_confident_placement:
        suggestion_id = event.get("suggestionID") or "unknown"
        if not band:
            placement_failures.append(f"{suggestion_id}: missing placementConfidenceBand")
        elif band not in {"high", "medium"}:
            score = metadata.get("placementConfidenceScore") or "unknown"
            placement_failures.append(
                f"{suggestion_id}: placement confidence {band} ({score})"
            )

if require_visual_evidence:
    for suggestion_id, suggestion_events in sorted(presentations_by_id.items()):
        issues_by_event = [
            visual_evidence_issues(event)
            for event in suggestion_events
        ]
        if any(not issues for issues in issues_by_event):
            visual_evidence_count += 1
            continue

        best_issues = min(issues_by_event, key=len)
        visual_evidence_failures.append(
            f"{suggestion_id}: " + "; ".join(best_issues)
        )

for event in events:
    metadata = metadata_for(event)
    event_type = event.get("type")
    reason = event.get("reason") or ""
    health_reason = metadata.get("placementHealthReason")

    if health_reason and event_type != "suggestionPresented":
        placement_health_reasons[health_reason] += 1

    action = metadata.get("placementSelfHealingAction")
    if action and action != "none" and event_type != "suggestionPresented":
        placement_self_healing_details[
            (
                f"{action} reason={health_reason or reason or 'unknown'} "
                f"{metadata.get('placementRequestedRenderMode') or 'unknown'}"
                f"->{effective_render_mode(event)} "
                f"anchor={metadata.get('placementAnchorSource') or 'unknown'}"
            )
        ] += 1

    if event_type in {"suggestionSuppressed", "suggestionHidden"} and reason == "panel-frame-unusable":
        append_limited(
            panel_frame_issue_examples,
            (
                f"{event.get('appBundleIdentifier') or 'unknown'}/"
                f"{event.get('suggestionID') or 'unknown'} "
                f"{event_type} mode={effective_render_mode(event)}"
            )
        )

    if event_type == "suggestionHidden" and (
        reason in {"focus-changed", "stale-after-keydown", "panel-frame-unusable"}
        or reason.startswith("placement-")
    ):
        append_limited(
            stale_mismatch_examples,
            (
                f"{event.get('appBundleIdentifier') or 'unknown'}/"
                f"{event.get('suggestionID') or 'unknown'} ({reason or 'unknown'})"
            )
        )

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
if end_line is not None:
    print(f"End line: {end_line}")
print(f"Events: {len(events)}")
print(f"Presented: {len(presented_by_id)}")
print(f"Accepted keypresses: {len(accepted)}")
print(f"Accepted suggestions: {len(accepted_ids.intersection(presented_by_id.keys()))}")
print(f"Typed through: {len(typed_through_ids.intersection(presented_ids))}")
print(f"Typed over: {types['suggestionTypedOver']}")
print(f"Hidden ignored: {sum(1 for event in events if event.get('type') == 'suggestionHidden' and event.get('outcome') == 'ignored')}")
print(f"Suppressed: {types['suggestionSuppressed']}")
print(f"Actionable suppressed: {sum(1 for event in events if event.get('type') == 'suggestionSuppressed' and event.get('reason') != 'no-fast-word-candidate')}")
print(f"Insertion failures: {types['insertionFailed']}")
print(f"Recovered insertion failures: {len(recovered_insertion_failures)}")
print(f"Unrecovered insertion failures: {len(unrecovered_insertion_failures)}")
accept_rate = 0 if not presented_ids else round((len(accepted_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
useful_rate = 0 if not presented_ids else round((len(useful_suggestion_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
if min_useful_rate is not None and useful_rate < min_useful_rate:
    annoyance_failures.append(
        f"useful rate {useful_rate}% is below required {min_useful_rate}%"
    )
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
actionable_suppressed_events = [
    event for event in suppressed_events
    if event.get("reason") != "no-fast-word-candidate"
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
print("Actionable suppressed by app:")
actionable_suppressed_apps = Counter(event.get("appBundleIdentifier") or "unknown" for event in actionable_suppressed_events)
if actionable_suppressed_apps:
    for app, count in actionable_suppressed_apps.most_common():
        print(f"  {app}: {count}")
else:
    print("  none")
print("Actionable suppressed by mode:")
actionable_suppressed_modes = Counter(event.get("requestMode") or "unknown" for event in actionable_suppressed_events)
if actionable_suppressed_modes:
    for mode, count in actionable_suppressed_modes.most_common():
        print(f"  {mode}: {count}")
else:
    print("  none")
print("Hidden by reason:")
hidden_reasons = Counter(
    event.get("reason") or "unknown"
    for event in events
    if event.get("type") == "suggestionHidden"
)
if hidden_reasons:
    for reason, count in hidden_reasons.most_common():
        print(f"  {reason}: {count}")
else:
    print("  none")
print("Top repeated unaccepted suggestions:")
if repeated_unaccepted:
    for count, mode, displayed, top_app, top_app_count, suggestion_id in repeated_unaccepted[:5]:
        print(f"  {count}x {mode}: {displayed} | app {top_app} {top_app_count}/{count} (example {suggestion_id})")
        if max_repeated_unaccepted is not None and count > max_repeated_unaccepted:
            annoyance_failures.append(
                f"{count}x repeated unaccepted {mode} suggestion exceeds limit {max_repeated_unaccepted}: {displayed} (example {suggestion_id})"
            )
else:
    print("  none")
print("Placement confidence by band:")
if placement_bands:
    for band, count in placement_bands.most_common():
        print(f"  {band}: {count}")
else:
    print("  none")
print("Placement self-healing actions:")
if self_healing_actions:
    for action, count in self_healing_actions.most_common():
        print(f"  {action}: {count}")
else:
    print("  none")
print("Placement health reasons:")
if placement_health_reasons:
    for reason, count in placement_health_reasons.most_common():
        print(f"  {reason}: {count}")
else:
    print("  none")
print("Placement self-healing detail:")
if placement_self_healing_details:
    for detail, count in placement_self_healing_details.most_common():
        print(f"  {detail}: {count}")
else:
    print("  none")
print("Panel frame issues:")
if panel_frame_issue_examples:
    for example in panel_frame_issue_examples:
        print(f"  {example}")
else:
    print("  none")
print("Inline clipping evidence:")
if inline_clipping_examples:
    for example in inline_clipping_examples:
        print(f"  {example}")
else:
    print("  none")
print("Stale or mismatch hidden reasons:")
if stale_mismatch_examples:
    for example in stale_mismatch_examples:
        print(f"  {example}")
else:
    print("  none")
if require_visual_evidence:
    print(f"Visual evidence complete: {visual_evidence_count}/{len(presentations_by_id)}")

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
    app_unrecovered_failed = [
        event for event in app_failed
        if event in unrecovered_insertion_failures
    ]

    if not app_presented:
        missing.append(f"{require_app}: suggestionPresented")
    if not app_accepted_ids.intersection(app_presented_ids):
        missing.append(f"{require_app}: accepted suggestion")
    if not app_verified:
        missing.append(f"{require_app}: insertionVerified")
    if app_unrecovered_failed:
        missing.append(f"{require_app}: no unrecovered insertionFailed")

if missing:
    raise SystemExit("missing required trace coverage: " + ", ".join(missing))
if insertion_failures:
    raise SystemExit("insertion recovery guardrail failed: " + "; ".join(insertion_failures))
if performance_failures:
    raise SystemExit("typing performance guardrail failed: " + "; ".join(performance_failures))
if placement_failures:
    raise SystemExit("placement confidence guardrail failed: " + "; ".join(placement_failures))
if visual_evidence_failures:
    raise SystemExit("visual evidence guardrail failed: " + "; ".join(visual_evidence_failures))
if annoyance_failures:
    raise SystemExit("suggestion annoyance guardrail failed: " + "; ".join(annoyance_failures))
PY
