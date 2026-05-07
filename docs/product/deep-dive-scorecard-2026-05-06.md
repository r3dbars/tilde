# Deep Dive Scorecard - 2026-05-06

This is the live scorecard for the autocomplete lab build after the latest
placement, privacy, selected-text safety, screenshot-tracing, Chrome fixture,
and typing-performance pass.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 8.4/10.

The app is much better than a raw lab prototype now. TextEdit and local Chrome
fixtures can show readable inline ghost text, accept with Tab/full accept, and
verify insertion. The app now blocks password/token-like fields, blocks selected
text replacement, bounds screenshot capture backlog, caps long synthetic-caret
measurement, and clips ghost text vertically inside editor bounds.

It is not a 10/10 yet. The biggest remaining gap is still recorder-grade visual
placement in real production editors, especially Notes, Obsidian, Claude Code,
and Claude desktop. Codex has a real screenshot now, but not screenshot plus two
verified accepts in one strict proof slice. The evidence-backed score should
stay lower until those rows are closed.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 9.4/10 | Event-tap summaries remain in microseconds in the latest runs, stale MLX streams now cancel earlier, screenshot capture is backlog-bounded, and long synthetic caret measurement is capped. AX polling is still synchronous and needs a deeper off-main-actor pass. |
| Keyboard capture safety | 9.6/10 | Capture starts only while a suggestion is visible, passes ordinary typing through, blocks selected-text replacement, and replays accept keys when focus moves to a protected field. |
| Acceptance reliability | 8.8/10 | TextEdit and core Chrome fixtures verify Tab plus full accept. Selected text is now blocked before suggestions/acceptance, but the new chat-like no-submit fixture still needs a live run, Notes has only partial current evidence, and Claude Code still needs refreshed proof. |
| Visual caret alignment | 8.6/10 | TextEdit, core Chrome fixtures, and a disposable Codex prompt now have screenshot-backed proof. Stale line rects are dropped and vertical clipping is enforced, but Chrome chat-like, Obsidian, Notes title/body/checklist, Claude Code, and Claude desktop proof is incomplete. |
| Self-healing behavior | 8.9/10 | The app falls back from inline to mirror, learns compatibility observations, captures screenshots when enabled, records placement evidence, applies only explicit trusted visual offsets, and manual nudges now move the visible ghost immediately. It does not yet auto-detect offsets from pixels. |
| Screenshot tracing | 9.4/10 | Screen Recording is preflighted, capture runs off the hot path, screenshots include editor bounds plus ghost text, traces/logs include capture rect plus rendered panel rect, and capture now has a backlog guard plus timeout. |
| TextEdit support | 9.5/10 | Fresh screenshot-backed run shows ghost text aligned after the caret and two verified accepts. |
| Notes support | 6.5/10 | Profile is safer than before. A disposable Notes note produced partial screenshot/Tab evidence, but title/body/checklist are not recorder-grade yet. |
| Chrome textarea support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome contenteditable support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome editor-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome Monaco-like support | 8.5/10 | Fresh pass verifies insertion; visual is readable and near the caret, but still needs real Monaco proof. |
| Chrome ProseMirror-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome chat-like no-submit support | 7.5/10 | A local no-submit fixture now exists so Tab/full accept can be tested against a chat-style composer without touching real prompts. It still needs a live screenshot-backed run. |
| Obsidian support | 8/10 | Prior synthetic caret proof exists, but it needs a fresh screenshot-backed visual audit. |
| Codex support | 8.5/10 | Fresh disposable prompt screenshot shows visible inline placement on the side display after the coordinate and render-level fixes. It still needs a recorder-grade visual pass with insertion in the same slice before it can be scored higher. |
| Claude Code support | 4/10 | Profile exists, but there is still no safe live prompt proof. |
| Claude desktop support | 8.5/10 | Prior manual proof exists, but it needs a fresh visual audit with the new screenshot loop. |
| Output relevance | 9/10 | Prompt labels, instruction echoes, assistant filler, punctuation suffixes, and parroting are suppressed before display. |
| Word completion quality | 9/10 | Word completion and partial acceptance are useful, bounded, and suppress repeated misses. |
| Non-annoyance | 8.5/10 | Esc, typed-over tracking, repetition suppression, pause control, and insertion recovery help, but visual misses still make the app feel annoying when placement is wrong. |
| Privacy | 9.3/10 | Local-first, secure fields suppressed, password/token/API-key-like fingerprints blocked before text reads, diagnostics redact text by default, and screenshots are opt-in. |
| Onboarding | 8/10 | Settings explains runtime readiness, but model install/repair is still not fully in-app. |
| User control | 8.5/10 | Pause, current-app enablement, privacy controls, and full-accept toggle exist; shortcut editing is still thin. |
| Diagnostics | 9.5/10 | Placement, event-tap latency, focused poll latency, insertion, trace, screenshot, and smoke logs are strong. |
| Automated tests | 9.6/10 | `swift test` passes 273 tests and smoke script self-tests are green. |
| Real-app smoke | 8.5/10 | TextEdit and core Chrome fixtures are green on the current build. Chrome chat-like no-submit, Notes title/body/checklist, and Claude Code remain honest gaps. |
| Release readiness | 7.8/10 | Packaging is in decent shape, but beta readiness now correctly fails unless all required manual and screenshot-backed proof rows are closed. Notarization/stapling and beta onboarding still need a final product pass. |
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
| Chrome chat-like no-submit | 7.5/10 | Pending chat-like screenshot | Local fixture support exists and fails if accepting a suggestion submits the form. | Needs `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like`. |
| Obsidian | 8/10 | Pending fresh screenshot | Prior synthetic caret proof passes, and Obsidian is profiled. | Needs screenshot-backed proof in a disposable vault note. |
| Codex | 8.5/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Disposable prompt screenshot shows the ghost visible on the same line after the caret on a negative-origin side display. | Needs a recorder-grade visual pass with Tab/full accept in the same trace slice. |
| Apple Notes title | 6.5/10 | Pending title screenshot | Partial current Notes evidence exists from a disposable note. | Needs `script/manual_smoke_session.sh notes-title --visual` with two verified accepts. |
| Apple Notes body | 6.5/10 | Pending body screenshot | Safer insertion stance exists. | Needs `script/manual_smoke_session.sh notes-body --visual` with two verified accepts. |
| Apple Notes checklist | 6.5/10 | Pending checklist screenshot | Safer insertion stance exists. | Needs `script/manual_smoke_session.sh notes-checklist --visual` with two verified accepts. |
| Claude Code | 4/10 | Pending safe prompt proof | Profile exists. | Needs a safe live prompt smoke before it can be scored high. |
| Claude desktop | 8.5/10 | Pending fresh screenshot | Prior manual proof passed. | Needs screenshot-backed placement audit on current renderer. |

## Latest Proof

- Prior full `swift test`: 273 tests passed before this script/docs-only no-submit fixture pass; no Swift sources changed in this loop.
- `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/manual_smoke_session.sh script/manual_smoke_status.sh`: passed after adding the chat-like no-submit guard.
- `./script/real_app_smoke_self_test.sh`: passed, including dry-run coverage for the Chrome chat-like fixture and the all-fixtures plan.
- `AUTOCOMPLETE_LAB_CHROME_FIXTURE=chat-like ./script/manual_smoke_session.sh chrome --print`: passed and points chat-like proof toward `script/real_app_smoke.sh chrome --fixture chat-like` so submit count is checked.
- `./script/manual_smoke_self_test.sh`: passed.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed with two verified accepts and screenshot capture.
- Prior `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture all`: passed for textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like fixtures before the chat-like fixture was added.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture monaco-like`: passed after the final Monaco gap adjustment.
- `./script/smoke_test.sh`: passed after the visual-evidence telemetry change, including model asset, trace eval, typing-performance, real-app smoke self-test, visual evidence, and package preflight checks. Latest focused-text poll p95 was 3ms, max was 4ms, with no slow markers.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed on a fresh app launch with two verified accepts and screenshot tracing.
- `AUTOCOMPLETE_LAB_TRACE_START_LINE=20143 AUTOCOMPLETE_LAB_TRACE_END_LINE=20158 AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.apple.TextEdit AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT=1 AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE=1 ./script/check_trace_eval.sh`: passed with `Visual evidence complete: 2/2`, high placement confidence, and p90 suggestion latency of 113ms.
- Live Codex disposable prompt probe: screenshot `visual-placement-screenshots/codex-inline.png` shows visible inline ghost text after the caret on the negative-origin side display; focused poll p95 was 5ms and event-tap p95 stayed in microseconds during the probe.
- Hardening pass: focused Swift tests passed for sensitive field policy, selected-text activation blocking, capped synthetic caret estimation, vertical clipping, and stale text-line rejection.
- Full smoke pass after hardening: `./script/smoke_test.sh` passed. Fresh diagnostics from line 64151 scanned 240 focused-text poll samples with p95 max 2ms, max 3ms, zero slow markers, and zero skipped polls.
- `script/beta_readiness.sh` now includes `./script/check_visual_placement_evidence.sh --require-all`, so beta readiness cannot pass while screenshot proof rows are still pending.
- Local chat-like Chrome fixture was added to prove Tab/full accept does not submit a chat-style composer. This is the safe precursor to Codex/Claude no-submit proof, not a substitute for real prompt-app proof.
- Parent handoff: a disposable Notes note produced screenshot-backed suggestion presentation and at least one verified Tab insertion, but this is not enough to mark title/body/checklist complete.
- `./script/manual_smoke_status.sh --strict`: failed honestly on Notes title/body/checklist, Chrome chat-like no-submit, and Claude Code insertion proof gaps, and separately reports Chrome chat-like, Obsidian, Apple Notes title/body/checklist, Claude Code, and Claude desktop screenshot proof gaps.
- `./script/check_visual_placement_evidence_self_test.sh`: passed, including missing, empty, invalid, too-small, unreferenced, and pending strict screenshot failure cases.
- `./script/check_visual_placement_evidence.sh`: passed with seven verified visual-placement screenshots and reports seven pending screenshot audits.
- `./script/check_visual_placement_evidence.sh --require-all`: failed honestly on the seven pending screenshot audits.
- `swift test --filter CompatibilityLearningTests`: passed, covering trusted manual visual offsets and untrusted stale-offset rejection.
- `swift test --filter 'PlacementHealthTests|CompatibilityLearningTests|VisualPlacementGeometryCorrectionPolicyTests'`: passed after synthetic caret confidence and visual-offset trust hardening.
- `./script/check_trace_eval_self_test.sh`: passed, including strict visual-evidence guardrails for screenshot path, anchor rect, rendered panel rect, capture rect, and placement confidence.
- `git diff --check`: passed.
- `swift build`: passed after the screenshot trace capture-rect changes.

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
- Manual smoke status now separates insertion proof from screenshot-backed
  placement proof, and the visual evidence check can fail on pending audit rows.
- Trusted learned visual offsets now apply to synthetic-caret apps such as
  Codex, Obsidian, and Chrome; untrusted stale offsets are still ignored.
- Manual visual nudges now target the visible suggestion's app instead of
  relying on frontmost-app state after the menu opens, and the visible ghost
  moves immediately after the nudge.
- Synthetic caret anchors now emit `placementAnchorSource=synthetic-caret` and
  medium confidence instead of pretending to be high-confidence real AX carets.
- Generic presentation observations can no longer make visual offsets trusted;
  only manual visual nudges and future screenshot visual corrections can.
- Screenshot traces now carry the capture rect in trace metadata and diagnostics.
- Suggestion presentation traces now carry the rendered panel rect, and
  diagnostics keep geometry-shaped keys readable instead of redacting them as
  text.
- Trace evaluation now has an opt-in strict visual-evidence gate that fails a
  screenshot-backed pass unless screenshot path, anchor rect, rendered panel
  rect, capture rect, and placement confidence are all present.
- Manual Notes proof now uses first-class title/body/checklist recorder targets;
  generic Notes rows are historical evidence only and do not close those gaps.
- Manual recorder rows only claim strict screenshot evidence when strict trace
  visual evidence was required and passed.
- Trace evaluation can now bound a proof slice with `AUTOCOMPLETE_LAB_TRACE_END_LINE`,
  so later app activity cannot pollute a completed real-app proof run.
- Password/token/API-key-like fields are now treated as sensitive from AX
  fingerprint metadata before editable text is read.
- Suggestions are now blocked while text is selected, preventing Tab accept from
  replacing highlighted user content.
- Screenshot tracing now skips captures when a small backlog exists and times
  out stuck `screencapture` processes.
- Synthetic caret estimation now measures only a bounded tail of the current
  paragraph, so long prompts cannot make wrapping work grow without bound.
- Inline and floating frames now clamp vertically to editor clipping bounds, and
  stale text-line rectangles far from the caret are ignored.
- A local Chrome chat-like no-submit fixture now tracks form submissions and
  fails the smoke run if Tab/full accept submits the disposable composer.
- A 15-minute Codex automation exists outside this repo to check this scorecard;
  the repository itself still treats the below-10 rows as open work.

## Remaining Gaps

1. Run recorder-grade screenshot-backed audits for Obsidian, Notes title/body/checklist,
   Claude desktop, and Claude Code with disposable text only. Codex has visual proof
   now, but still needs Tab/full-accept proof in the same strict visual trace slice.
2. Build automatic screenshot-driven self-healing: detect visible offset from
   pixels, write a trusted per-app correction, rerun smoke, and keep the proof.
3. Test real production Monaco, ProseMirror, and CodeMirror apps, not just local
   fixtures.
4. Build a fully in-app model install/repair flow.
5. Add a fuller shortcut editor if beta users need more than Tab plus the
   current full-accept toggle.
6. Move focused-text AX polling off the main actor or make it adaptive/event-driven.
7. Run the new local chat-like no-submit fixture with screenshot tracing, then
   use the same no-submit expectation for Codex/Claude prompt-app proof.
8. Split AppDelegate into focused services around polling, insertion,
   verification, screenshot tracing, and placement tuning.
