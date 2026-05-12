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
- Missing required target-app proof still blocks beta and 100/100. Without a
  mechanical prompt-trace gate it capped this score at 79/100; with the gate in
  place, the remaining cap is live target proof.
- ChatGPT, Slack, Telegram, Safari prompt/chat surfaces, and other unproven
  prompt apps must stay disabled or diagnostics-only until exact proof exists.
- Mock model fallback must not count as beta-ready prompt-app behavior.

## Current App Assessment

The app now has explicit prompt-app safety modes in
`CompatibilityProfile.promptAppSafetyMode` plus a versioned
`HostCompatibilityPolicyCatalog`. The proof manifest mirrors that catalog with
exact installed app versions where available, runtime state, proof state, kill
switch, and proof artifacts. Codex and Claude desktop are word-only prompt
surfaces. ChatGPT, Atlas, Safari, Slack, Discord, and Telegram are
disabled/diagnostics-only for prompt safety. This is the right product posture.

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

The proof story is still not enough for 100, but it is now mechanically
enforceable. `script/check_prompt_app_proof.sh` reads JSONL trace slices,
reports the five prompt-app safety counters, and exits nonzero when any counter
is nonzero or when no prompt-app proof events are present. It is wired into the
score loop, strict score target gates, beta readiness, and smoke self-tests.
Codex and Claude desktop now have same-slice one-word no-submit proof. Strict
manual proof remains stale or missing for some other real target apps, so this
does not claim beta-ready prompt-app support.

## Score

Overall score: 87/100

Starting score before this pass: 83/100
Ending score after this pass: 87/100

The score moves above the old proof-gate cap because prompt-app safety can now
fail closed from trace evidence and Codex now has exact same-slice proof. It is
still capped well short of 100 because fresh, exact-version, human-confirmed
prompt-app proof is still missing for other required hosts.

## Score Breakdown

### Host Detection And Context Classification

- Weight: 20
- Current score: 18/20
- Why this score: The app has explicit profiles, prompt-app safety modes, and
  a versioned per-host policy with exact installed versions where available,
  disabled/proof-only runtime states, kill switches, and proof artifacts. It
  still lacks deeper browser URL/domain/state classification.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
  - `Sources/AutocompleteLabCore/Configuration/HostCompatibilityPolicy.swift`
  - `Tests/AutocompleteLabCoreTests/CompatibilityProfileTests.swift`
  - `Tests/AutocompleteLabCoreTests/HostCompatibilityPolicyTests.swift`
  - `docs/product/proof-manifest.json`
  - `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`
  - `Sources/AutocompleteLabCore/Session/PromptEditorFingerprintPolicy.swift`
- Missing evidence:
  - Exact-version proof for required prompt apps.
  - Browser composer URL/domain and tool/context state proof.
  - Streaming/approval/command-menu host-state detection proof.
- What would make it 100/100:
  - Browser composer URL/domain, active-run, tool/context, approval, and
    command-menu state proof for each supported prompt surface.

### Acceptance Channel Safety

- Weight: 25
- Current score: 23/25
- Why this score: Full accept is disabled for prompt apps, Tab is one-word
  only where allowed, and missing-profile insertion now fails closed. Existing
  acceptance guards recheck app, field, focused text, selection, and stale
  context. Codex now has a same-slice Tab one-word no-submit proof; broader
  real prompt-app key collision proof is still incomplete.
- Evidence found in repo:
  - `Sources/AutocompleteLabApp/App/AppDelegate.swift`
  - `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`
  - `Sources/AutocompleteLabCore/Session/KeyboardEventTapConsumptionPolicy.swift`
  - `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift`
  - `Tests/AutocompleteLabCoreTests/KeyboardEventTapConsumptionPolicyTests.swift`
  - `Tests/AutocompleteLabAppTests/SettingsWindowControllerStateTests.swift`
- Missing evidence:
  - Event-level proof that accept never dispatches Return, Enter, submit,
    newline, command, approval, or host shortcut collisions in every required app.
  - More host-labeled active-run proof for Claude Code and browser prompt hosts.
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
- Current score: 11/15
- Why this score: Unit coverage is strong, proof scripts are strict, and the
  new prompt-app proof gate has pass/fail fixtures for the exact hard metrics.
  Codex now has fresh same-slice proof for this implementation branch, while
  the required target apps still do not all have fresh proof.
- Evidence found in repo:
  - `swift test` passed 742 tests.
  - `script/check_test_coverage_manifest.sh` passed.
  - `docs/product/proof-manifest.json`
  - `docs/product/manual-smoke-runs.md`
  - `docs/product/app-proof-matrix.md`
  - `script/manual_smoke_status.sh`
  - `script/real_app_smoke.sh`
  - `script/check_prompt_app_proof.sh`
  - `script/check_prompt_app_proof_self_test.sh`
- Missing evidence:
  - Fresh proof for Claude Code host variants, Claude desktop layout variants,
    ChatGPT, Slack, and Telegram.
  - Same-slice screenshot, one-word accept, verified insertion, before/after
    diff, event log, and no-submit confirmation for each required prompt app.
- What would make it 100/100:
  - All required proof rows current against the implementation commit or
    release archive, with zero hard-gate metrics.

### Observability And Rollback

- Weight: 10
- Current score: 9/10
- Why this score: The repo has trace analysis, privacy filtering, local trace
  deletion, pause/disable controls, typing performance checks, and now named
  prompt-app no-submit metrics plus a dedicated prompt-app proof gate script
  that fails on those exact metrics. It does not yet have a host kill switch.
- Evidence found in repo:
  - `Sources/AutocompleteLabCore/Tracing/PromptAppNoSubmitMetrics.swift`
  - `Tests/AutocompleteLabCoreTests/PromptAppNoSubmitMetricsTests.swift`
  - `script/check_trace_eval.sh`
  - `script/check_prompt_app_proof.sh`
  - `script/check_prompt_app_proof_self_test.sh`
  - `script/check_typing_performance_log.sh`
  - `script/delete_local_traces.sh`
  - `Sources/AutocompleteLabCore/Session/SuggestionControlPolicy.swift`
- Missing evidence:
  - Per-host kill switch or downgrade policy outside a new app build.
- What would make it 100/100:
  - Per-host rollback/downgrade controls plus fresh target-app proof that keeps
    the prompt-app proof gate green.

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

This repo now clears that bar at 87 because the prompt-app trace gate exists,
can fail closed, and Codex has live same-slice proof. It still needs broader
live target-app proof before beta support.

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
  Telegram on exact versions. Codex and Claude desktop now have current
  one-word no-submit rows; other hosts still need coverage.
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

- Status: Done in this pass.
- Result: `script/check_prompt_app_proof.sh` reads bounded trace slices and
  fails if any prompt-app no-submit metric is nonzero.
- Files involved:
  - `script/check_prompt_app_proof.sh`
  - `script/check_prompt_app_proof_self_test.sh`
  - `script/scorecard_goal_loop.sh`
  - `script/check_score_targets.sh`
  - `script/beta_readiness.sh`
  - `script/smoke_test.sh`
- Tests added:
  - `script/check_prompt_app_proof_self_test.sh` proves a clean prompt trace
    passes, all five hard metrics fail for the right reasons, metadata-tagged
    AI chat events count as prompt evidence, and missing prompt evidence fails
    closed.
- Score impact: +4.

### 2. Exact Target-App Manual Proof Pack

- Objective: Run the required manual-gated proof for Claude Code host variants,
  Claude desktop layout variants, ChatGPT, Slack, and Telegram. Codex default
  same-slice proof is complete.
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

Current stop condition reached: the automatable prompt-app proof gate is now in
place and wired into release-style gates. The remaining points are blocked on
fresh human/manual target-app proof.

## Remaining Gaps

- Required real-app proof is missing for ChatGPT, Slack, and Telegram.
- Claude Code still needs more host-labeled one-word no-submit proof, and
  Claude desktop still needs layout variants. Codex default proof is complete
  against the current proof branch.
- `check_trace_eval.sh` fails on old all-history traces with insertion
  failures; release proof should use fresh bounded trace slices.
- `beta_readiness.sh --check-only` is blocked by manual proof, the prompt-app
  proof gate when no clean bounded trace is provided, and missing private beta
  archive.
- The dedicated prompt-app proof gate exists now; it still needs fresh bounded
  live traces from the required target apps.
