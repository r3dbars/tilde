# Non-Annoyance Scorecard - 2026-05-08

## Source

- Deep Research topic: Non-Annoyance Rubric for System-Wide Autocomplete
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14dee37a4c8a44d89f1059f8a2aec9ca4e40`

## Executive Summary

The research standard is simple: this app should feel like quiet typing help, not a second actor in the room. Suggestions must be sparse, short, easy to ignore, fast to disappear, never stale, never in sensitive fields, and never repeated after the user rejects them.

This repo already has strong safety pieces: field classification, selected-text blocking, stale request gates, acceptance guards, prompt-app profiles, typed-over detection, and redacted trace analysis. The main weakness was that some non-annoyance policies were tested in core but not fully wired into the live app path, and the trace tooling did not expose the exact research metrics as first-class outputs.

This loop wired prefix-family cooldown and quiet-mode blocking into `AppDelegate`, added visible lifetime metadata for hides, and added non-annoyance trace rates.

## Product Standard

Excellent behavior for this app means:

- Suggestions appear only in trusted writing contexts with a stable caret and fresh nearby text.
- Suggestions are short, local, and shaped like the user's own continuation.
- Continued typing, Escape, deletion, focus changes, placement uncertainty, and stale text all make the suggestion disappear or stay suppressed.
- Rejected suggestions do not immediately return under the same prefix family.
- Trace proof can show shown/min, accept rate, explicit dismissals/shown, typed-over rate, stale/wrong-context rate, and visible lifetime.
- Prompt/chat apps stay one-word-only or disabled until same-slice no-submit proof exists.

## Non-Negotiables

Any of these must force the relevant category to 0 or block beta:

- Wrong-field insertion.
- Accidental prompt/chat submit.
- Suggestion shown in secure, password, payment, token, search, URL, terminal, or unsupported structured fields.
- Stale suggestion accepted after focus, caret, app, field, or text changed.
- App steals focus or corrupts clipboard.
- Normal typing lag from the key event path.
- Raw typed text, screenshots, or cloud inference enabled by default.
- Mock fallback represented as beta-ready.
- No pause, disable, or local trace deletion.
- Broad app compatibility claimed without current app-specific proof.

## Current App Assessment

Starting score before this loop: 76/100.

The app is beyond a raw prototype, but not yet a "forgettable" trusted autocomplete. It has good core safety machinery in `CompletionActivationPolicy`, `AXFieldClassifier`, `SensitiveTextFieldPolicy`, `SuggestionRequestGate`, `SuggestionAcceptanceGuard`, `SuggestionTypingProgressPolicy`, `AnnoyanceSuppressor`, `PrefixFamilyCooldownPolicy`, and `CompatibilityProfile`.

The harsh read: proof is still uneven. `check_proof_manifest.sh` and `check_visual_placement_evidence.sh` now pass in normal mode after linking current Obsidian and Notes screenshot evidence, but strict proof still fails. Codex still lacks strict same-slice screenshot plus one-word accept plus no-submit proof. Claude Code remains pending. Claude desktop proof is stale. A full human no-annoyance soak with pause/resume baseline is not present.

This loop improves live non-annoyance behavior and proof:

- `AppDelegate` now records typed-over, Escape, and deletion cooldowns with `PrefixFamilyCooldownPolicy`.
- `AppDelegate` now checks active `AnnoyanceSuppressor` quiet modes before requesting.
- `suggestionHidden` trace events now include `lifetimeMs` and `visibleLifetimeMs`.
- `AutocompleteTraceAnalyzer` now exposes shown/min, explicit dismissals/shown, typed-over rate, stale/wrong-context rate, and visible lifetime p50/p95.
- `check_trace_eval.sh` and its self-test now print and verify those research metrics.
- Accepted insertion now opens a short native Cmd-Z passthrough window, so immediate undo is tracked and replayed to the host app instead of being marked unavailable.
- Older proof docs now reference tracked Obsidian and Notes title/body/checklist screenshots, so normal proof checks reflect the current evidence.
- `hideSuggestion` now records `hideLatencyMs`, and analyzer/report/script output exposes hide-latency p50/p95.

## Score

Overall score: 87/100.

## Score Breakdown

### Context correctness

- Weight: 30
- Current score: 26/30
- Why this score: Strong suppression and accept-time guards exist, app/global quiet modes are now checked before new requests, and current Obsidian/Notes proof rows are linked. The score is capped by missing current prompt-app no-submit proof and production-surface proof beyond fixtures.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`, `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`, `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`, `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`, `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`.
- Missing evidence: Same-slice Codex/Claude prompt proof, production website proof beyond fixtures, proof manifest aligned to current scorecard.
- What would make it 100/100: Zero secure/structured leaks, stale/wrong-context rate <= 0.5%, and current proof for every enabled app surface.

### Disappearance discipline

- Weight: 20
- Current score: 19/20
- Why this score: Focus change, stale keydown, typed-over progress, placement failure, panel-frame failure, and cooldown/quiet mode all hide or suppress suggestions. This loop added visible lifetime metadata and hide request-to-panel-hide p50/p95 metrics. The remaining point requires live invalidation proof, not just instrumentation.
- Evidence found in repo: `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Session/SuggestionTypingProgressPolicy.swift`, `Sources/AutocompleteLabCore/Session/SuggestionPresentationGate.swift`, `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceAnalyzer.swift`, `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceReportGenerator.swift`, `Tests/AutocompleteLabCoreTests/SuggestionTypingProgressPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/AutocompleteTraceAnalyzerTests.swift`, `script/check_trace_eval.sh`.
- Missing evidence: real-app p95 hide latency < 50ms from live invalidation events, IME/dead-key proof, current 10-minute typing endurance with suggestion activity.
- What would make it 100/100: Automated and manual proof that every invalidation path hides within budget and never leaves a stale ghost.

### Interruption load

- Weight: 20
- Current score: 17/20
- Why this score: Trigger delays, typing-burst suppression, repeated-miss suppression, prefix-family cooldown, field/app/global quiet mode, pause, app disable, and local log deletion are present and traceable. The score is capped by missing human pause/resume baseline and incomplete live shown/min evidence across app surfaces.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/SuggestionTriggerPolicy.swift`, `Sources/AutocompleteLabCore/Session/SuggestionRepetitionSuppressor.swift`, `Sources/AutocompleteLabCore/Session/PrefixFamilyCooldownPolicy.swift`, `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `script/check_trace_eval.sh`.
- Missing evidence: Real dogfood trace showing 0.5-2.0 shown/min, explicit dismissals/shown <= 0.25, typed-over <= 0.35, and no pause/resume uplift.
- What would make it 100/100: A repeatable trace/proof loop that automatically backs off when annoyance rates cross red lines.

### Usefulness

- Weight: 15
- Current score: 11/15
- Why this score: The app filters assistant-y output, bounds word/phrase behavior, ranks candidates, tracks accepted-and-kept, and now reports typed-over rate. It lacks enough current real-app trace evidence to prove healthy accept and typed-over rates.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift`, `Sources/AutocompleteLabCore/Engine/WordCompletionCandidateRanker.swift`, `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceAnalyzer.swift`, `Tests/AutocompleteLabCoreTests/AutocompleteTraceAnalyzerTests.swift`.
- Missing evidence: Current accepted-and-kept rates by app, human voice/style ratings, and enough live misses to tune without raw text persistence.
- What would make it 100/100: Healthy accept rate without higher frequency, low typed-over rate, and user-rated suggestions that feel self-authored.

### Trust and voice

- Weight: 15
- Current score: 14/15
- Why this score: Local-first defaults, redacted traces, screenshot/raw text opt-ins, secure-field blocking, pause/disable/delete controls, assistant-voice filters, and a native Cmd-Z passthrough window are strong. The main gaps are real-app undo proof and current prompt-app proof.
- Evidence found in repo: `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceEvent.swift`, `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift`, `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`, `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `docs/product/privacy-and-controls.md`.
- Missing evidence: Fresh accepted-text undo proof, human review for voice drift, and no-submit proof in prompt/chat apps.
- What would make it 100/100: Every accept is safely reversible, no assistant voice appears in human review, and privacy behavior is obvious in UI and trace artifacts.

## 0/100 Definition

Spammy or dangerous. The app shows suggestions in blocked fields, survives focus/caret/text changes, inserts stale or wrong-field text, causes typing lag, stores raw text by default, or submits chat/prompt text accidentally.

## 50/100 Definition

Sometimes useful but too eager. It works in a few places, but repeats rejected suggestions, lacks proof for stale/wrong-context behavior, has weak pause/delete controls, or relies on docs instead of current trace evidence.

## 80/100 Definition

Mostly quiet and private-beta plausible. Suggestions are narrow, short, local, suppress correctly in risky fields, vanish on invalidation, and have passing automated tests plus some real-app proof. Remaining gaps are mostly manual proof and tuning.

## 100/100 Definition

Forgettably good. The app appears only when useful, hides before it becomes annoying, never feels stale or watchful, preserves the user's voice, proves all enabled app surfaces, and has automatic red-line gates for annoyance metrics.

## Failure Modes

1. Wrong-field or stale accept inserts text into the wrong place.
2. Prompt/chat accept sends or submits text.
3. Secure/private/search/form/terminal field leakage.
4. Normal typing lag or dropped keystrokes.
5. Suggestion remains visible after focus, caret, placement, or text changes.
6. Rejected suggestion respawns immediately.
7. Assistant-y or persuasive voice drifts the user's writing.
8. User cannot pause, disable, undo, or delete local traces.
9. App claims broad support without current proof.
10. Mock or fixture proof is presented as beta-ready real-app support.

## Evidence Requirements

- Automated tests for secure/structured suppression, stale request dropping, accept guard failures, selected-text blocking, typed-over handling, cooldowns, trace metrics, and report output.
- Trace metrics for shown/min, accept rate, explicit dismissals/shown, typed-over rate, stale/wrong-context rate, visible lifetime p50/p95, and latency p95.
- Manual proof rows with bounded trace lines, screenshot evidence, verified accepts, and no-submit proof where relevant.
- Prompt-app proof must be same-slice: screenshot, one-word accept, no prompt submit.
- Endurance proof must show typing event path stays fast and suggestions do not increase hesitation.
- Privacy proof must show raw text and screenshots remain opt-in and local traces can be deleted.

## Implementation Queue

### 1. Wire rejection cooldowns and quiet modes into the live app path

- Objective: Stop immediate respawn after typed-over, Escape, or deletion; honor field/app/global quiet modes before requests.
- Files likely involved: `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteLabCore/Session/PrefixFamilyCooldownPolicy.swift`, `Sources/AutocompleteLabCore/Session/AnnoyanceSuppressor.swift`.
- Tests to add/update: App compile path plus existing prefix and annoyance policy tests.
- Proof required: Trace shows `prefix-family-cooldown` suppression after rejection.
- Risk level: Medium.
- Expected score impact: +4.
- Status: Completed in this loop.

### 2. Add first-class non-annoyance trace rates

- Objective: Make the deep-research metrics visible in analyzer and CLI output.
- Files likely involved: `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceAnalyzer.swift`, `Sources/AutocompleteLabCore/Tracing/AutocompleteTraceReportGenerator.swift`, `script/check_trace_eval.sh`.
- Tests to add/update: `AutocompleteTraceAnalyzerTests`, `check_trace_eval_self_test.sh`.
- Proof required: Unit tests and script self-test assert rates, including hide-latency p50/p95.
- Risk level: Low.
- Expected score impact: +3.
- Status: Completed in this loop.

### 3. Refresh strict proof manifest and visual evidence docs

- Objective: Make proof scripts pass or fail only on real current gaps.
- Files likely involved: `docs/product/proof-manifest.json`, `docs/product/app-proof-matrix.md`, `docs/product/deep-dive-scorecard-2026-05-06.md`.
- Tests to add/update: `./script/check_proof_manifest.sh`, `./script/check_visual_placement_evidence.sh`.
- Proof required: Scripts pass for complete rows and fail for pending rows only.
- Risk level: Low.
- Expected score impact: +3.

### 4. Prompt-app no-submit proof

- Objective: Close Codex, Claude Code, and Claude desktop proof without broadening support.
- Files likely involved: proof docs and trace artifacts, maybe `CompatibilityProfile.swift` if proof changes support state.
- Tests to add/update: manual smoke/proof manifest checks.
- Proof required: Same-slice screenshot, one-word Tab accept, verified insertion, no submit.
- Risk level: High.
- Expected score impact: +5 to +8.

### 5. Accepted insertion undo/reversibility proof

- Objective: Prove immediate undo/backspace recovery after accept.
- Files likely involved: `KeyboardAction.swift`, `KeyboardEventTapConsumptionPolicy.swift`, `AppDelegate.swift`, acceptance survival/proof tests.
- Tests to add/update: keyboard action routing and real-app smoke.
- Proof required: Accepted text can be reversed without corrupting nearby text.
- Risk level: High.
- Expected score impact: +3.

## Codex Execution Goal

Make non-annoyance measurable and enforceable in the live app path by wiring rejection cooldowns and quiet modes into `AppDelegate`, adding visible lifetime and hide-latency trace metadata, exposing the research metrics in analyzer/CLI/report output, and updating this scorecard with exact evidence and remaining proof gaps.

## Stop Conditions

This goal is complete when:

- Targeted Swift tests for trace analysis pass.
- The trace eval self-test passes.
- The broader safety test slice passes.
- The scorecard includes honest starting and ending scores.
- Remaining gaps are manual proof, external UI proof, or higher-risk behavior that should not be automated blindly.

## Remaining Gaps

- `check_proof_manifest.sh` passes in normal mode; strict mode still cannot pass until partial/pending surfaces are complete.
- `check_visual_placement_evidence.sh` passes in normal mode; strict mode still fails on Codex same-slice proof plus Claude Code/Claude desktop screenshot proof.
- Codex, Claude Code, and Claude desktop need current same-slice prompt no-submit proof.
- Hide latency is now instrumented as hide request-to-panel-hide time, but still needs real-app invalidation proof under the 50ms p95 target.
- Prefix cooldown is now wired, but there is not yet a real-app trace run proving user-perceived annoyance improvement.
- Accepted insertion undo now has a native passthrough path, but still needs real-app proof.
- Human voice/style review and pause/resume baseline are still missing.
