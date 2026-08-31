# Frontier priors refresh — 2026-08-30

This is a dated transfer-prior review, not a Tilde result and not an executable
queue. It maps recent primary research and current open-source macOS input
systems onto the already frozen F03/F04/H01–H18 portfolio. The Learning Ledger
still decides what may run. As of this review, F03 remains the active causal
question; the later hypotheses remain locked.

## Strongest update

The highest-leverage underused ideas are measurement and routing changes, not
another larger model. Recent autocomplete, uncertainty, memory, and interaction
work repeatedly separates five decisions that a next-token score conflates:

1. whether the current moment is worth interrupting;
2. whether inference is worth its latency and energy;
3. which source deserves trust for this prefix;
4. how much of a candidate is safe to reveal; and
5. whether an accepted span survives subsequent editing.

Every item below is only a prior until Tilde freezes the same local corpus,
control, model/helper hashes, prompt, scoring policy, runtime controls, hard
gates, and retained-outcome review.

## P0 outside the model portfolio: real IMKit host truth

Apple's [IMKInputController](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller),
[IMKServerInput](https://developer.apple.com/documentation/inputmethodkit/imkserverinput),
and [NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient)
define contracts, but current implementations show that host behavior is not
uniform:

- [fcitx5-macos](https://github.com/fcitx/fcitx5-macos/blob/master/macosfrontend/macosfrontend.swift)
  carries app-specific preedit exceptions and explicitly calls out Escape,
  Backspace, arrows, normal keys, Terminal/iTerm, JetBrains, VS Code, Chrome,
  Spotlight, SwiftUI, Mail, and MacVim.
- Squirrel has distinct reports for [programmatic switch-away](https://github.com/rime/squirrel/issues/1140),
  [switch-in](https://github.com/rime/squirrel/issues/1162), and
  [selected-text/caret placement](https://github.com/rime/squirrel/issues/746).
- McBopomofo reports [IMKit activation/deactivation remote timeouts](https://github.com/openvanilla/McBopomofo/issues/346).
- Electron has a current [macOS preedit rendering report](https://github.com/electron/electron/issues/51557).
- [Appium Mac2](https://github.com/appium/appium-mac2-driver) is the closest
  reusable host-automation base, though it still cannot make a synthetic result
  count as Tilde IMKit proof.

The decisive matrix crosses native AppKit/SwiftUI, Chrome, WebKit,
Electron, Word/Mail, and Terminal/iTerm with empty/nonempty fields, end/middle
carets, selections, pending ghosts, manual/programmatic input-source changes,
app/focus changes, late results, Tab, Escape, Backspace, arrows, dead keys, and
ordinary typing. Hard pass means zero stranded marked text, raw-key bypass,
duplicate commits, caret errors, suffix damage, or lifecycle timeouts. Run it
serially in an isolated macOS user or test Mac because input-source state is
global. Repository issues are risk reports, not proof that Tilde has a bug.

## Twenty ranked falsifiable priors

| Rank | Theory to test | Portfolio map | Smallest decisive test and kill rule | Primary prior |
| ---: | --- | --- | --- | --- |
| 1 | Exposure-biased logs miscalibrate the controller | H05/H06 | Compare chronological authored continuations collected with suggestions disabled against ordinary exposed logs; kill if ranking, calibration, and worst-slice decisions do not materially change | [Synthetic Prefixes for real-time QAC](https://arxiv.org/abs/2510.01574) |
| 2 | Entropy boundaries beat a fixed visible-length cap | H02/H08 | Apply registered entropy stops to identical candidates, then separately test real decode cancellation; kill on useful-recall, bad-display, retention, or latency failure | [Chat-Ghosting](https://aclanthology.org/2026.eacl-long.209/), [code](https://github.com/blitzprecision/Chat-Ghosting) |
| 3 | Survival probability is a better display score than generation probability | H05/H06/H16 | Predict later retained/edit outcomes and compare chronologically with token log-probability at equal display budget; kill without calibrated retained-utility gain | [Generation Probabilities Are Not Enough](https://www.microsoft.com/en-us/research/publication/generation-probabilities-are-not-enough-exploring-the-effectiveness-of-uncertainty-highlighting-in-ai-powered-code-completions/) |
| 4 | Timing policy can help without changing the candidate | H04/H06 | Replay one candidate stream through fast, slow, and pause/burst-aware schedules; kill unless retention improves at equal opportunity and interruption budget | [Need Help? Proactive AI assistants](https://www.microsoft.com/en-us/research/publication/need-help-designing-proactive-ai-assistants-for-programming/) |
| 5 | A scene-value router beats always-scene and never-scene prompting | H03/H07 | Compare typed-only, always-scene, deterministic scene-quality, and tiny-router arms including stale/irrelevant scenes; kill on wrong-scene harm or overhead | [Router-Suggest](https://aclanthology.org/2026.eacl-industry.11/), [code](https://github.com/devichand579/MAC) |
| 6 | High-support seen prefixes belong to a deterministic phrase expert | H11/H12 | Route only preregistered high-support exact prefixes to a trie and unseen prefixes to Gemma; kill on ambiguity, leakage, or negligible retained gain | [Chat-Ghosting](https://aclanthology.org/2026.eacl-long.209/) |
| 7 | Silence should be a ranked candidate, not only a downstream threshold | H06/H12 | Add a reject candidate and compare at the same bad-display budget; kill if it duplicates the existing cascade or loses useful opportunities | [LaD](https://arxiv.org/abs/2505.20966), [code](https://github.com/JXZe/LaD) |
| 8 | Stable history plus a decayed recent cache beats one mixed memory | H09/H10 | Compare global/per-app mixed history with coarse stable statistics plus phrase/token recent memory on a chronological split; kill on worst-app/register harm | [LaD](https://arxiv.org/abs/2505.20966) |
| 9 | Memory value requires scope, retained action, and decay, not similarity alone | H09/H10/H11 | Add scope, later retention, and age to phrase ranking and ablate each against cosine/frequency retrieval; kill if the signals add no retained value | [Similarity = Value?](https://aclanthology.org/2025.emnlp-main.498/), [VAPS](https://github.com/E-qin/VAPS) |
| 10 | Static prefix replay gives the wrong answer when acceptance changes the future | H05 | Compare policy rankings under static replay and a sequential simulator where acceptance advances the authored trajectory; kill if conclusions do not change | [Next-action spreadsheet benchmark](https://www.microsoft.com/en-us/research/publication/a-benchmark-and-framework-for-evaluating-next-action-predictions-in-spreadsheets/) |
| 11 | Aggregate calibration hides unsafe app/register slices | H06/H09 | Freeze minimum slice sizes and worst-slice display risk, then compare global and per-slice thresholds; kill if global calibration is equally safe or data is insufficient | [CAP](https://proceedings.mlr.press/v304/tayebati26a.html), [multi-group uncertainty](https://proceedings.mlr.press/v286/liu25a.html) |
| 12 | Offline semantic dispersion can train a cheap pre-inference ambiguity gate | H07/H13 | Generate multiple futures offline, label dispersion, distill a small prompt score, and shadow it before skipping; kill on missed-opportunity or latency budget failure | [Semantic Self-Distillation](https://proceedings.mlr.press/v337/phillips26b.html) |
| 13 | Predicted edit boundary chooses visible length better than cap or entropy | H05/H08 | Hold candidates fixed and compare fixed cap, entropy stop, and predicted first-edit boundary; kill unless both retained utility and bad-display risk improve | Synthesis of the retention and uncertainty priors above |
| 14 | Probability-weighted semantic agreement beats exact agreement | H13/H14 | Compare exact-source agreement, literal shared prefix, and probability-weighted semantic clusters on identical sets; kill if gain cannot pay inference/latency cost | [Semantic Graph Density](https://proceedings.mlr.press/v286/li25b.html) |
| 15 | Edit Brain is safer when it must recover the exact selected anchor first | H17 | Compare direct replacement with search-then-replace and permit edits only after exact anchor recovery; kill on any suffix, selection, or caret corruption | [Search and Replace Infilling](https://aclanthology.org/2026.acl-long.361/) |
| 16 | Personal shorthand should start with deterministic/retrieval expansion | H18/H11 | Chronologically test exact mapping and retrieval expansion across ambiguity and register slices; kill automatic learning when one shorthand has competing expansions | [Parameter-Efficient Personalization for Text Entry](https://arxiv.org/abs/2312.14327) |
| 17 | User edits contain distinct final-text, preference, and edit-cost labels | H05/H16 | After data sufficiency, compare the three label encodings and their ensemble; kill if retained-text supervision alone matches them | [Principled Fine-tuning from User Edits](https://papers.nips.cc/paper_files/paper/2025/hash/f6d8ecbfd29e7ad87627758fadf8a7c6-Abstract-Conference.html) |
| 18 | Draftless n-gram speculation can reduce decode latency with exact parity | H15 | Only if profiling says decode dominates, compare exact output, p95, energy, and thermal behavior; kill on any output change or trivial speedup | [llama.cpp speculation](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md), [server](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) |
| 19 | KV prediction/cache sharing matters only when prefill dominates | H15/H16 | Profile first; prototype only if prefill dominates, with exact-output and energy gates; otherwise stop immediately | Apple [KV Prediction](https://machinelearning.apple.com/research/kv-prediction), [AFM cache sharing](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) |
| 20 | A deletable local personal adapter beats retrieval only after enough examples | H09/H16/H18 | Compare retrieval with a tiny adapter only after a frozen sufficiency gate and full-delete proof; kill on sparse-data regression or no retrieval gain | Apple [PLUM](https://machinelearning.apple.com/research/on-the-way) |

## Current open-source implementation priors

- [KeyType](https://github.com/johnbean393/KeyType) is a current on-device,
  system-wide macOS autocomplete implementation with useful benchmark,
  constrained-generation, prompt, latency, and app-geometry tests. Its focused
  field capture, overlay, and insertion use Accessibility, so that architecture
  cannot transfer into Tilde's IMKit product path.
- [LokalBot](https://github.com/stevyhacker/lokalbot) has useful cotyping tests
  for debounce, decode stopping, token healing, seam guards, focus flicker,
  session reconciliation, spell language, and chunked acceptance. Its AX/event
  insertion path is likewise a test prior, not an architecture option.
- [WindInput](https://github.com/huanfeng/WindInput) and
  [fcitx5-macos](https://github.com/fcitx/fcitx5-macos) are closer IMKit priors.
  Their secure-input rechecks, reconnection behavior, marked-text tests, and
  host exceptions strengthen the case for real-host proof rather than another
  synthetic UI assertion.

## Second-pass ranking delta

A later adversarial pass did not justify a twenty-first theory or a model
sweep. It changed the order and precision of the existing portfolio in six
ways:

1. **Complete the opportunity funnel before judging a policy.** F03 begins
   after a ghost is shown. A later controller study needs aggregate-only fixed
   reason codes from eligible keystroke through inference skipped, runtime
   unavailable, generated, filtered, cooldown, shown, and retained. The
   falsifier is simple: if this denominator leaves policy rankings and
   worst-slice decisions unchanged, stop paying its complexity cost.
2. **Do not call typed-through an intervention win.** It can be positive
   evidence that the candidate predicted what the author wrote while still
   being evidence that displaying the candidate saved nothing. Compare its
   continuation retention with ignored displays while separately scoring net
   saved keystrokes; kill the distinction if preregistered dwell/next-action
   controls erase it.
3. **Measure latency against the next action, not only the request clock.** A
   candidate can meet a global p95 and still arrive after the only useful
   deadline. Q10R already bounds the opposite mistake: readiness alone did not
   rescue lockability or compute. A later H04 test should ask whether
   ready-before-next-action and settled-before-next-key predict retention after
   controlling candidate quality.
4. **Separate prompt-prefix stability from Q08's cache-flag result.** Q08
   rejected one exact prompt-cache treatment; it did not test whether volatile
   scene timestamps and presence artifacts destroy reusable prefixes. Any
   byte-stable normalization must carry exact source attribution and die on one
   stale-scene event.
5. **Keep typed-suffix anchor reuse as an unqueued implementation prior.** A
   memory-only, field-bound cache may reuse an unchanged candidate only while
   the author types its exact suffix, with hard invalidation on divergence,
   backspace, focus, settings, or expiry. Require byte-identical visible output,
   zero cross-field reuse, and a material call or settled-latency reduction.
   [LokalBot's anchor-cache tests](https://github.com/stevyhacker/lokalbot/blob/master/LokalBotTests/CotypingSuggestionAnchorCacheTests.swift)
   are an implementation prior, not Tilde evidence. This mechanism does not
   cleanly match frozen H02 generation stopping or H04 cooldown behavior; it
   needs a separately authorized protocol or portfolio amendment before any
   executable comparison.
6. **Keep host adaptation and token healing out of the current causal lane.**
   Per-host transaction behavior remains a continuous product-proof surface,
   not a substitute for F03. Neural current-word healing remains below the
   portfolio boundary because Tilde deliberately gives current-word completion
   to the system spellchecker and phrase continuation to the neural layer;
   changing that product boundary needs a separate owner decision.

These are priority priors inside the existing portfolio, not a new execution
order. The canonical sequence remains F03, the Stage 0 exit gate, then
H01 -> H02 -> H03 -> H04. Real-host IMKit truth remains the Ledger's continuous
promotion gate rather than a newly invented prerequisite for opening H01. No
prior is executable until its named hypothesis, dependency, and preceding
Ledger exit gate are satisfied.

## Third-pass open-source audit and bounded runtime check — 2026-08-30

This aggregate-only, source-first pass inspected commit-pinned public code. It
did not inspect personal writing, persist prompts or candidates, install or
launch competitor apps or models, or change Tilde's queue, Ledger, production
policy, or runtime flags. The source snapshot was:

- FuJacob/cotabby `d73a18582ae657dea23c742bf7ca46d87f3a05b8`
  and its main-branch CotabbyInference dependency
  `7574a21516c65fc31f5cf8ef7380a03412eed480`;
- nikiomori/Pretype `a2db5f8cd2706911e84e51a4e2b4f058c60c0dbc`;
- johnbean393/KeyType `21df2cc1f5271d3712d567e3c2491ac09174caf3`;
  and
- stevyhacker/lokalbot `b21a657a0a5ca1fe2bcfa74c0e579395272c59ce`.

Five bounded mechanisms sharpen existing priors:

1. **Resolve opportunities instead of counting every draw.** Cotabby's pure
   [availability evaluator](https://github.com/FuJacob/cotabby/blob/d73a18582ae657dea23c742bf7ca46d87f3a05b8/Cotabby/Support/Suggestion/Request/SuggestionAvailabilityEvaluator.swift#L3-L81)
   centralizes pre-generation decisions, while Pretype's
   [resolved-offer rule](https://github.com/nikiomori/Pretype/blob/a2db5f8cd2706911e84e51a4e2b4f058c60c0dbc/Sources/Pretype/Stats.swift#L66-L105)
   waits for outcome and readable dwell. Tilde's gap remains the upstream
   interval before its shown-only F03 event begins. The smallest same-corpus
   test replays fixed synthetic traces through the current denominator and an
   exclusive `eligible -> terminal reason` funnel, requiring balanced counts
   before comparing policy ranking and worst slices. Kill it if counts do not
   balance, raw text is needed, or the decisions do not change. Do not copy
   Pretype's automatic per-app mute or its product-specific thresholds, and do
   not copy Cotabby's optional Screen Recording semantics.
2. **Use one exact-prefix session rule for outcome truth and staleness.**
   Pretype [shrinks only on an exact candidate prefix and separates
   typed-through from divergence](https://github.com/nikiomori/Pretype/blob/a2db5f8cd2706911e84e51a4e2b4f058c60c0dbc/Sources/Pretype/SuggestionController.swift#L565-L589),
   while Cotabby revalidates a
   [current work ID and live content generation](https://github.com/FuJacob/cotabby/blob/d73a18582ae657dea23c742bf7ca46d87f3a05b8/Cotabby/App/Coordinators/Suggestion/SuggestionCoordinator%2BPrediction.swift#L617-L685).
   Tilde already has strong client, bundle, context, range, request-order, and
   acceptance-time guards; the narrower gaps are that any settled typing can
   become `typed-through`, even after divergence, and there is no delayed-result
   fixture across a non-content policy revision. Replay exact continuation,
   one-character divergence, backspace, focus/selection change, supersession,
   partial acceptance, and a delayed partial/final across a policy revision.
   Kill on one stale show or accept, one rejected valid continuation, any need
   to persist text, or no change to the net-saved-versus-retention conclusion.
   The transfer is the pure state rule, never either project's AX/event path.
3. **Join pipeline latency to the writer's deadline.** KeyType's
   [phase trace](https://github.com/johnbean393/KeyType/blob/21df2cc1f5271d3712d567e3c2491ac09174caf3/KeyType/Logic/Completion/CompletionController.swift#L83-L243)
   separates prompt, debounce, generation, and presentation, but records the
   visible rollup only for shown results. Tilde has a post-show next-action
   field and separate generation timing without one joined request-to-action
   record. Replay identical candidates with authored next-key times and compare
   request-clock p95 with `ready-before-next-action` and
   `settled-before-next-key`. Kill if
   policy rankings and worst-slice decisions stay unchanged or deterministic
   replay cannot capture every timestamp. Keep only local aggregate timings and
   fixed outcomes; KeyType's AX overlay/insertion cannot transfer.
4. **Segment acceptance in user-visible Unicode words.** LokalBot's pure
   [acceptance chunker](https://github.com/stevyhacker/lokalbot/blob/b21a657a0a5ca1fe2bcfa74c0e579395272c59ce/LokalBot/Cotyping/CotypingAcceptanceChunker.swift#L3-L71)
   and [fixtures](https://github.com/stevyhacker/lokalbot/blob/b21a657a0a5ca1fe2bcfa74c0e579395272c59ce/LokalBotTests/CotypingAcceptanceChunkerTests.swift#L7-L227)
   use the same user-facing segmentation for highlight and insertion, including
   space-less scripts. Tilde's next-word accept is whitespace-only. Compare the
   current chunker with an ICU-word treatment on fixed Latin punctuation,
   URLs/decimals, abbreviations, CJK, Japanese, Thai, whitespace, emoji, and
   non-BMP cases with authored boundaries. Kill on a non-prefix result, suffix
   or caret corruption, a Latin regression, supported-macOS drift, or no
   reduction in space-less over-accept errors. Keep IMKit insertion and the
   three-word display control; a new phrase gesture is not implied.
5. **Reuse at most one inference sequence with a changing external identity.**
   Cotabby validates byte and token common prefixes plus an exact sampling
   fingerprint before [trimming and extending one serialized sequence](https://github.com/FuJacob/cotabby/blob/d73a18582ae657dea23c742bf7ca46d87f3a05b8/Cotabby/Services/Runtime/Llama/LlamaRuntimeCore.swift#L546-L668).
   CotabbyInference keeps one internal slot while changing the
   [public sequence ID](https://github.com/FuJacob/cotabbyinference/blob/7574a21516c65fc31f5cf8ef7380a03412eed480/Sources/CotabbyInferenceEngine/CotabbyInferenceEngine.cpp#L83-L176),
   so stale cancellation cannot hit a replacement. Tilde has no equivalent
   proof for its signed app-owned `llama-server` helper. Profile first; only if
   prefill dominates, replay one frozen prompt sequence through fresh calls and
   one field-bound reusable slot, requiring byte-identical output, exact
   field/policy invalidation, safe cancellation replacement, lower
   first-stable-word p95, and acceptable energy. Stop immediately if prefill
   does not dominate or safe trim is unsupported; otherwise kill on one output
   mismatch, cross-field reuse, stale cancellation, or immaterial benefit. Do
   not embed CotabbyInference or move runtime ownership into the IME.

The same pass did **not** promote a separate AX-style stale-result mechanism:
Tilde already covers the core late-result and acceptance-time field checks.
LokalBot's typed-suffix anchor cache is also not a sixth item; the second pass
already records it as unqueued and separately authorizable. Items 1–3 restate
the second-pass measurement priorities, item 4 sharpens the existing LokalBot
prior, and item 5 sharpens ranked prior 19 plus the stable-prefix warning.

### Bounded cache-contamination diagnostic

A separate Luna aggregate-only check used Preview9B helper `0.2.0-dev`, commit
`2115b73`, helper SHA-256
`e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546`,
and the exact pinned Qwen 9B model (5,629,109,312 bytes; SHA-256
`4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`). An
isolated default server (`auto=4` slots) was compared with
`--parallel 1 --cache-ram 0 --no-cache-idle-slots`. Both arms completed 40/40
requests. Default p50/p95/max was `324/1080/1114 ms`; control was
`332/1009/1462 ms`. All 8/8 repeated prompts matched after foreign churn, with
zero foreign-marker hits, zero cross-case response-hash replays, and an
identical aggregate response digest.

This bounded diagnostic failed to reproduce contamination or stale completion
in that synthetic workload. It was not a preregistered F03 result, does not
establish a latency or cache benefit, and is inconclusive outside that
workload. No raw prompts or outputs were retained, no
persisted or product runtime flag changed, isolated ports 54053 and 54105 were
closed, and product ports 17875 and 17876 were untouched.

This third pass is documentation, not promotion. F03 remains the active causal
question, H01–H18 remain locked, and neither the executable queue nor Learning
Ledger changes.

## Fourth-pass runtime, interaction, and control refinements — 2026-08-30

A final overlap audit searched for mechanisms that the first twenty theories,
Q08/Q09/Q12/Q13, and H01–H18 do not already answer. These are protocol
refinements or owner-gated portfolio candidates, not executable work. Risk
reports from dependencies identify what to falsify; they are not evidence that
Tilde's pinned helper has the reported behavior.

### Highest-priority refinements

1. **Cancellation must reclaim compute, not only suppress stale UI.** Current
   llama.cpp [issue 24496](https://github.com/ggml-org/llama.cpp/issues/24496)
   reports that a disconnected client can leave generation occupying a slot;
   the server exposes slot and decode state in its
   [documented endpoints](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).
   On the pinned helper and public synthetic prompts, cancel before the first
   token, after the first token, and after the first stable word, then
   immediately submit request B. Require request A to stop decoding within one
   scheduler quantum, B p95 within 5% of an idle-slot baseline, zero stale
   display, and bounded energy. Fold this into H02/H15 only after F03; the
   existing field/request guards prove stale-output safety, not capacity
   reclamation.
2. **Cache reuse needs decision parity, not just text parity.** llama.cpp's
   [server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
   warns that cache reuse and batch geometry need not produce bit-identical
   logits; current [issue 19034](https://github.com/ggml-org/llama.cpp/issues/19034)
   and earlier [issue 7594](https://github.com/ggml-org/llama.cpp/issues/7594)
   report related greedy/cache divergence. Compare cold/no-cache, first-cache,
   repeated-cache, and foreign-slot-churn arms on identical public prompts and
   registered batch settings. Require zero token, visible-output, cleaner,
   fact-filter, confidence-bucket, or show/silence flips, with probability
   drift no larger than repeated-cold noise. Q08 and the Luna diagnostic did
   not establish parity through Tilde's downstream policy boundary.
3. **Probability evidence itself needs a frozen contract.** The same server
   documentation distinguishes raw `n_probs` from `post_sampling_probs`.
   Replay fixed public cases with top-N depths 1, 5, 20, and 100 and both
   probability surfaces. Compare entropy/margin convergence, ECE, Brier score,
   risk-coverage, payload/latency, and final show/silence disagreements. Select
   the smallest N only if disagreement is at most 0.5 percentage points and
   registered calibration bounds hold. Q05/Q06's selected-token mean does not
   prove that future H06 receives sufficient probability evidence.
4. **Measure the scene's causal contribution to the same candidate.**
   [Context-Aware Decoding](https://aclanthology.org/2024.naacl-short.69/) and
   its [official implementation](https://github.com/xhan77/context-aware-decoding)
   motivate scoring one frozen candidate under typed-plus-scene and typed-only
   context. First teacher-force existing candidates across fresh, stale,
   wrong, irrelevant, literal, and paraphrased scenes; do not add a second
   visible generation path. The scene-support delta must improve held-out
   factual risk-coverage at equal display budget, with zero protected
   name/number leakage and acceptable p95/energy overhead. This sharpens H03;
   Q12's literal-echo filter answers a different question.
5. **Select and place scene facts inside Gemma's local window.** The official
   [Gemma 4 E2B model card](https://huggingface.co/google/gemma-4-E2B),
   [technical report](https://arxiv.org/abs/2607.02770),
   [LongLLMLingua paper](https://aclanthology.org/2024.acl-long.91/), and
   [reference code](https://github.com/microsoft/LLMLingua) motivate an equal-
   byte H03 comparison between recency packing, query-aware extractive line
   selection, and position permutations near `Continuation:`. Hold facts,
   source, freshness, and token budget fixed. Kill on any redaction or typed-
   context regression, stale/injection harm, selector overhead beyond the
   first-stable-word budget, or no supported-usefulness gain.

### Product-proof and runtime refinements

6. **The deterministic current-word layer should be language aware.** Apple's
   [`NSSpellChecker`](https://developer.apple.com/documentation/appkit/nsspellchecker),
   [completion API](https://developer.apple.com/documentation/appkit/nsspellchecker/completions%28forpartialwordrange%3Ain%3Alanguage%3Ainspelldocumentwithtag%3A%29),
   [preferred languages](https://developer.apple.com/documentation/appkit/nsspellchecker/userpreferredlanguages),
   [per-word language detection](https://developer.apple.com/documentation/appkit/nsspellchecker/language%28forwordrange%3Ain%3Aorthography%3A%29),
   and Apple's [short-string language-identification research](https://machinelearning.apple.com/research/language-identification-from-very-short-strings)
   support comparing Tilde's hard-coded English call with OS-selected and
   conservatively detected language arms. Use public multilingual prefixes and
   real hosts. Require fewer wrong-language/invalid-prefix suggestions outside
   English, zero English or latency regression, and silence for ambiguous
   short prefixes. H07's neural skip does not test this separate dictionary
   layer.
7. **Acceptance must be one undo-coherent native transaction.** Apple's
   [`unmarkText`](https://developer.apple.com/documentation/appkit/nstextinputclient/unmarktext%28%29),
   [`insertText`](https://developer.apple.com/documentation/appkit/nstextinputclient/inserttext%28_%3Areplacementrange%3A%29),
   and [`breakUndoCoalescing`](https://developer.apple.com/documentation/appkit/nstextview/breakundocoalescing%28%29)
   contracts motivate a real-IMKit host matrix for full/word acceptance,
   punctuation, middle caret, selection, and a remaining ghost. For every
   case, accept, undo once, then redo once. One undo must remove exactly the
   accepted suffix without touching authored text; one redo must restore it;
   zero duplicate insertion or stranded marked text is allowed. F03's
   aggregate `undone` outcome cannot substitute for this interaction proof.
8. **Foreground contention may need explicit scheduling/QoS policy.** The
   llama.cpp [server controls](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
   and Apple's [macOS QoS guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheTaskLevel.html)
   support a future H15 test under controlled compile, video, and mixed load.
   Freeze model, prompt, and slot settings; compare key-callback p99,
   first-stable-word p50/p95/p99, deadline hit rate, host responsiveness,
   energy, and thermals. Promote only a material deadline improvement with
   zero key-loop regression and bounded energy/thermal cost.
9. **Thermal and power pressure should degrade to deterministic help or
   silence.** Apple's [thermal guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/RespondToThermalStateChanges.html),
   [`ProcessInfo`](https://developer.apple.com/documentation/foundation/processinfo),
   and [Low Power Mode API](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled)
   motivate a future H07 arm where nominal state permits neural inference and
   serious/critical or low-power state uses exact dictionary/personal matches
   or silence. Require zero late/stale ghosts or key-latency regression and
   better energy/recovery behavior; never display a lower-quality neural
   candidate merely because the machine is throttled.

### Owner-gated portfolio candidates

10. **A conservative automatic lane may coexist with an explicit longer
    completion shortcut.** Microsoft's
    [efficient-invocation guideline](https://www.microsoft.com/en-us/haxtoolkit/guideline/support-efficient-invocation/)
    and [phrase-versus-word autocomplete study](https://www.microsoft.com/en-us/research/publication/suggesting-phrases-vs-predicting-words-mobile-text-composition/)
    motivate comparing automatic-only with automatic-plus-summon using the
    same frozen generator. Measure automatic interruptions, invoked retention,
    RNKS/time saved, correction/undo, discoverability, and host shortcut
    conflicts. Require unchanged automatic risk and meaningful retained
    invoked utility. This is outside H04/H08's automatic-only boundary and
    needs owner approval before entering the portfolio.
11. **Utility may be typing effort saved rather than characters retained.** A
    [large-scale query-autocomplete interaction study](https://www.microsoft.com/en-us/research/publication/on-user-interactions-with-query-auto-completion/)
    motivates comparing RNKS length with predicted milliseconds or physical
    key effort saved, using only local aggregate timing buckets. Require
    incremental prediction of stable-final time and lower time-to-finish at the
    same bad-display rate; reject on keyboard-layout transfer or calibration
    failure. This can refine H04 after the opportunity funnel is complete.
12. **Any on-device adaptation must be cautious, text free, and reversible.**
    [Sequential decision-making for personalized autocompletion](https://arxiv.org/abs/2403.15502)
    and Microsoft's [cautious-adaptation guideline](https://www.microsoft.com/en-us/haxtoolkit/guideline/update-and-adapt-cautiously/)
    motivate, only after a global H06 gate passes, a shadow device-local
    interruption intercept with a frozen baseline, minimum sample size,
    hysteresis, and exact rollback. Require chronological cross-app/week gain,
    no oscillation or worst-slice regression, no visible random exploration,
    and no retained text. This is the lowest-confidence refinement because it
    partially overlaps H05/H06.

Explicit non-additions: per-user quietness is an H06 parameterization, Gemma
positioning belongs inside H03, and thermal routing belongs inside H07. Do not
add a new speculative-decoding or model-swap theory: existing priors already
cover draftless speculation/KV sharing, while a new draft model or training
asset conflicts with the fixed-Gemma production contract. The server's
documented `t_max_predict_ms` activates only after a newline, so it is not a
true hard autocomplete deadline for Tilde's newline-stopping request shape.

This fourth pass changes neither stage nor queue. F03 remains the only active
causal question; every item above stays locked until its existing dependency
and promotion gates are satisfied or the owner explicitly amends the program.

## Boundary decisions

- This review does not reopen Q09's strong directional negative on 16
  independent futures; Q09 remains formally inconclusive under the later F01
  evidence contract. Draftless speculation and semantic-dispersion
  distillation ask different questions.
- It does not reopen Q13's rejected eight-word cap. Entropy/edit boundaries are
  future registered challengers against the surviving three-word control.
- LaD has industrial online evidence, but it is query autocomplete rather than
  personal system-wide prose. Every other source is similarly a transfer prior
  from chat, code, search, spreadsheets, memory, or uncertainty research.
- No item changes production, enters the Learning Ledger as a result, or unlocks
  H01–H18. First finish F03. Apply the real IMKit matrix continuously to any
  candidate that reaches preview, as the Ledger already requires.
