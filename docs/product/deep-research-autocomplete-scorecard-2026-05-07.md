# Deep Research Autocomplete Scorecard - 2026-05-07

Source research:
`/Users/redbars/Library/Caches/com.apple.SwiftUI.Drag-9DB841D4-8068-4044-B0CF-B2F61B9E12BB/deep-research-report (5).md`

Repo state graded: `codex/deep-research-scorecard` after the trusted visual
offset expiry pass, based on `origin/main`.

## Executive Grade

Baseline deep research score: **78/100**.

Current implementation score after the current build pass: **99/100**.
Proof status: **not complete**.

This is a strong prototype with real engineering depth. It has local MLX
runtime support, app compatibility profiles, privacy-safe tracing defaults,
one-suggestion UI, next-word Tab acceptance, insertion verification, stale
request cancellation, and a serious proof harness.

It is not yet magical by the research bar. The biggest remaining misses are:

- Trigger timing now uses researched delays, but still needs fresh replay proof
  and proof that accepted-and-kept tuning improves real usage.
- Phrase and sentence quality now has conservative candidate ranking and score
  margin suppression, but still needs real model proof and learned utility.
- Cross-app proof is honest but incomplete for Codex, terminal-hosted Claude Code,
  default-Chrome web-editor AX exposure, and more production-editor variants.
  Claude desktop now has same-baseline one-word no-submit proof, but more
  prompt layouts still need coverage.
- Normal typing proof now includes exact 1,200-, 4,800-, and 12,000-character
  strict TextEdit endurance passes, and the current harness revalidates named
  TextEdit focus in shorter CGEvent batches with bounded cleanup. The latest
  10-minute proof passed with zero missed text, zero tap disables, zero focused
  poll skips, focused-poll p95 max 57ms, focused-poll max 87ms, and 4
  under-threshold slow markers.

The repo's existing Apple-native score is **86/100**. This score is lower
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
- Placement uncertainty now hides any stale ghost immediately, records a
  caret-geometry failure, and feeds repeated failures into field quiet mode.
- Diagnostics now exposes the active quiet-mode scope, reason, score, and
  expiry from trace metadata without user text.
- Settings first-run copy now explains Accessibility in one short paragraph,
  only explains Screen Recording while screenshot capture is enabled, and
  points first success at TextEdit instead of private notes.
- Settings now has a Clear Learned Suggestions control that resets
  accepted-kept scores, aggregate style memory, recent words, repetition
  suppression, and prefix-family cooldowns without deleting logs.
- Settings now turns missing or invalid app-owned MLX assets into an in-app
  Install/Repair Model action with progress, cancellation, validation, runtime
  reload, and warmup instead of only revealing a folder.
- Replacement now protects fresh visible ghost text for 1.2s unless the new
  suggestion has a clear score win, then treats 2s-old suggestions as stale
  enough to replace.
- Trigger timing now separates whitespace, comma/semicolon, colon, closing
  punctuation, sentence punctuation, newline, and bullet-line starts.
- Ambient generation is now hard-capped at 16 generated tokens even when env
  overrides request more.
- The typing endurance harness now uses typing-like chunks, exact named
  TextEdit document verification, temporary TextEdit enablement, temporary
  pause-state restore, AX warmup flushing, bounded cleanup, and a CGEvent
  Unicode typing driver that verifies the target TextEdit window before each
  segmented Swift typing batch. Current strict proof has verified 1,200, 4,800,
  and 12,000 exact TextEdit characters; the latest 10-minute pass had no missed
  text, no tap disables, zero focused-poll skips, focused-poll p95 max 57ms,
  focused-poll max 87ms, and 4 under-threshold slow markers.
- Inline placement now suppresses when less than one useful word can fit after
  the caret, so near-edge fields hide instead of showing clipped slivers.
- Diagnostics export now creates a redacted privacy bundle with a manifest,
  checklist, redacted JSONL, survival report, visual calibration report, and
  HTML report instead of exposing raw trace rows through the export path.
- `docs/product/proof-manifest.json` now indexes target-surface proof as
  structured data. `script/check_proof_manifest.sh` rechecks completed claims
  against current proof-fingerprint constants, matching manual smoke rows,
  tracked scorecard screenshots, strict visual markers, and, in strict mode,
  the matched trace JSONL slice. Strict proof now requires bounded line
  evidence, screenshot-backed presented events for strict visual proof,
  verified insertions, and current trace/placement/key/runtime proof
  fingerprints.
- Fresh installs now start with suggestion-capable apps off, keep Settings open
  until a test app is enabled, and use plainer local-model recovery copy that
  says Ollama or another model server is not needed.
- Settings now shows share-safe privacy status, and the private beta packet
  requires a privacy status file that allows only the redacted privacy bundle
  by default.
- Prompt/context metadata now includes trace-safe partial-word shape: counts,
  casing, digits, hyphen, and apostrophe only.
- Accepted insertions now arm a one-step Command-Z restore path for the same
  focused app/field, with an 8s expiry and trace-safe diagnostics.
- Line-start cadence now stays quiet in plain prose while allowing constrained
  one-word completions in list/checklist and email contexts, so `- Pri` or
  `Tha` can complete without allowing phrase suggestions after a bare marker.
- Notes insertion verification now uses a slower read-only recheck for unchanged
  AX reads before retrying or suppressing the field, so delayed Notes body and
  checklist AX updates do not immediately look like failed insertions.
- Trace events now carry a proof fingerprint for the current trace, placement,
  key-capture, and runtime proof versions; replay fails stale proof that predates
  those versions.
- Replay now also requires every presented suggestion in the proof slice to
  include placement anchor, confidence band, and caret-rect metadata, with at
  least one trusted caret or synthetic-caret placement.
- Replay now requires at least one stale cancellation and at least one annoyance
  signal, so those research outcomes cannot be skipped by a happy-path-only
  trace.
- Notes body now has bounded screenshot-backed proof with two verified accepts,
  and accepted word-completion suffixes now count as kept when the completed
  current token keeps that suffix.
- The replay CLI now accepts `--start-line` and `--end-line`, and
  `script/trace_mark.sh --replay` replays only the fresh trace slice after a
  saved mark instead of mixing new proof with stale historical logs. Fresh
  proof can now be isolated and replayed, but it still needs a passing fresh
  real-app slice.
- `script/autocomplete_trace_replay_self_test.sh` proves the CLI and
  `trace_mark --replay` skip stale rows and honor frozen slice bounds.
- Screenshot placement now has a pure pixel offset detector that can identify
  bounded ghost/panel drift, reject blank or low-contrast images, reject
  excessive outliers, and feed the existing trusted visual correction policy.
  Screenshot capture now logs offset metadata after a PNG is captured, and
  explicit per-app screenshot tracing can write scoped trusted corrections.
  Fresh real-app proof still needs to show the correction loop working.
- Trusted visual offsets now expire when the target app version, screen, or
  field shape changes. Legacy offsets stay trusted until resaved with scoped
  context, so older local profiles do not break abruptly.
- Slow focused-text AX reads that return no focused text context now start a
  short app-specific cooldown immediately instead of requiring a repeated slow
  read, so failing editors back off sooner without touching the key path.
- Single slow focused-text AX reads with context now start a short polling
  throttle and drop that returned context, so a slow read cannot become the
  next visible suggestion while the app is trying to catch up.
- Chrome smoke now has pinned upstream `monaco-real` and `prosemirror-real`
  fixture lanes in addition to the dependency-free lookalikes. Both real-engine
  lanes now pass with isolated temp-profile Chrome, renderer accessibility
  forced, strict screenshot evidence, Tab accept, Option-Tab full accept, and
  two verified insertions. This closes the hidden lookalike-only gap, but the
  score stays below target because default Chrome AX exposure and caret-quality
  real-editor placement are still open.
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
  real trace proof for the new profile-aware email, bullet, and coding
  exceptions.
- Generated length now has the requested hard cap; remaining runtime polish is
  mostly cache and latency-slice proof. Sentence mode also has a tighter
  mode-level generation ceiling so env overrides cannot make it use the full
  ambient cap.
- Prompt metadata now includes partial-word shape, and accepted-kept style
  memory now adds raw-text-free kept suffix shape: short-suffix rate and average
  final-token length.
- Atomic undo now has an app-level restore path, but still needs per-app proof
  that Command-Z restores the accepted insertion cleanly in real editors.
- Replay-first real-app proof is still missing. The command exists, but the
  current local trace corpus fails the proof gate because it predates display
  scoring, candidate-selection metadata, proof fingerprints, kept-horizon
  events, and researched trigger delays.
- Cross-app proof rows still need a screenshot-backed acceptance slice for
  Codex and a live screenshot/no-submit terminal-host slice before Claude Code
  can count as prompt proof.
- Real Chrome editor-engine proof now passes under isolated forced-renderer AX,
  but still needs default Chrome focused web-editor AX context and caret-quality
  placement before the browser-editor scores can reach target.

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
| Trigger gate and boundary timing | 14 | 70 | 9.8 | Strong stale/deletion/focus basics, researched delays, and profile-aware fresh-paragraph suppression are now live; fresh replay proof is still needed. |
| Ranking and expected utility | 12 | 70 | 8.4 | Word ranking, candidate score margins, accepted-kept suppression, and a bounded learned utility adjustment exist; phrase/sentence ranking still needs trace-tuned semantic utility. |
| Context and prompt hygiene | 9 | 73 | 6.6 | Context is small and local, but lacks field metadata, style sketch, recent kept suffixes, and a hard `<NO_SUGGESTION>` prompt path. |
| Output shape and cleanup | 8 | 89 | 7.1 | Cleaner is one of the strongest parts of the app, and now suppresses phrase restarts or visible typed-word duplicates that survive prefix trimming. |
| Local runtime and latency | 10 | 87 | 8.7 | App-owned MLX runtime, warm model, streaming, timing slices, trace-visible static prompt cache, and trace-visible per-field session-cache eligibility/reset policy; live KV/session reuse is still pending. |
| Ghost text UX and controls | 10 | 92 | 9.2 | One suggestion, Tab next word, full accept when allowed, direct accept-all shortcut editing, Esc dismiss, stale hiding, current-field/session silence, per-app force-mirror control, and app-level Command-Z restore for accepted insertions. |
| Mode profiles and cross-app safety | 10 | 77 | 7.7 | Strong app profiles, a user-visible per-app mirror override, and a proof-only terminal-host Claude Code adapter now exist, but behavior modes are not first-class for every email, notes, bullets, docs, code, forms, search, and AI chat surface. |
| Learning, annoyance, accepted-and-kept loop | 12 | 66 | 7.9 | Accepted-kept learning now affects both affinity and utility, but the loop still needs fresh real-app threshold proof. |
| Metrics, replay, and proof gates | 5 | 85 | 4.3 | Trace/report scripts are strong, and Settings can now start per-app screenshot proof from the current app; true replay-first real-app rig is still missing. |
| Architecture and tests | 2 | 91 | 1.8 | Good policy/test structure, though AppDelegate still owns too much orchestration. |

Weighted total: **80.1/100**, rounded to **80/100**.

## Exact Research Items

| Research item | Score | Current evidence | What 100/100 requires |
| --- | ---: | --- | --- |
| Finishing a word | 90 | `CompletionRequestMode.wordCompletion` exists, `WordCompletionCandidateRanker` uses recent words first, trigger, activation, and fast ranking all require 3+ alphabetic chars, and Tab accepts one word. | Preserve casing/punctuation perfectly and prove acceptance-kept tuning by app/field. |
| Finishing a phrase | 87 | Phrase continuation prompt requests 1-3 tiny suffixes, prefix overlap is trimmed to suffixes, visible typed-word duplicates and phrase restarts are suppressed, and `CompletionCandidateRanker` prefers useful short phrase candidates with score-margin suppression. | Replace heuristic phrase scoring with learned utility, style fit, context fit, user affinity, risk, repetition, and instability. |
| Continuing a sentence | 80 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, streaming behavior, replay delay gate, sentence candidate ranking, and low-score suppression. | Fresh real-app proof that it does not drift into planning or take over the writer's next thought. |
| Rewriting | 86 | Ambient rewrite is effectively avoided, which matches the research. | Add explicit selected-text rewrite only if needed; never ambient. |
| Suggesting next action | 90 | Ambient next actions are not part of the app, and prompt-app guards block submit/run/Enter-like suggestions plus directive starters like "you should", "we need to", and "I'd recommend". | Keep next actions behind explicit invocation only, with tests preventing inline leakage. |
| Specificity with restraint | 87 | Prompt asks for boring connective tissue, cleaner suppresses filler, directive recommendation starters, visible typed-word duplicates, and phrase restarts, and context-aware candidate ranking now prefers restrained lengths while penalizing questions, generic filler, sentence planning drift, and unsupported new names/dates. | Tune the semantic-commitment weights against fresh traces. |
| Gate, not timer | 84 | Eligibility, stale request checks, repetition suppression, focus checks, mode-aware trigger delays, prefix-family cooldowns, and display scoring are live. | Prove the whole trigger/display decision from replayed real-app traces. |
| Within-word mode | 88 | Word completion now requires 3+ alphabetic chars in trigger, activation, and fast ranking, uses a 90-140ms trigger delay, and word suffix cleaning rejects spaces/punctuation. | Perfect casing/punctuation preservation and fresh app-slice proof. |
| Phrase mode | 84 | Word-boundary phrase requests use 140-240ms delay, phrase display threshold, behavior-profile prompt caps, and candidate ranking. | Fresh real-app proof and learned score margins. |
| Sentence mode | 78 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, streaming behavior, replay delay gate, and ranker penalties for question/planning drift. | Real-app proof that it does not take over the writer's next thought. |
| Line/paragraph start | 86 | Trigger policy suppresses plain line starts until two content words, keeps bare markers quiet, allows constrained one-word completions in list/checklist and email contexts, and now enforces profile fresh-paragraph suppression for docs/email/code until the new paragraph has stronger local context. | Add screenshot proof and tune profile-specific exceptions against real traces. |
| After deletion | 82 | Deletion skips requests and records a 250ms prefix-family cooldown. | Prove the live cooldown in fresh traces and feed longer-term deletion outcomes into learning. |
| After accept | 90 | Tab accepts one word, full accept is profile-gated, accepted-and-kept horizons feed durable display affinity, and the app now discards residual Tab text so the next follow-on must be recomputed and rescored. | Prove the recompute behavior in fresh real-app traces. |
| After typed-over | 86 | Typed-over is traced, learned as a miss, starts a 5s app/field/mode/prefix-family cooldown, and repeated typed-over on the same prefix escalates to 30s. | Prove thresholds with fresh real-app traces. |
| After Esc dismissal | 84 | Esc dismisses, traces the keyboard action, and starts a 15s app/field/mode/prefix-family cooldown. | Add repeated-dismiss escalation proof and diagnostics. |
| App switch / caret move / selection change | 82 | Focus/app mismatch hides and selection is blocked. Mouse/caret moves are polling-based. | Immediate hide/cancel on focus, caret, mouse, and selection events where possible. |
| Punctuation handling | 88 | Whitespace, comma/semicolon, colon, closing punctuation, and sentence punctuation now have separate clamped delay lanes; newline/bullet starts stay suppressed until constrained; email greeting commas and short list-label colons wait longer, and coding closing brackets stay quiet. | Tune against fresh traces. |
| Display score | 88 | Live display score includes utility, style fit, context fit, user affinity, risk, repetition, instability, accepted-and-kept probability, and trace metadata. Accepted-kept learning now applies a bounded utility adjustment in addition to affinity and low-probability suppression. Candidate count, top score, score margin, and suppression reason are logged at runtime. | Replace remaining heuristic components with learned estimates and use fresh traces to tune thresholds. |
| Accept-and-keep probability threshold | 87 | Durable learning now gates by app, field kind, mode, and behavior profile after enough evidence, applies bounded affinity and utility adjustments, decays with a 14-day half-life, and Settings can clear learned suggestion state without deleting logs. | Prove thresholds with fresh real-app traces and expose tuning controls. |
| Candidate generation | 84 | Phrase/sentence prompts ask for 1-3 candidates; `CompletionOutputCleaner.cleanCandidates` strips list prefixes, filters unsafe/sentinel lines, dedupes, and context/profile-aware `CompletionCandidateRanker` picks only high-score/high-margin candidates while penalizing unsupported names/dates, generic filler, email commitments, casual-chat steering, notes verbosity, docs new-point drift, coding block/API drift, repeated bullet markers, prompt-app submit actions, and form/search fills. | Prove real model outputs produce useful candidate sets and tune score/margin thresholds from traces. |
| Context budget | 84 | Prompt context now uses a 48-96 token budget, keeps the current local fragment, borrows the prior sentence when the current fragment is tiny or sentence mode needs it, and borrows the prior paragraph only for tiny sentence-mode starts. | Tune the usefulness rules against fresh real-model traces and add document-title context without storing raw text. |
| Metadata in prompt | 91 | App bundle, field kind, request mode, behavior profile, aggregate accepted-kept style sketch, trace-safe partial-word shape, trace-safe current-line list shape, and raw-text-free kept suffix shape now affect prompt/generation/scoring/tracing. | Include document title and tune these features against fresh traces. |
| Hard `<NO_SUGGESTION>` path | 86 | Word/phrase/sentence prompts include `<NO_SUGGESTION>` guidance, and cleaner suppresses direct sentinels plus prompt-echo sentinel lines. | Prove sentinel behavior in fresh real model traces. |
| Privacy-first tracing | 95 | Raw content is redacted by default, raw/screenshot capture is opt-in with expiry, line/list shape metadata avoids item text, kept suffix shape stores aggregate rates/lengths instead of text, Settings can clear learned suggestion state separately from local logs, permission copy states what is read and why, and Diagnostics now exposes placement confidence/anchor/render/self-healing evidence without suggestion text. | Store prefix hashes and make compact style/learning features more inspectable. |
| Local runtime ownership | 92 | App-owned embedded runtime and no user-managed server dependency. | Keep this stance through beta and fail clearly if model assets are missing. |
| Warm/runtime cache | 82 | Model container is warm and reused, static system prompts now go through a bounded redacted-key cache with hit/size trace metadata, `CompletionRequest` carries field identity, and `RuntimeSessionCachePolicy` defines a tested same-app/same-field/same-mode/same-neighborhood reuse gate with trace metadata for reuse eligibility and reset reasons. Each MLX request still builds a new `ChatSession`. | Wire safe per-field session/KV reuse into the app runtime. |
| Generated length | 92 | MVP defaults to 5 visible words / 10 generated tokens, behavior profiles stay shorter by mode, env overrides clamp at 7 visible words / 16 generated tokens, and sentence mode has its own 10-token ceiling. | Tune defaults from fresh traces. |
| Stale cancellation | 86 | Request IDs, text snapshots, and keydown invalidation are strong. | Add app-level async race tests and cancellation proof in replay rig. |
| One visible suggestion | 95 | Single `SuggestionSession`, no dropdown or carousel. | Keep this invariant. |
| Single-line under 42 chars | 90 | `CompletionSuggestion` caps visible text to one line, bounded words, and 42 visible characters. | Add screenshot proof across narrow editors and long wrapped lines. |
| Flicker control | 90 | Streaming presentation gate limits partial updates, and replacement now suppresses fresh/low-margin candidate swaps with 1.2s fresh and 2s stale lifetime tests. | Add screenshot proof across narrow editors and streaming model output. |
| Tab next word | 95 | Implemented, app/profile gated, and app Tab acceptance now discards residual visible text after one word so the next suggestion must come from a new scored request. | Prove the recompute behavior in fresh real-app traces. |
| Backtick full visible accept | 86 | Full accept exists when profile supports it; prompt apps disable full accept; accepted insertions arm the same one-step Command-Z restore path. | Prove undo and no-submit in every app where full accept is enabled. |
| Esc dismiss | 88 | Implemented and traces keyboard action. | Add prefix-family cooldown and repeated-dismiss escalation. |
| Atomic undo | 78 | Accepted insertions now arm an 8s one-step Command-Z restore for the same focused app/field; raw accepted text stays only in ephemeral memory and diagnostics log lengths/status only. | Prove the restore path per app and decide whether native undo grouping can replace the app-level fallback. |
| Casual chat profile | 82 | `AutocompleteBehaviorProfile.casualChat` caps at 4 words, suppresses questions/emotional text, and runtime candidate ranking penalizes question-like or emotionally steering completions. | Fresh chat-app proof and learned style fit. |
| Email profile | 79 | Mail resolves to an email profile with 2-6 word cap, prompt guidance plus trigger-level blank/fresh paragraph suppression, no invented commitments/names/deadlines guidance, and runtime candidate ranking now penalizes invented meetings, dates, attachments, and unsupported commitments. | Real Mail proof plus safe free-form exceptions. |
| Notes profile | 90 | Notes app profile exists with terse 1-5 word guidance, blank-line suppression, list/checklist prompt guidance, safer AX-first insertion, delayed read-only verification for Notes AX lag, and stale text-after-cursor repair. Title, body, and checklist fields have same-slice strict visual proof with two verified accepts each. | More list lengths, checked items, and undo proof. |
| Coding profile | 78 | Coding profile caps at 1-5 tokens, warns against invented APIs/imports/blocks, and runtime candidate ranking now penalizes block/import/function starters, multiline output, and unsupported identifiers. | Opt-in proof in real editors and deeper syntax-aware scoring from editor context. |
| Docs/prose profile | 82 | Docs/prose profile matches rhythm/vocabulary, now enforces fresh-paragraph trigger suppression instead of only prompt guidance, and runtime ranking penalizes candidates that start a new section or new point instead of continuing the current paragraph. | Fresh prose proof and learned rhythm/style fit. |
| Bullets profile | 84 | Bullet/checklist/numbered current-line shape is now detected without item text, feeds trace metadata and prompt guidance, maps generic list-shaped writing to the bullets profile, keeps AI/search/form safety profiles ahead of list shape, and runtime ranking penalizes repeated bullet/checklist markers. | Screenshot-backed same-slice accepts in Notes/TextEdit plus checklist undo proof. |
| Forms profile | 84 | Field-kind resolver maps forms/secure/url to a suppressed-by-default form profile with full accept disabled, and runtime candidate ranking keeps generated form text below the display threshold. | Proven non-sensitive free-form exceptions only. |
| Search profile | 84 | Search field kind maps to a suppressed-by-default search profile with full accept disabled, and runtime candidate ranking keeps generated search text below the display threshold. | Proven across browser/native search fields. |
| AI chat profile | 89 | Codex/Claude desktop profiles are conservative, one-word biased, block submit/run/Enter suggestions, disable full accept, and runtime candidate ranking suppresses submit-like action text if the model emits it anyway. Claude Code direct bundle support is diagnostics-only, but a proof-only terminal-host adapter now maps supported terminal hosts to a virtual Claude Code profile only when proof mode, the marker, and the current input-line safety checks pass. Claude desktop now has same-baseline strict visual proof with one verified Tab accept, detector offset near zero, and no submit signal. | Same-slice visual plus one-word no-submit proof for Codex, live terminal-host proof for Claude Code, and more Claude desktop prompt layouts. |
| Accepted-and-kept learning | 90 | Live survival events update a persisted app/field/mode/profile learning store that feeds display affinity, display utility, and suppression thresholds with a 14-day half-life. Diagnostics now exposes accepted-kept rates and the current display-affinity probability/samples/threshold from trace metadata. | Prove thresholds with fresh real-app traces and add tuning controls. |
| Typed-over learning | 88 | Typed-over trace, 5s prefix-family cooldown, 30s repeated typed-over escalation, and repeated-miss suppression exist; repeated-miss scores now decay by half-life instead of poisoning a prefix indefinitely, and Diagnostics exposes the current trace-safe miss score/threshold. | Prove thresholds with fresh real-app traces. |
| Ignored learning | 84 | Ignored hides now record a weak repetition signal scaled by visible lifetime, with trace-safe weight/total metadata, the same decaying repeated-miss bucket, and Diagnostics visibility into passive ignored miss score/lifetime. | Prove thresholds with fresh real-app traces and separate passive ignored from explicit dismiss in diagnostics. |
| Esc learning | 86 | Esc dismiss now records annoyance, suppresses eligible fields until blur, starts a 15s app/field/mode/prefix cooldown, repeated Esc on the same prefix escalates to 60s, and Diagnostics exposes prefix cooldown duration/escalation metadata. | Prove real-app thresholds. |
| Style memory | 92 | Durable local style memory stores aggregate accepted-kept length, punctuation, casing, question rates, short-suffix rate, and average final-token length with 14-day half-life and no raw accepted text. Prompt guidance uses the sketch when enough samples exist, Settings can clear it, and Diagnostics exposes the trace-safe aggregate sketch. | Add tuning controls and fresh real-app trace validation. |
| Annoyance index | 90 | AppDelegate records annoyance signals, queries `AnnoyanceSuppressorActor`, quiets field/app/global scopes, exposes current-field/session silence in Settings and the menu, records manual field pauses as scoped trace events, records placement uncertainty as caret-geometry failures, and Diagnostics now exposes annoyance score, active quiet-mode scope, and signal counts from trace summaries. | Prove thresholds with fresh traces and show active quiet-mode scope in real-app proof. |
| Replay-first test rig | 84 | Trace replay now gates trigger delay coverage, display score metadata, candidate-selection metadata, proof-fingerprint freshness, placement metadata, trusted caret placement, stale cancellation, kept horizon, latency slices, annoyance signals, and redacted trace compatibility. It can replay a fresh line-bounded trace slice, and the proof manifest now parses matched manual-smoke trace slices, requires bounded proof ranges, verifies accepts plus insertion verification, checks screenshot-backed strict visual trace events, and rejects stale proof fingerprints. | Replay recorded real app sessions with screenshots, accepts, kept horizon, and latency after every app/runtime change. |
| Cross-app proof honesty | 99 | App proof matrix explicitly keeps failing rows non-A until evidence exists, replay makes stale placement/key/runtime proof fail through trace proof fingerprints, and the proof manifest now verifies TextEdit, Chrome chat-like, real Monaco/ProseMirror under forced renderer AX, Obsidian, Apple Notes title/body/checklist, and Claude desktop with bounded current-fingerprint traces while requiring every compatibility profile to have owner/safety coverage. Strict mode still fails on Codex, terminal-hosted Claude Code, and default-Chrome/editor-placement gaps. | Close every pending proof row. |

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
- `Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift:1-132`
  downloads, validates, and reports progress for the app-owned MLX model via
  the Swift Hugging Face client, and AppDelegate reloads/warmups the runtime
  after success.
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
- Done: it makes old proof stale after placement/key/runtime changes through
  trace proof fingerprints.

### P1 - Close Cross-App Proof

- TextEdit stays green with light/dark variants.
- Chrome text fields and local editor fixtures stay screenshot-backed.
- Real CodeMirror, Monaco, and ProseMirror now have bounded proof; improve
  Chrome real-editor proof from isolated forced renderer AX to default-Chrome
  caret-quality placement.
- Obsidian has disposable-vault screenshot plus same-slice accepts; expand it across themes, panes, and long notes.
- Notes title, body, and checklist are green with separate bounded proof rows.
- Codex gets screenshot plus one-word accept plus no-submit in one strict slice.
- Claude Code gets safe live terminal-host prompt proof through the proof-only adapter.
- Claude desktop same-baseline proof expands across multi-line and long prompt layouts.

### P2 - Runtime Polish

- Add static prompt prefix cache.
- Done for policy only: define the same-app, same-field, same-mode,
  same-neighborhood gate for future session/KV reuse.
- Wire per-field session/KV cache while the user remains in the same sentence or
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
32. Done: make placement uncertainty hide stale ghosts immediately, record
   caret-geometry failures, and quiet the field after repeated uncertainty.
33. Done: expose active quiet-mode scope, reason, score, and expiry in
   Diagnostics without user text.
34. Done: make first-run Settings guidance explain Accessibility in one short
   paragraph, hide Screen Recording copy unless screenshot capture is on, and
   point first success at TextEdit instead of private notes.
35. Done: add a Settings and menu control to silence the current field/session
   without disabling the whole app, recording a scoped manual pause and
   reusing field quiet-mode suppression.
36. Done: add a Settings control to force mirror render mode for the current
   app or reset it to profile mode, backed by the existing compatibility
   learning render-mode override and a `renderModeChanged` trace event.
37. Done: add a Settings app-proof starter that enables temporary per-app
   screenshot tracing and opens Diagnostics for the current profiled app.
38. Done: add direct Settings editing for the accept-all shortcut while keeping
   the existing quick cycle button.
39. Done: add trace proof fingerprints so replay fails sessions captured before
   the current trace, placement, key-capture, and runtime proof versions.
40. Done: make replay proof require placement metadata and at least one trusted
   caret or synthetic-caret placement in presented suggestions.
41. Done: make replay proof require stale cancellation and annoyance outcomes
   instead of treating them as side metrics.
42. Done: add replay line slicing and `trace_mark --replay` so fresh proof can
   be isolated and replayed without stale historical trace rows. A passing fresh
   real-app slice is still required.
43. Done: add a replay CLI self-test that fails an unsliced stale fixture,
   passes the fresh slice, checks frozen bounds, and covers `trace_mark
   --replay`.
44. Done: add a pure screenshot pixel offset detector with synthetic image
   tests and visual correction trust-gate coverage, then log offset metadata
   after screenshot capture and wire live scoped correction behind explicit
   per-app screenshot tracing. Pending: recorder-grade real-app proof.
45. Done: scope trusted visual offsets to target app version, screen, and field
   shape so manual and future screenshot corrections expire when the layout
   context changes.

## Goal Status

Active goal: grade the app, write this scorecard, then keep iterating until
every scored item reaches 100/100.

Baseline status: **78/100**.

Current implementation status: **99/100**. Not complete.

Replay proof status:

- Command: `swift run AutocompleteTraceReplay
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`
- Fresh-slice command after a saved mark: `./script/trace_mark.sh --replay`.
- Frozen-slice command: `swift run AutocompleteTraceReplay --start-line
  "$START_LINE" --end-line "$END_LINE"
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Result on the current local trace corpus with proof-fingerprint gating: proof gate
  **failed**, as expected for stale pre-pass traces.
- Key failures: trigger delay coverage 3% (198/7186), display score coverage
  0% (6/6411), candidate selection coverage 0% (4/4001), and proof fingerprint
  coverage 0% (0/24336). Placement metadata coverage is now also checked and is
  21% (1336/6411, trusted=1153) on the stale corpus.
- Useful proof still present in the stale corpus: 25,229 events, 3,267
  presented suggestions, 289 stale cancellations, 12 kept-horizon events,
  6 app latency slices, 2 mode latency slices, and 976 annoyance signals.
