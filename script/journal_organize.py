#!/usr/bin/env python3
"""The journal organizer — the second reader of the "one diary, two readers"
design (owner decision 2026-07-25, promoted to plan 2026-07-28).

The raw stream (typing_journal_*.jsonl, written by the keyboard, ferried to
iCloud) feeds training and the matchmaker as-is. This script distills the
same stream for humans and agents:

  SteadyType-usage/daily/YYYY-MM-DD.md   one page per day, grouped by app,
                                         chronological, local times
  SteadyType-usage/daily/digest.md       the last 7 days at a glance —
                                         what got written, where, how much

Deliberately mechanical (no model calls): deterministic output, safe to
re-run any time, idempotent — day pages are rebuilt from the stream, which
remains the single source of truth. Entries were already scrubbed by
SensitiveTextScrubber before they ever reached disk.

Runs nightly via bar.r3d.steadytype.journal-organizer (4:15 AM, after the
3:30 retrain), or by hand:  python3 script/journal_organize.py
"""
import datetime
import glob
import json
import os
from collections import defaultdict

USAGE = os.path.expanduser(
    "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
DAILY = os.path.join(USAGE, "daily")

APP_NAMES = {
    "com.anthropic.claudefordesktop": "Claude",
    "com.tinyspeck.slackmacgap": "Slack",
    "com.apple.MobileSMS": "Messages",
    "com.openai.codex": "Codex",
    "com.openai.atlas": "Atlas",
    "com.openai.chat": "ChatGPT",
    "us.zoom.xos": "Zoom",
    "com.apple.TextEdit": "TextEdit",
    "com.apple.mail": "Mail",
    "com.google.Chrome": "Chrome",
    "com.apple.Safari": "Safari",
    "com.hnc.Discord": "Discord",
    "net.whatsapp.WhatsApp": "WhatsApp",
}


def app_name(bundle):
    if bundle in APP_NAMES:
        return APP_NAMES[bundle]
    return (bundle or "unknown").rsplit(".", 1)[-1] or "unknown"


def load_entries():
    entries = []
    for path in glob.glob(os.path.join(USAGE, "typing_journal_*.jsonl")):
        for line in open(path, errors="ignore"):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts, text = e.get("ts"), (e.get("text") or "").strip()
            if not ts or not text:
                continue
            try:
                when = datetime.datetime.fromisoformat(
                    ts.replace("Z", "+00:00")).astimezone()
            except ValueError:
                continue
            entries.append({
                "when": when,
                "app": e.get("app_bundle", ""),
                "text": text,
            })
    entries.sort(key=lambda e: e["when"])
    return entries


def write_day(day, rows):
    by_app = defaultdict(list)
    for e in rows:
        by_app[e["app"]].append(e)
    words = sum(len(e["text"].split()) for e in rows)
    lines = [
        f"# Typing journal — {day}",
        "",
        f"{len(rows)} {'entry' if len(rows)==1 else 'entries'} · {words:,} words · "
        + " · ".join(sorted({app_name(a) for a in by_app})),
        "",
    ]
    for app in sorted(by_app, key=lambda a: by_app[a][0]["when"]):
        lines.append(f"## {app_name(app)}")
        lines.append("")
        for e in by_app[app]:
            stamp = e["when"].strftime("%H:%M")
            lines.append(f"- **{stamp}** — {e['text']}")
        lines.append("")
    path = os.path.join(DAILY, f"{day}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return path, len(rows), words


def write_digest(by_day):
    today = datetime.date.today()
    recent = [
        (today - datetime.timedelta(days=i)).isoformat() for i in range(7)
    ]
    lines = [
        "# Typing digest — last 7 days",
        "",
        "The agent-facing summary of the typing journal. One line per day;",
        "open daily/YYYY-MM-DD.md for the full page.",
        "",
    ]
    for day in recent:
        rows = by_day.get(day)
        if not rows:
            lines.append(f"- **{day}** — no entries")
            continue
        words = sum(len(e["text"].split()) for e in rows)
        apps = " · ".join(sorted({app_name(e['app']) for e in rows}))
        n_lbl = "entry" if len(rows) == 1 else "entries"
        lines.append(f"- **{day}** — {len(rows)} {n_lbl}, {words:,} words ({apps})")
    lines.append("")
    path = os.path.join(DAILY, "digest.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return path


def main():
    os.makedirs(DAILY, exist_ok=True)
    entries = load_entries()
    by_day = defaultdict(list)
    for e in entries:
        by_day[e["when"].date().isoformat()].append(e)

    total = 0
    for day in sorted(by_day):
        _, n, words = write_day(day, by_day[day])
        total += n
    digest = write_digest(by_day)
    print(f"organized {total} entries into {len(by_day)} day page(s) "
          f"+ {os.path.basename(digest)} in {DAILY}")


if __name__ == "__main__":
    main()
