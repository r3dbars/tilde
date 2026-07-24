# Overnight exploration — making SteadyType feel magical

Started 2026-07-23 evening. Autonomous run: test every theory we have, wake the
owner to **specific recommendations**. This file is the live journal — results
append under each theory as experiments finish. Raw numbers in
`~/.cache/steadytype-eval/overnight_results.jsonl`.

## The theories under test

1. **Cost of being wrong** — measure the *downside* of bad suggestions, not just
   accuracy. Tune the confidence gate on the owner's own replies to find "never
   annoying." (GPU driver, Exp 3)
2. **The instant dictionary layer** — completely untested; may be half the felt
   magic. Quiz it. (build + GPU)
3. **Real-acceptance capture** — instrument the keyboard to record what the owner
   actually accepts / ignores / types-instead. The only ground truth. Privacy-
   safe, opt-in, local. (Swift build — ready for tomorrow's use)
4. **A better ruler (semantic scorer)** — exact-match can't tell "great but
   different reply" from "bad reply." Build a meaning-based scorer and re-judge
   our conclusions. (build + GPU re-score)
5. **Tiered brains** — fast 2B for constant typing + a bigger/instruct brain that
   fires only when replying to on-screen content. Best speed AND comprehension.
   (GPU Exp 1 + 4)
6. **Targeted Accessibility reading** — read "the message being replied to"
   directly (perfect, fast, structured) instead of screenshot→OCR. (build +
   compare)
7. **Personalization (the big lever)** — fine-tune Gemma 2 2B on the owner's
   32,337 real iMessage replies; measure before/after on their own data. (GPU,
   final + longest stage)

## Established facts going in (from earlier today)

- Model: **Gemma 2 2B base** is the shipping pick (beats instruct E4B on plain
  completion; fast; 1.7GB fits any Mac). Best config found: scaffold=size6,
  budget=16, temp=0.1, echo_guard=8 → ~28% EM@1 on diverse quiz.
- **Screen context helps predict the owner's real replies**: +42% keystrokes
  (0.74→1.05), +2.5pts EM@1 — but was flat on stranger data. Personal data tells
  the truth.
- **Bigger *base* models don't help replies**: 7B base < 2B on the owner's
  replies. So the reply lever is NOT raw size → is it instruct? (Exp 1)
- Screen framing (notes vs reply vs minimal): no difference. Not the lever.
- OCR eyes: ~98% on realistic images; keep accurate+language-correction.

## Reply corpora (all reply-pairs: prior message → the reply)

| corpus | register | records |
|---|---|---|
| imessage (owner) | texting / YOU | 32,337 |
| discord | casual chat | 2,000 |
| dailydialog | clean chat | 2,000 |
| reddit | casual online | 2,000 |
| ubuntu | work/tech chat | 2,000 |
| enron_thread | email | (built) |

---

## RESULTS (appended live)

<!-- experiments write below this line -->


## Theory 5 (tiered brains) / base-vs-instruct on the owner's replies

Predict the owner's real reply from 2 words + screen. Which brain?

| model | EM@1 | keystrokes/reply | p50 |
|---|---|---|---|
| gemma-2-2b(base) | 19.0% | 1.01 | 75ms |
| qwen2.5-7b(base) | 20.8% | 1.21 | 153ms |
| qwen2.5-7b(instr) | 18.0% | 1.02 | 166ms |
| gemma4-E4B(instr) | 19.1% | 0.99 | 137ms |

## Tooling built (CPU workflow, ~21:00)

- **Semantic scorer** `script/reply_score.py` — the better ruler. NOTE: shipped
  with the lexical-semantic *heuristic* (sentence-transformers not installed —
  disk tight); auto-upgrades to real embeddings if installed later. Selftest
  passes. Used for re-scoring model comparisons (a good-but-different reply gets
  credit instead of a zero).
- **Real-usage capture** `Sources/InlineGhostIME/GhostUsageLog.swift` — opt-in
  (UserDefaults `GhostUsageCaptureEnabled`, default OFF), local-only JSONL of
  accept/dismiss/typed-instead events, **redacted** (never raw text). Compiles.
  Ready for the owner to flip on tomorrow — the ground-truth capture.
- **Targeted-AX reader** + **dictionary-layer test** — built (see workflow).

Disk plan: ~9.7GB free. NOT pruning the audio/TTS/whisper HF caches (likely the
owner's other active projects). The fine-tune stage will instead reclaim the
now-disposable bakeoff GGUFs (gemma-4-12b/26b, big Qwens, ~40GB in my own
steadytype-eval/models) once the experiments finish with them.

Next (scheduled orchestration): finish GPU experiments → free disk → personal
fine-tune → semantic re-score → dictionary test → SPECIFIC RECOMMENDATIONS.
| gemma4-12b(instr) | 4.0% | 0.19 | 252ms |
| gemma4-26bMoE(instr) | 14.6% | 0.72 | 120ms |

## Screen-response lift across every register (Gemma 2 2B)

Does seeing the screen help predict replies — and where most?

| register | no-screen EM@1 | +screen EM@1 | no-screen ks | +screen ks |
|---|---|---|---|---|
| imessage | 16.8% | 19.4% | 0.73 | 0.99 |
| dailydialog | 22.0% | 28.6% | 1.11 | 1.90 |
| discord | 15.1% | 16.0% | 0.64 | 0.76 |

## Added scope (owner request, ~21:10): turn on usage capture + targeted-AX, deep-tune the dictionary

- **Dictionary layer** — dedicated deep track LAUNCHED NOW (CPU, parallel with GPU
  work): build a rigorous instant-word quiz on the owner's own vocabulary +
  general, make every heuristic tunable, coordinate-ascent tune it, report best
  config + accuracy/keystrokes/false-rate/latency. (Theory 2 section below.)
- **Usage capture ON** — flag pre-set. Real capture needs the rebuilt IME
  (with GhostUsageLog) installed on the owner's typing Macs → part of the
  post-experiment repackage stage.
- **Targeted-AX ON** — needs INTEGRATION into the app's screen-context pipeline
  (GhostScreenContextBridge/VisiblePageContextProvider): read via AX first, OCR
  fallback. Post-experiment stage (needs a dist rebuild, so after GPU work).
- **Post-experiment repackage** — rebuild app+IME with usage-capture + AX-first
  reading + the tuned dictionary + tuned defaults, notarize, drop a fresh install
  zip in iCloud + Downloads for the owner's typing Macs. Morning deliverable.
| reddit | 15.4% | 20.8% | 0.76 | 1.21 |
| ubuntu | 13.4% | 18.6% | 0.63 | 1.03 |
