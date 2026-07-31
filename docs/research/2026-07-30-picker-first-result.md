# The trained picker, first attempt: 23% of the oracle gap

2026-07-30, same day as the best-of-5 experiment that justified it. The
ladder's next rung, exactly as designed: the model cannot rank its own
candidates, so a small learned picker does it instead.

## Setup

- 4,000 messages sampled from the TRAINING pool of the iMessage corpus
  (curve_run's frozen seeded split — zero overlap with the exam), 5
  candidates each = 20,000 candidates, each labelled with its
  cosine-to-truth. The picker (gradient-boosted trees, 9 runtime-available
  features) regresses that label: it learns to predict "how close to what
  the owner would say is this?" without seeing the answer.
- Evaluated only on the frozen 500-question exam's candidate sets.

## Result

| arm | word-1 | similar★ | meaning |
|---|---|---|---|
| one shot | 25.6 | 8.2 | 0.249 |
| **picker** | 23.6 | **9.8** | 0.262 |
| oracle ceiling | 29.2 | 15.2 | 0.339 |

**The picker collected 23% of the oracle gap on the first attempt** —
similar★ +1.6, already larger than the matchmaker's +1.4, from an
afternoon's work and no new typing.

Honest statistics: +15/−7 flips, McNemar p≈0.134 — right direction, not yet
proof. word-1 dips (+11/−21, p≈0.110): the picker trades exact-first-word
for meaning, the same trade the matchmaker made. Both effects need a bigger
exam run (the full 1,500) to firm up.

## Why this matters

Third leg of the same week-long finding, now with a constructive ending:
the model's own confidence cannot judge phrases (p_first +0.06 correlation;
confidence gate useless; best-of-5 self-pick a wash) — but a tiny external
model looking at runtime signals CAN, at least partly. The empty judge's
seat is fillable.

## Ceiling and next steps

23% of the gap is a floor, not a ceiling: the picker used 9 hand-rolled
features and 4k training messages out of an available 28k. Obvious
climbs, in order of cheapness:

1. Train on the full pool (7x the data, pure compute).
2. Add the matchmaker's retrieval similarity as a feature — a close
   precedent is independent evidence a candidate is right; this also gives
   the memory a second, subtler job (measurement, not just generation).
3. Once deployed capture accrues: walk stopping points as per-word labels.
4. Run the full 1,500-question exam for significance.

Not wired into the app. The in-app cost question (5x generation per
keystroke) only becomes relevant if the offline number firms up.
