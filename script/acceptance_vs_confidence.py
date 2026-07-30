#!/usr/bin/env python3
"""Acceptance vs confidence: if Tilde only spoke when it was this sure, how
often would the owner have said yes, and how much would they have lost?

Join: brain_samples carries the generation's p_first (confidence in the first
token) and the suggestion text; ghost_events carries what happened to a shown
ghost. Matched the trace-bench way — the sample's suggestion prefix appearing
in the event's ghost, same app, sample at-or-before the event.
"""
import json, glob, os, datetime
from collections import defaultdict

IC = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
ACCEPTS = ("accept_word", "accept_all")
REJECTS = ("typed_instead", "dismiss", "flagged")


def rows(pat):
    for f in glob.glob(os.path.join(IC, pat)):
        for line in open(f, errors="ignore"):
            try:
                e = json.loads(line)
            except Exception:
                continue
            if isinstance(e, dict):
                yield e


def ts(v):
    try:
        return datetime.datetime.fromisoformat(v.replace("Z", "+00:00"))
    except Exception:
        return None


samples = sorted((s for s in rows("brain_samples_*.jsonl")
                  if s.get("ts") and s.get("suggestion")),
                 key=lambda s: s["ts"])
events = sorted((e for e in rows("ghost_events_*.jsonl") if e.get("ts")),
                key=lambda e: e["ts"])

# index samples by app for a bounded backward scan
by_app = defaultdict(list)
for s in samples:
    by_app[s.get("app_bundle", "")].append(s)

# outcome per shown ghost: the event stream logs 'shown' then later an outcome.
# Treat an accept/reject within 5 minutes on the same app+ghost as its verdict.
outcome = {}          # (app, ghost) -> "accept" | "reject"
for e in events:
    ev = e.get("event")
    if ev in ACCEPTS or ev in REJECTS:
        key = (e.get("app_bundle", ""), (e.get("ghost") or "").strip())
        if key[1]:
            outcome[key] = "accept" if ev in ACCEPTS else "reject"

matched = []
for e in events:
    if e.get("event") != "shown":
        continue
    ghost = (e.get("ghost") or "").strip()
    app = e.get("app_bundle", "")
    if not ghost:
        continue
    et = ts(e["ts"])
    if not et:
        continue
    conf = None
    for s in reversed(by_app.get(app, [])):
        if s["ts"] > e["ts"]:
            continue
        st = ts(s["ts"])
        if not st or (et - st).total_seconds() > 120:
            break
        sug = (s.get("suggestion") or "")[:20]
        if sug and sug in ghost:
            try:
                conf = float(s.get("p_first"))
            except (TypeError, ValueError):
                conf = None
            break
    if conf is None:
        continue
    verdict = outcome.get((app, ghost))
    matched.append({"conf": conf, "accepted": verdict == "accept",
                    "words": len(ghost.split()), "app": app})

print(f"shown ghosts matched to a confidence score: {len(matched):,}")
if not matched:
    raise SystemExit("no join — cannot build the curve")

acc = sum(1 for m in matched if m["accepted"])
print(f"baseline on this matched set: {acc}/{len(matched)} = {100*acc/len(matched):.1f}%")
print()

print(f"{'if Tilde only spoke when ≥':<28}{'shown':>8}{'kept':>7}{'accept':>9}{'of today':>10}")
total = len(matched)
for thr in (0.0, 0.10, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80):
    sub = [m for m in matched if m["conf"] >= thr]
    if not sub:
        continue
    a = sum(1 for m in sub if m["accepted"])
    print(f"{thr:>26.2f}  {len(sub):>7,}{a:>7,}{100*a/len(sub):>8.1f}%{100*len(sub)/total:>9.0f}%")

print()
print("by ghost length (all confidences):")
for lo, hi, label in ((1, 1, "1 word"), (2, 3, "2-3 words"),
                      (4, 6, "4-6 words"), (7, 99, "7+ words")):
    sub = [m for m in matched if lo <= m["words"] <= hi]
    if not sub:
        continue
    a = sum(1 for m in sub if m["accepted"])
    print(f"  {label:<12} shown {len(sub):>6,}  accepted {a:>5,}  = {100*a/len(sub):>5.1f}%")
