# Visual Placement Scorecard - 2026-05-08

## Source

- Deep Research topic: Visual Placement Rubric for Autocomplete Ghost Text
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `c23ead55140f884f73b1e746f7b6b2184ff13375` plus
  implementation changes recorded in this file.

## Executive Summary

The research standard is simple: suggestions must belong to the live caret, not
roughly to the editor box. This repo is much stronger than a raw lab prototype:
it has caret-first placement, suppression gates, screenshot proof, proof
manifests, and real app smoke tooling.

The strict score is still not near 100 because visual placement is only as good
as its weakest stale or wrong-surface case. Codex and Claude Code proof are not
closed, production browser/editor variants are not broadly proven, vertical
multi-display behavior is not tested enough, and one geometry proof script is
stale against the current trace metadata.

## Product Standard

Excellent behavior for this app means:

- Place from the current caret or collapsed selection when possible.
- Use floating panel mode when inline ghost text would be visually dishonest.
- Suppress on uncertain geometry, stale focus, stale text, stale field identity,
  offscreen anchors, secure/private fields, active composition, prompt submit
  risk, or unsupported browser/editor surfaces.
- Never show in the wrong window, wrong pane, or wrong monitor.
- Never keep a visible suggestion after geometry becomes stale.
- Prove every supported surface with bounded screenshots, trace slices,
  insertion verification, and no-submit evidence for prompt apps.

## Non-Negotiables

These block beta for this area or force the relevant category to zero:

- Wrong-window, wrong-pane, or wrong-monitor ghost text.
- Stale suggestion visible after focus, caret, text, scroll, resize, or display
  changes.
- Inline placement from a guessed element frame when caret geometry is missing.
- Prompt/chat field suggestion that can submit by accident.
- Password, token, payment, login, terminal, or private field display.
- Raw typed text or screenshots stored without explicit opt-in.
- Mock or local fixture proof represented as broad app compatibility.
- App steals focus while showing the overlay.
- Clipboard corruption during placement proof or insertion proof.

## Current App Assessment

This repo has real visual-placement engineering. `AccessibilityClient` reads AX
caret and line bounds. `PlacementHealth` gates inline, mirror, synthetic, and
low-confidence placement. `SuggestionPanelController` converts AX rectangles,
calculates frames, clamps to screen/clipping bounds, and suppresses unusable
inline frames. Tests cover negative-origin screens, zero-width carets, clipping,
synthetic caret trust, screenshot offset detection, and stale text-line rects.

The baseline weak spots were also concrete. `script/geometry_trace_report.py`
expected old `anchorSource` metadata even though current presentation traces use
`placementAnchorSource` and `placementConfidenceBand`; this pass fixed that.
The live panel conversion had no core helper or tests for vertically arranged
monitors; this pass added both. The remaining weak spots are manual proof and
deeper invalidation: strict proof still fails for Codex same-slice no-submit
proof, Claude Code terminal-host proof, and some partial browser/editor
manifest gates, and the app still lacks full window/scroll/display revision
tokens. A later hardening pass also made stable-bounds field identity
deterministic instead of process-random, which makes replay and trace evidence
more comparable across lab app launches.

## Score

Starting score: 82/100

Overall score: 85/100

Current score after this pass: 85/100

## Score Breakdown

### Geometry Source Quality

- Weight: 25
- Current score: 22
- Why this score: The app prefers caret and text-line geometry, has synthetic
  caret support for hard prompt/editor surfaces, and blocks detached placement
  for risky profiles. It still lacks host-native CodeMirror/ProseMirror/Monaco
  geometry integrations and has a Chrome descendant fallback that can choose the
  first editable descendant when focus metadata is poor.
- Evidence found in repo: `Sources/AutocompleteLabApp/Mac/AccessibilityClient.swift`;
  `Sources/AutocompleteLabCore/Geometry/PlacementHealth.swift`;
  `Sources/AutocompleteLabCore/Geometry/SyntheticCaretEstimator.swift`;
  `Tests/AutocompleteLabCoreTests/PlacementHealthTests.swift`.
- Missing evidence: Direct host-native editor caret APIs and multiple-editable
  Chrome descendant proof.
- What would make it 100/100: Every supported app uses caret/editor-native
  geometry first, with no element-frame fallback unless explicitly proven safe
  for panel mode.

### Coordinate Normalization

- Weight: 20
- Current score: 17
- Why this score: AX-to-AppKit conversion is isolated and tested for top-left
  origin, negative-X displays, and screens above/below the main display. The
  live panel now uses the core screen-selection helper. It still needs mirrored,
  fullscreen, separate Spaces, and real screenshot proof across display layouts.
- Evidence found in repo: `Sources/AutocompleteLabCore/Geometry/AccessibilityCoordinateConverter.swift`;
  `Tests/AutocompleteLabCoreTests/AccessibilityCoordinateConverterTests.swift`;
  `Sources/AutocompleteLabApp/UI/SuggestionPanelController.swift`.
- Missing evidence: Mirrored displays, separate Spaces behavior, fullscreen
  display proof, and screenshot proof around vertical monitor layouts.
- What would make it 100/100: A canonical logical coordinate pipeline with
  explicit per-screen conversion and screenshot proof on horizontal, vertical,
  mirrored, fullscreen, and Retina display setups.

### Freshness And Invalidation

- Weight: 15
- Current score: 13
- Why this score: Requests are ticketed, focus/app/field/text are refreshed
  before presentation, stale app/field/text is suppressed, and stale line rects
  far from the caret are dropped. This pass added a geometry-age cap so visible
  suggestions are not preserved through AX throttle/cooldown windows once their
  placement is older than the safety threshold. It still lacks full
  window-move, scroll, display-change, and revision-token invalidation.
- Evidence found in repo: `Sources/AutocompleteLabApp/App/SuggestionOrchestrator.swift`;
  `Sources/AutocompleteLabApp/App/AppDelegate.swift`;
  `Tests/AutocompleteLabAppTests/SuggestionOrchestratorTests.swift`;
  `Sources/AutocompleteLabCore/Session/FocusedTextPollingThrottleSuggestionVisibilityPolicy.swift`;
  `Sources/AutocompleteLabCore/Session/FocusedTextAXHealthSuggestionVisibilityPolicy.swift`;
  `Tests/AutocompleteLabCoreTests/FocusedTextPollingThrottleSuggestionVisibilityPolicyTests.swift`;
  `Tests/AutocompleteLabCoreTests/FocusedTextAXHealthSuggestionVisibilityPolicyTests.swift`.
- Missing evidence: Window-move/display-change invalidation tests, scroll
  invalidation tests, and a full focus/selection/geometry revision token.
- What would make it 100/100: Every visible panel is versioned against focus,
  field, selection, text, viewport, window, screen, and geometry revision; stale
  panels are impossible to preserve.

### Viewport, Scroll, And Display Handling

- Weight: 15
- Current score: 12
- Why this score: Frame calculators clamp to screens and editor clipping bounds;
  screenshots and smoke proof cover many app surfaces. Scroll, fullscreen,
  vertical monitor, and production virtualized-editor proof remain incomplete.
- Evidence found in repo: `Sources/AutocompleteLabCore/Geometry/SuggestionPanelFrameCalculator.swift`;
  `Tests/AutocompleteLabCoreTests/SuggestionPanelFrameCalculatorTests.swift`;
  `docs/product/visual-placement-screenshots/`;
  `docs/product/manual-smoke-runs.md`.
- Missing evidence: Multi-display vertical layouts, fullscreen spaces,
  kinetic scroll, zoom/font swaps, and off-viewport virtualized editor proof.
- What would make it 100/100: Screenshot-backed certification on required host
  states: line start/middle/end, wraps, scroll, resize, fullscreen, secondary
  display, and focus change.

### App And Editor Specific Integrations

- Weight: 10
- Current score: 8
- Why this score: The repo honestly scopes support and has proof for TextEdit,
  Notes title/body/checklist, Obsidian, Chrome fixtures, real Monaco/ProseMirror
  lanes, and Claude desktop. It blocks Google Docs, Notion, Slack, and Discord
  until proof exists. Codex and Claude Code remain open.
- Evidence found in repo: `Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift`;
  `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`;
  `docs/product/app-proof-matrix.md`;
  `docs/product/proof-manifest.json`.
- Missing evidence: Codex same-slice no-submit proof, Claude Code terminal-host
  proof, and production browser/editor variants.
- What would make it 100/100: Every claimed surface has current bounded proof,
  and every unclaimed surface is blocked or diagnostics-only.

### Suppression Discipline

- Weight: 10
- Current score: 9
- Why this score: The app strongly prefers suppression over risky display:
  secure fields, selected text, unsupported hosted browser surfaces, detached
  prompt anchors, low-confidence placement, and stale app/field/text are blocked.
  The remaining risk is stale geometry preservation during throttled AX reads.
- Evidence found in repo: `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift`;
  `Sources/AutocompleteLabCore/Configuration/BrowserHostedSurfacePolicy.swift`;
  `Sources/AutocompleteLabCore/Geometry/PlacementHealth.swift`;
  `Sources/AutocompleteLabApp/App/AppDelegate.swift`.
- Missing evidence: Geometry-age suppression under AX throttle and window moves.
- What would make it 100/100: No visible suggestion can survive uncertainty in
  focus, field, geometry, scroll, display, or prompt submit state.

### Proof And Observability

- Weight: 5
- Current score: 4
- Why this score: This repo has screenshots, manual smoke logs, proof manifest
  checks, trace replay, visual evidence checks, and diagnostics. Strict gates
  still fail honestly. This pass fixed `geometry_trace_report.py` so it can
  validate current `placementAnchorSource` and `placementConfidenceBand`
  metadata; the recent Chrome trace slice now reports zero geometry proof
  failures.
- Evidence found in repo: `script/check_visual_placement_evidence.sh`;
  `script/check_proof_manifest.sh`; `script/manual_smoke_status.sh`;
  `script/geometry_trace_report.py`; `docs/product/proof-manifest.json`.
- Missing evidence: Current-commit manifest and complete Codex/Claude Code
  proof rows.
- What would make it 100/100: One current proof command can verify all claimed
  surfaces, screenshots, trace metadata, insertion verification, stale
  cancellation, and no-submit evidence without stale docs.

## 0/100 Definition

The app places from approximate element/window frames, has no canonical
coordinate handling, shows stale suggestions after focus or caret changes, has
no screenshot proof, or displays in secure/private/prompt-submit-risk fields.

## 50/100 Definition

The app works in TextEdit or one easy native case, but guesses in browser/editor
hosts, lacks strict suppression, drifts during scroll/resize, and has mostly
manual or stale proof.

## 80/100 Definition

The app is private-beta strong for a narrow app set. It uses caret/synthetic
caret geometry, clamps panels, suppresses uncertain placement, and has
screenshot proof for major target surfaces. Prompt apps and edge display/editor
cases still need proof.

## 100/100 Definition

Every supported host has a current caret-anchored geometry pipeline, explicit
coordinate normalization, strict invalidation, zero stale/wrong-window telemetry,
and screenshot/trace proof across native, browser, editor, prompt, multi-monitor,
scroll, resize, and fullscreen states. Unknown cases suppress immediately.

## Failure Modes

1. Overlay appears in the wrong window, pane, app, or monitor.
2. Stale overlay remains after focus, text, caret, scroll, resize, or display
   change.
3. Prompt app accepts or submits text accidentally.
4. Overlay appears in secure/private fields.
5. Inline ghost is drawn from element/window frame instead of caret.
6. AX coordinate conversion flips Y or chooses the wrong screen.
7. Browser/contenteditable/editor virtualized layout drifts or clips.
8. Screenshot/manual proof is stale but still treated as current.
9. Floating panel covers typed text, send buttons, chips, or editor controls.
10. App steals focus or captures keys while placement is uncertain.

## Evidence Requirements

- Swift tests for coordinate conversion, panel frames, placement health,
  synthetic caret, screenshot offset detection, and stale geometry policy.
- Manual smoke rows with bounded trace line ranges and `visual strict-complete`.
- Tracked screenshots for each supported surface.
- `check_visual_placement_evidence.sh --strict` and
  `check_proof_manifest.sh --strict` passing for completed rows.
- Trace replay requiring placement metadata, proof fingerprints, verified
  insertions, stale cancellation, and accepted/kept outcomes.
- Geometry trace reports that understand current `placement*` metadata.
- Prompt-app proof with screenshot + one-word Tab accept + no-submit signal in
  the same bounded slice.
- Multi-display, fullscreen, scroll, resize, and wrapped-line proof.

## Implementation Queue

### 1. Add stale visible-suggestion geometry guards

- Status: Done in this pass.
- Objective: prevent visible suggestions from surviving AX throttle/cooldown
  windows after their geometry is too old to trust.
- Files likely involved:
  `Sources/AutocompleteLabCore/Session/FocusedTextPollingThrottleSuggestionVisibilityPolicy.swift`;
  `Sources/AutocompleteLabCore/Session/FocusedTextAXHealthSuggestionVisibilityPolicy.swift`;
  `Sources/AutocompleteLabApp/App/AppDelegate.swift`.
- Tests to add/update:
  `Tests/AutocompleteLabCoreTests/FocusedTextPollingThrottleSuggestionVisibilityPolicyTests.swift`;
  `Tests/AutocompleteLabCoreTests/FocusedTextAXHealthSuggestionVisibilityPolicyTests.swift`.
- Proof required: targeted Swift tests plus full `swift test`.
- Risk level: Medium.
- Expected score impact: +2 to +3.

### 2. Update geometry trace report for current metadata

- Status: Done in this pass.
- Objective: make proof tooling validate current placement metadata instead of
  failing fresh traces that use `placementAnchorSource`.
- Files likely involved: `script/geometry_trace_report.py`;
  `script/geometry_trace_report_self_test.sh`.
- Tests to add/update: `script/geometry_trace_report_self_test.sh`.
- Proof required: self-test plus a fresh bounded trace report command.
- Risk level: Low.
- Expected score impact: +1 to +2.

### 3. Add screen-aware conversion tests and helper

- Status: Done in this pass for the core helper and above/below display tests.
- Objective: cover vertical multi-monitor and per-screen conversion risk.
- Files likely involved:
  `Sources/AutocompleteLabCore/Geometry/AccessibilityCoordinateConverter.swift`;
  `Sources/AutocompleteLabApp/UI/SuggestionPanelController.swift`.
- Tests to add/update:
  `Tests/AutocompleteLabCoreTests/AccessibilityCoordinateConverterTests.swift`.
- Proof required: tests for above/below displays and negative origins.
- Risk level: Medium.
- Expected score impact: +2.

### 4. Finish Codex prompt proof

- Objective: close the biggest prompt-app visual-placement gap.
- Files likely involved: proof docs and committed screenshot only if the run
  produces disposable proof.
- Tests to add/update: none unless recorder drift is found.
- Proof required:
  `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate`.
- Risk level: High manual risk because the app must not submit.
- Expected score impact: +4 to +6.

### 5. Finish Claude Code terminal-host proof

- Objective: prove the terminal-host lane can display and accept one word
  without submitting shell or agent input.
- Files likely involved: proof docs and possibly terminal-host policy.
- Tests to add/update:
  `Tests/AutocompleteLabCoreTests/ClaudeCodeTerminalHostProofPolicyTests.swift`
  if gaps are found.
- Proof required:
  `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate`.
- Risk level: High manual risk.
- Expected score impact: +3 to +5.

## Codex Execution Goal

Raise visual-placement trust by closing automatable stale-geometry and proof-tool
gaps without broadening app support claims. Implement stale visible-suggestion
guards for AX throttle/cooldown preservation, update geometry trace proof tooling
to current placement metadata, run targeted tests and relevant proof self-tests,
then update this scorecard with the new score and remaining manual proof.

## Stop Conditions

- The score reaches 100/100, or
- all automatable changes in this pass are complete and remaining work is manual
  app proof, or
- a hard environment blocker prevents safe proof, or
- the remaining work would require unsafe prompt/terminal behavior.

## Remaining Gaps

- Codex needs screenshot + one-word Tab accept + no-submit proof in one strict
  bounded trace slice.
- Claude Code needs terminal-host screenshot/no-submit proof.
- Production browser/editor variants remain intentionally blocked or partial.
- Vertical/mirrored/fullscreen multi-display proof is incomplete.
- Host-native editor geometry APIs are not integrated.
- Current proof manifest source commit is stale against the inspected commit.

## Implementation Pass - 2026-05-08

Score movement: 82/100 to 85/100.

What changed:

- Added a maximum preserved geometry age for visible suggestions during focused
  text AX throttle and AX health cooldown windows.
- Wired the app to hide old visible suggestions instead of preserving them when
  fresh geometry cannot be trusted.
- Added tests for stale visible suggestions and unknown-age preservation.
- Added a core screen-selection helper and tests for screens above and below the
  main display.
- Updated the geometry trace report to understand current placement metadata:
  `placementAnchorSource`, `placementConfidenceBand`, and
  `placementHealthReason`.

Verification:

- `swift test --filter 'FocusedTextPollingThrottleSuggestionVisibilityPolicyTests|FocusedTextAXHealthSuggestionVisibilityPolicyTests'` passed 14 tests.
- `swift test --filter 'AccessibilityCoordinateConverterTests|FocusedTextPollingThrottleSuggestionVisibilityPolicyTests|FocusedTextAXHealthSuggestionVisibilityPolicyTests'` passed 21 tests.
- `swift test --filter 'AccessibilityCoordinateConverterTests|AnchorPlanTests|PlacementHealthTests|ScreenshotCaptureRegionTests|ScreenshotPlacementOffsetDetectorTests|ScreenshotTraceCapturePolicyTests|SuggestionPanelFrameCalculatorTests|SyntheticCaretEstimatorTests|VisualPlacementGeometryCorrectionPolicyTests'` passed 67 tests.
- `swift build` passed.
- `swift test` passed 716 tests.
- `./script/geometry_trace_report_self_test.sh` passed.
- `./script/geometry_trace_report.py --trace ~/Library/Logs/AutocompleteLab/traces.jsonl --start-line 56300 --require-proof` passed with 0 geometry proof failures.
- `./script/check_visual_placement_evidence.sh` passed in report mode with 15 screenshots verified.
- `./script/check_proof_manifest.sh` passed in report mode.
- `./script/check_visual_placement_evidence.sh --strict` still fails for Codex stale same-slice no-submit proof and Claude Code missing screenshot proof.
- `./script/check_proof_manifest.sh --strict` still fails for partial Chrome text fields, browser editor fixtures, Chrome chat-like composer, Codex, and pending Claude Code.
- `./script/check_score_targets.sh` still fails with 69 expected target and
  strict proof-gate misses.
