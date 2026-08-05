#!/usr/bin/env python3
"""Turn the keyboard's real-usage capture into aggregate product telemetry.

Reads opted-in GhostUsageLog events from local/iCloud files and reports counts
and acceptance rates by source and app. The files can contain writing context,
but this script never prints that text.

Events include shown, accepted, dismissed, typed-instead, and policy suppression.

Usage: python3 script/analyze_usage.py         # auto-find logs (iCloud + local)
       python3 script/analyze_usage.py --today # only today's local-time events
       python3 script/analyze_usage.py <file>  # a specific log
"""
import argparse
import glob
import json
import os
import sys
from collections import defaultdict
from datetime import date, datetime

ICLOUD = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage")
LOCAL = os.path.expanduser("~/Library/Application Support/Tilde/usage")


def find_logs():
    paths = []
    for d in (ICLOUD, LOCAL):
        paths += glob.glob(os.path.join(d, "ghost_events*.jsonl"))
    return paths


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument(
        "--today",
        action="store_true",
        help="include only events from today in the Mac's local time zone",
    )
    scope.add_argument(
        "--date",
        type=date.fromisoformat,
        metavar="YYYY-MM-DD",
        help="include only events from this date in the Mac's local time zone",
    )
    parser.add_argument("files", nargs="*", help="usage JSONL files (default: auto-find)")
    return parser.parse_args(argv)


def local_event_date(event):
    value = event.get("ts")
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone().date()
    except ValueError:
        return None


def main(argv=None):
    args = parse_args(argv)
    files = args.files or find_logs()
    if not files:
        print("no usage logs found. Enable capture and use the keyboard, then re-run.")
        print("  looked in:\n   %s\n   %s" % (ICLOUD, LOCAL))
        return 1

    events = []
    for f in files:
        try:
            for line in open(f):
                line = line.strip()
                if line:
                    events.append(json.loads(line))
        except Exception as e:
            print("skip %s: %s" % (f, e), file=sys.stderr)

    selected_date = date.today() if args.today else args.date
    if selected_date is not None:
        events = [event for event in events if local_event_date(event) == selected_date]

    if not events:
        if selected_date is not None:
            print("no usage events found for %s." % selected_date.isoformat())
            return 0
        print("logs found but empty — type with the keyboard to accumulate events.")
        return 0

    shown = sum(1 for e in events if e.get("event") == "shown")
    aw = sum(1 for e in events if e.get("event") == "accept_word")
    aa = sum(1 for e in events if e.get("event") == "accept_all")
    dis = sum(1 for e in events if e.get("event") == "dismiss")
    typed = sum(1 for e in events if e.get("event") == "typed_instead")
    blank = sum(1 for e in events if e.get("event") == "suppressed_blank")
    accepts = aw + aa

    label = selected_date.isoformat() if selected_date is not None else "all dates"
    print("=== Tilde aggregate usage: %s (%d events across %d log file(s)) ===" % (label, len(events), len(files)))
    print("ghosts shown:      %d" % shown)
    print("accepted:          %d  (%d word-by-word, %d whole)" % (accepts, aw, aa))
    print("dismissed (Esc):   %d" % dis)
    print("typed instead:     %d" % typed)
    print("blank suppressed:  %d" % blank)
    resolved = accepts + dis + typed
    if resolved:
        print("\nACCEPTANCE RATE: %.1f%%  (of the %d ghosts you acted on)" % (100 * accepts / resolved, resolved))
        print("  ignored/overrode: %.1f%%  <- the 'annoyance' signal" % (100 * (dis + typed) / resolved))

    # by source: dictionary (fast) vs AI model
    by_src = defaultdict(lambda: defaultdict(int))
    for e in events:
        by_src[e.get("source", "?")][e.get("event", "?")] += 1
    print("\n-- by source (which layer earns its keep) --")
    for src, c in sorted(by_src.items()):
        acc = c["accept_word"] + c["accept_all"]
        res = acc + c["dismiss"] + c["typed_instead"]
        rate = "%.0f%%" % (100 * acc / res) if res else "n/a"
        print("  %-6s shown %-5d  accepted %-5d  accept-rate %s" % (src, c["shown"], acc, rate))

    # by app: where it helps most / least
    by_app = defaultdict(lambda: defaultdict(int))
    for e in events:
        by_app[e.get("app_bundle", "?")][e.get("event", "?")] += 1
    print("\n-- by app (top by activity) --")
    ranked = sorted(by_app.items(), key=lambda kv: -sum(kv[1].values()))[:10]
    for app, c in ranked:
        acc = c["accept_word"] + c["accept_all"]
        res = acc + c["dismiss"] + c["typed_instead"]
        rate = "%.0f%%" % (100 * acc / res) if res else "n/a"
        print(
            "  %-34s shown %-5d  accepted %-4d  accept-rate %s"
            % (app[:34], c["shown"], acc, rate)
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
