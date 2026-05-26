#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_TRACE = Path.home() / "Library/Logs/SteadyType/traces.jsonl"

SAFE_METADATA_KEYS = {
    "acceptMode",
    "acceptanceID",
    "annoyanceSignal",
    "checkpoint",
    "deletedWithinTwoSeconds",
    "displayDecision",
    "finalAcceptedAndKept",
    "finishReason",
    "firstEditDelayMs",
    "lateSuggestion",
    "prefixCooldownReason",
    "staleLateSuggestion",
    "strongAcceptedAndKept",
    "suppressionReason",
    "survivalClass",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize SteadyType typing feel from a redacted trace JSONL."
    )
    parser.add_argument(
        "trace",
        nargs="?",
        default=os.environ.get("AUTOCOMPLETE_LAB_TRACE_PATH", str(DEFAULT_TRACE)),
    )
    parser.add_argument(
        "--start-line",
        type=int,
        default=int(os.environ.get("AUTOCOMPLETE_LAB_TRACE_START_LINE", "0")),
    )
    parser.add_argument(
        "--end-line",
        type=int,
        default=(
            int(os.environ["AUTOCOMPLETE_LAB_TRACE_END_LINE"])
            if os.environ.get("AUTOCOMPLETE_LAB_TRACE_END_LINE")
            else None
        ),
    )
    parser.add_argument(
        "--app",
        default=os.environ.get("AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP", ""),
        help="Optional app bundle filter for a single dogfood surface.",
    )
    parser.add_argument("--json", action="store_true", help="Print a redacted JSON summary.")
    parser.add_argument(
        "--late-ms",
        type=int,
        default=750,
        help="First-visible latency above this is counted as late.",
    )
    parser.add_argument(
        "--resurface-window-seconds",
        type=float,
        default=2.0,
        help="Shown events inside this window after rejection count as immediate resurfacing.",
    )
    parser.add_argument(
        "--target-shown-per-minute",
        type=float,
        default=2.0,
        help="Soft target used only for the 0-100 score.",
    )
    parser.add_argument(
        "--fail-under",
        type=int,
        help="Exit non-zero when the typing feel score is below this value.",
    )
    return parser.parse_args()


def load_events(path: str, start_line: int, end_line: int | None) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
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
                event = json.loads(line)
            except json.JSONDecodeError as error:
                raise SystemExit(f"invalid JSONL on line {line_number}: {error}") from error
            events.append(redacted_event(event, line_number))
    return sorted(events, key=event_time)


def redacted_event(event: dict[str, Any], line_number: int) -> dict[str, Any]:
    metadata = event.get("metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}
    safe_metadata = {
        key: str(value)
        for key, value in metadata.items()
        if key in SAFE_METADATA_KEYS
    }
    return {
        "_line": line_number,
        "type": str(event.get("type") or ""),
        "timestamp": str(event.get("timestamp") or ""),
        "suggestionID": str(event.get("suggestionID") or event.get("id") or ""),
        "appBundleIdentifier": str(event.get("appBundleIdentifier") or ""),
        "fieldIdentity": str(event.get("fieldIdentity") or ""),
        "requestMode": str(event.get("requestMode") or ""),
        "triggerReason": str(event.get("triggerReason") or ""),
        "latencyMilliseconds": event.get("latencyMilliseconds"),
        "outcome": str(event.get("outcome") or ""),
        "reason": str(event.get("reason") or ""),
        "metadata": safe_metadata,
    }


def event_time(event: dict[str, Any]) -> datetime:
    value = event.get("timestamp") or ""
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def safe_int(value: Any, default: int | None = None) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def truthy(value: Any) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def rate(numerator: int | float, denominator: int | float) -> float:
    return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


def percent(value: float) -> str:
    return f"{round(value * 100):.0f}%"


def event_type(event: dict[str, Any]) -> str:
    return event.get("type") or ""


def suggestion_key(event: dict[str, Any]) -> str:
    return event.get("suggestionID") or f"line:{event.get('_line')}"


def acceptance_key(event: dict[str, Any]) -> str:
    metadata = event.get("metadata") or {}
    return metadata.get("acceptanceID") or suggestion_key(event)


def same_surface(left: dict[str, Any], right: dict[str, Any]) -> bool:
    return (
        left.get("appBundleIdentifier") == right.get("appBundleIdentifier")
        and left.get("fieldIdentity") == right.get("fieldIdentity")
        and left.get("requestMode") == right.get("requestMode")
    )


def first_presented(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    shown: list[dict[str, Any]] = []
    seen: set[str] = set()
    for event in events:
        if event_type(event) != "suggestionPresented":
            continue
        key = suggestion_key(event)
        if key in seen:
            continue
        seen.add(key)
        shown.append(event)
    return shown


def kept_event(event: dict[str, Any]) -> bool:
    metadata = event.get("metadata") or {}
    if truthy(metadata.get("strongAcceptedAndKept")) or truthy(metadata.get("finalAcceptedAndKept")):
        return True
    if metadata.get("checkpoint") not in {"10s", "30s", "1m", "5m", "fieldBlur", "fieldSend"}:
        return False
    return metadata.get("survivalClass") in {
        "exactKept",
        "lightlyEditedKept",
        "partiallyKept",
    }


def typed_over_event(event: dict[str, Any]) -> bool:
    joined = " ".join([event.get("type", ""), event.get("reason", ""), event.get("outcome", "")]).lower()
    return event_type(event) == "suggestionTypedOver" or "typed-over" in joined or "typed-through" in joined


def dismissal_event(event: dict[str, Any]) -> bool:
    joined = " ".join([event.get("reason", ""), event.get("outcome", "")]).lower()
    return event_type(event) == "suggestionHidden" and (
        event.get("reason") == "escape"
        or "escape" in joined
        or "dismiss" in joined
    )


def accepted_then_deleted_event(event: dict[str, Any]) -> bool:
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
    compact = joined.replace("-", "").replace("_", "").replace(" ", "")
    if "acceptedthendeleted" in compact:
        return True
    if truthy(metadata.get("deletedWithinTwoSeconds")):
        return True
    if event_type(event) == "acceptedTextEdited":
        if metadata.get("survivalClass") == "rejectedAfterAccept":
            first_edit_delay = safe_int(metadata.get("firstEditDelayMs"), 999_999)
            return first_edit_delay <= 2_000 or metadata.get("checkpoint") == "2s"
        return metadata.get("survivalClass") in {"immediateDeletion", "deletedAfterAccept"}
    if event_type(event) == "acceptanceRetentionCleared":
        return "deleted" in joined
    return False


def late_shown_event(event: dict[str, Any], late_ms: int) -> bool:
    metadata = event.get("metadata") or {}
    latency = safe_int(event.get("latencyMilliseconds"), 0) or 0
    if latency > late_ms:
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


def immediate_resurfacing_count(
    events: list[dict[str, Any]],
    shown_keys: set[str],
    window_seconds: float,
) -> int:
    rejections: list[dict[str, Any]] = []
    count = 0

    for event in events:
        current_time = event_time(event)
        if event_type(event) == "suggestionPresented":
            key = suggestion_key(event)
            if key in shown_keys:
                if any(
                    same_surface(rejection, event)
                    and 0 < (current_time - event_time(rejection)).total_seconds() <= window_seconds
                    for rejection in rejections
                ):
                    count += 1
            rejections = [
                rejection
                for rejection in rejections
                if (current_time - event_time(rejection)).total_seconds() <= window_seconds
            ]
            continue

        if typed_over_event(event) or dismissal_event(event) or accepted_then_deleted_event(event):
            rejections.append(event)

    return count


def active_minutes(events: list[dict[str, Any]]) -> float:
    dates = [event_time(event) for event in events if event.get("timestamp")]
    if not dates:
        return 1.0
    seconds = (max(dates) - min(dates)).total_seconds()
    return max(1.0, seconds / 60.0)


def score_for(report: dict[str, Any], target_shown_per_minute: float) -> int:
    shown = report["shown"]
    accepted = report["accepted"]
    insertion_attempts = report["insertion_failures"] + report["insertion_verified"]
    insertion_failure_rate = rate(report["insertion_failures"], insertion_attempts or shown)
    caret_failure_rate = rate(report["caret_failures"], shown + report["caret_failures"])
    pause_disable_rate = rate(report["pause_disable_events"], shown)
    late_shown_rate = rate(report["late_shown_suggestions"], shown)
    resurfacing_rate = rate(report["immediate_resurfacing"], shown)
    accepted_then_deleted_rate = rate(report["accepted_then_deleted"], accepted or shown)

    penalty = 0.0
    if report["shown_per_minute"] > target_shown_per_minute:
        penalty += min(10.0, (report["shown_per_minute"] - target_shown_per_minute) * 4.0)
    if accepted > 0:
        target_kept_accepted = 0.70
        kept_gap = max(0.0, target_kept_accepted - report["accepted_and_kept_accepted_rate"])
        penalty += min(15.0, (kept_gap / target_kept_accepted) * 15.0)
    penalty += min(20.0, report["typed_over_rate"] * 40.0)
    penalty += min(20.0, accepted_then_deleted_rate * 60.0)
    penalty += min(15.0, resurfacing_rate * 40.0)
    penalty += min(15.0, late_shown_rate * 35.0)
    penalty += min(20.0, insertion_failure_rate * 70.0)
    penalty += min(15.0, caret_failure_rate * 45.0)
    penalty += min(10.0, pause_disable_rate * 25.0)
    return max(0, min(100, round(100.0 - penalty)))


def compute_report(events: list[dict[str, Any]], args: argparse.Namespace) -> dict[str, Any]:
    shown_events = first_presented(events)
    shown_ids = {suggestion_key(event) for event in shown_events}
    accepted_events = [event for event in events if event_type(event) == "suggestionAccepted"]
    accepted_ids = {acceptance_key(event) for event in accepted_events}
    kept_events = [
        event
        for event in events
        if event_type(event) == "acceptedTextEdited" and kept_event(event)
    ]
    kept_acceptance_ids = {acceptance_key(event) for event in kept_events}
    kept_suggestion_ids = {suggestion_key(event) for event in kept_events}
    typed_over_ids = {
        suggestion_key(event)
        for event in events
        if typed_over_event(event)
    }
    accepted_deleted_ids = {
        acceptance_key(event)
        for event in events
        if accepted_then_deleted_event(event)
    }
    late_shown_ids = {
        suggestion_key(event)
        for event in events
        if event_type(event) == "suggestionPresented" and late_shown_event(event, args.late_ms)
    }
    event_counts = Counter(event_type(event) for event in events)
    minutes = active_minutes(events)
    shown = len(shown_events)
    accepted = len(accepted_ids)

    report: dict[str, Any] = {
        "report": "typing_feel_score",
        "privacy": "redacted",
        "events": len(events),
        "active_minutes": minutes,
        "shown": shown,
        "shown_per_minute": rate(shown, minutes),
        "accepted": accepted,
        "accepted_and_kept": len(kept_acceptance_ids),
        "accepted_and_kept_shown_rate": rate(len(kept_suggestion_ids.intersection(shown_ids)), shown),
        "accepted_and_kept_shown_numerator": len(kept_suggestion_ids.intersection(shown_ids)),
        "accepted_and_kept_accepted_rate": rate(len(kept_acceptance_ids.intersection(accepted_ids)), accepted),
        "accepted_and_kept_accepted_numerator": len(kept_acceptance_ids.intersection(accepted_ids)),
        "typed_over": len(typed_over_ids),
        "typed_over_rate": rate(len(typed_over_ids), shown),
        "accepted_then_deleted": len(accepted_deleted_ids),
        "immediate_resurfacing": immediate_resurfacing_count(
            events,
            shown_ids,
            args.resurface_window_seconds,
        ),
        "late_shown_suggestions": len(late_shown_ids.intersection(shown_ids)),
        "insertion_failures": event_counts["insertionFailed"],
        "insertion_verified": event_counts["insertionVerified"],
        "caret_failures": event_counts["caretGeometryFailed"],
        "pause_events": event_counts["appPaused"] + event_counts["fieldPaused"],
        "disable_events": event_counts["appDisabled"],
        "pause_disable_events": (
            event_counts["appPaused"] + event_counts["fieldPaused"] + event_counts["appDisabled"]
        ),
    }
    report["score"] = score_for(report, args.target_shown_per_minute)
    return report


def score_drivers(report: dict[str, Any]) -> list[str]:
    drivers: list[tuple[float, str]] = []
    shown = report["shown"]
    accepted = report["accepted"]
    if report["insertion_failures"]:
        drivers.append((100.0, f"{report['insertion_failures']} insertion failure(s)"))
    if report["accepted_then_deleted"]:
        drivers.append((90.0, f"{report['accepted_then_deleted']} accepted-then-deleted"))
    if report["caret_failures"]:
        drivers.append((80.0, f"{report['caret_failures']} caret failure(s)"))
    if report["immediate_resurfacing"]:
        drivers.append((70.0, f"{report['immediate_resurfacing']} immediate resurfacing event(s)"))
    if report["late_shown_suggestions"]:
        drivers.append((60.0, f"{report['late_shown_suggestions']} late shown suggestion(s)"))
    if report["pause_disable_events"]:
        drivers.append((50.0, f"{report['pause_disable_events']} pause/disable event(s)"))
    if shown and report["typed_over_rate"] > 0:
        drivers.append((40.0, f"{percent(report['typed_over_rate'])} typed-over rate"))
    if accepted and report["accepted_and_kept_accepted_rate"] < 0.7:
        drivers.append((30.0, f"{percent(report['accepted_and_kept_accepted_rate'])} kept / accepted"))
    return [label for _, label in sorted(drivers, reverse=True)[:3]]


def print_report(report: dict[str, Any]) -> None:
    print("Typing feel score report")
    print("Privacy: redacted aggregate counts/rates only")
    print(f"Events: {report['events']}")
    print(f"Typing feel score: {report['score']}/100")
    print(f"Active writing minutes: {report['active_minutes']:.2f}")
    print(f"Shown/min: {report['shown_per_minute']:.2f} ({report['shown']} shown)")
    print(
        "Accepted-and-kept shown rate: "
        f"{percent(report['accepted_and_kept_shown_rate'])} "
        f"({report['accepted_and_kept_shown_numerator']}/{report['shown']})"
    )
    print(
        "Accepted-and-kept accepted rate: "
        f"{percent(report['accepted_and_kept_accepted_rate'])} "
        f"({report['accepted_and_kept_accepted_numerator']}/{report['accepted']})"
    )
    print(
        "Typed-over rate: "
        f"{percent(report['typed_over_rate'])} ({report['typed_over']}/{report['shown']})"
    )
    print(f"Accepted-then-deleted: {report['accepted_then_deleted']}")
    print(f"Immediate resurfacing: {report['immediate_resurfacing']}")
    print(f"Late shown suggestions: {report['late_shown_suggestions']}")
    print(f"Insertion failures: {report['insertion_failures']}")
    print(f"Caret failures: {report['caret_failures']}")
    print(
        "Pause/disable events: "
        f"{report['pause_disable_events']} "
        f"({report['pause_events']} pause, {report['disable_events']} disable)"
    )
    drivers = score_drivers(report)
    print(f"Main drags: {'none' if not drivers else '; '.join(drivers)}")


def main() -> int:
    args = parse_args()
    if not Path(args.trace).is_file():
        raise SystemExit(f"trace log missing: {args.trace}")

    events = load_events(args.trace, args.start_line, args.end_line)
    if args.app:
        events = [
            event for event in events
            if event.get("appBundleIdentifier") == args.app
        ]
    if not events:
        raise SystemExit("trace slice is empty")

    report = compute_report(events, args)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_report(report)

    if args.fail_under is not None and report["score"] < args.fail_under:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
