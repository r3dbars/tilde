#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


DEFAULT_TRACE = Path.home() / "Library/Logs/SteadyType/traces.jsonl"


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def percent(value):
    return f"{round(value * 100)}%"


def experiment_arm(event):
    metadata = event.get("metadata") or {}
    return event.get("experimentArm") or metadata.get("experimentArm") or "unknown"


def metadata_int(event, key):
    try:
        return int((event.get("metadata") or {}).get(key))
    except (TypeError, ValueError):
        return None


def kept_event(event):
    metadata = event.get("metadata") or {}
    if metadata.get("strongAcceptedAndKept") == "true" or metadata.get("finalAcceptedAndKept") == "true":
        return True
    if metadata.get("checkpoint") not in {"10s", "30s", "1m", "5m", "fieldBlur", "fieldSend"}:
        return False
    return metadata.get("survivalClass") in {"exactKept", "lightlyEditedKept", "partiallyKept"}


def duplicate_failure(event):
    metadata = event.get("metadata") or {}
    return (
        metadata.get("duplicateDetected") == "true"
        or "duplicate" in (event.get("reason") or "").lower()
        or "duplicate" in (event.get("outcome") or "").lower()
    )


def severe_annoyance_count(events, presented_by_id):
    count = 0
    for event in events:
        metadata = event.get("metadata") or {}
        kind = metadata.get("fieldKind")
        if event.get("type") == "suggestionTypedOver":
            count += 1
        elif event.get("type") == "suggestionHidden" and event.get("reason") == "escape":
            count += 1
        elif event.get("type") == "acceptedTextEdited" and metadata.get("survivalClass") == "rejectedAfterAccept":
            count += 1
        elif event.get("type") == "insertionFailed":
            count += 1
        elif event.get("type") == "appDisabled":
            count += 1
        elif event.get("type") == "suggestionPresented" and kind in {"search", "form", "url", "secure"}:
            count += 1
    return min(1.0, count / max(1, len(presented_by_id)))


def empty_model_result(event):
    word_count = metadata_int(event, "cleanedWordCount")
    if word_count is not None:
        return word_count == 0
    cleaned = (event.get("cleanedVisibleText") or "").strip()
    raw = (event.get("rawOutput") or "").strip()
    if not cleaned and not raw:
        return False
    return not cleaned


def first_events_by_suggestion(events, event_type):
    by_id = {}
    for event in events:
        if event.get("type") != event_type:
            continue
        suggestion_id = event.get("suggestionID")
        if suggestion_id and suggestion_id not in by_id:
            by_id[suggestion_id] = event
    return by_id


def arm_report(arm, events, min_shown):
    presented_by_id = first_events_by_suggestion(events, "suggestionPresented")
    presented_ids = set(presented_by_id)
    accepted_ids = {
        event.get("suggestionID")
        for event in events
        if event.get("type") == "suggestionAccepted" and event.get("suggestionID") in presented_ids
    }
    kept_ids = {
        event.get("suggestionID")
        for event in events
        if event.get("type") == "acceptedTextEdited" and kept_event(event) and event.get("suggestionID") in presented_ids
    }
    latencies = [
        event.get("latencyMilliseconds")
        for event in presented_by_id.values()
        if isinstance(event.get("latencyMilliseconds"), int)
    ]
    insertion_verified = sum(1 for event in events if event.get("type") == "insertionVerified")
    insertion_failed = [event for event in events if event.get("type") == "insertionFailed"]
    insertion_attempts = insertion_verified + len(insertion_failed)
    insertion_success = 0 if insertion_attempts == 0 else insertion_verified / insertion_attempts
    duplicate_count = sum(1 for event in insertion_failed if duplicate_failure(event))
    duplicate_rate = 0 if not presented_by_id else duplicate_count / len(presented_by_id)
    app_disable_count = sum(1 for event in events if event.get("type") == "appDisabled")
    app_disable_rate = 0 if not presented_by_id else app_disable_count / len(presented_by_id)
    annoyance = severe_annoyance_count(events, presented_by_id)
    p95 = percentile(latencies, 0.95)
    model_results = [event for event in events if event.get("type") == "modelResult"]
    empty_results = [event for event in model_results if empty_model_result(event)]
    pre_render_blocked = [
        event for event in events
        if event.get("type") == "suggestionSuppressed"
        and event.get("suggestionID") not in presented_by_id
    ]

    reasons = []
    if len(presented_by_id) < min_shown:
        reasons.append(f"sample below {min_shown}; directional only")
    if p95 is not None and p95 > 1000:
        reasons.append("p95 latency above 1000ms")
    if annoyance > 0.20:
        reasons.append("annoyance above 0.20")
    if insertion_attempts and insertion_success < 0.95:
        reasons.append("insertion success below 95%")
    if duplicate_rate > 0:
        reasons.append("duplicate rate above 0")
    if app_disable_rate > 0.02:
        reasons.append("app disable rate above 2%")

    hard_reasons = [reason for reason in reasons if not reason.startswith("sample below")]
    if not presented_by_id:
        label = "no-signal"
    elif len(presented_by_id) < min_shown:
        label = "directional"
    elif hard_reasons:
        label = "guardrail-blocked"
    else:
        label = "candidate"

    return {
        "arm": arm,
        "shown": len(presented_by_id),
        "accepted": len(accepted_ids),
        "kept": len(kept_ids),
        "kept_rate": 0 if not presented_by_id else len(kept_ids) / len(presented_by_id),
        "p95": p95,
        "annoyance": annoyance,
        "insertion_success": insertion_success,
        "duplicate_rate": duplicate_rate,
        "app_disable_rate": app_disable_rate,
        "empty_results": len(empty_results),
        "pre_render_blocked": len(pre_render_blocked),
        "pre_render_reasons": Counter(event.get("reason") or "unknown" for event in pre_render_blocked),
        "label": label,
        "reasons": reasons,
    }


def stable_bucket(value, bucket_count):
    hash_value = 14695981039346656037
    for char in value:
        hash_value ^= ord(char)
        hash_value *= 1099511628211
        hash_value &= 0xFFFFFFFFFFFFFFFF
    return hash_value % bucket_count


def crossover_order(tester):
    arms = ["length_1_word", "length_3_word"]
    bucket = stable_bucket(tester, len(arms))
    return arms[bucket:] + arms[:bucket]


def read_events(path, start_line):
    events = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line:
                continue
            line = line.strip()
            if not line:
                continue
            events.append(json.loads(line))
    return events


def main():
    parser = argparse.ArgumentParser(description="Print a local SteadyType experiment report.")
    parser.add_argument("--trace", default=str(DEFAULT_TRACE), help="trace JSONL path")
    parser.add_argument("--start-line", type=int, default=0, help="skip events through this line")
    parser.add_argument("--tester", help="show deterministic counterbalanced order for this tester")
    parser.add_argument("--min-shown", type=int, default=20, help="shown samples before an arm can be a candidate")
    args = parser.parse_args()

    trace_path = Path(args.trace).expanduser()
    if not trace_path.exists():
        raise SystemExit(f"trace log missing: {trace_path}")

    events = read_events(trace_path, args.start_line)
    if not events:
        raise SystemExit("trace slice is empty")

    events_by_arm = defaultdict(list)
    for event in events:
        events_by_arm[experiment_arm(event)].append(event)

    print("Experiment report")
    print(f"Trace: {trace_path}")
    print(f"Start line: {args.start_line}")
    if args.tester:
        print(f"Counterbalanced order for {args.tester}: {', '.join(crossover_order(args.tester))}")
    print(f"Minimum shown for candidate: {args.min_shown}")

    for arm in sorted(events_by_arm):
        report = arm_report(arm, events_by_arm[arm], args.min_shown)
        p95 = "n/a" if report["p95"] is None else f"{report['p95']}ms"
        print()
        print(f"{arm}: {report['label']}")
        print(
            f"  shown={report['shown']} accepted={report['accepted']} kept={report['kept']} "
            f"kept/shown={percent(report['kept_rate'])} p95={p95}"
        )
        print(
            f"  annoyance={report['annoyance']:.2f} insert={percent(report['insertion_success'])} "
            f"duplicate={percent(report['duplicate_rate'])} app-disable={percent(report['app_disable_rate'])}"
        )
        print(
            f"  empty-results={report['empty_results']} "
            f"pre-render-blocked={report['pre_render_blocked']}"
        )
        if report["pre_render_reasons"]:
            print("  pre-render reasons: " + ", ".join(
                f"{reason}={count}" for reason, count in report["pre_render_reasons"].most_common()
            ))
        if report["reasons"]:
            print("  guardrails: " + "; ".join(report["reasons"]))
        else:
            print("  guardrails: passed")


if __name__ == "__main__":
    main()
