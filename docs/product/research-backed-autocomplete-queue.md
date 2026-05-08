# Research-Backed Autocomplete Queue

This queue turns the local-first evaluation report into product and engineering work for this repo.

The north star is simple: a build is better only when accepted text survives, writing feels easier, and trust does not go down.

## P0 - Accepted-And-Kept

- [x] Add a deterministic accepted-text survival classifier.
- [x] Classify exact kept, lightly edited, partially kept, and rejected-after-accept outcomes.
- [x] Treat punctuation and whitespace tweaks as kept instead of false failures.
- [x] Track token recall for accepted text.
- [x] Track normalized edit distance after accept.
- [x] Emit `acceptedTextEdited` trace events.
- [x] Include `acceptanceID` so multiple accepts from one visible suggestion can be tracked separately.
- [x] Add 2s, 10s, 30s, and field-blur checkpoint support.
- [x] Keep accepted text in memory for checkpoint comparison instead of building a durable raw-text metric.
- [x] Add trace analyzer metrics for accepted-and-kept count.
- [x] Add accepted-and-kept rate by shown suggestions.
- [x] Add accepted-and-kept rate by accepted suggestions.
- [x] Add median edit distance after accept.
- [x] Add median first-edit delay after accept.
- [x] Show accepted-and-kept metrics in Diagnostics.
- [x] Show accepted-and-kept metrics in the local HTML trace report.
- [x] Print accepted-and-kept metrics from `script/check_trace_eval.sh`.
- [x] Add unit tests for exact kept, punctuation tweak, partial edit, immediate delete, and final checkpoint behavior.
- [x] Add a RAM-only expiry audit that proves accepted raw text is gone after 30s idle, blur, or 10 minutes max.
- [x] Add blur/send finalization for apps where send can be detected separately from generic blur.
- [x] Add local-window matching around expected insertion offset instead of full-field matching.
- [x] Add HMAC token and 3-gram fingerprints for redacted durable survival analysis.
- [x] Add a redacted survival export that never includes accepted raw text.
- [x] Add survival-rate slices by app, field kind, render mode, insertion mode, request mode, model, and experiment arm.
- [x] Add "accepted then deleted within 2s" as a hard trust-break signal.
- [x] Add a debug-only survival inspector that can be enabled for one local session.

## P0 - Annoyance And Backoff

- [x] Add annoyance signal counts to the trace analyzer.
- [x] Suppress phrase continuation during fast typing bursts while leaving word completion available.
- [x] Trace `typing-burst` suppressions before display.
- [x] Add annoyance score to Diagnostics and local HTML reports.
- [x] Count rapid Esc dismissal.
- [x] Count typed-over within 1s.
- [x] Count accepted-then-deleted.
- [x] Count wrong insertion and duplicate insertion.
- [x] Count search/form leakage when `fieldKind` is present.
- [x] Count repeated rejection.
- [x] Count app pause and app disable events.
- [x] Emit trace events when tracing is paused manually.
- [x] Emit trace events when the current app is disabled manually.
- [x] Build an `AnnoyanceSuppressor` with field, app, and global EMA scores.
- [x] Use a 20-minute half-life for annoyance decay.
- [x] Suppress a field for 15 minutes when field annoyance crosses the threshold.
- [x] Auto-pause an app for 30 minutes after repeated severe annoyance.
- [x] Mark an app default-off after repeated manual disables over 7 days.
- [x] Hard-stop a field immediately after wrong insertion, duplicate insertion, or focus stealing.
- [x] Treat two severe events in one app/day as an app auto-pause.
- [x] Record why a quiet mode started and when it expires.
- [x] Surface quiet mode in the menu bar and Diagnostics.
- [x] Add tests for EMA decay, field quiet mode, app quiet mode, severe hard stop, and manual disable default-off.

## P0 - Privacy-Safe Tracing

- [x] Split tracing into default redacted trace and explicit raw local debug trace.
- [x] Make raw context, prompts, raw outputs, displayed text, accepted text, and screenshots opt-in debug fields.
- [x] Add a scary local-only debug toggle with visible state.
- [x] Add `schemaVersion` and `privacyVersion` to every durable event.
- [x] Rotate `sessionID` daily for default tracing.
- [x] Add a Keychain-backed per-install HMAC secret.
- [x] Persist counts, lengths, buckets, fingerprints, and field metadata by default.
- [x] Store no document names, URLs, recipients, subject lines, screenshots, or raw text by default.
- [x] Add redaction tests for JSONL and HTML export.
- [x] Add a one-click redacted local report export.
- [x] Keep screenshot traces per-app opt-in and clearly marked.
- [x] Add retention controls for trace logs and screenshots.
- [x] Add a "delete all local traces" proof test.

## P0 - Field Targeting

- [x] Add `AXFieldClassifier`.
- [x] Classify field kind as multiline compose, singleline compose, search, form, secure, URL, unknown.
- [x] Use AX role, subrole, title, placeholder, selected range, line count, and window hints.
- [x] Suppress search, URL, password, short form, address, phone, payment-like, and secure fields by default.
- [x] Emit `fieldKind` on request, presentation, suppression, accept, insert, and survival events.
- [x] Add field-kind counts to Diagnostics.
- [x] Add field-kind slices to trace eval.
- [x] Add tests for secure/search/url/form/singleline/multiline classification.
- [x] Add an override path for safe singleline compose fields.
- [x] Add a "why blocked" line for field classifier suppressions.

## P0 - Insertion, Tab, And Focus Trust

- [x] Add a pre-accept suggestion snapshot guard for app, process, field, selected text, and before/after cursor text.
- [x] Trace `wrong-app-or-field-before-accept` as a severe do-not-ship blocker.
- [x] Add secure-field, unsupported-app, and screenshot/raw-text separation privacy tests.
- [x] Track insertion verification success rate in analyzer summaries.
- [x] Show insertion verification success in Diagnostics.
- [x] Print insertion verification success from `check_trace_eval.sh`.
- [x] Add duplicate text detection to `InsertionVerification`.
- [x] Add Tab-conflict detection after Tab accept.
- [x] Detect when Tab moved focus instead of inserting accepted text.
- [x] Detect when Tab inserted a literal tab or changed selection unexpectedly.
- [x] Emit `tab-conflict` and quiet that field/app.
- [x] Treat post-accept app, field, or focused-text verification mismatches as `insertionFailed` instead of silently ignoring them.
- [x] Add focus-stealing detection and trace event support.
- [x] Add rollback attempt metadata for failed inserts.
- [x] Add per-app insertion mode reliability stats.
- [x] Add a "wrong insertion means blocked" support gate.
- [x] Add tests for duplicate detection, Tab conflict, focus change, and rollback metadata.

## P0 - Caret And Overlay Reliability

- [x] Emit `caretGeometryFailed` when placement falls back or fails.
- [x] Track caret placement failure rate by app and render mode.
- [x] Move synthetic caret estimation into core geometry.
- [x] Reuse synthetic caret estimation for AXTextArea, WebKit, Electron, and CodeMirror-like targets when safe.
- [x] Add line-wrapping tests for synthetic caret estimation.
- [x] Add clipping tests for narrow and cramped screens.
- [x] Add overlay lifetime measurement.
- [x] Detect and count flicker under 150ms.
- [x] Suppress detached suggestions when only whole-editor anchors are available.
- [x] Add render-mode change events with reason.
- [x] Add a visual calibration report that does not require screenshots by default.

## P1 - Decision Dashboard

- [x] Add a do-not-ship blocker section to the redacted local HTML trace report.
- [x] Replace "useful rate" as the main dashboard proxy with accepted-and-kept.
- [x] Add daily summary: active writing time, shown, accepts, accepted-and-kept, p50/p95 latency, severe failures, pauses, disables.
- [x] Add per-app table: shows, accept rate, kept rate, verification success, caret failure, annoyance score, support state.
- [x] Add top failure reasons: insertion failed, duplicate text, Tab conflict, search/form leakage, caret failed, flicker.
- [x] Add latency percentiles: first-visible p50/p90/p95 and total-generation p50/p90/p95.
- [x] Add acceptance funnel: requested, model returned, shown, accepted, kept at 10s, kept at 30s/blur.
- [x] Add annoyance funnel: shown, ignored, typed over, Esc dismiss, accepted then deleted, paused, disabled.
- [x] Add current compatibility state: supported, supported with caveats, experimental, blocked.
- [x] Add recommended-next-fix rule engine.
- [x] Make duplicate/focus failures outrank model tuning.
- [x] Make caret/verification failures outrank prompt tuning.
- [x] Make latency failures outrank length experiments.

## P1 - Compatibility Gates

- [x] Add `CompatibilitySupportEvaluator`.
- [x] Gate TextEdit, Notes, Mail, Chrome textareas, Obsidian/CodeMirror, and Electron separately.
- [x] Track minimum sample size per app family.
- [x] Gate caret placement reliability.
- [x] Gate insertion verification success.
- [x] Gate duplicate text rate.
- [x] Gate Tab conflict rate.
- [x] Gate p95 first-visible latency.
- [x] Gate accepted-and-kept shown rate.
- [x] Gate annoyance score.
- [x] Mark any wrong insertion, duplicate text, focus steal, or major Tab conflict as blocked.
- [x] Make `check_trace_eval.sh` print supported / caveated / experimental / blocked.
- [x] Update `compatibility-matrix.md` from smoke-pass status to beta-readiness status.
- [x] Keep Mail diagnostics-only until compose insertion is proven safe.
- [x] Keep Atlas diagnostics-only until browser-field privacy and no-submit proof exist.

## P1 - Experiments

- [x] Add `experimentArm` to trace events.
- [x] Persist the current experiment arm locally.
- [x] Add a first-class 1-word vs 3-word suggestion-length experiment.
- [x] Stop treating 8-10 word suggestions as the default beta posture.
- [x] Add config capture for visible word count, token cap, model, prompt style, debounce, render mode, and acceptance mode.
- [x] Add within-user crossover helpers.
- [x] Counterbalance experiment order across testers.
- [x] Mark tiny-sample results as directional, not winners.
- [x] Add guardrail checks for annoyance, p95 latency, insertion success, duplicate rate, and app disable rate.
- [x] Add experiment slices to trace eval and Diagnostics.
- [x] Add a one-command local experiment report.

## P1 - Model Quality

- [x] Add a small offline prompt/output eval corpus.
- [x] Include realistic writing tasks, not only proxy completions.
- [x] Score relevance, literal continuation, repetition, assistant-style leakage, and length control.
- [x] Add confidence/coverage threshold experiments.
- [x] Track empty-result rate and blocked pre-render reason.
- [x] Add model-result latency buckets: first token, first visible, total generation.
- [x] Add p95 latency gates to `CompletionRuntimeBenchmark`.
- [x] Add p95 to `script/model_latency_report.py`.
- [x] Add model alias parity between runtime, docs, and download helper.
- [x] Move model acquisition into app/beta package so testers do not run Python.
- [x] Add a beta stop condition if runtime falls back to mock output.

## P1 - Private Beta

- [x] Upgrade the beta plan to 4 users over 10 days.
- [x] Include TextEdit, Notes, Mail, Chrome textareas, Obsidian/CodeMirror, and one Electron app.
- [x] Add day-zero onboarding with privacy, pause/disable, and smoke checks.
- [x] Add daily 2-minute survey.
- [x] Add midweek human check-in.
- [x] Add exit interview.
- [x] Include forced edge cases: search, login, forms, app switching, Tab, Esc, accept/delete.
- [x] Export a redacted local report after each session.
- [x] Keep manual reports lightweight: one magic moment, one annoying moment, best app, worst app, pause/disable reason.
- [x] Stop beta on wrong insertion, sensitive-field suggestion, unreliable Tab, mock fallback, or manual model setup.

## P2 - Architecture

- [x] Extract `SuggestionOrchestrator` from `AppDelegate`.
- [x] Extract `TraceLogger` as an actor.
- [x] Extract `RedactionLayer` as an actor.
- [x] Extract `AcceptanceSurvivalChecker` as an app-owned actor around the pure classifier.
- [x] Extract `AnnoyanceSuppressor` as an actor.
- [x] Extract `LocalReportExporter`.
- [x] Keep core logic AppKit-free.
- [x] Keep AX and AppKit adapters thin.
- [x] Add schema migration tests before changing trace storage format.
- [x] Keep raw dogfood diagnostics separate from beta/customer telemetry.

## P2 - Docs And Product Surface

- [x] Update `eval-and-tracing.md` so accepted-and-kept is the headline metric.
- [x] Update `private-beta-plan.md` with the 10-day protocol.
- [x] Update `compatibility-matrix.md` with support gates and caveats.
- [x] Update `implementation-plan.md` with the redacted telemetry architecture.
- [x] Update README model/runtime language so it matches Qwen3.5 and current packaging.
- [x] Document the exact privacy promise in plain language.
- [x] Document how to disable an app and delete traces.
- [x] Add a beta-readiness checklist that must pass before inviting testers.
- [x] Keep this repo framed as an experiment, not a committed Transcripted feature.
