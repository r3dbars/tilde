# Deep Dive Scorecard - 2026-05-06

This is the current rating after the trust-first hardening, browser editor
compatibility pass, Codex/Claude dogfood pass, Obsidian synthetic-caret pass,
typing-performance pass, cleaner hardening, and polling-pause extraction.
It now also includes the Settings readiness/control pass and Settings privacy
controls.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 9.4/10.

The app is no longer just a neat lab build. It now has real proof across
TextEdit, Notes, Obsidian, Codex, Claude desktop, and five Chrome editor shapes:
textarea, contenteditable, CodeMirror-style editor, Monaco-like editor, and
ProseMirror-like editor. The tight typing path is also fast in the latest
diagnostics slice: event-tap p95 is 63 microseconds, p99/max is 101 microseconds,
with zero slow markers and zero tap-disabled events. The fresh Obsidian slice
also stayed fast while accepting suggestions: event-tap p95 was 132
microseconds with no slow markers.

It is still not a 10/10. Claude Code does not have a safe live prompt proof yet,
release notarization is missing `NOTARYTOOL_PROFILE`, onboarding still needs a
self-contained model install/repair path, shortcut controls are still thin, and
the app still needs broader proof in real production editors beyond local
fixtures.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 9/10 | Fresh smoke slice shows event-tap p95 63us, p99/max 101us, no slow markers, and no tap-disabled events. |
| Keyboard capture safety | 9/10 | Capture starts only around visible suggestions, records latency, suppresses its own synthetic insertion observations, and passes normal keys through. |
| Acceptance reliability | 9/10 | Tab and full accept are verified across TextEdit, Codex, Claude desktop, and five Chrome fixture shapes. Codex now uses verified AX value replacement instead of failing key-event insertion. |
| Placement confidence | 9/10 | Strong where caret bounds exist, safer mirror placement where browser editors hide geometry, and dogfood smoke now requires caret-anchored high-confidence placement. |
| Self-healing behavior | 9/10 | Falls back from inline to mirror, repairs AX cursor drift after value replacement, pauses polling during editor settle time, and retries unchanged insertion through fallback modes. |
| TextEdit support | 9/10 | Reference target with current automated real-app proof. |
| Notes support | 8/10 | Notes now fails closed with key-event-only insertion, but title/body/checklist proof still needs to be refreshed on the current build. |
| Chrome textarea support | 9/10 | Automated smoke passes with two verified accepts. |
| Chrome contenteditable support | 9/10 | Automated smoke passes with recovered insertion handling. |
| Chrome editor-like support | 9/10 | CodeMirror-style local fixture passes with two verified accepts. |
| Chrome Monaco-like support | 9/10 | Monaco-shaped local fixture passes with two verified accepts. |
| Chrome ProseMirror-like support | 9/10 | ProseMirror-shaped local fixture passes with two verified accepts. |
| Obsidian support | 9/10 | Fresh CodeMirror proof now passes with synthetic caret placement, high-confidence caret anchoring, and two verified accepts. |
| Codex support | 9/10 | Live AppleScript-gated proof passes Tab plus full accept with caret-anchored placement and verified AX insertion. Computer Use remains blocked from inspecting Codex directly. |
| Claude Code support | 4/10 | Profile exists, but there is still no safe live prompt proof for the Claude Code surface. |
| Claude desktop support | 9/10 | Live proof now passes Tab plus full accept. Cursor repair and post-insert polling pause handle Electron selection drift. |
| Output relevance | 9/10 | Prompt labels, instruction echoes, assistant filler, punctuation suffixes, and context parroting are suppressed before display. |
| Word completion quality | 9/10 | Fast ranker path is useful, partial accept keeps remaining text alive, and repeated misses are suppressed. |
| Non-annoyance | 9/10 | Esc, typed-over tracking, repetition suppression, pause control, and insertion recovery all reduce bad loops. |
| Privacy | 9/10 | Local-first, secure fields suppressed, diagnostics redact text by default, and Settings exposes trace pause, raw text, screenshots, paths, and delete-local-logs controls. |
| Onboarding | 8/10 | Settings now gives stage-specific model guidance and runtime actions; model install/repair is still not fully in-app. |
| User control | 9/10 | Settings exposes pause, current-app enablement, disabled-app count, enable-all, privacy controls, and a full-accept shortcut toggle. |
| Diagnostics | 9/10 | Strong placement, latency, insertion, trace, recovered-insertion, and manual proof logs. |
| Automated tests | 9/10 | 228 Swift tests pass, plus script self-tests for smoke, model asset, trace eval, and typing-performance guards. |
| Real-app smoke | 9/10 | TextEdit, Obsidian, Codex, Claude desktop, and five Chrome shapes are green; Notes split rich-text proof and Claude Code remain pending. |
| Release readiness | 7/10 | Signing identity and preferred MLX model are ready, but `NOTARYTOOL_PROFILE` is missing and model distribution is not self-contained. |
| Architecture | 8/10 | Core boundaries are solid, and polling-pause timing moved into a tested core type; AppDelegate still needs larger service extraction. |

## Latest Proof

- `swift test`: 228 tests passed.
- `./script/real_app_smoke.sh chrome --fixture all`: textarea, contenteditable,
  editor-like, Monaco-like, and ProseMirror-like all passed with two verified
  accepts each.
- `AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 ./script/real_app_smoke.sh textedit`:
  passed with two verified accepts.
- Codex manual smoke: passed with two verified accepts after switching Codex
  insertion to AX value replacement.
- Claude desktop manual smoke: passed with two verified accepts after the
  stricter AX value verification change.
- Obsidian manual smoke: passed with two verified accepts after synthetic
  text-area caret placement; diagnostics show `placementAnchorSource=caret`,
  `placementConfidenceBand=high`, `hasCaretRect=true`, and event-tap p95 132us.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=53058 AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=10 ./script/check_typing_performance_log.sh`:
  p95 63us, p99/max 101us, zero slow markers, zero tap-disabled events.
- Focused cleaner and architecture tests passed:
  `FocusedTextPollingPauseTests`, `CompletionOutputCleanerTests`, and
  `CompletionQualityEvalTests`.
- Settings UI launched from the menu bar and exposed model readiness, runtime
  action, current-app state, disabled-app count, pause, and enable-all controls.
- Settings UI also exposes privacy controls for trace pause, raw text tracing,
  screenshot tracing, local log paths, and local log deletion.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=53357 AUTOCOMPLETE_LAB_LOG_LINES=260 ./script/check_diagnostics_log.sh`:
  launch/status diagnostics verified after a fresh relaunch.
- `./script/check_model_asset.py`: Qwen3.5 4B MLX asset ready at the app-owned
  model path.
- `./script/package_release.sh --check`: Developer ID identity found, preferred
  MLX model ready, notary profile missing.

## What Changed In This Pass

- Partial word acceptance now advances the suggestion baseline, so accepting the
  first word does not make the remaining suggestion look like stale typed-over
  text.
- Claude desktop is now a first-class profile and manual-smoke target.
- AX value replacement now verifies that the cursor actually stayed after the
  inserted text; when Electron resets the cursor, the app repairs it.
- The app pauses focused-text polling briefly after insertion so transient editor
  selection drift does not hide the remaining suggestion.
- Insertion retry now skips a failed primary mode and tries the configured
  fallback mode. This fixed Chrome when key events reported success but the text
  did not change.
- Diagnostics now distinguish recovered insertion verification from final
  unrecovered insertion failure.
- Manual smoke gates now fail on unrecovered failures while allowing proven
  fallback recovery.
- Dogfood prompt matching is now stricter: generic labels like "chat",
  "input", or "prompt" must also look like a bottom composer, and top-edge or
  central dogfood text areas are blocked.
- Stable-bounds field identity now includes stable AX fingerprint attributes,
  reducing same-sized wrong-field collisions in Electron-style apps.
- Keyboard event-tap suppression and replay tracking now use monotonic
  nanosecond deadlines instead of `Date` allocations on the hot path.
- Codex insertion now uses verified AX value replacement first, which fixed a
  live Codex failure where key events reported success but the prompt text did
  not change.
- Obsidian now participates in synthetic text-area caret placement, so CodeMirror
  hidden caret bounds no longer force a detached-suppression-only result.
- Manual smoke status now treats detached-suppression rows as limited evidence,
  not full green proof. A green Obsidian row now requires two verified accepts.
- Obsidian, Codex, Claude Code, and Claude desktop smoke checks now require
  caret-anchored high-confidence placement with `hasCaretRect=true`.
- Diagnostics line formatting now runs on the diagnostics queue, so event-tap
  and panel callers avoid timestamp creation, metadata sorting, and redaction
  work on the caller path.
- Focused-text polling pauses moved out of AppDelegate into a small tested core
  type.
- Completion cleaning now blocks prompt scaffolding echoes such as
  `Before cursor:`, `Inline autocomplete`, `Return only`, and related
  instruction text before anything is shown to the user.
- Settings now uses stage-specific runtime readiness guidance instead of a
  generic warmup message.
- Settings now exposes current-app enable/disable, disabled-app count, and
  enable-all controls.
- The app opens Settings automatically when Accessibility or model/runtime
  readiness needs user attention.
- Settings now exposes local privacy controls that were previously buried in
  Diagnostics: pause trace logging, raw text tracing, screenshot tracing, and
  local log deletion.
- Settings now lets users switch full accept between Backtick and Option-Tab,
  while Tab remains the next-word accept key.
- Notes now uses key-event insertion only and the manual smoke gate requires
  separate title, body, and checklist proof labels.

## Next Highest-Leverage Work

1. Run a safe Claude Code prompt proof.
2. Test real production Monaco and ProseMirror surfaces, not just local
   dependency-free fixtures.
3. Build a fully in-app model install/repair flow.
4. Add a fuller shortcut editor if beta users need more than the Backtick /
   Option-Tab full-accept toggle.
5. Split AppDelegate into focused services around polling, insertion,
   verification, and tracing.
