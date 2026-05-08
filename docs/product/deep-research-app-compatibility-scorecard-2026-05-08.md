# App Compatibility Scorecard - 2026-05-08

## Source

- Deep Research topic: App compatibility rubric for system-wide autocomplete
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `2c33d1342e9b6f2d0503a6a06d7281b1ef616c6c` plus the
  compatibility-safety changes in this pass
- Source document: `/Users/redbars/Downloads/deep-research-report (12).md`

## Executive Summary

The research says this app must not claim broad system-wide compatibility. The
safe unit is an exact profile: app, surface, app version, and insertion path.
Secure fields are blocked. Terminal and password-manager surfaces are blocked.
Prompt, chat, mail, and message composers stay suggest-only or blocked unless a
current no-submit proof exists. Unknown custom editors stay detect-only or
diagnostics-only until their surface and insertion path are proven.

This repo already has a strong safety posture: explicit compatibility profiles,
denylisted apps, prompt-app full-accept disablement, secure-field suppression,
manual smoke logs, screenshot evidence, proof manifests, trace replay, and
strict gates that still fail honestly. The main weakness is that the code still
leans on bundle-level profiles in places where the research wants profile-level
surface/path/version proof. This pass tightened browser hosted-surface blocking
for action-bearing web apps, made fast word completions use the final stale
context refresh before display, and added first-class surface/path/hard-cap
metadata to compatibility profiles. This follow-up also persists that scope on
learned compatibility profiles and blocks suggestions while marked-text
composition is active.

## Product Standard

Excellent app compatibility for this lab means:

- Every supported behavior is scoped to an app plus exact surface plus path.
- Default behavior is quiet and narrow.
- Secure, password, token, payment, URL, login, terminal, and unknown risky
  surfaces stay silent.
- Prompt/chat/email/message composers never get broad accept support without
  no-submit proof.
- Suggestions only appear when caret, field, text, and placement are current.
- Accepted text inserts once, in the intended field, and can be undone safely.
- Proof is current, bounded, replayable, and tied to the same build.

## Non-Negotiables

Any of these blocks beta or forces the relevant surface/category to zero:

- Wrong-field insertion.
- Accidental prompt, chat, email, shell, or agent submit.
- Showing suggestions in secure, password, token, payment, or private fields.
- Reading or storing raw typed text without explicit opt-in.
- Sending typed text to cloud services by default.
- Stale suggestion inserted after app, field, caret, or text changed.
- Normal typing lag caused by the app.
- Clipboard corruption.
- Mock model fallback represented as beta-ready.
- Broad app compatibility claimed without proof.
- App crash, focus steal, or wrong-window/wrong-monitor ghost text.
- No pause, disable, or local trace deletion path.

## Current App Assessment

The app is much stronger than a raw prototype. It has Swift/AppKit plumbing,
local MLX runtime ownership, secure-field and app-denylist policy, a small
profile store, prompt-app guards, screenshot-backed placement proof, insertion
verification, accepted-text survival checks, typed-through tracking, local-only
privacy controls, and scripts that make missing proof visible.

It is not broad-compatible. That is good. The strict gates still fail for
Codex same-slice one-word no-submit proof, Claude Code terminal-host proof,
production Chrome editor/chat surfaces, and broader rich-editor variants. The
current app should be treated as a narrow lab build with strong TextEdit and
fixture proof, not a general system-wide inserter.

## Score

Starting score before this pass: 72/100

Overall score after this pass: 80/100

This is a strict compatibility score. It is not a general app-quality score.
Several individual surfaces score much higher, but hard gates prevent a broad
compatibility claim.

## Score Breakdown

### Surface identification

- Weight: 15
- Current score: 15/15
- Why this score: The repo has explicit app profiles, AX field classification,
  browser hosted-surface blocking, prompt fingerprints, and proof-manifest
  coverage. This pass added action-bearing browser hosted surfaces such as
  Gmail, ChatGPT, Claude web, Codex web, and Telegram web, plus trace-safe
  profile metadata for surface ID, version range, preferred path, and hard caps.
  This follow-up also persists that scope on learned/user-created compatibility
  profiles and upgrades legacy learned profiles on read.
- Evidence found in repo:
  - `CompatibilityProfileStore.mvp` in `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`
  - `AXFieldClassifier` in `Sources/AutocompleteLabCore/Session/AXFieldClassifier.swift`
  - `BrowserHostedSurfacePolicy` in `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`
  - `PromptEditorFingerprintPolicy` in `Sources/AutocompleteLabCore/Configuration/PromptEditorFingerprintPolicy.swift`
  - `CompatibilityLearningProfile` in `Sources/AutocompleteLabCore/Configuration/CompatibilityLearning.swift`
  - `CompatibilityLearningStore` in `Sources/AutocompleteLabApp/Mac/CompatibilityLearningStore.swift`
  - `docs/product/proof-manifest.json`
- Missing evidence: Browser support is still mostly Chrome bundle plus
  fingerprint heuristics. Production browser-site proof is scored in later
  categories rather than treated as broad compatibility.
- What would make it 100/100: Versioned compatibility profiles for every proven
  app/surface/path with hard caps, last-verified dates, and proof links.

### Caret and selection fidelity

- Weight: 15
- Current score: 12/15
- Why this score: Many surfaces have screenshot-backed caret placement and
  field identity guards. Selection replacement is suppressed. Some prompt and
  terminal-host cases still lack same-slice proof.
- Evidence found in repo:
  - `FocusedFieldIdentityPolicy`
  - `PlacementHealth`
  - `SuggestionOrchestrator.placementHealthPlan`
  - `docs/product/visual-placement-screenshots/`
  - `docs/product/app-proof-matrix.md`
- Missing evidence: Codex same-slice proof, Claude Code terminal-host screenshot
  proof, more production editor variants, and IME/selection matrix proof.
- What would make it 100/100: Current screenshot-backed caret/selection proof
  for every supported profile, including focus-switch and selected-range tests.

### Insertion correctness

- Weight: 20
- Current score: 15/20
- Why this score: The app verifies insertion, blocks selected text, checks
  visible acceptance proof, and now fast word completions use the same final
  stale-context refresh as model suggestions. Still, key real-app proof gaps
  remain.
- Evidence found in repo:
  - `InsertionEngine`
  - `InsertionVerification`
  - `SuggestionAcceptanceProofPolicy`
  - `AppDelegate.refreshedPresentationContext`
  - `AcceptanceSurvivalChecker`
  - `Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift`
  - `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceProofPolicyTests.swift`
- Missing evidence: Same-slice Codex proof, Claude Code terminal-host proof,
  broader production Chrome proof, and direct app-level flow tests around
  poll-request-present-accept-verify.
- What would make it 100/100: Every accept-enabled profile has current proof
  for exact insertion, no duplication, no cross-field leakage, and verification.

### Undo/redo integrity

- Weight: 15
- Current score: 9/15
- Why this score: The app has accepted-insertion undo support and TextEdit has
  recorded undo proof. Rich-editor and prompt-app undo coverage is incomplete.
- Evidence found in repo:
  - `AppDelegate.undoAcceptedInsertion`
  - `AcceptedInsertionUndo`
  - TextEdit undo row in `docs/product/app-proof-matrix.md`
  - Notes undo commands listed in `docs/product/manual-smoke-checklist.md`
- Missing evidence: Current undo/redo chain proof for Notes body/checklist,
  Obsidian, Chrome editor fixtures, Claude desktop, and prompt surfaces.
- What would make it 100/100: One accept equals one undo step for every
  accept-enabled profile, with redo and continued typing proof.

### Structure preservation

- Weight: 10
- Current score: 7/10
- Why this score: Notes title/body/checklist, Obsidian, Chrome Monaco, and
  ProseMirror fixtures have useful proof. Production rich editors and complex
  structures remain capped.
- Evidence found in repo:
  - Notes and Obsidian rows in `docs/product/app-proof-matrix.md`
  - Chrome real Monaco and ProseMirror proof in `docs/product/proof-manifest.json`
  - `BrowserHostedSurfacePolicy` blocks Google Docs and Notion until proof
- Missing evidence: Google Docs, Notion, production editors, tables, long rich
  documents, attachments, quotes, and more checklist variants.
- What would make it 100/100: Rich-editor proof that insertion preserves
  markdown, code, tables, checklists, quotes, and editor-owned state.

### No-submit / no-side-effect safety

- Weight: 15
- Current score: 13/15
- Why this score: Prompt-app full accept is disabled, Claude desktop has
  one-word no-submit proof, Chrome chat-like local fixture has no-submit proof,
  and this pass blocks more action-bearing browser surfaces until no-submit
  proof exists. The remaining manual proof gaps are still real.
- Evidence found in repo:
  - `CompatibilityProfile.supportsFullAcceptance`
  - `PromptEditorFingerprintPolicy`
  - `ClaudeCodeTerminalHostProofPolicy`
  - `BrowserHostedSurfacePolicy`
  - `Tests/AutocompleteLabAppTests/SettingsWindowControllerStateTests.swift`
  - `Tests/AutocompleteLabCoreTests/BrowserHostedSurfacePolicyTests.swift`
- Missing evidence: Codex same-slice one-word no-submit proof, Claude Code
  terminal-host proof, real Gmail/Slack/Discord/Telegram proof, and network/send
  observers for browser prompt apps.
- What would make it 100/100: No-submit proof for every action-bearing profile,
  with full accept disabled until separately proven.

### IME, composition, accessibility, performance

- Weight: 5
- Current score: 5/5
- Why this score: Accessibility reads are throttled, latency is measured,
  typing endurance proof is strong, and marked-text composition now suppresses
  suggestions before display or insertion.
- Evidence found in repo:
  - `FocusedTextAXHealthPolicy`
  - `FocusedTextPollingBackoffPolicy`
  - `FocusedTextPollLatencyStats`
  - `KeyboardEventTapIdleStopPolicy`
  - `CompletionActivationPolicy`
  - `FocusedTextCapabilities.hasMarkedText`
  - `script/typing_performance_endurance_soak.sh`
- Missing evidence: Real IME/dead-key manual proof across supported surfaces is
  still useful, but the app now has an automated fail-closed composition gate.
- What would make it 100/100: IME/dead-key/composition proof plus current
  performance proof on each supported profile.

### Test coverage and telemetry

- Weight: 5
- Current score: 4/5
- Why this score: The repo has strong unit tests, smoke scripts, proof
  manifests, trace replay, visual evidence checks, and telemetry-safe traces.
  The remaining gap is that strict manual gates still fail.
- Evidence found in repo:
  - `swift test` test targets in `Package.swift`
  - `script/smoke_test.sh`
  - `script/check_proof_manifest.sh`
  - `script/manual_smoke_status.sh`
  - `script/check_visual_placement_evidence.sh`
  - `script/scorecard_goal_loop.sh`
- Missing evidence: Passing require-all proof gates.
- What would make it 100/100: Require-all proof, manual smoke, visual evidence,
  and beta readiness gates pass on current build.

## 0/100 Definition

This area is 0/100 if the app inserts into the wrong field, submits a prompt or
message, shows in a secure field, sends typed text off-device by default,
corrupts the clipboard, causes normal typing lag, steals focus, or cannot be
paused/disabled/deleted locally.

## 50/100 Definition

The app has some profiles and suppression rules, but support is still mostly
bundle-level, manual proof is stale or incomplete, prompt/chat surfaces are not
clearly capped, and insertion correctness depends on happy-path behavior.

## 80/100 Definition

The app has narrow private-beta compatibility for a small set of surfaces, with
current bounded proof, secure/prompt/custom-editor hard caps, verified insertion
and placement, and honest failing gates for everything else.

## 100/100 Definition

Every claimed profile has current versioned proof for surface classification,
caret/selection, exact insertion, undo/redo, structure preservation, no-submit,
IME/composition, performance, and rollback. Unsupported profiles are blocked or
diagnostics-only by policy, not by accident.

## Failure Modes

1. Wrong-field insertion.
2. Accidental prompt/chat/email/shell/agent submit.
3. Secure-field or password-manager leakage.
4. Stale suggestion shown or inserted after app, field, text, or caret changes.
5. Duplicate, truncated, or cross-field insertion.
6. Undo stack corruption.
7. Rich-editor structure damage.
8. IME/composition breakage.
9. Normal typing latency.
10. Broad compatibility claims based on local fixtures only.

## Evidence Requirements

- Unit tests for every compatibility policy and hard cap.
- Bounded manual smoke rows in `docs/product/manual-smoke-runs.md`.
- Screenshot-backed rows for every visual profile.
- Trace replay with current proof fingerprints.
- Insertion verification for every accept-enabled profile.
- One-word no-submit proof for prompt/chat/message/email surfaces.
- Separate full-accept no-submit proof before enabling full accept there.
- Undo/redo proof for every accept-enabled surface above suggest-only.
- Performance soak with event-tap and AX polling budgets.
- Redacted privacy bundle proof and local trace deletion proof.

## Implementation Queue

### 1. Stale fast-word display gate

- Objective: Make instant word completions use the same final context refresh
  as model suggestions.
- Files likely involved:
  - `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- Tests to add/update:
  - App-level harness is still needed; current verification is compile plus
    related policy tests.
- Proof required:
  - Targeted Swift tests and future real-app trace showing fast-word display
    suppresses on stale focus/text.
- Risk level: Medium
- Expected score impact: +2 insertion correctness, +1 no-submit/stale safety.
- Status: Done in this pass.

### 2. Browser action-bearing hosted-surface blocks

- Objective: Treat Gmail, ChatGPT, Claude web, Codex web, Slack, Discord, and
  Telegram web as action-bearing browser surfaces that need no-submit proof.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`
  - `Tests/AutocompleteLabCoreTests/BrowserHostedSurfacePolicyTests.swift`
- Tests to add/update:
  - Add policy tests for action-bearing block reason and trace-safe metadata.
- Proof required:
  - `swift test --filter BrowserHostedSurfacePolicyTests`
- Risk level: Low
- Expected score impact: +2 surface identification and no-submit safety.
- Status: Done in this pass.

### 3. Versioned compatibility profile schema

- Objective: Store app plus surface plus version plus path plus hard caps as a
  first-class profile instead of mostly bundle-level profile data.
- Files likely involved:
  - `CompatibilityProfile.swift`
  - `proof-manifest.json`
  - settings/diagnostics state tests
- Tests to add/update:
  - Profile serialization and default MVP profile tests.
- Proof required:
  - Full Swift tests, proof manifest checks.
- Risk level: Medium
- Expected score impact: +3 surface identification.
- Status: App-owned metadata and learned compatibility profile scope are done.
  Legacy learned profiles upgrade on read. Last-verified/proof-link metadata is
  still future work.

### 4. IME/composition fail-closed gate

- Objective: Suppress suggestions while AX reports active marked text so the
  app does not interrupt IME/dead-key composition.
- Files likely involved:
  - `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`
  - `Sources/AutocompleteLabApp/Mac/AccessibilityClient.swift`
  - `Sources/AutocompleteLabApp/App/AppDelegate.swift`
- Tests to add/update:
  - `CompletionActivationPolicyTests`
  - App-target compile path through `SuggestionOrchestratorTests`
- Proof required:
  - Focused Swift tests and future manual IME proof.
- Risk level: Low
- Expected score impact: +1 IME/composition safety.
- Status: Done in this follow-up.

### 5. Codex same-slice one-word no-submit proof

- Objective: Record one bounded Codex proof slice with screenshot, one-word Tab
  accept, and no submit.
- Files likely involved:
  - `docs/product/manual-smoke-runs.md`
  - `docs/product/proof-manifest.json`
  - screenshots folder
- Tests to add/update:
  - Existing proof scripts.
- Proof required:
  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate`
- Risk level: Medium
- Expected score impact: +3 no-submit and visual proof.

### 6. Claude Code terminal-host proof

- Objective: Prove terminal-hosted Claude Code one-word accept without shell or
  agent submit.
- Files likely involved:
  - `ClaudeCodeTerminalHostProofPolicy.swift`
  - manual smoke docs and proof manifest
- Tests to add/update:
  - Existing terminal-host proof tests plus manual proof row.
- Proof required:
  - `script/real_app_smoke.sh claude-code --manual-gate`
- Risk level: High
- Expected score impact: +4 compatibility confidence.

## Codex Execution Goal

Improve app compatibility safety by making browser action-bearing surfaces fail
closed until no-submit proof exists and by preventing fast word completions from
displaying unless the focused app, surface, field, text, and browser/prompt
policy are still current.

## Stop Conditions

This goal is complete when:

- The scorecard exists under `docs/product/`.
- Browser action-bearing surfaces are blocked with trace-safe metadata.
- Fast word completions use the final stale-context refresh before display.
- Targeted tests pass.
- Broader relevant checks either pass or fail only on known manual proof gaps.
- Changes are committed and pushed from the isolated worktree.

## Remaining Gaps

- Codex still needs current same-slice screenshot plus one-word no-submit proof.
- Claude Code still needs terminal-host manual proof.
- Chrome production editor/chat surfaces need real site proof before broadening.
- Learned compatibility profiles now carry versioned scope; last-verified and
  proof-link metadata is still not stored directly on learned profiles.
- IME/dead-key and undo/redo matrix proof remains incomplete.
- A full app-level non-AX harness would make trust flow testing much stronger.
