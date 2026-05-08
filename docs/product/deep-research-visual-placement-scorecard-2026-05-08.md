# Visual Placement Scorecard - 2026-05-08

## Source

- Deep Research topic: Visual Placement Rubric for Autocomplete Ghost Text
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14dee37a4c8a44d89f1059f8a2aec9ca4e40` plus the local display-selection and insertion-verification fail-closed passes

## Executive Summary

The research says placement has to feel native or disappear. For this app, that means the overlay must stay bound to the focused editable field, same window, same display, fresh caret geometry, and a safe render mode. The repo has serious placement infrastructure already, but the proof is not current enough for a 90+ score and there was one fail-open display risk in the panel controller.

Current score after this pass: **75/100**.

## Product Standard

Excellent visual placement means inline ghost text starts where the next glyph would appear, with 0-4 px horizontal error and <= 2 px baseline mismatch. Floating panels must anchor 8 px right and 6 px below the caret when possible, never cover the current line when safer space exists, stay fully inside the active display work area, and hide within 100 ms when geometry becomes stale.

## Non-Negotiables

- Wrong-window placement blocks beta.
- Wrong-monitor placement blocks beta.
- Offscreen placement blocks beta.
- Stale panel visible after focus, scroll, window move, or text change blocks beta.
- Axis inversion or double-scaling blocks beta.
- Showing in secure/private fields blocks beta.
- Detached whole-window or whole-field suggestions are blocked unless that surface explicitly allows them and has proof.
- Screenshots are proof only, not runtime placement truth.

## Current App Assessment

The app has a strong geometry core: AX bounds validation, caret correction, line-rect rejection, clipping, profile-based render modes, low-confidence suppression, redacted geometry trace metadata, screenshot artifacts, and visual evidence scripts. TextEdit and Chrome fixture proof exists, and risky apps are narrow or mirror-first.

The score stays at 75 because real-app proof is stale or incomplete for several required surfaces, the research-required debug screenshot bundle is not complete, and there is no recorder-grade proof for mixed-scale monitor moves, current Codex no-submit acceptance, Claude Code, or Claude desktop. This pass fixed the panel controller so an anchor that cannot be mapped to a real screen suppresses instead of falling back to the main display.

Continuation note: the next automatable trust gap fixed post-accept verification so app/context/field mismatches trace as insertion failures and suppress the original field. That improves insertion trust, but the visual-placement score stays at 75 until fresh recorder-grade app proof exists.

## Score

Overall score: **75/100**

Starting score before this pass: **72/100**

## Score Breakdown

### Anchor Accuracy

- Weight: 30
- Current score: 24/30
- Why this score: AX bounds validation, `CaretRectResolver`, `AccessibilityTextBoundsPolicy`, `InlineGhostPlacementResolver`, and existing screenshots prove a real placement engine. Missing recorder-grade pixel offset/baseline evidence keeps this below excellent.
- Evidence found in repo: `Sources/AutocompleteLabCore/Geometry/CaretRectResolver.swift`, `Sources/AutocompleteLabCore/Geometry/AccessibilityTextBoundsPolicy.swift`, `Sources/AutocompleteLabCore/Compatibility/InlineGhostPlacementResolver.swift`, `Tests/AutocompleteLabCoreTests/CaretRectResolverTests.swift`, `Tests/AutocompleteLabCoreTests/AccessibilityTextBoundsPolicyTests.swift`, `docs/product/visual-placement-screenshots/*.png`.
- Missing evidence: 2x/4x crops, baseline measurements, debug overlays with expected anchor and actual overlay.
- What would make it 100/100: current screenshot-backed pixel audits for each target surface with <= 4 px horizontal error and <= 2 px baseline mismatch.

### Freshness

- Weight: 20
- Current score: 14/20
- Why this score: async suggestions refresh focused context before display, stale request cancellation exists, typing-through hides visible suggestions, and display-layout changes invalidate state. There is not enough current proof that scroll/window/layout changes hide within 100 ms.
- Evidence found in repo: `AppDelegate.refreshedPresentationContext`, `SuggestionGeometryChangePolicy`, `hideStaleSuggestionIfNeeded`, `AutocompleteTraceReplayTests`.
- Missing evidence: AX observer implementation proof, explicit 100 ms stale-age watchdog proof, scroll/window-move proof.
- What would make it 100/100: trace slices and tests proving stale panel count is zero after focus, selection, value, layout, scroll, resize, and display changes.

### Viewport Discipline

- Weight: 15
- Current score: 12/15
- Why this score: inline and mirror frames clip to screen/editor bounds, cramped inline width suppresses display, and this pass added fail-closed screen selection for offscreen anchors.
- Evidence found in repo: `SuggestionPanelFrameCalculator`, `SuggestionPanelFrameCalculatorTests`, `SuggestionDisplaySelectionPolicy`, `SuggestionDisplaySelectionPolicyTests`, `SuggestionPanelController.show`.
- Missing evidence: current screenshot proof for clipping in all target surfaces and scroll containers.
- What would make it 100/100: clipped ghost count and offscreen placement count both stay zero in automated and manual proof.

### Window And Display Correctness

- Weight: 15
- Current score: 11/15
- Why this score: coordinate conversion and screen layout invalidation exist, and this pass removed the main-screen fallback when an anchor is outside every display. Mixed-scale monitor movement still lacks current proof.
- Evidence found in repo: `AccessibilityCoordinateConverter`, `AccessibilityCoordinateConverterTests`, `SuggestionGeometryChangePolicy`, `SuggestionDisplaySelectionPolicy`, `AppDelegate.displayGeometryDidChange`.
- Missing evidence: mixed 1x/2x monitor drag, window spanning displays, same-window metadata in screenshot debug overlays.
- What would make it 100/100: zero wrong-display events and zero double-scale events across mixed-scale display proof.

### Editor-Specific Correctness

- Weight: 10
- Current score: 5/10
- Why this score: TextEdit, Notes, Chrome, Obsidian, Codex, Claude, and terminal-like denylist profiles exist, but real Monaco, real ProseMirror, Obsidian, Codex no-submit, Claude Code, and Claude desktop proof remain incomplete.
- Evidence found in repo: `CompatibilityProfileStore.mvp`, `CompatibilityProfileTests`, `docs/product/compatibility-matrix.md`, `docs/product/proof-manifest.json`.
- Missing evidence: current real-app proof for the research list, especially CodeMirror/Monaco off-viewport suppression.
- What would make it 100/100: each app/editor family has current proof, or it stays explicitly suppressed.

### Mode Choice Quality

- Weight: 10
- Current score: 9/10
- Why this score: the app prefers inline only for proven surfaces, mirror for risky prompt/rich-editor contexts, and suppression when detached anchors are not allowed. The remaining point is blocked by stale/manual proof, not obvious policy shape.
- Evidence found in repo: `RenderModePlan`, `PlacementHealth`, `SuggestionPlacementPreflightPolicy`, `CompatibilityProfileTests`, `SettingsWindowControllerStateTests`.
- Missing evidence: current traces showing mode choice stays conservative across all target apps.
- What would make it 100/100: every low-confidence path chooses floating or suppresses with trace evidence.

## 0/100 Definition

This area is 0/100 if the app can show a suggestion in the wrong window, wrong monitor, offscreen, over a secure/private field, or after stale focus/caret/text state, or if it inserts based on a stale visible suggestion.

## 50/100 Definition

The app can usually place a floating panel near a caret in one or two apps, but it has visible drift, weak stale hiding, limited clipping, and little real screenshot proof.

## 80/100 Definition

The app is private-beta-safe for narrow target apps: TextEdit and core Chrome fixtures have current proof, risky apps are mirror-first or off, offscreen/wrong-display cases fail closed, and manual proof gaps are honest.

## 100/100 Definition

The app feels native everywhere it claims support. Anchor error is <= 4 px, baseline mismatch is <= 2 px, stale/clipped/offscreen/wrong-window counts are zero, mixed-scale displays are proven, and unsupported editor states suppress.

## Failure Modes

1. Wrong-window or wrong-monitor overlay.
2. Stale overlay after focus, scroll, resize, display move, or text change.
3. Offscreen or clipped overlay.
4. Axis inversion or double-scale Retina bug.
5. Whole-field/window detached suggestion where a caret is required.
6. Browser/editor collapsed-range or wrapped-line stale rect.
7. Monaco/CodeMirror off-viewport geometry guessed instead of suppressed.
8. Floating panel covers the active line when safer space exists.
9. Inline baseline drift makes the overlay feel foreign.

## Evidence Requirements

- `swift test --filter SuggestionDisplaySelectionPolicyTests`
- `swift test --filter SuggestionPanelFrameCalculatorTests`
- `swift test --filter PlacementHealthTests`
- `swift test --filter SuggestionGeometryChangePolicyTests`
- `./script/check_visual_placement_evidence.sh`
- `./script/check_proof_manifest.sh`
- `./script/manual_smoke_status.sh --strict`
- Fresh screenshot-backed manual proof for TextEdit, Notes title/body/checklist, Chrome textarea/contenteditable/editor fixtures/chat-like, Obsidian, Codex, Claude Code, Claude desktop, and mixed-scale display drag.
- Debug screenshot bundle with full screenshot, crop, AX rect, expected anchor, actual overlay rect, display id, scale factor, focused app/window metadata, and geometry age.

## Implementation Queue

1. Objective: fail closed when an anchor cannot be assigned to a real display.
   Files likely involved: `SuggestionPanelController.swift`, new core display-selection policy, core tests.
   Tests to add/update: `SuggestionDisplaySelectionPolicyTests`.
   Proof required: targeted unit test plus visual evidence scripts.
   Risk level: Low.
   Expected score impact: +3.

2. Objective: add an explicit 100 ms visible-stale watchdog for placement invalidation.
   Files likely involved: `AppDelegate.swift`, new core freshness policy.
   Tests to add/update: pure freshness policy tests and app-state tests if extractable.
   Proof required: trace event showing stale hide <= 100 ms.
   Risk level: Medium.
   Expected score impact: +4.

3. Objective: create recorder-grade debug screenshot bundles.
   Files likely involved: screenshot capture, trace metadata, visual report scripts.
   Tests to add/update: screenshot report self-tests.
   Proof required: full-screen plus crop plus debug overlay artifacts.
   Risk level: Medium.
   Expected score impact: +6.

4. Objective: refresh manual visual proof for stale surfaces.
   Files likely involved: `docs/product/manual-smoke-runs.md`, proof manifest, screenshot assets.
   Tests to add/update: proof manifest and visual evidence checks.
   Proof required: real app runs with disposable text.
   Risk level: Medium because it needs user-gated apps/permissions.
   Expected score impact: +10.

## Codex Execution Goal

Raise visual placement from 72/100 by closing the highest-risk automatable gap first: ensure anchors outside every known screen fail closed, keep the proof index honest, run targeted tests/checks, and leave the remaining score blocked only by manual recorder-grade app proof.

## Stop Conditions

- Offscreen anchors suppress instead of falling back to the main display.
- Existing screenshot files are referenced honestly by the scorecard/proof checks.
- Targeted tests for the new policy pass.
- Relevant visual/proof scripts either pass or fail only for manual proof gaps.
- No broad compatibility claim is added.

## Remaining Gaps

- Manual app proof is still needed for stale surfaces.
- Mixed-scale monitor drag cannot be fully proven by unit tests.
- Real Codex/Claude prompt no-submit proof requires safe live prompt runs.
- Debug overlay screenshot bundles are not complete.
- No current proof shows visible stale overlays always hide within 100 ms after scroll/window moves.
