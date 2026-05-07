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

- [x] Make raw trace capture opt-in by default.
- [x] Add explicit trace privacy modes: `lab`, `dogfood`, `beta`, `customer`.
- [x] In beta/customer mode, never persist `textBeforeCursor`, `textAfterCursor`, raw model output, displayed suggestion text, or accepted text.
- [x] Keep counts, app bundle id, role, geometry state, latency, and reason codes in redacted traces.
- [x] Add a redacted trace event type in core.
- [x] Add tests that redacted traces keep useful metadata but drop typed text.
- [x] Disable screenshot tracing outside lab/dogfood mode.
- [x] Require a visible local toggle before screenshot tracing can start.
- [x] Add a diagnostic banner when raw tracing is enabled.
- [x] Expand sensitive app denylist beyond Terminal and password managers.
- [x] Suppress in Mail compose until a safe adapter exists.
- [x] Suppress in payment, password, API key, and token-looking fields when detectable.
- [x] Suppress in unknown apps by default.
- [x] Add a "why no suggestion" reason for sensitive suppression.
- [x] Add tests for sensitive profiles having no insertion modes.
- [x] Add tests for trace redaction of diagnostics metadata.

## P0: First-Class Anchor Ladder

- [x] Add `SuggestionAnchorSource`: caret, line, field, window, none.
- [x] Add `SuggestionAnchorQuality`: trusted, usableFallback, diagnosticsOnly, invalid.
- [x] Replace bare `RenderModePlan.anchorRect` with a decision object that includes source, quality, reason, and rect.
- [x] Prefer caret mode when selected range and bounds validate.
- [x] Add line mode when insertion line or text line bounds are good but caret is missing.
- [x] Add field mode when element bounds are good but caret is not.
- [x] Add window mode only for explicit invocation or diagnostics.
- [x] Keep off mode as the default for no trustworthy text context.
- [x] Treat detached whole-editor anchors as a bug unless the profile allows them.
- [x] Add tests for caret, line, field, window, and off decisions.
- [x] Add tests for profiles that disallow detached field/window suggestions.
- [x] Add trace metadata for anchor source, anchor quality, and fallback reason.
- [x] Show anchor source in diagnostics.
- [x] Update the compatibility matrix with anchor source and proof state.

## P0: AX Geometry Validation

- [x] Capture `AXVisibleCharacterRange`.
- [x] Capture `AXInsertionPointLineNumber`.
- [x] Capture supported AX attributes and parameterized attributes as a compact capability snapshot.
- [x] Record AX errors by attribute without raw text.
- [x] Record AX timeout/cannot-complete errors.
- [x] Validate caret rect against element rect.
- [x] Validate caret rect against window rect.
- [x] Validate caret rect against current screen frame after coordinate conversion.
- [x] Validate text line rect against element/window rect.
- [x] Reject jumps that move too far from the previous caret while text did not change.
- [x] Reject stale caret rects after scroll or focus churn.
- [x] Add a short geometry history per field.
- [x] Add reason codes: zeroHeight, nonfinite, outsideElement, outsideWindow, offScreen, stale, jumpedTooFar, missingBounds.
- [x] Add tests for zero-width caret rects.
- [x] Add tests for browser zero-height caret rects.
- [x] Add tests for outside-field and outside-window rects.
- [x] Add tests for stale geometry rejection.
- [x] Add tests for wrapped line rect validation.
- [x] Add tests for visible range mismatch.

## P0: Observer-First Updates

- [x] Add `AccessibilityObserver` in `Sources/AutocompleteLabApp/Mac`.
- [x] Create one `AXObserver` per tracked PID.
- [x] Register for focused UI element changes.
- [x] Register for selected text changes where the app supports it.
- [x] Register for value changes where the app supports it.
- [x] Register for focused window changes.
- [x] Register for window moved/resized changes.
- [x] Reclassify from scratch on focus changes.
- [x] Re-read geometry on selection/value/window changes.
- [x] Keep bounded polling as a recovery layer.
- [x] Use active polling only while a suggestion is visible.
- [x] Use watch polling for flaky apps only.
- [x] Add trace metadata for update source: observer, activePoll, watchPoll, idlePoll, manualRefresh.
- [x] Add diagnostics for observer registration failures.
- [x] Add tests for pure observer event routing if the AX wrapper can be abstracted.

## P0: Insertion Safety

- [x] Carry the actual insertion mode used into verification.
- [x] Verify same frontmost app before marking insertion success.
- [x] Verify same focused field identity before marking insertion success.
- [x] Detect AX "success" with unchanged text.
- [x] Detect partial insertion.
- [x] Detect duplicated insertion.
- [x] Detect accepted text inserted at the wrong cursor location.
- [x] Add per-mode retry policy for AX selected text.
- [x] Add per-mode retry policy for AX value replacement.
- [x] Add per-mode retry policy for key events.
- [x] Keep clipboard fallback opt-in only.
- [x] Never use clipboard fallback for sensitive profiles.
- [x] Add insertion failure trace buckets by app and mode.
- [x] Add tests for Notes-style AX no-op success.
- [x] Add tests for Chrome-style value replacement.
- [x] Add tests for retry exhaustion.

## P0: Suggestion Quality

- [x] Add stricter answer-like output suppression for `Here are`, `You need to`, `The best way`, and `In order to`.
- [x] Suppress completions that restart the current sentence.
- [x] Suppress completions that repeat any earlier 3-word phrase unless it is exactly the immediate suffix.
- [x] Suppress word-completion phrases that contain punctuation.
- [x] Suppress static dictionary completions for ambiguous two-letter fragments unless the word is recent.
- [x] Let recent words override static ambiguity.
- [x] Add typed-over miss learning for repeated bad words.
- [x] Add tests for near-duplicate repeated misses.
- [x] Add tests for smart quotes, ellipses, casing, and punctuation normalization.
- [x] Add trace buckets for answer-style completions.
- [x] Add trace buckets for repeated typed-over suggestions.
- [x] Add trace buckets for too-short word completions.

## P0: App Compatibility Profiles

- [x] Add `appFamily`: nativeAppKit, swiftUIAppKit, WebKit, Chromium, Electron, customCanvas, unknown.
- [x] Add `anchorLadder` per profile.
- [x] Add `knownFailureModes` per profile.
- [x] Add `allowsFieldAnchor`.
- [x] Add `allowsWindowAnchor`.
- [x] Add `requiresValidatedCaret`.
- [x] Add `supportsObserverUpdates`.
- [x] Split browser textarea support from browser rich-editor support.
- [x] Add Safari diagnostics profile.
- [x] Add Slack diagnostics profile.
- [x] Add VS Code diagnostics profile.
- [x] Add Cursor diagnostics profile.
- [x] Add Atlas diagnostics profile once focused AX is reliable.
- [x] Keep Mail compose diagnostics-only.
- [x] Add explicit unsupported records for high-risk apps.
- [x] Add tests for profile defaults.
- [x] Add tests that unknown apps remain blocked.

## P1: Panel And Window Polish

- [x] Trace panel level.
- [x] Trace screen id or screen frame.
- [x] Trace converted anchor rect and final AppKit frame.
- [x] Add multi-display tests for conversion math.
- [x] Test display left of primary.
- [x] Test display above primary.
- [x] Test Retina and non-Retina frame conversion.
- [x] Hide immediately on app blur.
- [x] Hide immediately when anchor quality downgrades to invalid.
- [x] Hide immediately when secure/sensitive state appears.
- [x] Keep click-through in suggesting mode.
- [ ] Add an explicit interactive picker mode only if the user asks for it.
- [ ] Test fullscreen apps.
- [ ] Test Spaces changes.
- [ ] Test Stage Manager.
- [ ] Test menu bar focus changes.
- [ ] Test window dragging while suggestion is visible.

## P1: Runtime And First Run

- [x] Make first-run model install a real in-app action.
- [x] Add "Install local model" to settings when the model folder is missing.
- [x] Add "Retry model load" after install or repair.
- [x] Show clear missing/repair/ready states in plain language.
- [x] Update runtime docs to Qwen3.5 4B as the default.
- [x] Remove stale Gemma default copy from README and research docs.
- [x] Lower and document the macOS target decision: macOS 14 or newer on Apple Silicon.
- [x] Decide whether macOS target can be lowered.
- [x] Bundle or install the model in an app-owned path.
- [x] Never require Ollama, llama.cpp, or a user-started server.
- [x] Add a beta gate that fails if the app is running mock fallback.
- [x] Add latency proof for current default model.

## P1: Manual QA And Proof

- [ ] Refresh Codex dogfood manual smoke proof.
- [x] Require manual smoke proof from the current commit or current archive.
- [x] Add smoke rows for anchor source: caret, line, field, window, off.
- [x] Add "wrong app insertion" as a hard fail.
- [x] Add "Tab stolen with no visible suggestion" as a hard fail.
- [x] Add "Esc does not calm the field" as a hard fail.
- [x] Add "suggestion shown over sensitive field" as a hard fail.
- [x] Add "detached bubble over whole editor" as a hard fail unless explicitly allowed.
- [x] Add TextEdit multiline/wrapped-line smoke.
- [x] Add Notes rich-text smoke.
- [x] Add Chrome textarea smoke.
- [x] Add Chrome contenteditable smoke.
- [x] Add Obsidian CodeMirror smoke.
- [x] Add Codex prompt smoke.
- [x] Add unsupported-app smoke.
- [x] Add no-Accessibility-permission smoke.

## P1: Trace Analysis

- [x] Add top miss bucket for caret unavailable.
- [x] Add top miss bucket for caret invalid.
- [x] Add top miss bucket for field anchor used.
- [x] Add top miss bucket for window anchor used.
- [x] Add top miss bucket for observer missed update.
- [x] Add top miss bucket for poll recovered update.
- [x] Add summary by app and anchor quality.
- [x] Add summary by app and insertion mode.
- [x] Add summary by app and update source.
- [x] Add summary by app and AX failure reason.
- [x] Add `script/geometry_trace_report.py`.
- [x] Extend `script/check_trace_eval.sh` to enforce geometry proof.
- [x] Export a short local HTML report for manual review.

## P1: AppDelegate Refactor

- [ ] Extract presentation policy out of `AppDelegate`.
- [x] Extract observer coordination out of `AppDelegate`.
- [x] Extract insertion verification scheduling out of `AppDelegate`.
- [x] Extract trace screenshot capture out of `AppDelegate`.
- [ ] Extract compatibility learning actions out of `AppDelegate`.
- [ ] Keep `AppDelegate` mostly as wiring.
- [ ] Add unit tests for each extracted policy.

## P2: Self-Healing Compatibility

- [x] Turn manual nudges into adapter recommendations.
- [x] Add confidence thresholds for "learning should become code".
- [x] Add a local report that lists apps with repeated visual nudges.
- [x] Add a local report that lists apps with repeated detached suppression.
- [x] Add fixture-based visual calibration tests.
- [x] Explore ScreenCaptureKit for local screenshot capture.
- [x] Explore Vision-based caret/suggestion alignment only as a dogfood tool.
- [x] Never run visual calibration without explicit local opt-in.

## P2: Packaging And Beta

- [x] Recreate the zip after stapling during notarized packaging.
- [x] Add beta packet proof for app version, git commit, model state, smoke state, and checksum.
- [x] Add "known unsupported apps" to beta notes.
- [x] Add feedback questions: helped, interrupted, broke trust, wrong app, too slow.
- [x] Add a one-command beta readiness report.
- [x] Add a private beta stop condition checklist.
- [x] Add rollback instructions.

## Stop Conditions

- [x] Stop beta if insertion happens in the wrong app.
- [x] Stop beta if a suggestion appears in a sensitive field.
- [x] Stop beta if Tab is captured without a visible suggestion.
- [x] Stop beta if model setup requires a separate server.
- [x] Stop beta if the app falls back to mock runtime.
- [x] Stop beta if the panel frequently detaches from the typing location.
- [x] Stop beta if users cannot understand why suggestions are missing.
