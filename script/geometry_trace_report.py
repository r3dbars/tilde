#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_TRACE_PATH = Path.home() / "Library/Logs/AutocompleteLab/traces.jsonl"
ANCHOR_SOURCES = ("caret", "synthetic-caret", "line", "field", "element", "window", "none")
ANCHOR_QUALITIES = ("trusted", "usableFallback", "diagnosticsOnly", "invalid")
REQUIRED_LAYOUT_LANES = (
    "mirrored-display",
    "vertical-multi-display",
    "fullscreen-space",
    "narrow-window",
    "scrolled-text",
    "wrapped-line",
    "multiple-editables",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize Autocomplete Lab geometry and anchor trace proof."
    )
    parser.add_argument(
        "--trace",
        default=os.environ.get("AUTOCOMPLETE_LAB_TRACE_PATH", str(DEFAULT_TRACE_PATH)),
        help="Path to traces.jsonl.",
    )
    parser.add_argument(
        "--start-line",
        type=int,
        default=int(os.environ.get("AUTOCOMPLETE_LAB_TRACE_START_LINE", "0") or "0"),
        help="Skip trace lines up to this 1-based line number.",
    )
    parser.add_argument(
        "--require-proof",
        action="store_true",
        help="Exit nonzero if any presented suggestion lacks safe geometry proof.",
    )
    parser.add_argument(
        "--require-layout-lanes",
        action="store_true",
        help="Exit nonzero unless all weird desktop geometry proof lanes are present.",
    )
    return parser.parse_args()


def load_events(path: Path, start_line: int) -> list[dict]:
    if not path.exists():
        raise SystemExit(f"trace log is missing: {path}")

    events = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line or not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            event["_lineNumber"] = line_number
            events.append(event)
    return events


def metadata(event: dict) -> dict:
    value = event.get("metadata")
    return value if isinstance(value, dict) else {}


def metadata_value(event: dict, key: str) -> str:
    value = metadata(event).get(key)
    return value.strip() if isinstance(value, str) else ""


def bool_metadata(event: dict, key: str) -> bool | None:
    value = metadata_value(event, key).lower()
    if value == "true":
        return True
    if value == "false":
        return False
    return None


def anchor_source(event: dict) -> str:
    return metadata_value(event, "anchorSource") or metadata_value(event, "placementAnchorSource")


def anchor_quality(event: dict) -> str:
    explicit = metadata_value(event, "anchorQuality")
    if explicit:
        return explicit

    confidence = metadata_value(event, "placementConfidenceBand")
    if confidence == "high":
        return "trusted"
    if confidence == "medium":
        return "usableFallback"
    if confidence == "low":
        return "diagnosticsOnly"
    if confidence == "none":
        return "invalid"

    return ""


def anchor_reason(event: dict) -> str:
    return metadata_value(event, "anchorReason") or metadata_value(event, "placementHealthReason")


def anchor_can_present(event: dict, source: str, quality: str) -> bool | None:
    explicit = bool_metadata(event, "anchorCanPresent")
    if explicit is not None:
        return explicit

    if not source or not quality:
        return None

    return (
        source not in {"window", "none"}
        and quality not in {"invalid", "diagnosticsOnly"}
    )


def has_anchor_metadata(event: dict) -> bool:
    meta = metadata(event)
    return any(
        key in meta
        for key in (
            "anchorSource",
            "anchorQuality",
            "anchorReason",
            "anchorCanPresent",
            "placementAnchorSource",
            "placementConfidenceBand",
            "placementHealthReason",
        )
    )


def has_rect_metadata(event: dict) -> bool:
    value = metadata_value(event, "anchorRect")
    return bool(value) and value != "none"


def geometry_lanes(event: dict) -> set[str]:
    lanes = set()
    for key in ("geometryProofLane", "displayLayoutVariant"):
        value = metadata_value(event, key)
        if value and value != "standard":
            lanes.add(value)

    multi_value = metadata_value(event, "geometryProofLanes")
    for lane in multi_value.replace(";", ",").split(","):
        lane = lane.strip()
        if lane:
            lanes.add(lane)

    return lanes


def proof_failures(event: dict) -> list[str]:
    if event.get("type") != "suggestionPresented":
        return []

    app = event.get("appBundleIdentifier") or "unknown"
    suggestion_id = event.get("suggestionID") or "unknown"
    line = event.get("_lineNumber", "?")
    label = f"line {line} {app}/{suggestion_id}"
    source = anchor_source(event)
    quality = anchor_quality(event)
    reason = anchor_reason(event)
    can_present = anchor_can_present(event, source, quality)
    failures = []

    if not source:
        failures.append(f"{label}: missing anchorSource")
    elif source not in ANCHOR_SOURCES:
        failures.append(f"{label}: unknown anchorSource {source}")

    if not quality:
        failures.append(f"{label}: missing anchorQuality")
    elif quality not in ANCHOR_QUALITIES:
        failures.append(f"{label}: unknown anchorQuality {quality}")

    if not reason:
        failures.append(f"{label}: missing anchorReason")

    if can_present is not True:
        failures.append(f"{label}: anchorCanPresent is not true")

    if quality in {"invalid", "diagnosticsOnly"}:
        failures.append(f"{label}: presented with {quality} anchor")

    if source in {"window", "none"}:
        failures.append(f"{label}: presented with {source} anchor")

    if not has_rect_metadata(event):
        failures.append(f"{label}: missing anchorRect")

    if metadata_value(event, "geometryInvalidated").lower() == "true":
        reason = metadata_value(event, "geometryInvalidationReason") or "unknown"
        failures.append(f"{label}: presented after geometry invalidation {reason}")

    invalidation_reason = metadata_value(event, "geometryInvalidationReason")
    if invalidation_reason and invalidation_reason != "none":
        failures.append(f"{label}: presented with stale geometry reason {invalidation_reason}")

    if source in {"caret", "synthetic-caret"} and bool_metadata(event, "hasCaretRect") is not True:
        failures.append(f"{label}: {source} anchor without hasCaretRect")
    if source == "line" and bool_metadata(event, "hasTextLineRect") is not True:
        failures.append(f"{label}: line anchor without hasTextLineRect")
    if source in {"field", "element"} and bool_metadata(event, "hasElementRect") is not True:
        failures.append(f"{label}: {source} anchor without hasElementRect")

    return failures


def sorted_counter(counter: Counter) -> str:
    if not counter:
        return "-"
    return ", ".join(f"{key}={value}" for key, value in sorted(counter.items()))


def build_report(events: list[dict]) -> tuple[str, list[str]]:
    app_source_counts: dict[str, Counter] = defaultdict(Counter)
    app_quality_counts: dict[str, Counter] = defaultdict(Counter)
    app_reason_counts: dict[str, Counter] = defaultdict(Counter)
    app_presented_counts: Counter = Counter()
    app_failure_counts: Counter = Counter()
    failures = []
    anchor_metadata_count = 0
    layout_lanes_seen: Counter = Counter()
    stale_geometry_suppression_counts: Counter = Counter()

    for event in events:
        app = event.get("appBundleIdentifier") or "unknown"
        for lane in geometry_lanes(event):
            layout_lanes_seen[lane] += 1

        if event.get("type") == "suggestionHidden":
            reason = event.get("reason") or metadata_value(event, "reason")
            if reason.startswith("stale-geometry"):
                stale_geometry_suppression_counts[reason] += 1

        if has_anchor_metadata(event):
            anchor_metadata_count += 1
            source = anchor_source(event) or "missing"
            quality = anchor_quality(event) or "missing"
            reason = anchor_reason(event) or "missing"
            app_source_counts[app][source] += 1
            app_quality_counts[app][quality] += 1
            app_reason_counts[app][reason] += 1

        if event.get("type") == "suggestionPresented":
            app_presented_counts[app] += 1
            event_failures = proof_failures(event)
            failures.extend(event_failures)
            app_failure_counts[app] += len(event_failures)

    apps = sorted(
        set(app_presented_counts)
        | set(app_source_counts)
        | set(app_quality_counts)
        | set(app_reason_counts)
    )

    lines = [
        "# Geometry Trace Report",
        "",
        f"- Events scanned: {len(events)}",
        f"- Anchor metadata events: {anchor_metadata_count}",
        f"- Presented suggestions: {sum(app_presented_counts.values())}",
        f"- Geometry proof failures: {len(failures)}",
        f"- Layout proof lanes: {sorted_counter(layout_lanes_seen)}",
        f"- Stale geometry suppressions: {sorted_counter(stale_geometry_suppression_counts)}",
        "",
        "## App Summary",
        "",
        "| App | Presented | Anchor sources | Anchor qualities | Anchor reasons | Failures |",
        "| --- | ---: | --- | --- | --- | ---: |",
    ]

    if apps:
        for app in apps:
            lines.append(
                "| {app} | {presented} | {sources} | {qualities} | {reasons} | {failures} |".format(
                    app=app,
                    presented=app_presented_counts[app],
                    sources=sorted_counter(app_source_counts[app]),
                    qualities=sorted_counter(app_quality_counts[app]),
                    reasons=sorted_counter(app_reason_counts[app]),
                    failures=app_failure_counts[app],
                )
            )
    else:
        lines.append("| none | 0 | - | - | - | 0 |")

    lines.extend(["", "## Failures", ""])
    if failures:
        lines.extend(f"- {failure}" for failure in failures[:25])
        if len(failures) > 25:
            lines.append(f"- ...and {len(failures) - 25} more")
    else:
        lines.append("- none")

    return "\n".join(lines), failures


def main() -> int:
    args = parse_args()
    events = load_events(Path(args.trace), args.start_line)
    report, failures = build_report(events)
    print(report)

    if args.require_proof and failures:
        return 1

    if args.require_layout_lanes:
        lanes_seen = Counter()
        for event in events:
            for lane in geometry_lanes(event):
                lanes_seen[lane] += 1
        missing = [lane for lane in REQUIRED_LAYOUT_LANES if lane not in lanes_seen]
        if missing:
            print(
                "missing required geometry layout lanes: " + ", ".join(missing),
                file=sys.stderr,
            )
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
