# Deep Dive Scorecard - 2026-05-06

This is the live scorecard for the autocomplete lab build after the latest
placement, screenshot-tracing, Chrome fixture, and typing-performance pass.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 8.8/10.

The app is much better than a raw lab prototype now. TextEdit and local Chrome
fixtures can show readable inline ghost text, accept with Tab/full accept, and
verify insertion. The hot typing path is still fast in the latest diagnostics
and the screenshot loop now captures enough of the focused editor to judge
whether the ghost is actually near the caret.

It is not a 10/10 yet. The biggest remaining gap is still visual placement in
real production editors, especially Codex, Notes, Obsidian, and Claude Code.
The local Chrome fixture matrix is strong evidence, but it is not the same as
proof in every real website/editor. The app also still needs in-app model
install/repair and better shortcut controls before it feels fully productized.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 9.5/10 | Event-tap summaries remain in microseconds and focused-text polling stays in low milliseconds in the latest runs. |
| Keyboard capture safety | 9.5/10 | Capture starts only while a suggestion is visible, passes ordinary typing through, and the real-app smoke now asserts the target app stays frontmost before accept. |
| Acceptance reliability | 9/10 | TextEdit and Chrome fixtures verify Tab plus full accept. Codex and Claude desktop have previous manual proof. Notes and Claude Code still need refreshed proof. |
| Visual caret alignment | 8/10 | TextEdit and Chrome fixtures now have screenshot-backed proof. Real Codex, Obsidian, Notes, and Claude Code visual proof is still incomplete. |
| Self-healing behavior | 8.8/10 | The app falls back from inline to mirror, learns compatibility observations, captures screenshots when enabled, records placement evidence, applies trusted visual offsets to synthetic-caret apps, and manual nudges now move the visible ghost immediately. It does not yet auto-detect offsets from pixels. |
| Screenshot tracing | 9/10 | Screen Recording is preflighted, capture runs off the hot path, and screenshots now include editor bounds plus ghost text. |
| TextEdit support | 9.5/10 | Fresh screenshot-backed run shows ghost text aligned after the caret and two verified accepts. |
| Notes support | 6.5/10 | Profile is safer than before, but title/body/checklist proof is still stale and rich-text placement has not been re-shot. |
| Chrome textarea support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome contenteditable support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome editor-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome Monaco-like support | 8.5/10 | Fresh pass verifies insertion; visual is readable and near the caret, but still needs real Monaco proof. |
| Chrome ProseMirror-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Obsidian support | 8/10 | Prior synthetic caret proof exists, but it needs a fresh screenshot-backed visual audit. |
| Codex support | 7.5/10 | Prior insertion proof exists, but the user reports Codex placement still feels off and we do not have a safe fresh screenshot audit committed. |
| Claude Code support | 4/10 | Profile exists, but there is still no safe live prompt proof. |
| Claude desktop support | 8.5/10 | Prior manual proof exists, but it needs a fresh visual audit with the new screenshot loop. |
| Output relevance | 9/10 | Prompt labels, instruction echoes, assistant filler, punctuation suffixes, and parroting are suppressed before display. |
| Word completion quality | 9/10 | Word completion and partial acceptance are useful, bounded, and suppress repeated misses. |
| Non-annoyance | 8.5/10 | Esc, typed-over tracking, repetition suppression, pause control, and insertion recovery help, but visual misses still make the app feel annoying when placement is wrong. |
| Privacy | 9/10 | Local-first, secure fields suppressed, diagnostics redact text by default, and screenshots are opt-in. |
| Onboarding | 8/10 | Settings explains runtime readiness, but model install/repair is still not fully in-app. |
| User control | 8.5/10 | Pause, current-app enablement, privacy controls, and full-accept toggle exist; shortcut editing is still thin. |
| Diagnostics | 9.5/10 | Placement, event-tap latency, focused poll latency, insertion, trace, screenshot, and smoke logs are strong. |
| Automated tests | 9.5/10 | `swift test` passes 245 tests and smoke script self-tests are green. |
| Real-app smoke | 8.5/10 | TextEdit and Chrome fixtures are green on the current build. Notes and Claude Code remain honest gaps. |
| Release readiness | 8/10 | Packaging is in decent shape, but notarization/stapling and beta onboarding still need a final product pass. |
| Architecture | 8.5/10 | Core policy and geometry are tested; AppDelegate still owns too much orchestration. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 9.5/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Ghost is on the same line, after the caret, readable, and not focus-stealing. | Need more dark/light document variants. |
| Chrome textarea | 9/10 | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png) | Inline ghost is readable and follows the typed text. | This is a local fixture, not every real website. |
| Chrome contenteditable | 9/10 | [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | Ghost starts immediately after the caret with enough contrast. | Needs real app/site proof. |
| Chrome editor-like | 9/10 | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png) | CodeMirror-style fixture aligns well after the caret. | Needs real Obsidian/CodeMirror screenshot proof. |
| Chrome Monaco-like | 8.5/10 | [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png) | Ghost is readable and close to the caret in a dark editor. | Needs real Monaco proof and a slightly cleaner visual gap. |
| Chrome ProseMirror-like | 9/10 | [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png) | Ghost is readable and inline with the editing line. | Needs real production ProseMirror proof. |
| Obsidian | 8/10 | Pending fresh screenshot | Prior synthetic caret proof passes, and Obsidian is profiled. | Needs screenshot-backed proof in a disposable vault note. |
| Codex | 7.5/10 | Pending safe screenshot | AX value replacement proof exists. | User reports the visual placement still feels wrong; needs a safe prompt screenshot audit. |
| Apple Notes | 6.5/10 | Pending fresh screenshot | Safer insertion stance exists. | Needs title/body/checklist proof and screenshot-backed placement. |
| Claude Code | 4/10 | Pending safe prompt proof | Profile exists. | Needs a safe live prompt smoke before it can be scored high. |
| Claude desktop | 8.5/10 | Pending fresh screenshot | Prior manual proof passed. | Needs screenshot-backed placement audit on current renderer. |

## Latest Proof

- `swift test`: 245 tests passed.
- `bash -n script/real_app_smoke.sh script/manual_smoke_session.sh script/manual_smoke_self_test.sh`: passed.
- `./script/manual_smoke_self_test.sh`: passed.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed with two verified accepts and screenshot capture.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture all`: passed for textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixtures.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture monaco-like`: passed after the final Monaco gap adjustment.
- `./script/smoke_test.sh`: passed after the visible-nudge change, including model asset, trace eval, typing-performance, real-app smoke self-test, visual evidence, and package preflight checks. Latest focused-text poll p95 was 2ms with no slow markers.
- `./script/manual_smoke_status.sh --strict`: failed honestly on Notes title/body/checklist and Claude Code proof gaps.
- `./script/check_visual_placement_evidence_self_test.sh`: passed, including missing, empty, invalid, too-small, and unreferenced screenshot failure cases.
- `./script/check_visual_placement_evidence.sh`: passed with six verified visual-placement screenshots.
- `swift test --filter CompatibilityLearningTests`: passed, covering trusted manual visual offsets and untrusted stale-offset rejection.
- `swift build`: passed after the visible-suggestion nudge targeting change.

## What Changed In This Pass

- Screenshot capture now runs asynchronously, preflights Screen Recording access,
  and avoids stealing focus.
- Screenshot tracing now captures the editor bounds plus the rendered suggestion,
  so visual placement can be graded from real pixels.
- Streaming model partials no longer schedule repeated screenshot captures.
- Chrome moved to synthetic inline caret placement with mirror fallback instead
  of defaulting to a detached floating mirror.
- Inline ghost text now uses a neutral readable color instead of trusting
  unreliable app-reported foreground colors.
- Browser rich-editor synthetic caret tuning now handles textarea,
  contenteditable, CodeMirror-style, Monaco-like, and ProseMirror-like fixtures
  separately.
- Real-app smoke now waits for screenshot capture when tracing is enabled and
  asserts the target app is still frontmost before accepting.
- Screenshot evidence has been committed only from disposable TextEdit/Chrome
  fixtures, not from private prompts or user work.
- Visual-placement evidence now has an executable repo check that fails on
  missing, empty, invalid, too-small, or unreferenced screenshots.
- Trusted learned visual offsets now apply to synthetic-caret apps such as
  Codex, Obsidian, and Chrome; untrusted stale offsets are still ignored.
- Manual visual nudges now target the visible suggestion's app instead of
  relying on frontmost-app state after the menu opens, and the visible ghost
  moves immediately after the nudge.
- A 15-minute automation now checks this scorecard and keeps looping when any
  category is below 10/10.

## Remaining Gaps

1. Run fresh screenshot-backed audits for Codex, Obsidian, Notes, Claude desktop,
   and Claude Code with disposable text only.
2. Build automatic screenshot-driven self-healing: detect visible offset from
   pixels, write a trusted per-app correction, rerun smoke, and keep the proof.
3. Test real production Monaco, ProseMirror, and CodeMirror apps, not just local
   fixtures.
4. Build a fully in-app model install/repair flow.
5. Add a fuller shortcut editor if beta users need more than Tab plus the
   current full-accept toggle.
6. Split AppDelegate into focused services around polling, insertion,
   verification, screenshot tracing, and placement tuning.
