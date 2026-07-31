# Parked experiment: how best-of-5 should be SERVED — swap vs wait

2026-07-31. Design decision deliberately deferred until it can be judged by
feel on real hardware. Companion to the picker experiments
(2026-07-30-picker-first-result.md); this file is about the last step —
how a picked suggestion reaches the screen.

## The two candidate designs

**A — show-and-swap.** Paint the greedy guess at ~150ms exactly as today;
generate 4 alternates in parallel; if the judge prefers one, swap the ghost
at ~300ms. Preserves today's onset latency. Risk: people read the first
words of a ghost within 200-400ms — a swap lands mid-read. Text that
changes while being read is the same annoyance family as the re-offered
ghosts that justified the bench. Requires swap + race machinery (the
generation counter covers the Tab-during-swap case: once accepting starts,
the contest is over — you get exactly what you saw).

**B — wait-and-paint-once.** Fire all candidates at once, judge, paint the
winner a single time at ~300ms. Never changes after it lands. Strictly less
machinery: no swap logic, no mid-read changes. Cost: ~150ms later onset.
Hypothesis on record: **a calm 300ms beats a jumpy 150ms** — B wins on
feel AND simplicity. Onset delay is likely unfelt; instability is
definitely felt.

## Why parked rather than built

1. The judge is unproven (+1.3 similar★ at p=0.056; word-1 cost proven at
   p=0.018). It retrains on walk-stopping labels once deployed capture
   accrues — its real training data.
2. The meaning-vs-exact gate decision (owner's) is a prerequisite: this
   feature only makes sense if phrase mode optimises meaning.
3. Two zero-machinery wins ship first and raise the baseline: dead-zone
   silence and the single-word confidence gate (25%→48% measured).
4. Two questions only real hardware answers: battery under sustained 6x
   generation bursts in long composing sessions, and whether the 15.2%
   oracle ceiling (measured on the iMessage exam) holds on live typing
   with screen context.

## Revival procedure, when the time comes

Deploy week + judge cleared significance → build B first (simpler), A only
if B's onset delay is actually felt → run each for a day of real typing →
keep whichever feels calmer, judged by the owner's hands, not the exam.
Scope: phrase mode only, composing moments only (the moment model gates
where the compute spends). Behind a toggle like everything else.

## The one-line summary

The kitchen already cooks better dishes than it serves; the judge that
picks them is almost good enough; and when both are ready, serve once and
never swap the plate.
