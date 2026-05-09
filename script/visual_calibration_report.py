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


def safe_float(value, default=0.0):
    try:
        return float(value)
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


def load_diagnostics(path, start_line):
    records = []
    if not path or not os.path.exists(path):
        return records

    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            parts = line.strip().split()
            if len(parts) < 2:
                continue
            metadata = {}
            for field in parts[2:]:
                if "=" not in field:
                    continue
                key, value = field.split("=", 1)
                metadata[key] = value
            records.append({"event": parts[1], "metadata": metadata})
    return records


def trust_status(metadata):
    status = metadata.get("learningVisualOffsetStatus")
    if status:
        return status
    trusted = metadata.get("learningVisualOffsetTrusted")
    if trusted == "true":
        return "applied"
    if trusted == "false":
        return "refused"
    return "none"


def summarize(events):
    buckets = defaultdict(lambda: {
        "shown_ids": set(),
        "caret_failures": 0,
        "missing_caret": 0,
        "flicker": 0,
        "learning_applied": 0,
        "latest_offset": "none",
        "trusted_applied": 0,
        "trusted_refused": 0,
        "refused_reasons": Counter(),
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
            status = trust_status(metadata)
            if status == "applied":
                buckets[key]["trusted_applied"] += 1
            elif status == "refused":
                buckets[key]["trusted_refused"] += 1
                buckets[key]["refused_reasons"][metadata.get("learningVisualOffsetReason") or "unknown"] += 1
        elif event_type == "caretGeometryFailed":
            buckets[key]["caret_failures"] += 1
            failure_reasons[event.get("reason") or "unknown"] += 1
        elif event_type == "suggestionHidden":
            lifetime = safe_int(metadata.get("lifetimeMs"))
            if lifetime is not None and lifetime < 150:
                buckets[key]["flicker"] += 1

    return buckets, failure_reasons


def reason_summary(counter):
    if not counter:
        return "none"
    return ",".join(f"{reason}:{count}" for reason, count in counter.most_common())


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
            f"latestOffset={values['latest_offset']} "
            f"trustedCorrection=applied:{values['trusted_applied']} "
            f"refused:{values['trusted_refused']} "
            f"refusedReasons={reason_summary(values['refused_reasons'])}"
        ))
    return [row[-1] for row in sorted(rows)]


def summarize_diagnostics(records):
    buckets = defaultdict(lambda: {
        "applied": 0,
        "refused": 0,
        "improved": 0,
        "best_improvement": 0.0,
        "refused_reasons": Counter(),
        "bad_detections": Counter(),
        "privacy": Counter(),
    })

    for record in records:
        if record["event"] != "screenshot-captured":
            continue
        metadata = record["metadata"]
        app = metadata.get("app") or "unknown"
        correction = metadata.get("screenshotOffsetCorrection")
        proof = metadata.get("screenshotOffsetProof")
        if not correction and not proof:
            continue

        values = buckets[app]
        if correction in {"accepted", "clamped"}:
            values["applied"] += 1
        else:
            values["refused"] += 1
            reason = (
                metadata.get("screenshotOffsetCorrectionReason")
                or metadata.get("screenshotOffsetBadDetection")
                or correction
                or "unknown"
            )
            values["refused_reasons"][reason] += 1

        if proof == "improved":
            values["improved"] += 1
        values["best_improvement"] = max(
            values["best_improvement"],
            safe_float(metadata.get("screenshotOffsetImprovement")),
        )
        if metadata.get("screenshotOffsetBadDetection"):
            values["bad_detections"][metadata["screenshotOffsetBadDetection"]] += 1
        if metadata.get("screenshotOffsetProofPrivacy"):
            values["privacy"][metadata["screenshotOffsetProofPrivacy"]] += 1

    return buckets


def format_diagnostic_rows(buckets):
    rows = []
    for app, values in buckets.items():
        rows.append((
            -(values["applied"] + values["refused"]),
            app,
            f"  {app}: applied={values['applied']} refused={values['refused']} "
            f"improved={values['improved']} "
            f"bestImprovement={values['best_improvement']:.1f} "
            f"refusedReasons={reason_summary(values['refused_reasons'])} "
            f"badDetections={reason_summary(values['bad_detections'])} "
            f"privacy={reason_summary(values['privacy'])}"
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
    parser.add_argument(
        "--diagnostics-log",
        default="~/Library/Logs/AutocompleteLab/diagnostics.log",
        help="Diagnostics log path used for geometry-only screenshot correction proof.",
    )
    parser.add_argument("--start-line", type=int, default=0)
    parser.add_argument("--diagnostics-start-line", type=int, default=0)
    parser.add_argument("--require-app", default="")
    args = parser.parse_args()

    path = os.path.expanduser(args.log)
    diagnostics_path = os.path.expanduser(args.diagnostics_log)
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
    diagnostic_rows = format_diagnostic_rows(
        summarize_diagnostics(load_diagnostics(diagnostics_path, args.diagnostics_start_line))
    )

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
    print("Screenshot correction proof:")
    if diagnostic_rows:
        print("\n".join(diagnostic_rows))
    else:
        print("  none")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
