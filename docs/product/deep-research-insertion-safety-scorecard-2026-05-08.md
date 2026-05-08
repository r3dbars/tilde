# Insertion Safety Scorecard - 2026-05-08

## Source

- Deep Research topic: Insertion Safety Rubric for System-Wide Autocomplete
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14d` (`origin/main`)

## Executive Summary

The research says this app earns trust only when it can prove an accepted suggestion is still going into the same editable target, at the same caret, in a non-sensitive field, without submitting, replacing, duplicating, stealing focus, or damaging the clipboard.

This repo is already much stronger than a blind prototype. It has an explicit app profile store, denylisted high-risk apps, secure-field detection, selected-text blocking, prompt-app fingerprinting, acceptance snapshots, insertion verification, trace events, proof manifests, and many tests.

The strict read is still not beta-safe for insertion safety. Some profiles still allow generic key-event or AX insertion in prompt/browser/custom-editor surfaces without the app-specific bridge the research asks for. The target fingerprint does not yet include a full window/caret/text-hash revision, proof manifests are stale for the current commit, and post-write verification can fail too quietly when the focused target disappears or changes.

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

The gaps are material:

- Prompt apps (`com.openai.codex`, `com.anthropic.claude-code`, `com.anthropic.claudefordesktop`) are still suggestion-capable even though the research says generic prompt insertion should be blocked without an app-specific no-submit bridge.
- Chrome uses generic key events as its primary insertion mode for browser surfaces, while the research warns that browser textareas, contenteditable, and custom editors need surface-specific proof.
- The acceptance fingerprint lacks an explicit window identifier, role/subrole, caret bounds, text hash, and monotonic revision.
- Post-write verification uses only text-before-cursor in the live scheduler even though the verifier can check text-after-cursor.
- Post-write focus/field mismatch can return without recording an insertion failure.
- Clipboard fallback exists as code, and its restore condition is too weak to count as transaction-safe, even though it is off by default.
- Existing docs contain stale proof claims. Strict scoring must prefer live scripts and current-commit proof over older scorecards.

## Score

Starting score: 67/100

Current score after implementation pass: 75/100

Overall score: 75/100

## Score Breakdown

### Target lock and stale-suggestion prevention

- Weight: 25
- Current score: 19/25
- Why this score: Strong pre-accept snapshot checks exist, and post-write missing-context/target-mismatch now records an insertion failure instead of disappearing. The fingerprint is still not yet the full transactional fingerprint from the research and current proof is stale.
- Evidence found in repo: `SuggestionAcceptanceGuard`, `SuggestionAcceptanceSnapshot`, `FocusedFieldIdentity`, `AppDelegate.currentSuggestionAcceptanceDecision()`, `AppDelegate.scheduleInsertionVerification()`, `AppDelegate.recordInsertionVerificationFailure()`, `AppDelegate.observePassthroughTypingKeyDown()`.
- Missing evidence: Window identity, role/subrole match, caret bounds match, surrounding-text hash, monotonic revision, current proof slices, and proof that post-write focus mismatch is always recorded.
- What would make it 100/100: Every suggestion carries and rechecks a complete target fingerprint before and after insertion, with current proof artifacts.

### Sensitive-context blocking

- Weight: 20
- Current score: 16/20
- Why this score: Secure subroles, protected content, and password/token-like fingerprints are blocked. Password managers and Terminal are denylisted. Browser login/payment/OTP proof is still mostly heuristic.
- Evidence found in repo: `SensitiveTextFieldPolicy`, `AXFieldClassifier`, `AccessibilityClient.isSensitiveTextElement`, `CompatibilityProfileStore.defaultDenylist`, `SensitiveTextFieldPolicyTests`, `AXFieldClassifierTests`.
- Missing evidence: Real browser password/OTP/payment proof and proof that uncertain browser sensitive semantics always fail closed.
- What would make it 100/100: Current real-app blocked-context proof for native secure fields, browser passwords, OTPs, payment fields, password managers, and private prompt/search fields.

### No-submit and no-overwrite guarantees

- Weight: 20
- Current score: 16/20
- Why this score: Return is not an accept key, selected text blocks, prompt apps are now diagnostics-only until no-submit proof exists, and unhandled consumed accept keys are dropped instead of replayed into the target app. Browser form submit proof is still mostly fixture-based.
- Evidence found in repo: `KeyboardActionRouter`, `KeyboardEventTapConsumptionPolicy.shouldReplayUnhandledConsumedKey`, `AcceptedTextSafetyPolicy`, `SuggestionAcceptanceGuard`, `CompatibilityProfileStore.mvp`, `PromptEditorFingerprintPolicy`, `AppDelegate.handleAutocompleteKey`.
- Missing evidence: Field-level Mail body-only routing, production browser form submit proof beyond local fixtures, and manual prompt-app proof before any prompt insertion is restored.
- What would make it 100/100: Prompt/chat and Mail non-body fields stay insertion-disabled until app-specific no-submit proof exists.

### Write-path correctness and idempotence

- Weight: 15
- Current score: 10/15
- Why this score: The verifier catches many bad deltas, now checks after-cursor drift during live verification, and records missing-context/target-mismatch as insertion failures. It is still not a full transaction with caret and focus proof.
- Evidence found in repo: `InsertionEngine`, `InsertionVerification`, `InsertionRetryPolicy`, `AppDelegate.scheduleInsertionVerification`, `AppDelegate.recordInsertionVerificationFailure`, `InsertionVerificationTests`.
- Missing evidence: Exact post-write focus and field mismatch failure recording, text-after-cursor verification in the live scheduler, explicit exact-once idempotence token, and undo-as-one-edit proof per surface.
- What would make it 100/100: Every insertion attempt produces a verified success or a structured failure with target, delta, caret, duplicate, and focus evidence.

### Clipboard and event-tap hygiene

- Weight: 10
- Current score: 6/10
- Why this score: Clipboard fallback is off by default and event-tap latency/disable handling is well tested. The fallback implementation itself is not transaction-safe enough to claim credit if enabled.
- Evidence found in repo: `InsertionEngine.clipboardFallbackEnabled`, `InsertionModePlan`, `KeyboardEventTap`, `KeyboardEventTapConsumptionPolicy`, typing-performance scripts.
- Missing evidence: Lossless pasteboard representation snapshot/restore tests, strict `changeCount` race protection, and a product gate that keeps fallback out of beta.
- What would make it 100/100: Clipboard fallback removed or guarded by a fully tested pasteboard transaction object.

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
- `swift test` passes: 737 tests.
- `git diff --check` and `./script/check_test_coverage_manifest.sh` pass.

Current blockers from live proof scripts:

- `./script/check_proof_manifest.sh` fails because Obsidian and Notes screenshots are not referenced by the scorecard.
- `./script/check_visual_placement_evidence.sh --require-all` fails with pending/stale visual proof rows and unreferenced Notes/Obsidian screenshots.
- `./script/manual_smoke_status.sh --strict` fails because 16 target app passes need current commit/archive proof.
- `./script/beta_readiness.sh --check-only` fails on runtime diagnostics, manual proof, visual proof, and missing private beta archive.

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

### 4. Add a full target fingerprint object

- Objective: Extend the suggestion snapshot with role, subrole, caret rect, window rect/hash, text hash, and revision.
- Files likely involved: `FocusedFieldIdentity.swift`, `SuggestionAcceptanceGuard.swift`, `AppDelegate.swift`, tests.
- Tests to add/update: Fingerprint mismatch tests for role, subrole, window/caret geometry, text hash, and revision.
- Proof required: Full Swift test plus smoke test.
- Risk level: High.
- Expected score impact: +6 to +10.

### 5. Separate Chrome surface policy

- Objective: Stop treating all Chrome editable surfaces as one insertion safety class.
- Files likely involved: compatibility profiles, field classification, Chrome fixture scripts, proof manifest.
- Tests to add/update: Textarea allowed, contenteditable/custom editors blocked or bridge-only unless proof says otherwise.
- Proof required: Chrome fixture and production-site proof slices.
- Risk level: High.
- Expected score impact: +5 to +8.

## Codex Execution Goal

Make the app fail closed for high-risk prompt insertion and tighten post-write verification evidence. Start by disabling generic insertion for Codex, Claude Code, and Claude desktop until no-submit proof exists, then ensure insertion verification records wrong-target and after-cursor failures instead of letting them disappear.

## Stop Conditions

- Prompt app profiles no longer allow suggestion insertion by default.
- Tests prove the prompt app profiles are diagnostics-only.
- Accepted-text safety tests no longer depend on a real prompt app being insertion-enabled.
- Live post-write verification carries enough baseline text to catch after-cursor drift.
- Targeted tests pass.
- Full `swift test` passes, or any failure is confirmed out of scope and documented.
- Remaining work requires manual proof in real apps or a larger target-fingerprint refactor.

## Remaining Gaps

- Full transactional fingerprint is not implemented yet.
- Chrome still needs per-surface policy beyond app-level bundle ID.
- Clipboard fallback should be removed or isolated behind a tested transaction object before beta.
- Manual real-app proof is still needed for prompt/chat apps if support is ever restored.
- A real app-specific bridge would be needed for high-confidence browser rich editors, Obsidian, and prompt/chat apps.
