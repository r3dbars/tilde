#!/usr/bin/env bash
set -euo pipefail

TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
START_LINE="${AUTOCOMPLETE_LAB_TRACE_START_LINE:-0}"
REQUIRE_APP="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP:-}"
REQUIRE_EXPERIMENT_ARM="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_EXPERIMENT_ARM:-}"
REQUIRE_SUPPORT_STATE="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_SUPPORT_STATE:-}"

if [[ ! -f "$TRACE_PATH" ]]; then
  echo "trace log missing: $TRACE_PATH" >&2
  exit 1
fi

python3 - "$TRACE_PATH" "$START_LINE" "$REQUIRE_APP" "$REQUIRE_EXPERIMENT_ARM" "$REQUIRE_SUPPORT_STATE" <<'PY'
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

path = sys.argv[1]
start_line = int(sys.argv[2] or "0")
require_app = sys.argv[3]
require_experiment_arm = sys.argv[4]
require_support_state = sys.argv[5]
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
accepted_event_ids = {
    event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
    for event in accepted
    if event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
}
accepted_text_edited = [event for event in events if event.get("type") == "acceptedTextEdited"]

def kept_event(event):
    metadata = event.get("metadata") or {}
    if metadata.get("strongAcceptedAndKept") == "true" or metadata.get("finalAcceptedAndKept") == "true":
        return True
    if metadata.get("checkpoint") not in {"10s", "30s", "fieldBlur", "fieldSend"}:
        return False
    return metadata.get("survivalClass") in {"exactKept", "lightlyEditedKept", "partiallyKept"}

accepted_and_kept_event_ids = {
    event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
    for event in accepted_text_edited
    if kept_event(event) and (event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID"))
}
accepted_and_kept_suggestion_ids = {
    event.get("suggestionID")
    for event in accepted_text_edited
    if kept_event(event) and event.get("suggestionID")
}

def field_kind(event):
    metadata = event.get("metadata") or {}
    return metadata.get("fieldKind") or "unknown"

def experiment_arm(event):
    metadata = event.get("metadata") or {}
    return event.get("experimentArm") or metadata.get("experimentArm") or "unknown"

def render_mode(event):
    metadata = event.get("metadata") or {}
    return metadata.get("effectiveRenderMode") or metadata.get("renderMode") or "unknown"

presented_field_kinds = Counter(field_kind(event) for event in presented_by_id.values())
accepted_and_kept_field_kinds = Counter(
    field_kind(event)
    for event in accepted_text_edited
    if kept_event(event)
)
presented_experiment_arms = Counter(experiment_arm(event) for event in presented_by_id.values())
accepted_and_kept_experiment_arms = Counter(
    experiment_arm(event)
    for event in accepted_text_edited
    if kept_event(event)
)
suppressed_field_kinds = Counter(
    field_kind(event)
    for event in events
    if event.get("type") == "suggestionSuppressed"
)
suppressed_experiment_arms = Counter(
    experiment_arm(event)
    for event in events
    if event.get("type") == "suggestionSuppressed"
)
caret_geometry_failures = [
    event for event in events
    if event.get("type") == "caretGeometryFailed"
]
caret_failures_by_app = Counter(event.get("appBundleIdentifier") or "unknown" for event in caret_geometry_failures)
caret_failures_by_render_mode = Counter(render_mode(event) for event in caret_geometry_failures)
typed_through_ids = {
    event.get("suggestionID")
    for event in events
    if event.get("type") == "suggestionHidden"
    and event.get("outcome") == "typed-through"
    and event.get("suggestionID")
}
useful_suggestion_ids = accepted_ids.union(typed_through_ids)
presented_ids = set(presented_by_id.keys())

def metadata_int(event, key):
    try:
        return int((event.get("metadata") or {}).get(key))
    except (TypeError, ValueError):
        return None

def model_total_generation_latency(event):
    if isinstance(event.get("latencyMilliseconds"), int):
        return event["latencyMilliseconds"]
    return (
        metadata_int(event, "totalGenerationLatencyMilliseconds")
        or metadata_int(event, "modelTotalLatencyMilliseconds")
    )

def empty_model_result(event):
    metadata = event.get("metadata") or {}
    word_count = metadata_int(event, "cleanedWordCount")
    if word_count is not None:
        return word_count == 0
    char_count = metadata_int(event, "cleanedVisibleTextChars")
    if char_count is not None:
        return char_count == 0
    cleaned = (event.get("cleanedVisibleText") or "").strip()
    raw = (event.get("rawOutput") or "").strip()
    if not cleaned and not raw:
        return False
    return not cleaned

latencies = sorted(
    event["latencyMilliseconds"]
    for event in presented_by_id.values()
    if isinstance(event.get("latencyMilliseconds"), int)
)
model_result_latencies = sorted(
    latency
    for event in events
    if event.get("type") == "modelResult"
    for latency in [model_total_generation_latency(event)]
    if latency is not None
)
first_token_latencies = sorted(
    latency
    for event in events
    if event.get("type") == "modelResult"
    for latency in [metadata_int(event, "firstTokenLatencyMilliseconds")]
    if latency is not None
)
empty_model_results = [
    event for event in events
    if event.get("type") == "modelResult" and empty_model_result(event)
]
pre_render_blocked = [
    event for event in events
    if event.get("type") == "suggestionSuppressed"
    and event.get("suggestionID") not in presented_by_id
]

def percentile(values, fraction):
    if not values:
        return "n/a"
    index = min(len(values) - 1, round((len(values) - 1) * fraction))
    return f"{values[index]}ms"

def percentile_int(values, fraction):
    if not values:
        return None
    index = min(len(values) - 1, round((len(values) - 1) * fraction))
    return values[index]

def latency_buckets(values):
    labels = ["0-50ms", "51-100ms", "101-250ms", "251-500ms", "501-1000ms", ">1000ms"]
    buckets = Counter()
    for value in values:
        if value <= 50:
            buckets[labels[0]] += 1
        elif value <= 100:
            buckets[labels[1]] += 1
        elif value <= 250:
            buckets[labels[2]] += 1
        elif value <= 500:
            buckets[labels[3]] += 1
        elif value <= 1000:
            buckets[labels[4]] += 1
        else:
            buckets[labels[5]] += 1
    return [(label, buckets[label]) for label in labels if buckets[label]]

def parse_date(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None

def safe_int(value, default=999999999):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default

def accepted_then_deleted(event):
    metadata = event.get("metadata") or {}
    return (
        event.get("type") == "acceptedTextEdited"
        and metadata.get("survivalClass") == "rejectedAfterAccept"
        and (
            safe_int(metadata.get("firstEditDelayMs")) <= 2000
            or metadata.get("checkpoint") == "2s"
        )
    )

def tab_conflict(event):
    metadata = event.get("metadata") or {}
    return (
        event.get("reason") == "tab-conflict"
        or event.get("outcome") == "tab-conflict"
        or metadata.get("tabConflict") == "true"
    )

def focus_stealing(event):
    metadata = event.get("metadata") or {}
    return (
        "focus-steal" in (event.get("reason") or "").lower()
        or "focus-steal" in (event.get("outcome") or "").lower()
        or metadata.get("focusStealing") == "true"
    )

def overlay_flicker(event):
    metadata = event.get("metadata") or {}
    return (
        event.get("type") == "suggestionHidden"
        and safe_int(metadata.get("lifetimeMs")) < 150
    )

def severe_failure(event):
    metadata = event.get("metadata") or {}
    return (
        event.get("type") in {"insertionFailed", "appDisabled"}
        or (event.get("type") == "caretGeometryFailed" and metadata.get("severe") == "true")
        or metadata.get("focusStealing") == "true"
        or metadata.get("tabConflict") == "true"
    )

state_rank = {
    "blocked": 0,
    "experimental": 1,
    "caveated": 2,
    "supported": 3,
}

profiles = {
    "com.apple.TextEdit": {"display": "TextEdit", "can_present": True, "sensitive": False},
    "com.apple.Notes": {"display": "Notes", "can_present": True, "sensitive": False},
    "md.obsidian": {"display": "Obsidian", "can_present": True, "sensitive": False},
    "com.apple.mail": {"display": "Mail", "can_present": False, "sensitive": True},
    "com.google.Chrome": {"display": "Chrome", "can_present": True, "sensitive": False},
    "com.openai.codex": {"display": "Codex", "can_present": True, "sensitive": False},
}
denylist = {
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "com.apple.keychainaccess",
    "com.1password.1password",
    "com.agilebits.onepassword7",
}

def is_duplicate(event):
    metadata = event.get("metadata") or {}
    return (
        metadata.get("duplicateDetected") == "true"
        or "duplicate" in (event.get("reason") or "").lower()
        or "duplicate" in (event.get("outcome") or "").lower()
    )

def has_text_signal(event, *needles):
    haystack = " ".join([
        event.get("reason") or "",
        event.get("outcome") or "",
        " ".join(f"{key}={value}" for key, value in (event.get("metadata") or {}).items()),
    ]).lower()
    return any(needle in haystack for needle in needles)

def app_family(app):
    if app in {"com.apple.TextEdit", "com.apple.Notes"}:
        return "nativeText"
    if app == "com.google.Chrome":
        return "browserTextarea"
    if app in {"md.obsidian", "com.openai.codex"}:
        return "electronEditor"
    if app == "com.apple.mail":
        return "richTextCompose"
    return "unknown"

def minimum_sample_size(family):
    return {
        "nativeText": 20,
        "browserTextarea": 15,
        "electronEditor": 15,
        "richTextCompose": 20,
    }.get(family, 10)

def support_evaluation(app):
    app_events = [event for event in events if event.get("appBundleIdentifier") == app]
    app_presented_by_id = {}
    for event in app_events:
        if event.get("type") != "suggestionPresented":
            continue
        suggestion_id = event.get("suggestionID")
        if suggestion_id and suggestion_id not in app_presented_by_id:
            app_presented_by_id[suggestion_id] = event
    app_presented = list(app_presented_by_id.values())
    app_presented_ids = set(app_presented_by_id.keys())
    app_kept_ids = {
        event.get("suggestionID")
        for event in app_events
        if event.get("type") == "acceptedTextEdited"
        and kept_event(event)
        and event.get("suggestionID")
    }.intersection(app_presented_ids)
    verified = sum(1 for event in app_events if event.get("type") == "insertionVerified")
    failures = [event for event in app_events if event.get("type") == "insertionFailed"]
    attempts = verified + len(failures)
    insertion_success = 0 if attempts == 0 else verified / attempts
    caret_failures = sum(1 for event in app_events if event.get("type") == "caretGeometryFailed")
    caret_failure_rate = caret_failures / max(1, len(app_presented) + caret_failures)
    duplicate_count = sum(1 for event in failures if is_duplicate(event))
    wrong_insertion_count = sum(1 for event in failures if not is_duplicate(event))
    tab_conflict_count = sum(1 for event in app_events if has_text_signal(event, "tab-conflict", "tab conflict"))
    focus_steal_count = sum(1 for event in app_events if has_text_signal(event, "focus-steal", "focus steal", "focusstealing=true"))
    sensitive_field_shown_count = sum(
        1 for event in app_presented
        if field_kind(event) in {"search", "form", "url", "secure"}
    )
    detached_whole_anchor_count = sum(
        1 for event in app_presented
        if (event.get("metadata") or {}).get("effectiveRenderMode") == "floatingMirror"
        and (event.get("metadata") or {}).get("hasCaretRect") == "false"
    )
    app_disable_count = sum(1 for event in app_events if event.get("type") == "appDisabled")
    app_actionable_suppressed = [
        event for event in app_events
        if event.get("type") == "suggestionSuppressed"
        and event.get("reason") != "no-fast-word-candidate"
    ]
    actionable_suppressed_rate = (
        1 if app_actionable_suppressed and not app_presented
        else len(app_actionable_suppressed) / max(1, len(app_presented) + len(app_actionable_suppressed))
    )
    app_latencies = sorted(
        event.get("latencyMilliseconds")
        for event in app_presented
        if isinstance(event.get("latencyMilliseconds"), int)
    )
    app_p95 = percentile_int(app_latencies, 0.95)
    kept_rate = 0 if not app_presented_ids else len(app_kept_ids) / len(app_presented_ids)
    family = app_family(app)
    min_sample = minimum_sample_size(family)
    annoyance_signal_count = (
        duplicate_count
        + wrong_insertion_count
        + tab_conflict_count
        + focus_steal_count
        + sensitive_field_shown_count
        + app_disable_count
        + sum(1 for event in app_events if event.get("type") == "suggestionTypedOver")
        + sum(1 for event in app_events if event.get("type") == "acceptedTextEdited" and (event.get("metadata") or {}).get("survivalClass") == "rejectedAfterAccept")
    )
    annoyance_score = min(1, annoyance_signal_count / max(1, len(app_presented)))

    reasons = []
    profile = profiles.get(app)
    if app in denylist:
        reasons.append("denylisted")
    elif not profile:
        reasons.append("no MVP compatibility profile")
    else:
        if profile["sensitive"]:
            reasons.append("sensitive diagnostics-only app")
        if not profile["can_present"]:
            reasons.append("cannot present suggestions safely yet")
    if duplicate_count:
        reasons.append("duplicate insertion")
    if wrong_insertion_count:
        reasons.append("wrong insertion")
    if tab_conflict_count:
        reasons.append("Tab conflict")
    if focus_steal_count:
        reasons.append("focus steal")
    if sensitive_field_shown_count:
        reasons.append("sensitive field shown")
    if detached_whole_anchor_count:
        reasons.append("detached whole-anchor suggestion shown")
    if app_disable_count:
        reasons.append("app disabled")
    if attempts >= 3 and insertion_success < 0.90:
        reasons.append("insertion success below 90%")
    if caret_failure_rate > 0.10:
        reasons.append("caret failure above 10%")
    if app_p95 is not None and len(app_presented) >= 5 and app_p95 > 1500:
        reasons.append("p95 latency above 1500ms")
    if annoyance_score > 0.35:
        reasons.append("annoyance above 0.35")

    if reasons:
        state = "blocked"
    elif (
        len(app_presented) >= min_sample
        and kept_rate >= 0.15
        and len(app_kept_ids) >= 3
        and insertion_success >= 0.98
        and app_p95 is not None
        and app_p95 <= 750
        and caret_failure_rate == 0
        and actionable_suppressed_rate <= 0.15
        and annoyance_score <= 0.10
    ):
        state = "supported"
        reasons = ["meets supported gates"]
    elif (
        len(app_presented) >= 10
        and kept_rate >= 0.08
        and len(app_kept_ids) >= 1
        and insertion_success >= 0.95
        and app_p95 is not None
        and app_p95 <= 1000
        and caret_failure_rate <= 0.05
        and annoyance_score <= 0.20
    ):
        state = "caveated"
        reasons = ["meets caveated gates"]
        if any(event.get("reason") == "detached-suggestion-disabled" for event in app_actionable_suppressed):
            reasons.append("detached suggestions suppressed")
        if len(app_presented) < min_sample:
            reasons.append(f"needs {min_sample} shown for supported")
    else:
        state = "experimental"
        reasons = []
        if len(app_presented) < 10:
            reasons.append("needs 10 shown for caveated")
        if not app_kept_ids:
            reasons.append("needs accepted-and-kept proof")
        if attempts == 0:
            reasons.append("needs insertion verification")
        if app_p95 is None:
            reasons.append("needs latency proof")
        if not reasons:
            reasons.append("needs more clean trace proof")

    return {
        "app": app,
        "state": state,
        "shown": len(app_presented),
        "family": family,
        "minimum_sample": min_sample,
        "kept_rate": kept_rate,
        "insert_rate": insertion_success,
        "p95": app_p95,
        "annoyance": annoyance_score,
        "reasons": reasons,
    }

def insertion_mode_reliability(events):
    buckets = defaultdict(lambda: [0, 0])
    for event in events:
        if event.get("type") not in {"insertionVerified", "insertionFailed"}:
            continue
        metadata = event.get("metadata") or {}
        app = event.get("appBundleIdentifier") or "unknown"
        mode = metadata.get("insertionMode") or "unknown"
        bucket = buckets[(app, mode)]
        if event.get("type") == "insertionVerified":
            bucket[0] += 1
        else:
            bucket[1] += 1
    return buckets

missing = []
if not presented:
    missing.append("suggestionPresented")
if not latencies:
    missing.append("latencyMilliseconds")

accept_by_mode = defaultdict(lambda: [0, 0])
accept_by_app = defaultdict(lambda: [0, 0])
accept_by_experiment_arm = defaultdict(lambda: [0, 0])
useful_by_mode = defaultdict(lambda: [0, 0])
useful_by_app = defaultdict(lambda: [0, 0])
useful_by_experiment_arm = defaultdict(lambda: [0, 0])
for event in presented_by_id.values():
    accept_by_mode[event.get("requestMode") or "unknown"][1] += 1
    accept_by_app[event.get("appBundleIdentifier") or "unknown"][1] += 1
    accept_by_experiment_arm[experiment_arm(event)][1] += 1
    useful_by_mode[event.get("requestMode") or "unknown"][1] += 1
    useful_by_app[event.get("appBundleIdentifier") or "unknown"][1] += 1
    useful_by_experiment_arm[experiment_arm(event)][1] += 1
for suggestion_id in accepted_ids:
    event = presented_by_id.get(suggestion_id)
    if event:
        accept_by_mode[event.get("requestMode") or "unknown"][0] += 1
        accept_by_app[event.get("appBundleIdentifier") or "unknown"][0] += 1
        accept_by_experiment_arm[experiment_arm(event)][0] += 1
for suggestion_id in useful_suggestion_ids:
    event = presented_by_id.get(suggestion_id)
    if event:
        useful_by_mode[event.get("requestMode") or "unknown"][0] += 1
        useful_by_app[event.get("appBundleIdentifier") or "unknown"][0] += 1
        useful_by_experiment_arm[experiment_arm(event)][0] += 1

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

duplicate_text_count = sum(
    1 for event in events
    if event.get("type") == "insertionFailed" and is_duplicate(event)
)
wrong_insertion_count = sum(
    1 for event in events
    if event.get("type") == "insertionFailed" and not is_duplicate(event)
)
tab_conflict_count = sum(1 for event in events if tab_conflict(event))
focus_steal_count = sum(1 for event in events if focus_stealing(event))
search_form_leakage_count = sum(
    1 for event in presented_by_id.values()
    if field_kind(event) in {"search", "form", "url", "secure"}
)
overlay_flicker_count = sum(1 for event in events if overlay_flicker(event))
accepted_then_deleted_count = sum(1 for event in events if accepted_then_deleted(event))

failure_reasons = [
    ("Duplicate text", duplicate_text_count, 100, "insertion trust"),
    ("Focus stealing", focus_steal_count, 95, "insertion trust"),
    ("Insertion failed", wrong_insertion_count, 90, "insertion trust"),
    ("Tab conflict", tab_conflict_count, 85, "keyboard trust"),
    ("Search/form leakage", search_form_leakage_count, 80, "field targeting"),
    ("Caret failed", len(caret_geometry_failures), 75, "renderer/caret"),
    ("Overlay flicker", overlay_flicker_count, 60, "renderer/caret"),
]
failure_reasons = [item for item in failure_reasons if item[1] > 0]
failure_reasons.sort(key=lambda item: (-item[1], -item[2], item[0]))

recommended_fixes = []
insertion_trust_count = duplicate_text_count + wrong_insertion_count + tab_conflict_count + focus_steal_count
if insertion_trust_count:
    recommended_fixes.append((
        100,
        "Fix insertion trust before model tuning",
        f"{insertion_trust_count} duplicate, focus, wrong-insert, or Tab-conflict signal(s) found.",
    ))
if len(caret_geometry_failures) + types["insertionFailed"]:
    recommended_fixes.append((
        90,
        "Fix caret or verification before prompt tuning",
        f"{len(caret_geometry_failures)} caret failure(s) and {types['insertionFailed']} insertion verification failure(s) found.",
    ))
slow_suggestions = sum(1 for event in presented_by_id.values() if (event.get("latencyMilliseconds") or 0) >= 1000)
first_visible_p95 = percentile_int(latencies, 0.95)
if slow_suggestions or (first_visible_p95 or 0) >= 1000:
    recommended_fixes.append((
        80,
        "Fix latency before length experiments",
        f"first-visible p95 is {first_visible_p95 if first_visible_p95 is not None else 'unknown'}ms with {slow_suggestions} slow shown suggestion(s).",
    ))
if not recommended_fixes and presented_by_id and not accepted_and_kept_event_ids:
    recommended_fixes.append((
        50,
        "Collect accepted-and-kept proof",
        "suggestions were shown, but no accepted text survived a checkpoint yet.",
    ))
recommended_fixes.sort(key=lambda item: (-item[0], item[1]))

daily = {}
for event in events:
    date = (event.get("timestamp") or "")[:10] or "unknown"
    bucket = daily.setdefault(date, {"events": [], "dates": []})
    bucket["events"].append(event)
    parsed = parse_date(event.get("timestamp"))
    if parsed:
        bucket["dates"].append(parsed)
requested_ids = {
    event.get("suggestionID")
    for event in events
    if event.get("type") == "suggestionRequested" and event.get("suggestionID")
}
model_returned_ids = {
    event.get("suggestionID")
    for event in events
    if event.get("type") == "modelResult" and event.get("suggestionID")
}
kept_at_10_ids = {
    event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
    for event in accepted_text_edited
    if kept_event(event) and (event.get("metadata") or {}).get("checkpoint") == "10s"
}
kept_at_30_or_blur_ids = {
    event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
    for event in accepted_text_edited
    if kept_event(event) and (event.get("metadata") or {}).get("checkpoint") in {"30s", "fieldBlur", "fieldSend"}
}

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
print(f"Actionable suppressed: {sum(1 for event in events if event.get('type') == 'suggestionSuppressed' and event.get('reason') != 'no-fast-word-candidate')}")
print(f"Insertion failures: {types['insertionFailed']}")
caret_failure_denominator = len(presented_by_id) + len(caret_geometry_failures)
caret_failure_rate = 0 if not caret_failure_denominator else round((len(caret_geometry_failures) / caret_failure_denominator) * 100)
print(f"Caret placement failures: {len(caret_geometry_failures)}")
print(f"Caret placement failure rate: {caret_failure_rate}%")
accept_rate = 0 if not presented_ids else round((len(accepted_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
useful_rate = 0 if not presented_ids else round((len(useful_suggestion_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
accepted_and_kept_rate_shown = 0 if not presented_ids else round((len(accepted_and_kept_suggestion_ids.intersection(presented_ids)) / len(presented_ids)) * 100)
accepted_and_kept_rate_accepted = 0 if not accepted_event_ids else round((len(accepted_and_kept_event_ids.intersection(accepted_event_ids)) / len(accepted_event_ids)) * 100)
tab_accepts = [
    event for event in accepted
    if (event.get("metadata") or {}).get("acceptMode") == "tab" or event.get("outcome") == "acceptNextWord"
]
full_accepts = [
    event for event in accepted
    if (event.get("metadata") or {}).get("acceptMode") == "full" or event.get("outcome") == "acceptAllVisible"
]
tab_accept_share = 0 if not accepted else round((len(tab_accepts) / len(accepted)) * 100)
full_accept_share = 0 if not accepted else round((len(full_accepts) / len(accepted)) * 100)
verified_inserts = types["insertionVerified"]
failed_inserts = types["insertionFailed"]
insert_attempts = verified_inserts + failed_inserts
verification_success = 0 if not insert_attempts else round((verified_inserts / insert_attempts) * 100)
print(f"Accept rate: {accept_rate}%")
print(f"Useful rate: {useful_rate}%")
print(f"Accepted and kept: {len(accepted_and_kept_event_ids)}")
print(f"Accepted-and-kept shown rate: {accepted_and_kept_rate_shown}%")
print(f"Accepted-and-kept accepted rate: {accepted_and_kept_rate_accepted}%")
print(f"Tab accept share: {tab_accept_share}%")
print(f"Full accept share: {full_accept_share}%")
print(f"Insertion verification success: {verification_success}%")
print(f"p50 latency: {percentile(latencies, 0.50)}")
print(f"p90 latency: {percentile(latencies, 0.90)}")
print(f"p95 latency: {percentile(latencies, 0.95)}")
print(f"first-visible p50 latency: {percentile(latencies, 0.50)}")
print(f"first-visible p90 latency: {percentile(latencies, 0.90)}")
print(f"first-visible p95 latency: {percentile(latencies, 0.95)}")
print(f"total-generation p50 latency: {percentile(model_result_latencies, 0.50)}")
print(f"total-generation p90 latency: {percentile(model_result_latencies, 0.90)}")
print(f"total-generation p95 latency: {percentile(model_result_latencies, 0.95)}")
model_result_count = types["modelResult"]
empty_rate = 0 if not model_result_count else round((len(empty_model_results) / model_result_count) * 100)
print(f"Empty model results: {len(empty_model_results)} ({empty_rate}%)")
print(f"Pre-render blocked: {len(pre_render_blocked)}")
print("Pre-render blocked by reason:")
pre_render_reasons = Counter(event.get("reason") or "unknown" for event in pre_render_blocked)
if pre_render_reasons:
    for reason, count in pre_render_reasons.most_common():
        print(f"  {reason}: {count}")
else:
    print("  none")
print("Model-result latency buckets:")
print("  first token:")
for label, count in latency_buckets(first_token_latencies):
    print(f"    {label}: {count}")
if not first_token_latencies:
    print("    none")
print("  first visible:")
for label, count in latency_buckets(latencies):
    print(f"    {label}: {count}")
if not latencies:
    print("    none")
print("  total generation:")
for label, count in latency_buckets(model_result_latencies):
    print(f"    {label}: {count}")
if not model_result_latencies:
    print("    none")
print("Acceptance funnel:")
print(f"  requested: {len(requested_ids)}")
print(f"  model returned: {len(model_returned_ids)}")
print(f"  shown: {len(presented_by_id)}")
print(f"  accepted: {len(accepted_ids.intersection(presented_ids))}")
print(f"  kept at 10s: {len(kept_at_10_ids)}")
print(f"  kept at 30s/blur: {len(kept_at_30_or_blur_ids)}")
print("Annoyance funnel:")
print(f"  shown: {len(presented_by_id)}")
print(f"  ignored: {sum(1 for event in events if event.get('type') == 'suggestionHidden' and event.get('outcome') == 'ignored')}")
print(f"  typed over: {types['suggestionTypedOver']}")
print(f"  Esc dismiss: {sum(1 for event in events if event.get('type') == 'suggestionHidden' and event.get('reason') == 'escape')}")
print(f"  accepted then deleted: {accepted_then_deleted_count}")
print(f"  paused: {types['appPaused']}")
print(f"  disabled: {types['appDisabled']}")
print("Daily summary:")
if daily:
    for date, bucket in sorted(daily.items(), reverse=True)[:7]:
        day_events = bucket["events"]
        day_presented_by_id = {}
        for event in day_events:
            if event.get("type") == "suggestionPresented" and event.get("suggestionID") not in day_presented_by_id:
                day_presented_by_id[event.get("suggestionID")] = event
        day_latencies = sorted(
            event.get("latencyMilliseconds")
            for event in day_presented_by_id.values()
            if isinstance(event.get("latencyMilliseconds"), int)
        )
        dates = sorted(bucket["dates"])
        active_minutes = 0
        if dates:
            active_minutes = max(1, int(((dates[-1] - dates[0]).total_seconds() + 59) // 60))
        day_kept = {
            event.get("metadata", {}).get("acceptanceID") or event.get("suggestionID")
            for event in day_events
            if event.get("type") == "acceptedTextEdited" and kept_event(event)
        }
        print(
            f"  {date}: active={active_minutes}m shown={len(day_presented_by_id)} "
            f"accepted={sum(1 for event in day_events if event.get('type') == 'suggestionAccepted')} "
            f"kept={len(day_kept)} p50={percentile(day_latencies, 0.50)} "
            f"p95={percentile(day_latencies, 0.95)} "
            f"severe={sum(1 for event in day_events if severe_failure(event))} "
            f"pauses={sum(1 for event in day_events if event.get('type') == 'appPaused')} "
            f"disables={sum(1 for event in day_events if event.get('type') == 'appDisabled')}"
        )
else:
    print("  none")
print("Top failure reasons:")
if failure_reasons:
    for title, count, priority, category in failure_reasons:
        print(f"  {title}: count={count} priority={priority} category={category}")
else:
    print("  none")
print("Recommended next fix:")
if recommended_fixes:
    for priority, title, reason in recommended_fixes:
        print(f"  {title}: priority={priority} reason={reason}")
else:
    print("  keep collecting clean accepted-and-kept proof")
print("Accept rate by mode:")
for mode, (accepted_count, shown_count) in sorted(accept_by_mode.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {mode}: {rate}% ({accepted_count}/{shown_count})")
print("Accept rate by app:")
for app, (accepted_count, shown_count) in sorted(accept_by_app.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {app}: {rate}% ({accepted_count}/{shown_count})")
print("Accept rate by experiment arm:")
for arm, (accepted_count, shown_count) in sorted(accept_by_experiment_arm.items()):
    rate = 0 if shown_count == 0 else round((accepted_count / shown_count) * 100)
    print(f"  {arm}: {rate}% ({accepted_count}/{shown_count})")
print("Useful rate by mode:")
for mode, (useful_count, shown_count) in sorted(useful_by_mode.items()):
    rate = 0 if shown_count == 0 else round((useful_count / shown_count) * 100)
    print(f"  {mode}: {rate}% ({useful_count}/{shown_count})")
print("Useful rate by app:")
for app, (useful_count, shown_count) in sorted(useful_by_app.items()):
    rate = 0 if shown_count == 0 else round((useful_count / shown_count) * 100)
    print(f"  {app}: {rate}% ({useful_count}/{shown_count})")
print("Useful rate by experiment arm:")
for arm, (useful_count, shown_count) in sorted(useful_by_experiment_arm.items()):
    rate = 0 if shown_count == 0 else round((useful_count / shown_count) * 100)
    print(f"  {arm}: {rate}% ({useful_count}/{shown_count})")
print("Presented by experiment arm:")
if presented_experiment_arms:
    for arm, count in presented_experiment_arms.most_common():
        print(f"  {arm}: {count}")
else:
    print("  none")
print("Accepted and kept by experiment arm:")
if accepted_and_kept_experiment_arms:
    for arm, count in accepted_and_kept_experiment_arms.most_common():
        print(f"  {arm}: {count}")
else:
    print("  none")
print("Presented by field kind:")
if presented_field_kinds:
    for kind, count in presented_field_kinds.most_common():
        print(f"  {kind}: {count}")
else:
    print("  none")
print("Accepted and kept by field kind:")
if accepted_and_kept_field_kinds:
    for kind, count in accepted_and_kept_field_kinds.most_common():
        print(f"  {kind}: {count}")
else:
    print("  none")
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
print("Suppressed by experiment arm:")
if suppressed_experiment_arms:
    for arm, count in suppressed_experiment_arms.most_common():
        print(f"  {arm}: {count}")
else:
    print("  none")
print("Suppressed by field kind:")
if suppressed_field_kinds:
    for kind, count in suppressed_field_kinds.most_common():
        print(f"  {kind}: {count}")
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
print("Caret failures by app:")
if caret_failures_by_app:
    for app, count in caret_failures_by_app.most_common():
        shown = sum(1 for event in presented_by_id.values() if (event.get("appBundleIdentifier") or "unknown") == app)
        rate = round((count / max(1, shown + count)) * 100)
        print(f"  {app}: {rate}% ({count}/{shown + count})")
else:
    print("  none")
print("Caret failures by render mode:")
if caret_failures_by_render_mode:
    for mode, count in caret_failures_by_render_mode.most_common():
        shown = sum(1 for event in presented_by_id.values() if render_mode(event) == mode)
        rate = round((count / max(1, shown + count)) * 100)
        print(f"  {mode}: {rate}% ({count}/{shown + count})")
else:
    print("  none")
print("Top repeated unaccepted suggestions:")
if repeated_unaccepted:
    for count, mode, displayed, top_app, top_app_count, suggestion_id in repeated_unaccepted[:5]:
        print(f"  {count}x {mode}: {displayed} | app {top_app} {top_app_count}/{count} (example {suggestion_id})")
else:
    print("  none")
print("Support state by app:")
support_evaluations = {
    app: support_evaluation(app)
    for app in sorted({event.get("appBundleIdentifier") for event in events if event.get("appBundleIdentifier")})
}
if support_evaluations:
    for app, evaluation in support_evaluations.items():
        p95 = "n/a" if evaluation["p95"] is None else f"{evaluation['p95']}ms"
        reason_text = ""
        if evaluation["reasons"]:
            reason_text = "; " + ", ".join(evaluation["reasons"][:3])
        print(
            f"  {app}: {evaluation['state']} "
            f"(family={evaluation['family']} "
            f"shown={evaluation['shown']}/{evaluation['minimum_sample']} "
            f"kept={round(evaluation['kept_rate'] * 100)}% "
            f"insert={round(evaluation['insert_rate'] * 100)}% "
            f"p95={p95} "
            f"annoyance={evaluation['annoyance']:.2f}{reason_text})"
        )
else:
    print("  none")
print("Insertion reliability by app and mode:")
insertion_reliability = insertion_mode_reliability(events)
if insertion_reliability:
    for (app, mode), (verified, failed) in sorted(insertion_reliability.items()):
        attempts = verified + failed
        success = 0 if attempts == 0 else round((verified / attempts) * 100)
        print(f"  {app} {mode}: {success}% ({verified} ok / {failed} failed)")
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

if require_experiment_arm:
    arm_presented = [
        event for event in presented
        if experiment_arm(event) == require_experiment_arm
    ]
    if not arm_presented:
        missing.append(f"{require_experiment_arm}: suggestionPresented")

if require_support_state:
    if require_support_state not in state_rank:
        missing.append(f"unknown support state {require_support_state}")
    else:
        support_apps = [require_app] if require_app else sorted(support_evaluations.keys())
        for app in support_apps:
            evaluation = support_evaluations.get(app) or support_evaluation(app)
            if state_rank[evaluation["state"]] < state_rank[require_support_state]:
                missing.append(f"{app}: support state {evaluation['state']} below {require_support_state}")

if missing:
    raise SystemExit("missing required trace coverage: " + ", ".join(missing))
PY
