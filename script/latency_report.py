#!/usr/bin/env python3
"""Latency percentiles per pipeline stage, from the diagnostics log.

Reads the privacy-safe diagnostics log (metadata-only events; see
DiagnosticsMetadataRedactor) and reports count / p50 / p95 / p99 / max for
every event that carries a millisecond timing field, split by `kind` when
present. This is the read side of "P99 every section": stages report their
own duration into diagnostics, and this script turns eight hours of dogfood
into a percentile table.

Usage:
  script/latency_report.py [--log PATH] [--since ISO8601] [--json]
  script/latency_report.py --budget [--log PATH] [--budgets PATH]
                            [--min-samples N] [--json]

--budget mode evaluates a log against script/latency_budgets.json and exits
nonzero listing any stage whose p99 is over budget. A stage with fewer than
--min-samples observations (default 50) is skipped rather than failed — thin
data proves nothing either way. This is the machinery behind the p99 proof
lanes in script/proof.sh: a BLOCKING self-test (--selftest) runs it against
synthetic fixture logs built in-process, and a REPORT-ONLY lane runs it
against the live diagnostics log when one exists on the machine. Live-machine
verdicts never fail the build — see script/proof.sh's header for why.

Stages covered today (field in parentheses):
  llama-completion-timing   end-to-end completion incl. cleaner (totalMilliseconds)
  screen-capture-completed  capture + OCR duty cycle, by kind (duration_ms);
                            OCR alone, same event (ocrMilliseconds)
  scene-classified          ScreenScene.freshScene classification (milliseconds)
  personal-lookup-timing    the 250ms personal-brain race (waitedMilliseconds)
  ghost-request-timing      socket request total, parse to response write
                            (requestMilliseconds)
  ghost-handshake-timing    accept to parsed: the peer code-signature
                            verification plus the wire read that run *before*
                            ghost-request-timing starts (handshakeMilliseconds)
The IME side of the socket round-trip is now timed too, but it lands in
OSLog rather than this diagnostics log: InlineGhostIME has no dependency on
the app target, so it cannot reach DiagnosticsLog. Read those samples with

  log show --predicate 'subsystem == "bar.r3d.inputmethod.InlineGhost"' \
      --style compact --last 8h | grep ghost-round-trip

which emits `roundTripMilliseconds=` and a fixed `outcome=` word per
completed (non-cancelled) request. Folding that stream into this table is
the obvious next step; it needs a `log show` reader, not just a new field.
"""

import argparse
import json
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_LOG = Path.home() / "Library/Logs/Tilde/diagnostics.log"
DEFAULT_BUDGETS = Path(__file__).resolve().with_name("latency_budgets.json")
DEFAULT_MIN_SAMPLES = 50
TIMING_FIELDS = (
    "totalMilliseconds",
    # Streaming split on llama-completion-timing: the two numbers that
    # describe felt speed. Recorded since 2026-08 but never reported, so a
    # first-word regression could not trip anything.
    "firstTokenMilliseconds",
    "firstPartialMilliseconds",
    "duration_ms",
    "milliseconds",
    "ocrMilliseconds",
    "waitedMilliseconds",
    "requestMilliseconds",
    "handshakeMilliseconds",
)
LINE = re.compile(r"^(\S+)\s+(\S+)\s*(.*)$")
PAIR = re.compile(r"(\w+)=(\S+)")


def percentile(sorted_values, fraction):
    if not sorted_values:
        return None
    index = min(len(sorted_values) - 1, max(0, round(fraction * (len(sorted_values) - 1))))
    return sorted_values[index]


def parse(log_path, since):
    series = {}
    with open(log_path, encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            match = LINE.match(raw.strip())
            if not match:
                continue
            stamp, event, rest = match.groups()
            if since is not None:
                try:
                    when = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
                except ValueError:
                    continue
                if when < since:
                    continue
            fields = dict(PAIR.findall(rest))
            present = [field for field in TIMING_FIELDS if field in fields]
            if not present:
                continue
            base_key = event if "kind" not in fields else f"{event}[{fields['kind']}]"
            # Most events carry exactly one timing field, so its row keeps
            # the plain event name. `screen-capture-completed` carries two
            # (`duration_ms` for the whole duty cycle, `ocrMilliseconds` for
            # OCR alone) — suffix the field name on multi-field lines so
            # both become their own p50/p95/p99 row instead of one silently
            # shadowing the other.
            multiple_fields = len(present) > 1
            for field in present:
                try:
                    value = float(fields[field])
                except ValueError:
                    continue
                key = f"{base_key}:{field}" if multiple_fields else base_key
                series.setdefault(key, []).append(value)
    return series


def event_name(series_key):
    """Strip a series key's optional `[kind]` and `:field` suffixes.

    `screen-capture-completed[browser]:duration_ms` and plain
    `llama-completion-timing` both budget under their bare event name, so a
    budget applies across every kind/field a stage happens to log.
    """
    return series_key.split("[", 1)[0].split(":", 1)[0]


def load_budgets(budgets_path):
    with open(budgets_path, encoding="utf-8") as handle:
        payload = json.load(handle)
    return payload["budgets"]


def evaluate_budget(series, budgets, min_samples):
    """Compare each budgeted stage's p99 against its budget.

    Returns (rows, violations): rows cover every series key that matches a
    budgeted stage and clears min_samples; violations is the subset over
    budget. A stage absent from the log, or too thin to trust, is silently
    skipped — it is neither a pass nor a failure.
    """
    rows = []
    violations = []
    for key in sorted(series):
        name = event_name(key)
        if name not in budgets:
            continue
        values = sorted(series[key])
        if len(values) < min_samples:
            continue
        p99 = percentile(values, 0.99)
        budget_ms = budgets[name]["p99_ms"]
        over_budget = p99 > budget_ms
        row = {
            "stage": key,
            "count": len(values),
            "p99_ms": p99,
            "budget_ms": budget_ms,
            "over_budget": over_budget,
        }
        rows.append(row)
        if over_budget:
            violations.append(row)
    return rows, violations


def print_budget_report(rows, budgets, as_json):
    if as_json:
        print(json.dumps({"rows": rows}, indent=1))
        return
    if not rows:
        print("latency_report --budget: no budgeted stage had enough samples to evaluate")
        return
    width = max(len(row["stage"]) for row in rows)
    print(f"{'stage'.ljust(width)}  {'count':>6}  {'p99':>6}  {'budget':>6}  status")
    for row in rows:
        status = "FAIL" if row["over_budget"] else "PASS"
        print(
            f"{row['stage'].ljust(width)}  {row['count']:>6}  "
            f"{row['p99_ms']:>6.0f}  {row['budget_ms']:>6.0f}  {status}"
        )


def selftest():
    passing_log = "\n".join(
        f"2026-08-18T00:00:{i:02d}Z llama-completion-timing totalMilliseconds={100 + i}"
        for i in range(60)
    ) + "\n" + "\n".join(
        f"2026-08-18T00:01:{i:02d}Z ghost-request-timing requestMilliseconds={50 + i}"
        for i in range(60)
    ) + "\n"
    failing_log = "\n".join(
        f"2026-08-18T00:00:{i:02d}Z llama-completion-timing totalMilliseconds={900 + i}"
        for i in range(60)
    ) + "\n"
    thin_log = "\n".join(
        f"2026-08-18T00:00:{i:02d}Z llama-completion-timing totalMilliseconds=999999"
        for i in range(10)
    ) + "\n"
    budgets = {
        "llama-completion-timing": {"p99_ms": 400},
        "ghost-request-timing": {"p99_ms": 500},
    }

    with tempfile.TemporaryDirectory() as tempdir:
        passing_path = Path(tempdir) / "passing.log"
        failing_path = Path(tempdir) / "failing.log"
        thin_path = Path(tempdir) / "thin.log"
        passing_path.write_text(passing_log, encoding="utf-8")
        failing_path.write_text(failing_log, encoding="utf-8")
        thin_path.write_text(thin_log, encoding="utf-8")

        passing_series = parse(passing_path, since=None)
        rows, violations = evaluate_budget(passing_series, budgets, DEFAULT_MIN_SAMPLES)
        assert not violations, f"expected no violations, got {violations}"
        assert {row["stage"] for row in rows} == {
            "llama-completion-timing", "ghost-request-timing"
        }

        failing_series = parse(failing_path, since=None)
        rows, violations = evaluate_budget(failing_series, budgets, DEFAULT_MIN_SAMPLES)
        assert len(violations) == 1
        assert violations[0]["stage"] == "llama-completion-timing"
        assert violations[0]["p99_ms"] > violations[0]["budget_ms"]

        # A stage with fewer than --min-samples observations must never
        # fail the tripwire, no matter how bad its numbers look — thin data
        # proves nothing either way, so it is skipped rather than trusted.
        thin_series = parse(thin_path, since=None)
        rows, violations = evaluate_budget(thin_series, budgets, DEFAULT_MIN_SAMPLES)
        assert not rows and not violations
        rows, violations = evaluate_budget(thin_series, budgets, min_samples=5)
        assert violations, "lowering --min-samples below the sample count should re-enable it"

    assert event_name("llama-completion-timing") == "llama-completion-timing"
    assert event_name("screen-capture-completed[browser]:duration_ms") == "screen-capture-completed"
    assert event_name("screen-capture-completed:duration_ms") == "screen-capture-completed"

    real_budgets = load_budgets(DEFAULT_BUDGETS)
    for stage in ("llama-completion-timing", "ghost-request-timing", "screen-capture-completed"):
        assert stage in real_budgets and real_budgets[stage]["p99_ms"] > 0

    print("selftest OK: budget pass/fail split and the min-samples floor hold")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--since", help="only count events at/after this ISO-8601 time")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument(
        "--budget", action="store_true",
        help="evaluate the log against --budgets instead of printing percentiles"
    )
    parser.add_argument(
        "--budgets", type=Path, default=DEFAULT_BUDGETS,
        help="path to a latency_budgets.json (default: script/latency_budgets.json)"
    )
    parser.add_argument(
        "--min-samples", type=int, default=DEFAULT_MIN_SAMPLES,
        help="skip a budgeted stage with fewer than this many observations (default: 50)"
    )
    parser.add_argument("--selftest", action="store_true")
    arguments = parser.parse_args()

    if arguments.selftest:
        selftest()
        return 0

    since = None
    if arguments.since:
        since = datetime.fromisoformat(arguments.since.replace("Z", "+00:00"))
        if since.tzinfo is None:
            since = since.replace(tzinfo=timezone.utc)

    if not arguments.log.exists():
        print(f"latency_report: no log at {arguments.log}", file=sys.stderr)
        return 1

    series = parse(arguments.log, since)
    if not series:
        print("latency_report: no timing events found", file=sys.stderr)
        return 1

    if arguments.budget:
        budgets = load_budgets(arguments.budgets)
        rows, violations = evaluate_budget(series, budgets, arguments.min_samples)
        print_budget_report(rows, budgets, arguments.json)
        if violations:
            names = ", ".join(f"{row['stage']} (p99 {row['p99_ms']:.0f}ms > {row['budget_ms']:.0f}ms)" for row in violations)
            print(f"latency_report --budget: over budget: {names}", file=sys.stderr)
            return 1
        return 0

    rows = []
    for key in sorted(series):
        values = sorted(series[key])
        rows.append({
            "stage": key,
            "count": len(values),
            "p50_ms": percentile(values, 0.50),
            "p95_ms": percentile(values, 0.95),
            "p99_ms": percentile(values, 0.99),
            "max_ms": values[-1],
        })

    if arguments.json:
        print(json.dumps({"stages": rows}, indent=1))
        return 0

    width = max(len(row["stage"]) for row in rows)
    print(f"{'stage'.ljust(width)}  {'count':>6}  {'p50':>6}  {'p95':>6}  {'p99':>6}  {'max':>7}")
    for row in rows:
        print(
            f"{row['stage'].ljust(width)}  {row['count']:>6}  "
            f"{row['p50_ms']:>6.0f}  {row['p95_ms']:>6.0f}  {row['p99_ms']:>6.0f}  {row['max_ms']:>7.0f}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
