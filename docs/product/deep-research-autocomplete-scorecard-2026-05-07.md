# Deep Research Autocomplete Scorecard - 2026-05-07

Source research:
`/Users/redbars/Library/Caches/com.apple.SwiftUI.Drag-9DB841D4-8068-4044-B0CF-B2F61B9E12BB/deep-research-report (5).md`

Repo state graded: `codex/deep-research-scorecard` at `46ee5f4`, based on
`origin/main`.

## Executive Grade

Baseline deep research score: **78/100**.

Current implementation score after the first build pass: **84/100**.

This is a strong prototype with real engineering depth. It has local MLX
runtime support, app compatibility profiles, privacy-safe tracing defaults,
one-suggestion UI, next-word Tab acceptance, insertion verification, stale
request cancellation, and a serious proof harness.

It is not yet magical by the research bar. The biggest misses are:

- The trigger gate is still too eager compared with the research timings.
- Phrase and sentence quality rely mostly on prompt plus cleaner, not a real
  utility/ranking stack.
- Accepted-and-kept and annoyance loops exist in core/reporting code, but the
  live app path does not appear to close those loops yet.
- Field-kind classification exists, but the main activation call does not pass
  field kind into the policy.
- Cross-app proof is honest but incomplete for Notes, Obsidian, Codex, Claude
  Code, Claude desktop, and real production editors.

The repo's existing Apple-native score is **82/100**. This score is lower
because it grades against the research definition of "magical autocomplete,"
not only Mac plumbing, safety, and proof infrastructure.

## Implementation Progress

Pass 1 shipped these improvements:

- Hard `<NO_SUGGESTION>` prompt and cleaner path.
- Live field classification in activation and trace metadata.
- Live accepted-and-kept tracking at 2s, 10s, 30s, and blur.
- Live annoyance quiet mode for typed-over, Esc, insertion failure, repeated
  rejection, accepted-then-deleted, manual pause, and app disable.
- Mode-aware trigger timing: 90-140ms word, 140-240ms phrase, 280-450ms
  sentence boundary, plus line-start suppression.
- Prefix-family cooldowns: 5s typed-over, 15s Esc, 250ms deletion.
- Display-score object and live presentation gate with trace-safe components.
- One-line visible suggestion cap under 42 characters.

Remaining high-impact gaps:

- Display score is heuristic; it does not yet use real accepted-and-kept
  probability or multi-candidate ranking.
- Sentence mode is still a stricter boundary path, not a full first-class lane.
- Behavior profiles for email, bullets, code, docs/prose, notes, and AI chat
  are still thin.
- Replay-first real-app proof is still missing.
- Cross-app proof rows still need fresh screenshot-backed acceptance slices.

## Research Bar

The report defines "magical" autocomplete as low-amplification translating
support:

- Finish what the writer was already about to say.
- Stay short enough to verify instantly.
- Preserve writer ownership.
- Avoid ambient rewriting, planning, or next-action suggestions.
- Show fewer, better-timed suggestions.
- Hide the moment the user's intent diverges.

The target app should be a gate, not a timer. A request should pass only when
the field is eligible, text is stable, recent behavior says help is welcome,
expected utility is positive, and the app/field/prefix is outside cooldown.

## Scorecard

Baseline scorecard from the initial audit:

| Category | Weight | Score | Weighted | Current read |
| --- | ---: | ---: | ---: | --- |
| Product boundary and writer agency | 8 | 87 | 7.0 | Correctly avoids ambient rewrite/action behavior and keeps suggestions short, but sentence continuation can still drift into planning. |
| Trigger gate and boundary timing | 14 | 69 | 9.7 | Strong stale/deletion/focus basics, but app timings are 0-15ms where research asks 90-450ms by mode. |
| Ranking and expected utility | 12 | 68 | 8.2 | Word ranking exists; phrase/sentence ranking is still mostly single-candidate prompt plus cleaner. |
| Context and prompt hygiene | 9 | 73 | 6.6 | Context is small and local, but lacks field metadata, style sketch, recent kept suffixes, and a hard `<NO_SUGGESTION>` prompt path. |
| Output shape and cleanup | 8 | 88 | 7.0 | Cleaner is one of the strongest parts of the app. |
| Local runtime and latency | 10 | 84 | 8.4 | App-owned MLX runtime, warm model, streaming, timing slices; no KV/session cache and default length is still a little long. |
| Ghost text UX and controls | 10 | 84 | 8.4 | One suggestion, Tab next word, full accept when allowed, Esc dismiss, stale hiding; atomic undo is not proven. |
| Mode profiles and cross-app safety | 10 | 74 | 7.4 | Strong app profiles, but behavior modes are not first-class for email, notes, bullets, docs, code, forms, search, and AI chat. |
| Learning, annoyance, accepted-and-kept loop | 12 | 65 | 7.8 | Metrics and core types exist; live app wiring appears incomplete. |
| Metrics, replay, and proof gates | 5 | 84 | 4.2 | Trace/report scripts are strong; true replay-first real-app rig is still missing. |
| Architecture and tests | 2 | 91 | 1.8 | Good policy/test structure, though AppDelegate still owns too much orchestration. |

Weighted total: **78.5/100**, rounded to **78/100**.

## Exact Research Items

| Research item | Score | Current evidence | What 100/100 requires |
| --- | ---: | --- | --- |
| Finishing a word | 84 | `CompletionRequestMode.wordCompletion` exists, `WordCompletionCandidateRanker` uses recent words first, and Tab accepts one word. | Require 3+ alphabetic chars, 90-140ms pause, no backspace in 250ms, and acceptance-kept tuning by app/field. |
| Finishing a phrase | 78 | Phrase continuation prompt says to return only next words and avoid rewriting/new topics. Cleaner removes low-signal and advice-like output. | Real phrase ranker with utility, style fit, context fit, user affinity, risk, repetition, and instability. |
| Continuing a sentence | 58 | Sentence handling is prompt guidance inside phrase mode. There is no distinct sentence lane. | Separate sentence mode, 280-450ms delay, higher utility threshold, and proof that it does not take over planning. |
| Rewriting | 86 | Ambient rewrite is effectively avoided, which matches the research. | Add explicit selected-text rewrite only if needed; never ambient. |
| Suggesting next action | 90 | Ambient next actions are not part of the app, and prompt-app guards block submit/run/Enter-like suggestions. | Keep next actions behind explicit invocation only, with tests preventing inline leakage. |
| Specificity with restraint | 76 | Prompt asks for boring connective tissue and cleaner suppresses filler. | Candidate scoring must reward one useful semantic commitment and penalize unsupported new facts/names. |
| Gate, not timer | 64 | There is an eligibility path, stale request gate, repetition suppressor, and focus checks. | Add expected utility, user affinity, mode-aware cooldowns, and replayable pure trigger state. |
| Within-word mode | 66 | Current word completion can request after 2 chars with 0ms delay. | 3+ letters, 90-140ms pause, no deletion in 250ms, casing/punctuation preservation. |
| Phrase mode | 61 | Boundary requests can run with 0ms app delay. | 140-240ms after word boundary, no fresh paragraph start, phrase-specific display threshold. |
| Sentence mode | 45 | No first-class mode. | New lane with 280-450ms delay and stricter accept-and-keep probability. |
| Line/paragraph start | 50 | Some activation and middle-of-line checks exist, but no explicit 2-content-word rule. | Suppress by default until 2 content words unless bullet/email mode strongly constrains continuation. |
| After deletion | 70 | Deletion skips requests. | Add 250ms stabilization cooldown and feed deletion into the annoyance/learning loop. |
| After accept | 82 | Tab accepts one word and leaves residual visible text. | Only one follow-on after accept unless recomputed and scored high; track accepted-and-kept. |
| After typed-over | 62 | Typed-over is recorded and repetition miss is learned. | Add 5s app+field+prefix-family cooldown and update annoyance/user-affinity score. |
| After Esc dismissal | 70 | Esc suppresses current field until blur for profiles that allow it. | Add 15s app+field+prefix-family cooldown and repeated-dismissal escalation. |
| App switch / caret move / selection change | 82 | Focus/app mismatch hides and selection is blocked. Mouse/caret moves are polling-based. | Immediate hide/cancel on focus, caret, mouse, and selection events where possible. |
| Punctuation handling | 66 | Natural boundaries exist for whitespace and punctuation. | Separate comma/colon/close-paren/sentence/newline/bullet thresholds. |
| Display score | 45 | No explicit live `displayScore = utility + styleFit + contextFit + userAffinity - risk - repetition - instability`. | Implement display score and log each component. |
| Accept-and-keep probability threshold | 48 | Analyzer supports accepted-and-kept; live checker wiring appears incomplete. | Gate display on dynamic accepted-and-kept probability by app, field, mode, and boundary. |
| Candidate generation | 35 | Runtime returns one cleaned suggestion; word completion picks one candidate. | Generate/rank 3-5 candidates or equivalent scored candidates, then show only stable top result. |
| Context budget | 76 | Prompt uses bounded recent context from current sentence/paragraph. | Use 48-96 tokens plus prior sentence/paragraph only when useful. |
| Metadata in prompt | 45 | App bundle is used mainly for dogfood prompt branches. | Include app, field type, document title, mode, partial word, style sketch, and up to 3 accepted-kept suffixes. |
| Hard `<NO_SUGGESTION>` path | 38 | Cleaner can return nil, but prompt does not consistently ask for `<NO_SUGGESTION>`. | Add explicit output shape: short suffix or `<NO_SUGGESTION>`, then parse it. |
| Privacy-first tracing | 88 | Raw content is redacted by default and raw/screenshot capture is opt-in with expiry. | Store prefix hashes and compact style features; make clear-learning-data controls part of the main loop. |
| Local runtime ownership | 92 | App-owned embedded runtime and no user-managed server dependency. | Keep this stance through beta and fail clearly if model assets are missing. |
| Warm/runtime cache | 75 | Model container is warm and reused. Each request builds a new `ChatSession`. | Add static prompt prefix cache and per-field session/KV cache. |
| Generated length | 78 | MVP is 5 visible words / 10 generated tokens; policy allows up to 7 words / 32 tokens. | Hard cap ambient suggestions to 2-8 words and 16 generated tokens, with shorter defaults by mode. |
| Stale cancellation | 86 | Request IDs, text snapshots, and keydown invalidation are strong. | Add app-level async race tests and cancellation proof in replay rig. |
| One visible suggestion | 95 | Single `SuggestionSession`, no dropdown or carousel. | Keep this invariant. |
| Single-line under 42 chars | 82 | Visible words are bounded; UI is a single panel. | Add explicit visible-character cap and tests. |
| Flicker control | 80 | Streaming presentation gate limits partial updates. | Add score-margin replacement rule and stale lifetime tests. |
| Tab next word | 91 | Implemented and app/profile gated. | Recompute residual after one follow-on instead of chaining unscored residuals. |
| Backtick full visible accept | 82 | Full accept exists when profile supports it; prompt apps disable full accept. | Prove atomic undo and no-submit for every app where full accept is enabled. |
| Esc dismiss | 88 | Implemented and traces keyboard action. | Add prefix-family cooldown and repeated-dismiss escalation. |
| Atomic undo | 45 | Insertion verification and retry exist; true host-app undo grouping is not proven. | Make accepted insertion undoable as one unit or prove native insertion already groups it per app. |
| Casual chat profile | 50 | Prompt-app safety exists, but no chat behavior profile. | 1-4 words, informal style, conservative questions/emotional text suppression. |
| Email profile | 35 | Mail is diagnostics-only. No email mode. | 2-6 words, polite but not flowery, no invented commitments/names/deadlines. |
| Notes profile | 68 | Notes app profile exists and notes proof is split by title/body/checklist. | 1-5 words, bullet/list aware, no blank paragraph suggestions, fresh surface proof. |
| Coding profile | 30 | No code mode; generic prompt warns dogfood apps only. | 1-5 tokens, syntax-aware, no invented APIs/imports/blocks, opt-in or conservative. |
| Docs/prose profile | 68 | Phrase prompt generally fits prose. | 3-6 words, rhythm/style matching, fresh paragraph suppression. |
| Bullets profile | 42 | Bullet proof is mostly a desired smoke target, not a mode. | Bullet mode with marker/indent preservation and strong post-marker trigger. |
| Forms profile | 72 | Field classifier can suppress forms; activation does not pass field kind in main call. | Live form classifier wiring plus non-sensitive free-form exceptions only. |
| Search profile | 70 | Classifier can suppress search; live wiring appears incomplete. | Search off by default, proven across browser/native search fields. |
| AI chat profile | 78 | Codex/Claude profiles are conservative and full accept is disabled. | Same-slice visual plus one-word no-submit proof for Codex, Claude Code, Claude desktop. |
| Accepted-and-kept learning | 52 | Classifier/checker/reporting exist; AppDelegate wiring appears absent. | Live 2s/10s/30s/blur/send survival events with thresholds feeding display policy. |
| Typed-over learning | 74 | Typed-over trace and repetition miss exist. | Prefix-family cooldown plus decay and threshold updates. |
| Ignored learning | 66 | Hidden/ignored events can record misses. | Separate weak negative, lifetime-aware, not just repetition miss. |
| Esc learning | 70 | Field suppression exists. | Very strong prefix/mode negative with 15s cooldown and longer repeated-dismiss decay. |
| Style memory | 45 | App-scoped recent word memory exists. | Durable local style sketch from accepted-and-kept suggestions with 14-day half-life. |
| Annoyance index | 62 | Annoyance model/analyzer exists; actor appears unused by live app. | Live quiet-mode decisions for field/app/global, visible in diagnostics and traces. |
| Replay-first test rig | 68 | Trace eval and smoke scripts exist. | One rig that replays recorded real app sessions with caret, screenshots, accepts, kept horizon, and latency. |
| Cross-app proof honesty | 90 | App proof matrix explicitly keeps failing rows non-A until evidence exists. | Close every pending proof row and make stale proof fail automatically. |

## Baseline Evidence Notes

Strong evidence in current code:

- `Sources/AutocompleteLabApp/App/AppDelegate.swift:11-16` sets the live app
  trigger policy to 0ms word/boundary delay and 15ms pause delay.
- `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift:59-77`
  skips deletion, delays large changes, and requests at natural boundaries.
- `Sources/AutocompleteLabCore/Engine/CompletionEngine.swift:3-6` has only
  `phraseContinuation` and `wordCompletion`.
- `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift:53-87`
  keeps phrase prompting short and blocks dogfood prompt-submit behavior.
- `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift:51-130`
  rejects prompt echoes, assistant meta, unsafe prompt actions, repeats,
  low-value phrases, and advice/tone drift.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:1346-1412` implements
  next-word accept, full accept, and Esc dismiss.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:1515-1646` verifies
  insertion and retries/fails closed.
- `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift:195-318`
  defines TextEdit, Notes, Obsidian, Mail, Chrome, Codex, and Claude Code
  profiles with support level, render mode, insertion mode, and prompt safety.
- `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift:3-19` defines
  suppressing search/form/secure/url field kinds.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:691-697` calls activation
  without passing `fieldKind`, which is the main field-safety wiring gap.
- `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift:4-67`
  implements accepted-and-kept checks, but search did not find live
  AppDelegate wiring.
- `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift:3-20` and
  `:156-228` define annoyance signals and quiet modes, but the actor appears
  unused by the live app path.
- `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift:3-23`
  and `Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift:18-29`
  redact raw text and sensitive metadata by default.
- `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:75-92`,
  `:118-135`, and `:297-350` make raw/screenshot capture opt-in and redacted
  unless enabled.
- `docs/product/app-proof-matrix.md:24-40` honestly marks target proof as
  still failing and lists pending surfaces.

## 100/100 Goal Criteria

This is the active goal definition I will use for follow-up implementation.
Every scored item above must reach 100/100. The app is not done until all of
these are true.

### P0 - Close The Live Trust Loops

- Wire `AcceptanceSurvivalChecker` into AppDelegate after every acceptance.
- Emit accepted-and-kept / edited / deleted / blur / send horizon events.
- Feed accepted-and-kept probability into display gating.
- Wire `AnnoyanceSuppressorActor` into typed-over, Esc, insertion failure,
  accepted-then-deleted, repeated rejection, pause, and app disable events.
- Quiet suggestions by app, field, and global scope when annoyance thresholds
  are crossed.
- Add tests proving the live loop records and uses these events.

### P0 - Replace Eager Timing With Mode-Aware Gates

- Add explicit boundary state: within-word, phrase, sentence, line-start,
  paragraph-start, after-delete, after-accept, typed-over cooldown, Esc cooldown.
- Within-word: 3+ letters, 90-140ms, no backspace in 250ms.
- Phrase: 140-240ms after stable word boundary.
- Sentence: 280-450ms after `.`, `!`, `?`, newline, or paragraph start.
- Line/paragraph start: suppress until 2 content words unless bullet/email mode.
- After delete: suppress until text stabilizes for 250ms.
- After accept: allow one follow-on only after recomputing and rescoring.
- Typed-over: 5s app+field+prefix-family cooldown.
- Esc: 15s app+field+prefix-family cooldown.
- App switch, caret move, mouse click, and selection change hide and cancel.

### P0 - Add Real Display Scoring

- Create a live display-score object with utility, styleFit, contextFit,
  userAffinity, risk, repetition, and instability.
- Gate display on accepted-and-kept probability, with mode-specific thresholds.
- Generate or derive multiple candidates where practical, but show only one.
- Require stable score margin before replacing visible ghost text.
- Log score components without raw text.

### P0 - Finish Prompt And Context Shape

- Add a hard `<NO_SUGGESTION>` output path.
- Build context from app, field type, boundary mode, partial word, compact style
  sketch, and up to 3 accepted-and-kept suffixes.
- Keep raw prompt text out of logs by default.
- Add code-safe, email, notes, bullets, docs/prose, forms/search, and AI-chat
  prompt profiles.

### P0 - Make Field Safety Actually Live

- Pass `AXFieldClassification` into activation and trace metadata.
- Suppress search, forms, secure, url, OTP, payment, token, and selected-text
  fields in the main app path.
- Add real-app or fixture tests for native search, browser search, form fields,
  password fields, URL bars, and selected text.

### P0 - Prove UX Control

- Keep one suggestion only.
- Enforce one-line and under-42-visible-character limits.
- Keep Tab as next-word acceptance.
- Keep full accept disabled for prompt apps until separate no-submit proof.
- Make accepted insertions undoable as one unit or prove native undo grouping
  per app.
- Add stale lifetime checks around 1.2-2.0 seconds.
- Add no-flicker tests using score margin and presentation cadence.

### P1 - Ship Behavior Profiles

- Casual chat: 1-4 words, informal, no emotional/question overreach.
- Email: 2-6 words, no invented commitments, deadlines, or names.
- Notes: 1-5 words, terse fragments, blank paragraph suppression.
- Coding: 1-5 tokens, no invented APIs/imports/blocks, conservative by default.
- Docs/prose: 3-6 words, rhythm match, fresh paragraph suppression.
- Bullets: 2-5 words, preserve indentation and marker style.
- Forms: usually off, with only safe free-form exceptions.
- Search: off by default.
- AI chat: tiny phrasing only, one-word no-submit proof required.

### P1 - Build Replay-First Proof

- One replay rig should read local traces and replay trigger policy, display
  scoring, stale cancellation, kept horizon, latency, and annoyance outcomes.
- It must support redacted traces by default.
- It must report P50/P95 by mode and app.
- It must make old proof stale after placement/key/runtime changes.

### P1 - Close Cross-App Proof

- TextEdit stays green with light/dark variants.
- Chrome text fields and local editor fixtures stay screenshot-backed.
- Replace local editor fixture confidence with real CodeMirror, Monaco, and
  ProseMirror proof.
- Obsidian gets disposable-vault screenshot plus same-slice accepts.
- Notes gets separate title, body, and checklist proof.
- Codex gets screenshot plus one-word accept plus no-submit in one strict slice.
- Claude Code gets safe live prompt proof.
- Claude desktop gets fresh screenshot-backed one-word no-submit proof.

### P2 - Runtime Polish

- Add static prompt prefix cache.
- Add per-field session/KV cache while the user remains in the same sentence or
  paragraph neighborhood.
- Hard cap ambient generation at 16 tokens.
- Measure prompt, session, first token, generation, cleanup, and render time
  separately by mode.
- Keep app-owned runtime; no user-managed Ollama or local HTTP server.

## First Implementation Queue

1. Wire live field classification into activation.
2. Wire accepted-and-kept tracking into the acceptance path.
3. Wire annoyance suppression into the suggestion decision path.
4. Replace 0-15ms app trigger delays with mode-aware researched delays.
5. Add typed-over and Esc prefix-family cooldowns.
6. Add `<NO_SUGGESTION>` prompt/cleaner path.
7. Add display-score object and trace score components.
8. Add behavior profile enum and start with notes, bullets, docs/prose, AI chat.
9. Add bullet/checklist unit evals.
10. Build the replay-first proof command.

## Goal Status

Active goal: grade the app, write this scorecard, then keep iterating until
every scored item reaches 100/100.

Baseline status: **78/100**.

Current implementation status: **84/100**. Not complete.
