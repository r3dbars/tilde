# Deep Dive Scorecard - 2026-05-06

This is the current rating after the trust-first hardening, browser editor
compatibility pass, Claude desktop pass, and typing-performance pass.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 8.6/10.

The app is no longer just a neat lab build. It now has real proof across
TextEdit, Notes, Obsidian, Claude desktop, and five Chrome editor shapes:
textarea, contenteditable, CodeMirror-style editor, Monaco-like editor, and
ProseMirror-like editor. The tight typing path is also fast in the latest
diagnostics slice: event-tap p95 is 40 microseconds, p99/max is 91 microseconds,
with zero slow markers and zero tap-disabled events.

It is still not a 10/10. Codex cannot be fully exercised by Computer Use in this
environment, Claude Code is not installed/running, release notarization is
missing `NOTARYTOOL_PROFILE`, and the app still needs broader proof in real
production editors beyond local fixtures.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 9/10 | Fresh smoke slice shows event-tap p95 40us, p99/max 91us, no slow markers, and no tap-disabled events. |
| Keyboard capture safety | 9/10 | Capture starts only around visible suggestions, records latency, suppresses its own synthetic insertion observations, and passes normal keys through. |
| Acceptance reliability | 9/10 | Tab and full accept are verified across TextEdit, Claude desktop, and five Chrome fixture shapes. Chrome now recovers when key-event insertion is unchanged. |
| Placement confidence | 8/10 | Strong where caret bounds exist, safer mirror placement where browser editors hide geometry, and no detached suggestions in dogfood-style prompts. |
| Self-healing behavior | 9/10 | Falls back from inline to mirror, repairs AX cursor drift after value replacement, pauses polling during editor settle time, and retries failed insertion through fallback modes. |
| TextEdit support | 9/10 | Reference target with current automated real-app proof. |
| Notes support | 8/10 | Recorded manual proof exists, but rich text remains a higher-risk surface. |
| Chrome textarea support | 9/10 | Automated smoke passes with two verified accepts. |
| Chrome contenteditable support | 9/10 | Automated smoke passes with recovered insertion handling. |
| Chrome editor-like support | 9/10 | CodeMirror-style local fixture passes with two verified accepts. |
| Chrome Monaco-like support | 9/10 | Monaco-shaped local fixture passes with two verified accepts. |
| Chrome ProseMirror-like support | 9/10 | ProseMirror-shaped local fixture passes with two verified accepts. |
| Obsidian support | 8/10 | Recorded proof exists and detached suggestions are suppressed, but broader CodeMirror proof should be refreshed. |
| Codex support | 6/10 | Profile and synthetic caret path exist, but Computer Use is blocked from proving the prompt in this environment. |
| Claude Code support | 4/10 | Profile exists, but the Claude Code app is not installed/running for live proof. |
| Claude desktop support | 8/10 | Live proof now passes Tab plus full accept. Cursor repair and post-insert polling pause were needed for Electron selection drift. |
| Output relevance | 8/10 | Prompts and cleaners are short and local; echo, punctuation suffixes, and assistant filler are suppressed. |
| Word completion quality | 9/10 | Fast ranker path is useful, partial accept keeps remaining text alive, and repeated misses are suppressed. |
| Non-annoyance | 9/10 | Esc, typed-over tracking, repetition suppression, pause control, and insertion recovery all reduce bad loops. |
| Privacy | 8/10 | Local-first, secure fields suppressed, diagnostics redact text by default; raw trace and screenshots remain opt-in. |
| Onboarding | 7/10 | Permission flow and settings exist, but first-run model readiness still needs a normal-user path. |
| User control | 8/10 | Per-app disable and global pause/resume exist; visible multi-app management is still missing. |
| Diagnostics | 9/10 | Strong placement, latency, insertion, trace, recovered-insertion, and manual proof logs. |
| Automated tests | 9/10 | 211 Swift tests pass, plus script self-tests for smoke, model asset, and typing-performance guards. |
| Real-app smoke | 9/10 | TextEdit, Notes, Obsidian, Claude desktop, and five Chrome shapes are green; Codex and Claude Code remain pending. |
| Release readiness | 7/10 | Signing identity and preferred MLX model are ready, but `NOTARYTOOL_PROFILE` is missing and model distribution is not self-contained. |
| Architecture | 7/10 | Core boundaries are solid; AppDelegate is still too large and should be split into focused services. |

## Latest Proof

- `swift test`: 211 tests passed.
- `./script/real_app_smoke.sh chrome --fixture all`: textarea, contenteditable,
  editor-like, Monaco-like, and ProseMirror-like all passed with two verified
  accepts each.
- `AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 ./script/real_app_smoke.sh textedit`:
  passed with two verified accepts.
- Claude desktop manual smoke: passed with two verified accepts.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=51834 AUTOCOMPLETE_LAB_LOG_LINES=400 AUTOCOMPLETE_LAB_REQUIRE_TYPING_FAST=1 AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=10 ./script/check_diagnostics_log.sh`:
  p95 40us, p99/max 91us, zero slow markers, zero tap-disabled events.
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

## Next Highest-Leverage Work

1. Finish real manual proof for Codex once it can be safely exercised.
2. Install or launch Claude Code and run the same smoke proof there.
3. Test real production Monaco and ProseMirror surfaces, not just local
   dependency-free fixtures.
4. Refresh Obsidian proof with current CodeMirror behavior.
5. Build a normal-user model readiness flow.
6. Split AppDelegate into focused services around polling, insertion,
   verification, and tracing.
