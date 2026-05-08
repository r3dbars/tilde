# Overall Excellence Scorecard - 2026-05-08

## Source

- Deep Research topic: local-first macOS system-wide autocomplete excellence.
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `64d72cf`

## Executive Summary

The research says this app wins by being fast, quiet, local, narrow, and easy to turn off. The repo already has serious trust machinery: native AppKit app, app-owned MLX runtime, Tab/Esc handling, stale-focus guards, secure-field suppression, redacted local traces, proof scripts, and app compatibility profiles.

The app does not deserve a 100/100 yet. The biggest blockers are proof freshness, prompt-app no-submit proof, default app scope, deterministic snippet fallback, stale public docs, and missing real production-editor proof. The current implementation is strong lab software, not a fully trusted broad system-wide autocomplete product.

## Product Standard

Excellent behavior for this app means:

- Suggestions appear only in intentionally enabled, proven writing contexts.
- Normal typing is never slowed, captured, submitted, or redirected.
- `Tab` accepts only the next word unless full accept is separately proven safe for that surface.
- `Esc`, continued typing, app switch, focus change, caret change, selected text, and secure/private field detection all fail closed.
- Local model setup is owned by the app. Mock fallback never counts as beta-ready.
- Default logs are redacted and local. Raw typed text and screenshots require explicit temporary opt-in.
- App support claims are narrow and backed by fresh same-commit proof.

## Non-Negotiables

Any of these force the relevant category to zero and block beta:

- Wrong-app or wrong-field insertion.
- Prompt/chat submit caused by autocomplete.
- Suggestions in secure, password, token, payment, search, URL, address, or private fields.
- Raw typed text, prompts, screenshots, accepted text, URLs, document names, recipients, or subject lines stored or uploaded by default.
- Cloud inference enabled by default.
- Mock runtime represented as production or beta-ready.
- Normal typing lag caused by polling, event taps, model work, trace writes, or screenshots.
- Stale suggestion accepted after focus, field, selected text, before-text, or after-text changed.
- Clipboard corruption or hidden clipboard fallback.
- No pause, app-disable, trace-delete, or local-data-delete control.
- Broad app compatibility claimed without current same-commit proof.
- Ghost text displayed in the wrong window, wrong monitor, or detached whole-editor anchor.

## Current App Assessment

This is a well-built lab app with many right primitives. The core policies are better than most prototypes: `SuggestionAcceptanceGuard`, `CompletionActivationPolicy`, `KeyboardEventTapConsumptionPolicy`, `TypingBurstPolicy`, `CompletionConfidencePolicy`, `AnnoyanceSuppressor`, `TracePrivacyPolicy`, `RuntimeBootstrapPlan`, and the compatibility profiles all show a conservative trust posture.

The weak part is not code volume. It is proof and scope. `./script/check_score_targets.sh`, `./script/manual_smoke_status.sh --strict`, `./script/check_visual_placement_evidence.sh --require-all`, and `./script/check_proof_manifest.sh --require-all` all fail at this commit.

Pass 1 fixed the biggest automatable scope gap: startup selection now defaults all suggestion-capable profiles off on fresh install, while `AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS` can enable only the target app for proof launches. README runtime/scope copy now matches the current Qwen3.5 4B MLX, app-owned, mock-not-beta-ready posture.

Pass 2 added durable exact-suggestion suppression. A user can block the current visible suggestion from the menu, the app suppresses future matching fast-word/model suggestions before presentation, and the persisted blocklist stores only app/mode-scoped HMAC fingerprints plus shape metadata. Deleting local privacy logs now clears this blocklist too.

Pass 3 added the safe core foundation for deterministic snippets/templates: explicit `;trigger` matching, per-app allowlisting, replacement safety checks, longest-trigger selection, and shape-only trace metadata. It is intentionally not wired into live insertion yet because replacing the trigger before the caret needs fresh app-specific proof.

Pass 4 repaired the live proof harness: `script/build_and_run.sh` no longer calls removed launch helpers, `script/real_app_smoke.sh` can set disposable TextEdit setup text by document path, and the default TextEdit smoke recorded a fresh strict-visual pass. The score does not move because committing the harness makes that proof row stale relative to `HEAD`, and concurrent Codex worktrees repeatedly launched AutocompleteLab during multiline/Chrome proof attempts.

Pass 5 added a shared UI proof lock used by `script/real_app_smoke.sh` and `script/build_and_run.sh`. New proof runs from this branch now fail closed if another local proof/build launch owns the macOS UI lane. This does not raise the score by itself because older worktrees still need to pick up the lock before a clean full proof sweep can count.

## Score

Starting score: 76/100

Current score after pass 5: 83/100

This is a strict product score, not an implementation-depth score. The score is still capped by stale/manual proof, prompt-app no-submit proof, live snippet insertion proof, and the need for a quiet single-owner proof lane.

## Score Breakdown

### Perceived Latency

- Weight: 20
- Current score: 15/20
- Why this score: The app has event-tap pass-through, AX polling backoff, runtime readiness gating, model latency reports, and typing soak scripts. Current strict proof still flags normal typing and latency lanes as not complete.
- Evidence found in repo: `FocusedTextPollingBackoffPolicy`, `FocusedTextAXHealthPolicy`, `TypingBurstPolicy`, `script/check_typing_performance_log.sh`, `script/model_latency_report.py`, `script/typing_performance_soak.sh`, `docs/product/deep-dive-scorecard-2026-05-06.md`.
- Missing evidence: Fresh same-commit long-run proof showing p95/p99 key handling and focused-text AX warning lanes stay calm.
- What would make it 100/100: Current marked trace plus soak proof for each supported app class, with median/p95 first-visible latency below target and zero normal typing lag.

### Acceptance Ergonomics

- Weight: 15
- Current score: 13/15
- Why this score: `Tab` next-word accept, full visible accept, and `Esc` dismiss are implemented and tested. Prompt apps correctly disable full accept, but one-word no-submit proof is still pending for Codex, Claude Code, and Claude desktop.
- Evidence found in repo: `KeyboardEventTapConsumptionPolicy`, `KeyboardEventTap`, `SuggestionSession`, `AcceptedTextSafetyPolicy`, `AppDelegate.handleAutocompleteKey`, `Tests/AutocompleteLabCoreTests/SuggestionSessionTests.swift`, `Tests/AutocompleteLabCoreTests/KeyboardEventTapConsumptionPolicyTests.swift`, `docs/product/manual-smoke-checklist.md`.
- Missing evidence: Fresh same-slice prompt-app no-submit proof and full-accept no-submit proof before broad full accept.
- What would make it 100/100: Every enabled surface proves `Tab`, full accept where allowed, `Esc`, continued typing, and app switch behavior with fresh traces.

### Suggestion Precision And Hit Rate

- Weight: 15
- Current score: 10/15
- Why this score: Output cleaning, confidence gating, ranking, accepted-and-kept learning, and repetition suppression exist. The repo still lacks enough fresh real-model, real-app traces proving sparse suggestions are accepted and kept.
- Evidence found in repo: `CompletionPromptBuilder`, `CompletionOutputCleaner`, `CompletionCandidateRanker`, `CompletionConfidencePolicy`, `DisplayScorePolicy`, `AcceptedAndKeptLearning`, `SuggestionRepetitionSuppressor`, `script/check_quality_eval.sh`.
- Missing evidence: Current accepted-and-kept score by app/mode, real model quality slices, and rejection analysis for prompt apps and production editors.
- What would make it 100/100: Sparse suggestions with strong accepted-and-kept rates by surface, no embarrassing assistant/meta output, and fresh quality evals tied to the current model.

### Intrusiveness Control

- Weight: 10
- Current score: 10/10
- Why this score: Pause, app disable, quiet current field, Esc suppression, typed-over suppression, typing-burst suppression, fresh-install default-off, proof-launch temporary enablement, and a menu-level exact "never suggest this again" control are now implemented.
- Evidence found in repo: `SuggestionControlPolicy`, `DisabledAppSelection`, `AnnoyanceSuppressor`, `SuggestionRepetitionSuppressor`, `SuppressedSuggestionStore`, `SuppressedSuggestionFileStore`, `AppDelegate.togglePauseSuggestions`, `AppDelegate.toggleCurrentApp`, `AppDelegate.suppressCurrentField`, `AppDelegate.neverSuggestCurrentSuggestion`.
- Missing evidence: UI/manual proof that non-technical users understand the blocked-by-default state and only enable intended apps.
- What would make it 100/100: Fresh install starts safe, each app must be deliberately enabled, and user-driven pause/disable/delete controls are proven in UI and traces.

### Privacy And Trust Clarity

- Weight: 15
- Current score: 14/15
- Why this score: Default traces are redacted and local, raw text and screenshots are opt-in, trace deletion exists, runtime is local-first, and README now avoids broad "everywhere" and stale Gemma-first claims.
- Evidence found in repo: `TracePrivacyPolicy`, `RawAutocompleteTraceLog`, `TracePrivacySecretStore`, `DiagnosticsMetadataRedactor`, `docs/product/privacy-and-controls.md`, `script/delete_local_traces.sh`, `docs/research/runtime-options.md`.
- Missing evidence: Settings/onboarding copy still needs a fresh product pass against the final beta flow.
- What would make it 100/100: All user-facing docs and settings copy match the implemented privacy/runtime boundaries and pass proof checks.

### Failure Containment

- Weight: 10
- Current score: 10/10
- Why this score: Bad outcomes feed quiet modes, repeated misses suppress recurring suggestions, secure/search/form/url fields block before display, insertion failures can suppress, severe events are tracked, and exact user-blocked suggestions now persist by app/mode-scoped HMAC fingerprint instead of raw text.
- Evidence found in repo: `AnnoyanceSuppressor`, `SuggestionRepetitionSuppressor`, `SuppressedSuggestionStore`, `SuppressedSuggestionFileStore`, `TracePrivacyFingerprint.textToken`, `CompletionActivationPolicy`, `AXFieldClassifier`, `InsertionVerification`, `InsertionRetryPolicy`, `AutocompleteTraceAnalyzer`, `Tests/AutocompleteLabCoreTests/SuppressedSuggestionStoreTests.swift`, `Tests/AutocompleteLabAppTests/SuppressedSuggestionFileStoreTests.swift`.
- Missing evidence: Personal dictionary/protected phrases, deterministic snippet fallback, and fresh severe-failure zero proof.
- What would make it 100/100: A bad suggestion can be dismissed once, suppressed forever, blocked by phrase/pattern/app, and audited without raw text.

### Scope Control And App Compatibility

- Weight: 5
- Current score: 4/5
- Why this score: The compatibility profile store is conservative, denylisted apps include terminals/password managers/system settings/many code editors, and fresh installs now default suggestion-capable profiles off. Proof gates still fail.
- Evidence found in repo: `CompatibilityProfileStore.mvp`, `CompatibilitySupportEvaluator`, `docs/product/compatibility-matrix.md`, `docs/product/app-proof-matrix.md`, `docs/product/proof-manifest.json`.
- Missing evidence: Fresh proof for all enabled app surfaces, real prompt-app no-submit proof, and production Monaco/ProseMirror proof beyond Chrome fixtures.
- What would make it 100/100: Unknown apps off, suggestion-capable apps default blocked until enabled, and every support claim backed by fresh screenshot + insertion + no-submit proof where applicable.

### Deterministic Fallback And Templates

- Weight: 5
- Current score: 3/5
- Why this score: Deterministic mock/local completion, recent-word memory, and a safe core snippet matcher now exist. The snippet path supports explicit triggers, per-app allowlisting, replacement safety rules, and shape-only metadata, but it is not wired into live trigger replacement or UI yet.
- Evidence found in repo: `MockCompletionEngine`, `LocalCompletionEngine`, `RecentWordMemory`, `WordCompletionCandidateRanker`, `SnippetTemplateMatcher`, `Tests/AutocompleteLabCoreTests/SnippetTemplateMatcherTests.swift`.
- Missing evidence: User-facing snippet management, live trigger replacement proof, protected phrases, searchable snippet recall, and tests that snippet insertion works in real apps without probabilistic model behavior.
- What would make it 100/100: Exact local snippets/templates alongside AI, with per-app enablement and no raw-text logging.

### Resource Efficiency And Native Feel

- Weight: 5
- Current score: 4/5
- Why this score: Native menu bar app, AppKit overlay, app-owned model runtime, diagnostics, and Settings are present. `Package.swift` currently targets macOS 26 while runtime docs say macOS 14 is the intended lower beta target.
- Evidence found in repo: `Package.swift`, `AppDelegate`, `SuggestionPanelController`, `SettingsWindowController`, `MLXModelRuntime`, `docs/research/runtime-options.md`.
- Missing evidence: Build/runtime proof for the documented macOS target and current packaging after any code changes.
- What would make it 100/100: Lightweight native bundle, verified on target macOS/hardware, with no external runtime and clean package checks.

## 0/100 Definition

This area is 0/100 if autocomplete can insert into the wrong field, submit a prompt/chat message, show in secure/private fields, store or upload typed text by default, corrupt the clipboard, capture `Tab` without a visible suggestion, or claim broad compatibility without proof.

## 50/100 Definition

A 50/100 app has a visible autocomplete prototype with local-ish generation, Tab/Esc basics, and some tests, but it still relies on broad app assumptions, stale proof, permissive defaults, or manual trust.

## 80/100 Definition

An 80/100 app is private-beta credible for a narrow allowlist. It defaults safe, proves TextEdit/Notes/Chrome fixtures/Obsidian with current screenshots and verified accepts, blocks prompt-app full accept, keeps traces redacted, and fails beta readiness when model/proof is missing.

## 100/100 Definition

A 100/100 app is boringly trusted. Every supported surface has fresh same-commit proof, every high-risk surface is off or no-submit-proven, latency is proven, app scope is explicit, deletion/pause/disable controls are obvious, local runtime setup is in-app, and deterministic snippets/templates provide safe exact fallback.

## Failure Modes

1. Wrong-app or wrong-field insertion.
2. Prompt/chat submit from `Tab`, full accept, Enter-like generated text, or focus confusion.
3. Suggestion in secure, password, token, payment, login, URL, search, address, terminal, password-manager, or private field.
4. Stale suggestion accepted after app, field, selection, before-text, after-text, caret, or runtime state changed.
5. Raw typed text, screenshots, prompts, accepted text, or document identifiers stored without explicit opt-in.
6. Normal typing lag from event tap, Accessibility polling, model generation, trace writes, or screenshot capture.
7. Mock runtime fallback counted as beta-ready.
8. Ghost text drawn in wrong window, wrong display, clipped inline space, or detached whole-editor anchor.
9. Repeated bad suggestions with no durable suppression.
10. Broad support copy that makes users trust unproven apps.

## Evidence Requirements

- `swift test` passes.
- Targeted tests pass for any changed policy.
- `./script/smoke_test.sh` passes.
- `./script/check_test_coverage_manifest.sh` passes.
- `./script/check_trace_eval_self_test.sh` passes.
- `./script/check_quality_eval.sh` passes when suggestion quality changes.
- `./script/model_latency_report.py --default-model-proof` passes after a model run.
- `./script/check_visual_placement_evidence.sh --require-all` passes before any 100/100 visual/support claim.
- `./script/check_proof_manifest.sh --require-all` passes before any 100/100 proof claim.
- `./script/manual_smoke_status.sh --strict` passes before private beta.
- Prompt apps require screenshot-backed one-word no-submit proof before enablement and separate full-accept no-submit proof before full accept.
- Real app support requires fresh same-commit trace slices, not stale historical rows.

## Implementation Queue

### 1. Wire Default-Off App Scope And Temporary Proof Enablement

- Objective: Make fresh installs block all suggestion-capable profiles until the user or proof harness explicitly enables the target app.
- Files likely involved: `DisabledAppSelection.swift`, `AppDelegate.swift`, `DisabledAppSelectionTests.swift`, docs.
- Tests to add/update: startup selection tests for no persisted value, persisted value, and temporary enablement.
- Proof required: targeted Swift tests and app proof docs explaining the default.
- Risk level: medium.
- Expected score impact: +4.

### 2. Correct Stale Runtime And Scope Copy

- Objective: Make README/docs match current Qwen3.5 4B MLX path, narrow app support, and mock fallback stop condition.
- Files likely involved: `README.md`, this scorecard, maybe `compatibility-matrix.md`.
- Tests to add/update: docs gates if available; otherwise `git diff --check`.
- Proof required: direct doc/code consistency review.
- Risk level: low.
- Expected score impact: +2.

### 3. Reconcile Proof Matrix With Current Manifest Or Keep It Explicitly Pending

- Objective: Stop unreferenced screenshots and stale rows from making proof gates confusing.
- Files likely involved: `docs/product/app-proof-matrix.md`, `docs/product/deep-dive-scorecard-2026-05-06.md`, `docs/product/proof-manifest.json`.
- Tests to add/update: proof/visual scripts.
- Proof required: `check_visual_placement_evidence` and `check_proof_manifest`.
- Risk level: medium.
- Expected score impact: +3 to +8, depending on whether proof is genuinely current.

### 4. Add Explicit Never-Again / Protected Phrase Control

- Objective: Give users a durable way to suppress an exact bad suggestion without storing raw text.
- Files likely involved: `SuppressedSuggestionStore`, `SuppressedSuggestionFileStore`, `TracePrivacyFingerprint`, `AppDelegate`.
- Tests to add/update: `SuppressedSuggestionStoreTests`, `SuppressedSuggestionFileStoreTests`, `TracePrivacyFingerprintTests`.
- Proof required: unit tests and redaction review.
- Risk level: medium.
- Status: Done in pass 2 for exact suggestions. Protected phrase/personal dictionary controls remain separate.
- Expected score impact: +2.

### 5. Add Deterministic Snippet Fallback

- Objective: Add exact local snippets/templates as an explicit fallback path, separate from prediction.
- Files likely involved: `SnippetTemplateMatcher`, future settings or command panel, future insertion plan.
- Tests to add/update: `SnippetTemplateMatcherTests`; future tests for app-side trigger replacement and no raw trace storage.
- Proof required: unit tests and manual TextEdit proof.
- Risk level: high.
- Status: Core matcher done in pass 3. Live insertion intentionally remains pending until app-specific proof can verify trigger replacement.
- Expected score impact: +1 now, up to +4 after live proof.

### 6. Fresh Manual Proof Sweep

- Objective: Close all manual/screenshot/no-submit proof gaps on current commit.
- Files likely involved: docs only, screenshots, proof manifest, manual smoke logs.
- Tests to add/update: none unless scripts drift.
- Proof required: `manual_smoke_status --strict`, `check_visual_placement_evidence --require-all`, `check_proof_manifest --require-all`.
- Risk level: high because it requires live app/manual confirmation.
- Expected score impact: +8 to +15.

### 7. Serialize UI Proof Runs

- Objective: Prevent multiple Codex/worktree smoke sessions from racing the same macOS UI, launch environment, and AutocompleteLab app instance.
- Files likely involved: `script/real_app_smoke.sh`, `script/build_and_run.sh`, `script/ui_proof_lock.sh`.
- Tests to add/update: shell syntax tests plus `script/ui_proof_lock_self_test.sh`, which proves a second proof run exits before launching or changing `launchctl` app enablement.
- Proof required: one clean TextEdit smoke and one Chrome fixture smoke with no competing `app-proof-mode-started` rows from other worktrees.
- Risk level: medium.
- Status: Done for this branch; older/local worktrees still need this branch's scripts before the lock can protect every Codex instance.
- Expected score impact: +1 to +4 by making current proof attainable and trustworthy.

## Codex Execution Goal

Improve Overall Excellence from 76/100 by closing automatable trust gaps first: default-off app scope, narrow runtime/scope copy, durable exact-suggestion suppression, then deterministic snippet/template fallback. Keep proof scores honest and do not claim 100/100 until strict proof gates pass.

## Stop Conditions

- Overall score reaches 100/100 with passing proof gates; or
- all automatable code/docs/test improvements are complete and remaining gaps require manual live app proof; or
- a hard external blocker prevents model, macOS Accessibility, or prompt-app proof from running safely; or
- remaining improvements require unsafe broad app support, cloud default inference, raw text storage, or hidden screenshot capture.

## Remaining Gaps

- Fresh same-commit proof is missing for many surfaces.
- Claude Code proof is pending.
- Codex and Claude desktop need same-slice one-word no-submit proof.
- Prompt-app full accept must stay disabled until separately proven.
- Chrome fixture proof does not equal broad website proof.
- Real Monaco/ProseMirror proof is missing beyond local fixtures.
- Live deterministic snippet/template insertion is missing; only the safe core matcher exists.
- Protected phrase/personal dictionary controls are missing beyond exact visible-suggestion suppression.
- Some score/proof docs are stale relative to `proof-manifest.json`.
- Current live proof attempts are blocked by concurrent Codex worktrees launching AutocompleteLab and changing proof-mode app enablement mid-run.
