#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_TRACE_PATH = Path.home() / "Library/Logs/SteadyType/traces.jsonl"
DEFAULT_LEARNING_PATH = (
    Path.home()
    / "Library/Application Support/SteadyType/compatibility-learning.json"
)
NUDGE_STEP_PIXELS = 2.0
CODE_PROMOTION_REASONS = {"manual-visual-nudge", "screenshot-visual-correction"}
FIELD_HASH_PREFIX = "sha256:"
BLOCKED_APP_REASONS = {
    "app-disabled",
    "blocked-field-kind",
    "diagnostics-only-profile",
    "disabled",
    "insert-missing-compatibility-profile",
    "missing-compatibility-profile",
    "missing-profile",
    "profile-diagnostics-only",
    "secure-field",
    "sensitive-field",
    "unsupported-app",
    "unsupported-browser-surface",
    "unsupported-profile",
}
PLACEMENT_FAILURE_REASONS = {
    "anchor-outside-active-display",
    "caret-outside-focused-bounds",
    "detached-suggestion-disabled",
    "invalid-anchor",
    "invalid-caret",
    "low-confidence-placement",
    "missing-anchor",
    "missing-caret",
    "missing-floating-fallback",
    "placement-caret-outside-focused-bounds",
    "placement-detached-suggestion-disabled",
    "placement-invalid-anchor",
    "placement-invalid-caret",
    "placement-low-confidence-placement",
    "placement-missing-anchor",
    "placement-missing-caret",
    "placement-missing-floating-fallback",
    "placement-untrusted-detached-anchor",
    "placement-untrusted-synthetic-caret",
    "untrusted-detached-anchor",
    "untrusted-placement",
    "untrusted-synthetic-caret",
}
QUIET_FIELD_REASONS = {
    "accepted-then-deleted",
    "acceptedThenDeleted",
    "below-threshold",
    "dismissed",
    "escape",
    "escape-dismissed",
    "field-paused",
    "field-silenced",
    "high-instability",
    "high-repetition",
    "late-suggestion-hidden",
    "low-accepted-and-kept-probability",
    "prefix-family-cooldown",
    "quiet-mode-started",
    "repeated-miss",
    "too-slow-to-display",
    "typed-against-visible-suggestion",
    "typed-over",
    "typedOver",
    "typed-through",
}
PROMPT_APP_BUNDLES = {
    "com.anthropic.claude-code",
    "com.anthropic.claudefordesktop",
    "com.hnc.Discord",
    "com.hnc.DiscordCanary",
    "com.hnc.DiscordPTB",
    "com.openai.ChatGPT",
    "com.openai.atlas",
    "com.openai.chat",
    "com.openai.codex",
    "com.tinyspeck.slackmacgap",
    "ru.keepcoder.Telegram",
}
SMOKE_TARGETS_BY_BUNDLE = {
    "com.apple.Notes": "notes-body",
    "com.apple.TextEdit": "textedit",
    "com.anthropic.claude-code": "claude-code",
    "com.anthropic.claudefordesktop": "claude",
    "com.google.Chrome": "chrome",
    "com.openai.codex": "codex",
    "md.obsidian": "obsidian",
}


def read_json(path):
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_learning_profiles(path):
    payload = read_json(path)
    if payload is None:
        return []
    if isinstance(payload, dict):
        if "bundleIdentifier" in payload:
            return [payload]
        return [profile for profile in payload.values() if isinstance(profile, dict)]
    if isinstance(payload, list):
        return [profile for profile in payload if isinstance(profile, dict)]
    return []


def load_trace_events(path, start_line):
    if not path.exists():
        return []

    events = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            stripped = line.strip()
            if not stripped:
                continue
            try:
                event = json.loads(stripped)
            except json.JSONDecodeError as error:
                raise SystemExit(f"invalid JSONL at line {line_number}: {error}") from error
            if isinstance(event, dict):
                events.append(event)
    return events


def number(value, default=0.0):
    if isinstance(value, bool):
        return default
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return default
    return default


def text(value, default="unknown"):
    if isinstance(value, str) and value.strip():
        return value.strip()
    return default


def metadata(event):
    value = event.get("metadata")
    return value if isinstance(value, dict) else {}


def sorted_counter(counter):
    return dict(sorted(counter.items(), key=lambda item: (-item[1], item[0])))


def event_type(event):
    return text(event.get("type"), "")


def bundle_identifier(event):
    return text(event.get("appBundleIdentifier"))


def first_signal(event, keys):
    event_metadata = metadata(event)
    for key in keys:
        if key.startswith("metadata."):
            value = text(event_metadata.get(key.removeprefix("metadata.")), "")
        else:
            value = text(event.get(key), "")
        if value:
            return value
    return "unknown"


def primary_reason(event):
    return first_signal(
        event,
        [
            "reason",
            "metadata.suppressionReason",
            "metadata.displayScoreSuppressionReason",
            "metadata.placementHealthReason",
            "metadata.anchorReason",
            "metadata.finishReason",
            "outcome",
            "triggerReason",
        ],
    )


def render_mode(event):
    event_metadata = metadata(event)
    return text(
        event_metadata.get("effectiveRenderMode")
        or event_metadata.get("renderMode")
        or event_metadata.get("placementEffectiveRenderMode"),
        "unknown",
    )


def request_mode(event):
    return text(event.get("requestMode"), "unknown")


def field_kind(event):
    event_metadata = metadata(event)
    return text(
        event_metadata.get("fieldKind") or event_metadata.get("requestFieldKind"),
        "unknown",
    )


def field_surface(event):
    event_metadata = metadata(event)
    return text(
        event_metadata.get("browserSurface")
        or event_metadata.get("sensitiveSuppressionCategory")
        or event_metadata.get("supportLevel"),
        "",
    )


def short_hash(value):
    if not value:
        return "unknown"
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:10]


def redacted_field_fingerprint(event):
    event_metadata = metadata(event)
    source = (
        text(event.get("fieldIdentity"), "")
        or text(event_metadata.get("fieldFingerprint"), "")
        or text(event_metadata.get("targetFingerprint"), "")
        or text(event_metadata.get("runtimeSessionCacheKey"), "")
        or text(event_metadata.get("promptFingerprint"), "")
        or text(event_metadata.get("prefixFamilyHMACToken"), "")
    )
    fingerprint = short_hash(source)
    return "unknown" if fingerprint == "unknown" else f"{FIELD_HASH_PREFIX}{fingerprint}"


def field_label(event):
    surface = field_surface(event)
    kind = field_kind(event)
    suffix = f"; surface={surface}" if surface else ""
    return f"{kind}/{redacted_field_fingerprint(event)}{suffix}"


def counter_keys(counter, limit=3):
    return list(sorted_counter(counter).keys())[:limit]


def is_tab_conflict(event):
    joined = " ".join(
        [
            primary_reason(event),
            text(event.get("outcome"), ""),
            text(metadata(event).get("keyboardReason"), ""),
        ]
    ).lower()
    return "tab conflict" in joined or "tab-conflict" in joined


def is_focus_steal(event):
    joined = " ".join([primary_reason(event), text(event.get("outcome"), "")]).lower()
    return "focus steal" in joined or "focus-steal" in joined


def is_accepted_then_deleted(event):
    event_metadata = metadata(event)
    joined = " ".join(
        [
            text(event.get("triggerReason"), ""),
            text(event.get("outcome"), ""),
            text(event.get("reason"), ""),
            text(event_metadata.get("annoyanceSignal"), ""),
            text(event_metadata.get("survivalClass"), ""),
            text(event_metadata.get("finishReason"), ""),
        ]
    )
    return (
        "acceptedThenDeleted" in joined
        or "accepted-then-deleted" in joined
        or (
            event_type(event) == "acceptedTextEdited"
            and event_metadata.get("deletedWithinTwoSeconds") == "true"
        )
        or (
            event_type(event) == "acceptanceRetentionCleared"
            and "deleted" in text(event.get("reason"), "").lower()
        )
    )


def is_placement_failure(event):
    reason = primary_reason(event)
    event_metadata = metadata(event)
    return (
        event_type(event) == "caretGeometryFailed"
        or reason in PLACEMENT_FAILURE_REASONS
        or text(event_metadata.get("placementHealthReason"), "") in PLACEMENT_FAILURE_REASONS
        or text(event_metadata.get("anchorReason"), "") in PLACEMENT_FAILURE_REASONS
    )


def is_insertion_failure(event):
    return event_type(event) == "insertionFailed"


def smoke_target(bundle_id):
    return SMOKE_TARGETS_BY_BUNDLE.get(bundle_id)


def visual_nudge_candidates(profiles, minimum_steps):
    candidates = []
    for profile in profiles:
        bundle_id = text(profile.get("bundleIdentifier"))
        x_offset = number(profile.get("xOffset"))
        y_offset = number(profile.get("yOffset"))
        approx_steps = round((abs(x_offset) + abs(y_offset)) / NUDGE_STEP_PIXELS)
        if approx_steps < minimum_steps:
            continue
        candidates.append(
            {
                "bundleIdentifier": bundle_id,
                "xOffset": x_offset,
                "yOffset": y_offset,
                "approxNudgeSteps": approx_steps,
                "observations": int(number(profile.get("observations"), 0)),
                "confidence": number(profile.get("confidence")),
                "lastReason": text(profile.get("lastReason"), ""),
                "updatedAt": text(profile.get("updatedAt"), ""),
                "renderModeOverride": text(profile.get("renderModeOverride"), "profile"),
            }
        )
    return sorted(
        candidates,
        key=lambda item: (
            -item["approxNudgeSteps"],
            -item["observations"],
            item["bundleIdentifier"],
        ),
    )


def code_promotion_candidates(
    profiles,
    minimum_steps,
    minimum_observations,
    minimum_confidence,
):
    candidates = []
    for item in visual_nudge_candidates(profiles, minimum_steps):
        if item["observations"] < minimum_observations:
            continue
        if item["confidence"] < minimum_confidence:
            continue
        if item["lastReason"] not in CODE_PROMOTION_REASONS:
            continue
        candidates.append(item)
    return candidates


def detached_suppression_candidates(events, minimum_count):
    by_app = defaultdict(list)
    for event in events:
        if event.get("type") != "suggestionSuppressed":
            continue
        if event.get("reason") != "detached-suggestion-disabled":
            continue
        by_app[text(event.get("appBundleIdentifier"))].append(event)

    candidates = []
    for bundle_id, app_events in by_app.items():
        if len(app_events) < minimum_count:
            continue
        modes = Counter(text(event.get("requestMode"), "unknown") for event in app_events)
        anchor_reasons = Counter(
            text(metadata(event).get("anchorReason"), "unknown") for event in app_events
        )
        anchor_sources = Counter(
            text(metadata(event).get("anchorSource"), "unknown") for event in app_events
        )
        candidates.append(
            {
                "bundleIdentifier": bundle_id,
                "count": len(app_events),
                "modes": dict(sorted(modes.items())),
                "anchorReasons": dict(sorted(anchor_reasons.items())),
                "anchorSources": dict(sorted(anchor_sources.items())),
            }
        )
    return sorted(candidates, key=lambda item: (-item["count"], item["bundleIdentifier"]))


def apps_that_should_stay_blocked(
    events,
    minimum_block_events,
    minimum_insertion_failures,
    minimum_placement_failures,
):
    by_app = defaultdict(
        lambda: {
            "signals": Counter(),
            "fields": Counter(),
            "requestModes": Counter(),
            "critical": 0,
        }
    )

    for event in events:
        bundle_id = bundle_identifier(event)
        reason = primary_reason(event)
        event_metadata = metadata(event)
        signal = ""
        critical = False

        if event_type(event) == "appDisabled":
            signal = "app-disabled"
            critical = True
        elif reason in BLOCKED_APP_REASONS:
            signal = reason
            critical = True
        elif event_metadata.get("browserSurfaceDecision") == "blocked":
            signal = "browser-surface-blocked"
            critical = True
        elif event_metadata.get("sensitiveSuppressionDecision") == "blocked":
            signal = "sensitive-field-blocked"
            critical = True
        elif event_metadata.get("supportLevel") in {"diagnosticsOnly", "unsupported"}:
            signal = f"support-{event_metadata['supportLevel']}"
            critical = True
        elif is_tab_conflict(event):
            signal = "tab-conflict"
            critical = True
        elif is_focus_steal(event):
            signal = "focus-steal"
            critical = True
        elif is_insertion_failure(event):
            signal = "insertion-failed"
        elif is_placement_failure(event):
            signal = "placement-failed"

        if not signal:
            continue

        bucket = by_app[bundle_id]
        bucket["signals"][signal] += 1
        bucket["fields"][field_label(event)] += 1
        bucket["requestModes"][request_mode(event)] += 1
        if critical:
            bucket["critical"] += 1

    candidates = []
    for bundle_id, bucket in by_app.items():
        signals = bucket["signals"]
        if not (
            bucket["critical"] > 0
            or sum(signals.values()) >= minimum_block_events
            or signals["insertion-failed"] >= minimum_insertion_failures
            or signals["placement-failed"] >= minimum_placement_failures
        ):
            continue
        candidates.append(
            {
                "bundleIdentifier": bundle_id,
                "riskEvents": sum(signals.values()),
                "signals": sorted_counter(signals),
                "fields": counter_keys(bucket["fields"]),
                "requestModes": sorted_counter(bucket["requestModes"]),
            }
        )

    return sorted(
        candidates,
        key=lambda item: (-item["riskEvents"], item["bundleIdentifier"]),
    )


def quiet_field_candidates(events, minimum_count):
    by_field = defaultdict(
        lambda: {
            "signals": Counter(),
            "requestModes": Counter(),
        }
    )

    for event in events:
        reason = primary_reason(event)
        event_metadata = metadata(event)
        signal = ""
        if event_type(event) == "suggestionTypedOver":
            signal = "typed-over"
        elif event_type(event) == "fieldPaused":
            signal = "field-paused"
        elif is_accepted_then_deleted(event):
            signal = "accepted-then-deleted"
        elif reason in QUIET_FIELD_REASONS:
            signal = reason
        elif text(event_metadata.get("prefixCooldownReason"), "") in QUIET_FIELD_REASONS:
            signal = event_metadata["prefixCooldownReason"]
        elif text(event_metadata.get("annoyanceSignal"), "") in QUIET_FIELD_REASONS:
            signal = event_metadata["annoyanceSignal"]
        elif text(event_metadata.get("displayScoreSuppressionReason"), "") in QUIET_FIELD_REASONS:
            signal = event_metadata["displayScoreSuppressionReason"]

        if not signal:
            continue

        key = (bundle_identifier(event), field_label(event))
        bucket = by_field[key]
        bucket["signals"][signal] += 1
        bucket["requestModes"][request_mode(event)] += 1

    candidates = []
    for (bundle_id, field), bucket in by_field.items():
        signals = bucket["signals"]
        count = sum(signals.values())
        if count < minimum_count:
            continue
        candidates.append(
            {
                "bundleIdentifier": bundle_id,
                "field": field,
                "count": count,
                "signals": sorted_counter(signals),
                "requestModes": sorted_counter(bucket["requestModes"]),
            }
        )

    return sorted(
        candidates,
        key=lambda item: (-item["count"], item["bundleIdentifier"], item["field"]),
    )


def repeated_placement_failures(events, minimum_count):
    by_cluster = defaultdict(
        lambda: {
            "count": 0,
            "fields": Counter(),
            "anchorSources": Counter(),
            "requestModes": Counter(),
        }
    )

    for event in events:
        if not is_placement_failure(event):
            continue
        event_metadata = metadata(event)
        reason = primary_reason(event)
        key = (bundle_identifier(event), render_mode(event), reason)
        bucket = by_cluster[key]
        bucket["count"] += 1
        bucket["fields"][field_label(event)] += 1
        bucket["anchorSources"][
            text(
                event_metadata.get("anchorSource")
                or event_metadata.get("placementAnchorSource"),
                "unknown",
            )
        ] += 1
        bucket["requestModes"][request_mode(event)] += 1

    failures = []
    for (bundle_id, mode, reason), bucket in by_cluster.items():
        if bucket["count"] < minimum_count:
            continue
        failures.append(
            {
                "bundleIdentifier": bundle_id,
                "renderMode": mode,
                "reason": reason,
                "count": bucket["count"],
                "fields": counter_keys(bucket["fields"]),
                "anchorSources": sorted_counter(bucket["anchorSources"]),
                "requestModes": sorted_counter(bucket["requestModes"]),
            }
        )

    return sorted(
        failures,
        key=lambda item: (-item["count"], item["bundleIdentifier"], item["reason"]),
    )


def insertion_failure_clusters(events, minimum_count):
    by_cluster = defaultdict(
        lambda: {
            "count": 0,
            "fields": Counter(),
            "requestModes": Counter(),
            "recoverability": Counter(),
        }
    )

    for event in events:
        if not is_insertion_failure(event):
            continue
        event_metadata = metadata(event)
        mode = text(
            event_metadata.get("insertionMode")
            or event_metadata.get("acceptMode")
            or event_metadata.get("keyboardAction"),
            "unknown",
        )
        reason = primary_reason(event)
        key = (bundle_identifier(event), mode, reason)
        bucket = by_cluster[key]
        bucket["count"] += 1
        bucket["fields"][field_label(event)] += 1
        bucket["requestModes"][request_mode(event)] += 1
        bucket["recoverability"][
            text(event_metadata.get("failureRecoverability"), "unknown")
        ] += 1

    clusters = []
    for (bundle_id, mode, reason), bucket in by_cluster.items():
        if bucket["count"] < minimum_count:
            continue
        clusters.append(
            {
                "bundleIdentifier": bundle_id,
                "insertionMode": mode,
                "reason": reason,
                "count": bucket["count"],
                "fields": counter_keys(bucket["fields"]),
                "requestModes": sorted_counter(bucket["requestModes"]),
                "recoverability": sorted_counter(bucket["recoverability"]),
            }
        )

    return sorted(
        clusters,
        key=lambda item: (-item["count"], item["bundleIdentifier"], item["reason"]),
    )


def suggested_smoke_commands(report):
    commands = []

    def add(command):
        if command not in commands:
            commands.append(command)

    for item in report["codePromotionCandidates"]:
        target = smoke_target(item["bundleIdentifier"])
        if target:
            add(f"./script/manual_smoke_session.sh {target} --print --visual")
        add(
            "AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="
            f"{item['bundleIdentifier']} ./script/check_trace_eval.sh"
        )

    for item in report["appsThatShouldStayBlocked"]:
        bundle_id = item["bundleIdentifier"]
        add(
            "AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="
            f"{bundle_id} ./script/check_trace_eval.sh"
        )
        if bundle_id in PROMPT_APP_BUNDLES:
            add(f"./script/check_prompt_app_proof.sh --bundle {bundle_id}")

    for item in report["fieldsNeedingQuietMode"]:
        add(
            "python3 script/non_annoyance_report.py "
            "\"${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}\" "
            "--start-line \"${AUTOCOMPLETE_LAB_TRACE_START_LINE:-1}\" --no-gate"
        )
        target = smoke_target(item["bundleIdentifier"])
        if target:
            add(f"./script/manual_smoke_session.sh {target} --print")

    for item in report["repeatedPlacementFailures"]:
        target = smoke_target(item["bundleIdentifier"])
        if target:
            add(f"./script/manual_smoke_session.sh {target} --print --visual")

    for item in report["insertionFailureClusters"]:
        target = smoke_target(item["bundleIdentifier"])
        if target:
            add(f"./script/manual_smoke_session.sh {target} --print")
        add(
            "AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="
            f"{item['bundleIdentifier']} ./script/check_trace_eval.sh"
        )

    if not commands:
        add("./script/compatibility_self_healing_report.py")
        add("./script/manual_smoke_session.sh textedit --print")

    return commands[:8]


def counter_summary(values):
    if not values:
        return "none"
    return ", ".join(f"{key}={value}" for key, value in values.items())


def section_items(report, key):
    items = report[key]
    limit = int(report.get("maxItems", len(items)))
    return items[:limit], max(0, len(items) - limit)


def append_more_line(lines, remaining):
    if remaining > 0:
        lines.append(f"  ... {remaining} more in --json output")


def render_text(report):
    lines = [
        "Compatibility self-healing report",
        f"Trace: {report['tracePath']}",
        f"Compatibility learning: {report['learningPath']}",
        f"Start line: {report['startLine']}",
        "",
        (
            "Repeated visual nudges "
            f"(>= {report['minimumNudgeSteps']} approx nudge steps):"
        ),
    ]

    if report["visualNudgeCandidates"]:
        items, remaining = section_items(report, "visualNudgeCandidates")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"offset=({item['xOffset']:.1f},{item['yOffset']:.1f}), "
                        f"approxNudges={item['approxNudgeSteps']}, "
                        f"observations={item['observations']}, "
                        f"confidence={item['confidence']:.2f}, "
                        f"lastReason={item['lastReason'] or 'unknown'}"
                    ),
                    (
                        "    recommendation: turn the learned offset into an "
                        "app/profile calibration fixture before widening support."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Adapter promotion candidates "
                f"(>= {report['minimumCodePromotionObservations']} observations, "
                f">= {report['minimumCodePromotionConfidence']:.2f} confidence, "
                "trusted visual reason):"
            ),
        ]
    )

    if report["codePromotionCandidates"]:
        items, remaining = section_items(report, "codePromotionCandidates")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"offset=({item['xOffset']:.1f},{item['yOffset']:.1f}), "
                        f"approxNudges={item['approxNudgeSteps']}, "
                        f"observations={item['observations']}, "
                        f"confidence={item['confidence']:.2f}, "
                        f"lastReason={item['lastReason']}"
                    ),
                    (
                        "    recommendation: convert to a checked-in app/profile "
                        "calibration only after current-commit screenshot smoke "
                        "passes for that app."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Apps that should stay blocked "
                f"(>= {report['minimumBlockEvents']} risk events or critical signal):"
            ),
        ]
    )

    if report["appsThatShouldStayBlocked"]:
        items, remaining = section_items(report, "appsThatShouldStayBlocked")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"riskEvents={item['riskEvents']}, "
                        f"signals={counter_summary(item['signals'])}, "
                        f"modes={counter_summary(item['requestModes'])}"
                    ),
                    (
                        "    fields: "
                        + (", ".join(item["fields"]) if item["fields"] else "unknown")
                    ),
                    (
                        "    recommendation: keep suggestions blocked until a "
                        "fresh smoke trace proves placement and insertion are both safe."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Fields needing quiet mode "
                f"(>= {report['minimumQuietFieldSignals']} annoyance signals):"
            ),
        ]
    )

    if report["fieldsNeedingQuietMode"]:
        items, remaining = section_items(report, "fieldsNeedingQuietMode")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"field={item['field']}, "
                        f"signals={counter_summary(item['signals'])}, "
                        f"modes={counter_summary(item['requestModes'])}"
                    ),
                    (
                        "    recommendation: start quiet mode for this redacted "
                        "field fingerprint before widening suggestion cadence."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Repeated placement failures "
                f"(>= {report['minimumPlacementFailures']} events per cluster):"
            ),
        ]
    )

    if report["repeatedPlacementFailures"]:
        items, remaining = section_items(report, "repeatedPlacementFailures")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"render={item['renderMode']}, "
                        f"reason={item['reason']}, "
                        f"count={item['count']}, "
                        f"anchorSources={counter_summary(item['anchorSources'])}"
                    ),
                    (
                        "    fields: "
                        + (", ".join(item["fields"]) if item["fields"] else "unknown")
                    ),
                    (
                        "    recommendation: keep detached or low-confidence "
                        "placement blocked until current visual smoke passes."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Insertion failure clusters "
                f"(>= {report['minimumInsertionFailures']} events per cluster):"
            ),
        ]
    )

    if report["insertionFailureClusters"]:
        items, remaining = section_items(report, "insertionFailureClusters")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"insert={item['insertionMode']}, "
                        f"reason={item['reason']}, "
                        f"count={item['count']}, "
                        f"recoverability={counter_summary(item['recoverability'])}"
                    ),
                    (
                        "    fields: "
                        + (", ".join(item["fields"]) if item["fields"] else "unknown")
                    ),
                    (
                        "    recommendation: keep the app blocked or fallback-only "
                        "until insertion verification is clean in a new trace slice."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            (
                "Repeated detached suppression "
                f"(>= {report['minimumDetachedSuppressions']} events):"
            ),
        ]
    )

    if report["detachedSuppressionCandidates"]:
        items, remaining = section_items(report, "detachedSuppressionCandidates")
        for item in items:
            lines.extend(
                [
                    (
                        f"  {item['bundleIdentifier']}: "
                        f"detachedSuppressions={item['count']}, "
                        f"modes={counter_summary(item['modes'])}, "
                        f"anchorSources={counter_summary(item['anchorSources'])}, "
                        f"anchorReasons={counter_summary(item['anchorReasons'])}"
                    ),
                    (
                        "    recommendation: keep detached display blocked; "
                        "only add an adapter after proving caret or line bounds."
                    ),
                ]
            )
        append_more_line(lines, remaining)
    else:
        lines.append("  none")

    lines.extend(["", "Next recommended smoke commands:"])
    if report["nextRecommendedSmokeCommands"]:
        for command in report["nextRecommendedSmokeCommands"]:
            lines.append(f"  {command}")
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            "Field identifiers are redacted as sha256 10-character fingerprints when present.",
            "No screenshots, calibration, or new trace capture were started.",
        ]
    )
    return "\n".join(lines)


def build_report(args):
    learning_path = Path(args.learning_path).expanduser()
    trace_path = Path(args.trace_path).expanduser()
    profiles = load_learning_profiles(learning_path)
    events = load_trace_events(trace_path, args.start_line)
    report = {
        "reportKind": "overnight-self-healing-proof",
        "learningPath": str(learning_path),
        "tracePath": str(trace_path),
        "startLine": args.start_line,
        "minimumNudgeSteps": args.min_nudge_steps,
        "minimumDetachedSuppressions": args.min_detached_suppressions,
        "minimumBlockEvents": args.min_block_events,
        "minimumQuietFieldSignals": args.min_quiet_field_signals,
        "minimumPlacementFailures": args.min_placement_failures,
        "minimumInsertionFailures": args.min_insertion_failures,
        "maxItems": args.max_items,
        "redaction": {
            "fieldIdentifiers": "sha256-10",
            "rawTypedText": "not read or printed",
            "screenshots": "not read or linked",
        },
        "profileCount": len(profiles),
        "traceEventCount": len(events),
        "visualNudgeCandidates": visual_nudge_candidates(
            profiles,
            args.min_nudge_steps,
        ),
        "minimumCodePromotionObservations": args.min_code_observations,
        "minimumCodePromotionConfidence": args.min_code_confidence,
        "codePromotionCandidates": code_promotion_candidates(
            profiles,
            args.min_nudge_steps,
            args.min_code_observations,
            args.min_code_confidence,
        ),
        "detachedSuppressionCandidates": detached_suppression_candidates(
            events,
            args.min_detached_suppressions,
        ),
        "appsThatShouldStayBlocked": apps_that_should_stay_blocked(
            events,
            args.min_block_events,
            args.min_insertion_failures,
            args.min_placement_failures,
        ),
        "fieldsNeedingQuietMode": quiet_field_candidates(
            events,
            args.min_quiet_field_signals,
        ),
        "repeatedPlacementFailures": repeated_placement_failures(
            events,
            args.min_placement_failures,
        ),
        "insertionFailureClusters": insertion_failure_clusters(
            events,
            args.min_insertion_failures,
        ),
    }
    report["nextRecommendedSmokeCommands"] = suggested_smoke_commands(report)
    return report


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Report local app compatibility patterns that should become "
            "self-healing adapter work."
        )
    )
    parser.add_argument(
        "--trace",
        dest="trace_path",
        default=os.environ.get("AUTOCOMPLETE_LAB_TRACE_PATH", str(DEFAULT_TRACE_PATH)),
        help="Path to traces.jsonl.",
    )
    parser.add_argument(
        "--learning",
        dest="learning_path",
        default=os.environ.get(
            "AUTOCOMPLETE_LAB_COMPATIBILITY_LEARNING_PATH",
            str(DEFAULT_LEARNING_PATH),
        ),
        help="Path to compatibility-learning.json.",
    )
    parser.add_argument(
        "--start-line",
        type=int,
        default=int(os.environ.get("AUTOCOMPLETE_LAB_TRACE_START_LINE", "0") or "0"),
        help="Ignore trace lines at or before this 1-based line number.",
    )
    parser.add_argument(
        "--min-nudge-steps",
        type=int,
        default=2,
        help="Minimum approximate 2px manual nudge steps to report.",
    )
    parser.add_argument(
        "--min-detached-suppressions",
        type=int,
        default=2,
        help="Minimum detached suppression events per app to report.",
    )
    parser.add_argument(
        "--min-block-events",
        type=int,
        default=2,
        help="Minimum risk events before recommending an app stay blocked.",
    )
    parser.add_argument(
        "--min-quiet-field-signals",
        type=int,
        default=2,
        help="Minimum annoyance signals before recommending field quiet mode.",
    )
    parser.add_argument(
        "--min-placement-failures",
        type=int,
        default=2,
        help="Minimum placement failures per repeated-failure cluster.",
    )
    parser.add_argument(
        "--min-insertion-failures",
        type=int,
        default=2,
        help="Minimum insertion failures per failure cluster.",
    )
    parser.add_argument(
        "--max-items",
        type=int,
        default=12,
        help="Maximum rows per text section. JSON output always includes all rows.",
    )
    parser.add_argument(
        "--min-code-observations",
        type=int,
        default=5,
        help="Minimum learning observations before recommending checked-in code.",
    )
    parser.add_argument(
        "--min-code-confidence",
        type=float,
        default=0.75,
        help="Minimum learning confidence before recommending checked-in code.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    report = build_report(args)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print(render_text(report))


if __name__ == "__main__":
    main()
