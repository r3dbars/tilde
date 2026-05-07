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
- [ ] Add a RAM-only expiry audit that proves accepted raw text is gone after 30s idle, blur, or 10 minutes max.
- [ ] Add blur/send finalization for apps where send can be detected separately from generic blur.
- [ ] Add local-window matching around expected insertion offset instead of full-field matching.
- [ ] Add HMAC token and 3-gram fingerprints for redacted durable survival analysis.
- [ ] Add a redacted survival export that never includes accepted raw text.
- [ ] Add survival-rate slices by app, field kind, render mode, insertion mode, request mode, model, and experiment arm.
- [ ] Add "accepted then deleted within 2s" as a hard trust-break signal.
- [ ] Add a debug-only survival inspector that can be enabled for one local session.

## P0 - Annoyance And Backoff

- [x] Add annoyance signal counts to the trace analyzer.
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
- [ ] Build an `AnnoyanceSuppressor` with field, app, and global EMA scores.
- [ ] Use a 20-minute half-life for annoyance decay.
- [ ] Suppress a field for 15 minutes when field annoyance crosses the threshold.
- [ ] Auto-pause an app for 30 minutes after repeated severe annoyance.
- [ ] Mark an app default-off after repeated manual disables over 7 days.
- [ ] Hard-stop a field immediately after wrong insertion, duplicate insertion, or focus stealing.
- [ ] Treat two severe events in one app/day as an app auto-pause.
- [ ] Record why a quiet mode started and when it expires.
- [ ] Surface quiet mode in the menu bar and Diagnostics.
- [ ] Add tests for EMA decay, field quiet mode, app quiet mode, severe hard stop, and manual disable default-off.

## P0 - Privacy-Safe Tracing

- [ ] Split tracing into default redacted trace and explicit raw local debug trace.
- [ ] Make raw context, prompts, raw outputs, displayed text, accepted text, and screenshots opt-in debug fields.
- [ ] Add a scary local-only debug toggle with visible state.
- [ ] Add `schemaVersion` and `privacyVersion` to every durable event.
- [ ] Rotate `sessionID` daily for default tracing.
- [ ] Add a Keychain-backed per-install HMAC secret.
- [ ] Persist counts, lengths, buckets, fingerprints, and field metadata by default.
- [ ] Store no document names, URLs, recipients, subject lines, screenshots, or raw text by default.
- [ ] Add redaction tests for JSONL and HTML export.
- [ ] Add a one-click redacted local report export.
- [ ] Keep screenshot traces per-app opt-in and clearly marked.
- [ ] Add retention controls for trace logs and screenshots.
- [ ] Add a "delete all local traces" proof test.

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

- [x] Track insertion verification success rate in analyzer summaries.
- [x] Show insertion verification success in Diagnostics.
- [x] Print insertion verification success from `check_trace_eval.sh`.
- [ ] Add duplicate text detection to `InsertionVerification`.
- [ ] Add Tab-conflict detection after Tab accept.
- [ ] Detect when Tab moved focus instead of inserting accepted text.
- [ ] Detect when Tab inserted a literal tab or changed selection unexpectedly.
- [ ] Emit `tab-conflict` and quiet that field/app.
- [ ] Add focus-stealing detection and trace event support.
- [ ] Add rollback attempt metadata for failed inserts.
- [ ] Add per-app insertion mode reliability stats.
- [ ] Add a "wrong insertion means blocked" support gate.
- [ ] Add tests for duplicate detection, Tab conflict, focus change, and rollback metadata.

## P0 - Caret And Overlay Reliability

- [ ] Emit `caretGeometryFailed` when placement falls back or fails.
- [ ] Track caret placement failure rate by app and render mode.
- [ ] Move synthetic caret estimation into core geometry.
- [ ] Reuse synthetic caret estimation for AXTextArea, WebKit, Electron, and CodeMirror-like targets when safe.
- [ ] Add line-wrapping tests for synthetic caret estimation.
- [ ] Add clipping tests for narrow and cramped screens.
- [ ] Add overlay lifetime measurement.
- [ ] Detect and count flicker under 150ms.
- [ ] Suppress detached suggestions when only whole-editor anchors are available.
- [ ] Add render-mode change events with reason.
- [ ] Add a visual calibration report that does not require screenshots by default.

## P1 - Decision Dashboard

- [ ] Replace "useful rate" as the main dashboard proxy with accepted-and-kept.
- [ ] Add daily summary: active writing time, shown, accepts, accepted-and-kept, p50/p95 latency, severe failures, pauses, disables.
- [ ] Add per-app table: shows, accept rate, kept rate, verification success, caret failure, annoyance score, support state.
- [ ] Add top failure reasons: insertion failed, duplicate text, Tab conflict, search/form leakage, caret failed, flicker.
- [ ] Add latency percentiles: first-visible p50/p90/p95 and total-generation p50/p90/p95.
- [ ] Add acceptance funnel: requested, model returned, shown, accepted, kept at 10s, kept at 30s/blur.
- [ ] Add annoyance funnel: shown, ignored, typed over, Esc dismiss, accepted then deleted, paused, disabled.
- [ ] Add current compatibility state: supported, supported with caveats, experimental, blocked.
- [ ] Add recommended-next-fix rule engine.
- [ ] Make duplicate/focus failures outrank model tuning.
- [ ] Make caret/verification failures outrank prompt tuning.
- [ ] Make latency failures outrank length experiments.

## P1 - Compatibility Gates

- [ ] Add `CompatibilitySupportEvaluator`.
- [ ] Gate TextEdit, Notes, Mail, Chrome textareas, Obsidian/CodeMirror, and Electron separately.
- [ ] Track minimum sample size per app family.
- [ ] Gate caret placement reliability.
- [ ] Gate insertion verification success.
- [ ] Gate duplicate text rate.
- [ ] Gate Tab conflict rate.
- [ ] Gate p95 first-visible latency.
- [ ] Gate accepted-and-kept shown rate.
- [ ] Gate annoyance score.
- [ ] Mark any wrong insertion, duplicate text, focus steal, or major Tab conflict as blocked.
- [ ] Make `check_trace_eval.sh` print supported / caveated / experimental / blocked.
- [ ] Update `compatibility-matrix.md` from smoke-pass status to beta-readiness status.
- [ ] Keep Mail diagnostics-only until compose insertion is proven safe.
- [ ] Keep Atlas unsupported until focused AX element reliability is proven.

## P1 - Experiments

- [ ] Add `experimentArm` to trace events.
- [ ] Persist the current experiment arm locally.
- [ ] Add a first-class 1-word vs 3-word suggestion-length experiment.
- [x] Stop treating 8-10 word suggestions as the default beta posture.
- [ ] Add config capture for visible word count, token cap, model, prompt style, debounce, render mode, and acceptance mode.
- [ ] Add within-user crossover helpers.
- [ ] Counterbalance experiment order across testers.
- [ ] Mark tiny-sample results as directional, not winners.
- [ ] Add guardrail checks for annoyance, p95 latency, insertion success, duplicate rate, and app disable rate.
- [ ] Add experiment slices to trace eval and Diagnostics.
- [ ] Add a one-command local experiment report.

## P1 - Model Quality

- [ ] Add a small offline prompt/output eval corpus.
- [ ] Include realistic writing tasks, not only proxy completions.
- [ ] Score relevance, literal continuation, repetition, assistant-style leakage, and length control.
- [ ] Add confidence/coverage threshold experiments.
- [ ] Track empty-result rate and blocked pre-render reason.
- [ ] Add model-result latency buckets: first token, first visible, total generation.
- [ ] Add p95 latency gates to `CompletionRuntimeBenchmark`.
- [x] Add p95 to `script/model_latency_report.py`.
- [ ] Add model alias parity between runtime, docs, and download helper.
- [ ] Move model acquisition into app/beta package so testers do not run Python.
- [ ] Add a beta stop condition if runtime falls back to mock output.

## P1 - Private Beta

- [ ] Upgrade the beta plan to 4 users over 10 days.
- [ ] Include TextEdit, Notes, Mail, Chrome textareas, Obsidian/CodeMirror, and one Electron app.
- [ ] Add day-zero onboarding with privacy, pause/disable, and smoke checks.
- [ ] Add daily 2-minute survey.
- [ ] Add midweek human check-in.
- [ ] Add exit interview.
- [ ] Include forced edge cases: search, login, forms, app switching, Tab, Esc, accept/delete.
- [ ] Export a redacted local report after each session.
- [ ] Keep manual reports lightweight: one magic moment, one annoying moment, best app, worst app, pause/disable reason.
- [ ] Stop beta on wrong insertion, sensitive-field suggestion, unreliable Tab, mock fallback, or manual model setup.

## P2 - Architecture

- [ ] Extract `SuggestionOrchestrator` from `AppDelegate`.
- [ ] Extract `TraceLogger` as an actor.
- [ ] Extract `RedactionLayer` as an actor.
- [ ] Extract `AcceptanceSurvivalChecker` as an app-owned actor around the pure classifier.
- [ ] Extract `AnnoyanceSuppressor` as an actor.
- [ ] Extract `LocalReportExporter`.
- [ ] Keep core logic AppKit-free.
- [ ] Keep AX and AppKit adapters thin.
- [ ] Add schema migration tests before changing trace storage format.
- [ ] Keep raw dogfood diagnostics separate from beta/customer telemetry.

## P2 - Docs And Product Surface

- [ ] Update `eval-and-tracing.md` so accepted-and-kept is the headline metric.
- [ ] Update `private-beta-plan.md` with the 10-day protocol.
- [ ] Update `compatibility-matrix.md` with support gates and caveats.
- [ ] Update `implementation-plan.md` with the redacted telemetry architecture.
- [ ] Update README model/runtime language so it matches Qwen3.5 and current packaging.
- [ ] Document the exact privacy promise in plain language.
- [ ] Document how to disable an app and delete traces.
- [ ] Add a beta-readiness checklist that must pass before inviting testers.
- [ ] Keep this repo framed as an experiment, not a committed Transcripted feature.
