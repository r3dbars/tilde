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
- Cross-app proof is honest but incomplete for Codex and more production-editor variants.
  Terminal-hosted Claude Code now has current one-word no-submit insertion proof plus historical strict visual proof; strict screenshot refresh still needs user-granted Screen Recording.
  Claude desktop now has same-baseline one-word no-submit proof, but more
  prompt layouts still need coverage.
- Chrome-hosted Google Docs, Notion, Slack, and Discord now fail closed with an
  explicit unsupported-surface decision until production proof exists.
- Acceptance traces now prove whether the inserted text exactly matched the
  visible suggestion or was a deliberate next-word visible-prefix accept.
- Normal typing proof now includes exact 1,200-, 2,400-, 4,800-, and
  12,000-character strict TextEdit endurance passes, and the current harness
  revalidates named TextEdit focus in shorter CGEvent batches with bounded
  cleanup. The current build backs off focused-text polling after observed text
  changes while keeping the fast cadence for visible suggestions. The fresh
  2026-05-08 10-minute strict run verified exact 12,000-character TextEdit
  text, event-tap p95 78us, event-tap p99/max 82us, focused-poll p95 max 35ms,
  focused-poll max 57ms, zero focused-poll slow markers, zero focused-poll
  skips, and zero tap disables.

The repo's existing Apple-native visual-feel score is **95/100**. This score is lower
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
- Accepted-and-kept display suppression is now behavior-profile aware, with
  stricter prompt/chat and sentence-like prose thresholds after enough local
  samples.
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
- Command fallback policy now makes non-sensitive diagnostics-only and
  untrusted-placement cases explicitly copy-only instead of making unsupported
  apps look broken.
- Settings now exposes quiet, normal, and eager suggestion aggressiveness,
  wiring that choice into trigger cadence, display score thresholds, runtime
  status, and trace metadata.
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
  segmented Swift typing batch. Current strict proof has verified 1,200, 2,400,
  4,800, and 12,000 exact TextEdit characters; the latest 10-minute pass had no
  missed text, no tap disables, zero focused-poll skips, focused-poll p95 max
  35ms, focused-poll max 57ms, and zero focused-poll slow markers.
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
  fingerprints. It also parses `docs/product/app-proof-matrix.md` and rejects
  `complete` manifest rows for `A-` matrix surfaces, so variant-incomplete proof
  stays marked `partial`.
- The proof manifest now carries named pending requirement labels for remaining
  variant gaps, including Notes undo lanes, Obsidian variants, Claude desktop
  prompt layouts, and production Chrome editor/chat variants. Strict manifest
  output names those exact pending requirements instead of only saying a
  surface is partial.
- Fresh installs now start with suggestion-capable apps off, keep Settings open
  until a test app is enabled, and use plainer local-model recovery copy that
  says Ollama or another model server is not needed.
- Settings now shows share-safe privacy status, and the private beta packet
  requires a privacy status file that allows only the redacted privacy bundle
  by default.
- Prompt/context metadata now includes trace-safe partial-word shape: counts,
  casing, digits, hyphen, and apostrophe only.
- Prompt/context metadata now also includes trace-safe document/window title
  shape: length bucket, word count, file extension, untitled state, and unsaved
  marker only. Raw title text is never sent to prompts or trace metadata.
- Diagnostics now exposes prompt-context shape metadata for document title,
  partial word, and current line without suggestion text or raw title text.
- Prefix-family cooldown and eagerness metadata now includes a keyed
  install-local HMAC token for the normalized prefix family, so repeated
  typed-over/Esc/deletion behavior can be correlated in diagnostics and traces
  without storing the prefix words.
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
- Replay now requires accepted insertions to have matching insertion
  verification, so a displayed suggestion cannot count as replay proof unless
  the accepted text actually landed.
- Replay now requires at least one stale cancellation and at least one annoyance
  signal, so those research outcomes cannot be skipped by a happy-path-only
  trace.
- Notes body now has bounded screenshot-backed proof with two verified accepts,
  and accepted word-completion suffixes now count as kept when the completed
  current token keeps that suffix.
- The replay CLI now accepts `--start-line`, `--end-line`, and `--profile
  full|smoke-slice`, and `script/trace_mark.sh --replay [profile]` replays
  only the fresh trace slice after a saved mark instead of mixing new proof
  with stale historical logs. Fresh bounded smoke proof can now be isolated
  from the stricter full-scenario gate.
- `script/autocomplete_trace_replay_self_test.sh` proves the CLI and
  `trace_mark --replay` skip stale rows, honor frozen slice bounds, and select
  the smoke-slice profile.
- Screenshot placement now has a pure pixel offset detector that can identify
  bounded ghost/panel drift, reject blank or low-contrast images, reject
  excessive outliers, and feed the existing trusted visual correction policy.
  Screenshot capture now logs offset metadata after a PNG is captured, and
  explicit per-app screenshot tracing can write scoped trusted corrections.
  Fresh real-app proof still needs to show the correction loop working.
- Trusted visual offsets now expire when the target app version, screen, or
  field shape changes. Legacy offsets stay trusted until resaved with scoped
  context, so older local profiles do not break abruptly.
- Fast word-completion selection now emits trace-safe candidate metadata for
  deterministic local completions, and replay counts those presented fast-word
  events as candidate-selection proof without treating them as MLX model
  results.
- `SuggestionOrchestrator` now owns rich request construction, behavior-profile
  resolution, request metadata, runtime session-cache metadata, the active
  completion request, request ticket gate, field-delivery race gate, fast
  word-selection delegation, failure visibility gate, engine delegation, and
  engine replacement after model runtime reload behind a focused app-level test
  suite. Trace-safe app-model candidate metadata now lives there too, next to
  fast-word candidate metadata, and display-score construction, streaming
  partial pacing state, replacement gating, placement planning, placement
  suppression/fallback metadata, and prefix-family cooldown display pressure now
  live behind the same boundary. AppDelegate still owns final presentation side
  effects, insertion, screenshot capture, and trace recording.
- Slow focused-text AX reads that return no focused text context now start a
  short app-specific cooldown immediately instead of requiring a repeated slow
  read, so failing editors back off sooner without touching the key path.
- Single slow focused-text AX reads with context now start a short polling
  throttle and drop that returned context, so a slow read cannot become the
  next visible suggestion while the app is trying to catch up.
- Recent text-change polling now uses a slower active-typing cadence so normal
  typing spends less time in off-main AX reads before a suggestion is visible.
- Chrome smoke now has pinned upstream `monaco-real` and `prosemirror-real`
  fixture lanes in addition to the dependency-free lookalikes. Both real-engine
  lanes now pass with isolated temp-profile Chrome, renderer accessibility
  forced, strict screenshot evidence, Tab accept, Option-Tab full accept, and
  two verified insertions. This closes the hidden lookalike-only gap, but
  production editor variants are still open.
- Chrome smoke has an explicit `--chrome-accessibility default` proof lane for
  the real Monaco/ProseMirror fixtures, but it is currently blocked on this
  machine: the latest 2026-05-09 rerun exposed only browser chrome through AX
  and failed before typing. Treat older 2026-05-08 default-Chrome proof as
  historical, not current. Current reliable real-engine proof is the isolated
  forced-renderer Chrome lane.
- Stable-bounds field identity now uses a deterministic privacy-safe hash over
  normalized AX role, fingerprint metadata, and rounded geometry instead of
  Swift's process-random `Hasher`, so trace/proof field IDs for hard editor
  surfaces stay stable across app runs when the field shape is the same.
- Acceptance now has a profile-aware safety gate before insertion: no-submit
  prompt profiles can accept only visible one-word prefixes, full accept stays
  blocked, non-visible text is blocked, and newline/tab/control accepted text is
  blocked for every profile.
- Replay-first trace proof command: `swift run AutocompleteTraceReplay
  /path/to/traces.jsonl`; bounded smoke slices can use `--profile
  smoke-slice`.

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
- Prompt metadata now includes partial-word shape, document/window title shape,
  and accepted-kept style memory now adds raw-text-free kept suffix shape:
  short-suffix rate and average final-token length.
- Atomic undo now has an app-level restore path and fresh TextEdit proof, but
  still needs per-app proof that Command-Z restores the accepted insertion
  cleanly in real editors beyond TextEdit.
- Full replay-first real-app proof is still missing. The command exists, and
  fresh bounded Chrome Monaco/ProseMirror smoke slices now pass the
  `smoke-slice` profile, but the full gate still needs model-result
  candidate metadata, stale cancellation, annoyance, and final kept-horizon
  proof in one current real-app pass.
- Cross-app proof rows still need a screenshot-backed one-word no-submit
  acceptance slice for Codex.
- Real Chrome editor-engine proof now passes under isolated forced-renderer AX,
  but default Chrome AX is currently blocked by missing page-editor exposure and
  production editor variants still need bounded proof before browser-editor
  scores can reach target.

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
| Product boundary and writer agency | 8 | 87 | 7.0 | Correctly avoids ambient rewrite/action behavior, keeps suggestions short, and now makes sentence-mode streaming wait for a fuller partial before showing anything; final sentence continuation still needs real-app drift proof. |
| Trigger gate and boundary timing | 14 | 71 | 9.9 | Strong stale/deletion/focus basics, researched delays, quiet/normal/eager cadence control, and profile-aware fresh-paragraph suppression are now live; bounded smoke replay proof exists, but full replay proof is still needed. |
| Ranking and expected utility | 12 | 70 | 8.4 | Word ranking, candidate score margins, accepted-kept suppression, and a bounded learned utility adjustment exist; phrase/sentence ranking still needs trace-tuned semantic utility. |
| Context and prompt hygiene | 9 | 73 | 6.6 | Context is small and local, but lacks field metadata, style sketch, recent kept suffixes, and a hard `<NO_SUGGESTION>` prompt path. |
| Output shape and cleanup | 8 | 89 | 7.1 | Cleaner is one of the strongest parts of the app, and now suppresses phrase restarts or visible typed-word duplicates that survive prefix trimming. |
| Local runtime and latency | 10 | 87 | 8.7 | App-owned MLX runtime, warm model, streaming, timing slices, trace-visible static prompt cache, and trace-visible per-field session-cache eligibility/reset policy; live KV/session reuse is still pending. |
| Ghost text UX and controls | 10 | 94 | 9.4 | One suggestion, Tab next word, full accept when allowed, direct accept-all shortcut editing, Esc dismiss, stale hiding, current-field/session silence, per-app force-mirror control, app-level Command-Z restore for accepted insertions, explicit copy-only fallback status when inline is unsafe, trace-safe proof that full accept matches the visible text while Tab is a visible-prefix accept, and a profile-aware acceptance safety gate before insertion. |
| Mode profiles and cross-app safety | 10 | 78 | 7.8 | Strong app profiles, a user-visible per-app mirror override, a proof-only terminal-host Claude Code adapter, and copy-only fallback stance for non-sensitive diagnostics-only or untrusted-placement cases now exist, but behavior modes are not first-class for every email, notes, bullets, docs, code, forms, search, and AI chat surface. |
| Learning, annoyance, accepted-and-kept loop | 12 | 67 | 8.0 | Accepted-kept learning now affects both affinity and utility, and user-selected quiet/normal/eager aggressiveness can tune eagerness without clearing learning; the loop still needs fresh real-app threshold proof. |
| Metrics, replay, and proof gates | 5 | 88 | 4.4 | Trace/report scripts are strong, Settings can start per-app screenshot proof from the current app, fresh bounded real-app slices now pass a replay smoke profile, deterministic fast-word selection now has trace-safe candidate metadata, and stable-bounds field identity no longer depends on process-random hashing; full replay proof still needs all scenario signals in one current pass. |
| Architecture and tests | 2 | 99 | 2.0 | Good policy/test structure, app-proof command execution is behind a small coordinator, and request construction/session-cache/request-ticket/candidate-metadata/display-score/streaming/replacement/prefix-cooldown/placement/placement-fallback/field-delivery/failure-visibility/fast-word suggestion orchestration is now behind `SuggestionOrchestrator`; AppDelegate still owns final presentation side effects, insertion, screenshot capture, and trace recording. |

Weighted total: **80.9/100**, rounded to **81/100**.

## Exact Research Items

| Research item | Score | Current evidence | What 100/100 requires |
| --- | ---: | --- | --- |
| Finishing a word | 90 | `CompletionRequestMode.wordCompletion` exists, `WordCompletionCandidateRanker` uses recent words first, trigger, activation, and fast ranking all require 3+ alphabetic chars, and Tab accepts one word. | Preserve casing/punctuation perfectly and prove acceptance-kept tuning by app/field. |
| Finishing a phrase | 87 | Phrase continuation prompt requests 1-3 tiny suffixes, prefix overlap is trimmed to suffixes, visible typed-word duplicates and phrase restarts are suppressed, and `CompletionCandidateRanker` prefers useful short phrase candidates with score-margin suppression. | Replace heuristic phrase scoring with learned utility, style fit, context fit, user affinity, risk, repetition, and instability. |
| Continuing a sentence | 80 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, quieter one-partial streaming behavior, replay delay gate, sentence candidate ranking, and low-score suppression. | Fresh real-app proof that it does not drift into planning or take over the writer's next thought. |
| Rewriting | 86 | Ambient rewrite is effectively avoided, which matches the research. | Add explicit selected-text rewrite only if needed; never ambient. |
| Suggesting next action | 90 | Ambient next actions are not part of the app, and prompt-app guards block submit/run/Enter-like suggestions plus directive starters like "you should", "we need to", and "I'd recommend". | Keep next actions behind explicit invocation only, with tests preventing inline leakage. |
| Specificity with restraint | 88 | Prompt asks for boring connective tissue, dogfood prompt guidance rejects generic productivity filler, cleaner suppresses filler, directive recommendation starters, visible typed-word duplicates, and phrase restarts, and context-aware candidate ranking now prefers restrained lengths while penalizing questions, generic filler, sentence planning drift, and unsupported new names/dates. | Tune the semantic-commitment weights against fresh traces. |
| Gate, not timer | 85 | Eligibility, stale request checks, repetition suppression, focus checks, mode-aware trigger delays, quiet/normal/eager cadence, prefix-family cooldowns, and display scoring are live. | Prove the whole trigger/display decision from replayed real-app traces. |
| Within-word mode | 88 | Word completion now requires 3+ alphabetic chars in trigger, activation, and fast ranking, uses a 90-140ms trigger delay, and word suffix cleaning rejects spaces/punctuation. | Perfect casing/punctuation preservation and fresh app-slice proof. |
| Phrase mode | 84 | Word-boundary phrase requests use 140-240ms delay, phrase display threshold, behavior-profile prompt caps, and candidate ranking. | Fresh real-app proof and learned score margins. |
| Sentence mode | 78 | First-class `sentenceContinuation` mode exists with activation, prompt guidance, stricter display threshold, one-partial streaming restraint, replay delay gate, and ranker penalties for question/planning drift. | Real-app proof that it does not take over the writer's next thought. |
| Line/paragraph start | 86 | Trigger policy suppresses plain line starts until two content words, keeps bare markers quiet, allows constrained one-word completions in list/checklist and email contexts, and now enforces profile fresh-paragraph suppression for docs/email/code until the new paragraph has stronger local context. | Add screenshot proof and tune profile-specific exceptions against real traces. |
| After deletion | 83 | Deletion skips requests, records a 250ms prefix-family cooldown, and carries the same keyed trace-safe prefix-family HMAC token used by typed-over and Esc cooldowns. | Prove the live cooldown in fresh traces and feed longer-term deletion outcomes into learning. |
| After accept | 91 | Tab accepts one word, full accept is profile-gated, accepted-and-kept horizons feed durable display affinity, the app discards residual Tab text so the next follow-on must be recomputed and rescored, accepted events now carry visible-text proof metadata, and acceptance safety blocks non-visible/control text before insertion. | Prove the recompute behavior in fresh real-app traces. |
| After typed-over | 89 | Typed-over is traced, learned as a miss, starts a 5s app/field/mode/prefix-family cooldown, repeated typed-over on the same prefix escalates to 30s, repeated typed-over pressure raises display thresholds for the same app/field/mode/prefix family after cooldown, and cooldown/eagerness metadata now carries a keyed trace-safe prefix-family HMAC token. | Prove thresholds with fresh real-app traces. |
| After Esc dismissal | 86 | Esc dismisses, traces the keyboard action, starts a 15s app/field/mode/prefix-family cooldown, escalates repeated dismissals on the same prefix to 60s, and exposes cooldown duration/escalation plus the trace-safe prefix-family HMAC token in diagnostics. | Prove the no-text-change path and repeated-dismiss thresholds in fresh real-app traces. |
| App switch / caret move / selection change | 84 | Workspace app activation/deactivation now clears focused-field state, hides visible suggestions, stops key capture, and invalidates pending requests immediately; focus/app mismatch still hides on polling/key paths, event-tap start/failed-closed failures are separated from AX warning noise, and selection is blocked. Mouse/caret moves inside the same app are still polling-based. | Immediate hide/cancel on caret, mouse, and same-app selection events where possible, plus fresh real-app proof. |
| Punctuation handling | 88 | Whitespace, comma/semicolon, colon, closing punctuation, and sentence punctuation now have separate clamped delay lanes; newline/bullet starts stay suppressed until constrained; email greeting commas and short list-label colons wait longer, and coding closing brackets stay quiet. | Tune against fresh traces. |
| Display score | 91 | Live display score includes utility, style fit, context fit, user affinity, risk, repetition, instability, accepted-and-kept probability, behavior profile, suggestion aggressiveness, and trace metadata. Accepted-kept learning now applies a bounded utility adjustment in addition to affinity and profile-aware low-probability suppression. Candidate count, top score, score margin, and suppression reason are logged at runtime for MLX candidate ranking and deterministic fast word completions. | Replace remaining heuristic components with learned estimates and use fresh traces to tune thresholds. |
| Accept-and-keep probability threshold | 89 | Durable learning now gates by app, field kind, mode, and behavior profile after enough evidence, uses stricter thresholds for AI chat, casual chat, sentence-like prose, coding, forms, and search profiles, applies bounded affinity and utility adjustments, decays with a 14-day half-life, and Settings can clear learned suggestion state without deleting logs. | Prove thresholds with fresh real-app traces and expose tuning controls. |
| Candidate generation | 85 | Phrase/sentence prompts ask for 1-3 candidates; `CompletionOutputCleaner.cleanCandidates` strips list prefixes, filters unsafe/sentinel lines, dedupes, and context/profile-aware `CompletionCandidateRanker` picks only high-score/high-margin candidates while penalizing unsupported names/dates, generic filler, email commitments, casual-chat steering, notes verbosity, docs new-point drift, coding block/API drift, repeated bullet markers, prompt-app submit actions, and form/search fills. Fast word completion now exposes its deterministic candidate count, top score, margin, and suppression reason in trace-safe metadata. | Prove real model outputs produce useful candidate sets and tune score/margin thresholds from traces. |
| Context budget | 85 | Prompt context now uses a 48-96 token budget, keeps the current local fragment, borrows the prior sentence when the current fragment is tiny or sentence mode needs it, borrows the prior paragraph only for tiny sentence-mode starts, and adds trace-safe document/window title shape without raw title text. | Tune the usefulness rules against fresh real-model traces. |
| Metadata in prompt | 93 | App bundle, field kind, request mode, behavior profile, aggregate accepted-kept style sketch, trace-safe partial-word shape, trace-safe current-line list shape, trace-safe document/window title shape, and raw-text-free kept suffix shape now affect prompt/generation/scoring/tracing. Diagnostics exposes the prompt-context shape without suggestion text or raw title text. | Tune these features against fresh traces. |
| Hard `<NO_SUGGESTION>` path | 86 | Word/phrase/sentence prompts include `<NO_SUGGESTION>` guidance, and cleaner suppresses direct sentinels plus prompt-echo sentinel lines. | Prove sentinel behavior in fresh real model traces. |
| Privacy-first tracing | 97 | Raw content is redacted by default, raw/screenshot capture is opt-in with expiry, line/list and document/window title shape metadata avoid item/title text, kept suffix shape stores aggregate rates/lengths instead of text, prefix-family cooldown/eagerness traces now store only keyed install-local HMAC tokens, Settings can clear learned suggestion state separately from local logs, permission copy states what is read and why, and Diagnostics now exposes placement confidence/anchor/render/self-healing evidence without suggestion text. | Make compact style/learning features more inspectable and prove the new prefix HMAC metadata in fresh real-app traces. |
| Local runtime ownership | 92 | App-owned embedded runtime and no user-managed server dependency. | Keep this stance through beta and fail clearly if model assets are missing. |
| Warm/runtime cache | 82 | Model container is warm and reused, static system prompts now go through a bounded redacted-key cache with hit/size trace metadata, `CompletionRequest` carries field identity, and `RuntimeSessionCachePolicy` defines a tested same-app/same-field/same-mode/same-neighborhood reuse gate with trace metadata for reuse eligibility and reset reasons. Each MLX request still builds a new `ChatSession`. | Wire safe per-field session/KV reuse into the app runtime. |
| Generated length | 92 | MVP defaults to 7 visible words / 14 generated tokens, behavior profiles stay shorter for risky modes, env overrides clamp at 7 visible words / 16 generated tokens, and sentence mode has its own 10-token ceiling. | Tune defaults from fresh traces. |
| Stale cancellation | 90 | Request IDs, text snapshots, keydown invalidation, session-cache request metadata, and the app-level request/ticket/field-delivery/failure-visibility gate are now behind tested `SuggestionOrchestrator` ownership. | Add cancellation proof in replay rig. |
| One visible suggestion | 95 | Single `SuggestionSession`, no dropdown or carousel. | Keep this invariant. |
| Single-line under 42 chars | 90 | `CompletionSuggestion` caps visible text to one line, bounded words, and 42 visible characters. | Add screenshot proof across narrow editors and long wrapped lines. |
| Flicker control | 90 | Streaming presentation gate limits partial updates, sentence-mode streaming now waits for three visible words and caps at one partial, and replacement suppresses fresh/low-margin candidate swaps with 1.2s fresh and 2s stale lifetime tests. | Add screenshot proof across narrow editors and streaming model output. |
| Tab next word | 96 | Implemented, app/profile gated, app Tab acceptance discards residual visible text after one word so the next suggestion must come from a new scored request, and traces mark it as a visible-prefix accept rather than a full visible accept. | Prove the recompute behavior in fresh real-app traces. |
| Full visible accept shortcut | 87 | Full accept exists when profile supports it, prompt apps disable full accept through the no-submit acceptance gate, accepted insertions arm the same one-step Command-Z restore path, and full accept is blocked unless the accepted text exactly matches the visible suggestion. | Prove undo and no-submit in every app where full accept is enabled. |
| Esc dismiss | 90 | Implemented, traces keyboard action, marks Esc dismissal as inserting zero suggestion text, starts a prefix-family cooldown, and repeated Esc on the same prefix escalates. | Prove the no-text-change path in fresh real-app traces. |
| Atomic undo | 85 | Accepted insertions now arm an 8s one-step Command-Z restore for the same focused app/field; deliberate undo clears acceptance-survival tracking so normal Command-Z is not scored as accepted-then-deleted; raw accepted text stays only in ephemeral memory and diagnostics log lengths/status only. The TextEdit smoke lane now has fresh live proof at 2026-05-08T09:16:49Z with `accepted-insertion-undone`, two verified accepts, and strict visual evidence. Notes now has explicit `notes-title-undo`, `notes-body-undo`, and `notes-checklist-undo` recorder lanes that require the same undo diagnostics. | Run the new Notes undo lanes, then prove the restore path per app beyond TextEdit and decide whether native undo grouping can replace the app-level fallback. |
| Casual chat profile | 82 | `AutocompleteBehaviorProfile.casualChat` caps at 4 words, suppresses questions/emotional text, and runtime candidate ranking penalizes question-like or emotionally steering completions. | Fresh chat-app proof and learned style fit. |
| Email profile | 79 | Mail resolves to an email profile with 2-6 word cap, prompt guidance plus trigger-level blank/fresh paragraph suppression, no invented commitments/names/deadlines guidance, and runtime candidate ranking now penalizes invented meetings, dates, attachments, and unsupported commitments. | Real Mail proof plus safe free-form exceptions. |
| Notes profile | 90 | Notes app profile exists with terse 1-5 word guidance, blank-line suppression, list/checklist prompt guidance, safer AX-first insertion, delayed read-only verification for Notes AX lag, and stale text-after-cursor repair. Title, body, and checklist fields have same-slice strict visual proof with two verified accepts each, and separate undo recorder lanes now require `accepted-insertion-undone`. | Run the Notes undo lanes, then add more list lengths and checked-item proof. |
| Coding profile | 78 | Coding profile caps at 1-5 tokens, warns against invented APIs/imports/blocks, and runtime candidate ranking now penalizes block/import/function starters, multiline output, and unsupported identifiers. | Opt-in proof in real editors and deeper syntax-aware scoring from editor context. |
| Docs/prose profile | 82 | Docs/prose profile matches rhythm/vocabulary, now enforces fresh-paragraph trigger suppression instead of only prompt guidance, and runtime ranking penalizes candidates that start a new section or new point instead of continuing the current paragraph. | Fresh prose proof and learned rhythm/style fit. |
| Bullets profile | 84 | Bullet/checklist/numbered current-line shape is now detected without item text, feeds trace metadata and prompt guidance, maps generic list-shaped writing to the bullets profile, keeps AI/search/form safety profiles ahead of list shape, and runtime ranking penalizes repeated bullet/checklist markers. | Screenshot-backed same-slice accepts in Notes/TextEdit plus checklist undo proof. |
| Forms profile | 84 | Field-kind resolver maps forms/secure/url to a suppressed-by-default form profile with full accept disabled, and runtime candidate ranking keeps generated form text below the display threshold. | Proven non-sensitive free-form exceptions only. |
| Search profile | 84 | Search field kind maps to a suppressed-by-default search profile with full accept disabled, and runtime candidate ranking keeps generated search text below the display threshold. | Proven across browser/native search fields. |
| AI chat profile | 92 | Codex/Claude desktop profiles are conservative, one-word biased, block submit/run/Enter suggestions, require no-submit acceptance safety, disable full accept, and runtime candidate ranking suppresses submit-like action text if the model emits it anyway. Claude Code direct bundle support is diagnostics-only, but a proof-only terminal-host adapter now maps supported terminal hosts to a virtual Claude Code profile only when proof mode, the marker, and the current input-line safety checks pass; that virtual profile also requires no-submit acceptance safety. Claude Code now has current Terminal-host one-word no-submit insertion proof, and Claude desktop has same-slice strict visual proof with one verified Tab accept and no submit signal. | Strict screenshot refresh for Claude Code, plus more Claude Code terminal-host and Claude desktop prompt layouts. |
| Accepted-and-kept learning | 91 | Live survival events update a persisted app/field/mode/profile learning store that feeds display affinity, display utility, and profile-aware suppression thresholds with a 14-day half-life. Diagnostics now exposes accepted-kept rates and the current display-affinity probability/samples/threshold from trace metadata. | Prove thresholds with fresh real-app traces and add tuning controls. |
| Typed-over learning | 91 | Typed-over trace, 5s prefix-family cooldown, 30s repeated typed-over escalation, repeated-miss suppression, and post-cooldown prefix-family display-threshold backoff exist; repeated-miss scores now decay by half-life instead of poisoning a prefix indefinitely, and Diagnostics exposes the current trace-safe miss score/threshold plus the keyed prefix-family HMAC token. | Prove thresholds with fresh real-app traces. |
| Ignored learning | 84 | Ignored hides now record a weak repetition signal scaled by visible lifetime, with trace-safe weight/total metadata, the same decaying repeated-miss bucket, and Diagnostics visibility into passive ignored miss score/lifetime. | Prove thresholds with fresh real-app traces and separate passive ignored from explicit dismiss in diagnostics. |
| Esc learning | 87 | Esc dismiss now records annoyance, suppresses eligible fields until blur, starts a 15s app/field/mode/prefix cooldown, repeated Esc on the same prefix escalates to 60s, and Diagnostics exposes prefix cooldown duration/escalation metadata plus the keyed prefix-family HMAC token. | Prove real-app thresholds. |
| Style memory | 92 | Durable local style memory stores aggregate accepted-kept length, punctuation, casing, question rates, short-suffix rate, and average final-token length with 14-day half-life and no raw accepted text. Prompt guidance uses the sketch when enough samples exist, Settings can clear it, and Diagnostics exposes the trace-safe aggregate sketch. | Add tuning controls and fresh real-app trace validation. |
| Annoyance index | 91 | AppDelegate records annoyance signals, queries `AnnoyanceSuppressorActor`, quiets field/app/global scopes, exposes current-field/session silence and quiet/normal/eager aggressiveness in Settings, records manual field pauses as scoped trace events, records placement uncertainty as caret-geometry failures, and Diagnostics now exposes annoyance score, active quiet-mode scope, and signal counts from trace summaries. | Prove thresholds with fresh traces and show active quiet-mode scope in real-app proof. |
| Replay-first test rig | 88 | Trace replay now gates trigger delay coverage, display score metadata, candidate-selection metadata, proof-fingerprint freshness, placement metadata, trusted caret placement, accepted insertion verification, stale cancellation, kept horizon, latency slices, annoyance signals, and redacted trace compatibility. It can replay fresh line-bounded trace slices, including a `smoke-slice` profile that passes current Chrome Monaco/ProseMirror bounded real-app proof while keeping the default full gate strict. Full replay can now count trace-safe deterministic fast-word candidate metadata on presented events, not only MLX `modelResult` rows. The proof manifest parses matched manual-smoke trace slices, requires bounded proof ranges, verifies accepts plus insertion verification, checks screenshot-backed strict visual trace events, and rejects stale proof fingerprints. | Replay recorded real app sessions with screenshots, accepts, final kept horizon, stale cancellation, annoyance, model candidate metadata, fast-word candidate metadata, and latency after every app/runtime change. |
| Cross-app proof honesty | 99 | App proof matrix explicitly keeps failing rows non-A until evidence exists, unsupported/sensitive apps expose an intentional off or copy-only stance instead of silent breakage, replay makes stale placement/key/runtime proof fail through trace proof fingerprints, stable-bounds field identity is deterministic for proof traces, and the proof manifest now verifies TextEdit, Chrome chat-like, and real Monaco/ProseMirror under forced renderer AX while keeping default Chrome AX as a blocked proof gap. Obsidian, Apple Notes title/body/checklist, and Claude desktop have bounded historical proof; Claude Code now has a current no-submit insertion row but still needs strict screenshot refresh and host variants. Chrome-hosted Google Docs, Notion, Slack, and Discord now have a trace-safe unsupported-surface block until proof exists. Strict mode still fails on Codex and production-editor variant gaps. | Close every pending proof row. |

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
- Gate display on accepted-and-kept probability, with mode- and profile-specific
  thresholds.
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
- Real CodeMirror, Monaco, and ProseMirror now have bounded proof; add
  production editor variants beyond the local real-engine fixtures.
- Obsidian has disposable-vault screenshot plus same-slice accepts across default, theme, pane, and long-note lanes; expand later only for broader vault layouts and hidden-caret edge cases.
- Notes title, body, and checklist are green with separate bounded proof rows.
- Codex still needs screenshot plus one-word accept plus no-submit in one strict slice.
- Claude Code has safe live terminal-host prompt proof through the proof-only adapter; the current row is no-submit insertion proof, while screenshot refresh still needs user-granted Screen Recording.
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
20. Partial: build the replay-first proof command. The command exists, and
   fresh Chrome Monaco/ProseMirror bounded slices pass the `smoke-slice`
   replay profile. The full replay profile still needs a current all-scenario
   real-app pass.
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
   be isolated and replayed without stale historical trace rows.
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
46. Done: add `full` and `smoke-slice` replay profiles. The default full gate
   still requires candidate-selection metadata, stale cancellation, final kept
   horizon, and annoyance signals; the smoke-slice gate proves bounded
   trigger/display/fingerprint/placement/accepted-insertion evidence for
   fresh real-app slices.
47. Done: make deterministic fast word-completion selection trace-visible with
   candidate count, top score, score margin, and suppression reason, then let
   full replay count those fast-word presented events as candidate-selection
   proof.
48. Done: move active request ownership, request-ticket gating, fast-word
   selection, engine delegation, and runtime-reload engine replacement behind
   `SuggestionOrchestrator`, with app-level tests for current-request storage,
   stale ticket blocking, invalidation, candidate metadata, engine delegation,
   and replacement-engine suggestions.
49. Done: move async delivery field matching into `SuggestionOrchestrator`, so
   partial and final model results share the same tested request-ticket plus
   current-field race guard before AppDelegate presents anything.
50. Done: move rich completion-request construction, behavior-profile
   resolution, request trace metadata, accepted-style key derivation, and
   runtime session-cache metadata into `SuggestionOrchestrator`, with app-level
   tests for style-sketch wiring and same-field reuse metadata.
51. Done: move engine-failure visibility gating into `SuggestionOrchestrator`,
   so stale failed requests or failures from another focused field cannot hide
   the visible suggestion through AppDelegate-owned request-gate plumbing.
52. Done: move app-level model-result candidate metadata into
   `SuggestionOrchestrator`, keeping deterministic fast-word and MLX-result
   candidate metadata in the same tested orchestration boundary.
53. Done: move display-score construction into `SuggestionOrchestrator`, so the
   utility/style/context/learning/repetition/instability math that decides
   presentation readiness is tested outside AppDelegate.
54. Done: move prefix-family cooldown ownership and display-threshold pressure
   into `SuggestionOrchestrator`, including reset behavior when learning data is
   cleared.
55. Done: move visible-suggestion replacement gating into
   `SuggestionOrchestrator`, including fresh-suggestion age calculation and
   score-margin proof.
56. Done: move streaming partial pacing state into `SuggestionOrchestrator`, so
   interval gates, max partial count, finish, and clear behavior are tested away
   from AppDelegate.
57. Done: move placement-health planning and Chrome synthetic-caret proof gating
   into `SuggestionOrchestrator`, leaving AppDelegate to execute panel display,
   screenshots, and trace recording.
58. Done: move placement suppression fallback metadata into
   `SuggestionOrchestrator`, so low-confidence placement branches emit copy-only
   fallback state outside AppDelegate.
59. Done: extend the Settings Chrome proof command to run the forced
   all-fixtures lane plus default-AX real Monaco and real ProseMirror add-on
   lanes, so one-click Chrome proof now exercises the Chrome editor proof rows.
60. Done: make automatic proof command start failures end temporary proof mode
   immediately, so unavailable or failed proof commands cannot leave a proof
   window open until expiry.
61. Done: make sentence-mode streaming quieter by requiring a three-word partial
   and allowing only one visible sentence partial before the final suggestion.
62. Done: classify event-tap start failures and failed-closed markers as hard
   key-capture failures in Diagnostics and the typing-performance guard while
   keeping AX polling slowness in its separate warning lane.
63. Done: make `check_proof_manifest.py` cross-check
   `docs/product/app-proof-matrix.md` in strict mode, so any `A-` matrix row
   marked `complete` in the proof manifest fails and variant-incomplete live
   smoke proof stays `partial`.
64. Done: strengthen ambient output restraint by suppressing more assistant-like
   advice and planning starters such as "what I would do", "one option is",
   "the next step would", and "I think we should".
65. Done: tighten post-write insertion verification so after-cursor drift fails
   even when the accepted prefix appears to land, and missing or changed
   verification targets record `insertionFailed` trace evidence instead of
   returning quietly.
66. Done: add a clipboard fallback policy so pasteboard insertion remains
   blocked unless the debug runtime flag is enabled and the specific
   compatibility profile explicitly opts into clipboard fallback.
67. Done: make clipboard fallback restore the original pasteboard only while
   the pasteboard still contains this app's temporary payload at the same
   change count, preserving user clipboard changes made during fallback.
68. Done: wire strict manual-smoke, visual-evidence, and proof-manifest gates
   into the score target script for the real scorecard files, so Markdown score
   edits cannot report completion while proof artifacts are still partial or
   pending.
69. Done: replace process-random Swift `Hasher` stable-bounds field IDs with a
   deterministic privacy-safe hash over normalized field metadata and rounded
   geometry, with an exact stable-ID unit test.
70. Done: add profile-aware acceptance safety before insertion so no-submit
   prompt profiles block full accept and multiword/non-visible/control accepted
   text, while standard profiles still allow proven full visible accept.
71. Done: strengthen strict proof-manifest replay for prompt no-submit slices:
   Codex, Claude Code, Claude desktop, and Chrome chat-like trace verification
   now fails on submit-like trace signals, and no-submit-only prompt surfaces
   also fail if the slice used full accept instead of one-word Tab proof.
72. Done: add guarded official Chrome editor smoke lanes for CodeMirror,
   Monaco, and ProseMirror, plus a single-run smoke lock and pre-keystroke
   Chrome/frontmost/URL checks so proof attempts fail closed instead of typing
   into the wrong app. These lanes are implementation-ready but still score as
   pending until bounded screenshot-backed official-demo traces pass.
73. Done: harden Chrome proof typing further after live proof exposed stale
   worktree smoke processes, disabled Chrome JavaScript-from-Apple-Events
   preflight, and global setup-keystroke focus changes. Non-dry real-app smoke
   now scans for other active smoke scripts before acquiring the lock, uses
   isolated Chrome plus localhost DevTools for official-demo readiness/focus/
   setup, requires a focused editable web text AX target before Chrome setup
   text, and verifies setup text before waiting for app logs. `prosemirror-
   official` and `codemirror-official` now have strict screenshot-backed proof;
   Monaco still fails on current-page AX context, so Chrome scores stay capped
   until the remaining screenshot-backed official-demo trace passes.

## Goal Status

Active goal: grade the app, write this scorecard, then keep iterating until
every scored item reaches 100/100.

Baseline status: **78/100**.

Current implementation status: **99/100**. Not complete.

Replay proof status:

- Command: `swift run AutocompleteTraceReplay
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`
- Fresh-slice command after a saved mark: `./script/trace_mark.sh --replay`.
- Bounded smoke-slice command after a saved mark: `./script/trace_mark.sh
  --replay smoke-slice`.
- Frozen-slice command: `swift run AutocompleteTraceReplay --start-line
  "$START_LINE" --end-line "$END_LINE"
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Frozen bounded smoke-slice command: `swift run AutocompleteTraceReplay
  --profile smoke-slice --start-line "$START_LINE" --end-line "$END_LINE"
  /Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Fresh bounded Chrome smoke proof now passes `smoke-slice`:
  `--start-line 56348 --end-line 56359` for `monaco-real-default` passed with
  11 events, 2/2 trigger delay coverage, 2/2 display score coverage, 11/11
  proof fingerprint freshness, 2/2 trusted placement coverage, 2/2 accepted
  insertion coverage, and 2 short-horizon survival events.
- Fresh bounded Chrome smoke proof also passes `smoke-slice`:
  `--start-line 56360 --end-line 56373` for `prosemirror-real-default` passed
  with 13 events, 2/2 trigger delay coverage, 2/2 display score coverage,
  13/13 proof fingerprint freshness, 2/2 trusted placement coverage, 2/2
  accepted insertion coverage, 4 short-horizon survival events, and 2 final
  kept-horizon events.
- New fast word-completion traces captured after this pass include
  `candidateSelectionSource=fast-word-completion`, `cleanedCandidateCount`,
  `candidateTopScore`, `candidateScoreMargin`, and
  `candidateSuppressionReason` on presented fast-word events, so future full
  replay slices can prove deterministic local candidate selection without
  requiring an MLX `modelResult` row.
- Result on the current local trace corpus with proof-fingerprint gating: proof gate
  **failed**, as expected for stale pre-pass traces.
- Key failures: trigger delay coverage 3% (198/7186), display score coverage
  0% (6/6411), candidate selection coverage 0% (4/4001), and proof fingerprint
  coverage 0% (0/24336). Placement metadata coverage is now also checked and is
  21% (1336/6411, trusted=1153) on the stale corpus.
- The default `full` profile remains intentionally stricter than the bounded
  smoke profile: it still requires current model-result candidate metadata,
  stale cancellation, final kept-horizon, and annoyance evidence in the proof
  slice.
- Useful proof still present in the stale corpus: 25,229 events, 3,267
  presented suggestions, 289 stale cancellations, 12 kept-horizon events,
  6 app latency slices, 2 mode latency slices, and 976 annoyance signals.
