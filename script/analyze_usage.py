#!/usr/bin/env python3
"""Turn the keyboard's real-usage capture into insight — the ground truth of
what actually helps. Reads GhostUsageLog events (redacted, local/iCloud) from
all Macs and reports accept rates by source and app.

Events: {ts, app_bundle, event: shown|accept_word|accept_all|dismiss|typed_instead,
         ghost_len, source: fast|model}. NO raw text is ever logged.

Usage: python3 script/analyze_usage.py         # auto-find logs (iCloud + local)
       python3 script/analyze_usage.py <file>  # a specific log
"""
import glob
import json
import os
import sys
from collections import defaultdict

ICLOUD = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
LOCAL = os.path.expanduser("~/Library/Application Support/SteadyType/usage")


def find_logs():
    paths = []
    for d in (ICLOUD, LOCAL):
        paths += glob.glob(os.path.join(d, "ghost_events*.jsonl"))
    return paths


def main():
    files = sys.argv[1:] or find_logs()
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

    if not events:
        print("logs found but empty — type with the keyboard to accumulate events.")
        return 0

    shown = sum(1 for e in events if e.get("event") == "shown")
    aw = sum(1 for e in events if e.get("event") == "accept_word")
    aa = sum(1 for e in events if e.get("event") == "accept_all")
    dis = sum(1 for e in events if e.get("event") == "dismiss")
    typed = sum(1 for e in events if e.get("event") == "typed_instead")
    accepts = aw + aa

    print("=== SteadyType real usage (%d events across %d log file(s)) ===" % (len(events), len(files)))
    print("ghosts shown:      %d" % shown)
    print("accepted:          %d  (%d word-by-word, %d whole)" % (accepts, aw, aa))
    print("dismissed (Esc):   %d" % dis)
    print("typed instead:     %d" % typed)
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
        print("  %-34s accepted %-4d  accept-rate %s" % (app[:34], acc, rate))
    return 0


if __name__ == "__main__":
    sys.exit(main())
