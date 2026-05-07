# Caret-Locked Autocomplete Research Queue

This queue turns `/Users/redbars/Downloads/deep-research-report.md` into repo-specific work for Autocomplete Lab.

The core lesson is simple: AX should be the first path, not the only path. The app needs to trust caret geometry only after validation, then fall back through line, field, window, and off modes without surprising the user.

## Landed From This Pass

- [x] Reject AX text bounds that are nonfinite, zero-height, or outside the focused element/window.
- [x] Stop polling at a zero-second interval.
- [x] Add a bounded polling policy: fast while visible, slower while watching a supported app, slower again when idle or missing Accessibility trust.
- [x] Suppress deletion-triggered suggestion requests.
- [x] Delay large paste-style text changes instead of immediately requesting a suggestion.
- [x] Suppress more answer-like model outputs such as `Here's`, `You can`, `As an AI`, and `I'd suggest`.
- [x] Extract Codex synthetic caret math into a pure tested core helper.
- [x] Add tests for bounds validation, polling cadence, paste/delete triggering, answer-like output cleanup, and synthetic caret geometry.

## P0: Trust And Safety

- [ ] Make raw trace capture opt-in by default.
- [ ] Add explicit trace privacy modes: `lab`, `dogfood`, `beta`, `customer`.
- [ ] In beta/customer mode, never persist `textBeforeCursor`, `textAfterCursor`, raw model output, displayed suggestion text, or accepted text.
- [ ] Keep counts, app bundle id, role, geometry state, latency, and reason codes in redacted traces.
- [ ] Add a redacted trace event type in core.
- [ ] Add tests that redacted traces keep useful metadata but drop typed text.
- [ ] Disable screenshot tracing outside lab/dogfood mode.
- [ ] Require a visible local toggle before screenshot tracing can start.
- [ ] Add a diagnostic banner when raw tracing is enabled.
- [ ] Expand sensitive app denylist beyond Terminal and password managers.
- [ ] Suppress in Mail compose until a safe adapter exists.
- [ ] Suppress in payment, password, API key, and token-looking fields when detectable.
- [ ] Suppress in unknown apps by default.
- [ ] Add a "why no suggestion" reason for sensitive suppression.
- [ ] Add tests for sensitive profiles having no insertion modes.
- [ ] Add tests for trace redaction of diagnostics metadata.

## P0: First-Class Anchor Ladder

- [ ] Add `SuggestionAnchorSource`: caret, line, field, window, none.
- [ ] Add `SuggestionAnchorQuality`: trusted, usableFallback, diagnosticsOnly, invalid.
- [ ] Replace bare `RenderModePlan.anchorRect` with a decision object that includes source, quality, reason, and rect.
- [ ] Prefer caret mode when selected range and bounds validate.
- [ ] Add line mode when insertion line or text line bounds are good but caret is missing.
- [ ] Add field mode when element bounds are good but caret is not.
- [ ] Add window mode only for explicit invocation or diagnostics.
- [ ] Keep off mode as the default for no trustworthy text context.
- [ ] Treat detached whole-editor anchors as a bug unless the profile allows them.
- [ ] Add tests for caret, line, field, window, and off decisions.
- [ ] Add tests for profiles that disallow detached field/window suggestions.
- [ ] Add trace metadata for anchor source, anchor quality, and fallback reason.
- [ ] Show anchor source in diagnostics.
- [ ] Update the compatibility matrix with anchor source and proof state.

## P0: AX Geometry Validation

- [ ] Capture `AXVisibleCharacterRange`.
- [ ] Capture `AXInsertionPointLineNumber`.
- [ ] Capture supported AX attributes and parameterized attributes as a compact capability snapshot.
- [ ] Record AX errors by attribute without raw text.
- [ ] Record AX timeout/cannot-complete errors.
- [ ] Validate caret rect against element rect.
- [ ] Validate caret rect against window rect.
- [ ] Validate caret rect against current screen frame after coordinate conversion.
- [ ] Validate text line rect against element/window rect.
- [ ] Reject jumps that move too far from the previous caret while text did not change.
- [ ] Reject stale caret rects after scroll or focus churn.
- [ ] Add a short geometry history per field.
- [ ] Add reason codes: zeroHeight, nonfinite, outsideElement, outsideWindow, offScreen, stale, jumpedTooFar, missingBounds.
- [ ] Add tests for zero-width caret rects.
- [ ] Add tests for browser zero-height caret rects.
- [ ] Add tests for outside-field and outside-window rects.
- [ ] Add tests for stale geometry rejection.
- [ ] Add tests for wrapped line rect validation.
- [ ] Add tests for visible range mismatch.

## P0: Observer-First Updates

- [ ] Add `AccessibilityObserver` in `Sources/AutocompleteLabApp/Mac`.
- [ ] Create one `AXObserver` per tracked PID.
- [ ] Register for focused UI element changes.
- [ ] Register for selected text changes where the app supports it.
- [ ] Register for value changes where the app supports it.
- [ ] Register for focused window changes.
- [ ] Register for window moved/resized changes.
- [ ] Reclassify from scratch on focus changes.
- [ ] Re-read geometry on selection/value/window changes.
- [ ] Keep bounded polling as a recovery layer.
- [ ] Use active polling only while a suggestion is visible.
- [ ] Use watch polling for flaky apps only.
- [ ] Add trace metadata for update source: observer, activePoll, watchPoll, idlePoll, manualRefresh.
- [ ] Add diagnostics for observer registration failures.
- [ ] Add tests for pure observer event routing if the AX wrapper can be abstracted.

## P0: Insertion Safety

- [ ] Carry the actual insertion mode used into verification.
- [ ] Verify same frontmost app before marking insertion success.
- [ ] Verify same focused field identity before marking insertion success.
- [ ] Detect AX "success" with unchanged text.
- [ ] Detect partial insertion.
- [ ] Detect duplicated insertion.
- [ ] Detect accepted text inserted at the wrong cursor location.
- [ ] Add per-mode retry policy for AX selected text.
- [ ] Add per-mode retry policy for AX value replacement.
- [ ] Add per-mode retry policy for key events.
- [ ] Keep clipboard fallback opt-in only.
- [ ] Never use clipboard fallback for sensitive profiles.
- [ ] Add insertion failure trace buckets by app and mode.
- [ ] Add tests for Notes-style AX no-op success.
- [ ] Add tests for Chrome-style value replacement.
- [ ] Add tests for retry exhaustion.

## P0: Suggestion Quality

- [ ] Add stricter answer-like output suppression for `Here are`, `You need to`, `The best way`, and `In order to`.
- [ ] Suppress completions that restart the current sentence.
- [ ] Suppress completions that repeat any earlier 3-word phrase unless it is exactly the immediate suffix.
- [ ] Suppress word-completion phrases that contain punctuation.
- [ ] Suppress static dictionary completions for ambiguous two-letter fragments unless the word is recent.
- [ ] Let recent words override static ambiguity.
- [ ] Add typed-over miss learning for repeated bad words.
- [ ] Add tests for near-duplicate repeated misses.
- [ ] Add tests for smart quotes, ellipses, casing, and punctuation normalization.
- [ ] Add trace buckets for answer-style completions.
- [ ] Add trace buckets for repeated typed-over suggestions.
- [ ] Add trace buckets for too-short word completions.

## P0: App Compatibility Profiles

- [ ] Add `appFamily`: nativeAppKit, swiftUIAppKit, WebKit, Chromium, Electron, customCanvas, unknown.
- [ ] Add `anchorLadder` per profile.
- [ ] Add `knownFailureModes` per profile.
- [ ] Add `allowsFieldAnchor`.
- [ ] Add `allowsWindowAnchor`.
- [ ] Add `requiresValidatedCaret`.
- [ ] Add `supportsObserverUpdates`.
- [ ] Split browser textarea support from browser rich-editor support.
- [ ] Add Safari diagnostics profile.
- [ ] Add Slack diagnostics profile.
- [ ] Add VS Code diagnostics profile.
- [ ] Add Cursor diagnostics profile.
- [ ] Add Atlas diagnostics profile once focused AX is reliable.
- [ ] Keep Mail compose diagnostics-only.
- [ ] Add explicit unsupported records for high-risk apps.
- [ ] Add tests for profile defaults.
- [ ] Add tests that unknown apps remain blocked.

## P1: Panel And Window Polish

- [ ] Trace panel level.
- [ ] Trace screen id or screen frame.
- [ ] Trace converted anchor rect and final AppKit frame.
- [ ] Add multi-display tests for conversion math.
- [ ] Test display left of primary.
- [ ] Test display above primary.
- [ ] Test Retina and non-Retina frame conversion.
- [ ] Hide immediately on app blur.
- [ ] Hide immediately when anchor quality downgrades to invalid.
- [ ] Hide immediately when secure/sensitive state appears.
- [ ] Keep click-through in suggesting mode.
- [ ] Add an explicit interactive picker mode only if the user asks for it.
- [ ] Test fullscreen apps.
- [ ] Test Spaces changes.
- [ ] Test Stage Manager.
- [ ] Test menu bar focus changes.
- [ ] Test window dragging while suggestion is visible.

## P1: Runtime And First Run

- [ ] Make first-run model install a real in-app action.
- [ ] Add "Install local model" to settings when the model folder is missing.
- [ ] Add "Retry model load" after install or repair.
- [ ] Show clear missing/repair/ready states in plain language.
- [ ] Update runtime docs to Qwen3.5 4B as the default.
- [ ] Remove stale Gemma default copy from README and research docs.
- [ ] State the macOS 26 requirement clearly in beta docs.
- [ ] Decide whether macOS target can be lowered.
- [ ] Bundle or install the model in an app-owned path.
- [ ] Never require Ollama, llama.cpp, or a user-started server.
- [ ] Add a beta gate that fails if the app is running mock fallback.
- [ ] Add latency proof for current default model.

## P1: Manual QA And Proof

- [ ] Refresh Codex dogfood manual smoke proof.
- [ ] Require manual smoke proof from the current commit or current archive.
- [ ] Add smoke rows for anchor source: caret, line, field, window, off.
- [ ] Add "wrong app insertion" as a hard fail.
- [ ] Add "Tab stolen with no visible suggestion" as a hard fail.
- [ ] Add "Esc does not calm the field" as a hard fail.
- [ ] Add "suggestion shown over sensitive field" as a hard fail.
- [ ] Add "detached bubble over whole editor" as a hard fail unless explicitly allowed.
- [ ] Add TextEdit multiline/wrapped-line smoke.
- [ ] Add Notes rich-text smoke.
- [ ] Add Chrome textarea smoke.
- [ ] Add Chrome contenteditable smoke.
- [ ] Add Obsidian CodeMirror smoke.
- [ ] Add Codex prompt smoke.
- [ ] Add unsupported-app smoke.
- [ ] Add no-Accessibility-permission smoke.

## P1: Trace Analysis

- [ ] Add top miss bucket for caret unavailable.
- [ ] Add top miss bucket for caret invalid.
- [ ] Add top miss bucket for field anchor used.
- [ ] Add top miss bucket for window anchor used.
- [ ] Add top miss bucket for observer missed update.
- [ ] Add top miss bucket for poll recovered update.
- [ ] Add summary by app and anchor quality.
- [ ] Add summary by app and insertion mode.
- [ ] Add summary by app and update source.
- [ ] Add summary by app and AX failure reason.
- [ ] Add `script/geometry_trace_report.py`.
- [ ] Extend `script/check_trace_eval.sh` to enforce geometry proof.
- [ ] Export a short local HTML report for manual review.

## P1: AppDelegate Refactor

- [ ] Extract presentation policy out of `AppDelegate`.
- [ ] Extract observer coordination out of `AppDelegate`.
- [ ] Extract insertion verification scheduling out of `AppDelegate`.
- [ ] Extract trace screenshot capture out of `AppDelegate`.
- [ ] Extract compatibility learning actions out of `AppDelegate`.
- [ ] Keep `AppDelegate` mostly as wiring.
- [ ] Add unit tests for each extracted policy.

## P2: Self-Healing Compatibility

- [ ] Turn manual nudges into adapter recommendations.
- [ ] Add confidence thresholds for "learning should become code".
- [ ] Add a local report that lists apps with repeated visual nudges.
- [ ] Add a local report that lists apps with repeated detached suppression.
- [ ] Add fixture-based visual calibration tests.
- [ ] Explore ScreenCaptureKit for local screenshot capture.
- [ ] Explore Vision-based caret/suggestion alignment only as a dogfood tool.
- [ ] Never run visual calibration without explicit local opt-in.

## P2: Packaging And Beta

- [ ] Recreate the zip after stapling during notarized packaging.
- [ ] Add beta packet proof for app version, git commit, model state, smoke state, and checksum.
- [ ] Add "known unsupported apps" to beta notes.
- [ ] Add feedback questions: helped, interrupted, broke trust, wrong app, too slow.
- [ ] Add a one-command beta readiness report.
- [ ] Add a private beta stop condition checklist.
- [ ] Add rollback instructions.

## Stop Conditions

- [ ] Stop beta if insertion happens in the wrong app.
- [ ] Stop beta if a suggestion appears in a sensitive field.
- [ ] Stop beta if Tab is captured without a visible suggestion.
- [ ] Stop beta if model setup requires a separate server.
- [ ] Stop beta if the app falls back to mock runtime.
- [ ] Stop beta if the panel frequently detaches from the typing location.
- [ ] Stop beta if users cannot understand why suggestions are missing.
