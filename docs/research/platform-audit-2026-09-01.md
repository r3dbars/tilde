# Platform audit — 2026-09-01

> **Corrections (2026-09-02).** The first version of this document cited a
> decided "Q10R" early-start result in three places, with specific numbers.
> No such record exists: `docs/experiments/Q10-early-start-timing-falsifier.md`
> reads NOT RUN, and neither the Learning Ledger nor the lab log carries a
> Q10R entry. Those citations are struck below, the rejected-mechanisms tally
> is 2 of 3, and early start returns to the open questions. The twenty-agent
> field audit of 2026-09-02 found the discrepancy (lab log, same date).

A reconstruction of Tilde from its code, its Lab, and its experiment record,
made on 2026-09-01 with the owner's question in hand: how does this become
the best personal autocomplete on macOS, on quality and on speed. It is a
dated read, not a queue. The Learning Ledger still decides what may run.
The same day's engineering that came out of it is recorded in
[`lab-log.md`](lab-log.md) (entries dated 2026-09-01 and 2026-09-02) and
[`docs/model-lessons.md`](../model-lessons.md).

Five read-only code audits fed this document (the production request
path, the deterministic policy layer, the two context sources, the helper
runtime, and the experiment record). Line references are to `main` at
commit `97de15b7`; later commits moved some of them.

## The short version

- **The generator is not the bottleneck.** Three independent instruments
  (the campaign store, the ~1.5M-observation mining sweep, and the
  simulated typist) agree that Gemma E2B, Qwen 9B, and Gemma 26B fail the
  same way in the same categories. What moved the number was the filter
  stack: bad-when-shown fell from 43% to 18% offline with zero model change
  (Q11, Q12).
- **The default model was running the weaker filter stack.** Selecting Qwen
  turns on factual grounding and the 24-character echo floor. Gemma shipped
  with grounding off and the floor Q12 proved was deleting correct short
  answers.
- **Speed on Gemma was dominated by fixed overhead, not decode.** Two
  code-signature verifications per typed word, a fresh socket and TCP
  session per request, a 200 ms reveal floor in Chromium hosts, and a full
  3.4 GB SHA-256 on every launch and restart. The model itself answered at
  91 ms p50.
- **Qwen's tail problem had a cheap fix.** It generated 12 tokens for a
  3-word ghost and the stream was never cut once the cap was reached.
- **The exact-text context path existed and was never used.** The
  Accessibility reader beats OCR on precision and latency and is tried
  first, but nothing in the app ever asked for the permission.
- **The ruler still is not done.** F03 has zero clean live retained-outcome
  events. Every quality claim below is offline.

## Where it stood on 2026-09-01

| Measure | Value | Source |
| --- | --- | --- |
| Bad-when-shown, offline, Qwen arm | 43% → 30% → 18% | Q08 baseline → Q11 silence gate → Q12 echo-24 + grounding |
| Useful displays, same test | 473 → 765 | Q12 echo retune alone; grounding removed 35 wrongs at zero useful cost |
| Gemma live model latency | p50 91 / p95 190 / p99 339 ms | 1,213 completions, `production-e2b-live-latency-1213` |
| Qwen 9B live model latency | p50 192 / p95 366 / p99 416 ms | 148 completions, below the 200-completion verdict floor, over the 400 ms p99 budget |
| Clean live retained-outcome events | 0 | F03 IMPLEMENTING |
| Latency-hiding mechanisms rejected | 2 of 3 | Q08 prompt cache (p95 −0.47%), Q09 16-branch lattice. Q10 early start: NOT RUN — the "Q10R" figures this document first carried have no registered record (see Corrections) |

## One keystroke, reconstructed

The production path for a Gemma user typing a space after a word in a
Chromium host, before any of the 2026-09-01 changes.

1. **The keyboard sees whitespace.** Model requests fire only after a space;
   letters go to the macOS spell checker; punctuation triggers nothing at
   all. There is no inference debounce.
2. **The reveal clock starts.** Chromium hosts cannot show a ghost before
   keystroke + 200 ms, native hosts 50 ms; the clock starts at schedule time,
   so a 60 ms answer still waits. The delay guards a real caret ping-pong
   defect.
3. **New socket, two signature checks.** A fresh connection per request;
   both the keyboard and the app resolve the peer's code identity every
   time, budgeted at 250 ms p99 on its own.
4. **Health and target checks.** Enumerate every file descriptor of
   llama-server; copy the full window list to confirm the front window (and
   again on every streamed partial).
5. **Scene read.** Memory-only snapshot from the last capture, never a
   capture on the hot path. Nearly always OCR, because Accessibility
   permission was never requested.
6. **Pre-inference gates.** Sensitive scene, injection, no incoming turn,
   resolved conversation, ambiguous choice, non-actionable scene,
   3-character activation, growing-edge check. Evaluated twice, once in the
   host and once in the engine. Three of the detectors Q11 supported are
   compiled in and switched off.
7. **Prefill.** Scaffold (70–180 tokens, fixed per register) + scene block
   (quantized to 250-character steps to keep the KV prefix stable) + field
   tail. Cache reuse held until the field passed 3,000 characters, then the
   tail slid one character per keystroke and invalidated the prefix on every
   word.
8. **Decode, streamed.** 20 tokens for Gemma, 12 for Qwen. The loop ran
   until the model stopped, even after the visible cap (8 words / 80
   characters, or 3 words / 42) had been reached and nothing further could
   be shown. A partial is revealed only at a whitespace boundary.
9. **Clean and filter, per partial.** Control-character reject, instruction
   echo, typed-prefix echo, context replay, self-repetition, dangling-tail
   repair, visible cap, scene echo (3 words / 10 characters, including the
   writer's own turns), factual grounding (off for Gemma). The cleaner
   re-tokenized the full 3,000-character context on every partial.
10. **Marked text.** Grow-only: the ghost never shrinks or rewrites. Tab
    accepts a word, the tilde key accepts everything. A fully consumed
    ghost issued no new request.
11. **Outcome ledger.** Text-free retained-character counts at 5 s, 30 s,
    and segment close, only for ghosts that were shown: a keystroke a gate
    silenced produced no event, so the funnel above the ghost was invisible.

## What the evidence has settled

1. Scene context is essential: correct context 33.3% exact reply starts,
   deliberately wrong context 20.0%, typed-only 14.5%, across 3,000
   completions and all three splits (`certified-context-falsification`).
2. Three visible words beat eight. Cap-8 halved useful displays (766 → 396)
   and tripled bad-when-shown (18% → 49%) on the tuned arm (Q13); reproduced
   independently on the simulated typist.
3. Tilde's own filters were eating correct facts. The scene-echo detector
   killed 304 candidates and every one carried a fact; its floor sat exactly
   on the 3-word cap. Raising the character floor 10 → 24 recovered +62%
   useful at unchanged bad displays (Q12).
4. Names-and-numbers grounding is free: 35 unsupported-fact wrongs removed,
   zero useful lost (Q12).
5. Three ordinary-silence subcategories leak at ~100% and contain zero
   useful displays; gating them cut bad-when-shown 13.2 points at 100%
   useful retention (Q11, development confirmation only).
6. The residual failures are model-independent and deterministic: five
   chronic categories fail identically across both model families and every
   sampler; per scenario the outcome is all-wrong or all-useful across seeds.
   It is generic-continuation bias at the entity slot, not a missing fact in
   the prompt (mining sweep, shared-floor autopsy, issues #443, #447, #457).
7. Parameter count does not predict quality here: Qwen 9B 43, Nemotron 9B
   42, Gemma 26B 40, Qwen 4B 37, Gemma E2B 17 on the same protocol; the 26B
   came last on the simulated typist.
8. A mean-token-probability floor removes bad displays but pays in
   protected slices (Q05, Q06, issue #456).
9. Prompt-cache reuse engaged and bought nothing on the tail (Q08: p95
   429 → 427 ms), measured on Qwen with cache-reuse 0 and n_probs 5, so it
   says little about the shipped Gemma configuration.
10. Sampling more futures does not produce different futures (Q09).
11. Starting early buys a real lead and cannot lock — UNSUPPORTED. This
    line originally cited "Q10R" figures (readiness 100%, median lead
    689 ms, lockable 12.2%, compute 1.87×) that have no registered record;
    Q10 is NOT RUN. Treat early start as an open question until Q10 runs.
12. Tab is not the utility; retained characters at segment close is the
    usable live horizon for this writer (scientific-program.md, first F03
    ingest).

## Quality levers, ranked

| # | Lever | Status on 2026-09-02 |
| --- | --- | --- |
| Q1 | Give Gemma the filter stack Qwen already has (echo-24 + grounding) | Not done; needs the Q12 validation campaign with a Gemma control arm |
| Q2 | Ask for Accessibility permission | **Done** (PR #461): one-time prompt at launch, menu line "Exact Screen Text" |
| Q3 | Stop the echo detector reading the writer's own turns | Not done; offline replay on the Q12 cache first |
| Q4 | Promote the extended silence gate (Q11) | Not done; validation campaign |
| Q5 | Instrument the funnel above the ghost (`policyHidden` events) | Not done |
| Q6 | Fix the non-actionable gate reading the head of the buffer | **Done for the 9B preview** (PR #461, #462): current sentence for the cue, stands down once the current paragraph has ≥3 words |
| Q7 | A register for code editors and terminals | Not done; the owner does not want terminals excluded |
| Q8 | Window title and freshness in the scene block | **Title done for the 9B preview** (PR #461); freshness not done |
| Q9 | Fix dangling-tail repair under the 3-word cap | Not done |
| Q10 | Register the confidence ROC (Q16) | Not done |
| Q11 | Delete inert policy (Intent Futures output, duplicate suppression call) | Not done |
| Q12 | Personal History into the prompt | Stage 3, locked |

## Speed levers, ranked

| # | Lever | Status on 2026-09-02 |
| --- | --- | --- |
| S1 | Cut the stream once the visible cap has settled | **Done, all profiles** (PR #461) |
| S2 | Cache peer code-signing identities per live process | **Done, all profiles** (PR #461) |
| S3 | Shorter reveal floor in Chromium/Electron hosts | **Done for the 9B preview** (PR #463): 120/80 ms vs 200/120 |
| S4 | Warm the scaffold; stop the context window sliding | **Done, all profiles** (PR #461) |
| S5 | Draftless n-gram speculation (`--spec-type ngram-*`, verified present on the helper) | Not done; needs a runtime-class campaign |
| S6 | Hash the model once per process | **Done, all profiles** (PR #461) |
| S7 | Per-partial housekeeping (window-list copy, cleaner re-tokenization, per-request URLSession) | Not done |
| S8 | Report first-token and first-partial timings | **Done** (PR #461) |
| S9 | Pin the server flags the product depends on | Not done |
| S10 | A draft model for Qwen 9B | Later |

Interaction levers added after the audit, from the owner's felt experience:

| Lever | Status |
| --- | --- |
| Chained accept (request the next continuation once a ghost is consumed) | **Done for the 9B preview** (PR #462), with the Electron caret-lag fix |
| Punctuation as a request boundary | **Done for the 9B preview** (PR #463) |

## Built and switched off (as found on 2026-09-01)

| Capability | State | What held it back |
| --- | --- | --- |
| Factual grounding (names and numbers) | Wired, tested, on for Qwen only | Profile flag; Q12 validation not run |
| 24-character scene-echo floor | On for Qwen only | Same |
| Extended ordinary-silence detectors | Compiled in, off | Q11 supported at dev; validation not run |
| Accessibility text reader | Preferred over OCR, never enabled | No permission prompt anywhere (fixed) |
| H01 block-randomization harness | Built, disabled, Model Preview only | F03 not supported |
| n-gram speculative decoding | In the helper binary | Never flagged, never measured |
| Five-source candidate set and oracle@K replay | Plumbing complete, two sources populated | Stage 3 locked |
| Outcome-event funnel fields | Schema has them | No production writer sets them |
| First-token and first-partial timings | Logged | Not in the report, no budget (fixed) |
| Intent Futures | Runs every request | Output discarded for the only register with a scene |
| GLiNER redaction model | Bundled | Only the rules layer runs on the live path |

## What not to do

- Another model sweep. The catalog is stale against the tuned filter
  stack, and the residual failure is a curriculum problem (#457), not a
  size problem. If anything, re-run Qwen 4B once on the echo-24-grounded
  arm: lowest bad rate in the catalog, 119 ms faster than 9B, never
  configured.
- More branches, hotter branches, or a bigger K (Q09; Q10 is still NOT RUN).
- Whole-sentence ghosts or an 8-word default (Q13). The chained accept is
  how "complete the sentence" is delivered without touching the cap.
- Private LoRA or continual training before the reward is real.
- Trusting the simulated typist's absolute numbers.
- Reading Q08 as a statement about the shipped app.

## Owner calls still open

- Which model is the default once both run the same filter stack. Nobody
  has plotted the latency-versus-quality frontier; a 1×1 runtime campaign
  on Gemma E2B, Qwen 4B, and Qwen 9B, all on the tuned arm, would draw it.
- Selecting Qwen currently switches six knobs at once (temperature, token
  budget, visible cap, character cap, echo floor, grounding). Decide whether
  display policy follows the model or the user.
- Mid-word requests: the model never sees a partial word; Q10R says the
  timing window exists.
- The Screen Recording hard requirement: one revoked permission makes the
  product look dead, and the target-identity check can silence hosts whose
  front window belongs to a helper process with no distinguishing
  diagnostic.

## Sources

AGENTS.md, docs/research-roadmap.md, docs/research/lab-log.md,
docs/research/scientific-program.md, docs/research/frontier-priors-2026-08-30.md
(PR #459), docs/experiments/F01–F04 and Q01–Q13, the bundled Learning
Ledger, issues #434–#457, and read-only audits of Sources/InlineGhostIME,
Sources/TildeApp, Sources/TildeCore, and Sources/TildeLabKit. Helper flags
were verified on the installed Tilde 9B Preview helper (llama.cpp 0.2.0-dev,
commit 2115b73). No personal writing, screen text, prompts, or model output
were read or reproduced.
