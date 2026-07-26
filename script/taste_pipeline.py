#!/usr/bin/env python3
"""The taste pipeline: convert trace grades into (1) a frozen personal
benchmark ("the taste quiz") and (2) training data that bakes the owner's
judgment into the model.

Outputs (in ~/.cache/steadytype-eval/taste/):
- taste_gold.jsonl   : corrections -> gold SFT pairs (context+screen -> the
                       phrase the owner said it SHOULD have suggested)
- taste_prefs.jsonl  : preference pairs for DPO (rejected ghost vs what the
                       owner accepted/wrote/corrected, same context)
- taste_bench.jsonl  : every graded trace as a benchmark row (verdict +
                       failure tag + correction) — the personal eval any
                       future model must pass
Run any time; idempotent over the full grades file."""
import json, os, collections

USAGE = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
OUT = os.path.expanduser("~/.cache/steadytype-eval/taste")
os.makedirs(OUT, exist_ok=True)

grades = []
p = os.path.join(USAGE, "trace_grades.jsonl")
if os.path.exists(p):
    for line in open(p):
        try: grades.append(json.loads(line))
        except Exception: pass

gold, prefs, bench = [], [], []
tags = collections.Counter()
for g in grades:
    t = g.get("trace") or {}
    tag = g.get("tag","")
    tags[tag] += 1
    row = {"context": t.get("context",""), "screen": t.get("screen",""),
           "ghost": t.get("ghost",""), "event": t.get("event",""),
           "typed": t.get("typed",""), "app": t.get("app",""),
           "verdict": "pass" if tag == "PASS" else "fail",
           "tag": tag, "highlight": g.get("highlight"),
           "comment_or_correction": g.get("instead")}
    if g.get("session") is not None:
        row["session_grade"] = True
    bench.append(row)
    instead = (g.get("instead") or "").strip()
    # A correction that looks like replacement text (short, no meta-talk)
    # becomes gold; longer prose is open-coding commentary, benched only.
    is_phrase = instead and len(instead.split()) <= 12 and not any(
        w in instead.lower() for w in ("this is", "it is", "why does", "i would say"))
    if is_phrase:
        gold.append({"context": t.get("context",""), "screen": t.get("screen",""),
                     "completion": instead})
        if t.get("ghost"):
            prefs.append({"context": t.get("context",""), "screen": t.get("screen",""),
                          "chosen": instead, "rejected": t.get("ghost","")})
    if tag.startswith("FAIL") and t.get("event") == "typed_instead" and t.get("typed"):
        prefs.append({"context": t.get("context",""), "screen": t.get("screen",""),
                      "chosen": t.get("typed",""), "rejected": t.get("ghost","")})

for name, rows in [("taste_gold.jsonl", gold), ("taste_prefs.jsonl", prefs), ("taste_bench.jsonl", bench)]:
    with open(os.path.join(OUT, name), "w") as f:
        for r in rows: f.write(json.dumps(r) + "\n")

print(f"grades processed: {len(grades)}")
print(f"tag distribution: {dict(tags)}")
print(f"-> taste_gold.jsonl:  {len(gold)} gold completion pairs (your voice, your call)")
print(f"-> taste_prefs.jsonl: {len(prefs)} preference pairs (chosen vs rejected)")
print(f"-> taste_bench.jsonl: {len(bench)} benchmark rows (the personal eval)")
