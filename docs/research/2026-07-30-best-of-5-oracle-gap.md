# Best-of-5: the good answers exist — the model just can't find them

2026-07-30. The simplest version of candidate selection, run on the frozen
texting exam (n=500; the loader capped the intended 1,500 — signal is far
beyond noise regardless). Three arms, same questions, same scoring as every
other exam. Reproduce: `bestof_quiz.py` in the matchmaker eval dir.

| arm | word-1 | similar★ | meaning |
|---|---|---|---|
| one shot (today's behaviour) | 25.6 | 8.2 | 0.249 |
| best-of-5, picked by own confidence | 23.4 | 8.4 | 0.243 |
| **best-of-5, perfect picker (oracle)** | **29.2** | **15.2** | **0.339** |

Sanity: the one-shot 8.2% matches the known 7.1-8.5% baseline band.

## The two findings

**1. The generation headroom is enormous.** Among 5 candidates (1 at
production temperature, 4 at 0.8), a meaning-right answer exists nearly
TWICE as often as one is shown (8.2 → 15.2). That +7.0pt oracle gap is
five times the matchmaker's measured gain (+1.4). The model is already
producing the answers the product needs — and discarding them.

**2. The model cannot recognise its own good guesses.** Picking by
length-normalised mean log-prob is a wash (8.4 ≈ 8.2, word-1 actually
down). Third independent confirmation of the same physics: p_first
correlation +0.06; confidence gate useless on phrases; now sequence
confidence blind at ranking its own diverse candidates.

## What this decides

The simple version FAILS, and the fancy version is now justified — the
ladder worked as designed ("the trained reranker only earns existence if
the simple picker fails"; it just did, on the record).

The prize for a real picker sits between 8.2 and 15.2. Even collecting a
third of the gap beats every other known lever. The reranker's training
signal is already being logged as of this week: Tab-walk stopping points
(per-word verdicts), typed_instead pairs, and accepts — all personal, all
implicit.

Constraint for the permanent build: 5x generation per keystroke is not
free. Offline exam use is unconstrained; in-app use likely reserves
best-of-k for phrase mode (where the headroom lives) with the KV cache
amortising the shared prompt.

## Status

Experiment only — nothing wired into the app. Next steps in order:
(1) train a small reranker on capture labels, rescore these same frozen
candidate dumps offline; (2) only if it collects a real fraction of the
oracle gap, design the in-app path.
