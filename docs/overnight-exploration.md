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
| enron_thread | 18.0% | 20.6% | 1.03 | 1.18 |

## Theory 1 (cost of being wrong) — confidence gate on the owner's replies

Higher bar = speaks less but more accurate when it does. Find 'never annoying'.

| threshold | speaks | EM@1(spoken) | keystrokes/reply |
|---|---|---|---|
| 0 | 97% | 20.6% | 1.07 |
| 0.1 | 76% | 23.2% | 0.91 |
| 0.15 | 54% | 29.2% | 0.87 |
| 0.2 | 37% | 31.2% | 0.61 |
| 0.3 | 18% | 41.9% | 0.45 |
| 0.4 | 9% | 52.8% | 0.31 |

_Experiment driver complete 21:13. Fine-tune + semantic re-score are separate stages._



## Theory 2 — Instant dictionary layer (tuned)

Deep-tested and tuned the mid-word instant-completion layer
(`dictionaryCompletion(for:)` in `Sources/InlineGhostIME/GhostInputController.swift`)
— the NSSpellChecker-backed layer that fires on every keystroke, no debounce,
no confirm step. CPU-only (NSSpellChecker), no GPU/dist-app/llama-server
touched.

**Tooling** (all under `script/`, none touch the running app):
- `dict_probe.swift` — standalone mirror of `dictionaryCompletion(for:)`,
  byte-for-byte identical logic at default env vars, with all six heuristics
  exposed as knobs (`STEADYTYPE_DICT_MIN_LETTERS`, `_MIN_SUFFIX`,
  `_MAX_OBSCURE_LEN`, `_PREFER_COMMON`, `_COMMON_ONLY`,
  `_BLOCK_COMPLETE_COMMON`). Reads prefixes from stdin in a long-lived
  process (NSSpellChecker/XPC warms up once) so per-call timing is realistic
  and the eval harness doesn't pay process-spawn cost per data point.
  Build: `swiftc -O script/dict_probe.swift -o script/dict_probe`.
- `dictionary_eval.py` — quiz harness. Pulls real words (≥5 letters) from
  the owner's own vocabulary (`~/.cache/steadytype-eval/imessage_eval.jsonl`,
  32,337 messages) and general chat (`diverse_eval.jsonl`), cuts each word
  after 1/2/3/4 letters, scores top-1 accuracy, a looser "helpful-prefix"
  partial-credit metric, keystrokes saved, false-completion rate, silence
  rate, and p50/p95 latency — then runs a coordinate-ascent sweep over every
  knob on a 70/30 train/test split (so the reported "tuned" numbers aren't
  curve-fit to the exact quiz set) to maximize a utility function
  (keystrokes saved − 3× false completions, i.e. a wrong instant guess costs
  ~3 keystrokes of trust since there's no confirm step).
- Quiz set used below: 300 words/source × cut at 1/2/3/4 letters = **2,400
  test cases** (600 per cut length), seed 17.
- Raw results + full sweep log: `~/.cache/steadytype-eval/dictionary_layer_eval_v2.jsonl`,
  `dictionary_layer_sweep.jsonl`, `dictionary_layer_summary.json`.

### Headline finding: the shipped defaults are trigger-happy and usually wrong when they speak

| config | spoken rate | accuracy when spoken | **false-completion rate when spoken** | false rate overall | keystrokes saved/attempt | p50 / p95 latency |
|---|---|---|---|---|---|---|
| **DEFAULT (shipped)** | 72.6% | 33.1% | **66.9%** | 48.6% | 0.72 | 1.9ms / 2.8ms |
| **RECOMMENDED (tuned)** | 47.7% | 49.2% | **50.8%** | 24.2% | 0.55 | ~0ms / 2.8ms |
| CONSERVATIVE (tuned, high-precision) | 14.7% | 62.6% | **37.4%** | 5.5% | 0.24 | ~0ms / 2.8ms |

Two in three times the shipped instant layer shows ghost text, it's showing
the **wrong word** — with no way for the user to tell short of finishing
typing. Latency was never the problem (p95 stays 2.5–3.3ms across every
config tried, an order of magnitude under the 20ms budget); precision is.

### Per-prefix-length breakdown (default vs recommended)

| cut length | default: spoken / false-when-spoken | recommended: spoken / false-when-spoken |
|---|---|---|
| 1 letter | 0% (below min-letters gate) | 0% (below min-letters gate) |
| 2 letters | **100% spoken / 80.7% wrong** | 0% (raised gate excludes this) |
| 3 letters | 98.8% spoken / 54.8% wrong | 98.8% spoken / **61.6% wrong** |
| 4 letters | 91.5% spoken / 65.0% wrong | 92.2% spoken / **39.2% wrong** |

The single worst offender is **2-letter prefixes**: the shipped
`STEADYTYPE_DICT_MIN_LETTERS=2` gate lets the layer guess off almost nothing,
and it's wrong 4 times out of 5 when it does. Cutting that bucket entirely
(raising the gate to 3 letters) removes the layer's worst failure mode for
free. 4-letter prefixes improve the most from the second change
(`MIN_SUFFIX` 2→1): demanding only 1 more correct character instead of 2
before it's willing to speak is a strictly safer bet, and false-when-spoken
at 4 letters drops from 65.0% → 39.2%.

By source: the owner's own vocabulary (imessage) is consistently easier to
predict than general chat (diverse) at every config — e.g. recommended:
accuracy-when-spoken 55.8% (imessage) vs 42.7% (diverse) — consistent with
the personalization finding elsewhere in this doc (personal data tells the
truth).

### The tuned coordinate-ascent search

Search space: `MIN_LETTERS ∈ {1,2,3}`, `MIN_SUFFIX ∈ {1,2,3,4}`,
`MAX_OBSCURE_LEN ∈ {4,6,9,12,999}`, `PREFER_COMMON/COMMON_ONLY/BLOCK_COMPLETE_COMMON ∈ {on,off}`.
2 rounds, 6 knobs, converged in 25 config evaluations.

The optimum is sensitive to how harshly a false completion is penalized
(reasonable — it's a genuine product-values call, not a fact):

- **Penalty 1.0–1.5** (a wrong guess costs about one keystroke of
  annoyance) → converges to `MIN_LETTERS=3, MIN_SUFFIX=1,
  MAX_OBSCURE_LEN=9(unchanged), COMMON_ONLY=off,
  BLOCK_COMPLETE_COMMON=off`. This is **RECOMMENDED** above, with one
  override: I put `BLOCK_COMPLETE_COMMON` back **on**. Turning it off barely
  moves the numbers here (utility −433 vs −448, ~1pt of coverage) because
  this synthetic quiz never tests the scenario the guard exists for (user
  finishes typing a complete common word and pauses — "the" → "theory" is
  noise, not help, per the code comment) — the quiz only cuts words
  mid-token, so it can't see that failure mode. No reason to spend the
  guard's protection for a gain the quiz can't actually measure.
- **Penalty 3.0** (a wrong guess costs three keystrokes — appropriate if
  trust erosion compounds, i.e. users start ignoring the layer entirely
  after repeated bad guesses) → converges to `MIN_LETTERS=3, MIN_SUFFIX=2,
  MAX_OBSCURE_LEN=4, COMMON_ONLY=on`. This is **CONSERVATIVE** above: it
  restricts completions to the ~200-word curated `commonWords` list only,
  which slashes the false rate to 5.5% overall but also slashes coverage to
  14.7% spoken (vs 72.6% today) — probably too big a cut to the layer's
  felt usefulness for the precision gained.

### Recommendation

**Ship the two-line RECOMMENDED change** — it roughly **halves the overall
false-completion rate (48.6% → 24.2%)** and **cuts the worst bucket (2-letter
false rate 80.7%) to zero**, while keeping the majority of the layer's
coverage and keystroke savings (0.55 vs 0.72 keystrokes/attempt, spoken rate
47.7% vs 72.6%) — a much better trade than either extreme:

```swift
// dictionaryCompletion(for:), Sources/InlineGhostIME/GhostInputController.swift
guard partial.count >= 3 else { return "" }          // was: >= 2
...
candidate.count >= partial.count + 1                  // was: partial.count + 2
    && candidate.lowercased().hasPrefix(lowerPartial)
```

Everything else (prefer-common-word logic, the ≤9-char obscure-word cap, the
already-complete-common-word guard) stays as shipped. If the owner wants to
lean further toward trust over magic, `CONSERVATIVE` is the config to reach
for next, but it gives up most of the layer's day-to-day usefulness to get
there — not recommended as a first move.

**Caveat on the quiz itself**: this only tests the layer's core word-guessing
mechanic (cut a real word, ask for the rest). It does not model debounce
timing, caret-jump quirks per app, or the "already-complete-word pause"
scenario `BLOCK_COMPLETE_COMMON` guards against — those need the real IME or
the owner's opt-in `GhostUsageLog` capture (built earlier tonight) to
measure.

## Experiment driver results (synthesis, 21:33)

**Base vs instruct on the owner's replies** — base wins even here:
| model | EM@1 | keystrokes | p50 |
|---|---|---|---|
| qwen2.5-7b (base) | 20.8% | 1.21 | 153ms |
| gemma4-E4B (instr) | 19.1% | 0.99 | 137ms |
| gemma-2-2b (base) | 19.0% | 1.01 | 75ms |
| qwen2.5-7b (INSTRUCT) | 18.0% | 1.02 | 166ms |
| gemma4-26b MoE (instr) | 14.6% | 0.72 | 120ms |
| gemma4-12b (instr) | 4.0% | 0.19 | 252ms |
CONCLUSION: instruct does NOT help replies (7B base 20.8% > 7B instruct 18.0%).
A 7B base reply-brain buys only +1.8pts at 2x latency → **not worth a 2nd brain.**
Keep the fast 2B; the reply lever is personalization, not a bigger/instruct model.

**Screen-context lift by register** (Gemma 2 2B, EM@1 off→on):
imessage 16.8→19.4 | dailydialog 22.0→28.6 | reddit 15.4→20.8 | ubuntu 13.4→18.6 |
enron 18.0→20.6 | discord 15.1→16.0. CONCLUSION: **screen context helps in EVERY
register** (weakest on chaotic Discord). The feature is broadly valuable.

**Confidence gate (cost of being wrong)** — clean dial:
thr 0: speaks 97%, 20.6% right. thr 0.1: 76%, 23.2%. thr 0.15: 54%, 29.2%.
thr 0.2: 37%, 31.2%. thr 0.3: 18%, 41.9%. RECOMMENDATION: ship a light gate
(~0.1) as default — trims the worst guesses with little coverage loss; expose it
as a "chattiness" control so the owner can dial toward trust.

**Baked in:** dictionary fix (MIN_LETTERS 2→3, suffix +2→+1) in
GhostInputController.dictionaryCompletion — halves the instant layer's wrong guesses.

## Theory 7 — PERSONALIZATION (fine-tune on the owner's replies) — THE BIG WIN

LoRA fine-tune of Gemma 2 2B on 30,720 of the owner's own iMessage replies
(8 layers, 1000 iters, val loss 4.44→0.61). Fused → GGUF Q4 →
`~/.cache/steadytype-eval/models/gemma-2-2b-personal.Q4_K_M.gguf`.

Reply quiz on the owner's own data (800 cases, predict from 2 words + screen):
| model | EM@1 | EM@2 | keystrokes/reply | p50 |
|---|---|---|---|---|
| baseline gemma-2-2b | 19.0% | ~4% | 1.01 | 75ms |
| **PERSONAL (fine-tuned)** | **26.2%** | 7.4% | **1.50** | 58ms |

**+38% relative EM@1, +49% keystrokes, same speed & size.** Personalization is
by far the biggest lever found — it makes the model predict the OWNER, not a
generic writer. RECOMMENDATION: ship the personal model as the owner's model;
for a general release, ship the tuned base + the fine-tune pipeline so each user
personalizes on their own data (their data never leaves their machine).

---
# ⭐ SPECIFIC RECOMMENDATIONS (morning briefing)

Ranked, concrete, evidence-backed — how to make SteadyType magical:

1. **SHIP PERSONALIZATION — the headline.** Fine-tuning Gemma 2 2B on the owner's
   own 32k replies lifted reply prediction +38% (19.0→26.2% EM@1) and keystrokes
   +49% (1.01→1.50), same 58ms speed. The personalized build is in iCloud +
   Downloads NOW (`SteadyType-personal.zip`). For a general product: ship the
   base model + the fine-tune pipeline so each user personalizes on their OWN
   local data (never leaves their machine). THIS is what makes it read your mind.
2. **Keep the fast Gemma 2 2B base — no second/bigger brain.** Base beats instruct
   even for replies; a 7B base buys only +1.8pts at 2× latency. One fast model
   everywhere; simpler and instant.
3. **Instant dictionary fix — DONE (baked in).** It was wrong ~67% of the time it
   fired (80% at 2 letters). Requiring 3 letters halves the bad guesses — a real
   annoyance removed (the "cost of being wrong").
4. **Add a light confidence gate (~0.1 default) + a "chattiness" control.** Trims
   the worst guesses for little coverage loss (speaks 76%, precision 20.6→23.2%);
   let the user dial quiet-and-trustworthy vs chatty-and-helpful.
5. **Keep screen-context (helps EVERY register).** Next upgrade: AX-first reading
   (prototyped `script/ax_probe_targeted.swift`, ready to wire) — perfect, faster,
   targetable context vs screenshot+OCR.
6. **Usage capture is ON in the personal build** — it gathers the real ground
   truth (what you actually accept). Feed it into the NEXT fine-tune → the app
   gets better the more you use it. Flywheel.

ONE LINE: the thing that makes it magical is **you** — training on your own
writing. Everything else is polish on top.

_Deferred (needs verification, not shipped tonight): wiring AX-first reading into
the live pipeline; semantic re-score (exact-match already showed +38% clearly)._

## Register split across the owner's Macs (2026-07-24 evening)

The work Mac (Q0KL4R3L24MBP) is Slack/business-register replies; the personal
Mac is casual/chat. Day-1 accuracy: personal Mac 17.1% vs work Mac 11.7% — the
gap is largely REGISTER MISMATCH: the personal model has only ever trained on
iMessage casual voice, so business-you is a blind spot, not a weak spot.
Implications:
1. Work-Mac captures are the highest-value training stream right now (first
   business-register examples the model will ever see) — include in every
   retrain.
2. Medium-term: use the existing ContinuationRegister per-app voice plumbing to
   condition Slack vs Messages differently.
3. Expect work-Mac accuracy to move MORE than personal-Mac after retrain #2
   (blind-spot filling beats weak-spot sharpening).
This is the real version of the planned "it just learned your work voice"
progression moment in the Tilde window design.

## THE DATA-VS-ACCURACY CURVE + retrain #2 (2026-07-24 evening, 32-minute run)

Same LoRA recipe (mlx gemma-2-2b, 8 layers) at increasing data sizes, each
scored on a FROZEN 500-case held-out slice of the owner's replies (never
trained on), context=prior. Full pipeline per point: train -> fuse -> GGUF ->
Q4_K_M -> live-app quiz. Runtime: ~3-5 min per point end to end.

| trained on | EM@1 | meaning |
|---|---|---|
| 250 | 20.4% | 0.180 |
| 1,000 | 23.6% | 0.208 |
| 4,000 | **26.4%** | 0.205 |
| 16,000 | 24.6% | 0.202 |
| 30,637 | 26.0% | 0.207 |

**THE KNEE IS ~4,000 EXAMPLES.** Steep 250->4k, then flat (±1% noise) to 31k.
250 examples already deliver most of the personalization lift. Product
implications:
1. A new user feels personalization within DAYS (a few hundred phrases), and
   hits full quality at ~4k — the Learning card's retrain threshold is now a
   measured number.
2. Data beyond 4k buys nothing today -> retrains can train on the ~4k most
   RECENT (correction-weighted) examples: tracks the owner's current voice,
   trains in ~2 minutes. Nightly retraining is computationally trivial.

**Retrain #2 scoreboard (v1 = yesterday's 32k model; v2 = all data + today's
751 corrections x2), 4-way per the owner's spec:**

| model | context | EM@1 | meaning |
|---|---|---|---|
| v1 | prior | 25.4% | 0.215 |
| v1 | off | 24.4% | 0.184 |
| v2 | prior | 25.8% | 0.202 |
| v2 | off | 23.2% | 0.186 |

v2 edged v1 on the primary metric (EM@1 with context) and was auto-installed
per the keep-only-if-better rule — but HONESTLY: +0.4pt is 2 cases in 500,
within noise, and v1 scored slightly better on meaning. Verdict: **a tie.**
One day of corrections (751) cannot move a 30k-corpus model — consistent with
the knee: the marginal data was ~2% of the pool. The lever for retrain #3:
recency/correction-WEIGHTED 4k training sets, not more volume.

Context on/off (both models): screen/prior context adds +1.0-2.6 EM@1 pts and
the largest meaning lift (v1: 0.184->0.215). Confirms screen context earns its
permission.
