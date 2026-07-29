# The matchmaker: what it proved, what it didn't, and what to try next

2026-07-29. Written at the end of the sitting-2 A/B, including two hypotheses
that died the same day. All numbers reproducible from
`~/.cache/steadytype-eval/matchmaker/` (frozen indexes, per-question dumps,
result JSON).

## The thesis being tested

Training plateaued on *sounding like the owner*. A week of nightly retrains
moved word-level accuracy but similar★ stalled around 8 on the personal
papers — the ceiling noted repeatedly in the retrain journal. The bet: the
lever for meaning-level accuracy is **memory, not more training**. Retrieve
the owner's own past exchanges that rhyme with the current moment, put them in
the scaffold slot, and let the model guess while looking at precedent.

Second, quieter bet: memory learns *instantly*. A retrain teaches tomorrow;
a memory that indexes an exchange the moment it happens teaches at lunchtime.

## Sitting 1 — does retrieval find the right page?

Index built capture-only (owner explicitly removed the 32k-iMessage seed:
"too complicated for users starting"). Pairs are the trace-bench join —
`brain_samples.screen` as the incoming side, `ghost_events` typed/accepted as
the reply.

**Two construction lessons, both learned the hard way:**

1. **Collapse the keystroke stream into exchanges BEFORE splitting train/exam.**
   Capture logs per-keystroke, so one sentence produces dozens of rows whose
   replies are prefixes of each other. Split first and the same moment lands on
   both sides; retrieval then returns the probe itself and the demo looks
   magical. 3,827 raw pairs collapse to 2,238 real exchanges.

2. **The join must match on app, not just time.** A screen from another app is
   not this moment.

Demo verdict: retrieval is real and register-native — a Codex task list on
screen retrieves the owner's "can you launch a thread that will fix…" family
unprompted. Roughness in the demo was *capture quality* (mid-word fragments),
not concept failure.

## Sitting 2 — does it move the exam?

Both arms identical except the scaffold slot. Champion model, private
llama-server on :17999, scored by `general_quiz.score_dump` verbatim.

**TEXTING-1500** (frozen iMessage held-out; twin-free by construction because
the index is July capture and the exam is old iMessage):

| arm | word-1 | first-2 | similar★ | meaning |
|---|---|---|---|---|
| without | 23.7 | 5.1 | 7.1 | 0.232 |
| with (897 memories) | 22.5 | 5.1 | **8.5** | 0.246 |

similar★ +69 gained / −47 lost, **McNemar p≈0.051**. At n=500 it was p≈0.09;
tripling the sample tightened it to the significance line. word-1 −1.2 is
churn (p≈0.39).

**The control that mattered most.** Random personal exemplars — same memories,
retrieval disabled — score *worse than baseline* on everything (word-1 20.3,
similar★ 6.5). Same mode collapse the opener-scaffold experiment hit. So the
gain is not "personal text in the prompt"; **the matching is the active
ingredient**, even at weak absolute similarity (mean top-1 cosine 0.356).

## Hypothesis 1 that died: always-on injection

**GENERAL-8000** (strangers' text, the product floor):

| arm | word-1 | first-2 | similar★ | spoke |
|---|---|---|---|---|
| without | 20.9 | 5.0 | 5.0 | 99.7 |
| with | 19.7 | **3.6** | 4.7 | 94.9 |

first-2 down 29% relative, and it goes quiet 5× more often. At n=8,000 that is
not noise. **Ship-gate ("similar★ improves, nothing regresses") FAILS for
always-on.**

## Hypothesis 2 that died: gate by register

The natural fix: the owner's memories are all chat (Claude, Slack, Codex), so
switch the matchmaker on for chat and off for prose/email. Keep the gain, drop
the harm.

Per-register similar★ change says the opposite:

| category | without | with | change |
|---|---|---|---|
| work email | 3.8 | 4.2 | **+0.4** |
| mixed | 5.4 | 5.8 | **+0.4** |
| casual dialog | 8.3 | 8.5 | +0.2 |
| Reddit | 4.4 | 4.4 | 0.0 |
| email threads | 3.0 | 2.7 | −0.3 |
| Discord chat | 3.8 | 3.3 | −0.5 |
| blog prose | 3.7 | 3.1 | −0.6 |
| **tech chat** | 7.3 | 5.8 | **−1.5** |

The worst-hurt category is **tech chat** — the most chat-like register in the
exam. Discord is hurt too. The two that improved are *email*. Register gating
would have switched the memory on exactly where it does the most damage.

**Why:** the index is four days of one intense project. It knows the owner's
*topic* (evals, diarization, shipping Tilde), not the owner's *voice*. Ask it
about a stranger debugging Ubuntu and it confidently supplies thoughts about
DER. It leaves email alone because nothing in the index looks like an email.

**The generalisable claim: a young personal memory is topic-specific, not
style-specific.** Breadth over time is what converts one into the other.

## Also learned: how to lie to yourself with an exam

The LIVE-99 paper reported +16 points of word-1 with the matchmaker. It was
false. 77 of 99 questions had a same-app precedent within 300 seconds — the
same typing session — because the exam slice hashed *per-keystroke timestamps*.
Retrieval handed the model the owner's own sentence from 30 seconds earlier.

Fixed (`ebf08291`): sessions (same app, gaps < 10 min) are the split unit.
Verified 0/63 twins, was 77/99. A later review found the fix itself keyed
sessions by timestamp alone; the real logs already contained 11 cross-app
one-second collisions, so it is now keyed `(app, ts)`.

**Lab rule, alongside "a suspiciously CONSTANT latency means suspect the
ruler": a suspiciously LARGE win on a capture-derived exam means suspect the
split.**

## Where this leaves the bet

Alive, unproven, and the failure mode is scoped. The personal gain is real and
at the significance line from a four-day index; the harm is concentrated where
the memory has topic knowledge but no relevant experience. Both point the same
direction: **the index needs to be broad and boring before it is useful.**

Next test scheduled for 2026-08-11 (`bar.r3d.steadytype.matchmaker-week2`),
deliberately after a real week of ordinary typing rather than a project sprint.
Same frozen harness, one command.

If similar★ clears significance on a bigger index, the wiring question becomes
gate-by-retrieval-strength (simulated: protects the floor, but at a 900-entry
index also erased the gain — the arithmetic changes as the index grows), not
gate-by-register.

## Rejected: DPO on the saved distillation rejects

Considered while the owner was away from the Mac, on the theory that 19,655
saved rejections were idle preference data and the machine was idle too.

Killed on inspection. `distill_gen.PUBLIC` is `aeslc_eval, blog_eval,
dailydialog_eval, discord_eval, …` — every reject is **strangers' text**.
Preference-training on it would tune the model's taste on other people's
voices, while the stuck metric is the owner's own. Wrong target.

**The right preference data already exists in capture and needs no new
typing:** every `typed_instead` is a pair — the ghost is the rejected answer,
what the owner typed instead is the chosen one. ~2,900 pairs, plus 11 explicit
Shift-Esc flags as highest-trust negatives. That is personal, on-target, and
untouched. Exam hygiene applies: build the pairs through the session-aware
split, never from exam-held sessions.

Queued as the next experiment when there is a machine to run it on.
