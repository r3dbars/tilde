#!/usr/bin/env python3
import argparse
import json
import os
import sys
from collections import Counter, defaultdict


def render_mode(event):
    metadata = event.get("metadata") or {}
    return metadata.get("effectiveRenderMode") or metadata.get("renderMode") or "unknown"


def safe_int(value, default=None):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def load_events(path, start_line):
    events = []
    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            line = line.strip()
            if not line:
                continue
            events.append(json.loads(line))
    return events


def summarize(events):
    buckets = defaultdict(lambda: {
        "shown_ids": set(),
        "caret_failures": 0,
        "missing_caret": 0,
        "flicker": 0,
        "learning_applied": 0,
        "latest_offset": "none",
    })
    failure_reasons = Counter()
    seen_presented = set()

    for event in events:
        app = event.get("appBundleIdentifier") or "unknown"
        mode = render_mode(event)
        key = (app, mode)
        metadata = event.get("metadata") or {}
        event_type = event.get("type")

        if event_type == "suggestionPresented":
            suggestion_id = event.get("suggestionID") or ""
            if suggestion_id and suggestion_id in seen_presented:
                continue
            if suggestion_id:
                seen_presented.add(suggestion_id)
            buckets[key]["shown_ids"].add(suggestion_id or f"line-{len(seen_presented)}")
            if metadata.get("hasCaretRect") == "false":
                buckets[key]["missing_caret"] += 1
            if metadata.get("learningApplied") == "true":
                buckets[key]["learning_applied"] += 1
            if metadata.get("learningXOffset") is not None and metadata.get("learningYOffset") is not None:
                buckets[key]["latest_offset"] = f"({metadata['learningXOffset']}, {metadata['learningYOffset']})"
        elif event_type == "caretGeometryFailed":
            buckets[key]["caret_failures"] += 1
            failure_reasons[event.get("reason") or "unknown"] += 1
        elif event_type == "suggestionHidden":
            lifetime = safe_int(metadata.get("lifetimeMs"))
            if lifetime is not None and lifetime < 150:
                buckets[key]["flicker"] += 1

    return buckets, failure_reasons


def format_rows(buckets):
    rows = []
    for (app, mode), values in buckets.items():
        shown = len(values["shown_ids"])
        failures = values["caret_failures"]
        denominator = shown + failures
        rate = 0 if denominator == 0 else round((failures / denominator) * 100)
        rows.append((
            -failures,
            app,
            mode,
            f"  {app} / {mode}: shown={shown} caretFailures={failures} "
            f"failureRate={rate}% missingCaret={values['missing_caret']} "
            f"flicker={values['flicker']} learningApplied={values['learning_applied']} "
            f"latestOffset={values['latest_offset']}"
        ))
    return [row[-1] for row in sorted(rows)]


def main():
    parser = argparse.ArgumentParser(
        description="Summarize visual placement calibration from redacted trace geometry."
    )
    parser.add_argument(
        "--log",
        default="~/Library/Logs/AutocompleteLab/traces.jsonl",
        help="Trace JSONL path. Defaults to the local redacted trace.",
    )
    parser.add_argument("--start-line", type=int, default=0)
    parser.add_argument("--require-app", default="")
    args = parser.parse_args()

    path = os.path.expanduser(args.log)
    try:
        events = load_events(path, args.start_line)
    except FileNotFoundError:
        print(f"trace log missing: {path}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as error:
        print(f"invalid JSONL: {error}", file=sys.stderr)
        return 1

    if args.require_app:
        events = [event for event in events if event.get("appBundleIdentifier") == args.require_app]
        if not events:
            print(f"missing required app in visual calibration slice: {args.require_app}", file=sys.stderr)
            return 1

    buckets, failure_reasons = summarize(events)
    rows = format_rows(buckets)

    print("Visual calibration report (no screenshots required)")
    print(f"Trace: {path}")
    print(f"Start line: {args.start_line}")
    print("Screenshots: not read, linked, or required")
    print("App/render calibration:")
    if rows:
        print("\n".join(rows))
    else:
        print("  none")
    print("Caret failure reasons:")
    if failure_reasons:
        for reason, count in failure_reasons.most_common():
            print(f"  {reason}: {count}")
    else:
        print("  none")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
