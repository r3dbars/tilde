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
  H01–H18. First finish F03 and the real IMKit host gate.
