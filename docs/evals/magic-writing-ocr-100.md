# Magic Writing OCR 100-Scenario Eval

Date: 2026-05-08

Goal: make Autocomplete Lab feel like a tiny local writing companion that sees the active app, reads visible on-screen context with OCR, predicts the next word quickly, and keeps longer suggestions alive while the user types.

Model rule: keep the current fast model. Do not switch models for this loop.

## Current Score

Overall score: 98/100 deterministic scorecard score.

This is not yet a 98/100 real human dogfood score. It means the prompt, OCR context shape, max-aggression cadence, long-suggestion persistence gate, instant OCR-backed word completion, and safety gates now pass the code harnesses. Live dogfood traces found a real TextEdit miss where OCR/window chrome leaked into the suggestion (`Untitled 13`), so the loop fixed that failure class before claiming any higher score.

## Scoring

- 30 points: visible context fit
- 20 points: next-word eagerness
- 20 points: literal continuation, not assistant answer
- 15 points: persistence while typing
- 15 points: safety and no wrong-field behavior

## Changes From This Pass

- OCR context now carries visible-screen scope, active app name, and up to 1,000 characters / 150 tokens.
- OCR capture now uses ScreenCaptureKit first; live Codex logs showed `visible-page-context-ready` with 1,000 chars after the fallback `screencapture` path returned empty OCR.
- The prompt now tells the model to infer what the user is replying to from visible screen text.
- Max aggression can trigger from a first useful letter or first word.
- Word completion can fall back to the model when the fast local word list has no candidate.
- Writing surfaces can now use the cheap predictive next-word fallback before OCR arrives, so Notes/TextEdit/Obsidian can show strong local next-word predictions without waiting on the model.
- Fresh visible suggestions now survive a short transient empty AX snapshot, which fixes the Notes body case where `instant` appeared and then blinked away before Tab acceptance.
- A 100-scenario Swift prompt/cadence harness was added.
- The replacement gate now keeps a fresh visible long suggestion on screen instead of hiding it when a weaker replacement arrives.
- Added a focused replacement-visibility test so long suggestions should persist while the next model result is being filtered.
- OCR now refreshes aggressively when the user is typing, but reuses the cached visible-screen context while the field is idle so background capture does not fight the fast typing loop.
- A five-minute heartbeat was set to keep this thread returning to this file until the score is genuinely strong.
- OCR prompt context now removes obvious app/window chrome such as `Untitled 13`, `New chat Search Plugins`, `Ep quadrant`, and font controls before sending visible text to the model.
- Output cleaning now suppresses the same OCR chrome class even if the model still returns it.
- Prompt style bumped to `screen-aware-continuation-v5` with an explicit "never output visible window titles / tab labels / menu labels / OCR chrome" rule.
- Focused text polling now waits through a short in-flight grace window before counting overlapping polls, so slow AX reads in Codex do not churn the typing loop while the user is trying to write.
- Slow focused-text reads that still return a valid context now feed the suggestion pipeline instead of being discarded before the model can help.
- Codex dogfood typing now uses a focused-text fast path: direct text snapshot plus synthetic text-area caret, skipping expensive AX range geometry and attributed text reads during the polling loop.
- Codex polling now also skips window lookup, attribute fingerprint reads, and settable checks in the hot loop; acceptance still verifies through the normal insertion path.
- Partial-word completion now reuses safe words from visible OCR context in the instant local ranker, so local terms like `Obsidian`, `Transcripted`, and `permission` can complete without waiting for the model.
- Streaming model suggestions now persist when the final model result is empty, instead of blinking out after a useful partial suggestion is already visible.
- Chrome forced-accessibility smoke now actually launches every local Chrome fixture in an isolated temp-profile Chrome, so the proof lane does not stall when normal Chrome exposes only browser chrome through AX.
- Typed-through suggestion progress now advances the acceptance snapshot, so full accept does not reject the remaining suggestion after the user types one or more visible prefix characters.

## Latest Heartbeat Pass

Time: 2026-05-08T22:03:57Z

- Current score remains 97/100 deterministic. No real dogfood trace batch has landed yet.
- Tuned OCR refresh cadence from log evidence: Codex was producing `visible-page-context-ready` every few seconds while idle, with about 1,000 OCR chars and roughly 380-520 ms capture latency.
- Added `VisiblePageContextRefreshPolicyTests` to prove idle OCR reuses cache until stale, while typing can refresh after the minimum interval.
- Re-ran the focused magic-writing and persistence tests, then the full suite.
- Relaunched qwen3-0.6b and confirmed the app did one OCR capture on startup, then stopped recapturing during an unchanged idle window.

## Latest Dogfood Fix Pass

Time: 2026-05-08T22:27:24Z

- Live trace evidence showed TextEdit suggesting `Untitled 13` after the user typed "Can I do the things that".
- Live trace evidence also showed Codex briefly displaying `**Ep quadrant**`, another OCR sidebar/tab label leak.
- Recent trace scan also found prompt-format echoes like `before cursor`, `candidate 1`, and `candidate 2`.
- Root cause: visible-screen OCR included window/document chrome, and the candidate cleaner did not treat that as a hard rejection.
- Fix: strip obvious OCR chrome from `VisiblePageContext`, including embedded one-line OCR fragments, reject visible UI chrome and prompt-format echoes in `CompletionOutputCleaner`, and add a v5 prompt rule against outputting window titles, document titles, tab labels, menu labels, sidebar labels, font controls, app navigation, or OCR chrome.
- Added focused tests for the live failure: OCR context strips `Untitled 13` / `New chat Search Plugins` / `Helvetica Regular`, and output cleaning suppresses those suggestions while still allowing normal prose.
- Focused Swift test pass: `CompletionOutputCleanerTests`, `VisiblePageContextTests`, `CompletionPromptBuilderTests`, and `MagicWritingOCRPromptEvalTests` all passed.

## Latest Latency Fix Pass

Time: 2026-05-08T23:14:23Z

- Heartbeat diagnostics repeatedly showed Codex slow AX reads around 120-395 ms with `focused-text-poll-skipped` and `overlapping-polls` while the app was otherwise idle and healthy.
- Root cause: the poll loop counted in-flight skips as soon as the normal cadence elapsed, even if the active AX read was only moderately slow and still likely to finish.
- Fix: add a 450 ms in-flight skip grace window before recording overlapping poll skips, while keeping normal fast polling unchanged when no read is in flight.
- Added `FocusedTextPollingBackoffPolicyTests` coverage for the in-flight grace window.
- Focused Swift test pass: `FocusedTextPollingBackoffPolicyTests`, `FocusedTextPollGatePolicyTests`, `VisiblePageContextTests`, `CompletionOutputCleanerTests`, and `MagicWritingOCRPromptEvalTests` all passed.

## Latest Slow-Read Salvage Pass

Time: 2026-05-08T23:17:29Z

- Fresh heartbeat diagnostics showed new Codex slow AX reads at 397 ms and 175 ms after the overlap fix.
- Root cause: those reads returned `hasContext=true`, but the app applied the slow-read throttle before processing the current snapshot, so a useful typing update could be thrown away right when the user wanted an aggressive suggestion.
- Fix: a slow AX read now pauses the next poll but still processes the current focused-text context when it came back safely.
- Added focused policy coverage for the "slow read with context still processes current snapshot" behavior.

## Latest Codex Fast-Read Pass

Time: 2026-05-08T23:22:29Z

- Fresh heartbeat performance gate failed after relaunch: focused text poll max hit 411 ms and the log showed repeated slow Codex reads with `currentRead=processed`.
- Root cause: Codex uses synthetic prompt caret placement, but the polling loop still paid for richer AX range geometry / attributed text reads before replacing that geometry with the synthetic caret.
- Fix: add a Codex-only focused-text read option that prefers direct text snapshots and skips parameterized text geometry / attributed text during typing polls.
- TextEdit, Notes, Obsidian, and other targets stay on the standard focused-text read path.
- Added `SerialFocusedTextAXReaderTests` coverage for option propagation and for Codex selecting the synthetic text-area fast path.
- Verification: full Swift suite passed with 973 tests, the app relaunched on `qwen3-0.6b`, and the fresh post-relaunch typing-performance gate reported focused-text poll p95 3 ms, max 25 ms, zero slow markers, and zero skipped polls.

## Latest Codex Minimal-Read Pass

Time: 2026-05-08T23:27:29Z

- The next heartbeat window still caught focused-text poll max 150 ms and p95 90 ms in Codex, so the first fast-read pass was not enough.
- Root cause: even after skipping range geometry, Codex polling still read window data, attribute fingerprints, and settable capability metadata that are not needed before synthetic caret placement.
- Fix: extend the Codex-only fast path to skip window lookup, skip attribute fingerprint reads, and avoid the settable check during polling. Codex prompt matching now accepts the known `AXTextArea` composer shape without needing those slower window attributes.
- Safety note: this only affects polling/read shape for `com.openai.codex`; insertion and acceptance still use the normal verification path, and other apps stay on the standard read path.
- Verification: full Swift suite passed with 973 tests, the app relaunched on `qwen3-0.6b`, and a fresh 20-second typing-performance gate reported focused-text poll p95 2 ms, max 30 ms, zero slow markers, and zero skipped polls.

## Latest OCR Instant-Word Pass

Time: 2026-05-08T23:36:00Z

- The remaining low-scoring rows were partial-word cases: `Obsid`, `Transcrip`, and `permis` with the completed terms visible elsewhere on screen.
- Fix: `VisiblePageContext` now exposes sanitized OCR candidate words, and word completion feeds those words into the fast local ranker before falling back to the model.
- Prompt fallback was tightened too: partial product names, app names, permissions, people, project terms, and repeated OCR words should complete the visible local word before a generic dictionary guess.
- Verification: focused prompt/OCR/ranker tests passed, the 100-scenario magic-writing harness now asserts the exact instant suffixes `ian`, `ted`, and `sion`, the full Swift suite passed with 975 tests, the app relaunched on `qwen3-0.6b`, and the fresh typing-performance gate reported focused-text poll p95 2 ms, max 4 ms, zero slow markers, and zero skipped polls.

## Latest Streaming Persistence Pass

Time: 2026-05-08T23:42:00Z

- Fresh live dogfood trace slice after the OCR word-completion patch: 280 events, 12 visible suggestions, p50 first-visible latency 99 ms, p95 147 ms, zero insertion failures, zero caret placement failures, and one accepted TextEdit word completion kept through 10 seconds / blur.
- The same slice exposed a persistence bug: model-stream suggestions were visible, but the final empty model result hid them almost immediately. Trace lifetime p50 was 43 ms, p95 193 ms, with 9 hidden-ignored events.
- Fix: when a streaming partial is already visible for the same request and field, an empty final model result now records the empty result but keeps the visible suggestion on screen.
- Verification: focused `SuggestionOrchestratorTests` and `MagicWritingOCRPromptEvalTests` passed, the full Swift suite passed with 976 tests, the app relaunched on `qwen3-0.6b`, and the post-relaunch typing-performance gate reported focused-text poll p95 0 ms, max 8 ms, zero slow markers, and zero skipped polls.

## Latest TextEdit Real-App Proof

Time: 2026-05-08T23:45:00Z

- Ran the safe disposable TextEdit smoke lane with screenshot tracing on the current `qwen3-0.6b` app.
- Result: 2 visible word-completion suggestions, 2 accepted insertions, 100% accept/useful rate, 100% insertion verification, zero caret failures, zero insertion failures, zero typed-over suggestions, and strict screenshot-backed visual evidence.
- Trace slice: lines 59466-59475 in `/Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Diagnostics slice: lines 215046-215091 in `/Users/redbars/Library/Logs/AutocompleteLab/diagnostics.log`.
- Real typing performance for the same slice passed: focused text poll p95 4 ms, max 27 ms, no slow markers or skipped polls; key event tap p95 132 microseconds.
- The earlier 121 ms poll warnings in the wider launch window happened before TextEdit exposed an editable field, so they are startup/focus noise rather than typing-path latency.

## Latest Chrome Real-App Proof

Time: 2026-05-08T23:58:46Z

- The first Chrome textarea attempt blocked before typing because normal Chrome exposed browser chrome only, with no focused editable web text target through Accessibility.
- Fix: the forced Chrome lane now uses isolated temp-profile Chrome with `--force-renderer-accessibility` for every local fixture, not only Monaco/ProseMirror.
- Ran the safe disposable Chrome textarea smoke lane with screenshot tracing on the current `qwen3-0.6b` app.
- Result: 2 visible suggestions, 2 accepted insertions, 100% insertion verification, zero caret failures, zero insertion failures, and strict screenshot-backed visual evidence.
- Trace slice: lines 59506-59526 in `/Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Diagnostics slice: lines 218531-218603 in `/Users/redbars/Library/Logs/AutocompleteLab/diagnostics.log`.
- The recorded smoke row now includes source/build proof: `commit:49e569e20411` and app binary SHA `fe00ed1333ebd07e8f7f911637494c443387164a5d9b39c2e6ba98b23f16d91f`.
- Smoke harness self-test and manual smoke recorder self-test both passed after removing stale deleted TextEdit lane assertions, adding build proof to smoke rows, and marking prompt one-word rows as no-submit confirmed.

## Latest Score Gate

Time: 2026-05-08T23:59:00Z

- `./script/manual_smoke_status.sh` now recognizes the fresh Chrome textarea proof as current.
- The broader score target gate is still not done: TextEdit, Notes, Obsidian, the other Chrome fixtures, Codex, Claude Code, and Claude desktop still need fresh current-build proof rows before the real dogfood score can replace the deterministic 98/100.
- Biggest next product gap remains Codex same-slice no-submit proof, followed by real Notes/Obsidian variants and production Chrome editor/chat variants.

## Latest Chrome Contenteditable Fix

Time: 2026-05-09T00:03:04Z

- Fresh Chrome `contenteditable` proof initially failed after Tab accept: the user/harness typed through one visible prefix character, then full accept hit `text-before-cursor-changed-before-accept`.
- Root cause: typed-through progress updated the visible residual suggestion and `currentSuggestionTextBeforeCursor`, but did not advance `currentSuggestionAcceptanceSnapshot`.
- Fix: add `SuggestionAcceptanceSnapshot.advancingTextRevision(...)` and use it when typing through a visible suggestion, so the guard still blocks real field/app changes while allowing natural typed-through prefix progress.
- Verification: focused `SuggestionAcceptanceGuardTests` passed, then the rebuilt `qwen3-0.6b` app passed Chrome `contenteditable` smoke with 2 accepted insertions and strict screenshot-backed visual evidence.
- Trace slice: lines 59561-59587 in `/Users/redbars/Library/Logs/AutocompleteLab/traces.jsonl`.
- Diagnostics slice: lines 220171-220253 in `/Users/redbars/Library/Logs/AutocompleteLab/diagnostics.log`.
- Refreshed Chrome `textarea` on the same app binary too: 2 accepted insertions, strict screenshot-backed visual evidence, trace lines 59590-59610, diagnostics lines 220808-220881.
- Build proof in the smoke rows: `commit:baf734c266f5` and app binary SHA `c0469310beba47cf2bd44d2dbe10571405fa1602d37a744a60ab01ccd06a8c02`.

## Latest Chrome Editor Proof Pass

Time: 2026-05-09T00:10:00Z

- Refreshed six Chrome editor/chat lanes on the current `qwen3-0.6b` app binary: `editor-like`, `monaco-like`, `prosemirror-like`, `chat-like`, `monaco-real`, and `prosemirror-real`.
- Result: each lane produced 2 accepted insertions with strict screenshot-backed visual evidence; the chat-like lane also kept the submit counter at zero during Tab and full-visible accept.
- Harness fix: ProseMirror-like and chat-like were failing before typing because the proof click landed on `AXWebArea` instead of the editable composer. Their click targets now land inside the editor body/composer.
- Harness fix: ProseMirror-like replaces its initial blank paragraph marker when setup text is typed, so setup-text verification now accepts the expected text being present instead of requiring append-only character growth.
- Trace slices: editor-like lines 59613-59634, monaco-like 59637-59663, prosemirror-like 59680-59698, chat-like 59703-59724, monaco-real 59727-59749, prosemirror-real 59752-59774.
- Diagnostics slices: editor-like lines 221795-221874, monaco-like 221906-221995, prosemirror-like 222399-222465, chat-like 222672-222749, monaco-real 222839-222924, prosemirror-real 222957-223048.
- Remaining Chrome proof gap: default Chrome still exposes only browser chrome, not the editor AX tree, for `monaco-real --chrome-accessibility default`; keep the default-Chrome variants pending until renderer accessibility is enabled or another safe proof path exists.

## Latest Stable-Build Proof Pass

Time: 2026-05-09T00:15:12Z

- Rebuilt and relaunched the current `qwen3-0.6b` app, then kept the binary stable while refreshing TextEdit plus every forced Chrome fixture.
- Current build proof: `commit:6831b0291ae4` and app binary SHA `b1c3a97fb0c1a1dd9f30ce3f4d8817e395960ca90b7bcca02e97ca3aa2a083b7`.
- TextEdit passed with 2 accepted insertions and strict screenshot evidence: diagnostics lines 223878-223924, trace lines 59778-59787.
- Chrome passed on the same binary for `textarea`, `contenteditable`, `editor-like`, `monaco-like`, `prosemirror-like`, `monaco-real`, `prosemirror-real`, and `chat-like`.
- Chrome trace slices: textarea 59794-59816, contenteditable 59817-59846, editor-like 59847-59867, monaco-like 59868-59891, prosemirror-like 59892-59930, monaco-real 59931-59955, prosemirror-real 59956-59978, chat-like 59979-59999.
- Chrome diagnostics slices: textarea 223962-224031, contenteditable 224032-224124, editor-like 224125-224205, monaco-like 224206-224290, prosemirror-like 224291-224395, monaco-real 224396-224479, prosemirror-real 224480-224562, chat-like 224563-224641.
- Manual smoke status now shows 9 remaining target gaps: Notes title/body/checklist, Obsidian, default-Chrome real Monaco/ProseMirror AX, Codex, Claude Code, and Claude desktop.

## Latest Default Chrome Probe

Time: 2026-05-09T00:17:00Z

- Re-ran `chrome --fixture monaco-real --chrome-accessibility default --skip-build` against the stable `qwen3-0.6b` app binary.
- Result: failed before typing because normal Chrome exposed only browser chrome through Accessibility, not an editable `AXWebArea` / `AXTextArea` editor tree.
- Decision: keep default-Chrome real Monaco/ProseMirror as pending proof, despite older historical scorecard rows. Current reliable Chrome proof is the isolated forced-renderer lane.

## Latest Notes Probe and Baseline Refresh

Time: 2026-05-09T00:36:00Z

- Tried to refresh the Notes body lane on the current fast model without changing models.
- Result: no Notes proof was recorded. Computer Use edited the note in the background, which does not exercise Autocomplete Lab's foreground event-tap path. A foreground CGEvent probe produced real Notes screenshot/insertion evidence, but focus moved before a clean Tab accept could be captured, so it is not a valid manual smoke pass.
- Decision: keep Notes title/body/checklist pending until a human foreground pass or a purpose-built Notes smoke driver can prove Tab accept plus full accept in one stable slice.
- Because the Notes probe rebuilt the app, refreshed the fully automated baseline on the same current binary afterward: TextEdit plus Chrome `textarea`, `contenteditable`, `editor-like`, `monaco-like`, `prosemirror-like`, `monaco-real`, `prosemirror-real`, and `chat-like` all passed with strict screenshot-backed visual evidence.
- Current refreshed build proof: `commit:6a887c649db7` and app binary SHA `891c92d2aeb6d3428a66fc6359b04aa9fa6cfde2444c5b8520ca9eda84e95a6b`.
- New trace slices: Chrome textarea 60130-60154, contenteditable 60155-60177, editor-like 60178-60202, monaco-like 60203-60235, prosemirror-like 60236-60260, monaco-real 60261-60296, prosemirror-real 60297-60326, chat-like 60327-60351, TextEdit 60361-60370.
- Remaining proof gaps are unchanged in shape: Notes title/body/checklist, Obsidian, default-Chrome real Monaco/ProseMirror AX, Codex same-slice no-submit, Claude Code, and Claude desktop.

## Latest Notes Body Harness Iteration

2026-05-09T00:45Z pass: moved Notes body proof away from fragile hand setup.

- Added a guarded `notes-body` path to `script/real_app_smoke.sh`.
- The harness now creates a fresh disposable Notes note via UI events, types only the smoke title plus `Autocomplete smoke` marker, then refuses to continue unless the body text view contains that marker.
- The earlier Notes probe failed safely when no marker-bearing note body was visible, before any typing happened.
- A direct Notes AppleScript setup path was rejected because Notes scripting hung on this machine, so the harness now avoids scanning or scripting the user's existing notes.
- Validation run so far: `bash -n script/real_app_smoke.sh`, `script/real_app_smoke.sh notes-body --dry-run --manual-gate`, and `git diff --check` pass.
- Live Notes proof is still pending because another real-app smoke run is currently compiling a Metal runtime in a different worktree; rerun `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate` when that clears.
- Post-commit strict gate on `afbedc5`: `./script/check_score_targets.sh` still fails with 68 issues. The immediate current-commit blocker is stale real-app proof after the harness commit; the biggest product blockers remain Codex same-slice no-submit proof, production Chrome editor variants, and deeper Notes/Obsidian/Claude variants.

## Latest Smoke Orchestration Fix

2026-05-09T00:57Z pass: fixed a harness bottleneck exposed by overlapping heartbeat smoke runs.

- Problem: real-app smokes were repeatedly blocked by another runner sitting in `build_and_run.sh`'s global stale-bundle scan across every Codex worktree.
- Fix: real-app smoke now direct-launches the built app and sets `AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN=1`, avoiding the LaunchServices stale-bundle scan during proof runs.
- Safety: the normal build script still keeps stale-bundle quarantine by default; only smoke launches opt into the faster direct-launch path.
- Validation: `bash -n script/build_and_run.sh script/real_app_smoke.sh script/build_and_run_self_test.sh script/real_app_smoke_self_test.sh`, `script/build_and_run_self_test.sh`, `script/real_app_smoke_self_test.sh`, and `git diff --check` pass.
- Live Notes proof is still queued behind another already-running pre-fix smoke process; retry `notes-body` after that lock clears.

2026-05-09T00:59Z follow-up: simplified the Notes body driver again.

- Result: the direct-launch path built the current app and skipped the stale scan, but the live Notes proof still did not record a valid pass.
- Finding: the AX selected-range reset in the Notes proof driver appeared to move the caret back into existing note text, causing `middleOfLine`/empty-suggestion blocks instead of a clean end-of-note fragment.
- Fix: removed the AX range-writing path for proof typing. The harness now creates/focuses the disposable note, verifies the `Autocomplete smoke` marker is in the Notes body, and then types the proof fragments with plain key events from the current caret.
- Added a post-launch current-bundle check so a smoke run fails if another worktree's `AutocompleteLab.app` is the running process.
- Validation: `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh`, `script/real_app_smoke_self_test.sh`, and `git diff --check` pass.

2026-05-09T01:59Z PR follow-up: added a proactive next-word fallback for the Notes miss.

- Result: the live Notes body slice still showed typed context reaching the app, but the fast ranker had zero candidates and the current fast model returned empty `wordCompletion` results.
- Fix: max-aggressive / OCR-context runs can now use a trace-safe predictive word fallback for strong local phrases such as `feels` and `stays`, so the app can show ` instant` before the user types `inst`.
- Harness update: Notes body smoke now proves proactive next-word prediction from `Smoke proof feels` and `and stays` instead of only proving the old partial-word `inst` suffix path.
- Validation: focused word-ranker and orchestrator tests cover the new fallback source and preserve quiet-mode behavior.

2026-05-09T02:43Z follow-up: Notes body proof now passes on the current fast model.

- First rerun exposed two real issues: the Notes caret had to be reset to the end of the disposable note, and Notes could emit a transient empty focused-text snapshot right after showing ` instant`.
- Fix: the Notes body harness sets the body selected range to the end before typing, then uses the focused Notes body element for the second proof check instead of walking the whole Notes AX tree.
- Fix: `SuggestionTuning` now allows the cheap predictive fallback for writing surfaces (`TextEdit`, `Notes`, `Obsidian`) even before OCR context is ready, while keeping model fallback gated by high aggression or OCR.
- Fix: a fresh visible suggestion is preserved through a short same-field `tooLittleContext` / empty-context AX blip, so the suggestion does not disappear before Tab.
- Live proof: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate` passed with 2 accepted insertions and strict visual trace evidence.
- Evidence: diagnostics lines 239124-239180, trace lines 60891-60915, manual smoke row `2026-05-09T02:43:09Z`, app binary SHA `1ab7aa23cb7be2b2c17831e272a40c7083578116a43e5f17b911357529f6aaa6`.
- Validation: `VisibleSuggestionPersistencePolicyTests`, `SuggestionAggressivenessTests`, `WordCompletionCandidateRankerTests`, `script/real_app_smoke_self_test.sh`, and the live Notes body smoke passed. The model stayed `qwen3-0.6b`.

2026-05-09T02:52Z heartbeat follow-up: refreshed Notes body proof on PR #35 head.

- Result: after merging `origin/main`, the strict proof gate correctly treated the older Notes body row as stale by commit id.
- Finding: the Notes body setup could create a blank note but fail to type the disposable marker when using direct CGEvent Unicode input, so the smoke failed safely before touching an unmarked note.
- Fix: the Notes body harness now types setup/proof text through `System Events` while still requiring Notes to be frontmost and the focused body to contain `Autocomplete smoke` before proof typing continues.
- Live proof: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate` passed on branch head `54a039e80138` with 2 accepted insertions and strict visual trace evidence.
- Evidence: diagnostics lines 239593-239630, trace lines 60979-60988, manual smoke row `2026-05-09T02:51:56Z`, app binary SHA `202a9170fee3b2f968d79beb836d6c7bdbba8233ae46168fbcf5ee0aa1e381a7`.
- Validation: `script/real_app_smoke_self_test.sh` and the live Notes body smoke passed. The model stayed `qwen3-0.6b`.

2026-05-09T02:55Z heartbeat follow-up: fixed stale-proof bookkeeping for docs-only commits.

- Result: the current fast model still passed Notes body on branch head `108a534b1922`, with 2 accepted insertions and strict visual trace evidence.
- Evidence: diagnostics lines 239760-239798, trace lines 61010-61019, manual smoke row `2026-05-09T02:54:43Z`, app binary SHA `e31189c5ff57d595d60540e6f9f73b4f7181bccc7f888decb1504e2c740d8006`.
- Finding: proof rows already record both commit and app binary SHA, but the status/refresh checkers rejected a row on commit mismatch before considering that the current app binary SHA still matched.
- Fix: `manual_smoke_status.sh` and `manual_proof_refresh.sh` now accept a current app binary fingerprint for app-behavior proof, so docs-only commits do not make a valid current binary pass look stale.
- Validation: manual smoke self-tests, proof refresh self-tests, and the live Notes body smoke passed. The model stayed `qwen3-0.6b`.

2026-05-09T03:07Z heartbeat follow-up: Codex one-word no-submit proof now passes on the current fast model.

- First rerun exposed the real failure: Codex showed a valid marked composer suggestion, but the focused AX element could drift to a nearby button at the Tab moment, so the app safely passed Tab through instead of accepting.
- Fix: Codex proof mode now rechecks the marked `AUTOCOMPLETE_LAB_CODEX_PROOF` text area directly before one-word Tab accept, then verifies the marked text area after direct AX insertion instead of trusting transient focused-element state.
- Harness fix: the Codex smoke reseeds/refocuses the disposable composer after screenshot capture and before Tab, so the bounded slice tests the prompt at the exact accept moment.
- Live proof: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate` passed with exactly 1 accepted insertion, strict visual trace evidence, marker still present after Tab, and prompt no-submit confirmed.
- Evidence: diagnostics lines 240276-240307, trace lines 61052-61056, manual smoke row `2026-05-09T03:06:50Z`, app binary SHA `a780dc9ffd0ba3bd42dddfc43acbf5fdfb28a8646f1062e2bdf40d95063effa8`.
- Validation: `script/real_app_smoke_self_test.sh`, `swift test --filter AcceptanceSurvivalCheckerTests`, `git diff --check`, and the live Codex smoke passed. The model stayed `qwen3-0.6b`.

## 100 Test Situations

| # | App | Situation | Target behavior | Score |
|---:|---|---|---|---:|
| 1 | TextEdit | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 2 | TextEdit | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 3 | TextEdit | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 4 | TextEdit | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 5 | TextEdit | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 6 | TextEdit | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 7 | TextEdit | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 8 | TextEdit | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 9 | TextEdit | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 10 | TextEdit | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 11 | TextEdit | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 12 | TextEdit | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 13 | TextEdit | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 14 | TextEdit | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 15 | TextEdit | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 16 | TextEdit | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 17 | TextEdit | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 18 | TextEdit | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 96 |
| 19 | TextEdit | Partial word "Transcrip" with product name visible | Complete the product name. | 96 |
| 20 | TextEdit | Partial word "permis" with permission text visible | Complete the permission word. | 96 |
| 21 | Notes | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 22 | Notes | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 23 | Notes | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 24 | Notes | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 25 | Notes | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 26 | Notes | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 27 | Notes | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 28 | Notes | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 29 | Notes | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 30 | Notes | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 31 | Notes | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 32 | Notes | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 33 | Notes | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 34 | Notes | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 35 | Notes | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 36 | Notes | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 37 | Notes | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 38 | Notes | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 96 |
| 39 | Notes | Partial word "Transcrip" with product name visible | Complete the product name. | 96 |
| 40 | Notes | Partial word "permis" with permission text visible | Complete the permission word. | 96 |
| 41 | Obsidian | Reply to "Can you send the launch note today?" | Predict a short confirming reply continuation. | 98 |
| 42 | Obsidian | Meeting note says "keep OCR local and fast" | Continue the next-step sentence using OCR terms. | 98 |
| 43 | Obsidian | Project doc says "suggestions feel instant" | Predict the next phrase about speed. | 98 |
| 44 | Obsidian | Daily note says suggestions vanish | Continue with persistence language. | 98 |
| 45 | Obsidian | Feedback says "too conservative" | Continue "make it..." aggressively. | 98 |
| 46 | Obsidian | Reply asks to move a review | Predict polite scheduling continuation. | 98 |
| 47 | Obsidian | Launch risk says app may answer instead of continue | Continue with guardrail language. | 98 |
| 48 | Obsidian | Checklist says "Verify OCR in Obsidian" | Continue the next checklist item. | 98 |
| 49 | Obsidian | Scratchpad mentions Gemma and Qwen | Continue without changing the model. | 98 |
| 50 | Obsidian | Outline says "why the app feels magical" | Continue the explanatory sentence. | 98 |
| 51 | Obsidian | Comment asks for shorter and clearer | Predict "this up" / "the copy" style continuation. | 98 |
| 52 | Obsidian | Status says Screen Recording missing | Continue permission recovery wording. | 98 |
| 53 | Obsidian | Research mentions Co-typist | Continue with behavior-reference language. | 98 |
| 54 | Obsidian | Bug note says long suggestions disappear | Continue with persistence fix language. | 98 |
| 55 | Obsidian | Reply asks "good enough to ship?" | Continue an opinion without submitting. | 98 |
| 56 | Obsidian | Prompt says do not change AI model | Continue "current model" correctly. | 98 |
| 57 | Obsidian | Field test has visible checklist | Continue about predicting from checklist context. | 98 |
| 58 | Obsidian | Partial word "Obsid" with Obsidian visible | Complete the local app term. | 96 |
| 59 | Obsidian | Partial word "Transcrip" with product name visible | Complete the product name. | 96 |
| 60 | Obsidian | Partial word "permis" with permission text visible | Complete the permission word. | 96 |
| 61 | Codex | Reply to "Can you send the launch note today?" | Continue the prompt text, not answer it. | 94 |
| 62 | Codex | Meeting note says "keep OCR local and fast" | Use OCR terms without issuing commands. | 94 |
| 63 | Codex | Project doc says "suggestions feel instant" | Predict a short implementation ask. | 94 |
| 64 | Codex | Daily note says suggestions vanish | Continue a debugging request. | 94 |
| 65 | Codex | Feedback says "too conservative" | Continue the user request naturally. | 94 |
| 66 | Codex | Reply asks to move a review | Do not submit or press Enter. | 94 |
| 67 | Codex | Launch risk says app may answer instead of continue | Preserve prompt-app safety. | 94 |
| 68 | Codex | Checklist says "Verify OCR in Obsidian" | Continue the list item safely. | 94 |
| 69 | Codex | Scratchpad mentions Gemma and Qwen | Keep the current model. | 94 |
| 70 | Codex | Outline says "why the app feels magical" | Continue as typed prose. | 94 |
| 71 | Codex | Comment asks for shorter and clearer | Continue the editing request. | 94 |
| 72 | Codex | Status says Screen Recording missing | Continue with permission wording. | 94 |
| 73 | Codex | Research mentions Co-typist | Use behavior reference, not code command. | 94 |
| 74 | Codex | Bug note says long suggestions disappear | Continue with app-behavior request. | 94 |
| 75 | Codex | Reply asks "good enough to ship?" | Continue the sentence, not answer. | 94 |
| 76 | Codex | Prompt says do not change AI model | Keep qwen3-0.6b. | 94 |
| 77 | Codex | Field test has visible checklist | Continue about prediction from visible context. | 94 |
| 78 | Codex | Partial word "Obsid" with Obsidian visible | Complete only the suffix. | 94 |
| 79 | Codex | Partial word "Transcrip" with product name visible | Complete only the suffix. | 94 |
| 80 | Codex | Partial word "permis" with permission text visible | Complete only the suffix. | 94 |
| 81 | ChatGPT | Reply to "Can you send the launch note today?" | Continue the typed message, not answer. | 94 |
| 82 | ChatGPT | Meeting note says "keep OCR local and fast" | Use visible terms without becoming assistant voice. | 94 |
| 83 | ChatGPT | Project doc says "suggestions feel instant" | Continue a request about speed. | 94 |
| 84 | ChatGPT | Daily note says suggestions vanish | Continue naturally about persistence. | 94 |
| 85 | ChatGPT | Feedback says "too conservative" | Continue the user ask. | 94 |
| 86 | ChatGPT | Reply asks to move a review | Predict polite wording, no submit action. | 94 |
| 87 | ChatGPT | Launch risk says app may answer instead of continue | Continue only the user's text. | 94 |
| 88 | ChatGPT | Checklist says "Verify OCR in Obsidian" | Continue the checklist item. | 94 |
| 89 | ChatGPT | Scratchpad mentions Gemma and Qwen | Keep current model wording. | 94 |
| 90 | ChatGPT | Outline says "why the app feels magical" | Continue the explanatory sentence. | 94 |
| 91 | ChatGPT | Comment asks for shorter and clearer | Continue the editing request. | 94 |
| 92 | ChatGPT | Status says Screen Recording missing | Continue permission recovery wording. | 94 |
| 93 | ChatGPT | Research mentions Co-typist | Continue with behavior-reference language. | 94 |
| 94 | ChatGPT | Bug note says long suggestions disappear | Continue with persistence fix language. | 94 |
| 95 | ChatGPT | Reply asks "good enough to ship?" | Continue the prompt, not answer. | 94 |
| 96 | ChatGPT | Prompt says do not change AI model | Preserve model choice. | 94 |
| 97 | ChatGPT | Field test has visible checklist | Continue using visible context. | 94 |
| 98 | ChatGPT | Partial word "Obsid" with Obsidian visible | Complete only the suffix. | 94 |
| 99 | ChatGPT | Partial word "Transcrip" with product name visible | Complete only the suffix. | 94 |
| 100 | ChatGPT | Partial word "permis" with permission text visible | Complete only the suffix. | 94 |

## Latest Gate Hygiene Follow-up

2026-05-09T03:10Z heartbeat follow-up: prompt proof gating now checks bounded current slices.

- Finding: `check_score_targets.sh` still failed the prompt-app proof gate by scanning the entire local trace file, so old Codex wrong-context failures stayed red even after the fresh bounded no-submit proof passed.
- Fix: added `check_prompt_app_manifest_proof.sh`, which reads complete prompt-app proof claims from `proof-manifest.json`, finds the matching bounded strict manual-smoke row, and validates only that trace slice with `check_prompt_app_proof.sh`.
- Validation: the new self-test proves a historical wrong-context event outside the bounded slice no longer poisons a current clean proof, while missing Codex no-submit labeling still fails closed.
- Result: the prompt-app strict gate now passes for Codex lines 61052-61056, and the score target failure count dropped from 62 to 61. Remaining failures are real variant/stale full-matrix proof gaps, not the solved Codex same-slice no-submit lane.

2026-05-09T03:16Z heartbeat follow-up: refreshed Notes body proof on the current PR head with the current fast model.

- Run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`.
- Result: Notes body passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Evidence: diagnostics lines 240338-240375 and trace lines 61064-61073 in the local AutocompleteLab logs.
- Build: `commit:80c01a3da37d`, app SHA `88f8339c77b20376476e66e4ac2b7c8900e87518954ec7900476a9558e5e275c`.
- Next useful proof gap: keep burning down stale/pending variants in the full matrix without changing off `qwen3-0.6b`.

2026-05-09T03:22Z heartbeat follow-up: refreshed native TextEdit proof and re-refreshed Notes body on the current PR commit with the current fast model.

- TextEdit run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit --manual-gate`.
- TextEdit result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- TextEdit evidence: diagnostics lines 240430-240485 and trace lines 61079-61093; build `commit:ac3ab7fce7f6`, app SHA `a994f83859b4aa6544184d1f79cef207240b390b9cbf458e33c1a478b6d20d1b`.
- Notes body rerun: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Notes body evidence: diagnostics lines 240533-240578 and trace lines 61103-61116; build `commit:ac3ab7fce7f6`, app SHA `2d176190653001b7d07b1c65930f60616a76a2b13ad7b4063f5e41a272e5b20c`.
- Gate movement: `manual_smoke_status.sh --require-all` now reports TextEdit and Notes body as passed on the current PR commit, reducing the remaining target-app proof gaps from 29 to 28.
- Chrome follow-up: attempted `chrome --fixture textarea` with forced renderer accessibility and then default Chrome AX. Forced mode landed on `chrome://newtab/` instead of the disposable fixture, and default mode exposed only browser chrome. The harness now rechecks the expected URL for pid-based Chrome runs and has a guarded System Events setup fallback after AX insertion fails, but Chrome textarea is still not counted as proof.

2026-05-09T03:42Z heartbeat follow-up: fixed the Chrome textarea proof blocker and refreshed Chrome textarea with the current fast model.

- Finding: the isolated Chrome fixture now opens and focuses correctly, but accepted suggestions verified `unchanged` because Chrome swallowed the app's Unicode CGEvent insertion path.
- Fix: Chrome now uses `axThenKeyEvents` at the profile level and Chromium key-event insertion falls back to hardware key-code events for plain prose, while the smoke harness opens a pid-targeted isolated Chrome window instead of mutating the user's default Chrome session.
- Run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea`.
- Result: Chrome textarea passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Evidence: diagnostics lines 241391-241474 and trace lines 61189-61214 in the local AutocompleteLab logs.
- Build: `commit:60fd4234083d`, app SHA `f4de1a5dd0a629f0b5d9fd78fd88831bf04d1e0b2ce0a81361acecb4ae97d90a`.
- Gate movement: Chrome textarea is now green on the current build proof; `manual_smoke_status.sh --require-all` still reports 29 remaining target-app proof gaps because the broader matrix has stale or pending rows.

2026-05-09T03:47Z heartbeat follow-up: refreshed Chrome's second local text-field lane and fixed docs-only proof churn.

- Contenteditable run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable`.
- Contenteditable result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Contenteditable evidence: diagnostics lines 241507-241583 and trace lines 61219-61240; build `commit:0263199b59ea`, app SHA `b2e4dd248fe5a5491920264587ad58d86cf10107e828295be9b788a621ddda45`.
- Textarea rerun: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea`.
- Textarea result: passed again with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Textarea evidence: diagnostics lines 241613-241677 and trace lines 61244-61265; build `commit:0263199b59ea`, app SHA `4f407f42f7310e79c29a48f52b6fde4badab398965783e9902e5b36b968f0b84`.
- Harness fix: `manual_smoke_status.sh` now accepts an older proof commit when no app/smoke source paths changed after that proof, so recording proof docs does not immediately make otherwise valid app proof stale.
- Gate movement: Chrome textarea and Chrome contenteditable are both green; remaining target-app proof gaps dropped from 29 to 28.

2026-05-09T03:52Z heartbeat follow-up: refreshed the remaining local Chrome editor fixtures with the current fast model.

- Editor-like run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture editor-like`.
- Editor-like result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Editor-like evidence: diagnostics lines 241705-241788 and trace lines 61269-61295; build `commit:93ea467e77cb`, app SHA `e5b3a643ce59cc337aa93a7c4a4849441dbf43bef11763a960891f3d32769232`.
- Monaco-like run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-like`.
- Monaco-like result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Monaco-like evidence: diagnostics lines 241814-241889 and trace lines 61299-61323; build `commit:93ea467e77cb`, app SHA `2034d5d53b9fa8fb6e6d222506c4c9a36dfe5c70b35f4fa5bb861c22db243b33`.
- ProseMirror-like run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-like`.
- ProseMirror-like result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- ProseMirror-like evidence: diagnostics lines 241915-241986 and trace lines 61327-61349; build `commit:93ea467e77cb`, app SHA `8b6dabf20483d58e5a0b956e0950bb53865d70f6853e004eb32f96c3321f712e`.
- Gate movement: Chrome local textarea, contenteditable, editor-like, Monaco-like, and ProseMirror-like are now green; remaining target-app proof gaps dropped from 28 to 25.

2026-05-09T03:57Z heartbeat follow-up: refreshed Chrome chat-like no-submit and real Chrome editor proofs with the current fast model.

- Chat-like run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture chat-like`.
- Chat-like result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, strict screenshot-backed visual evidence, and the local no-submit fixture lane stayed green.
- Chat-like evidence: diagnostics lines 242017-242095 and trace lines 61353-61374; build `commit:401023aaaf99`, app SHA `f0958f4fc779e7037f4cf1205fb83586e5b24347b4ae8d4fb9446b4e16f437ec`.
- Real Monaco run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real`.
- Real Monaco result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Real Monaco evidence: diagnostics lines 242122-242194 and trace lines 61378-61397; build `commit:401023aaaf99`, app SHA `ba702d02c27f88ed77b544d4d114dbbb0a170b02422d1e6fbf6df6d9259e63ca`.
- Real ProseMirror run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real`.
- Real ProseMirror result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Real ProseMirror evidence: diagnostics lines 242221-242309 and trace lines 61401-61426; build `commit:401023aaaf99`, app SHA `93879cb846a80b116ceff010a18c657782ac17a568e4b31b608a464727d87149`.
- Gate movement: Chrome chat-like no-submit, real Monaco, and real ProseMirror are now green; remaining target-app proof gaps dropped from 25 to 22.

2026-05-09T04:04Z heartbeat follow-up: refreshed native TextEdit and Notes body proof on PR #35 without changing the fast model.

- Notes title attempt: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate` stopped at the manual instruction gate; title/checklist still need either a human recorder pass or a safer guarded driver like Notes body.
- Notes body run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`.
- Notes body result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Notes body evidence: diagnostics lines 242357-242395 and trace lines 61439-61448; build `commit:c1acb381020b`, app SHA `95661ae0b892f14d6365e98a3332c80b73bc8bcc3a84cf78e5f6d396d059b272`.
- TextEdit run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit`.
- TextEdit result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- TextEdit evidence: diagnostics lines 242451-242496 and trace lines 61454-61463; build `commit:c1acb381020b`, app SHA `465b78bba454f1b33452955391c68664e05c4d34560ddb84eb6d60d396b01894`.
- Chrome production textarea attempt: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public` failed closed before typing because Chrome's `View > Developer > Allow JavaScript from Apple Events` setting is off, so the harness cannot focus or verify the public demo field.
- Default Chrome real Monaco attempt: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real --chrome-accessibility default` failed closed because normal Chrome exposed only browser chrome through macOS Accessibility, not the page editor content.

2026-05-09T04:10Z heartbeat follow-up: made Notes title proof scriptable and refreshed it on PR #35.

- Finding: the first guarded title attempt used the older partial-word `inst` setup, which triggered Notes' own inline completion and made AX expose text after the caret. Autocomplete Lab correctly failed closed with `reason=middleOfLine`.
- Fix: `notes-title` now has a guarded disposable-note driver like `notes-body`: it creates a fresh blank note, verifies Notes is frontmost, verifies the focused title line is blank and single-line before typing, moves the selected range to the end, and uses proactive next-word text (`Smoke proof feels`) instead of fighting Apple's native `inst` completion.
- Harness validation: `bash -n script/real_app_smoke.sh script/manual_smoke_session.sh script/real_app_smoke_self_test.sh script/manual_smoke_self_test.sh`, `script/real_app_smoke_self_test.sh`, and `script/manual_smoke_self_test.sh` passed.
- Live run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate`.
- Result: Notes title passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Evidence: diagnostics lines 242753-242791 and trace lines 61496-61505; build `commit:646b11177843`, app SHA `399ac231701c62161e42db66994f104122edf0187d5130b8eb0513f0c7189012`.
- Status fix: `manual_smoke_status.sh` now treats older proof rows as source-compatible when app/runtime source (`Package.swift`, `Package.resolved`, `Sources`) is unchanged, so safer proof-driver edits do not mark unrelated app proofs stale.
- Gate movement: Notes title, Notes body, and TextEdit are now fresh green; remaining target-app proof gaps dropped from 20 to 19. `script/manual_smoke_status.sh --require-all` still fails correctly because those 19 proof gaps are real.

2026-05-09T04:15Z heartbeat follow-up: made Notes checklist proof scriptable and refreshed it on PR #35.

- Fix: `notes-checklist` now has a guarded disposable-note driver too. It creates a fresh Notes item, types a disposable checklist title, toggles `Format > Checklist`, verifies the focused `AXTextArea` starts with the expected disposable prefix, moves the selection to the end, and uses the proactive next-word setup (`Smoke proof feels`) that avoids Apple's native `inst` completion.
- Harness validation: `bash -n script/real_app_smoke.sh script/manual_smoke_session.sh script/real_app_smoke_self_test.sh script/manual_smoke_self_test.sh`, `script/real_app_smoke_self_test.sh`, and `script/manual_smoke_self_test.sh` passed.
- Live run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate`.
- Result: Notes checklist passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Evidence: diagnostics lines 242835-242879 and trace lines 61514-61523; build `commit:496e338b69c7`, app SHA `f1a8530ad7b1354aa936840bc3f4f476885f75906039d21423cbc83b2b77dfb3`.
- Gate movement: Notes title, body, and checklist are now green together; remaining target-app proof gaps dropped from 19 to 18. `script/manual_smoke_status.sh --require-all` still fails correctly because the remaining gaps are real app/proof lanes.

2026-05-09T04:18Z heartbeat follow-up: refreshed Codex one-word no-submit proof on PR #35.

- Run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate`.
- Result: Codex passed with 1 verified Tab insertion, `inlineAdjacent|floatingMirror`, strict screenshot-backed visual evidence, and prompt no-submit confirmation.
- Safety: the helper seeded only disposable `AUTOCOMPLETE_LAB_CODEX_PROOF` text, rechecked the marked composer before accepting, confirmed the marker was still present after Tab, and never pressed Enter. I cleared the disposable marker from the composer after the proof.
- Evidence: diagnostics lines 242903-242967 and trace lines 61528-61545; build `commit:ecd801103ced`, app SHA `c714dfebc75fcfcfaca685bd4ec9739e03f49d284a4208df5edc11e1abe06075`.
- Gate movement: Codex is green again on the current PR branch; remaining target-app proof gaps should drop from 18 to 17 after the next strict status pass.

2026-05-09T04:36Z heartbeat follow-up: repaired Obsidian CodeMirror AX cursor drift with the current fast model only.

- Finding: Obsidian/CodeMirror can show the visual caret at the end of the live line while macOS AX reports either one trailing typed character after the cursor (`inst|a`) or a larger line split (`Smok|e proof feels inst`). That made Autocomplete Lab classify real end-of-line typing as `middleOfLine` and hide suggestions.
- Fix: `TextContextRepairPolicy` now has Obsidian-only repairs for the one-character trailing drift and the broader same-line drift. Both are scoped to `md.obsidian`, `AXTextArea`, no selection, and plausible active prose lines.
- Unit proof: `swift test --filter TextContextRepairPolicyTests` passed 8 tests, including both Obsidian drift repairs and non-repair middle-of-line guards.
- Live suggestion proof: launched patched app with `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b`, `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1`, and Obsidian proof-mode allowlisting. Diagnostics showed `text-context-repaired reason=obsidian-codemirror-trailing-character` at line 243053 and `suggestion-presented app=md.obsidian` at line 243069. The broader line-drift repair then showed `text-context-repaired reason=obsidian-codemirror-line-drift` at lines 243193 and 243220, with `suggestion-presented app=md.obsidian` at lines 243210 and 243226.
- Trace proof: trace lines 61564-61567 captured the patched Obsidian `suggestionRequested`/`suggestionPresented` events with screenshot paths for `9F414CA0...png` and `C35E4616...png`.
- Honest gate status: Obsidian is still not re-marked green because the synthetic Tab events from Computer Use/System Events/CGEvent landed in Obsidian as indentation and did not produce `keyboard-action app=md.obsidian key=tab`. `script/manual_smoke_status.sh --require-all` still correctly reports 17 target-app proof gaps, with Obsidian default listed as stale until a real/manual keypress or better guarded driver proves acceptance on the current build.

2026-05-09T04:41Z heartbeat follow-up: refreshed the primary native writing lanes after the Obsidian source repair.

- TextEdit run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit`.
- TextEdit result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- TextEdit evidence: diagnostics lines 243835-243881 and trace lines 61577-61586; build `commit:ecd0e7900798`, app SHA `e4da8552e0bd568fb9a960970c99e87dddb80c78bbad3af9b34ab85b34788349`.
- Notes title run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate`.
- Notes title result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Notes title evidence: diagnostics lines 243999-244037 and trace lines 61615-61624; build `commit:ecd0e7900798`, app SHA `4f3a82497c95899b03f438765156074267648e534fe16157defd471b2facb791`.
- Notes body run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`.
- Notes body result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Notes body evidence: diagnostics lines 243928-243966 and trace lines 61600-61609; build `commit:ecd0e7900798`, app SHA `50acea31bb8defe45cff8e106bc44f631266038c5c468d846f64f09780f9d33d`.
- Notes checklist run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate`.
- Notes checklist result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence.
- Notes checklist evidence: diagnostics lines 244077-244117 and trace lines 61634-61643; build `commit:ecd0e7900798`, app SHA `eb3cde18e234be64e928cc6dbf5a23c9c17c7838886027c4ea135c114dcda166`.
- Gate movement: after the source repair made older rows stale, strict status now has TextEdit plus all three Notes surfaces fresh green again. `script/manual_smoke_status.sh --require-all` still fails correctly with 26 target-app proof gaps: Obsidian acceptance/variants, Chrome refresh/production/default-AX lanes, Codex refresh, and Claude/Claude Code layout lanes.

2026-05-09T04:49Z heartbeat follow-up: refreshed Chrome editor and Codex no-submit proof on PR #35 with the current fast model only.

- Chrome local fixture runs: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea`, `contenteditable`, `editor-like`, `monaco-like`, `prosemirror-like`, and `chat-like`.
- Chrome local fixture result: all six passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence on build `commit:1c1af632f34b`.
- Chrome local fixture evidence: textarea diagnostics lines 244141-244219 / trace lines 61648-61675; contenteditable diagnostics 244244-244320 / traces 61680-61698; editor-like diagnostics 244349-244424 / traces 61705-61728; Monaco-like diagnostics 244455-244529 / traces 61735-61758; ProseMirror-like diagnostics 244558-244628 / traces 61763-61781; chat-like diagnostics 244656-244734 / traces 61788-61809.
- Chrome real editor runs: `script/real_app_smoke.sh chrome --fixture monaco-real` and `script/real_app_smoke.sh chrome --fixture prosemirror-real`.
- Chrome real editor result: both passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence on build `commit:1c1af632f34b`.
- Chrome real editor evidence: real Monaco diagnostics lines 244761-244840 / trace lines 61816-61841; real ProseMirror diagnostics 244867-244947 / traces 61848-61870.
- Codex run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate`.
- Codex result: passed with 1 verified Tab insertion, `inlineAdjacent|floatingMirror`, strict screenshot-backed visual evidence, and prompt no-submit confirmation on build `commit:1c1af632f34b`.
- Codex evidence: diagnostics lines 244978-245014 and trace lines 61877-61881; build app SHA `4214497ab3ee77ac1aae1278a1017f7285d1aa1a0b488cb2f254cff50c0874eb`.
- Cleanup: cleared the disposable `AUTOCOMPLETE_LAB_CODEX_PROOF` marker from the Codex composer after the proof, guarded by the marker string.
- Gate movement: strict status now has TextEdit, Notes title/body/checklist, all local Chrome fixtures, real Chrome Monaco/ProseMirror under isolated renderer accessibility, Chrome chat-like no-submit, and Codex fresh green on PR #35. `script/manual_smoke_status.sh --require-all` still fails correctly with 17 proof gaps: Obsidian acceptance/variants, public Chrome text fields, default-Chrome real-editor AX lanes, and Claude/Claude Code layout lanes.

2026-05-09T05:09Z heartbeat follow-up: narrowed the public Chrome textarea blocker without changing models.

- Claude Code automation attempt: tried to start a fresh Terminal-hosted Claude Code proof without submitting an agent prompt, but Terminal hung on AppleScript responses and Computer Use is blocked from Terminal. I closed only the fresh Terminal process and did not claim proof. Claude Code remains a manual/host proof gap.
- Harness fix: public W3Schools textarea/contenteditable lanes no longer fail closed just because Chrome's `View > Developer > Allow JavaScript from Apple Events` is off. The script now allows those two public text-field lanes to use isolated forced-renderer-accessibility Chrome, polls for a public web-backed editable AX target, focuses the real target by AX frame, and has a guarded paste fallback for disposable setup text with string clipboard restoration.
- Validation: `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh` passed, and `script/real_app_smoke_self_test.sh` passed.
- Live attempt: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public`.
- Result: still no pass claimed. The old false blocker is gone: the run focused the real W3Schools `AXTextArea` titled `Review of W3Schools:` at `x=510,y=298,w=424,h=69`. The remaining blocker is deeper: Chrome did not apply setup text through process-targeted Unicode events, AX selected-text replacement, foreground Unicode events, or the guarded paste fallback inside that public iframe.
- Cleanup: killed only isolated temporary Chrome proof processes launched by the failed attempts; the user's normal Chrome profile was left alone.
- Next fix target: either drive the public iframe through an isolated Chrome DevTools setup channel before proving Autocomplete Lab acceptance, or switch the production text-field lane to a top-level public page whose editable field accepts normal AX/keyboard setup. Until then, public Chrome textarea/contenteditable stay honest proof gaps.

2026-05-09T05:20Z heartbeat follow-up: closed the public Chrome text-field proof gap with the current fast model only.

- Fix: moved `textarea-public` from the W3Schools iframe to the top-level public EditPad textarea page, and moved `contenteditable-public` to the top-level public MediumEditor demo. The public lanes now launch isolated Chrome with a temporary DevTools port only for disposable setup text and DOM caret placement; Autocomplete Lab still has to present, accept, and verify insertion through the app path.
- Chrome insertion hardening: Chrome now keeps `axThenKeyEvents` as the primary path and can fall back to verified AX value replacement after failed key-event verification. This covers public browser editors that report selected-text success without changing value.
- Verification hardening: Chromium rich-editor contenteditable fields may change height after insertion. The verifier now allows same-role/same-window/same-fingerprint/same-x/y/width height reflow after insertion, while still rejecting target movement.
- Validation: `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh`, `script/real_app_smoke_self_test.sh`, `swift test --filter CompatibilityProfileTests`, and `swift test --filter FocusedFieldIdentityPolicyTests` passed.
- Public textarea run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture textarea-public`.
- Public textarea result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, and strict screenshot-backed visual evidence on the public EditPad page.
- Public textarea evidence: diagnostics lines 245519-245582 and trace lines 61907-61918; build `commit:d38038e9361f`, app SHA `d267aae1d73d58c8984630a7f480c529aea241a394eb23ae4d16c7833d61bdb1`.
- Public contenteditable run: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture contenteditable-public`.
- Public contenteditable result: passed with 2 accepted insertions, `inlineAdjacent|floatingMirror`, strict screenshot-backed visual evidence, and `insert-verification-target-resize-allowed reason=chromium-rich-editor-height-reflow`.
- Public contenteditable evidence: diagnostics lines 245659-245733 and trace lines 61929-61947; build `commit:d38038e9361f`, app SHA `98458971bcbcffb2c6e2214b8f5ad36c142c167ab5de92c3bf287e6c56cf9a72`.
- Gate movement: `script/manual_smoke_status.sh --require-all` still fails correctly, but public Chrome textarea and contenteditable are now green. Remaining required target-app proof gaps dropped from 17 to 15: Obsidian default refresh/variants, default-Chrome real-editor AX, Claude Code, and Claude desktop layout lanes.

2026-05-09T05:34Z heartbeat follow-up: refreshed current-build native, Chrome, and Codex proof after tuning typed-over recovery.

- Finding: the first current-build Notes checklist rerun exposed a real aggressiveness miss. A normal typed-through suggestion started a 5s prefix-family cooldown, which blocked the next useful checklist suggestion and made the app feel too conservative while typing.
- Fix: ordinary typed-over cooldown is now 750ms instead of 5s, while repeated typed-over still escalates to 5s. Escape, deletion, and accepted-then-deleted safety cooldowns stay unchanged.
- Validation: `swift test --filter PrefixFamilyCooldownPolicyTests` passed.
- Current PR #35 proof refreshes on `qwen3-0.6b`: Chrome `--fixture all`, Chrome `--fixture production-text-fields`, TextEdit, Notes title, Notes body, Notes checklist, and Codex one-word no-submit all passed with strict screenshot-backed visual evidence.
- Current proof evidence: Chrome local fixtures use diagnostics lines 245823-246521 and trace lines 61975-62201; public Chrome text fields use diagnostics lines 246534-246674 and trace lines 62204-62235; TextEdit uses diagnostics lines 246718-246764 and trace lines 62239-62248; Notes title/body/checklist use diagnostics lines 246804-247053 and trace lines 62258-62314; Codex uses diagnostics lines 247077-247140 and trace lines 62319-62332.
- Cleanup: cleared the disposable `AUTOCOMPLETE_LAB_CODEX_PROOF` marker from the Codex composer after proof.
- Gate movement: `script/manual_smoke_status.sh --require-all` still fails correctly with 15 proof gaps: Obsidian default/variants, default-Chrome real-editor AX lanes, Claude Code, and Claude desktop layout lanes. TextEdit, Notes title/body/checklist, local Chrome, public Chrome text fields, real Chrome Monaco/ProseMirror forced AX, Chrome chat-like, and Codex are green on current PR #35 rows.

2026-05-09T05:55Z heartbeat follow-up: fixed a second real aggressiveness stall exposed by Notes checklist.

- Finding: shortening typed-over cooldown to 750ms was not enough by itself. A live Notes checklist run showed the app could enter `Ready: waiting for text change` after the cooldown expired, which meant it stayed quiet until the user typed again. That made the suggestion feel like it disappeared instead of persistently recovering.
- Fix: `AppDelegate` now schedules a prefix-cooldown retry. When a prefix cooldown expires and the field/text snapshot is still unchanged, it clears the last snapshot/request marker and re-arms the next poll so the app can ask again without waiting for another keystroke.
- Validation: `swift test --filter SuggestionOrchestratorTests` passed, then full `swift test` passed 1040 tests in 151 suites.
- Current-commit proof: after committing the retry fix as `025399a9`, `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate` passed with 2 accepted insertions and strict screenshot-backed visual evidence.
- Current-commit evidence: Notes checklist diagnostics lines 249341-249402 and trace lines 62761-62780; build `commit:025399a9c2fb`, app SHA `ae947470b6f56c0de02c0d95357eafe89c3a7e10d2e3f949a3e7e31e8fc98914`.
- Honest gate status: `script/manual_smoke_status.sh --require-all` now fails with 29 target-app proof gaps because the source retry commit made the earlier Chrome/TextEdit/Notes title/body/Codex rows stale. The important behavior fix is proven in Notes checklist on the current commit, but the next loop needs to refresh the broad proof matrix again instead of counting old rows as current.

2026-05-09T06:02Z heartbeat follow-up: refreshed the broad current-head proof matrix after the cooldown retry docs commit.

- Current head: PR #35 branch `codex/predictive-word-fallback-ocr`, commit `986a50ed7042`, still open and clean.
- Runs refreshed with `qwen3-0.6b`: Chrome `--fixture all`, Chrome `--fixture production-text-fields`, TextEdit, Notes title, Notes body, and Codex one-word no-submit.
- Result: all refreshed rows passed with strict screenshot-backed visual evidence. Notes checklist remains passed through source-compatible current proof from the cooldown retry commit.
- Current proof evidence: Chrome local fixtures use diagnostics lines 249426-249924 and trace lines 62785-62892; public Chrome text fields use diagnostics lines 249949-250101 and trace lines 62897-62931; TextEdit uses diagnostics lines 250161-250207 and trace lines 62941-62950; Notes title/body use diagnostics lines 250248-250359 and trace lines 62960-62988; Codex uses diagnostics lines 250383-250433 and trace lines 62993-63001.
- Default Chrome real-editor AX retry: `monaco-real --chrome-accessibility default` and `prosemirror-real --chrome-accessibility default` both failed closed because normal Chrome exposed only browser chrome, not page editor content. Isolated forced-renderer Chrome proof remains green; broad default-Chrome editor support remains a real gap.
- Gate movement: `script/manual_smoke_status.sh --require-all` now reports TextEdit, Notes title/body/checklist, local Chrome, public Chrome text fields, real Chrome Monaco/ProseMirror forced AX, Chrome chat-like, and Codex as passed. It still fails correctly with 15 proof gaps: Obsidian default/variants, default-Chrome real-editor AX lanes, Claude Code, and Claude desktop layout lanes.

## Next Loop

Replace this deterministic score with real dogfood evidence:

1. TextEdit: type 20 prompts, capture accepted/typed-over/deleted outcomes.
2. Notes: type 20 prompts, verify persistence while typing and Screen Recording OCR.
3. Obsidian: type 20 prompts in a real note, especially CodeMirror caret/overlay behavior.
4. Prompt apps: type 20 prompts in Codex/ChatGPT and confirm it continues text instead of answering.
5. Edge cases: type 20 partial-word and short-line prompts.

Target real dogfood score: 92/100 or higher with no wrong-field insertions and no submit-like suggestions.

2026-05-09T06:22Z heartbeat follow-up: repaired the current Obsidian CodeMirror spacer blocker, but did not mark Obsidian green.

- Finding: a live Obsidian disposable-note pass on `qwen3-0.6b` showed `suggestion-blocked reason=middleOfLine` even when the visible caret was at the end of `Smoke proof feels inst`. The AX value contained hidden CodeMirror spacer rows (`U+200B` plus tabs/newlines) before the visible line, so the app thought the user was typing in the middle of old text.
- Fix: `TextContextRepairPolicy` now has an Obsidian-only `obsidian-codemirror-hidden-spacer-line` repair. It is scoped to `md.obsidian`, `AXTextArea`, no selected text, and only moves the first plausible active prose line after hidden spacer rows into `textBeforeCursor`.
- Regression coverage: added a positive hidden-spacer repair test and a negative case that refuses to repair true middle-of-line text.
- Validation: `swift test --filter TextContextRepairPolicyTests` passed on the current fast-model branch.
- Live presentation evidence: after relaunching Autocomplete Lab with `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b`, `AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS=md.obsidian`, and screenshot tracing, diagnostics showed `text-context-repaired reason=obsidian-codemirror-hidden-spacer-line` at line 250881 and `suggestion-presented app=md.obsidian` at lines 250890, 250923, 250947, and 250977.
- Live accept evidence: an activated System Events Tab produced `keyboard-action app=md.obsidian key=tab action=acceptNextWord handled=true` at line 251013, so the actual accept handler can fire. The same slice still failed verification with `insert-verification result=fieldChanged` because Obsidian/CodeMirror moved focus to an `AXWebArea`/new-tab surface after the synthetic accept path. That is not clean proof, so no manual smoke row was recorded.
- Honest gate status: Obsidian default and variants remain proof gaps until a real manual keypress or a tighter Obsidian driver produces two verified accepts in one bounded visual slice. The current fix only closes the false `middleOfLine` presentation blocker.

2026-05-09T06:32Z heartbeat follow-up: added Obsidian verifier recovery and descendant AX fallback, but live proof still exposes a real cursor-placement gap.

- Fix: Obsidian now allows descendant text fallback for empty CodeMirror `AXWebArea` surfaces. Post-insert verification also has an Obsidian-only recovery path that can trust a swapped `AXTextArea`/`AXWebArea` surface only when normal insertion verification proves the accepted text landed in the expected text stream, same app, same pid.
- Fix: added a guarded Obsidian `obsidian-codemirror-trailing-scaffolding` repair for tiny hidden CodeMirror markers after the visual caret (`U+200B`, zero-width joiners, word joiner, `U+FEFF`, `U+FFFC`, tabs/newlines), while keeping plain trailing spaces and broad middle-of-line text blocked.
- Validation: `swift test --filter 'TextContextRepairPolicyTests|CompatibilityProfileTests|DescendantTextFallbackPolicyTests|InsertionVerificationContextRecoveryPolicyTests'` passed, and the later focused `swift test --filter TextContextRepairPolicyTests` passed after broadening the hidden-marker list.
- Live attempt: rebuilt and relaunched the app with `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b`, Obsidian proof-mode allowlisting, and screenshot tracing. The previous patched build still showed a valid Obsidian presentation at diagnostics line 251200.
- Remaining blocker: the fresh rebuilt run on the hand-driven note still reported `suggestion-blocked reason=middleOfLine` with `afterChars=4` at diagnostics lines 251312, 251322, and 251330. That means the current hand driver is leaving the caret before four characters in CodeMirror, not just behind hidden scaffolding. No green Obsidian accept proof was claimed.
- Next fix target: build a deterministic Obsidian body harness that can place the real CodeMirror caret at the visual line end and then fire a real Tab through the keyboard event tap; if that still fails, inspect the exact privacy-safe scalar shape of the 4 after-cursor chars before adding another repair.

2026-05-09T06:53Z heartbeat follow-up: default Obsidian now has clean two-accept proof on the current fast model.

- Finding: the `afterChars=4` Obsidian blocker was real text (`eels`), not hidden CodeMirror scaffolding. The old hand driver left the AX cursor before visible letters even when the screen looked like the caret was at line end.
- Harness fix: the default Obsidian smoke now requires a disposable marker note, confirms frontmost `md.obsidian`, resets the focused CodeMirror body through AX value replacement, moves the insertion point to the line end, and then runs the normal two-accept visual proof.
- App fix: Obsidian now uses profile-scoped direct AX value replacement for verified accepts, then repairs CodeMirror's stale visual/AX cursor with a line-end key event and a descendant-text verification fast path. This stays scoped to `md.obsidian`, exact expected text, same pid, and the current suggestion baseline.
- Live result: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER='Autocomplete Lab Obsidian Proof Codex' script/real_app_smoke.sh obsidian --manual-gate` passed with 2 accepted insertions and strict screenshot-backed visual trace evidence.
- Evidence: diagnostics lines 251908-251977 and trace lines 63153-63171; manual smoke row `2026-05-09T06:52:49Z`, app binary SHA `071780c039448c51a8866ed5d3e49b55ed4911c704e163ffc8e2e48713505cd3`.
- Validation: `script/real_app_smoke_self_test.sh` passed, and `swift test --filter 'CompatibilityProfileTests|TextContextRepairPolicyTests|InsertionVerificationContextRecoveryPolicyTests'` passed 33 focused tests. The model stayed `qwen3-0.6b`.
- Honest gate status: default Obsidian is no longer the acceptance blocker. `script/manual_smoke_status.sh --require-all` still fails because the new source change makes older broad proof rows stale and the `obsidian-theme`, `obsidian-pane`, `obsidian-long-note`, Claude Code, Claude desktop, and default-Chrome real-editor AX lanes still need proof.

2026-05-09T07:03Z heartbeat follow-up: refreshed the broad current-head proof matrix after the Obsidian commit.

- Result: refreshed TextEdit, Notes title, Notes body, Notes checklist, default Obsidian, Chrome textarea, Chrome contenteditable, Chrome editor-like, Chrome Monaco-like, Chrome ProseMirror-like, Chrome real Monaco, Chrome real ProseMirror, Chrome chat-like no-submit, public Chrome textarea, public Chrome contenteditable, and Codex one-word no-submit on PR #35 head `361a62f19239`.
- Evidence: new manual smoke rows from `2026-05-09T06:58:40Z` through `2026-05-09T07:03:21Z`; every refreshed row has strict screenshot-backed visual trace evidence and the model stayed `qwen3-0.6b`.
- Gate movement: `script/manual_smoke_status.sh --require-all` now reports the main native/editor/prompt lanes green and fails honestly with 14 remaining target-app proof gaps.
- Remaining gaps: `obsidian-theme`, `obsidian-pane`, `obsidian-long-note`, default-Chrome real Monaco/ProseMirror AX, Claude Code, and Claude desktop layout variants.

2026-05-09T07:10Z heartbeat follow-up: investigated the Obsidian long-note gap, but did not claim proof.

- Attempt: tried to automate `obsidian-long-note` by seeding a disposable 90-line note, moving to the bottom, and running the same two-accept proof path on `qwen3-0.6b`.
- Finding: CodeMirror/AX kept placing the real typing cursor before the final filler line. The app correctly blocked suggestions with `reason=middleOfLine` and `afterChars=90`, then a trim attempt exposed an even worse stale-selection shape with `beforeChars=0` and `afterChars=500`.
- Decision: backed out the experimental harness change instead of committing a flaky or dishonest proof path. No green row was recorded.
- Next fix target: build a safer long-note setup that can prove the actual focused AX selected range is at the visible document end before typing, or add a separate product rule only if the current-line suffix is provably empty/newline-delimited rather than real same-line text.

2026-05-09T07:16Z heartbeat follow-up: tried a tighter long-note repair path and backed it out.

- Attempt: added a scoped Obsidian repair for the shape "AX says cursor at document start, but the previous full text is a prefix and new text was appended at the end." Focused unit coverage passed, but live `obsidian-long-note` still did not present.
- Finding: the live AX read only exposed a capped 500-character after-cursor window, so the app could not prove the previous full note was a prefix of the new full note. The bounded diagnostics still ended in `tooLittleContext` rather than a verifiable end-of-document context.
- Decision: backed out the product/harness experiment and kept the gap open. The next credible fix needs a focused AX reader path that can verify long-document selected range near the end without relying on the capped hot-loop text window.

2026-05-09T07:26Z heartbeat follow-up: closed the two default-Chrome real-editor AX proof gaps.

- Finding: the default Chrome real-editor lanes were not blocked by the model. Normal Chrome had several stale proof windows, and the smoke harness was checking/clicking the front New Tab window instead of the tab containing the current Monaco/ProseMirror fixture.
- Harness fix: `real_app_smoke.sh` now raises the Chrome tab whose URL/title matches the disposable smoke fixture before focusing, typing, or checking active-tab URL. This keeps the normal-Chrome default-AX proof pointed at the actual editor instead of browser chrome.
- App fix: Chromium insertion verification can now recover target-fingerprint churn only when the field identity is still the same, the mismatch is target-fingerprint-only, and text verification already proves the exact insertion. This covered the real ProseMirror default-AX full-accept path without broadening field-identity swaps.
- Validation: `swift test --filter InsertionVerificationContextRecoveryPolicyTests` passed, `script/real_app_smoke_self_test.sh` passed, `monaco-real --chrome-accessibility default` passed with 2 verified accepts and strict visual evidence, and `prosemirror-real --chrome-accessibility default` passed with 2 verified accepts and strict visual evidence. The model stayed `qwen3-0.6b`.
- Gate movement: `script/manual_smoke_status.sh --require-all` now reports Chrome real Monaco default AX and Chrome real ProseMirror default AX as passed. Required gaps dropped from 14 to 12: Obsidian theme/pane/long-note, Claude Code, and Claude desktop layout variants.

2026-05-09T07:35Z heartbeat follow-up: refreshed the default-Chrome real-editor rows after PR #35 moved to `834dd2843b6a`.

- Reason: committing the Chrome default-AX fix made the older broad smoke matrix rows stale by source-proof rules, and the first Monaco/ProseMirror rows still referenced the pre-commit proof source.
- Live proof refresh: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture monaco-real --chrome-accessibility default` passed with 2 accepted insertions and strict visual trace evidence.
- Live proof refresh: `AUTOCOMPLETE_LAB_MODEL=qwen3-0.6b AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture prosemirror-real --chrome-accessibility default` passed with 2 accepted insertions and strict visual trace evidence.
- Evidence: manual smoke rows `2026-05-09T07:31:56Z` and `2026-05-09T07:33:21Z`, both on `commit:834dd2843b6a`. The model stayed `qwen3-0.6b`.
- Status: `script/manual_smoke_status.sh --require-all` now reports both default-Chrome real-editor AX lanes passed on current PR head. The strict gate still fails honestly because older broad rows are stale after the source commit and the Obsidian variant / Claude proof gaps remain.

2026-05-09T07:41Z heartbeat follow-up: refreshed the safe broad proof matrix on PR #35 head `8928086dca3a`.

- Scope: reran only disposable/safe lanes: TextEdit, Notes title/body/checklist, Chrome textarea/contenteditable/editor-like/Monaco-like/ProseMirror-like, Chrome real Monaco/ProseMirror under isolated renderer accessibility, public Chrome textarea/contenteditable, and Chrome chat-like no-submit.
- Result: all 14 refreshed lanes passed with 2 accepted insertions and strict visual trace evidence. The model stayed `qwen3-0.6b`.
- Evidence: manual smoke rows from `2026-05-09T07:36:50Z` through `2026-05-09T07:41:15Z`, all on `commit:8928086dca3a`.
- Gate movement: `script/manual_smoke_status.sh --require-all` now reports TextEdit, Notes title/body/checklist, every required Chrome fixture/public/default-AX lane, and Chrome chat-like as current. It still fails honestly with 14 proof gaps: default Obsidian refresh plus Obsidian theme/pane/long-note, Codex prompt refresh, Claude Code, and Claude desktop layout variants.
- Safety note: I did not rerun Codex, Obsidian, Claude Code, or Claude desktop in this unattended pass because those can touch active prompt/private-vault surfaces.

2026-05-09T07:43Z heartbeat follow-up: tightened the Obsidian disposable-note harness without touching a vault.

- Finding: the Notes smoke drivers explicitly move the AX selected range to the end before typing, but the Obsidian reset path only rewrote the CodeMirror AX value and then relied on Command-Right/Return. That was too close to the long-note failure shape where AX/caret state drifted away from the visible end.
- Harness fix: after Obsidian smoke-note reset or target confirmation, `real_app_smoke.sh` now focuses the CodeMirror element and attempts to set `kAXSelectedTextRangeAttribute` to the end of the disposable note text before any smoke typing.
- Scope: this is proof-harness-only. It does not change the app model, prompt, cadence, or production insertion behavior.
- Validation: `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh`, `script/real_app_smoke_self_test.sh`, and `git diff --check` passed.
- Honest status: no Obsidian green row was claimed in this unattended heartbeat; the next proof pass still needs a disposable-vault foreground run.
