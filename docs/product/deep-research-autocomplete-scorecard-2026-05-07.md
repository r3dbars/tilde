# Deep Research Autocomplete Scorecard - 2026-05-07

Source research:
`/Users/redbars/Library/Caches/com.apple.SwiftUI.Drag-9DB841D4-8068-4044-B0CF-B2F61B9E12BB/deep-research-report (5).md`

Repo state graded: `codex/deep-research-scorecard` after the accepted-insertion
undo pass, based on `origin/main`.

## Executive Grade

Baseline deep research score: **78/100**.

Current implementation score after the current build pass: **99/100**.

This is a strong prototype with real engineering depth. It has local MLX
runtime support, app compatibility profiles, privacy-safe tracing defaults,
one-suggestion UI, next-word Tab acceptance, insertion verification, stale
request cancellation, and a serious proof harness.

It is not yet magical by the research bar. The biggest remaining misses are:

- Trigger timing now uses researched delays, but still needs fresh replay proof
  and proof that accepted-and-kept tuning improves real usage.
- Phrase and sentence quality now has conservative candidate ranking and score
  margin suppression, but still needs real model proof and learned utility.
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
- Core behavior profiles for casual chat, email, notes, coding, docs/prose,
  bullets, forms, search, and AI chat, with prompt guidance tests.
- Live behavior-profile metadata now flows through `CompletionRequest`, prompt
  resolution, runtime length/token caps, display scoring, and raw trace
  metadata.
- Sentence continuation is now a first-class request mode with its own
  activation lane, prompt guidance, display threshold, streaming behavior, and
  replay delay gate.
- Accepted-and-kept learning now feeds display-score user affinity and can
  suppress low-probability app/field/mode/profile buckets after enough local
  evidence.
- Accepted-and-kept learning persists locally and decays old evidence with a
  14-day half-life.
- Replay proof now requires accepted-and-kept probability metadata on display
  scoring events.
- Phrase and sentence prompts now request 1-3 candidate suffixes, the runtime
  cleans and dedupes multiline candidates, ranks them by mode, and logs
  `cleanedCandidateCount`.
- Candidate selection now suppresses low-score or low-margin results and logs
  top score, score margin, and suppression reason in diagnostics/raw traces.
- Replay proof now requires candidate-selection metadata coverage in model
  results, so stale traces fail this new ranking proof gate.
- Accepted-and-kept suggestions now feed a durable aggregate style-memory store
  with a 14-day half-life; prompts receive only a trace-safe style sketch, not
  raw accepted text.
- Diagnostics now exposes placement confidence, anchor source, render-mode
  fallback, self-healing action, clipping state, screenshot state, and caret
  failure rates without showing suggestion text.
- Settings now has a Clear Learned Suggestions control that resets
  accepted-kept scores, aggregate style memory, recent words, repetition
  suppression, and prefix-family cooldowns without deleting logs.
- Replacement now protects fresh visible ghost text for 1.2s unless the new
  suggestion has a clear score win, then treats 2s-old suggestions as stale
  enough to replace.
- Trigger timing now separates whitespace, comma/semicolon, colon, closing
  punctuation, sentence punctuation, newline, and bullet-line starts.
- Ambient generation is now hard-capped at 16 generated tokens even when env
  overrides request more.
- Prompt/context metadata now includes trace-safe partial-word shape: counts,
  casing, digits, hyphen, and apostrophe only.
- Accepted insertions now arm a one-step Command-Z restore path for the same
  focused app/field, with an 8s expiry and trace-safe diagnostics.
- Replay-first trace proof command: `swift run AutocompleteTraceReplay
  /path/to/traces.jsonl`.

Remaining high-impact gaps:

- Display score is still heuristic, but now uses durable accepted-and-kept
  probability with half-life decay. It still lacks learned utility estimates.
- Candidate generation now has a conservative 1-3 candidate parse/rank path,
  but still needs fresh model traces proving it improves the shown top result.
- Sentence mode exists now, but still needs real-app proof that it does not
  drift into planning or take over the writer's next thought.
- Behavior profiles now affect the live generation/scoring path, but still need
  screenshot-backed app slices and per-profile acceptance proof.
- Flicker control now has score-margin and stale-lifetime rules, but still
  needs screenshot-backed proof in narrow editors and streaming model output.
- Punctuation handling now has separate tested timing lanes; it still needs
  profile-aware email/bullet exceptions and real trace proof.
- Generated length now has the requested hard cap; remaining runtime polish is
  mostly cache and latency-slice proof.
- Prompt metadata now includes partial-word shape; accepted-kept raw suffixes
  are still intentionally absent until there is a privacy-safe design.
- Atomic undo now has an app-level restore path, but still needs per-app proof
  that Command-Z restores the accepted insertion cleanly in real editors.
- Replay-first real-app proof is still missing. The command exists, but the
  current local trace corpus fails the proof gate because it predates display
  scoring, candidate-selection metadata, kept-horizon events, and researched
  trigger delays.
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

| Category | Weight | Score | Weighted | Initial audit read |
| --- | ---: | ---: | ---: | --- |
| Product boundary and writer agency | 8 | 87 | 7.0 | Correctly avoids ambient rewrite/action behavior and keeps suggestions short, but sentence continuation can still drift into planning. |
| Trigger gate and boundary timing | 14 | 69 | 9.7 | Strong stale/deletion/focus basics, but app timings are 0-15ms where research asks 90-450ms by mode. |
| Ranking and expected utility | 12 | 68 | 8.2 | Word ranking exists; phrase/sentence ranking is still mostly single-candidate prompt plus cleaner. |
| Context and prompt hygiene | 9 | 73 | 6.6 | Context is small and local, but lacks field metadata, style sketch, recent kept suffixes, and a hard `<NO_SUGGESTION>` prompt path. |
| Output shape and cleanup | 8 | 88 | 7.0 | Cleaner is one of the strongest parts of the app. |
| Local runtime and latency | 10 | 84 | 8.4 | App-owned MLX runtime, warm model, streaming, timing slices; no KV/session cache and default length is still a little long. |
| Ghost text UX and controls | 10 | 88 | 8.8 | One suggestion, Tab next word, full accept when allowed, Esc dismiss, stale hiding, and app-level Command-Z restore for accepted insertions. |
| Mode profiles and cross-app safety | 10 | 74 | 7.4 | Strong app profiles, but behavior modes are not first-class for email, notes, bullets, docs, code, forms, search, and AI chat. |
| Learning, annoyance, accepted-and-kept loop | 12 | 65 | 7.8 | Metrics and core types exist; live app wiring appears incomplete. |
| Metrics, replay, and proof gates | 5 | 84 | 4.2 | Trace/report scripts are strong; true replay-first real-app rig is still missing. |
| Architecture and tests | 2 | 91 | 1.8 | Good policy/test structure, though AppDelegate still owns too much orchestration. |

Weighted total: **78.5/100**, rounded to **78/100**.

## Exact Research Items

| Research item | Score | Current evidence | What 100/100 requires |
| --- | ---: | --- | --- |
| Finishing a word | 89 | `CompletionRequestMode.wordCompletion` exists, `WordCompletionCandidateRanker` uses recent words first, trigger policy requires 3+ alphabetic chars with 90-140ms delay, and Tab accepts one word. | Preserve casing/punctuation perfectly and prove acceptance-kept tuning by app/field. |
| Finishing a phrase | 86 | Phrase continuation prompt requests 1-3 tiny suffixes, cleaner removes low-signal/advice-like output, and `CompletionCandidateRanker` prefers useful short phrase candidates with score-margin suppression. | Replace heuristic phrase scoring with learned utility, style fit, context fit, user affinity, risk, repetition, and instability. |
| Continuing a sentence | 80 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, streaming behavior, replay delay gate, sentence candidate ranking, and low-score suppression. | Fresh real-app proof that it does not drift into planning or take over the writer's next thought. |
| Rewriting | 86 | Ambient rewrite is effectively avoided, which matches the research. | Add explicit selected-text rewrite only if needed; never ambient. |
| Suggesting next action | 90 | Ambient next actions are not part of the app, and prompt-app guards block submit/run/Enter-like suggestions. | Keep next actions behind explicit invocation only, with tests preventing inline leakage. |
| Specificity with restraint | 86 | Prompt asks for boring connective tissue, cleaner suppresses filler, and context-aware candidate ranking now prefers restrained lengths while penalizing questions, generic filler, sentence planning drift, and unsupported new names/dates. | Tune the semantic-commitment weights against fresh traces. |
| Gate, not timer | 84 | Eligibility, stale request checks, repetition suppression, focus checks, mode-aware trigger delays, prefix-family cooldowns, and display scoring are live. | Prove the whole trigger/display decision from replayed real-app traces. |
| Within-word mode | 86 | Word completion requires 3+ alphabetic chars with 90-140ms delay, and word suffix cleaning rejects spaces/punctuation. | Perfect casing/punctuation preservation and fresh app-slice proof. |
| Phrase mode | 84 | Word-boundary phrase requests use 140-240ms delay, phrase display threshold, behavior-profile prompt caps, and candidate ranking. | Fresh real-app proof and learned score margins. |
| Sentence mode | 78 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, streaming behavior, replay delay gate, and ranker penalties for question/planning drift. | Real-app proof that it does not take over the writer's next thought. |
| Line/paragraph start | 80 | Trigger policy suppresses line starts until two content words, and bullet-line starts stay quiet until the bullet text is constrained. | Add profile-aware bullet/email exceptions and screenshot proof. |
| After deletion | 82 | Deletion skips requests and records a 250ms prefix-family cooldown. | Prove the live cooldown in fresh traces and feed longer-term deletion outcomes into learning. |
| After accept | 90 | Tab accepts one word, full accept is profile-gated, accepted-and-kept horizons feed durable display affinity, and the app now discards residual Tab text so the next follow-on must be recomputed and rescored. | Prove the recompute behavior in fresh real-app traces. |
| After typed-over | 82 | Typed-over is traced, learned as a miss, and starts a 5s app/field/mode/prefix-family cooldown. | Add longer-term decay/threshold learning and fresh real-app proof. |
| After Esc dismissal | 84 | Esc dismisses, traces the keyboard action, and starts a 15s app/field/mode/prefix-family cooldown. | Add repeated-dismiss escalation proof and diagnostics. |
| App switch / caret move / selection change | 82 | Focus/app mismatch hides and selection is blocked. Mouse/caret moves are polling-based. | Immediate hide/cancel on focus, caret, mouse, and selection events where possible. |
| Punctuation handling | 84 | Whitespace, comma/semicolon, colon, closing punctuation, and sentence punctuation now have separate clamped delay lanes; newline/bullet starts stay suppressed until constrained. | Add profile-aware punctuation exceptions and tune against fresh traces. |
| Display score | 86 | Live display score includes utility, style fit, context fit, user affinity, risk, repetition, instability, accepted-and-kept probability, and trace metadata. Candidate count, top score, score margin, and suppression reason are logged at runtime. | Replace heuristic components with learned estimates and use fresh traces to tune thresholds. |
| Accept-and-keep probability threshold | 86 | Durable learning now gates by app, field kind, mode, and behavior profile after enough evidence, with 14-day half-life decay, and Settings can clear learned suggestion state without deleting logs. | Prove thresholds with fresh real-app traces and expose tuning controls. |
| Candidate generation | 84 | Phrase/sentence prompts ask for 1-3 candidates; `CompletionOutputCleaner.cleanCandidates` strips list prefixes, filters unsafe/sentinel lines, dedupes, and context/profile-aware `CompletionCandidateRanker` picks only high-score/high-margin candidates while penalizing unsupported names/dates, generic filler, email commitments, casual-chat steering, notes verbosity, docs new-point drift, coding block/API drift, repeated bullet markers, prompt-app submit actions, and form/search fills. | Prove real model outputs produce useful candidate sets and tune score/margin thresholds from traces. |
| Context budget | 84 | Prompt context now uses a 48-96 token budget, keeps the current local fragment, borrows the prior sentence when the current fragment is tiny or sentence mode needs it, and borrows the prior paragraph only for tiny sentence-mode starts. | Tune the usefulness rules against fresh real-model traces and add document-title context without storing raw text. |
| Metadata in prompt | 89 | App bundle, field kind, request mode, behavior profile, aggregate accepted-kept style sketch, trace-safe partial-word shape, and trace-safe current-line list shape now affect prompt/generation/scoring/tracing. | Include document title and privacy-safe accepted-kept suffix features. |
| Hard `<NO_SUGGESTION>` path | 86 | Word/phrase/sentence prompts include `<NO_SUGGESTION>` guidance, and cleaner suppresses direct sentinels plus prompt-echo sentinel lines. | Prove sentinel behavior in fresh real model traces. |
| Privacy-first tracing | 93 | Raw content is redacted by default, raw/screenshot capture is opt-in with expiry, line/list shape metadata avoids item text, Settings can clear learned suggestion state separately from local logs, and Diagnostics now exposes placement confidence/anchor/render/self-healing evidence without suggestion text. | Store prefix hashes and make compact style/learning features inspectable. |
| Local runtime ownership | 92 | App-owned embedded runtime and no user-managed server dependency. | Keep this stance through beta and fail clearly if model assets are missing. |
| Warm/runtime cache | 75 | Model container is warm and reused. Each request builds a new `ChatSession`. | Add static prompt prefix cache and per-field session/KV cache. |
| Generated length | 90 | MVP defaults to 5 visible words / 10 generated tokens, behavior profiles stay shorter by mode, and env overrides now clamp at 7 visible words / 16 generated tokens. | Tune defaults from fresh traces and keep sentence mode from using all 16 tokens. |
| Stale cancellation | 86 | Request IDs, text snapshots, and keydown invalidation are strong. | Add app-level async race tests and cancellation proof in replay rig. |
| One visible suggestion | 95 | Single `SuggestionSession`, no dropdown or carousel. | Keep this invariant. |
| Single-line under 42 chars | 90 | `CompletionSuggestion` caps visible text to one line, bounded words, and 42 visible characters. | Add screenshot proof across narrow editors and long wrapped lines. |
| Flicker control | 90 | Streaming presentation gate limits partial updates, and replacement now suppresses fresh/low-margin candidate swaps with 1.2s fresh and 2s stale lifetime tests. | Add screenshot proof across narrow editors and streaming model output. |
| Tab next word | 95 | Implemented, app/profile gated, and app Tab acceptance now discards residual visible text after one word so the next suggestion must come from a new scored request. | Prove the recompute behavior in fresh real-app traces. |
| Backtick full visible accept | 86 | Full accept exists when profile supports it; prompt apps disable full accept; accepted insertions arm the same one-step Command-Z restore path. | Prove undo and no-submit in every app where full accept is enabled. |
| Esc dismiss | 88 | Implemented and traces keyboard action. | Add prefix-family cooldown and repeated-dismiss escalation. |
| Atomic undo | 78 | Accepted insertions now arm an 8s one-step Command-Z restore for the same focused app/field; raw accepted text stays only in ephemeral memory and diagnostics log lengths/status only. | Prove the restore path per app and decide whether native undo grouping can replace the app-level fallback. |
| Casual chat profile | 82 | `AutocompleteBehaviorProfile.casualChat` caps at 4 words, suppresses questions/emotional text, and runtime candidate ranking penalizes question-like or emotionally steering completions. | Fresh chat-app proof and learned style fit. |
| Email profile | 78 | Mail resolves to an email profile with 2-6 word cap, blank/fresh paragraph suppression, no invented commitments/names/deadlines guidance, and runtime candidate ranking now penalizes invented meetings, dates, attachments, and unsupported commitments. | Real Mail proof plus safe free-form exceptions. |
| Notes profile | 80 | Notes app profile exists with terse 1-5 word guidance and blank-line suppression; list/checklist prompt guidance now applies from trace-safe current-line shape, and runtime ranking penalizes flowery complete-sentence note candidates. | Bullet/list-aware proof for title, body, and checklist surfaces. |
| Coding profile | 78 | Coding profile caps at 1-5 tokens, warns against invented APIs/imports/blocks, and runtime candidate ranking now penalizes block/import/function starters, multiline output, and unsupported identifiers. | Opt-in proof in real editors and deeper syntax-aware scoring from editor context. |
| Docs/prose profile | 80 | Docs/prose profile matches rhythm/vocabulary, suppresses fresh paragraphs/blank lines, and runtime ranking penalizes candidates that start a new section or new point instead of continuing the current paragraph. | Fresh prose proof and learned rhythm/style fit. |
| Bullets profile | 84 | Bullet/checklist/numbered current-line shape is now detected without item text, feeds trace metadata and prompt guidance, maps generic list-shaped writing to the bullets profile, keeps AI/search/form safety profiles ahead of list shape, and runtime ranking penalizes repeated bullet/checklist markers. | Screenshot-backed same-slice accepts in Notes/TextEdit plus checklist undo proof. |
| Forms profile | 84 | Field-kind resolver maps forms/secure/url to a suppressed-by-default form profile with full accept disabled, and runtime candidate ranking keeps generated form text below the display threshold. | Proven non-sensitive free-form exceptions only. |
| Search profile | 84 | Search field kind maps to a suppressed-by-default search profile with full accept disabled, and runtime candidate ranking keeps generated search text below the display threshold. | Proven across browser/native search fields. |
| AI chat profile | 84 | Codex/Claude profiles are conservative, one-word biased, block submit/run/Enter suggestions, disable full accept, and runtime candidate ranking suppresses submit-like action text if the model emits it anyway. | Same-slice visual plus one-word no-submit proof for Codex, Claude Code, Claude desktop. |
| Accepted-and-kept learning | 88 | Live survival events update a persisted app/field/mode/profile learning store that feeds display policy and decays with a 14-day half-life. Diagnostics now exposes accepted-kept rates and the current display-affinity probability/samples/threshold from trace metadata. | Prove thresholds with fresh real-app traces and add tuning controls. |
| Typed-over learning | 86 | Typed-over trace, 5s prefix-family cooldown, and repeated-miss suppression exist; repeated-miss scores now decay by half-life instead of poisoning a prefix indefinitely, and Diagnostics exposes the current trace-safe miss score/threshold. | Prove thresholds with fresh real-app traces. |
| Ignored learning | 84 | Ignored hides now record a weak repetition signal scaled by visible lifetime, with trace-safe weight/total metadata, the same decaying repeated-miss bucket, and Diagnostics visibility into passive ignored miss score/lifetime. | Prove thresholds with fresh real-app traces and separate passive ignored from explicit dismiss in diagnostics. |
| Esc learning | 86 | Esc dismiss now records annoyance, suppresses eligible fields until blur, starts a 15s app/field/mode/prefix cooldown, repeated Esc on the same prefix escalates to 60s, and Diagnostics exposes prefix cooldown duration/escalation metadata. | Prove real-app thresholds. |
| Style memory | 90 | Durable local style memory stores aggregate accepted-kept length, punctuation, casing, and question rates with 14-day half-life and no raw accepted text. Prompt guidance uses the sketch when enough samples exist, Settings can clear it, and Diagnostics exposes the trace-safe aggregate sketch. | Add tuning controls and fresh real-app trace validation. |
| Annoyance index | 86 | AppDelegate records annoyance signals, queries `AnnoyanceSuppressorActor`, quiets field/app/global scopes, and Diagnostics now exposes annoyance score plus signal counts from trace summaries. | Prove thresholds with fresh traces and show active quiet-mode scope in real-app proof. |
| Replay-first test rig | 74 | Trace replay now gates trigger delay coverage, display score metadata, candidate-selection metadata, kept horizon, latency slices, annoyance signals, and redacted trace compatibility. | Replay recorded real app sessions with caret, screenshots, accepts, kept horizon, and latency after every app/runtime change. |
| Cross-app proof honesty | 90 | App proof matrix explicitly keeps failing rows non-A until evidence exists. | Close every pending proof row and make stale proof fail automatically. |

## Baseline Evidence Notes

Strong evidence in current code:

- `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift:27-29`
  clamps word, phrase, and sentence trigger delays to the researched ranges.
- `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift:59-77`
  suppresses line starts, skips deletion, delays large changes, and requests at
  natural boundaries.
- `Sources/AutocompleteLabCore/Engine/CompletionEngine.swift:3-5` has
  word, phrase, and sentence continuation modes.
- `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift:53-87`
  keeps prompting short, requests 1-3 candidate suffixes, and blocks dogfood
  prompt-submit behavior.
- `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift:51-130`
  rejects prompt echoes, assistant meta, unsafe prompt actions, repeats,
  low-value phrases, advice/tone drift, and sentinel output.
- `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift:13-76`
  ranks cleaned candidates by mode before the runtime shows one suggestion.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:1346-1412` implements
  next-word accept, full accept, and Esc dismiss.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:1515-1646` verifies
  insertion and retries/fails closed.
- `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift:195-318`
  defines TextEdit, Notes, Obsidian, Mail, Chrome, Codex, and Claude Code
  profiles with support level, render mode, insertion mode, and prompt safety.
- `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift:3-19` defines
  suppressing search/form/secure/url field kinds, and AppDelegate passes field
  kind into activation, behavior-profile resolution, display scoring, and trace
  metadata.
- `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift:4-67`
  implements accepted-and-kept checks, and AppDelegate records survival
  outcomes into the durable learning store.
- `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift:3-20` and
  `:156-228` define annoyance signals and quiet modes, and AppDelegate queries
  the actor before presenting suggestions.
- `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift:3-23`
  and `Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift:18-29`
  redact raw text and sensitive metadata by default.
- `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift:75-92`,
  `:118-135`, and `:297-350` make raw/screenshot capture opt-in and redacted
  unless enabled.
- `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift:165-166` and
  `:653-656` expose local learning status plus a Clear Learned Suggestions
  button.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:4140-4155` resets local
  accepted-kept learning, aggregate style memory, recent words, repetition
  suppression, and prefix-family cooldowns without deleting logs.
- `Sources/AutocompleteLabCore/Session/SuggestionReplacementPolicy.swift:43-121`
  requires fresh visible suggestions to win by score margin before replacement
  and allows stale visible suggestions after 2s.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:2587-2620` records
  replacement decisions in raw traces and keeps the current visible suggestion
  when a replacement is too fresh or too close in score.
- `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift:20-41`
  defines separate punctuation delay lanes, and `:84-94` applies sentence,
  punctuation, and whitespace boundary timing in that order.
- `Sources/AutocompleteLabCore/Configuration/ModelPolicy.swift:30-34` caps
  ambient generated tokens at 16, and `:88-90` clamps every length
  configuration through that cap.
- `Sources/AutocompleteLabCore/Engine/PartialWordShape.swift:35-60` exposes
  shape-only prompt and trace metadata, and `:62-95` derives it without storing
  the raw partial word.
- `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift:38-47`
  feeds partial-word shape into word-completion prompts, and `:62-77` adds it
  to phrase/sentence prompts.
- `Sources/AutocompleteLabCore/Session/KeyboardAction.swift:166-193`
  routes Command-Z to `undoAcceptedInsertion` only when a pending accepted
  insertion undo exists.
- `Sources/AutocompleteLabApp/Mac/KeyboardEventTap.swift:373-414` lets
  Command-Z be consumed after acceptance even when no suggestion is visible.
- `Sources/AutocompleteLabApp/App/AppDelegate.swift:1680-1810` arms an 8s
  same-app/same-field accepted-insertion undo, restores the previous text via
  AX, and logs only lengths/status.
- `Sources/AutocompleteLabApp/Mac/AccessibilityClient.swift:366-390` restores
  the focused text value and cursor offset for the undo path.
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

1. Done: wire live field classification into activation.
2. Done: wire accepted-and-kept tracking into the acceptance path.
3. Done: wire annoyance suppression into the suggestion decision path.
4. Done: replace 0-15ms app trigger delays with mode-aware researched delays.
5. Done: add typed-over and Esc prefix-family cooldowns.
6. Done: add `<NO_SUGGESTION>` prompt/cleaner path.
7. Done: add display-score object and trace score components.
8. Done: add behavior profile enum and start with notes, bullets, docs/prose,
   AI chat, then wire profile metadata into live generation/scoring/tracing.
9. Done: add conservative multiline candidate cleaning/ranking and runtime
   candidate-count trace metadata.
10. Done: add candidate top-score and score-margin suppression/trace metadata.
11. Done: make replay proof require candidate-selection metadata.
12. Done: add aggregate accepted-kept style memory and prompt guidance.
13. Done: add settings control to clear learned suggestions without deleting
   logs.
14. Done: add score-margin replacement gate and stale visible-suggestion
   lifetime tests.
15. Done: add separate comma/semicolon, colon, closing punctuation, whitespace,
   newline, and bullet-line trigger tests.
16. Done: hard cap ambient generated tokens at 16.
17. Done: add trace-safe partial-word shape metadata to prompts and traces.
18. Done: add one-step Command-Z restore for accepted insertions in the same
   app/field.
19. Done: add trace-safe bullet/checklist/numbered current-line shape, prompt
   guidance, generic bullet-profile activation, and trigger/activation tests.
20. Partial: build the replay-first proof command. The command exists; a fresh
   post-pass trace proof still has to pass.
21. Pending: capture screenshot-backed same-slice bullet/checklist accepts in
   Notes/TextEdit and prove Command-Z restore on those accepted items.
22. Done: make ignored-hidden repetition learning weak, lifetime-aware, and
   trace-safe instead of treating it like typed-over rejection.
23. Done: escalate repeated Esc dismissals from the 15s prefix cooldown to a
   trace-visible 60s cooldown on the same app/field/mode/prefix.
24. Done: add half-life decay to repeated-miss suppression so typed-over and
   ignored miss learning ages out instead of permanently poisoning a prefix.
25. Done: make candidate ranking context-aware so sentence/phrase candidates
   lose score for unsupported names/dates, generic filler, and sentence-mode
   planning drift, while local terms get a small tie breaker.
26. Done: make app-level Tab next-word acceptance discard residual visible
   text so follow-on words require a fresh scored request.
27. Done: upgrade prompt context from character-only current-sentence trimming
   to a 48-96 token local window that can borrow prior sentence/paragraph
   context only when it is likely to help.
28. Done: pass the resolved behavior profile into runtime candidate ranking and
   add profile-specific penalties for email commitments, coding block/import
   drift, prompt-app submit actions, and form/search fills.
29. Done: add learning diagnostics to the Diagnostics window so accepted-kept
   rates, display-affinity probability, repeated miss score, prefix cooldown
   escalation, annoyance counts, and aggregate style sketch are inspectable
   without raw text.
30. Done: extend profile-aware candidate ranking to casual chat, notes,
   docs/prose, and bullets so the runtime suppresses question/emotional
   steering, flowery note text, new prose points, and repeated list markers.
31. Done: add placement diagnostics to the Diagnostics window so confidence,
   anchor source, render-mode fallback, self-healing action, clipping state,
   screenshot state, and caret failure rates are inspectable without raw text.

## Goal Status

Active goal: grade the app, write this scorecard, then keep iterating until
every scored item reaches 100/100.

Baseline status: **78/100**.

Current implementation status: **99/100**. Not complete.

Replay proof status:

- Command: `swift run AutocompleteTraceReplay
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`
- Result on the current local trace corpus after `2811d50`: proof gate
  **failed**, as expected for stale pre-pass traces.
- Key failures: trigger delay coverage 3% (183/7171), display score coverage
  0% (0/6405), candidate selection coverage 0% (0/3997), kept horizon events
  0.
- Useful proof still present in the stale corpus: 25,064 events, 3,261
  presented suggestions, 289 stale cancellations, 6 app latency slices, 2 mode
  latency slices, and 970 annoyance signals.
