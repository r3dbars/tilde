#!/usr/bin/env python3
"""The Tilde scorecard: every measure the app produces, on one page,
grouped by the question it answers.

Four questions, in the order they matter:

  DID IT HELP?      value delivered — the only reason anyone keeps it
  WAS IT WELCOME?   trust — the reason anyone uninstalls it
  IS IT SMARTER?    the lab exams, which predict the two above
  IS IT ALIVE?      health, so a broken app can't masquerade as a bad one

The north star is WORDS EARNED PER SUGGESTION SHOWN — words accepted divided
by ghosts shown. It is the only single number that captures both halves:
raise it by suggesting better, or by interrupting less. A system that is
always right but never speaks scores 0, and so does one that never shuts up.

Run: python3 script/scorecard.py            # the 3 numbers that matter
     python3 script/scorecard.py --full     # every diagnostic
"""
import argparse
import glob
import json
import os
import subprocess
from collections import Counter

ICLOUD = os.path.expanduser(
    "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
EVAL = os.path.expanduser("~/.cache/steadytype-eval")
ACCEPTS = ("accept_word", "accept_all")


def rows(pattern, root=ICLOUD):
    for path in glob.glob(os.path.join(root, pattern)):
        for line in open(path, errors="ignore"):
            try:
                row = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            if isinstance(row, dict):
                yield row


def bar(value, target, width=22):
    """A crude progress bar toward a target, so a ratio reads as a distance."""
    filled = 0 if target <= 0 else max(0, min(width, int(width * value / target)))
    return "█" * filled + "·" * (width - filled)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7,
                    help="window for the behaviour numbers")
    ap.add_argument("--full", action="store_true",
                    help="show every diagnostic, not just the 3 watched numbers")
    args = ap.parse_args()

    events = [e for e in rows("ghost_events_*.jsonl") if e.get("ts")]
    if not events:
        print("no capture yet — type with the keyboard and re-run")
        return

    days = sorted({e["ts"][:10] for e in events})[-args.days:]
    recent = [e for e in events if e["ts"][:10] in days]
    active_days = len({e["ts"][:10] for e in recent}) or 1

    shown = sum(1 for e in recent if e.get("event") == "shown")
    accepts = [e for e in recent if e.get("event") in ACCEPTS]
    typed_over = sum(1 for e in recent if e.get("event") == "typed_instead")
    flagged = sum(1 for e in recent if e.get("event") == "flagged")

    words_taken = sum(len((e.get("accepted") or "").split()) for e in accepts)
    per_shown = words_taken / shown if shown else 0.0
    accept_rate = len(accepts) / shown if shown else 0.0
    words_per_accept = words_taken / len(accepts) if accepts else 0.0

    # Walk depth — only meaningful once the walk-logging build is deployed.
    walks = [e for e in recent if e.get("walk_id")]
    walk_depth = None
    if walks:
        deepest = {}
        for e in walks:
            wid = e["walk_id"]
            deepest[wid] = max(deepest.get(wid, 0), int(e.get("taken_words") or 0))
        walk_depth = sum(deepest.values()) / len(deepest)

    # ---- the simple view: three numbers and a health line -------------
    if not args.full:
        similar = None
        scores = os.path.join(EVAL, "nightly", "champion_scores.json")
        if os.path.exists(scores):
            champ = json.load(open(scores))
            similar = (champ.get("live") or {}).get("similar")
        app_up = subprocess.run(["pgrep", "-x", "SteadyType"],
                                capture_output=True).returncode == 0
        brain_up = subprocess.run(["pgrep", "-f", "llama-server.*17872"],
                                  capture_output=True).returncode == 0
        last = max(e["ts"] for e in events)

        print("TILDE — the three numbers        (--full for everything)")
        print()
        print(f"  1. words earned per suggestion   {per_shown:.2f}    target 1.00")
        print(f"  2. accepted when shown           {100*accept_rate:.1f}%")
        if similar is not None:
            print(f"  3. sounds like you (similar*)    {100*similar:.1f}%")
        else:
            print("  3. sounds like you (similar*)    —     (next nightly writes it)")
        print()
        health = "ok" if (app_up and brain_up) else "BROKEN — check app/brain"
        print(f"  health: {health} · last keystroke {last}")
        print()
        print("  1 is the product. 2 is the annoyance. 3 is the voice.")
        print("  If none of them moved, nothing else matters today.")
        return

    print("=" * 58)
    print(f"TILDE SCORECARD           last {active_days} day(s) of typing")
    print("=" * 58)

    print("\nDID IT HELP?")
    print(f"  words written for you        {words_taken:>7,}  ({words_taken/active_days:,.0f}/day)")
    print(f"  words earned per suggestion  {per_shown:>7.2f}  ← THE NUMBER")
    print(f"                               {bar(per_shown, 1.0)}  target 1.00")

    print("\nWAS IT WELCOME?")
    print(f"  accepted when shown          {100*accept_rate:>6.1f}%  ({len(accepts):,} of {shown:,})")
    print(f"  words taken per accept       {words_per_accept:>7.2f}")
    if walk_depth is not None:
        print(f"  words walked before stopping {walk_depth:>7.2f}")
    else:
        print("  words walked before stopping      —  (needs the walk-logging build)")
    print(f"  typed over it                {typed_over:>7,}")
    print(f"  flagged as bad               {flagged:>7,}")

    print("\nIS IT GETTING SMARTER?")
    scores = os.path.join(EVAL, "nightly", "champion_scores.json")
    if os.path.exists(scores):
        champ = json.load(open(scores))
        live = champ.get("live") or {}
        traps = champ.get("traps") or {}
        if live:
            print(f"  sounds like you (similar*)   {100*live.get('similar',0):>6.1f}%  personal exam")
            print(f"  first word exactly right     {100*live.get('word1',0):>6.1f}%")
        if champ.get("meaning") is not None:
            print(f"  meaning score                {champ['meaning']:>7.3f}  texting exam")
        if traps:
            ok = traps.get("reoffend", 0) == 0
            print(f"  never repeats a flagged miss {'    pass' if ok else '    FAIL'}")
    else:
        print("  (no champion scores yet — the nightly retrain writes these)")

    gen = os.path.join(EVAL, "nightly", "general_results.json")
    if os.path.exists(gen):
        g = json.load(open(gen))
        champ = (g.get("champion") or {})
        vals = [v["word1"] for v in champ.values() if isinstance(v, dict) and "word1" in v]
        if vals:
            print(f"  works for anyone             {100*sum(vals)/len(vals):>6.1f}%  general exam (8 registers)")

    print("\nIS IT ALIVE?")
    app_up = subprocess.run(["pgrep", "-x", "SteadyType"],
                            capture_output=True).returncode == 0
    brain_up = subprocess.run(["pgrep", "-f", "llama-server.*17872"],
                              capture_output=True).returncode == 0
    print(f"  app running                  {'     yes' if app_up else '      NO'}")
    print(f"  brain running                {'     yes' if brain_up else '      NO'}")
    sources = Counter(e.get("source", "?") for e in recent if e.get("event") == "shown")
    if sources:
        top = ", ".join(f"{k} {100*v/shown:.0f}%" for k, v in sources.most_common())
        print(f"  where suggestions came from  {top}")
    last = max(e["ts"] for e in events)
    print(f"  last captured keystroke      {last}")

    print("\n" + "-" * 58)
    print("Read it this way: the top number is value, the second block is")
    print("trust, the third predicts both, the fourth rules out 'broken'.")
    print("Chase the north star — it can only rise by helping more or")
    print("interrupting less, which is the whole product in one ratio.")


if __name__ == "__main__":
    main()
