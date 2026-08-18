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

Stages covered today (field in parentheses):
  llama-completion-timing   end-to-end completion incl. cleaner (totalMilliseconds)
  screen-capture-completed  capture + OCR duty cycle, by kind (duration_ms);
                            OCR alone, same event (ocrMilliseconds)
  scene-classified          ScreenScene.freshScene classification (milliseconds)
  personal-lookup-timing    the 250ms personal-brain race (waitedMilliseconds)
  ghost-request-timing      socket request total, parse to response write
                            (requestMilliseconds)
Stages logged but not yet timed (gaps show as absent rows):
  IME socket round-trip (InlineGhostIME's slow-key os_log path is out of
  scope for this diagnostics log — see AGENTS.md).
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_LOG = Path.home() / "Library/Logs/Tilde/diagnostics.log"
TIMING_FIELDS = (
    "totalMilliseconds",
    "duration_ms",
    "milliseconds",
    "ocrMilliseconds",
    "waitedMilliseconds",
    "requestMilliseconds",
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


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--since", help="only count events at/after this ISO-8601 time")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    arguments = parser.parse_args()

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
