# Deep Dive Scorecard - 2026-05-06

This is the live scorecard for the autocomplete lab build after the latest
placement, privacy, selected-text safety, screenshot-tracing, Chrome fixture,
typing-performance, prompt-app safety, AX-health, and native-control pass.

Scale: 10 means beta-ready for normal people. 5 means promising but still easy
to break or annoy users.

## Executive Rating

Overall: 9.0/10.

The app is much better than a raw lab prototype now. TextEdit and local Chrome
fixtures can show readable inline ghost text, accept with Tab/full accept, and
verify insertion. The app now blocks password/token-like fields, blocks selected
text replacement, bounds screenshot capture backlog, caps long synthetic-caret
measurement, clips ghost text vertically inside editor bounds, throttles slow
focused-text polling, suppresses stale async suggestions, fails closed when the
keyboard event tap is disabled, scopes recent word memory by app, and removes
fixed sleeps from AX value-replacement insertion. This pass also made instant
word completion obey repeated-miss suppression, removed lab/debug vocabulary
from the global word list, and tightened dogfood prompt detection so loose
words like `table`, `model`, or `test` do not bias normal writing. The latest
wave also added expiring debug capture, green/yellow/diagnostics-only app
support status, a wired serial AX reader for focused-text polling, app-specific
AX cooldowns, stronger assistant-y output filtering, safer Codex/Claude prompt
profiles, calmer menu/status copy, Settings "why hidden" copy,
placement-confidence diagnostics, and screenshot-backed Chrome chat-like
no-submit proof. The latest placement pass also hides stale ghosts when
placement cannot be trusted and feeds repeated caret-geometry uncertainty into
field quiet mode, with the active quiet scope visible in Diagnostics. Slow
focused-text AX reads that return no focused text context now cool down that app
immediately by default, which keeps failing editors from being polled twice
before the app backs away. A single slow AX read with context now also starts a
short focused-text polling throttle and drops that returned context instead of
turning a stale read into a visible suggestion. The latest trust pass also makes
post-accept verification fail closed when the frontmost app, focused text
context, or field identity no longer matches the accepted suggestion baseline;
those cases now trace as `insertionFailed`, count as wrong-insertion annoyance,
and suppress the original field when the profile is configured to quiet failed
insertions.

It is not a 10/10 yet. The biggest remaining gap is still recorder-grade visual
placement in real prompt apps and production-editor variants, especially Codex,
Claude Code, Claude desktop, and more Obsidian/editor shapes. Codex has a real screenshot now, but not screenshot plus
verified one-word accept/no-submit proof in one strict proof slice. The
evidence-backed score should stay lower until those rows are closed.

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Normal typing passthrough | 9.9/10 | Live TextEdit soak now proves the key path stays in microseconds during a long synthetic typing run. Event-tap summaries stayed clean over 600 samples with p95 max 35us, p99 max 95us, max 161us, zero slow markers, and zero tap-disable events. Focused-text AX reads are off the hot path, slow reads with no focused text context now cool down that app immediately, and a single slow AX read with context now throttles polling and drops the stale read result. Fresh long-run proof still has to show the AX warning lane stays calm before this can reach 10/10. |
| Keyboard capture safety | 9.8/10 | Capture starts only after a suggestion panel frame is actually usable, passes ordinary typing through, blocks selected-text replacement, fails closed if macOS disables the tap, and replays accept keys when focus moves to a protected field. |
| Acceptance reliability | 9.5/10 | TextEdit, core Chrome fixtures, Chrome chat-like, Obsidian, and Apple Notes title/body/checklist verify accept paths. Prompt-app full accept is intentionally disabled until separate full-accept no-submit proof exists. Selected text is blocked before suggestions/acceptance, AX insertion is faster, and post-accept verification mismatches now fail closed with tested trace/quiet behavior. Current Codex, Claude Code, and Claude desktop one-word no-submit proof still need live runs. |
| Visual caret alignment | 9.5/10 | TextEdit, core Chrome fixtures, Chrome chat-like, Obsidian, Apple Notes title/body/checklist, and a disposable Codex prompt now have screenshot-backed proof. Stale line rects are dropped, vertical clipping is enforced, too-narrow inline space suppresses display instead of showing a sliver, and async suggestions refresh current geometry before display, but Claude Code and Claude desktop proof is incomplete and Codex still needs same-slice accept/no-submit proof. |
| Self-healing behavior | 9.5/10 | The app falls back from inline to mirror, learns compatibility observations, captures screenshots when enabled, records placement evidence, applies only explicit trusted visual offsets, manual nudges move the visible ghost immediately, untrusted placement suppression now hides any stale ghost, and trusted visual offsets expire when the target app version, screen, or field shape changes. A unit-tested pixel detector can now identify screenshot offset from synthetic pixels, screenshot capture logs offset metadata, and per-app screenshot tracing can write trusted scoped corrections through the existing trust gate. Fresh real-app screenshot proof still needs to prove this before it can count as complete. |
| Screenshot tracing | 9.4/10 | Screen Recording is preflighted, capture runs off the hot path, screenshots include editor bounds plus ghost text, traces/logs include capture rect plus rendered panel rect, and capture now has a backlog guard plus timeout. |
| TextEdit support | 9.6/10 | Fresh screenshot-backed run at 2026-05-07T02:28:19Z shows ghost text aligned after the caret and two verified accepts. The smoke harness now respects the active full-accept shortcut instead of assuming Backtick. |
| Notes support | 6.5/10 | Profile is safer than before and now uses mirror-first placement until title/body/checklist proof exists. A disposable Notes note produced partial screenshot/Tab evidence, but title/body/checklist are separate proof targets and none are recorder-grade yet. |
| Chrome textarea support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome contenteditable support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome editor-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome Monaco-like support | 8.5/10 | Fresh pass verifies insertion; visual is readable and near the caret, but still needs real Monaco proof. |
| Chrome ProseMirror-like support | 9/10 | Fresh full-frame screenshot and two verified accepts. |
| Chrome chat-like no-submit support | 9/10 | A local no-submit fixture now has screenshot-backed proof with Tab/full accept verified and submit count still zero. It is still a local fixture, not proof for real chat apps. |
| Obsidian support | 8/10 | Prior synthetic caret proof exists, but it needs a fresh screenshot-backed visual audit. |
| Codex support | 8.5/10 | Fresh disposable prompt screenshot shows visible inline placement on the side display after the coordinate and render-level fixes, but the current profile is mirror-first until same-slice one-word no-submit proof exists. It still needs a recorder-grade visual pass with one-word accept and no-submit proof in the same slice before it can be scored higher; full accept is disabled until separate full-accept no-submit proof exists. |
| Claude Code support | 4/10 | Profile exists and is mirror-first, but there is still no safe live prompt proof. |
| Claude desktop support | 8.4/10 | Prior manual proof exists, but it needs fresh one-word no-submit proof with the new screenshot loop. The current profile is mirror-first, and full accept is disabled until separate full-accept no-submit proof exists. |
| Output relevance | 8.9/10 | Prompt labels, instruction echoes, assistant filler, unsafe prompt actions, punctuation suffixes, parroting, and more assistant-y prefixes are suppressed before display. Dogfood prompts now avoid loose substring triggers, but default redacted tracing means deeper output-quality audits require explicit raw-content dogfood runs. |
| Word completion quality | 8.9/10 | Word completion and partial acceptance are useful, bounded, app-scoped, fast completions obey repeated-miss suppression, and unrelated whole-word completions are rejected. It still needs more real-app miss-rate proof before scoring higher. |
| Non-annoyance | 8.8/10 | Esc, typed-over tracking, repetition suppression, pause control, insertion recovery, app-specific AX cooldowns, unknown field-kind suppression, and Settings "why hidden" copy help, but visual misses still make the app feel annoying when placement is wrong. |
| Privacy | 9.7/10 | Local-first, secure fields suppressed, password/token/API-key-like fingerprints blocked before text reads, diagnostics redact text by default, screenshots are opt-in, recent word memory is app-scoped, raw/global/per-app screenshot debug capture now expires from app UI, Settings has a one-click Privacy Status panel, local log deletion clears compatibility-learning artifacts, and exported reports include a privacy checklist. Plain-language permission copy still needs polish. |
| Onboarding | 8.2/10 | Settings explains runtime readiness, current app state, and local privacy controls more clearly, but model install/repair and first-run permission explanation are still not fully in-app. |
| User control | 9.2/10 | Pause, current-app enablement, green/yellow/diagnostics-only/unsupported support status, privacy controls, temporary screenshot/raw trace toggles, local log deletion, explicit full-accept shortcut choice, quiet/normal/eager pace, and Settings "why hidden" copy are clearer. Per-app mode visibility and broader shortcut customization are still thin. |
| Diagnostics | 9.8/10 | Placement, placement confidence, event-tap latency, focused poll latency, AX cooldowns, insertion, trace, screenshot-file evidence, and smoke logs are strong. The Diagnostics window now separates key capture health from AX polling health and shows recent trace text as lengths instead of raw suggestion text. |
| Automated tests | 10/10 | `swift test` passes 326 tests, including app-target settings state tests, diagnostics typing-health tests, scoped recent-word memory, privacy expiry, support status, serial AX reader, focused AX-health cooldown, focused-poll backoff, dogfood false-positive coverage, neutral word-completion vocabulary, screenshot trace capture policy, placement trust policy, and trace visual evidence. Script self-tests now cover strict score targets, the 10-pass score loop path, manual smoke status, visual proof, typing performance, and the 10-minute endurance soak command. |
| Real-app smoke | 8.8/10 | TextEdit, core Chrome fixtures, and Chrome chat-like no-submit are green on the current build. The latest TextEdit strict visual smoke passed after the accept-all shortcut/race fix. Notes title/body/checklist, Codex, Claude Code, and Claude desktop remain honest insertion-proof gaps. |
| Release readiness | 8/10 | Packaging is in decent shape, and the current local archive has been notarized, stapled, and Gatekeeper-verified. Beta readiness still correctly fails unless all required manual and screenshot-backed proof rows are closed, and beta onboarding still needs a final product pass. |
| Architecture | 9.2/10 | Core policy, geometry, deterministic stable-bounds field identity, scoped word memory, trace analysis, privacy expiry, support status, serial AX focused-text reads, and AX-health cooldowns are tested and wired. AppDelegate still owns too much orchestration. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 9.5/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Ghost is on the same line, after the caret, readable, and not focus-stealing. | Pending: more dark/light document variants. |
| Chrome textarea | 9/10 | [chrome-textarea.png](visual-placement-screenshots/chrome-textarea.png) | Inline ghost is readable and follows the typed text. | Pending: real website proof beyond the local fixture. |
| Chrome contenteditable | 9/10 | [chrome-contenteditable.png](visual-placement-screenshots/chrome-contenteditable.png) | Ghost starts immediately after the caret with enough contrast. | Pending: real app/site proof. |
| Chrome editor-like | 9/10 | [chrome-editor-like.png](visual-placement-screenshots/chrome-editor-like.png) | CodeMirror-style fixture aligns well after the caret. | Pending: Obsidian now covers real CodeMirror; still needs more production editor variants. |
| Chrome Monaco-like | 8.5/10 | [chrome-monaco-like.png](visual-placement-screenshots/chrome-monaco-like.png) | Ghost is readable and close to the caret in a dark editor. | Pending: real Monaco proof and a slightly cleaner visual gap. |
| Chrome ProseMirror-like | 9/10 | [chrome-prosemirror-like.png](visual-placement-screenshots/chrome-prosemirror-like.png) | Ghost is readable and inline with the editing line. | Pending: real production ProseMirror proof. |
| Chrome chat-like no-submit | 9/10 | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Ghost is inline after the caret, Tab and full accept verified, and the local submit counter stayed at zero. | Pending: real prompt/chat-app no-submit proof before broad enablement. |
| Obsidian | 8/10 | Stale screenshot: [obsidian.png](visual-placement-screenshots/obsidian.png) | Prior synthetic caret proof passes, and Obsidian is profiled. | Pending: needs fresh screenshot-backed proof in a disposable vault note. |
| Codex | 8.5/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Disposable prompt screenshot shows the ghost visible on the same line after the caret on a negative-origin side display, but current unproven prompt-app behavior is mirror-first. | Pending: needs a recorder-grade visual pass with one-word accept and no-submit proof in the same trace slice. |
| Apple Notes title | 6.5/10 | Stale screenshot: [notes-title.png](visual-placement-screenshots/notes-title.png) | Partial generic Notes evidence exists from a disposable note, but it does not close title proof. | Pending: needs `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate` with two verified accepts. |
| Apple Notes body | 6.5/10 | Stale screenshot: [notes-body.png](visual-placement-screenshots/notes-body.png) | Safer insertion stance exists, but body proof cannot borrow title or generic Notes evidence. | Pending: needs `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate` with two verified accepts. |
| Apple Notes checklist | 6.5/10 | Stale screenshot: [notes-checklist.png](visual-placement-screenshots/notes-checklist.png) | Safer insertion stance exists, but checklist proof needs its own caret and insertion pass. | Pending: needs `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate` with two verified accepts. |
| Claude Code | 4/10 | Pending safe prompt proof | Profile exists. | Needs a safe live prompt smoke before it can be scored high. |
| Claude desktop | 8.4/10 | Pending fresh screenshot | Prior manual proof passed. | Needs screenshot-backed one-word no-submit proof on current renderer. |

## Latest Proof

- 2026-05-08 continuation pass: added
  `InsertionVerificationPreflightPolicy` and tests so post-accept verification
  only proceeds when the same frontmost app and focused field are still present.
  `AppDelegate.scheduleInsertionVerification` now records app/context/field
  mismatches as `insertionFailed`, marks them as wrong-insertion annoyance
  signals, and suppresses the original field for profiles that quiet failed
  insertions. `swift test --filter InsertionVerification` passed 14 tests, and
  full `swift test` passed 744 tests.
- 2026-05-08 stable identity pass: replaced Swift's randomized `Hasher` in
  stable-bounds field identity with a deterministic FNV-style hash and pinned a
  fixture in `FocusedFieldIdentityPolicyTests`. `swift test --filter
  FocusedFieldIdentityPolicyTests` passed 6 tests.
- 2026-05-08 unknown-field pass: profiles now default to rejecting unknown AX
  field kinds at activation time unless a profile explicitly opts in.
  `CompletionActivationPolicyTests` covers the block/allow split, and
  `CompatibilityProfileTests` verifies MVP profiles do not opt in. Full
  `swift test` passed 747 tests.
- 2026-05-08 local deletion pass: Settings deletion now removes compatibility
  learning artifacts as well as raw/redacted traces, screenshots, and
  diagnostics. `CompatibilityLearningStorePrivacyTests` and
  `script/delete_local_traces_self_test.sh` cover the app and CLI paths.
- Current 2026-05-07 goal pass: added a pre-accept snapshot guard for app,
  process, focused field, selected text, and before/after cursor text; records
  accept-key focus mismatches as `wrong-app-or-field-before-accept` severe
  do-not-ship blockers; suppresses phrase continuation during fast typing
  bursts while leaving word completion available; and gates low-confidence
  suggestions before display. Added privacy tests for secure fields,
  unsupported apps, and screenshot/raw-text separation. `swift test` passed 437
  tests, and `./script/smoke_test.sh` passed, including bundle and diagnostics
  log checks.
- Five-agent continuation pass: prompt-app safety hardening, strict visual proof
  gates, focused-text AX-health cooldown, Notes/Obsidian proof triage, and
  Apple-native polish ranking all completed on branch
  `codex/trust-first-autocomplete-hardening`.
- Local final polish pass: full `swift test` passed 326 tests, and
  `swift test --filter DiagnosticsTypingHealthTests`,
  `swift test --filter SettingsWindowControllerStateTests`, and
  `swift test --filter FocusedTextAXHealthPolicyTests` passed after adding the
  Diagnostics typing-health summary, Settings "why hidden" copy, calmer menu
  status titles, and AX-health cooldown diagnostics.
- Prompt-app safety worker pass: full `swift test` passed 318 tests after
  keeping prompt-app full accept disabled until separate full-accept no-submit
  proof exists and suppressing unsafe prompt actions like Enter/send/submit/run.
- AX-health worker pass: full `swift test` passed 318 tests after wiring
  app-specific focused-text AX cooldowns before/after serial reads.
- Strict proof gate worker pass: visual and manual smoke self-tests passed, and
  live strict gates fail honestly on the current pending app-proof rows.
- `./script/smoke_test.sh`: passed after the final diagnostics/status/docs
  pass. It ran 326 Swift tests, test coverage manifest, model asset self-test,
  manual smoke self-test, real-app smoke self-test, visual evidence self-test,
  trace eval self-test, typing performance self-test, model latency self-test,
  package preflight, app build/sign/verify, and diagnostics verification. The
  fresh diagnostics slice showed event-tap latency had no samples, no slow tap
  markers, no tap disable events, focused poll p95 max 3ms, focused poll max
  94ms, one off-main slow focused-poll marker, and two focused-poll skips. The
  typing guard passed because key capture stayed clean and AX slowness is now a
  suggestion-responsiveness warning.
- `./script/manual_smoke_status.sh --strict`: exits 1 honestly. Remaining
  prompt-app insertion gaps are Codex, Claude Code, and Claude desktop;
  remaining screenshot gaps are Claude Code and Claude desktop; Codex still needs same-slice one-word
  no-submit visual proof.
- `./script/check_score_targets.sh`: exits 1 honestly on the current docs with
  70 target misses across this scorecard, the Apple-native checklist, and the
  app proof matrix. This makes the requested "all 10s / all 100s / all As"
  target executable instead of subjective.
- `./script/check_proof_manifest.sh`: verifies the machine-readable
  `docs/product/proof-manifest.json` against current proof-fingerprint
  constants, tracked screenshots, scorecard links, and matching manual smoke
  rows. It passes in report mode. Strict mode now also parses each matched
  trace JSONL slice, requires bounded line evidence, screenshot-backed
  presented events for strict visual proof, verified insertions, and current
  proof fingerprints. It now verifies the latest TextEdit, Chrome chat-like,
  Obsidian, and Notes title/body/checklist bounded trace slices. Require-all
  mode still fails on partial or pending surfaces.
- `./script/typing_performance_endurance_soak.sh --minutes 1 --strict-ax --require-event-tap-samples 50 --require-ax-samples 5`:
  passed with exact 1,200-character TextEdit verification, event-tap p95 max
  36us, p99 max 95us, max 95us, zero slow tap markers, zero tap-disable events,
  focused-poll p95 max 42ms, focused-poll max 88ms, and zero focused-poll skips.
- Latest harness hardening keeps CGEvent typing focused on the named TextEdit
  document, uses 250-character segments so focus is revalidated often, and
  bounds cleanup AppleScript so a wedged disposable TextEdit document cannot
  hang the proof runner. A current short proof passed with exact 100-character
  named-document verification. The 10-minute wrapper is now more realistic and
  self-tested, but the current live 10-minute harness still needs a durable
  unattended pass before this score can become 10/10.
- `./script/scorecard_goal_loop.sh --iterations 10`: completed all 10 requested
  proof-loop iterations and still failed, as expected, because the same manual
  app-proof gaps remain. It is now the repeatable repo command for grinding
  against the score targets without inflating grades.
- Latest live TextEdit proof: `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`
  passed at 2026-05-07T21:01:59Z with two verified accepts, strict screenshot
  trace evidence, bounded diagnostics lines 135065-135095, bounded trace lines
  34620-34630, and current trace/placement/key/runtime proof fingerprints.
- Latest live Notes body proof: `AUTOCOMPLETE_LAB_LOG_START_LINE=138145 AUTOCOMPLETE_LAB_TRACE_START_LINE=35010 AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab ./script/manual_smoke_session.sh notes-body --check --visual`
  passed at 2026-05-07T23:33:48Z with two verified accepts, strict screenshot
  trace evidence, bounded diagnostics lines 138146-138299, bounded trace lines
  35011-35048, and current trace/placement/key/runtime proof fingerprints.
- Latest live Notes checklist proof: `AUTOCOMPLETE_LAB_LOG_START_LINE=138740 AUTOCOMPLETE_LAB_TRACE_START_LINE=35082 AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/manual_smoke_session.sh notes-checklist --check --visual`
  passed at 2026-05-08T00:21:33Z with a visible native checklist circle, two
  verified accepts, strict screenshot trace evidence, bounded diagnostics lines
  138741-138783, bounded trace lines 35083-35095, and current
  trace/placement/key/runtime proof fingerprints.
- Latest older live typing soak: `./script/typing_performance_soak.sh --skip-build --characters 1800 --chunk-size 10 --delay-ms 15 --require-event-tap-samples 100`
  passed after increasing the post-typing focused-text poll pause. The hard key
  path stayed clean over 600 event-tap summary samples: p95 max 35us, p99 max
  95us, max 161us, zero slow markers, and zero tap-disabled events. The same
  run still reported off-main AX polling warnings: focused poll p95 max 59ms,
  focused poll max 209ms, two slow markers, and four in-flight skip events.
- Current multi-agent hardening pass: `swift test` passed 303 tests after wiring slow-poll throttle, stale-context suppression, event-tap fail-closed handling, app-scoped recent-word memory, fast-word repeated-miss suppression, dogfood false-positive tests, neutral word-completion vocabulary tests, privacy-expiry tests, support-status tests, serial AX reader tests, settings state tests, and faster AX value replacement.
- Follow-up strictness/performance pass: `swift test` passed after AppDelegate routed focused-text polling through the serial off-main AX reader; `./script/manual_smoke_self_test.sh` passed after `manual_smoke_status.sh --strict` started failing on pending screenshot proof, not just missing insertion proof.
- `./script/smoke_test.sh`: passed after the serial AX polling and checker split. The final diagnostics slice started at line 75648 and showed no event-tap latency samples, no slow tap markers, no tap disable events, focused poll p95 max 3ms, focused poll max 21ms, and zero focused-poll skips.
- `./script/check_trace_eval_self_test.sh`: passed after trace evaluation started verifying screenshot files and placement failure details.
- `./script/check_typing_performance_log_self_test.sh`: passed after typing performance checks defaulted to a bounded recent log window.
- `AUTOCOMPLETE_LAB_LOG_START_LINE=75390 AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES=1 ./script/check_typing_performance_log.sh`: passed on the fresh TextEdit smoke slice with event-tap p95 96us. Off-main focused-text poll warnings are reported separately so slow AX reads do not masquerade as key latency.
- `git diff --check`: passed for the current hardening patch before commit.
- Settings polish pass: `swift build --target AutocompleteLabApp`, `swift test --filter AutocompleteLabAppTests`, and full `swift test` passed before commit `95f9583`.
- Screenshot-evidence pass: `script/check_trace_eval_self_test.sh`, `script/check_visual_placement_evidence_self_test.sh`, and `script/check_visual_placement_evidence.sh` passed before commit `faffcad`.
- App proof matrix pass: `git diff --check` and `./script/check_visual_placement_evidence.sh` passed before commit `6ef3bd1`.
- Prior full `swift test`: 273 tests passed before this script/docs-only no-submit fixture pass; no Swift sources changed in this loop.
- Apple-native placement pass: `swift test` now passes 274 tests after adding the inline frame guard that clips at the caret and suppresses too-narrow inline panels instead of showing invisible or wrong-side ghost text.
- `./script/manual_smoke_self_test.sh`: passed after adding Chrome chat-like no-submit to the self-test proof ledger.
- `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/manual_smoke_session.sh script/manual_smoke_status.sh`: passed after adding the chat-like no-submit guard.
- `./script/real_app_smoke_self_test.sh`: passed, including dry-run coverage for the Chrome chat-like fixture and the all-fixtures plan.
- `AUTOCOMPLETE_LAB_CHROME_FIXTURE=chat-like ./script/manual_smoke_session.sh chrome --print`: passed and points chat-like proof toward `script/real_app_smoke.sh chrome --fixture chat-like` so submit count is checked.
- `./script/manual_smoke_self_test.sh`: passed.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit`: passed with two verified accepts and screenshot capture.
- `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh chrome --fixture chat-like`: passed with two verified accepts, strict visual trace evidence, and submit count zero after switching the fixture check from Chrome JavaScript execution to a tab-title submit marker.
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
- Parent handoff: a disposable Notes note produced screenshot-backed suggestion presentation and at least one verified Tab insertion, but this is generic historical evidence only. The later bounded Notes title and body runs are complete; checklist still needs its own proof.
- `./script/manual_smoke_status.sh --strict`: now shows Chrome chat-like no-submit, Obsidian, and Notes title/body/checklist as passed, and fails honestly on prompt-app proof plus remaining score targets. The current blockers remain Codex, Claude Code, and Claude desktop insertion proof plus Claude Code/Claude desktop screenshot proof.
- `./script/check_visual_placement_evidence_self_test.sh`: passed, including missing, empty, invalid, too-small, unreferenced, and pending strict screenshot failure cases.
- `./script/check_visual_placement_evidence.sh`: passed with twelve verified visual-placement screenshots and reports two pending screenshot audits.
- `./script/check_visual_placement_evidence.sh --require-all`: fails honestly on the two pending screenshot audits.
- `./script/manual_smoke_self_test.sh`: passed after prompt-app no-submit
  proof started requiring exactly one trace-level accept and rejecting
  trace-level full-accept or field-send finalization signals.
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
- Trusted visual offsets are now scoped to target app version, screen, and field
  shape, so a manual or future screenshot correction expires when that context
  changes instead of silently applying to a different layout.
- Manual visual nudges now target the visible suggestion's app instead of
  relying on frontmost-app state after the menu opens, and the visible ghost
  moves immediately after the nudge.
- Synthetic caret anchors now emit `placementAnchorSource=synthetic-caret` and
  medium confidence instead of pretending to be high-confidence real AX carets.
- Generic presentation observations can no longer make visual offsets trusted;
  only manual visual nudges and future screenshot visual corrections can.
- Screenshot pixel offset detection now has a pure, unit-tested detector that
  finds high-contrast ghost/panel drift inside a bounded search region, rejects
  blank or low-contrast screenshots, rejects outlier offsets, and feeds the
  existing visual correction trust gate.
- Screenshot capture now runs that detector after a PNG is captured and records
  offset metadata (`screenshotOffsetDetection`, confidence, pixels, dx/dy, and
  signal bounds).
- Per-app screenshot tracing now lets high-confidence detector output write a
  trusted scoped correction through `VisualPlacementCorrectionPolicy`; global
  screenshot tracing remains diagnostics-only.
- Screenshot traces now carry the capture rect in trace metadata and diagnostics.
- Suggestion presentation traces now carry the rendered panel rect, and
  diagnostics keep geometry-shaped keys readable instead of redacting them as
  text.
- Trace evaluation now has an opt-in strict visual-evidence gate that fails a
  screenshot-backed pass unless screenshot path, anchor rect, rendered panel
  rect, capture rect, and placement confidence are all present.
- Manual Notes proof now uses first-class `notes-title`, `notes-body`, and
  `notes-checklist` recorder targets; generic Notes rows are historical
  evidence only and do not close those gaps.
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
- Inline ghost frames now prefer staying attached to the caret over sliding left
  to fit inside cramped bounds; if too little visible width remains, the
  suggestion is suppressed so Tab cannot accept invisible text.
- A local Chrome chat-like no-submit fixture now tracks form submissions and
  fails the smoke run if Tab/full accept submits the disposable composer.
- A 15-minute Codex automation exists outside this repo to check this scorecard;
  the repository itself still treats the below-10 rows as open work.
- Typing performance checks now scan the last bounded log window by default
  while preserving an all-history override. The checker now treats event-tap
  latency as the hard typing guard and reports off-main focused-text poll
  slowness as a separate warning unless strict AX-poll enforcement is requested.
- Slow focused-text poll summaries and overlapping-poll summaries now apply
  throttle/backoff and hide visible suggestions instead of continuing to chase
  the caret during a slow AX stretch.
- Async model and streaming suggestions now refresh current focused app, field,
  prompt target, and surrounding text before display, suppressing stale results
  instead of showing ghost text at old geometry.
- Keyboard capture now starts only after `suggestionPanel.show` returns a usable
  panel frame, closing the invisible-panel/Tab-capture gap.
- The keyboard event tap now fails closed when macOS disables it for timeout or
  user-input reasons.
- AX value replacement removed fixed 30ms and 40ms sleeps from the accept hot
  path while keeping immediate read-back confirmation plus async insertion
  verification.
- Recent word memory is now scoped by app bundle, so learned local vocabulary
  does not bleed from one app into another.
- Fast word completion now uses the same repeated-miss suppression as model
  completions before showing anything.
- The global word-completion list no longer includes Codex, Transcripted,
  autocomplete, diagnostics, traces, or other lab/debug vocabulary.
- Dogfood prompt detection now uses explicit phrases and token boundaries, so
  normal words like `table`, `stable`, `model`, and `test` do not pull
  suggestions toward autocomplete debugging topics.
- Settings now uses clearer native sections, checkbox controls, app state copy,
  privacy diagnostics copy, and app-target state tests.
- Raw text capture, global screenshot tracing, and per-app screenshot tracing
  now expire when enabled from Settings, and deleting local privacy logs also
  disables those capture modes where possible.
- Settings and menu copy now expose green/yellow/diagnostics-only/unsupported
  app support status and disable toggles for unavailable apps.
- A serial off-main focused-text AX reader now exists with tests, and AppDelegate
  routes live focused-text polling through it.
- App-specific focused-text AX health now cools down only the slow app after
  repeated slow reads, records active cooldown/recovery diagnostics, and keeps
  typing passthrough separate from suggestion responsiveness.
- Diagnostics now shows typing-health and placement-confidence summaries; recent
  trace rows show text lengths instead of raw suggestion or accepted text.
- Settings now shows the last suggestion decision as "Why", and menu bar status
  copy is calmer while detailed reasons stay in the tooltip/diagnostics.
- Codex, Claude Code, and Claude desktop prompt profiles require one-word
  no-submit proof and keep full accept disabled until separate full-accept
  no-submit proof exists. Prompt completions now reject unsafe submit/run
  actions.
- Prompt-app smoke proof now requires exactly one trace-level accepted
  suggestion and rejects full-accept or field-send finalization signals before
  it records Codex, Claude Code, or Claude desktop as a prompt no-submit pass.
- Output cleaning suppresses more assistant-y starts and rejects unrelated
  whole-word completions in word-completion mode. It also rejects
  recommendation, rewrite, and next-action candidates so a separate product
  behavior cannot masquerade as inline autocomplete.
- Word completion keeps suffix-only behavior while preserving typed casing, so
  uppercase fragments complete with uppercase suffixes and mixed-case recent
  words can keep their useful casing.
- Sentence-mode ranking now suppresses invented action commitments like
  scheduling, calls, new names, and dates instead of treating them as harmless
  sentence starters.
- Repeated typed-over misses now escalate from a short prefix cooldown to a
  longer quiet period for that same app/field/mode/prefix family.
- Punctuation cadence is now profile-aware at fragile boundaries: email
  greeting commas and short list-label colons wait longer, while coding closing
  brackets stay quiet.
- Sentence continuations now keep a tighter 10-token generation ceiling even
  when environment overrides raise the global ambient token cap.
- Accepted-kept style memory now includes raw-text-free suffix shape: short
  suffix rate and average final-token length.
- Chrome chat-like no-submit proof now uses a tab-title submit counter so the
  smoke test works even when Chrome JavaScript execution from Apple Events is
  disabled.
- Real-app smoke now waits for and verifies the configured full-accept shortcut
  (`backtick` or `optionTab`) instead of hard-coding Backtick, which fixed a
  live TextEdit smoke failure on machines where the shortcut state differs.
- The post-typing focused-text poll pause increased from 120ms to 220ms so
  repeated normal typing gives AX reads more room before the app resumes chasing
  the caret.
- Score targets are now checked by `script/check_score_targets.sh`, self-tested
  by `script/check_score_targets_self_test.sh`, and looped by
  `script/scorecard_goal_loop.sh --iterations 10` together with strict manual
  smoke status, strict visual evidence, and the proof manifest gate.
- `script/typing_performance_endurance_soak.sh` now wraps the safe TextEdit
  soak with a 10-minute default, computed AppleScript timeout, and dry-run
  self-test coverage.
- Unproven Notes and prompt-app profiles are now mirror-first with detached
  whole-field/window suggestions still disabled, so missing proof makes the app
  quieter instead of pretending inline placement is native.
- Inline suggestions now hide unless at least one useful-word-width can fit
  after the caret, so cramped fields fail quiet instead of showing clipped
  fragments.
- Compatibility placement trust is now pinned in core tests: unproven yellow
  apps suppress low-confidence and synthetic placement unless a trusted manual
  or screenshot visual correction exists.
- Learned visual offsets now carry app-version, screen-layout, and field-shape
  scope; the live app strips the offset when any of those proof conditions
  change.
- Repeated placement uncertainty is now field-scoped: after the threshold is
  reached, the current field is suppressed so the app stops retrying unsafe
  placement until focus changes or a clean placement resets the count.

## Remaining Gaps

1. Run recorder-grade screenshot-backed audits for Obsidian, Notes title/body/checklist,
   Claude desktop, and Claude Code with disposable text only. Run Notes as
   three explicit surface commands:
   `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate`,
   `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`,
   and `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate`.
   Codex has visual proof now, but still needs one-word accept/no-submit proof
   in the same strict visual trace slice.
2. Prove automatic screenshot-driven self-healing in real apps: rerun smoke
   after a trusted scoped correction is written, and keep the proof.
3. Test real production Monaco, ProseMirror, and CodeMirror apps, not just local
   fixtures.
4. Add a guided post-enable proof pass so first-run setup can confirm TextEdit
   insertion and placement before the user tries riskier apps.
5. Add a fuller shortcut editor if beta users need more than Tab plus the
   current full-accept toggle in proven apps.
6. Keep focused-text polling on the serial AX reader and collect live long-form
   typing proof in the worst real apps.
7. Use the same no-submit expectation for Codex/Claude prompt-app proof now
   that the local Chrome chat-like fixture has screenshot-backed proof.
8. Split AppDelegate into focused services around polling, insertion,
   verification, screenshot tracing, and placement tuning.
9. Private beta feedback now uses one-row reports and forbids raw typed text,
   prompts, screenshots, document names, URLs, recipients, subject lines, and
   trace excerpts by default.
10. Run explicit disposable raw-content dogfood audits for suggestion quality;
   default tracing correctly protects privacy, but it cannot fully grade output
   relevance without opt-in raw text.
11. Keep `./script/check_score_targets.sh` and
    `./script/scorecard_goal_loop.sh --iterations 10` failing until every target
    row has real app proof, then raise scores only in the same commit as the
    proof.
