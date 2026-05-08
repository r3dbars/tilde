# Insertion Safety Scorecard - 2026-05-08

## Source

- Deep Research topic: Insertion Safety Rubric for System-Wide Autocomplete
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14d` (`origin/main`)

## Executive Summary

The research says this app earns trust only when it can prove an accepted suggestion is still going into the same editable target, at the same caret, in a non-sensitive field, without submitting, replacing, duplicating, stealing focus, or damaging the clipboard.

This repo is already much stronger than a blind prototype. It has an explicit app profile store, denylisted high-risk apps, secure-field detection, selected-text blocking, prompt-app fingerprinting, acceptance snapshots, insertion verification, trace events, proof manifests, and many tests.

The strict read is still not beta-safe for insertion safety because proof is stale or missing for several real app surfaces. The implementation is safer after the current hardening pass: prompt apps are diagnostics-only, generic unhinted browser web areas fail closed, accept-time snapshots include a target fingerprint, post-write verification checks target scope, and clipboard insertion is hard-disabled. The remaining gap is mostly real current-build proof plus a few deeper transaction guarantees.

## Product Standard

Excellent behavior for this app means:

- Suggestions appear only in explicitly profiled writing surfaces.
- Accepting text requires a fresh target match at accept time.
- The target match includes app, process, element or stable bounds, selected range, caret/cursor text, and sensitive-field state.
- Non-empty selections block insertion.
- Secure/password/OTP/payment/token-like fields block before text is read or inserted.
- Prompt/chat, terminal, mail-recipient, browser login/payment/search, password manager, and unsupported custom editor contexts default to no insertion.
- Generic Return is never an accept key.
- Generic Tab is allowed only for a proven app/path.
- Clipboard fallback is off by default and cannot count as beta-ready until it is transaction-safe.
- Post-write verification records every mismatch as evidence, not a silent no-op.

## Non-Negotiables

Any of these should block beta for the affected app/path:

- Wrong-field insertion.
- Accidental chat/prompt/form/email/shell submit.
- Insertion into secure, password, OTP, payment, token, or password-manager fields.
- Replacement of selected text without an explicit replace mode.
- Clipboard mutation from fallback insertion.
- Duplicate insertion from one accept action.
- Stale suggestion accepted after focus, caret, selection, text, or window changed.
- Focus steal by the panel or insertion path.
- Mock runtime presented as beta-ready.
- Broad app compatibility claims without current app/path proof.

## Current App Assessment

The app has a serious trust-first shape:

- `CompatibilityProfileStore.mvp` keeps support explicit and denylists Terminal, password managers, developer IDEs, and system settings.
- `SensitiveTextFieldPolicy` blocks secure subroles and password/token-like fingerprints.
- `SuggestionAcceptanceGuard` compares app, PID, field identity, selected-text length, and before/after cursor text before accept.
- `AcceptedTextSafetyPolicy` blocks empty text, line breaks, tabs, control characters, and multiword full accept on profiles where full accept is disabled.
- `InsertionVerification` detects exact insert, unchanged insert, partial insert, literal Tab, duplicate text, wrong-location insert, and unexpected mutation.
- `KeyboardEventTap` consumes accept keys only while a visible suggestion exists and fails closed when the system disables the tap.
- `docs/product/proof-manifest.json` tracks proof surfaces and gaps, but its `sourceCommit` is `409f75b...`, not the inspected `771f14d`.

The latest hardening pass fixed several material gaps:

- Prompt apps (`com.openai.codex`, `com.anthropic.claude-code`, `com.anthropic.claudefordesktop`) are diagnostics-only until same-slice one-word no-submit proof exists.
- Accept-time snapshots now carry `FocusedTargetFingerprint` with role, subrole, element/window/caret bounds, normalized element fingerprint, and hashed surrounding-text revision.
- Post-write verification now compares a post-insertion target scope instead of relying only on `FocusedFieldIdentity`.
- Generic `AXWebArea` surfaces without a compose hint now classify as `unprovenSurface` and suppress suggestions.
- Clipboard insertion fallback is hard-disabled in `InsertionEngine`, no default compatibility profile uses clipboard fallback acceptance, and beta readiness has a clipboard fallback gate.

The remaining gaps are material but narrower:

- Current-build manual/visual proof is still missing for prompt apps and stale or partial for some Chrome proof surfaces.
- The acceptance fingerprint still does not include a stable OS window ID or explicit monotonic field revision from the target app.
- There is no exact-once insertion transaction token or undo-as-one-edit proof per surface.
- Existing older scorecards still contain non-100 scores until real proof catches up.

## Score

Starting score: 67/100

Current score after implementation pass: 86/100

Overall score: 86/100

## Score Breakdown

### Target lock and stale-suggestion prevention

- Weight: 25
- Current score: 22/25
- Why this score: Strong pre-accept snapshot checks exist, accept-time target fingerprints now cover role/subrole, normalized element fingerprint, element/window/caret bounds, and hashed surrounding-text revision, and post-write verification now checks target scope. The remaining gap is stable OS window identity, a monotonic target revision, and current proof.
- Evidence found in repo: `SuggestionAcceptanceGuard`, `SuggestionAcceptanceSnapshot.targetFingerprint`, `FocusedTargetFingerprint`, `FocusedTextRevision`, `FocusedFieldIdentity`, `AppDelegate.currentSuggestionAcceptanceDecision()`, `AppDelegate.scheduleInsertionVerification()`, `AppDelegate.recordInsertionVerificationFailure()`, `FocusedFieldIdentityPolicyTests`, `SuggestionAcceptanceGuardTests`.
- Missing evidence: Stable window ID, monotonic field revision, exact current proof slices, and live proof that focus/caret/window mismatch is always blocked before accept.
- What would make it 100/100: Every suggestion carries and rechecks a complete target fingerprint before and after insertion, with current proof artifacts.

### Sensitive-context blocking

- Weight: 20
- Current score: 17/20
- Why this score: Secure subroles, protected content, password/token-like fingerprints, unhinted browser web areas, password managers, and Terminal are blocked or suppressed. Browser login/payment/OTP proof is still mostly heuristic.
- Evidence found in repo: `SensitiveTextFieldPolicy`, `AXFieldClassifier`, `AccessibilityClient.isSensitiveTextElement`, `CompatibilityProfileStore.defaultDenylist`, `SensitiveTextFieldPolicyTests`, `AXFieldClassifierTests`.
- Missing evidence: Real browser password/OTP/payment proof and proof that uncertain browser sensitive semantics always fail closed.
- What would make it 100/100: Current real-app blocked-context proof for native secure fields, browser passwords, OTPs, payment fields, password managers, and private prompt/search fields.

### No-submit and no-overwrite guarantees

- Weight: 20
- Current score: 17/20
- Why this score: Return is not an accept key, selected text blocks, prompt apps are now diagnostics-only until no-submit proof exists, and unhandled consumed accept keys are dropped instead of replayed into the target app. Unhinted web areas suppress instead of relying on generic browser insertion. Browser form submit proof is still mostly fixture-based.
- Evidence found in repo: `KeyboardActionRouter`, `KeyboardEventTapConsumptionPolicy.shouldReplayUnhandledConsumedKey`, `AcceptedTextSafetyPolicy`, `SuggestionAcceptanceGuard`, `CompatibilityProfileStore.mvp`, `PromptEditorFingerprintPolicy`, `AppDelegate.handleAutocompleteKey`.
- Missing evidence: Field-level Mail body-only routing, production browser form submit proof beyond local fixtures, and manual prompt-app proof before any prompt insertion is restored.
- What would make it 100/100: Prompt/chat and Mail non-body fields stay insertion-disabled until app-specific no-submit proof exists.

### Write-path correctness and idempotence

- Weight: 15
- Current score: 12/15
- Why this score: The verifier catches many bad deltas, checks after-cursor drift during live verification, records missing-context/target-mismatch failures, and now compares a post-insertion target fingerprint scope. It is still not a full exact-once transaction.
- Evidence found in repo: `InsertionEngine`, `InsertionVerification`, `InsertionRetryPolicy`, `AppDelegate.scheduleInsertionVerification`, `AppDelegate.recordInsertionVerificationFailure`, `FocusedTargetFingerprint.postInsertionScope`, `InsertionVerificationTests`.
- Missing evidence: Explicit exact-once idempotence token, stable OS-level window identity, and undo-as-one-edit proof per surface.
- What would make it 100/100: Every insertion attempt produces a verified success or a structured failure with target, delta, caret, duplicate, and focus evidence.

### Clipboard and event-tap hygiene

- Weight: 10
- Current score: 10/10
- Why this score: Clipboard fallback insertion is hard-disabled for beta instead of pretending global pasteboard mutation is transaction-safe. Default app compatibility profiles no longer use clipboard fallback acceptance, and beta readiness checks for unsafe fallback code.
- Evidence found in repo: `InsertionEngine.clipboardFallbackUnavailable`, `AppCompatibilityRegistry.defaultProfiles`, `CompatibilityRouterTests`, `AppCompatibilityProfileTests`, `script/beta_readiness.sh`.
- Missing evidence: None for beta, as long as clipboard insertion remains disabled.
- What would make it 100/100: Keep clipboard insertion disabled unless a future explicit pasteboard transaction is proven separately.

### Tests, telemetry, and proof artifacts

- Weight: 10
- Current score: 8/10
- Why this score: This is one of the repo's strongest areas. There are many unit tests, trace analyzers, smoke scripts, visual screenshots, and a proof manifest. The remaining gap is current proof for high-risk prompt and browser production surfaces.
- Evidence found in repo: `Tests/AutocompleteLabCoreTests`, `Tests/AutocompleteLabAppTests`, `script/check_proof_manifest.sh`, `script/check_trace_eval.sh`, `script/check_visual_placement_evidence.sh`, `script/beta_readiness.sh`, `docs/product/proof-manifest.json`.
- Missing evidence: Current same-slice no-submit proof for Codex, Claude Code, Claude desktop, and production browser editors.
- What would make it 100/100: Release gates fail every unsupported or stale proof row automatically and all shipped app/path rows have current artifacts.

## 0/100 Definition

A blind insertion prototype. It posts keys or uses the clipboard without proving the target, shows in secure or unsupported fields, accepts stale suggestions, can submit or overwrite, and has no trustworthy tests or proof artifacts.

## 50/100 Definition

The demo works in a few editors, but safety is mostly heuristic. It has some secure-field checks and visible suggestions, but target identity, no-submit proof, clipboard safety, and post-write verification are incomplete.

## 80/100 Definition

Private-beta-ready for a narrow allowlist. Unsupported contexts fail closed, TextEdit and a few low-risk surfaces have current proof, prompt/chat and terminal-like contexts are blocked, and every insertion attempt is verified or recorded as a failure.

## 100/100 Definition

Every shipped app/path has a complete transactional fingerprint, preflight and postflight verification, zero catastrophic failures in validation, current proof artifacts, and no generic insertion in prompt/chat/browser-rich/custom-editor surfaces without an app-specific safe bridge.

## Failure Modes

1. Wrong app, window, or field receives accepted text.
2. Prompt/chat/form/email/shell submit is triggered.
3. Secure/password/OTP/payment/token field receives or displays a suggestion.
4. Selected text is replaced unexpectedly.
5. Stale suggestion inserts after text, caret, focus, or window drift.
6. Duplicate text inserts from one accept action.
7. Clipboard fallback corrupts or downgrades pasteboard contents.
8. Synthetic key events recurse through the app's own event tap.
9. Suggestion panel steals focus or remains visible in the wrong window.
10. Mock/runtime fallback makes beta proof look stronger than it is.

## Evidence Requirements

- Unit tests for every acceptance guard block reason.
- Unit tests for sensitive native, browser, OTP, payment, token, and password-manager fields.
- Unit tests for no line-break, no Tab, no control-character, no multiword prompt accept.
- Unit tests for post-write wrong-target, duplicate, wrong-location, text-after-cursor, and focus-mismatch failures.
- Script gate proving clipboard fallback is disabled for beta unless transaction tests pass.
- Manual proof for every supported app/path: screenshot, accept, stale-caret block, selection block, secure block, focus-switch block, and no-submit/no-execute where relevant.
- Trace metrics for wrong insertion, stale insertion, duplicate insertion, accidental submit, selected-text overwrite success, clipboard damage, and focus steal.

## Implementation Queue

Completed in this pass:

- Prompt apps are diagnostics-only until same-slice one-word no-submit proof exists.
- Disabled profiles are blocked by `AcceptedTextSafetyPolicy` even if a call path reaches insertion.
- Blocked/unhandled consumed accept keys are dropped instead of replayed into the target app.
- Live insertion verification now carries `previousTextAfterCursor`.
- Missing-context and target-mismatch verification paths now record `insertionFailed` trace evidence.
- Accept-time target fingerprints now include role/subrole, element/window/caret bounds, normalized element fingerprint, and hashed surrounding-text revision.
- Post-write verification now checks a post-insertion target scope.
- Clipboard insertion fallback is hard-disabled and beta readiness gates it.
- Generic browser `AXWebArea` fields without a compose hint now suppress as unproven surfaces.
- `swift test` passes: 737 tests.
- `git diff --check` and `./script/check_test_coverage_manifest.sh` pass.

Current blockers from live proof scripts:

- `./script/check_proof_manifest.sh --require-all` fails because Chrome text fields, browser editor fixtures, Chrome chat-like composer, Codex, and Claude desktop are still partial, and Claude Code is pending.
- `./script/check_visual_placement_evidence.sh --require-all` fails on Claude Code, Claude desktop, and stale same-slice Codex visual/no-submit proof.
- `./script/manual_smoke_status.sh --strict` fails because 16 target app passes need current commit/archive proof.
- `./script/beta_readiness.sh --check-only` was not completed in this pass because the runtime diagnostics step did not return promptly; prior blockers remain manual proof, visual proof, and missing private beta archive.

### 1. Disable prompt-app insertion until no-submit proof exists

- Objective: Make Codex, Claude Code, and Claude desktop diagnostics-only until same-slice one-word no-submit proof exists.
- Files likely involved: `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`, `Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift`, `README.md`, this scorecard.
- Tests to add/update: Compatibility profile assertions and accepted-text safety tests that use a synthetic prompt-safe profile.
- Proof required: `swift test --filter CompatibilityProfileTests`, `swift test --filter AcceptedTextSafetyPolicyTests`, full `swift test`.
- Risk level: Medium. It reduces product coverage but lowers catastrophic prompt-submit risk.
- Expected score impact: +4 to +6.

### 2. Record post-write wrong-target verification as a failure

- Objective: Ensure post-write missing context or field mismatch records an insertion failure instead of returning quietly.
- Files likely involved: `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift` or a new core policy if extracted.
- Tests to add/update: A pure policy test for post-write verification decisions.
- Proof required: Targeted Swift tests and full `swift test`.
- Risk level: Low to medium.
- Expected score impact: +2 to +4.

### 3. Use text-after-cursor in live insertion verification

- Objective: Pass captured `textAfterCursor` into live post-write verification so selected-text or wrong-location changes are caught.
- Files likely involved: `Sources/AutocompleteLabApp/App/AppDelegate.swift`.
- Tests to add/update: Baseline carries previous after-cursor text; verifier detects after-cursor drift.
- Proof required: Targeted verification tests and full `swift test`.
- Risk level: Low.
- Expected score impact: +1 to +2.

### 4. Add a fuller target fingerprint object

- Objective: Extend the suggestion snapshot with role, subrole, caret rect, window rect/hash, text hash, and revision.
- Files likely involved: `FocusedFieldIdentity.swift`, `SuggestionAcceptanceGuard.swift`, `AppDelegate.swift`, tests.
- Tests to add/update: Fingerprint mismatch tests for role, subrole, window/caret geometry, text hash, and revision.
- Proof required: Full Swift test plus smoke test.
- Risk level: High.
- Expected score impact: +6 to +10.
- Status: Implemented for role/subrole, normalized element fingerprint, element/window/caret bounds, and hashed surrounding-text revision. Still missing stable OS window ID and target-provided monotonic revision.

### 5. Separate Chrome surface policy

- Objective: Stop treating all Chrome editable surfaces as one insertion safety class.
- Files likely involved: compatibility profiles, field classification, Chrome fixture scripts, proof manifest.
- Tests to add/update: Textarea allowed, contenteditable/custom editors blocked or bridge-only unless proof says otherwise.
- Proof required: Chrome fixture and production-site proof slices.
- Risk level: High.
- Expected score impact: +5 to +8.
- Status: Partially implemented. Generic `AXWebArea` with text but no compose hint is now `unprovenSurface`; production Chrome proof is still required before raising compatibility claims.

### 6. Refresh current proof

- Objective: Replace stale/partial proof with current-build manual and visual evidence.
- Files likely involved: `docs/product/manual-smoke-runs.md`, `docs/product/proof-manifest.json`, `docs/product/deep-dive-scorecard-2026-05-06.md`, `docs/product/app-proof-matrix.md`.
- Tests to add/update: No code tests; proof scripts must pass.
- Proof required: `./script/manual_smoke_status.sh --strict`, `./script/check_visual_placement_evidence.sh --require-all`, `./script/check_proof_manifest.sh --require-all`.
- Risk level: High because proof touches real apps.
- Expected score impact: Required for 100/100.
- Status: Blocked on manual/human real-app proof.

## Codex Execution Goal

Keep tightening insertion safety until the only remaining 100/100 blockers are real current-build proof. Code-side priorities are target fingerprinting, no clipboard insertion, conservative browser-surface suppression, and structured failure evidence.

## Stop Conditions

- Prompt app profiles no longer allow suggestion insertion by default.
- Tests prove the prompt app profiles are diagnostics-only.
- Accepted-text safety tests no longer depend on a real prompt app being insertion-enabled.
- Live post-write verification carries enough baseline text to catch after-cursor drift.
- Accept-time target fingerprints block role, bounds, caret, and surrounding-text drift.
- Clipboard insertion fallback is hard-disabled for beta.
- Generic browser web areas without compose hints suppress as unproven.
- Targeted tests pass.
- Full `swift test` passes, or any failure is confirmed out of scope and documented.
- Remaining work requires manual proof in real apps, stable OS window identity, monotonic target revision, or exact-once/undo proof.

## Remaining Gaps

- Stable OS window identity and target-provided monotonic revision are not implemented yet.
- Chrome still needs production proof beyond local fixtures.
- Exact-once insertion transaction and undo-as-one-edit proof are still missing.
- Manual real-app proof is still needed for prompt/chat apps if support is ever restored.
- A real app-specific bridge would be needed for high-confidence browser rich editors, Obsidian, and prompt/chat apps.
