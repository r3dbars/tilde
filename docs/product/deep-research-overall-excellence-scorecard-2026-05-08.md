# Overall Excellence Scorecard - 2026-05-08

## Source

- Deep Research topic: System-Wide Autocomplete Excellence Rubric
- Deep Research file: `/Users/redbars/Downloads/deep-research-report (11).md`
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14dee37a4c8a44d89f1059f8a2aec9ca4e40`

## Executive Summary

The research says this app wins only if it is boringly trustworthy: fast enough to stay out of the user's way, quiet when uncertain, explicit about every insert, local-first by default, and honest about which apps are actually proven.

The repo has serious safety architecture: focused-field identity checks, selected-text blocking, secure-field suppression, redacted tracing, default-off app selection, local model readiness gates, and real smoke/proof scripts. The current score is still capped because strict manual proof is stale or inconsistent across docs, prompt-app no-submit proof is incomplete, no current network-egress proof exists for local-only mode, and the newly wired accepted-survival runtime path still needs fresh real-app trace proof.

## Product Standard

Excellent behavior for this app means:

- Suggestions appear only in a narrow set of proven writing surfaces.
- `Tab` accepts one word only.
- A separate shortcut accepts the full visible suggestion only where full accept is proven safe.
- `Esc`, continued typing, focus changes, selection changes, stale text, secure fields, unsupported apps, and uncertain placement all fail closed.
- The app never inserts into the wrong field, never submits a prompt/chat, never overwrites selected text unexpectedly, never steals focus, and never corrupts clipboard contents in the normal path.
- Typed text, accepted text, screenshots, and prompts stay local and are not stored raw unless the user explicitly opts into a local debug session.
- Mock suggestions are clearly a development fallback and never count as beta-ready runtime proof.
- Proof is current, app-specific, screenshot-backed where visual placement matters, and tied to the current commit.

## Non-Negotiables

Any item below blocks beta for the affected area and can force a category score to zero until fixed:

- Wrong-field insertion.
- Accidental prompt/chat submit.
- Unexpected selected-text replacement.
- Clipboard corruption in normal autocomplete insertion.
- Suggestions in password, secure, payment, login, search, URL, or private fields.
- Reading or storing raw typed text without explicit opt-in.
- Cloud inference or typed-text egress by default.
- Typing lag caused by event tap, AX polling, model work, or rendering.
- Stale suggestion accepted after app, focus, caret, selection, or text changed.
- No pause, per-app disable, or delete-local-traces path.
- Mock fallback represented as beta-ready.
- Broad compatibility claims without current proof.
- Crash on the normal typing path.
- Focus stealing.
- Ghost text in the wrong window, monitor, or detached editor box.

## Current App Assessment

This is a strong lab prototype, not a beta-ready product. The core safety model is better than a typical prototype: `SuggestionAcceptanceGuard` fails closed on app, process, element, selected text, and before/after text mismatch; `CompletionActivationPolicy` blocks selected text, secure fields, unsafe field kinds, sensitive content, middle-of-line text, and short contexts; `CompatibilityProfileStore` blocks or disables many risky apps; raw traces and screenshots are opt-in; fresh installs start paused and suggestion-capable apps default off.

The main weakness is proof quality, not just code. `docs/product/proof-manifest.json` claims some complete surfaces, while `script/manual_smoke_status.sh --strict` and `script/check_proof_manifest.sh --strict` still treat proof as incomplete for this commit. So completed-looking docs cannot be scored as completed proof.

The first automatable product gap found in this pass was slow display. Before the first loop, `CompletionConfidencePolicy` penalized suggestions above 500 ms and 1000 ms, but a high-quality suggestion could still remain displayable at 900-1000 ms. That loop changed the display gate so suggestions over the 750 ms first-visible budget become low confidence and are suppressed.

The next automatable gap was accepted-survival proof. Before the continuation loop, the app recorded acceptance and insertion verification, but did not start the RAM-only `AcceptanceSurvivalChecker`, schedule 2s/10s/30s checks, emit live `acceptedTextEdited`, or emit `acceptanceRetentionCleared`. This loop wired that path after verified insertion and added privacy-shaped metadata tests.

## Score

Overall score: 77/100

Starting score before this implementation loop: 73/100.
Score after first implementation loop: 74/100.
Ending score after continuation loop: 75/100.
Accepted-kept restraint update: suggestion relevance is 75/100 after deletion, typed-over, and edit-distance outcomes started lowering future display scores.
Latency update: latency is 82/100 after the current benchmark gate added
p50/p90/p95/p99 first-visible, first-token, total-generation, event-tap, AX,
stale-late suppression, and default-runtime proof checks.

Release gate status: blocked. `Insertion safety`, `Privacy/trust`, and `Non-annoyance` must all be at least 80/100 with current proof before beta.

## Score Breakdown

| Category | Weight | Current score | Weighted |
| --- | ---: | ---: | ---: |
| Insertion safety | 18 | 81 | 14.58 |
| Privacy and trust | 16 | 84 | 13.44 |
| Non-annoyance | 14 | 76 | 10.64 |
| Latency | 12 | 82 | 9.84 |
| Suggestion relevance | 10 | 75 | 7.50 |
| App compatibility | 10 | 71 | 7.10 |
| Visual placement | 8 | 74 | 5.92 |
| User control | 6 | 78 | 4.68 |
| Recoverability | 4 | 68 | 2.72 |
| Local model/runtime readiness | 2 | 64 | 1.28 |

Weighted total: 76.90, rounded to 77/100.

### Insertion Safety

- Weight: 18
- Current score: 81/100
- Why this score: Strong code gates exist, but real-app proof is not current enough for a higher score.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`, `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift`, `Tests/AutocompleteLabCoreTests/AcceptedTextSafetyPolicyTests.swift`.
- Missing evidence: Current strict real-app proof for all claimed supported surfaces, prompt no-submit proof for Codex/Claude, and per-app undo proof.
- What would make it 100/100: Every accept revalidates app, process, element, selected range, text before/after, foreground status, and insertion verification in current screenshot/trace slices, with zero wrong-field and zero accidental-submit cases.

### Privacy And Trust

- Weight: 16
- Current score: 84/100
- Why this score: Local-first defaults, redacted traces, raw/screenshot opt-in, pause, per-app disable, delete traces, RAM-only accepted-survival retention, and a source-level local-only network surface check are present. Runtime packet-capture proof is still missing.
- Evidence found in repo: `docs/product/privacy-and-controls.md`, `Sources/AutocompleteLabCore/Configuration/TracePrivacyPolicy.swift`, `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalTraceMetadata.swift`, `Sources/AutocompleteLabCore/Tracing/TracePrivacyFingerprint.swift`, `Tests/AutocompleteLabCoreTests/TracePrivacyPolicyTests.swift`, `Tests/AutocompleteLabAppTests/RawTracePrivacyExpiryTests.swift`, `Tests/AutocompleteLabAppTests/RawTraceReportExportTests.swift`, `Tests/AutocompleteLabAppTests/AcceptanceSurvivalCheckerTests.swift`, `script/delete_local_traces.sh`, `script/check_local_only_network_surface.sh`, `script/check_local_only_network_surface_self_test.sh`.
- Missing evidence: Packet-capture or network assertion showing no unexpected egress in a running local-only typing session, and a current onboarding proof that a new user can explain the privacy model.
- What would make it 100/100: Local-only egress tests, clear in-product privacy status, current redacted export proof, and opt-in debug flows that expire and are easy to revoke.

### Non-Annoyance

- Weight: 14
- Current score: 76/100
- Why this score: Burst suppression, cooldowns, confidence gating, display scoring, typed-over handling, slow-display suppression, and accepted-then-deleted runtime signaling exist. The score is still capped because long-session annoyance proof and real trace-based suppression proof are incomplete.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/TypingBurstPolicy.swift`, `Sources/AutocompleteLabCore/Session/DisplayScorePolicy.swift`, `Sources/AutocompleteLabCore/Session/CompletionConfidencePolicy.swift`, `Sources/AutocompleteLabCore/Session/PrefixFamilyCooldownPolicy.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `Tests/AutocompleteLabCoreTests/TypingBurstPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/DisplayScorePolicyTests.swift`, `Tests/AutocompleteLabAppTests/AcceptanceSurvivalCheckerTests.swift`.
- Missing evidence: Long-session annoyance proof, current show-rate/dismiss-rate/resurfacing metrics, and fresh real-app proof that accepted-then-deleted signals suppress future similar suggestions.
- What would make it 100/100: Low show density in real sessions, no immediate resurfacing after dismiss, no mid-word phrase spam, late suggestions hidden, and accepted-then-deleted signals wired into future suppression.

### Latency

- Weight: 12
- Current score: 82/100
- Exact metric change: 69/100 -> 82/100 (+13).
- Why this score: Latency is now measurable by current numbers instead of vibes. The new benchmark reports first-visible/keystroke-to-visible, first-token, total-generation, event-tap, AX read, and stale-late suppression percentiles by app/profile, and the beta gate fails if late suggestions are shown or the default runtime proof is missing. Current log-window metrics show first-visible p50 0 ms, p90 263 ms, p95 280 ms, p99 426 ms; first-token p95 270 ms; total-generation p95 357 ms; event-tap p95 84 us; and zero late shown suggestions. The score is still capped because fresh bounded shown-suggestion proof is not complete for every target app after each relaunch.
- Evidence found in repo: `Sources/AutocompleteLabCore/Runtime/CompletionRuntimeBenchmark.swift`, `Sources/AutocompleteLabCore/Session/FocusedTextPollLatencyStats.swift`, `Sources/AutocompleteLabApp/Mac/KeyboardEventTap.swift`, `script/check_typing_performance_log.sh`, `script/latency_benchmark_report.py`, `script/latency_benchmark_report_self_test.sh`, `script/model_latency_report.py`, `Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift`, `Tests/AutocompleteLabCoreTests/FocusedTextPollLatencyStatsTests.swift`.
- Missing evidence: Fresh bounded p50/p90/p95/p99 shown-suggestion slices for every target app after the same default-model relaunch, plus long-session memory/energy proof.
- What would make it 100/100: Warm-path p50 under 90 ms, p90 under 150 ms, p95 under 180 ms, no event-tap jank, and no stale late suggestions shown.

### Suggestion Relevance

- Weight: 10
- Current score: 75/100
- Exact metric change: 67/100 -> 75/100 (+8).
- Why this score: Output cleaning, ranking, request modes, and accepted-and-kept concepts exist. Accepted-kept is now a restraint signal: immediate deletion, typed-over, and high post-accept edit distance lower future display scoring after sample guardrails, while tiny samples only report directional metadata.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift`, `Sources/AutocompleteLabCore/Session/AcceptedAndKeptLearning.swift`, `Sources/AutocompleteLabCore/Session/DisplayScorePolicy.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `Tests/AutocompleteLabCoreTests/AcceptedAndKeptLearningTests.swift`, `Tests/AutocompleteLabAppTests/SuggestionOrchestratorTests.swift`, `script/check_trace_eval.sh`, `script/experiment_report.py`.
- Missing evidence: Fresh real-model replay slices showing accepted-and-kept improvement, partial accept rate, early undo/delete rate, post-accept edit distance, and style match across every supported app.
- What would make it 100/100: Suggestions are short, locally relevant, style-compatible, accepted often, and rarely edited away after acceptance.

### App Compatibility

- Weight: 10
- Current score: 71/100
- Why this score: Compatibility profiles and denylist are strong, and the proof matrix now links the existing Obsidian and Notes screenshot evidence. Strict current proof is still incomplete and prompt-app graduation is not proven.
- Evidence found in repo: `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`, `Sources/AutocompleteLabCore/Compatibility/CompatibilityRouter.swift`, `docs/product/compatibility-matrix.md`, `docs/product/app-proof-matrix.md`, `Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift`, `Tests/AutocompleteLabCoreTests/CompatibilityRouterTests.swift`.
- Missing evidence: Current strict proof for all claimed rows, real Monaco/ProseMirror beyond fixtures, Codex/Claude one-word no-submit proof, and no-Accessibility off-state proof.
- What would make it 100/100: A living app matrix where every supported/degraded/blocked state has current trace, screenshot, and insertion proof tied to the current commit.

### Visual Placement

- Weight: 8
- Current score: 74/100
- Why this score: Placement policies, screenshot evidence, and visual scripts exist. This pass fixed missing scorecard references for Obsidian and Notes screenshots, but strict screenshot evidence still has broader pending rows.
- Evidence found in repo: `Sources/AutocompleteLabCore/Geometry/VisualPlacementCorrectionPolicy.swift`, `Sources/AutocompleteLabCore/Geometry/SuggestionPanelFrameCalculator.swift`, `docs/product/visual-placement-screenshots/`, `script/check_visual_placement_evidence.sh`, `Tests/AutocompleteLabCoreTests/VisualPlacementGeometryCorrectionPolicyTests.swift`.
- Missing evidence: Current scorecard-linked screenshots for every claimed complete surface, multi-display proof, wrap/scroll proof, and real prompt-app screenshot slices.
- What would make it 100/100: p95 anchor error under 4 px with no wrong-window, wrong-monitor, detached, clipped, or occluding suggestions.

### User Control

- Weight: 6
- Current score: 78/100
- Why this score: Pause, per-app disable, trace pause/delete, forced mirror, proof commands, and full-accept shortcut settings exist. Shortcut conflict detection and language/personalization controls are not complete.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/SuggestionControlPolicy.swift`, `Sources/AutocompleteLabCore/Configuration/DisabledAppSelection.swift`, `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`, `Tests/AutocompleteLabCoreTests/SuggestionControlPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/DisabledAppSelectionTests.swift`.
- Missing evidence: Shortcut conflict detection, per-app shortcut profiles, language preference, personal dictionary, and explicit feedback controls.
- What would make it 100/100: Clear defaults for normal users and deep per-app control for power users without making setup noisy.

### Recoverability

- Weight: 4
- Current score: 68/100
- Why this score: Verification, app-level restore paths, RAM-only accepted-survival checks, retention-cleared traces, and 2s/10s/30s runtime scheduling now exist. Single-step undo and fresh live-editor proof remain incomplete.
- Evidence found in repo: `Sources/AutocompleteLabApp/App/InsertionVerificationScheduler.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalTraceMetadata.swift`, `Sources/AutocompleteLabCore/Session/InsertionVerification.swift`, `Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift`, `Tests/AutocompleteLabCoreTests/AcceptanceSurvivalClassifierTests.swift`, `Tests/AutocompleteLabAppTests/AcceptanceSurvivalCheckerTests.swift`.
- Missing evidence: Real-app undo/redo loops, crash/restart recovery, field-send finalization, and fresh live 2s/10s/30s accepted-and-kept trace slices.
- What would make it 100/100: Every accepted insertion is one clean undo unit with rollback or explicit failure handling when verification mismatches.

### Local Model/Runtime Readiness

- Weight: 2
- Current score: 64/100
- Why this score: The app owns an MLX runtime path and install/repair flow, but current live latency and hardware proof are incomplete.
- Evidence found in repo: `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`, `Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift`, `docs/research/runtime-options.md`, `script/model_latency_report.py`, `Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift`, `Tests/AutocompleteLabAppTests/ModelAssetInstallerTests.swift`.
- Missing evidence: Current default-model proof, minimum-hardware proof, memory/energy proof, sleep/wake proof, and beta packaging proof after any app change.
- What would make it 100/100: Predictable app-owned local inference across the supported hardware matrix, no mock fallback for beta, and latency/energy budgets that stay green in long writing sessions.

## 0/100 Definition

This area is 0/100 if the app can insert into the wrong field, submit a prompt/chat, show in secure/private fields, corrupt the clipboard in normal insertion, store or send typed text without explicit opt-in, cause normal typing lag, steal focus, crash in the typing path, or claim broad compatibility without proof.

## 50/100 Definition

The app works in simple demos and has some tests, but it still relies on stale proof, accepts risky states, shows noisy/late suggestions, has unclear local/cloud boundaries, or cannot prove current behavior in real target apps.

## 80/100 Definition

The app is strong private-beta material: safety, privacy, and non-annoyance are each at least 80; supported apps are narrow and honest; risky apps are blocked; default tracing is redacted; local runtime works without a user-managed server; and current proof scripts mostly pass except for explicitly external/manual gates.

## 100/100 Definition

The app is shippable and deeply trusted: every supported surface has current proof; all risky surfaces fail closed; latency feels immediate; suggestions are useful but quiet; undo/recovery is reliable; privacy is auditable; local-only mode has no unexpected network egress; and the product never asks the user to trust stale or vague claims.

## Failure Modes

1. Wrong-field insertion after app, focus, field, caret, selection, or text changed.
2. Prompt/chat submit caused by autocomplete acceptance or shortcut capture.
3. Secure/private field display or raw typed-text storage without opt-in.
4. Clipboard mutation in normal autocomplete insertion.
5. Slow suggestion displayed after the user has moved on.
6. Event tap, AX polling, or model work causing typing lag.
7. Detached ghost text in the wrong field, window, monitor, or editor region.
8. Selected text overwritten unexpectedly.
9. Full accept enabled in prompt apps without separate no-submit proof.
10. Dismissed, typed-over, or deleted suggestions resurfacing immediately.
11. Mock runtime presented as beta-ready.
12. Compatibility docs claiming support that strict proof cannot reproduce.
13. Accepted text cannot be undone or recovered cleanly.
14. Network behavior contradicts local-first copy.

## Evidence Requirements

- Automated tests for focus change, selected text, secure fields, sensitive phrases, unsupported apps, prompt full-accept disablement, stale request cancellation, and accepted-text safety.
- Targeted latency tests for event-tap p95/max, model shown latency, AX poll backoff, and slow-suggestion display suppression.
- Current `swift test` and targeted policy test passes.
- `script/check_test_coverage_manifest.sh`.
- `script/check_trace_eval.sh` or fresh bounded replay for current traces.
- `script/check_proof_manifest.sh --strict`.
- `script/manual_smoke_status.sh --strict`.
- Screenshot-backed proof linked from scorecards for visual placement rows.
- Manual no-submit proof for Codex, Claude Code, and Claude desktop.
- Manual no-Accessibility proof that suggestions stay off when permission is revoked.
- Network-egress proof for local-only mode.
- Runtime proof from `script/model_latency_report.py --default-model-proof`.
- Redacted report export proof and local trace deletion proof.

## Implementation Queue

### 1. Fail Closed On Slow Suggestions - Completed This Pass

- Objective: Do not show suggestions that miss the first-visible latency budget.
- Files likely involved: `Sources/AutocompleteLabCore/Session/CompletionConfidencePolicy.swift`, `Tests/AutocompleteLabCoreTests/CompletionConfidencePolicyTests.swift`.
- Tests to add/update: Slow otherwise-good suggestions become low confidence and carry a clear reason.
- Proof required: Targeted confidence tests and `swift test`.
- Risk level: Low.
- Expected score impact: +1 overall by improving latency and non-annoyance.
- Result: `CompletionConfidencePolicy` now suppresses suggestions over 750 ms with `too-slow-to-display`; `CompletionConfidencePolicyTests` and full `swift test` pass.

### 2. Reconcile Proof Docs Against Current Strict Gates - Partially Completed This Pass

- Objective: Make `app-proof-matrix.md`, `beta-readiness-checklist.md`, proof manifest, and scorecard rows agree.
- Files likely involved: `docs/product/app-proof-matrix.md`, `docs/product/beta-readiness-checklist.md`, `docs/product/proof-manifest.json`, current scorecards.
- Tests to add/update: `script/check_proof_manifest.sh`, `script/check_visual_placement_evidence.sh`, `script/manual_smoke_status.sh --strict`.
- Proof required: Strict proof scripts should fail only on real pending manual gaps, not stale doc disagreement.
- Risk level: Medium because docs can overclaim if updated carelessly.
- Expected score impact: +2 to +4 overall if proof claims become coherent.
- Result: `script/check_proof_manifest.sh` now passes. `script/check_visual_placement_evidence.sh` now passes in non-strict mode and strict visual gaps were reduced to the real manual proof blockers: Codex same-slice no-submit, Claude Code screenshot proof, and Claude desktop screenshot proof. `script/check_score_targets.sh` now includes this overall-excellence scorecard so it cannot be ignored. Strict proof and score-target gates still fail because prompt-app/manual proof and target-score gaps remain.

### 3. Wire Accepted-Then-Deleted Survival Runtime Signals - Completed In Continuation Loop

- Objective: Make post-accept delete/edit outcomes affect learning and suppression.
- Files involved: `Sources/AutocompleteLabApp/App/AcceptanceSurvivalChecker.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabApp/App/AcceptanceSurvivalTraceMetadata.swift`, `Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift`.
- Tests added/updated: `Tests/AutocompleteLabAppTests/AcceptanceSurvivalCheckerTests.swift`, `Tests/AutocompleteLabCoreTests/DiagnosticValueRedactorTests.swift`.
- Proof required: Fresh trace slice with accepted, 2s/10s/30s `acceptedTextEdited`, `acceptanceRetentionCleared`, and suppression follow-up.
- Risk level: Medium.
- Expected score impact: +1 overall now, with more available after real-app proof.
- Result: Verified insertions now start RAM-only accepted-survival tracking. The app schedules 2s, 10s, and 30s checks, finalizes on blur, records redacted `acceptedTextEdited` and `acceptanceRetentionCleared` events, adds current proof metadata to emitted trace events, uses `acceptanceID` to separate partial accepts, and records accepted-then-deleted annoyance only after survival proof instead of treating every verified insert as accepted-and-kept.

### 3b. Turn Accepted-Kept Into Safe Display Restraint - Completed In This Loop

- Objective: Stop treating accepted-kept as only a dashboard metric.
- Files involved: `Sources/AutocompleteLabCore/Session/AcceptedAndKeptLearning.swift`, `Sources/AutocompleteLabCore/Session/DisplayScorePolicy.swift`, `Sources/AutocompleteLabApp/App/SuggestionOrchestrator.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `script/check_trace_eval.sh`, `script/experiment_report.py`.
- Tests added/updated: `Tests/AutocompleteLabCoreTests/AcceptedAndKeptLearningTests.swift`, `Tests/AutocompleteLabAppTests/SuggestionOrchestratorTests.swift`, `Tests/AutocompleteLabCoreTests/AutocompleteTraceReplayTests.swift`, `script/check_trace_eval_self_test.sh`, `script/experiment_report_self_test.sh`.
- Proof required: Fresh trace slice showing `acceptedAndKeptLearningRestraint`, typed-over/deletion/edit-distance counts, and later display suppression or lower display score in the same app/field/mode bucket.
- Risk level: Medium.
- Expected score impact: suggestion relevance +8 now, with more available after real-model replay proof.
- Result: Immediate deletion, typed-over, and high normalized edit distance now feed the local accepted-kept learner. The learner keeps text private, reports only counts/rates, applies zero score adjustment for tiny samples, and subtracts a bounded learning-restraint component from future display score.

### 4. Add Local-Only Network Egress Proof - Partially Completed In Continuation Loop

- Objective: Prove local-only mode does not unexpectedly talk to the network while typing.
- Files involved: `script/check_local_only_network_surface.sh`, `script/check_local_only_network_surface_self_test.sh`.
- Tests added/updated: Source-audit self-test with safe allowed references and an unsafe `URLSession` fixture.
- Proof required: Current local-only run with host visibility or packet-capture artifact.
- Risk level: Medium because macOS network observation can be environment-specific.
- Expected score impact: +0 overall now because it is a source audit, with +2 to +4 available after runtime packet proof.
- Result: Added a guard that fails if app/core source adds network APIs outside the explicit user-triggered model install path, MLX local import, or static model license URLs.

### 5. Complete Prompt-App No-Submit Proof

- Objective: Keep Codex, Claude Code, and Claude desktop honest before any broader prompt support.
- Files likely involved: `docs/product/manual-smoke-runs.md`, `docs/product/app-proof-matrix.md`, `docs/product/proof-manifest.json`, `script/real_app_smoke.sh`.
- Tests to add/update: Existing prompt-app recorder should reject full accept and send/finalization signals.
- Proof required: Manual-gated screenshot-backed one-word no-submit slices.
- Risk level: High because it touches live prompt surfaces.
- Expected score impact: +3 to +6 overall.

## Codex Execution Goal

Implemented in this pass: make late suggestions fail closed before display, reconcile the non-strict proof manifest screenshot references for existing Obsidian and Notes proof, and wire RAM-only accepted-survival runtime checks after verified insertion.

## Stop Conditions

This goal is complete when:

- The scorecard exists under `docs/product/`.
- The initial score is evidence-based and strict.
- The chosen implementation improvement is tested.
- Targeted tests pass.
- Broader relevant checks run or failures are clearly recorded.
- The scorecard is updated with ending score and remaining gaps.
- The branch is committed and pushed.

## Remaining Gaps

- Manual proof is still required for prompt no-submit behavior, no-Accessibility behavior, multi-display placement, current app-specific visual slices, and real accepted-survival traces.
- Network-egress proof cannot be fully claimed without a real local-only observation run.
- Runtime readiness cannot be fully claimed without current default-model latency proof on target hardware.
- Strict proof gates currently fail and need either fresh proof or doc reconciliation.
- The app remains a lab until safety/privacy/non-annoyance each clear 80/100 with current evidence.
