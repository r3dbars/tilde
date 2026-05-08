# Prompt-App No-Submit Safety Scorecard - 2026-05-08

## Source

- Deep Research topic: Prompt-App No-Submit Safety Rubric
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `002ed53034a4e851c930619d87e6e12be345c513`

## Executive Summary

Prompt and chat apps are not normal writing fields. Their composers can send,
submit, run commands, attach context, approve tools, or steer an active agent.
For this app, excellence means the autocomplete is boringly safe: no Return or
Enter replay, no stale focus insertion, no command-like suggestions, no secure
or private field display, and no broad app promise without exact proof.

This implementation pass moved the app from a prompt-aware but incomplete
state to a stricter fail-closed state. The score is still capped because the
required real-app proof is not present for every target app.

## Product Standard

The app should only help in prompt/chat fields when the exact host is known,
the safety mode is explicit, the accept gesture cannot collide with host send
shortcuts, and accepting the visible text can only insert a plain, safe,
single word into the same focused field.

Unknown, unproven, secure, selected-text, browser-login, payment, terminal,
password-manager, and risky prompt contexts should suppress suggestions. No
suggestion is better than a wrong or surprising suggestion.

## Non-Negotiables

- Any accidental send, submit, execute, approval, or prompt interruption blocks
  beta and caps this score at 19/100.
- Any wrong-field or stale-context insertion blocks beta and caps this score at
  39/100.
- Any mutation outside the accepted span, attachment change, or rich-text leak
  caps this score at 59/100.
- Any prompt-app suggestion content violation in a release proof corpus caps
  this score at 59/100.
- Missing required target-app proof caps this score at 79/100.
- ChatGPT, Slack, Telegram, Safari prompt/chat surfaces, and other unproven
  prompt apps must stay disabled or diagnostics-only until exact proof exists.
- Mock model fallback must not count as beta-ready prompt-app behavior.

## Current App Assessment

The app now has explicit prompt-app safety modes in
`CompatibilityProfile.promptAppSafetyMode`. Codex, Claude Code, and Claude
desktop are word-only prompt surfaces. ChatGPT, Atlas, Safari, Slack, Discord,
and Telegram are disabled/diagnostics-only for prompt safety. This is the
right product posture.

The insertion path is safer than before. `AppDelegate.insertAcceptedText` no
longer inserts raw text when there is no current compatibility profile; it
records an insertion failure and hides the suggestion instead. The accepted
text policy blocks whitespace-only accepts, hidden control characters,
multiword accepts where full accept is disabled, prompt command prefixes,
shell-like content, and action words such as `send`, `run`, `approve`, and
`deploy`.

Suggestion generation is stricter. `CompletionOutputCleaner` and
`CompletionCandidateRanker` suppress prompt actions, slash/at/bang commands,
shell-looking text, hidden characters, and approval/submit language. AI chat
prompt guidance now says not to suggest slash commands, at-references, bang
commands, shell text, approval text, or prompt answers.

The proof story is still not enough for 100. `swift test` passes 742 tests,
but strict manual proof remains stale or missing. `manual_smoke_status.sh
--strict`, `check_visual_placement_evidence.sh`, `check_score_targets.sh`, and
`beta_readiness.sh --check-only` all still fail on proof/archive blockers.
`check_trace_eval.sh` also fails against old all-history local traces because
they contain unrecovered insertion failures. Those traces are useful warning
evidence, not current release proof for this implementation commit.

## Score

Overall score: 79/100

Starting score before this pass: 70/100
Ending score after this pass: 79/100

The ending score hits the research hard cap for missing required target-app
proof. The code can improve further, but the last 21 points require fresh,
exact-version, human-confirmed prompt-app proof.

## Score Breakdown

### Host Detection And Context Classification

- Weight: 20
- Current score: 16/20
- Why this score: The app has explicit profiles and prompt-app safety modes,
  and high-risk unproven apps are disabled. It still lacks a versioned host
  policy file and deeper browser URL/domain/state classification.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
  - `Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift`
  - `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`
  - `Sources/AutocompleteLabCore/Session/PromptEditorFingerprintPolicy.swift`
- Missing evidence:
  - Exact-version proof for required prompt apps.
  - Browser composer URL/domain and tool/context state proof.
  - Streaming/approval/command-menu host-state detection proof.
- What would make it 100/100:
  - Versioned per-host policy with exact app versions, safety mode, disabled
    states, and proof artifacts for each supported prompt surface.

### Acceptance Channel Safety

- Weight: 25
- Current score: 22/25
- Why this score: Full accept is disabled for prompt apps, Tab is one-word
  only where allowed, and missing-profile insertion now fails closed. Existing
  acceptance guards recheck app, field, focused text, selection, and stale
  context. Real prompt-app key collision proof is still missing.
- Evidence found in repo:
  - `Sources/AutocompleteLabApp/App/AppDelegate.swift`
  - `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`
  - `Sources/AutocompleteLabCore/Session/KeyboardEventTapConsumptionPolicy.swift`
  - `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift`
  - `Tests/AutocompleteLabCoreTests/KeyboardEventTapConsumptionPolicyTests.swift`
  - `Tests/AutocompleteLabAppTests/SettingsWindowControllerStateTests.swift`
- Missing evidence:
  - Event-level proof that accept never dispatches Return, Enter, submit,
    newline, command, approval, or host shortcut collisions in required apps.
  - Active-run proof for Codex and Claude Code.
- What would make it 100/100:
  - Recorded proof bundles showing zero accidental sends and zero key
    collisions across every required target app and preference mode.

### Suggestion Content Restrictions

- Weight: 15
- Current score: 13/15
- Why this score: The cleaner, ranker, accepted-text policy, and AI-chat prompt
  guidance now block the key unsafe content classes. The policy is still
  heuristic and not yet a single versioned prompt-host policy artifact.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`
  - `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift`
  - `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`
  - `Sources/AutocompleteLabCore/Session/AutocompleteBehaviorProfile.swift`
  - `Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift`
  - `Tests/AutocompleteLabCoreTests/CompletionCandidateRankerTests.swift`
  - `Tests/AutocompleteLabCoreTests/AcceptedTextSafetyPolicyTests.swift`
- Missing evidence:
  - Release corpus proof with zero suggestion-content violations.
  - App-specific allow/deny word policy for command-like contexts.
- What would make it 100/100:
  - A versioned content policy plus release-corpus proof for every risky host.

### Mutation Control

- Weight: 15
- Current score: 13/15
- Why this score: Selection replacement is blocked, insertion verification
  exists, wrong-context acceptance is guarded, and stale suggestions are
  invalidated. The app still needs exact prompt-app proof that no hidden
  context, attachment, rich-text node, or previous text mutates.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Session/InsertionVerification.swift`
  - `Sources/AutocompleteLabCore/Text/SelectedTextRangeReplacer.swift`
  - `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`
  - `Sources/AutocompleteLabApp/Mac/InsertionEngine.swift`
  - `Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift`
  - `Tests/AutocompleteLabCoreTests/SelectedTextRangeReplacerTests.swift`
- Missing evidence:
  - Before/after prompt diffs in each required app.
  - Proof that attachments, canvas/tool context, and approval UI are unchanged.
- What would make it 100/100:
  - Exact accepted-span diff proof and zero mutation metrics for every required
    app, including contenteditable and native composer variants.

### Testing And Proof Coverage

- Weight: 15
- Current score: 8/15
- Why this score: Unit coverage is strong, and proof scripts are strict. The
  required target apps do not have fresh proof for this implementation commit.
- Evidence found in repo:
  - `swift test` passed 742 tests.
  - `script/check_test_coverage_manifest.sh` passed.
  - `docs/product/proof-manifest.json`
  - `docs/product/manual-smoke-runs.md`
  - `docs/product/app-proof-matrix.md`
  - `script/manual_smoke_status.sh`
  - `script/real_app_smoke.sh`
- Missing evidence:
  - Fresh proof for Codex, Claude Code, Claude desktop, ChatGPT, Slack, and
    Telegram.
  - Same-slice screenshot, one-word accept, verified insertion, before/after
    diff, event log, and no-submit confirmation for each required prompt app.
- What would make it 100/100:
  - All required proof rows current against the implementation commit or
    release archive, with zero hard-gate metrics.

### Observability And Rollback

- Weight: 10
- Current score: 7/10
- Why this score: The repo has trace analysis, privacy filtering, local trace
  deletion, pause/disable controls, typing performance checks, and now named
  prompt-app no-submit metrics. It does not yet have a host kill switch or a
  dedicated prompt-app proof gate script that fails on these exact metrics.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Tracing/PromptAppNoSubmitMetrics.swift`
  - `Tests/AutocompleteLabCoreTests/PromptAppNoSubmitMetricsTests.swift`
  - `script/check_trace_eval.sh`
  - `script/check_typing_performance_log.sh`
  - `script/delete_local_traces.sh`
  - `Sources/AutocompleteLabCore/Session/SuggestionControlPolicy.swift`
- Missing evidence:
  - A first-class script that consumes prompt-app proof traces and reports
    `accidentalSubmitCount`, `sendKeyCollisionCount`,
    `promptMutationWithoutUserIntentCount`, `wrongContextInsertionCount`, and
    `suggestionContentViolationCount`.
  - Per-host kill switch or downgrade policy outside a new app build.
- What would make it 100/100:
  - Dedicated prompt-app proof gate plus per-host rollback/downgrade controls.

## 0/100 Definition

The app inserts into the wrong field, submits a prompt, sends a message,
executes or approves an action, shows in secure/private fields, stores raw
typed text without opt-in, or cannot be paused. One catastrophic trust failure
is enough.

## 50/100 Definition

The app has some prompt-aware code and tests, but risky hosts are still broadly
enabled, unsafe content can get through, full accept may work in prompt apps,
and real-app proof is missing or stale.

## 80/100 Definition

The app is conservative and mostly safe for private dogfooding: risky hosts
are disabled or word-only, full accept is off, wrong-context insertion is
guarded, unsafe content is blocked, unit tests pass, and proof scripts clearly
name remaining manual blockers.

This repo is just under that bar at 79 because the research hard cap applies.

## 100/100 Definition

Every supported prompt/chat app has fresh exact-version proof with zero
accidental sends, zero send-key collisions, zero wrong-context insertions, zero
mutations outside the accepted span, zero suggestion-content violations, and a
clear host rollback path. Unsupported or unproven hosts stay disabled.

## Failure Modes

1. Accidental prompt/message send, tool execution, approval, or active-run
   interruption.
2. Wrong field, stale field, wrong window, or wrong monitor insertion.
3. Hidden command/control content accepted into a prompt app.
4. Full-line or multiword accept in an unproven prompt app.
5. Slash, at, bang, shell, approval, or submit language suggested by the model.
6. Mutation outside the accepted text span.
7. Secure/private/login/payment/search field display.
8. Stale proof represented as current support.
9. Mock fallback represented as beta-ready model behavior.
10. Normal typing lag or focus stealing during prompt use.

## Evidence Requirements

- Unit tests for host profiles, accepted-text safety, cleaner/ranker content
  filtering, acceptance guard behavior, and prompt-app metrics.
- `swift build` and `swift test` passing on the implementation commit.
- Manual proof for Codex, Claude Code, Claude desktop, ChatGPT, Slack, and
  Telegram on exact versions.
- For each prompt app: screen video or screenshot trace, key/event log,
  before/after prompt diff, send-count or no-submit confirmation, field role
  log, app version, commit/archive proof token, and trace slice.
- Metrics must be zero for accidental submit, send-key collision, wrong-context
  insertion, prompt mutation without user intent, and suggestion-content
  violation.
- Proof must use harmless disposable text and must not press Enter as part of
  the accept path.

## Implementation Queue

### 1. Dedicated Prompt-App Proof Gate

- Objective: Add a script that reads a bounded trace slice and fails if any
  prompt-app no-submit metric is nonzero.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Tracing/PromptAppNoSubmitMetrics.swift`
  - `script/check_trace_eval.sh`
  - new or existing self-test under `script/`
- Tests to add/update:
  - `Tests/AutocompleteLabCoreTests/PromptAppNoSubmitMetricsTests.swift`
  - self-test with fixture traces for pass/fail cases.
- Proof required:
  - Script output showing all five metrics at zero for a fixture pass.
- Risk level: Medium.
- Expected score impact: +3 to +5.

### 2. Exact Target-App Manual Proof Pack

- Objective: Run the required manual-gated proof for Codex, Claude Code,
  Claude desktop, ChatGPT, Slack, and Telegram.
- Files likely involved:
  - `docs/product/manual-smoke-runs.md`
  - `docs/product/proof-manifest.json`
  - `docs/product/app-proof-matrix.md`
  - `docs/product/visual-placement-screenshots/`
- Tests to add/update:
  - Existing proof scripts should validate the new rows.
- Proof required:
  - Same-slice screenshot, one-word accept, verified insertion, before/after
    prompt diff, event log, and no-submit confirmation per app.
- Risk level: High because it touches real prompt/chat apps.
- Expected score impact: +15 to +21.

### 3. Versioned Host Safety Policy

- Objective: Move prompt-app safety modes, risky token policy, and target app
  version requirements into a structured policy object or file.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
  - `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`
  - `Sources/AutocompleteLabCore/Engine/CompletionCandidateRanker.swift`
- Tests to add/update:
  - Profile policy tests for disabled/click-only/word-only modes.
  - Content policy tests for per-host exceptions.
- Proof required:
  - Policy fixture tests and docs that map each target app to a safety mode.
- Risk level: Medium.
- Expected score impact: +2 to +4.

### 4. Browser/Prompt State Detection

- Objective: Suppress prompt suggestions during streaming, command menus,
  approvals, attachments, screenshot/canvas/tool modes, and unknown browser
  domains.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Session/PromptEditorFingerprintPolicy.swift`
  - `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`
  - app-specific AX reader or compatibility routing files.
- Tests to add/update:
  - Fingerprint and activation tests for active-run, approval, command-menu,
    and attachment-like states.
- Proof required:
  - App-specific fixture and manual proof where possible.
- Risk level: High.
- Expected score impact: +4 to +8.

### 5. Host Rollback/Downgrade Control

- Objective: Add a local per-host downgrade path so a host can be moved from
  word-only to click-only or disabled without broad code changes.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Configuration/DisabledAppSelection.swift`
  - `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
  - Settings UI state files.
- Tests to add/update:
  - Profile override tests and Settings state tests.
- Proof required:
  - Local setting or policy override visibly downgrades a prompt app.
- Risk level: Medium.
- Expected score impact: +2 to +3.

## Codex Execution Goal

Make prompt-app autocomplete no-submit safety honestly reach 100/100 by keeping
unproven prompt apps disabled or word-only, adding a dedicated prompt-app proof
gate, and collecting exact-version proof bundles for Codex, Claude Code,
Claude desktop, ChatGPT, Slack, and Telegram with zero hard-gate metrics.

## Stop Conditions

- The score reaches 100/100 with fresh exact-version proof for every required
  target app, or
- All automatable code/test/proof-gate work is complete and only human manual
  proof remains, or
- A target app cannot be safely tested without risking a real submit/send.

Current stop condition reached: all high-leverage automatable code/test
hardening from this pass is complete, and the remaining points are blocked on
human/manual proof.

## Remaining Gaps

- Required real-app proof is missing for ChatGPT, Slack, and Telegram.
- Codex, Claude Code, and Claude desktop need fresh same-slice one-word
  no-submit proof against this implementation commit or a release archive.
- `docs/product/app-proof-matrix.md` and `docs/product/proof-manifest.json`
  still disagree in places; proof docs need a cleanup pass after fresh runs.
- `check_trace_eval.sh` fails on old all-history traces with insertion
  failures; release proof should use fresh bounded trace slices.
- `beta_readiness.sh --check-only` is blocked by manual proof and missing
  private beta archive, not by this code path.
- The prompt-app metrics analyzer exists, but there is not yet a dedicated
  command-line prompt-app proof gate around it.
