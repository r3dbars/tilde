#!/usr/bin/env python3
import argparse
import json
import os
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_TRACE_PATH = Path.home() / "Library/Logs/AutocompleteLab/traces.jsonl"
DEFAULT_LEARNING_PATH = (
    Path.home()
    / "Library/Application Support/AutocompleteLab/compatibility-learning.json"
)
NUDGE_STEP_PIXELS = 2.0
CODE_PROMOTION_REASONS = {"manual-visual-nudge", "screenshot-visual-correction"}


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


def counter_summary(values):
    if not values:
        return "none"
    return ", ".join(f"{key}={value}" for key, value in values.items())


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
        for item in report["visualNudgeCandidates"]:
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
        for item in report["codePromotionCandidates"]:
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
        for item in report["detachedSuppressionCandidates"]:
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
    else:
        lines.append("  none")

    lines.extend(
        [
            "",
            "No screenshots, calibration, or new trace capture were started.",
        ]
    )
    return "\n".join(lines)


def build_report(args):
    learning_path = Path(args.learning_path).expanduser()
    trace_path = Path(args.trace_path).expanduser()
    profiles = load_learning_profiles(learning_path)
    events = load_trace_events(trace_path, args.start_line)
    return {
        "learningPath": str(learning_path),
        "tracePath": str(trace_path),
        "startLine": args.start_line,
        "minimumNudgeSteps": args.min_nudge_steps,
        "minimumDetachedSuppressions": args.min_detached_suppressions,
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
    }


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
