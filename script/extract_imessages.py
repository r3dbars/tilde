#!/usr/bin/env python3
"""Extract a PERSONAL reply corpus from the local iMessage database.

Privacy: reads ~/Library/Messages/chat.db READ-ONLY, writes ONLY to the local
cache, transmits nothing. This is the owner's own data on the owner's own Mac.
Run with --purge to delete the extracted corpus.

Each record is a real reply situation, in the eval contract:
  text          = a message YOU sent (is_from_me=1)
  prior_messages= the recent conversation you were replying to (both sides,
                  oldest first) — the "screen context" the model should use
  source="imessage", register="chat", app="com.apple.MobileSMS"

So the reply/screen-response quiz can be run on YOUR real replies, not strangers.
"""
import argparse
import hashlib
import os
import re
import sqlite3
import sys

DB = os.path.expanduser("~/Library/Messages/chat.db")
OUT = os.path.expanduser("~/.cache/steadytype-eval/imessage_eval.jsonl")
URL_RE = re.compile(r"https?://|www\.")
MAX_PRIOR = 3
PRIOR_TRIM = 200


def clean(msg):
    if not msg:
        return None
    msg = " ".join(msg.split())
    if URL_RE.search(msg):
        return None
    # attachment/placeholder junk iMessage leaves in text
    if msg in ("￼", "") or msg.startswith("￼"):
        return None
    letters = sum(1 for c in msg if c.isalpha())
    if letters == 0:
        return None
    ascii_letters = sum(1 for c in msg if c.isalpha() and ord(c) < 128)
    if ascii_letters / letters < 0.9:
        return None
    return msg


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--min-words", type=int, default=4)
    ap.add_argument("--max-words", type=int, default=60)
    ap.add_argument("--limit", type=int, default=None, help="deterministic sample size (default: keep all)")
    ap.add_argument("--purge", action="store_true", help="delete the extracted corpus and exit")
    args = ap.parse_args()

    if args.purge:
        try:
            os.remove(OUT); print("purged", OUT)
        except FileNotFoundError:
            print("nothing to purge")
        return 0

    if not os.path.exists(DB):
        print("no chat.db at", DB, file=sys.stderr); return 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    con = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
    rows = con.execute(
        "SELECT cmj.chat_id, m.date, m.is_from_me, m.text "
        "FROM message m JOIN chat_message_join cmj ON m.ROWID=cmj.message_id "
        "WHERE m.text IS NOT NULL AND length(m.text)>0 "
        "ORDER BY cmj.chat_id, m.date"
    ).fetchall()
    con.close()

    records = []
    seen = set()
    buf = []            # rolling recent messages in the current chat: (is_from_me, cleaned)
    cur_chat = None
    scanned = reject = 0
    for chat_id, date, is_from_me, text in rows:
        if chat_id != cur_chat:
            cur_chat, buf = chat_id, []
        c = clean(text)
        if c is None:
            continue
        if is_from_me == 1:
            scanned += 1
            wc = len(c.split())
            prior = [t for _, t in buf][-MAX_PRIOR:]
            has_incoming = any(fm == 0 for fm, _ in buf[-MAX_PRIOR:])
            key = c.lower()
            if (args.min_words <= wc <= args.max_words and has_incoming
                    and key not in seen):
                seen.add(key)
                records.append({
                    "source": "imessage", "register": "chat",
                    "app": "com.apple.MobileSMS",
                    "text": c,
                    "prior_messages": [p[:PRIOR_TRIM] for p in prior],
                    "ts": None,
                })
            else:
                reject += 1
        buf.append((is_from_me, c))
        if len(buf) > 8:
            buf.pop(0)

    # deterministic order + optional sample
    records.sort(key=lambda r: hashlib.sha256(r["text"].encode()).hexdigest())
    if args.limit:
        records = records[:args.limit]

    with open(OUT, "w", encoding="utf-8") as f:
        for r in records:
            import json
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print("your-sent scanned: %d | kept as reply records: %d | rejected: %d" % (
        scanned, len(records), reject))
    print("written to %s (local only)" % OUT)
    # privacy-safe sanity: lengths, not content
    if records:
        wlens = sorted(len(r["text"].split()) for r in records)
        print("reply length words: min %d  median %d  max %d" % (
            wlens[0], wlens[len(wlens)//2], wlens[-1]))
        print("records with >=1 prior message: %d/%d" % (
            sum(1 for r in records if r["prior_messages"]), len(records)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
