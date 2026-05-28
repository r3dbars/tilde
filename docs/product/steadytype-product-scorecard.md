# SteadyType Product Scorecard

Updated: 2026-05-28 America/Chicago.
Base app/source evidence checked through the current score-loop commits.
Latest beta gate evidence checked with `./script/beta_readiness.sh --check-only`, `./script/manual_smoke_status.sh --strict`, `./script/check_runtime_network_egress.py --validate-proof`, `./script/select_latency_window.py`, `./script/private_beta_packet.sh --check`, `./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/package_release.sh --check --require-developer-id --require-notary-profile`, `./script/check_prompt_app_manifest_proof.sh`, the guided TextEdit walkthrough proof gate self-test, fresh beta-safe app proof, current TextEdit model-latency proof, retired Claude desktop model-latency proof lane, packaged TextEdit model-latency proof wrapper, current runtime no-egress proof, Claude Code terminal-host insertion source proof, detached Ghostty launchd proof failure evidence, detached Ghostty proof runner self-test, focused daily-driver activation/trigger Swift tests, full Swift test, focused model-integrity Swift tests, current Obsidian run-on proof, current Obsidian font-zoom proof, current Obsidian Markdown-list proof, current Obsidian Markdown-bold proof, current Obsidian multiline proof, current Codex one-word no-submit proof, current Chrome textarea/contenteditable split-persistence proof, and current strict manual smoke proof for the 10 beta-safe writing rows.
Overall score: 86/100.

This is the single current product scorecard. Older scorecards are historical
inputs only. Do not raise a score unless the evidence in the row changes.
Stale proof can explain progress, but it cannot make a row green.

Current Ghostty terminal-host evidence is sharper but still red. Local probes
showed Ghostty `input text` can return success without mutating a fresh shell,
while Ghostty `perform action "text:..."` can type into a fresh shell. External
shell-driven System Events can also type into a fresh Ghostty/Claude prompt, but
the app-originated direct and shell-launched System Events rungs still leave the
disposable proof prompt unchanged. The latest pass also proved that explicitly
foregrounding Ghostty through System Events avoids frontmost-script failures but
does not make those keystrokes insert into the Claude prompt. This pass fixed
the next proof blockers:
actively reused prompt-row anchors now stay fresh, hidden suggestions no longer
satisfy the primary scanner, Claude Code terminal-host proof candidates can
bypass final-result latency suppression without broadening normal app latency
behavior, focused-text polling throttles can preserve a still-valid pending
proof phrase request, and exclusive proof cleanup no longer terminates the
current SteadyType app bundle. The current insertion pass adds two verified
hardware-key sources, direct and shell-launched bulk System Events probes, paced
per-character System Events typing, and a native Ghostty
`paste_from_clipboard` action rung with pasteboard restore and unchanged-prompt
baseline checks before the bundled Unicode helpers. `20260527T203149Z-ghostty`
found prompt-row suggestions at diagnostics lines `752131` and `752812`, then
captured Tab on the fresh second context and ran the foregrounded insertion
ladder. Direct bulk System Events, shell-launched bulk System Events, and
per-character System Events all exited `0` and posted, but each verified
`false`; the bundled helper then reported frontmost PID mismatch, and the ladder
failed closed with `ghosttyFastFailClosed` and `keyboard-action handled=false
reason=insert-failed`. The exact-PID follow-up kept the target process honest
without turning Ghostty green. `20260527T204323Z-ghostty` again found a
prompt-row suggestion at diagnostics line `756273`, captured Tab, and ran the
native Ghostty/System Events insertion ladder with the proof Ghostty process
targeted by Unix pid. Native action text, native input text, native paste,
send-key, foregrounded System Events, hardware, Unicode, and pasteboard rungs
still left the disposable prompt unchanged. The bundled helper still reported
frontmost pid mismatch after later global key-event rungs, and the ladder failed
closed with `ghosttyFastFailClosed` and `keyboard-action handled=false
reason=insert-failed`. Ghostty remains unsupported until the detached proof
exits `0` with verified one-word no-submit insertion.
The next PID-reassertion slice narrowed the helper failure without making the
host green. `20260527T210539Z-ghostty` found a prompt-row suggestion at
diagnostics line `763147`, lost the first accept attempt after Tab delivery
produced no key diagnostic, relaunched a fresh disposable context, then found a
second prompt-row suggestion at line `764044` and ran the insertion ladder.
Exact-PID frontmost reassertion returned `verified=true` before hardware,
bundled-helper, and pasteboard rungs. Hardware, native Ghostty, System Events,
Unicode, and pasteboard rungs still left the disposable prompt unchanged. The
bundled helper still refused to post, but the error is now sharper:
`frontmost pid mismatch actual=39183 expected=82940`, which shows NSWorkspace
can report Ghostty's root app pid while the proof target is the exact
title-marked Ghostty process. The helper now has a System Events exact-PID
frontmost check for that Ghostty root-pid split, but the follow-up detached runs
`20260527T211020Z-ghostty` and `20260527T211114Z-ghostty` did not reach
insertion because focus moved away before accept / the proof process did not
become frontmost. Ghostty is still unsupported until a detached proof exits `0`
with verified one-word no-submit insertion.
The next live proof slices made the red sharper instead of broadening support.
`20260527T212018Z-ghostty` found a prompt-row suggestion at diagnostics line
`765974`, captured Tab, and reached the insertion ladder, but stopped after the
native input-text baseline exposed unsafe pasteboard item cloning in the app
restore path. `20260527T212628Z-ghostty` found a prompt-row suggestion at
diagnostics line `767231`, captured Tab, and ran the full native Ghostty,
System Events, hardware, bundled-helper, Unicode, and pasteboard ladder, but
stopped after global `pasteboardCommandV verified=false` before recording the
unchanged-prompt baseline. The current follow-up fixes that diagnostic trap:
`20260527T213259Z-ghostty` found prompt-row suggestions at diagnostics lines
`768445` and `769511`, captured Tab on the second disposable context, verified
the exact Ghostty PID before fragile rungs, recorded unchanged-prompt baselines
through targeted and global pasteboard attempts, queued pasteboard restore with
`pasteboardCommandVRestoreScheduled`, and failed closed with
`ghosttyFastFailClosed` plus `keyboard-action handled=false
reason=insert-failed`. Ghostty is still unsupported because every insertion
transport left the disposable Claude prompt unchanged.
The latest direct `claude-code-ghostty` pass sharpened placement before the
same insertion failure. The terminal-screen anchor now keeps Ghostty's visible
prompt marker in `promptLineInputText`, moving the proof click from the bad
middle-row sample at `x=747` to the end-of-input neighborhood at `x=989`. The
app then stops the event tap, click-focuses the proven caret, and tries a
front-window native Ghostty `input text` rung that mirrors the smoke harness.
Diagnostics line `797843` recorded
`source=ghosttyFrontWindowInputText verified=false`, the unchanged-prompt
baseline stayed true, and line `797884`
failed closed with `ghosttyFastFailClosed`. Ghostty remains unsupported until
app-owned insertion mutates the disposable prompt and verifies one-word
no-submit acceptance.
The newest insertion pass tested the closest shell-shaped native variants
without turning Ghostty green. SteadyType now launches Ghostty `input text`
through both direct `osascript` and `/bin/zsh -lc exec /usr/bin/osascript`,
covering the smoke-equivalent front-window path and the safer marker-scanned
proof-window path. The direct `claude-code-ghostty` run found the prompt-row
suggestion at diagnostics line `799244`; `ghosttyLoginShellFrontWindowInputText`
posted at line `799787`, `ghosttyAppleScriptLoginShellInputText` posted at line
`799795`, both verified `false`, both unchanged-prompt baselines verified
`true`, and line `799831` failed closed with `ghosttyFastFailClosed`.
Ghostty remains unsupported until a different app-owned transport actually
mutates and verifies the disposable Claude prompt.
The latest direct pass tested that next app-owned transport without turning
Ghostty green. SteadyType now tries Ghostty's native `input text` through an
in-process AppleScript rung before the subprocess front-window and
marker-scanned variants. The direct `claude-code-ghostty` run found the
prompt-row suggestion at diagnostics line `800174`; `ghosttyInProcessInputText`
posted at line `800768`, verified `false`, the unchanged-prompt baseline
verified `true` at line `800769`, and the ladder still failed closed at line
`800816` with `ghosttyFastFailClosed`. Ghostty remains unsupported until an
app-owned transport mutates and verifies the disposable Claude prompt.
The detached Ghostty follow-up now makes stale proof windows less likely to
produce false evidence: insertion verification prefers the current
terminal-screen prompt over stale focused text, the detached launcher assigns a
unique proof title before running `claude`, the frontmost wait actively refocuses
the exact title-marked Ghostty window, and the AX prompt helper can inspect the
focused window/app tree. The live detached proof still failed honestly:
`20260528T012221Z-ghostty` reached the exact frontmost Ghostty PID but the AX
prompt-readiness snapshot only matched part of the typed proof text before the
retry path, and `20260528T012819Z-ghostty` failed exact frontmost reactivation
after title-PID resolution. Ghostty remains unsupported until the detached proof
exits `0` with verified one-word no-submit insertion.
The newest detached pass moved the failure back to the real insertion problem
instead of stale host state. `20260528T021253Z-ghostty` exercised retryable
prompt/process discovery but showed a poisoned zero-window Ghostty process could
block fresh contexts. The harness now uses Ghostty-native stale cleanup, resets
only a Ghostty host whose own API reports exactly zero windows, retries fresh
contexts, records proof-process exit diagnostics, and tries Command-V pasteboard
insertion before slower native/key-event Ghostty rungs. `20260528T023640Z-ghostty`
reset stale pid `32024` and reached prompt-row Tab insertion; `20260528T024044Z-ghostty`
waited through the full ladder. Both failed closed with `keyboard-action
handled=false` after unchanged-prompt baselines. Ghostty remains unsupported, but
the next red bar is now cleanly a verified app-owned insertion transport or an
async post-Tab verification path.
The newest proof pass rules out one more transport-shape hunch without widening
support. SteadyType now paces app-owned Command-V, hardware, and Unicode-to-pid
key events. A session-tap pasteboard Command-V probe is still available for
isolated repros, but it is opt-in through
`AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE` after timeout-shaped evidence
showed it should not run in the default ladder. `20260528T025919Z-ghostty` found
a prompt-row suggestion at diagnostics line `818560`, posted
`pasteboardCommandVSession` at line `819222`, continued through the full
insertion ladder, and failed closed at `819271` / `819273`. The default follow-up
`20260528T030442Z-ghostty` found the prompt-row suggestion at diagnostics line
`821100`, consumed Tab at `821919`, skipped the session probe at `821948`,
recorded the unchanged global paste baseline at `821951`, and failed closed at
`821995` / `821997` with `keyboard-action handled=false reason=insert-failed`.
The bounded follow-up `20260528T031735Z-ghostty` kept the same prompt-row Tab
path, accepted the next-word proof at diagnostics line `823023`, ran targeted
and global pasteboard, in-process native input, direct front-window input, and
shell-launched front-window input, then stopped at the explicit default budget:
line `823052` recorded `ghosttyFastInsertionBudget` with
`elapsedMilliseconds=9886` / `budgetMilliseconds=8000` before
`ghosttyPerformActionText`, and lines `823053` / `823055` failed closed with
`keyboard-action handled=false reason=insert-failed`. The longer exploratory
Ghostty insertion ladder is now opt-in through
`AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES`; Ghostty remains
unsupported until a transport actually mutates and verifies the disposable
Claude prompt.
The next transport hypothesis is now available as an opt-in probe rather than a
support claim: `AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE=1` tries
the same shape the harness uses for setup typing, native Ghostty `input text`
for the accepted prefix plus a real final key event. The detached runner now
forwards that opt-in env into both the worker and relaunched SteadyType app.
`20260528T033921Z-ghostty` reached the probe: diagnostics line `825139`
recorded `ghosttyNativePrefixFinalKeyText stage=start`, line `825141` reported
`verified=false`, line `825142` proved the prompt stayed unchanged, and the run
still failed closed at `825160` / `825163` before the slower `ghosttySendKey`
rung. The app now separately verifies the native prefix before sending the final
key so an insertion-reaching run can distinguish a prefix no-op from a final-key
miss. A follow-up detached run, `20260528T034406Z-ghostty`, failed earlier with
no visible suggestion after one disposable context. `20260528T040957Z-ghostty`
and `20260528T041228Z-ghostty` both reached prompt-row suggestions; the latest
run found the prompt-row suggestion at diagnostics line `832819`, reasserted and
activated Ghostty before posting input at lines `832453` / `832454`, then proved
`ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key,
in-process native text, front-window input text, and action-text still left the
prompt unchanged before the budget fail-closed at lines `832488` / `832489` and
the handled-false Tab result at line `832491`. Treat the probe as unproven until
a detached run reaches `ghosttyNativePrefixFinalKeyText` and verifies one-word
no-submit insertion.
The latest detached follow-up, `20260528T043409Z-ghostty`, stalled before prompt
suggestions while warming the CGEvent Tab helper and was stopped with exit
status `143`; that is harness failure evidence, not insertion evidence. The
harness now builds both CGEvent keypress and text helpers behind
timeout-bounded `swiftc` waits so the next detached proof fails fast instead of
silently hanging before the real Ghostty insertion red bar.
The follow-up after that hardening moved past helper warmup:
`20260528T043930Z-ghostty` found a prompt-row suggestion at diagnostics line
`839022`, but the detached worker exited before writing a final status and left
`state=running`; `./script/claude_code_ghostty_detached_proof.sh status --run-dir
dist/claude-code-ghostty-detached-proof/20260528T043930Z-ghostty` now repairs
that stale status to failed with `exit_status=1`. A later run,
`20260528T044123Z-ghostty`, hung after helper warmup and was stopped with exit
status `143`; the harness now logs explicit warmed, stale-cleanup, and fresh
context phases so the next detached proof points at the exact shell step rather
than another silent pre-insertion stall.
The next bounded run, `20260528T044446Z-ghostty`, confirmed those breadcrumbs
and reached the insertion red bar: prompt-row suggestion at diagnostics line
`841085`, deferred Tab accept at lines `842182`-`842184`, unchanged prompt
mismatches through send-key, System Events, pasteboard, in-process native input,
direct front-window input, and shell front-window input, then
`ghosttyPerformActionText` failed verification at line `842224`. Its unchanged
baseline failed at line `842225`, and the app failed closed with
`ghostty-action-unverified-mutated-input`, `insert ... success=false`, and
deferred `stage=insert-failed` at lines `842226`-`842228`. The smoke harness now
waits for either success or explicit fail-closed insertion diagnostics, so this
class of Ghostty proof should report the real insertion red bar instead of
timing out while the app is still verifying. Typed prompt readiness now requires
exact prompt text after marker stripping, and zero-window Ghostty reset is
opt-in only, so stale or poisoned contexts cannot silently satisfy or terminate
normal proof runs.
The live follow-up `20260528T045213Z-ghostty` proved the new fail-closed wait
path: it printed the warmed, stale-cleanup, and fresh-context breadcrumbs, found
a prompt-row suggestion at diagnostics line `844141`, scheduled deferred Tab
accept at lines `845236`-`845238`, and exited quickly when the app logged
`insert ... success=false` at line `845306` plus deferred
`stage=insert-failed` at line `845307` instead of timing out. That run also
exposed the remaining ladder-ordering bug:
native action text was still running before the safer front-window input rungs.
The app ladder now runs action text after in-process, direct front-window, and
shell-launched front-window native input, while keeping it before the slower
marker-scanned native input and paste-action rungs.
The next current-head run, `20260528T045645Z-ghostty`, found a prompt-row
suggestion at diagnostics line `846384` and proved the action-word safety gate
was the next blocker: deferred Tab accept reached `stage=insert-start`, then
line `847494` blocked with `reason=accepted-text-prompt-action-word`. That is
too broad for the explicit one-word no-submit proof lane, so accepted text
safety now allows prompt action words only when
`shouldUseClaudeCodeTerminalHostProofDirectInsertion` is true; command prefixes,
shell metacharacters, hidden controls, multiword unsafe text, and normal prompt
surfaces remain blocked.
After that patch, bare detached proof defaults also changed to the intended
deferred Ghostty lane with a proof-only 45s insertion budget. `20260528T050302Z-ghostty`
showed the normal detached command now passes the action-word gate and reaches
the reordered ladder, but the 28s prior default still stopped before the session
helper at diagnostics line `851094`. The longer exploratory run,
`20260528T050557Z-ghostty`, found a prompt-row suggestion at line `851655`,
scheduled deferred Tab accept at lines `852671`-`852673`, then proved every
current app-owned transport still left the disposable prompt unchanged:
send-key, direct and shell-launched System Events, targeted and global
pasteboard, in-process native input, front-window native input, action text,
marker-scanned native input, paste action, HID and session CGEvent helpers,
shell-launched bulk System Events, and global Unicode key events. It failed
closed with `ghostty-fast-verified-insertion-failed`, `insert ... success=false`,
and deferred `stage=insert-failed` at lines `852754`-`852756`. Ghostty remains
unsupported; the next real fix needs a new transport or permission shape, not
another no-op rung.
The app bundle, release packaging, and dependency inventory now sign and verify
both `NSAppleEventsUsageDescription` and the
`com.apple.security.automation.apple-events` entitlement for opted-in terminal
host Automation. This is permission hygiene for the next Ghostty transport
attempt, not green support: `AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=5
./script/build_and_run.sh --verify`, `./script/check_app_bundle.sh`, and
`./script/check_dependency_inventory.sh` passed after the change. The current
detached entitled-app proof `20260528T051532Z-ghostty` still failed closed after
finding a prompt-row suggestion at proof-log line `855905`, scheduling deferred
Tab insertion at diagnostics lines `857001` and `857003`, and stopping on
`ghostty-fast-insertion-budget-exceeded` plus `insert ... success=false` at
diagnostics lines `857069` and `857071` before deferred `stage=insert-failed`
at line `857072`.
The follow-up current-head 45s detached attempt `20260528T052125Z-ghostty`
exposed a harness-only failure: Terminal did not start the worker, so the run
stayed `state=starting` with no `pid`. The detached proof wrapper now repairs
stale no-pid `starting` runs after the startup grace window; `status` marks that
run failed with a clear startup-grace-expired note, and `wait` returns instead
of hanging.
The next `nohup` detached run, `20260528T052542Z-ghostty`, proved the worker can
start without Terminal but failed before insertion because the disposable
Ghostty shell did not execute the proof command. The launch harness now logs a
redacted Ghostty launch-state snapshot when that happens. The focused one-attempt
verification run `20260528T053230Z-ghostty` failed cleanly with the pidfile
missing and launch state `windows=3 proofTitleWindows=1
frontWindowHasProofTitle=true focusedTerminalWorkingDirectoryPresent=false`,
which proves the title-marked window existed but no ready terminal working
directory / proof command execution was visible. Ghostty remains unsupported.
The current readiness-check follow-up makes that launch failure fail earlier
instead of typing into an unready Ghostty surface. `20260528T054054Z-ghostty`
timed out waiting for launch retry, did not write the proof pidfile, and logged
launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false
focusedTerminalWorkingDirectoryPresent=false`. This proves the harness now
requires a visible title-marked Ghostty proof window with a real terminal
working directory before it can count a disposable proof command as launched.
The current harness-hardening pass widened the proof-only Ghostty launch waits,
made the detached wrapper default to the `nohup` runner instead of the flaky
Terminal launcher, invokes generated runners through `/bin/bash`, added an EXIT
status trap, stops orphaned `real_app_smoke` children after dead-runner repair,
and guarded the Ghostty host bundle-id helper against broken-pipe termination.
`bash -n script/real_app_smoke.sh
script/real_app_smoke_self_test.sh script/claude_code_ghostty_detached_proof.sh
script/claude_code_ghostty_detached_proof_self_test.sh`,
`./script/real_app_smoke_self_test.sh`,
`./script/claude_code_ghostty_detached_proof_self_test.sh`, and `git diff
--check` passed after the hardening. The live follow-up
`20260528T063520Z-ghostty` still failed red before insertion: the `nohup` runner
started, wrote the proof header, then exited before explicit final status, so
the next blocker is the wrapper/smoke handoff rather than a green Ghostty
insertion claim.
Ghostty remains unsupported until a detached run reaches verified one-word
no-submit insertion and exits `0`.

## Scores

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Suggestion quality | 94/100 | `./script/check_quality_eval.sh`: completion quality, word-completion quality, offline-model quality, and the deterministic 500-case completion-prediction suite all passed on 2026-05-28 after the generic-filler suppression, concrete suffix examples, 8-word default phrase posture, first-pass 3-8 word prompt label, and instant short-reply / thinking-flow predictors in `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`, `Sources/AutocompleteLabCore/Engine/CommonPhraseContinuationPredictor.swift`, `Sources/AutocompleteLabCore/Session/AutocompleteBehaviorProfile.swift`, `Sources/AutocompleteLabCore/Session/SuggestionAggressiveness.swift`, and `script/local_completion_runtime.py`. `./script/check_daily_driver_local_quality_audit_report.sh`: passed for `docs/evals/daily-driver-local-quality-audit-2026-05-25.md` with 45 disposable rows, 36 display-eligible rows, 9 expected suppression rows, 100/100 overall, 100/100 relevance, and no raw output persisted. `swift test --jobs 1 --filter SuggestionOrchestratorTests`: 36 tests passed after a shown 0ms phrase fallback stopped ending the request early; it now queues the model for refinement, stays visible during fast typing instead of being hidden by the model typing-burst gate, and remains visible if the follow-up model continuation fails for the same live request. `swift test --jobs 1 --filter CompletionPromptBuilderTests`: 33 tests passed after the primary default 8-word prompt started asking for `Next 3-8 words, or <NO_SUGGESTION>:` before retry instead of waiting for the short-candidate repair path. `swift test --jobs 1 --filter CommonPhraseContinuationPredictorTests`: 20 tests passed after the instant predictor added Obsidian/writing-flow continuations such as "One thing I noticed is" -> "that the flow breaks there", "What I know so far is" -> "the next step is clear", "The next pass should" -> "make the point clearer", daily-driver reach-test continuations such as "The difference is" -> "whether it feels magical", "This breaks trust when" -> "it appears in the wrong field", and "The reach test is" -> "whether i keep using it", and guarded next-sentence boundary continuations such as "Suggestions feel too timid." -> "It should predict the next phrase", "Placement keeps showing in the wrong field." -> "That has to fail closed", and "Typing feels slow when suggestions lag." -> "Speed has to feel invisible" while keeping trailing-whitespace, email, prompt, search, and code contexts off for that path. `swift test --jobs 1 --filter 'AutocompleteBehaviorProfileTests|CommonPhraseContinuationPredictorTests'`: 31 tests passed after the instant predictor added short messaging/email reply continuations such as "Sounds good" -> "to me", "Let me" -> "take a look", "Thanks for" -> "sending this over", while Messages and Telegram resolve to the casual-chat profile and prompt/search/form/code profiles remain off for that fallback path. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SuggestionTriggerPolicyTests|CompletionActivationPolicyTests'`: 61 tests passed after very-proactive writing surfaces started preferring phrase continuation for word fragments with enough context, requesting next-sentence phrase continuations at sentence boundaries, and allowing an Obsidian-only daily-driver line-start phrase path after one word while prompt surfaces keep the old quiet gate. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SettingsWindowControllerStateTests|SuggestionOrchestratorTests|ModelPolicyTests|CommonPhraseContinuationPredictorTests'`: 95 tests passed after the default visible phrase cap moved to 8 words, old 3-word and 5-word defaults gained a version 6 migration, and the default cap now asks for 3-8 word phrase guidance. `./script/daily_driver_dogfood_session_self_test.sh`: passed after the redacted dogfood gate started reporting instant draft model follow-up results, model replacements shown, visible preservation after empty model results, and per-outcome instant phrase counts. | Deterministic and disposable local-model quality proof is green, and the default tuning is less timid at sentence boundaries, partial-word phrase starts, first-pass 3-8 word requests, guarded instant next-sentence phrases, common reply phrasing, common notes/Obsidian thinking-flow starts, reach-test complaint language, and instant-then-model phrase refinement, but this is still not broad live writing volume with real accepted-kept, typed-over, annoyance, and reach-for-it signals. | Run a real writing dogfood session, fill the Manual Trust Row, then gate it with `./script/daily_driver_dogfood_session.sh review --report <report>`. |
| Placement | 89/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-26 at commit `01d9d427a2b5` for TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. The refreshed rows include strict visual trace evidence and 2 accepted insertions each, including Obsidian long-note diagnostics lines 412384-412504 / traces lines 27824-27834, Chrome textarea diagnostics lines 413133-413420 / traces lines 27932-27989, and Chrome contenteditable diagnostics lines 413430-413717 / traces lines 27992-28051. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c` with 2 accepted insertions after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-font-zoom --manual-gate`: passed on 2026-05-26T00:21:08Z at commit `73c85c56109b` with diagnostics lines 409510-409632 / traces lines 27370-27381, 2 accepted insertions, strict visual trace evidence, and restored Obsidian zoom. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z at commit `70cc9b29b59c` with diagnostics lines 410919-411071 / traces lines 27597-27618, 2 accepted insertions, strict visual trace evidence, and the suggestion staying on the dash-list row. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z at commit `1953b49a6e21` with diagnostics lines 413977-414128 / traces lines 28065-28085, 2 accepted insertions, strict visual evidence, and the caret repaired back to the bold line before the second suggestion. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-multiline --manual-gate`: passed on 2026-05-26T02:23:05Z at commit `db5bc6ffcd72` with diagnostics lines 414135-414268 / traces lines 28086-28099, 2 accepted insertions, and strict visual evidence on the lower multiline caret. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with diagnostics lines 574487-574600 / traces lines 28182-28188, 1 accepted insertion, strict visual trace evidence, and prompt no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed for the same Codex bounded prompt slice. | The 10 beta-safe writing lanes plus Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline variants and Codex one-word no-submit proof are current, but the claim is still intentionally narrow. Prompt apps remain proof-only, terminal hosts need current insertion-source proof, and production browser apps, hosted docs, and chat surfaces remain unclaimed. The Markdown-list full-accept pass uses the disposable proof-vault direct-value gate after a verified unchanged retry, so it does not broaden production Obsidian insertion claims by itself. | Keep `./script/check_prompt_app_manifest_proof.sh` green after each app/source change, then record a live prompt full-accept no-submit row before broadening prompt/chat claims. |
| Tab safety | 86/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-26 at commit `01d9d427a2b5`, with Tab/full-accept insertion proof across TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c`; Tab accepted the next word and Option+Tab accepted the remaining visible phrase after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z with Tab accepting `instant` inside a dash-list row instead of turning into indentation, then full accept verifying through the proof-vault retry path. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z with Tab and full accept staying in the bold Markdown line. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with one-word Tab accept, strict visual evidence, and no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed with prompt safety counters at 0. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after adding explicit full-accept no-submit proof mode with required manifest, smoke-row, accepted-event, and verified-insertion evidence. | Prompt/chat apps are not normal beta writing surfaces. Codex one-word no-submit is current, but full accept stays off for prompt apps until exact full-accept no-submit proof exists, production browser apps stay unclaimed, and Markdown-list/full accept variants are still proof-vault lanes rather than broad Obsidian production guarantees. | Run `./script/check_prompt_app_manifest_proof.sh` after the next app/source change, then record a live separate full-accept no-submit proof before enabling full accept in any prompt/chat surface. |
| Latency | 80/100 | `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-model-latency`: passed on 2026-05-28 with 5 model-backed visible samples, first-visible `avg=253ms p95=258ms`, first-token `avg=228ms p95=233ms`, total generation `avg=252ms p95=293ms`, event-tap overhead `avg=40us p99=89us`, AX read summaries `p99Max=25ms max=25ms`, and zero late shown suggestions, event-tap failures, AX slow markers, or AX skips. executable-sha256=`bbf596398145cbf1b1ca4c639fedaa56f9cbc8a731ca2d447bc66bb7eae29e4d`; TextEdit strict selector `./script/select_latency_window.py`: selected diagnosticsLine=833735, traceStartLine=30421, firstVisibleSamples=5, modelSamples=5, fastWordVisibleSamples=0. `swift test --jobs 1 --filter TypingBurstPolicyTests`: 5 tests passed after the default fast-typing detector started catching roughly 70 wpm typing with 6 inserted characters inside 1.1 seconds while leaving word completion eligible. The Claude desktop latency lane is retired for now because its current task UI is not a safe prompt proof surface; the helper now refuses task/start buttons and only uses a safe chat composer. `./script/packaged_latency_proof_self_test.sh`: passed after the packaged proof wrapper default moved to the beta-safe TextEdit latency lane while keeping Claude as an explicit target. | Current dev-smoke latency is fast and model-backed in a beta-safe writing app, but the release-packaged app cannot collect current latency samples until Accessibility is granted for `bar.r3d.steadytype` after notarized install. | Grant Accessibility to the notarized `dist/SteadyType.app`, then rerun `./script/packaged_latency_proof.sh textedit-model-latency` and `./script/select_latency_window.py`. |
| Privacy | 95/100 | `./script/beta_readiness.sh --check-only`: runtime no-egress proof, redacted report export, current build privacy export proof, issue template, clipboard fallback disabled, prompt app proof gate, and prompt/chat safety counters all passed after the release-signed proof refresh. `python3 ./script/check_runtime_network_egress.py --pid 25216 --phase autocomplete --duration 12 --interval 1 --activity-note "current release-signed packaged runtime after package_release archive" --proof-out docs/product/runtime-network-egress-latest.md --json-out docs/product/runtime-network-egress-latest.json`: passed on 2026-05-28T05:48:01Z with 13 samples, 0 non-loopback remote endpoints, and wrote redacted packaged-runtime proof to `docs/product/runtime-network-egress-latest.md` and `docs/product/runtime-network-egress-latest.json` for executable SHA-256 `b6a899a2949d5eebcbd13a4a37015508c038dbe95ba132e6b9564f6cae4006b6`. `python3 ./script/check_runtime_network_egress.py --validate-proof docs/product/runtime-network-egress-latest.json --diagnostics-log "$HOME/Library/Logs/SteadyType/diagnostics.log" --require-newer-than-latest-launch --max-proof-age-seconds 86400 --min-samples 10 --app-binary dist/SteadyType.app/Contents/MacOS/SteadyType`: passed. `./script/check_sensitive_field_proof_self_test.sh`: passed after the gate expanded required suppressed categories and required browser-hosted suppression rows for Google Docs, Notion, ChatGPT, Slack, Discord, browser login/payment/password-manager/private-search/address-bar/developer-tool, and unproven browser pages. `swift test --jobs 1 --filter 'SensitiveTextFieldPolicyTests|BrowserHostedSurfacePolicyTests'`: 30 tests passed, including the expanded Chrome/Safari/Brave/Arc/Firefox/Chromium browser-hosted fail-closed policy. | Privacy proof is current, but the beta privacy claim still depends on the human onboarding walkthrough and the packaged-app Accessibility recovery proof. | Rerun `./script/beta_readiness.sh --check-only` after onboarding proof and packaged-app Accessibility proof are complete. |
| App coverage | 81/100 | `./script/check_proof_manifest.sh --require-all`: passed with 7 complete surfaces, 20 profile coverage rows, 20 host policy rows, 12 graduation decision rows, and 24 verified trace slices. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-26 at commit `01d9d427a2b5` for the 10 beta-safe writing rows. Current app proof also includes Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline, Codex one-word no-submit, Chrome textarea/contenteditable split persistence, and Claude Code terminal-host Terminal/iTerm2 one-word no-submit rows. The Ghostty branch now has prompt-row recovery, terminal prompt-row caret estimation, visible prompt-marker modeling, proof-only caret focus click, bounded diagnostics scanning, fresh-process detached proof retries, exact-process focus reassertion, title-scoped fallback focus, terminal-ready launch gating, timeout-bounded native Ghostty action/input/paste attempts, app-owned in-process native input, direct and shell-launched front-window native input, direct and shell-launched marker-scanned native input, terminal-scoped send-key/System Events paths, foregrounded direct and shell-launched bulk System Events probes, targeted and global hardware-key attempts, bundled/in-process Unicode helpers, pasteboard fallbacks, paced synthetic key events, an opt-in session-tap pasteboard probe, opt-in native-prefix/final-key probe env forwarding, separate prefix verification, and fail-closed gating before generic insertion. `20260527T203149Z-ghostty` found prompt-row suggestions, captured Tab on the fresh second context, tried foregrounded direct bulk System Events, shell-launched bulk System Events, per-character System Events, native Ghostty actions, terminal-scoped send key, hardware-key sources, bundled Unicode helpers, direct Unicode events, and pasteboard insertion, then failed closed because every app-owned insertion transport left the disposable prompt unchanged. `20260527T213259Z-ghostty` again reached hot Tab accept on a fresh prompt-row suggestion, ran the full ladder, proved targeted/global pasteboard misses left the prompt unchanged, queued clipboard restore, and failed closed instead of hanging after global paste. `20260528T025919Z-ghostty` reached prompt-row Tab accept, proved the opt-in session-tap paste miss at diagnostics lines `819221`-`819224`, continued through the full ladder, and still failed closed at `819271` / `819273`. `20260528T030442Z-ghostty` then proved the default ladder skips the session probe, keeps unchanged-prompt baselines, and still fails closed at `821995` / `821997`. `20260528T031735Z-ghostty` accepted the next-word proof at diagnostics line `823023`, tried pasteboard plus native input families, and stopped at diagnostics line `823052` before the slower action-text rung because the default 8s Ghostty insertion budget was exceeded. `20260528T033921Z-ghostty` proved the detached opt-in env reached the app, reached `ghosttyNativePrefixFinalKeyText` at line `825139`, and kept the prompt unchanged at lines `825141` / `825142`; the follow-up `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared in one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at lines `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at lines `832488` / `832489` with handled-false Tab at line `832491`. The latest direct `claude-code-ghostty` pass found the prompt-row suggestion at diagnostics line `800174`, tried the new app-owned in-process native input rung at line `800768`, verified the unchanged baseline at line `800769`, then tried the subprocess front-window/native paths and still failed closed at line `800816`. The latest detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. `./script/real_app_smoke_self_test.sh`: passed after adding source checks for bulk System Events ordering, shell-launched bulk System Events, System Events foregrounding, fail-closed baselines, native paste action ordering, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, prompt focus click, in-process native input, front-window input text ordering, shell-launched marker-scanned native input, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification, paced Command-V checks, nonblocking session miss handoff, and terminal-ready Ghostty launch checks. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner command, status, tail, stop-mode guardrails, and no raw custom proof-text persistence checks. | Coverage is intentionally narrow. Codex now has a current one-word no-submit proof-only lane, but Claude, chat apps, Mail, terminal hosts, public browser pages, and production browser apps stay proof-only or unclaimed unless exact current proof exists. Ghostty can anchor to the prompt row and route Tab into the expanded fail-closed insertion ladder when launch succeeds, but verified one-word Tab insertion is still not proven and the current detached lane is red at launch readiness. Obsidian Markdown-list, Markdown-bold, and multiline are covered only for disposable proof-vault lanes. | Keep the Ghostty prompt-row suggestion accept-ready through Tab, repair or replace the app-owned Ghostty insertion transport, then make `./script/claude_code_ghostty_detached_proof.sh start` and `./script/claude_code_ghostty_detached_proof.sh wait` prove verified one-word no-submit insertion. Only count Ghostty when that detached run exits `0`. |
| Onboarding | 70/100 | Documented manual gate: `docs/product/onboarding-permission-qa-checklist.md`. `./script/onboarding_walkthrough_evidence_helper_self_test.sh`: passed for the new redacted before-delete/after-delete evidence helper. `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready`: failed on the current local logs because no `textedit-practice-started` event exists, even though older TextEdit Tab, Esc, pause, and trace events exist; this proves the helper will not assemble a false walkthrough from scattered old sessions. `./script/check_onboarding_walkthrough_proof_self_test.sh`: passed for the fail-closed guided TextEdit proof validator, and the template now prints the helper commands plus `./script/build_and_run.sh --verify`, diagnostics paths, and trace log paths before recording. `./script/check_onboarding_walkthrough_proof.py`: failed because no completed passing walkthrough proof row exists yet; row 1 is still Pending. `./script/check_onboarding_permission_qa.sh --check`: failed with 48 unchecked items and 3 Pending proof rows after adding the helper step to the checklist. | The first-run path is documented and now has executable pre-delete and post-delete evidence checks for Accessibility, app-owned runtime readiness, TextEdit practice, Tab, Esc, pause, and trace deletion, but the checklist still has no real clean-user tester-walkthrough row. | Record one guided TextEdit practice run in `docs/product/onboarding-permission-qa-checklist.md` using `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready` before Delete Local Logs and `./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready` after deletion, then rerun `./script/check_onboarding_walkthrough_proof.py` and `./script/beta_readiness.sh --check-only`. |
| Controls | 84/100 | `./script/check_controls_diagnostics_readiness.sh`: Settings, Diagnostics, pause scheduling, disabled-app selection, raw-trace expiry, redacted export, privacy export proof, diagnostics log self-test, and local trace deletion all passed. `script/delete_local_traces.sh` now removes `diagnostics.log` too. | Pause/delete/export controls now have better automated parity proof, but the latest score run still does not include a human walkthrough across every visible surface. | Run a documented manual gate that toggles pause, disabled apps, trace delete, and redacted export from Settings, menu bar, and Diagnostics. |
| Diagnostics | 92/100 | `./script/check_controls_diagnostics_readiness.sh`: Diagnostics state tests, RawTraceReportExport tests, diagnostics log self-test, redacted report export, and current-build privacy export proof passed. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-26 at commit `01d9d427a2b5`, so the beta-safe manual proof rows now have current diagnostics and trace slices. `./script/beta_readiness.sh --check-only`: runtime production gate OK and redacted report export OK. | Diagnostics are healthy for local beta work, but onboarding walkthrough and packaged-app Accessibility recovery proof are not complete. | Rerun `./script/check_diagnostics_log.sh`, `./script/check_current_build_privacy_export.sh`, and `./script/manual_smoke_status.sh --strict` after the next app/source change. |
| Model readiness | 94/100 | `./script/check_model_asset.py --quiet`: Qwen3.5 4B MLX verified at revision `32f3e8ecf65426fc3306969496342d504bfa13f3` with `.steadytype-model-integrity.json`. `./script/package_release.sh --check --require-developer-id --require-notary-profile`: Preferred MLX model ready. `./script/check_model_asset_self_test.sh`: passed and proves checksum-skip env no longer bypasses known-good file checks. `./script/download_mlx_model_self_test.sh`: passed and checks immutable revision validation. `swift test --jobs 1 --filter 'AppModelRuntimeFactoryTests|ModelAssetInstallerTests|LocalModelAssetInstallerTests|RuntimePolicyTests'`: 48 tests passed, including immutable 40-character commit revision requirements, absent/tampered integrity receipt rejection, checksum mismatch, duplicate, unsafe path, absent referenced file, extra file, and byte-count mismatch coverage. | The app-owned model path and integrity receipt checks are strong, but beta trust still depends on onboarding and distribution proof. | Keep `./script/check_model_asset.py` green, then rerun `./script/beta_readiness.sh --check-only` after onboarding proof and the primary beta DMG exist. |
| Beta readiness | 80/100 | `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`: created a current Developer ID signed `dist/SteadyType.dmg` and `dist/SteadyType.zip` after the default parallel release build died during compile. `./script/package_release.sh --notarize`: Apple notarization accepted submission `bf39ea78-ed19-4a74-95ba-714ed6c474b6`, stapled the DMG, verified Gatekeeper, and refreshed the secondary ZIP. The current `./script/beta_readiness.sh --check-only` run uses the bounded prompt manifest gate instead of the whole historical trace: model asset, runtime production gate, release-signed runtime no-egress proof, controls/diagnostics, redacted export, issue template validation, clipboard fallback disabled, production mock fallback disabled, prompt app manifest proof, visual placement proof, release package prerequisites, Developer ID DMG/archive signature, notarized install proof, and private beta packet passed. The same run found 4 real blockers: no onboarding walkthrough proof, onboarding permission QA with 48 unchecked items and 3 proof rows waiting for a clean-user run, out-of-date manual app proof for the current commit, and no eligible packaged latency launch until Accessibility is granted for the notarized app. `./script/packaged_latency_proof_self_test.sh`: passed and keeps the TextEdit packaged-latency rerun path one command. | Manual app proof, onboarding proof, and packaged Accessibility latency still need current human runs before testers should get the build. | Refresh strict manual app proof, grant Accessibility to the notarized app for packaged latency, then record onboarding proof / complete the onboarding checklist and rerun `./script/beta_readiness.sh --check-only`. |
| Test/proof coverage | 85/100 | `swift test --jobs 1`: 1508 tests passed after instant fast-phrase-to-model refinement, model-failure visible fallback preservation, and Ghostty insertion diagnostics changes. `swift test --jobs 1 --filter ClaudeCodeTerminalHostProofPolicyTests`: 90 tests passed after the paced Command-V/session-paste proof change. Focused Swift suites for keyboard capture/safety, synthetic caret placement, Chrome same-text split preservation, Codex proof geometry, and Obsidian insertion retry all passed in the current proof set. `./script/real_app_smoke_self_test.sh`: passed after adding bounded log-slice scanning, fast Ghostty focus reassertion, insertion-rung ordering, timeout fail-closed guards, stdin-only helper input, safe apostrophes, unsupported-scalar diagnostics, hardware key-event ordering checks, bulk and paced per-character System Events checks, shell-launched System Events checks, System Events foregrounding checks, native paste-action checks, in-process native input checks, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification checks, paced Command-V checks, nonblocking session miss handoff, and terminal-ready Ghostty launch checks. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner's help, dry-run, status, tail, `nohup` launch path, stop-mode guardrails, and no raw custom proof-text persistence checks. `swift build --product SteadyType`: passed after adding separate native-prefix verification. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-26 at commit `01d9d427a2b5` for all 10 beta-safe writing rows. Direct `AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate`: failed closed after finding a prompt-row suggestion at diagnostics line `800174`, posting the new `ghosttyInProcessInputText` rung at line `800768`, verifying the unchanged baseline at line `800769`, and failing closed at line `800816` with `keyboard-action handled=false reason=insert-failed`. `./script/claude_code_ghostty_detached_proof.sh start` plus `./script/claude_code_ghostty_detached_proof.sh wait`: `20260528T025919Z-ghostty` found a prompt-row suggestion at diagnostics line `818560`, captured Tab, ran targeted paste, opt-in session-tap paste, global paste, native Ghostty, System Events, hardware, bundled-helper, and Unicode rungs, then failed closed with `ghosttyFastFailClosed` plus `keyboard-action handled=false reason=insert-failed` at lines `819271` / `819273`. The default follow-up `20260528T030442Z-ghostty` found the prompt-row suggestion at diagnostics line `821100`, consumed Tab at `821919`, skipped the session probe at `821948`, kept pasteboard baselines unchanged, and failed closed at `821995` / `821997`. The bounded follow-up `20260528T031735Z-ghostty` accepted the next-word proof at line `823023`, logged `ghosttyFastInsertionBudget` at line `823052` with `elapsedMilliseconds=9886` and `budgetMilliseconds=8000`, then failed closed at lines `823053` / `823055` before slower exploratory rungs. `20260528T033921Z-ghostty` proved opt-in env propagation into the detached app and reached `ghosttyNativePrefixFinalKeyText`, but the prompt stayed unchanged at lines `825141` / `825142`; `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared after one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at `832488` / `832489` with handled-false Tab at `832491`. The current detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after the prompt gate gained an explicit full-accept no-submit proof mode while still requiring `prompt no-submit confirmed` for every normal prompt-app proof claim. `./script/check_prompt_app_manifest_proof.sh`: passed for the Codex bounded prompt slice. `./script/beta_readiness_self_test.sh` now proves beta readiness uses that bounded manifest gate instead of scanning old prompt trace history, and the current `./script/beta_readiness.sh --check-only` run shows the prompt app manifest proof gate passing. `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/claude_code_ghostty_detached_proof.sh script/claude_code_ghostty_detached_proof_self_test.sh script/beta_readiness.sh script/beta_readiness_self_test.sh script/check_prompt_app_manifest_proof.sh script/check_prompt_app_proof.sh`, `./script/check_test_coverage_manifest.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/check_steadytype_scorecard.py --live`, `AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=5 ./script/build_and_run.sh --verify`, `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/beta_readiness.sh --check-only`, and `git diff --check`: passed or failed only on the known human proof gates. Earlier proof includes `./script/private_beta_packet.sh --check`, runtime no-egress validation, visual placement evidence validation, prompt proof validation, and focused model-integrity tests. | The proof loop now covers current beta-safe writing lanes, Obsidian run-on, Obsidian font-zoom, Obsidian Markdown-list, Obsidian Markdown-bold, Obsidian multiline, Codex one-word no-submit, Chrome same-text split persistence, virtual-host suggestion preservation, release-signed no-egress proof, Developer ID signed/notarized beta artifacts, private beta packet regeneration, Ghostty fail-closed prompt-row placement trust, Ghostty prompt-row suggestion evidence, Ghostty Tab delivery into the expanded insertion ladder when launch succeeds, detached proof cleanup safety, terminal-ready Ghostty launch failure proof, prompt proof bounded to manifest slices, and a detached Ghostty proof runner. Onboarding, Ghostty verified insertion proof, packaged Accessibility latency proof, and current strict app-proof refresh are the named non-green proof lanes. Proof-only prompt/chat/terminal/browser-production lanes do not count as beta-safe support without live host proof. | Keep `./script/check_steadytype_scorecard.py --live`, `./script/check_prompt_app_manifest_proof.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/claude_code_ghostty_detached_proof.sh start && ./script/claude_code_ghostty_detached_proof.sh wait`, `./script/packaged_latency_proof.sh textedit-model-latency`, `./script/private_beta_packet.sh --check`, and `./script/beta_readiness.sh --check-only` in the loop. |

## Score Rules

- The overall score is the rounded average of the 12 row scores.
- A row with stale, pending, blocked, missing, or failed evidence must stay visibly below green.
- A 100/100 row must have its own row-specific gates green. It cannot contain
  stale, pending, blocked, missing, failed, incomplete, open-gap, remaining-gap,
  still-needs, short-of, or not-yet language.
- A row can only rise when its evidence cell names a current command, trace slice,
  screenshot, proof manifest row, or documented manual gate.
- If a gate fails, the failure is evidence. Keep it in the row until the command
  actually passes.

## 100 Paper-Cut Remediation Map

The paper-cut audit rolls up into these product-truth clusters. This map is a
triage view, not a claim that all 100 are fixed.

| Cluster | What It Covers | Current Stance |
| --- | --- | --- |
| Proof freshness | 10 beta-safe target app rows from strict manual smoke. | Current strict manual smoke passes for all 10 beta-safe rows; rerun after every app/source change. |
| Proof-only surfaces | Browser editor fixtures, Chrome real Monaco, Chrome chat-like, Codex, Claude Code, and Claude desktop. | Do not count them as beta-safe normal writing support. |
| Prompt-app safety | Codex, Claude, Claude Code, and chat-like composers. | Codex has current one-word no-submit proof; full accept and normal beta use stay off without exact current proof. |
| Hosted browser apps | Google Docs, Notion, Slack, Discord, Browser ChatGPT, production Monaco/CodeMirror. | Block until disposable real-surface proof exists. |
| First-run trust | Accessibility, TextEdit practice, model readiness, pause, Esc, trace deletion. | Needs a current guided walkthrough row before beta. |
| Runtime and packaging | App-owned model, latency freshness, signed DMG, notarization, Gatekeeper. | Notarized DMG/private packet proof exists; packaged Accessibility trust, onboarding proof, and the umbrella beta run still block. |
| Privacy language | Local-first defaults, redacted export, no raw text/screenshots by default. | Keep simple and tester-readable; no cloud or telemetry overclaim. |
| Naming and public docs | SteadyType-facing copy, old lab/tester wording, support claims. | Public docs should say SteadyType and avoid broad support promises. |

## Loop Command

Run this before changing the score:

```bash
./script/check_steadytype_scorecard.py --live
./script/check_test_coverage_manifest.sh
./script/check_onboarding_walkthrough_proof_self_test.sh
./script/check_onboarding_walkthrough_proof.py
./script/check_visual_placement_evidence.sh --require-all
./script/select_latency_window_self_test.sh
./script/latency_benchmark_report_self_test.sh
./script/check_controls_diagnostics_readiness.sh
./script/check_proof_manifest.sh --require-all
./script/manual_smoke_status.sh --strict
./script/packaged_latency_proof_self_test.sh
./script/claude_code_ghostty_detached_proof_self_test.sh
./script/beta_readiness.sh --check-only
```
