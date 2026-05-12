#!/usr/bin/env python3
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

TEXT_KEYS = {
    "textBeforeCursor",
    "textAfterCursor",
    "systemPrompt",
    "userPrompt",
    "rawOutput",
    "cleanedVisibleText",
    "displayedText",
    "acceptedText",
    "remainingVisibleText",
    "screenshotPath",
}


def parse_args():
    default_trace = os.environ.get(
        "AUTOCOMPLETE_LAB_TRACE_PATH",
        str(Path.home() / "Library/Logs/SteadyType/traces.jsonl"),
    )
    parser = argparse.ArgumentParser(description="Gate redacted autocomplete non-annoyance rates.")
    parser.add_argument("trace", nargs="?", default=default_trace)
    parser.add_argument("--start-line", type=int, default=1)
    parser.add_argument("--end-line", type=int)
    parser.add_argument("--no-gate", action="store_true")
    parser.add_argument("--max-shown-per-minute", type=float, default=2.0)
    parser.add_argument("--max-dismissals-per-shown", type=float, default=0.25)
    parser.add_argument("--max-typed-over-within-1s", type=float, default=0.20)
    parser.add_argument("--max-accepted-then-deleted", type=float, default=0.05)
    parser.add_argument("--max-immediate-resurfacing", type=int, default=0)
    parser.add_argument("--max-late-shown", type=int, default=0)
    parser.add_argument("--min-late-hidden-rate", type=float, default=1.0)
    parser.add_argument("--max-pause-disable-per-shown", type=float, default=0.10)
    parser.add_argument("--min-severe-suppression-rate", type=float, default=1.0)
    return parser.parse_args()


def load_events(path, start_line, end_line):
    events = []
    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number < start_line:
                continue
            if end_line is not None and line_number > end_line:
                break
            line = line.strip()
            if not line:
                continue
            events.append(redacted_event(json.loads(line)))
    return sorted(events, key=event_time)


def redacted_event(event):
    safe = dict(event)
    for key in TEXT_KEYS:
        value = safe.pop(key, "")
        if value and key != "screenshotPath":
            safe.setdefault("metadata", {})[f"{key}Chars"] = str(len(str(value)))
    if event.get("screenshotPath"):
        safe.setdefault("metadata", {})["screenshotCaptured"] = "true"
    metadata = safe.get("metadata") or {}
    safe["metadata"] = {
        key: value
        for key, value in metadata.items()
        if not any(raw in key.lower() for raw in ("text", "prompt", "output", "path"))
    }
    return safe


def event_time(event):
    value = event.get("timestamp", "")
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return datetime.fromtimestamp(0, tz=timezone.utc)


def rate(numerator, denominator):
    return 0.0 if denominator <= 0 else numerator / denominator


def percent(value):
    return f"{round(value * 100):.0f}%"


def event_type(event):
    return event.get("type", "")


def suggestion_key(event):
    return event.get("suggestionID") or event.get("id") or ""


def acceptance_key(event):
    metadata = event.get("metadata") or {}
    return metadata.get("acceptanceID") or event.get("suggestionID") or event.get("id") or ""


def same_surface(left, right):
    return (
        left.get("appBundleIdentifier") == right.get("appBundleIdentifier")
        and left.get("fieldIdentity") == right.get("fieldIdentity")
        and left.get("requestMode") == right.get("requestMode")
    )


def is_dismissal(event):
    joined = " ".join([event.get("reason", ""), event.get("outcome", "")]).lower()
    return event_type(event) == "suggestionHidden" and ("escape" in joined or "dismiss" in joined)


def is_accepted_then_deleted(event):
    metadata = event.get("metadata") or {}
    joined = " ".join(
        [
            event.get("triggerReason", ""),
            event.get("outcome", ""),
            event.get("reason", ""),
            metadata.get("annoyanceSignal", ""),
            metadata.get("survivalClass", ""),
            metadata.get("finishReason", ""),
        ]
    ).lower()
    return (
        "acceptedthendeleted" in joined
        or "accepted-then-deleted" in joined
        or (event_type(event) == "acceptedTextEdited" and metadata.get("deletedWithinTwoSeconds") == "true")
        or (event_type(event) == "acceptanceRetentionCleared" and "deleted" in event.get("reason", "").lower())
    )


def is_late(event):
    metadata = event.get("metadata") or {}
    if (event.get("latencyMilliseconds") or 0) > 750:
        return True
    joined = " ".join(
        [
            event.get("reason", ""),
            event.get("outcome", ""),
            metadata.get("lateSuggestion", ""),
            metadata.get("staleLateSuggestion", ""),
            metadata.get("displayDecision", ""),
            metadata.get("suppressionReason", ""),
        ]
    ).lower()
    return "late" in joined or "stale" in joined


def typed_over_within_one_second(events):
    presented_at = {}
    count = 0
    for event in events:
        key = suggestion_key(event)
        if event_type(event) == "suggestionPresented":
            presented_at[key] = event_time(event)
        elif event_type(event) == "suggestionTypedOver" and key in presented_at:
            if (event_time(event) - presented_at[key]).total_seconds() <= 1:
                count += 1
    return count


def immediate_resurfacing(events):
    rejections = []
    count = 0
    accepted_deleted_keys = {
        acceptance_key(event)
        for event in events
        if is_accepted_then_deleted(event)
    }
    used_accepted_deleted_keys = set()

    for event in events:
        if event_type(event) == "suggestionPresented":
            presented_at = event_time(event)
            if any(
                same_surface(rejection, event)
                and 0 < (presented_at - event_time(rejection)).total_seconds() <= 2
                for rejection in rejections
            ):
                count += 1
            rejections = [
                rejection
                for rejection in rejections
                if (presented_at - event_time(rejection)).total_seconds() <= 2
            ]
        elif is_dismissal(event) or event_type(event) == "suggestionTypedOver":
            rejections.append(event)
        elif is_accepted_then_deleted(event):
            key = acceptance_key(event)
            if key in accepted_deleted_keys and key not in used_accepted_deleted_keys:
                rejections.append(event)
                used_accepted_deleted_keys.add(key)
    return count


def severe_suppression_coverage(events, severe_events):
    by_key = {}
    for event in severe_events:
        by_key.setdefault(acceptance_key(event), event)

    covered = 0
    for severe_event in by_key.values():
        metadata = severe_event.get("metadata") or {}
        if metadata.get("prefixCooldownReason") == "acceptedThenDeleted":
            covered += 1
            continue
        severe_at = event_time(severe_event)
        for candidate in events:
            candidate_metadata = candidate.get("metadata") or {}
            delay = (event_time(candidate) - severe_at).total_seconds()
            if (
                event_type(candidate) == "suggestionSuppressed"
                and same_surface(severe_event, candidate)
                and 0 <= delay <= 120
                and (
                    candidate_metadata.get("prefixCooldownReason") == "acceptedThenDeleted"
                    or candidate.get("triggerReason") == "annoyance-signal"
                    or candidate_metadata.get("annoyanceSignal") == "acceptedThenDeleted"
                )
            ):
                covered += 1
                break
    return covered, len(by_key)


def compute_report(events, args):
    shown_events = [event for event in events if event_type(event) == "suggestionPresented"]
    dismissals = [event for event in events if is_dismissal(event)]
    severe_events = [event for event in events if is_accepted_then_deleted(event)]
    late_shown = [event for event in shown_events if is_late(event)]
    late_hidden = [
        event
        for event in events
        if event_type(event) == "suggestionHidden" and is_late(event)
    ]
    pause_disable = [
        event
        for event in events
        if event_type(event) in {"appPaused", "fieldPaused", "appDisabled"}
    ]
    if events:
        active_minutes = max(1.0, (event_time(events[-1]) - event_time(events[0])).total_seconds() / 60)
    else:
        active_minutes = 1.0

    severe_covered, severe_total = severe_suppression_coverage(events, severe_events)
    accepted_then_deleted_count = len({acceptance_key(event) for event in severe_events})
    shown = len(shown_events)
    late_total = len(late_hidden) + len(late_shown)
    report = {
        "active_minutes": active_minutes,
        "shown": shown,
        "shown_per_minute": rate(shown, active_minutes),
        "dismissals": len(dismissals),
        "dismissals_per_shown": rate(len(dismissals), shown),
        "typed_over_within_one_second": typed_over_within_one_second(events),
        "accepted_then_deleted": accepted_then_deleted_count,
        "accepted_then_deleted_rate": rate(accepted_then_deleted_count, shown),
        "immediate_resurfacing": immediate_resurfacing(events),
        "late_shown": len(late_shown),
        "late_hidden": len(late_hidden),
        "late_hidden_rate": rate(len(late_hidden), late_total),
        "pause_disable": len(pause_disable),
        "pause_disable_per_shown": rate(len(pause_disable), shown),
        "severe_covered": severe_covered,
        "severe_total": severe_total,
        "severe_suppression_rate": rate(severe_covered, severe_total),
    }
    report["typed_over_within_one_second_rate"] = rate(
        report["typed_over_within_one_second"],
        shown,
    )
    report["failures"] = failures(report, args)
    return report


def failures(report, args):
    problems = []
    if report["shown_per_minute"] > args.max_shown_per_minute:
        problems.append(f"shown/min above {args.max_shown_per_minute}")
    if report["dismissals_per_shown"] > args.max_dismissals_per_shown:
        problems.append(f"dismissals/shown above {args.max_dismissals_per_shown}")
    if report["typed_over_within_one_second_rate"] > args.max_typed_over_within_1s:
        problems.append(f"typed-over within 1s above {args.max_typed_over_within_1s}")
    if report["accepted_then_deleted_rate"] > args.max_accepted_then_deleted:
        problems.append(f"accepted-then-deleted above {args.max_accepted_then_deleted}")
    if report["immediate_resurfacing"] > args.max_immediate_resurfacing:
        problems.append(f"immediate resurfacing above {args.max_immediate_resurfacing}")
    if report["late_shown"] > args.max_late_shown:
        problems.append(f"late suggestions shown above {args.max_late_shown}")
    if report["late_hidden"] + report["late_shown"] > 0:
        if report["late_hidden_rate"] < args.min_late_hidden_rate:
            problems.append(f"late suggestions hidden below {args.min_late_hidden_rate}")
    if report["pause_disable_per_shown"] > args.max_pause_disable_per_shown:
        problems.append(f"pause/disable rate above {args.max_pause_disable_per_shown}")
    if report["severe_total"] > 0:
        if report["severe_suppression_rate"] < args.min_severe_suppression_rate:
            problems.append(f"severe suppression coverage below {args.min_severe_suppression_rate}")
    return problems


def print_report(report):
    print("Non-annoyance report")
    print(f"Gate: {'pass' if not report['failures'] else 'fail'}")
    print(f"Active writing minutes: {report['active_minutes']:.2f}")
    print(f"Shown/min: {report['shown_per_minute']:.2f} ({report['shown']} shown)")
    print(
        "Dismissals/shown: "
        f"{percent(report['dismissals_per_shown'])} ({report['dismissals']}/{report['shown']})"
    )
    print(
        "Typed-over within 1s: "
        f"{percent(report['typed_over_within_one_second_rate'])} "
        f"({report['typed_over_within_one_second']}/{report['shown']})"
    )
    print(f"Accepted-then-deleted: {report['accepted_then_deleted']}")
    print(f"Immediate resurfacing: {report['immediate_resurfacing']}")
    print(f"Late suggestions shown: {report['late_shown']}")
    total_late = report["late_hidden"] + report["late_shown"]
    print(
        "Late suggestions hidden: "
        f"{report['late_hidden']}/{total_late} ({percent(report['late_hidden_rate'])})"
    )
    print(f"Pause/disable events: {report['pause_disable']}")
    print(
        "Severe suppression coverage: "
        f"{report['severe_covered']}/{report['severe_total']} "
        f"({percent(report['severe_suppression_rate'])})"
    )
    print(f"Failures: {'none' if not report['failures'] else '; '.join(report['failures'])}")


def main():
    args = parse_args()
    events = load_events(args.trace, args.start_line, args.end_line)
    report = compute_report(events, args)
    print_report(report)
    if report["failures"] and not args.no_gate:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
