# SteadyType Product Scorecard

Updated: 2026-05-28 America/Chicago.
Base app/source evidence checked through the current score-loop commits.
Latest beta gate evidence checked with `./script/beta_readiness.sh --check-only`, `./script/manual_smoke_status.sh --strict`, `./script/check_runtime_network_egress.py --validate-proof`, `./script/select_latency_window.py`, `./script/private_beta_packet.sh --check`, `./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/package_release.sh --check --require-developer-id --require-notary-profile`, `./script/check_prompt_app_manifest_proof.sh`, the guided TextEdit walkthrough proof gate self-test, fresh beta-safe app proof, current TextEdit model-latency proof, retired Claude desktop model-latency proof lane, packaged TextEdit model-latency proof wrapper, current runtime no-egress proof, Claude Code terminal-host insertion source proof, detached Ghostty launchd/nohup proof failure evidence, direct Ghostty command-open prompt-readiness evidence, detached Ghostty proof runner self-test, focused daily-driver activation/trigger Swift tests, full Swift test, focused model-integrity Swift tests, current Obsidian run-on proof, current Obsidian font-zoom proof, current Obsidian Markdown-list proof, current Obsidian Markdown-bold proof, current Obsidian multiline proof, current Codex one-word no-submit proof, current Chrome textarea/contenteditable split-persistence proof, and the latest strict manual smoke status passing on the current build.
Overall score: 86/100.

This is the single current product scorecard. Older scorecards are historical
inputs only. Do not raise a score unless the evidence in the row changes.
Stale proof can explain progress, but it cannot make a row green.

Current strict manual smoke is green after the latest source changes.
`./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit
`e2da385b0ece`. TextEdit, Notes title/body/checklist, Obsidian
default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable all
have current rows with 2 accepted insertions and strict visual trace evidence.
The refreshed rows include TextEdit diagnostics lines `936047`-`936183`,
Obsidian long-note lines `936188`-`936319`, Chrome textarea lines
`936380`-`936545`, and Chrome contenteditable lines `936553`-`936730`.

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
requires a visible title-marked Ghostty proof window before it can count a
disposable proof command as launched. A manual probe showed Ghostty can expose a
focused terminal while reporting an empty working directory, so the harness now
treats focused terminal availability as readiness and keeps the working
directory signal diagnostic-only.
The current harness-hardening pass widened the proof-only Ghostty launch waits,
made the detached wrapper default to the `launchd` runner with terminal/nohup
as explicit fallback launchers, invokes generated runners through `/bin/bash`,
added an EXIT status trap, records the child `real_app_smoke` pid in `status.env` and
`smoke.pid`, reports `smoke_process=alive|not-running`, preserves an alive
smoke child after runner exit so its evidence can keep flowing, protects the
wrapper process group from exclusive proof cleanup, isolates the child through
job-control process groups, writes `smoke-startup.log` phase markers from inside
`real_app_smoke.sh`, and guarded the Ghostty host bundle-id helper against
broken-pipe termination.
`bash -n script/real_app_smoke.sh
script/real_app_smoke_self_test.sh script/claude_code_ghostty_detached_proof.sh
script/claude_code_ghostty_detached_proof_self_test.sh`,
`./script/real_app_smoke_self_test.sh`,
`./script/claude_code_ghostty_detached_proof_self_test.sh`,
`./script/check_steadytype_scorecard.py --live`, and `git diff --check` passed
after the hardening. The live follow-ups
`20260528T063520Z-ghostty` and `20260528T063816Z-ghostty` still failed red
before insertion because the runner/smoke handoff died before prompt setup. The
bounded run `20260528T064731Z-ghostty` sharpened the red bar: the `nohup`
runner wrote the proof header, logged protected proof process group `55629`,
spawned smoke pid `55652`, then both the runner and smoke child exited before
the child printed the real app smoke plan or wrote a final status. The latest
diagnostic run, `20260528T065031Z-ghostty`, proved the child shell itself
starts: it logged protected process group `65768`, spawned smoke pid `65791`,
and printed `Detached Ghostty smoke child shell pid 65785 pgid 65768 entering
real_app_smoke`, but still died before `real_app_smoke.sh` printed its plan or
returned a status. The job-control follow-up, `20260528T065942Z-ghostty`, moved
past that handoff failure: the child printed the smoke plan, built SteadyType,
warmed CGEvent helpers, wrote startup phases through `after-interference-guard`,
and exited cleanly with status `1` after two fresh Ghostty disposable contexts
failed to write the Claude pidfile. The next blocker is Ghostty launch command
execution / pidfile creation, not wrapper/smoke handoff and not a green
insertion claim. The launch-command follow-up now defaults Ghostty to the native
`text:` action with a carriage return instead of separating text input from
Enter, but `20260528T070944Z-ghostty` was not conclusive: it waited on an active
older smoke process, reached build/helper warmup, then the runner was
interrupted with `TERM` and the orphaned smoke child was stopped. The next clean
run, `20260528T071059Z-ghostty`, still failed after two fresh disposable
contexts with no Claude pidfile. The launch-stage diagnostic follow-up,
`20260528T071510Z-ghostty`, narrowed that failure further: `ghostty-launch.log`
recorded only `launch-begin retry-begin`, which proves the AppleScript wrapper
started but never reached `new-window-start` inside the Ghostty `tell` block.
Manual `open -na /Applications/Ghostty.app` probes with `--command`, `-e`, and a
`.command` document also failed to write a proof pidfile.
The AppleScript-health follow-up now checks Ghostty before any disposable
launch, records handler calls through `my recordStage` inside Ghostty's `tell`
block, probes `version` instead of the hanging `count windows` path, preserves
nonzero background child exits, and now traces the disposable-window object
lookup before retry. The bounded run `20260528T074034Z-ghostty` proved the
preflight repair: it logged
`preflight-begin preflight-tell-entered preflight-version:1.3.1
preflight-finished launch-begin new-window-start retry-begin` before failing
without a Claude pidfile. Local disposable `open -na Ghostty.app --args`
probes with `--command`, `--initial-command`, and AppleScript surface
configuration did not write a pidfile, and Ghostty CLI reported `+new-window`
is unsupported on macOS. Follow-up detached runs `20260528T074729Z-ghostty`,
`20260528T074807Z-ghostty`, and `20260528T075016Z-ghostty` were interrupted
with `TERM`, so they are treated as inconclusive cleanup noise rather than
support evidence. The follow-up `20260528T080441Z-ghostty` proved the current
AppleScript freeze is the `front window` lookup after `new-window-start`: it
recorded `new-window-front-window-start` and never reached
`new-window-front-window-resolved`, then ended with `TERM` during cleanup. A
temporary proof-only System Events launch experiment moved past that freeze and
created a fresh Ghostty window, but it still never wrote the Claude pidfile, so
that fallback was removed. A separate stage-log probe reached
`launch-action-finished` and `launch-finished` without `script-started` or a
pidfile, proving the Ghostty `text:` action can place the disposable command
without submitting it; the current code now sends an explicit Enter after the
launch action instead of embedding a carriage return in the action text. The
fresh detached proof `20260528T082327Z-ghostty` exited `42` after recording
`new-window-front-window-start` without `new-window-front-window-resolved`, so
the explicit-Enter path is present but still unexercised by a successful
disposable launch. The follow-up `20260528T082847Z-ghostty` enabled the
opt-in proof-only Ghostty host reset and still exited `42` at the same
`front window` lookup. `20260528T083459Z-ghostty` proved the pre-launch
proof-only reset can remove a Ghostty proof/probe-only pid, then still failed at
`new-window-front-window-start`. The `nohup` launcher follow-up
`20260528T083919Z-ghostty` got through `launch-action-enter-sent` and
`retry-launch-action-enter-sent`, but still never wrote the Claude pidfile. The
current launch bridge now refuses to treat a fresh Ghostty terminal as ready
until `working directory of targetTerminal` is non-empty, and records
`terminal-working-directory-present` / `retry-terminal-working-directory-present`
before submitting the proof command. The follow-ups `20260528T084711Z-ghostty`
and `20260528T085044Z-ghostty` showed that gate holding: neither run reached
the working-directory stage. `20260528T085401Z-ghostty` then opened Ghostty with
`window-save-state=never` before preflight, but still did not reach
`terminal-working-directory-present`; direct `-e`, `--initial-command`,
`--command`, and temp `--config-file` no-restore probes also failed to write a
pidfile. AppleScript `new window with configuration` probes reached `window` and
`activated`, but `command`, `initial input`, native `input text`, and proof-only
paste/Enter launch attempts still left the pidfile missing. The current blocker
is Ghostty accepting a script-owned command submission into a real shell/pty. The
follow-up `20260528T090002Z-ghostty` records the new no-restore ownership path
(`owns no-restore host pid(s): 55808`), still failed at
`new-window-front-window-start` with exit `42`, and cleanup removed that
proof-created Ghostty host afterward. `20260528T091930Z-ghostty` added a
proof-owned process-tree classifier, recorded `no-restore-host-no-child-process`
for Ghostty pid `94700`, still stalled at `new-window-front-window-start`, exited
`42`, and cleaned up the proof-owned host. `20260528T094943Z-ghostty` then
started Ghostty with `--initial-window=false`, skipped the restored-window count
path, reached `configured-window-start`, recorded the configured-window API stall
classifier before `configured-window-created`, exited `42`, cleaned proof-owned
pid `5157`, and left no Ghostty/proof process behind.
`20260528T095836Z-ghostty` moved the launch bridge forward: both disposable
attempts reached `configured-window-created` and `new-window-created`, then
failed because Ghostty never reached `terminal-working-directory-present` or
wrote `claude.pid`; the harness now records this as
`configured-window-shell-not-ready` / `retry-configured-window-shell-not-ready`
instead of conflating it with window creation.
The newest direct-open follow-up moves the red bar past configured-window
launch. Local `open -na Ghostty.app --args --window-save-state=never
--quit-after-last-window-closed=true --working-directory=<repo> -e <script>`
probes wrote `claude.pid` reliably, so the smoke harness now tries that path
before AppleScript window creation. `20260528T102120Z-ghostty` proved the
patched detached runner publishes the live smoke child pid, protects that
process group, and reaches proof-owned Ghostty pid `42748` through the direct
command-open path. It still failed red: AX prompt readiness saw only part of
the typed proof text before retry, and the second context received SIGTERM
before insertion could start. Ghostty's next blocker is now stable prompt text
readiness/retry handling after direct command-open, not configured-window shell
creation.
`20260528T103308Z-ghostty` proved the direct command-open path still creates
fresh proof-owned Ghostty contexts and writes `claude.pid`, but it failed before
verified insertion because the AX/readiness path kept treating shell-command
text as prompt context. The run then timed out with
`suggestion-blocked` diagnostics for shell-command and unsafe-input-line
reasons, so Ghostty's red bar is now making the direct-open prompt truly
Claude-ready and AX-readable before typing or retrying.
`20260528T103624Z-ghostty` then showed the native prompt clear can get the
direct-open context past the shell-text blocker and recover a prompt-row anchor,
but the old long typing drain let focus slip before the final trigger. The
current harness splits that drain so prefix typing settles briefly while prompt
clearing can still use the longer Ghostty event drain. `20260528T104312Z-ghostty`
proved that shorter drain plus native final-trigger typing avoids the focus-loss
failure, but it still failed red: the prompt exposed only partial marked input
(`beforeChars=28`), produced no visible suggestion, then fell back into
missing-marker / unsafe-input-line diagnostics. The next Ghostty red bar is now
full marked proof-text insertion into the Claude prompt before suggestion
discovery, not just direct process launch. The bounded retry loop now routes
retryable Ghostty misses through a max-attempt guard so one-attempt proofs stop
at the real red bar instead of opening an extra disposable context; the
follow-up `20260528T104706Z-ghostty` failed earlier in launch readiness, before
the typed-prompt path, and left no running proof process.
The newest prompt-policy pass keeps Ghostty's focused-window screen text
available even when direct AX text has a proof marker, trusts title-scoped
visible prompt rows when stale AX header text is the only mismatch, and makes
initial Ghostty prompt readiness tolerate launch-command scrollback only after
Claude prompt chrome is visible. `20260528T110025Z-ghostty` still failed red:
the first direct-open context did not become frontmost, the second context hit
launch-command scrollback, the clear-and-retry path removed the prompt hint, and
AX readiness still rejected shell-command text. The next Ghostty red bar is now
preserving or rediscovering Claude prompt chrome after clearing launch scrollback
so typed prompt proof can start consistently. A follow-up
`20260528T110231Z-ghostty` failed even earlier because both direct-open contexts
could not become frontmost and zero-window Ghostty hosts had to be reset, so
frontmost launch readiness is still flaky around the same prompt-preflight lane.
The empty-prompt AX helper now treats hints as optional only for empty-text
readiness, avoiding brittle placeholder dependence after process/pid proof.
`20260528T110650Z-ghostty` proved the improvement: the run reached a fresh
direct-open context, cleared the prompt, typed the proof text, showed a prompt-row
phrase suggestion, and delivered Tab with `keyboard-action handled=true`, then
failed closed at verified insertion because every app-owned Ghostty transport
left the prompt unchanged. `20260528T111744Z-ghostty` repeated the important
part of that red bar after live AX inspection: Ghostty's focused `AXTextArea`
was readable but not settable, shell-driven System Events typing could work
outside the app, and the app-owned send-key, bulk System Events, pasteboard,
native, helper, hardware, and Unicode transports still left the disposable
prompt unchanged. The app now classifies that initial send-key / bulk System
Events / pasteboard unchanged-prompt cluster as a known Ghostty no-op and fails
fast unless `AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES=1` is set.
Ghostty remains unsupported until a detached run reaches verified one-word
no-submit insertion and exits `0`. The follow-up proofs
`20260528T112642Z-ghostty`, `20260528T112856Z-ghostty`, and
`20260528T113115Z-ghostty` did not reach the new insertion classifier: the first
two failed typed-prompt readiness after native final-trigger failure and CGEvent
fallback, and the third got past Ghostty's command-execution approval sheet but
failed both direct-open attempts because the prompt still contained launch-command
shell text. `20260528T114032Z-ghostty` proved the direct-command fallback: the
first direct-open context still exposed launch-command text, the harness disabled
direct command-open for the retry, the script-owned/no-restore path reached a
fresh disposable context, typed the marked proof prompt, found a prompt-row
suggestion at diagnostics line `903324`, handled Tab, and then failed closed at
the expected `ghostty-initial-insertion-noop-cluster` after `ghosttySendKey`,
bulk System Events, and pasteboard all left the prompt unchanged. The initial
fail-fast cluster now also includes the default app-owned in-process Ghostty
input proof before slower extended probes, so a future in-process verified or
unsafe result will not be hidden behind the known send-key / System Events /
pasteboard no-op. The current red bar is verified Ghostty one-word insertion,
not prompt readiness. Current-tree follow-ups `20260528T114501Z-ghostty` and
`20260528T115241Z-ghostty` were both terminated by `SIGTERM` during the
script-owned retry launch before prompt readiness, so they are not counted as
insertion evidence. `20260528T115530Z-ghostty` reached the script-owned
no-restore prompt twice, found prompt-row suggestions at diagnostics lines
`905520` and `906995`, retried after Tab delivery lost the first visible
suggestion, then delivered Tab on attempt 2 and failed closed at
`ghostty-initial-insertion-noop-cluster` after send-key, System Events,
pasteboard, and in-process native input all left the prompt unchanged. The app
now has a focused frontmost-process System Events bulk rung before the heavier
terminal-scanning System Events script, but `20260528T120508Z-ghostty` and the
diagnostic `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=0`
`20260528T120653Z-ghostty` were both terminated by `SIGTERM` during
build/relaunch before reaching insertion, so they do not count as proof for
that new rung. After the smoke cleanup path started stopping its exclusive
interference guard, `20260528T120818Z-ghostty` survived build/relaunch, found a
prompt-row suggestion at diagnostics line `908782`, handled Tab, exercised the
new `ghosttyFocusedSystemEventsBulkKeystroke` rung at line `908826`, and proved
it exited `0` but still left the prompt unchanged before the known no-op cluster
failed closed. `20260528T121157Z-ghostty` tried to run the extended ladder but
was terminated during the second no-restore launch before insertion. A focused
native `text:` action rung then shipped before pasteboard probes;
`20260528T121458Z-ghostty` reached the same prompt-row suggestion lane at
diagnostics line `910704`, ran `ghosttyFocusedActionText` at line `911799`, and
proved that focused native action also exited `0` while leaving the prompt
unchanged before the expanded no-op cluster failed closed at line `911879`.
The next proof slice adds a native Ghostty screen-copy verifier after a focused
native action miss so AX-only insertion misses are not the only source of truth.
The verifier uses Ghostty's `write_screen_file:copy,plain` action, restores the
user pasteboard, and records only redacted shape metadata. The short
non-exclusive run `20260528T122859Z-ghostty` reached a prompt-row suggestion at
diagnostics line `914890`, handled Tab at line `915747`, and then recorded
`ghosttyFocusedActionTextScreenCopy` at line `915773`: Ghostty's native copied
screen had `screenChars=90` but contained neither the expected inserted prompt
nor the original prompt, while AX still reported the original prompt at the
following baseline. That does not make Ghostty supported; it proves AX and
native screen state can disagree after app-owned insertion attempts, so the app
now treats proof-context screen-copy mismatches as fail-closed evidence and only
continues when the copied screen has no proof context. The patched rerun
`20260528T123354Z-ghostty` rebuilt the app, reached a prompt-row suggestion at
diagnostics line `916684`, but lost the visible suggestion during Tab injection
before insertion, so it is launch/accept flake evidence rather than verifier
evidence. A later patched run, `20260528T123843Z-ghostty`, reached the same
prompt-row path at diagnostics line `918110`, exercised the native screen-copy
verifier at lines `919006`-`919007`, classified the copy as
`ghostty-screen-copy-no-proof-context`, continued through the AX baseline only as
inconclusive, and still failed closed through the unchanged-prompt no-op cluster
at lines `919023`-`919026`.
The current follow-up makes that classifier stricter before it can shorten the
default Ghostty ladder: the initial no-op fail-fast now requires the focused
native action's screen-copy verifier to classify an original-prompt native
no-op, not merely an AX unchanged baseline. `20260528T124841Z-ghostty` rebuilt
the app, reached a prompt-row suggestion at diagnostics line `919640`, consumed
Tab, and scheduled deferred insertion at lines `920533`-`920535`.
`ghosttyFocusedActionText` posted at line `920559`,
`ghosttyFocusedActionTextScreenCopy` at lines `920560`-`920561` again reported
`ghostty-screen-copy-no-proof-context`, and the app therefore continued past the
initial no-op cluster instead of treating that inconclusive native copy as
classified no-op evidence. The run then proved the same app-owned insertion
miss across front-window native input, marker-scanned native input,
paste-from-clipboard action, System Events, hardware, and bundled helper rungs,
before failing closed on the explicit 45s budget at diagnostics lines
`920618`-`920620`. Ghostty remains unsupported until a detached run exits `0`
with verified one-word no-submit insertion.
The next slice made the native screen-copy verifier use the same title-marker
window scan as the marker-scanned Ghostty action/input rungs instead of relying
only on `front window`. `20260528T125524Z-ghostty` rebuilt the app, reached a
prompt-row suggestion at diagnostics line `921180`, consumed Tab, and scheduled
deferred insertion at lines `922040`-`922042`. Even with marker-scanned window
selection, `ghosttyFocusedActionTextScreenCopy` still copied a 90-character
screen with no proof marker, no expected prompt, and no original prompt at
lines `922067`-`922068`. The app correctly treated that as inconclusive,
continued through the unchanged-prompt baseline at line `922084`, and then
failed closed on the explicit 45s budget at lines `922125`-`922127`. The
remaining Ghostty red bar is no longer just front-window targeting; Ghostty's
native copied screen can still be detached from the proof prompt even after a
title-marked target window is selected.
The newest diagnostic slice keeps that evidence red but more legible. The
screen-copy verifier now returns sanitized target-selection metadata instead of
only a boolean success: `targetSelection`, `frontWindowProofMatch`, and
`windowCount`. `20260528T130343Z-ghostty` rebuilt the app, reached prompt-row
suggestion diagnostics, handled Tab, and recorded
`ghosttyFocusedActionTextScreenCopy` at diagnostics lines `923632`-`923633`.
The native copy selected `targetSelection=frontProofTitle` with `windowCount=1`,
but still copied a 90-character screen with no proof marker, no expected prompt,
and no original prompt, so the app continued past the inconclusive native copy,
proved the prompt stayed unchanged across the rest of the app-owned ladder, and
failed closed on the 45s budget at lines `923690`-`923693`. A follow-up after
renaming the title-match key, `20260528T130816Z-ghostty`, reached a prompt-row
suggestion at diagnostics line `924218`, handled Tab at line `925104`, recorded
the current metadata keys at lines `925131`-`925132`, and then failed closed on
the 45s budget at lines `925189`-`925192`.
The latest natural detached rerun before the classified-no-op patch,
`20260528T131620Z-ghostty`, reached prompt-row suggestion diagnostics line
`925644`, consumed Tab at line `926571`, recorded the same title-selected
90-character no-proof-context screen copy at lines `926612`-`926613`, and failed
closed on the 45s budget at lines `926670`-`926673`.
After classifying that high-confidence proof-window/no-proof-context copy as a
native no-op, `20260528T132403Z-ghostty` reached prompt-row suggestion
diagnostics line `927766`, consumed Tab at line `928636`, recorded
`nativeNoopClassified=true` with `frontWindowProofMatch=true`,
`targetSelection=frontProofTitle`, and `windowCount=1` at lines
`928677`-`928678`, proved the prompt stayed unchanged through the in-process
native input baseline at lines `928692`-`928694`, and failed closed earlier with
`reason=ghostty-initial-insertion-noop-cluster` at lines `928695`-`928697`
instead of spending the full 45s exploratory budget. Ghostty remains unsupported
until a detached run exits `0` with verified one-word no-submit insertion.
The detached proof runner now defaults `AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=0`
so recurring automation starts on the script-owned/no-restore fallback path that
has been reaching prompt-row Tab, while direct command-open remains available as
an explicit opt-in probe. The first rerun after that change,
`20260528T132935Z-ghostty`, exposed a harness edge where direct command-open
dirtied the prompt on the final launch attempt; the fresh-context retry now
grants one extra script-owned attempt after that dirty-prompt classification.
The follow-up `20260528T133331Z-ghostty` proved the intended path: command-open
was disabled, the script-owned/no-restore host reached a prompt-row suggestion
at diagnostics line `929688`, handled Tab at line `930715`, recorded
`nativeNoopClassified=true` at lines `930741`-`930742`, proved unchanged
baselines through `ghosttyInProcessInputText` at lines `930754`-`930758`, and
failed closed at `ghostty-initial-insertion-noop-cluster` on lines
`930759`-`930760`. An extended probe run, `20260528T134007Z-ghostty`, then
disabled fail-fast and enabled the native prefix/final-key probe. It reached a
prompt-row suggestion at diagnostics line `931345`, proved the prefix/final-key
prefix was still a no-op at lines `932401`-`932404`, exercised the remaining
front-window/native/action/paste/System Events/hardware/bundled helper rungs
through line `932455`, and ended with `ghostty-fast-verified-insertion-failed`
at lines `932456`-`932457`. This rules out a simple reorder of the current
transport ladder on the stable script-owned launch path.

Latest daily-driver source delta: `swift test --jobs 1 --filter
CommonPhraseContinuationPredictorTests` passed on 2026-05-28 after expanding
the instant email/casual-chat reply layer with safe short continuations such as
`Good call` -> `that makes sense`, `Let me know` -> `what you think`,
`Checking in` -> `on this`, `I'll take` -> `a look`, `I'm on` -> `it now`,
and `Thanks again` -> `for sending this`; prompt, search, form, and code
profiles stay gated out of that fallback path.

## Scores

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Suggestion quality | 95/100 | `./script/check_quality_eval.sh`: completion quality, word-completion quality, offline-model quality, and the deterministic 500-case completion-prediction suite all passed on 2026-05-28 after the generic-filler suppression, concrete suffix examples, 8-word default phrase posture, first-pass 3-8 word prompt label, and instant short-reply / thinking-flow predictors in `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`, `Sources/AutocompleteLabCore/Engine/CommonPhraseContinuationPredictor.swift`, `Sources/AutocompleteLabCore/Session/AutocompleteBehaviorProfile.swift`, `Sources/AutocompleteLabCore/Session/SuggestionAggressiveness.swift`, and `script/local_completion_runtime.py`. `./script/check_daily_driver_local_quality_audit_report.sh`: passed for `docs/evals/daily-driver-local-quality-audit-2026-05-25.md` with 45 disposable rows, 36 display-eligible rows, 9 expected suppression rows, 100/100 overall, 100/100 relevance, and no raw output persisted. `swift test --jobs 1 --filter SuggestionOrchestratorTests`: 36 tests passed after a shown 0ms phrase fallback stopped ending the request early; it now queues the model for refinement, stays visible during fast typing instead of being hidden by the model typing-burst gate, and remains visible if the follow-up model continuation fails for the same live request. `swift test --jobs 1 --filter CompletionPromptBuilderTests`: 33 tests passed after the primary default 8-word prompt started asking for `Next 3-8 words, or <NO_SUGGESTION>:` before retry instead of waiting for the short-candidate repair path. `swift test --jobs 1 --filter CommonPhraseContinuationPredictorTests`: 21 tests passed after the instant predictor added Obsidian/writing-flow continuations such as "One thing I noticed is" -> "that the flow breaks there", "What I know so far is" -> "the next step is clear", "The next pass should" -> "make the point clearer", "I am thinking about" -> "what needs to happen next", "What I actually want is" -> "the simplest version that works", "The thing I am worried about is" -> "where this breaks trust", "The next obvious move is" -> "to test it in context", daily-driver reach-test continuations such as "The difference is" -> "whether it feels magical", "This breaks trust when" -> "it appears in the wrong field", and "The reach test is" -> "whether i keep using it", field-safety trust continuations such as "If the focused field looks risky, it should" -> "fail closed before typing", "When the wrong field should" -> "stay silent until proof", and "If placement feels weird, it should" -> "stay quiet until proof", and guarded next-sentence boundary continuations such as "Suggestions feel too timid." / "Suggestions feel too timid. " -> "It should predict the next phrase", "Placement keeps showing in the wrong field." / "Placement keeps showing in the wrong field. " -> "That has to fail closed", and "Typing feels slow when suggestions lag." -> "Speed has to feel invisible" while keeping email, prompt, search, and code contexts off for that path. `swift test --jobs 1 --filter 'AutocompleteBehaviorProfileTests|CommonPhraseContinuationPredictorTests'`: 32 tests passed after the instant predictor added short messaging/email reply continuations such as "Sounds good" -> "to me", "Let me" -> "take a look", "Thanks for" -> "sending this over", while Messages and Telegram resolve to the casual-chat profile and prompt/search/form/code profiles remain off for that fallback path. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SuggestionTriggerPolicyTests|CompletionActivationPolicyTests'`: 61 tests passed after very-proactive writing surfaces started preferring phrase continuation for word fragments with enough context, requesting next-sentence phrase continuations at sentence boundaries, and allowing an Obsidian-only daily-driver line-start phrase path after one word while prompt surfaces keep the old quiet gate. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SettingsWindowControllerStateTests|SuggestionOrchestratorTests|ModelPolicyTests|CommonPhraseContinuationPredictorTests'`: 102 tests passed after the default visible phrase cap moved to 8 words, old 3-word and 5-word defaults gained a version 6 migration, and the default cap now asks for 3-8 word phrase guidance. `./script/daily_driver_dogfood_session_self_test.sh`: passed after the redacted dogfood gate started reporting instant draft model follow-up results, model replacements shown, visible preservation after empty model results, and per-outcome instant phrase counts. | Deterministic and disposable local-model quality proof is green, and the default tuning is less timid at sentence boundaries, natural period-plus-space boundaries, partial-word phrase starts, first-pass 3-8 word requests, guarded instant next-sentence phrases, common reply phrasing, common notes/Obsidian thinking-flow starts, reach-test complaint language, field-safety trust language, and instant-then-model phrase refinement, but this is still not broad live writing volume with real accepted-kept, typed-over, annoyance, and reach-for-it signals. | Run a real writing dogfood session, fill the Manual Trust Row, then gate it with `./script/daily_driver_dogfood_session.sh review --report <report>`. |
| Placement | 91/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `e2da385b0ece` for TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. The refreshed rows include strict visual trace evidence and 2 accepted insertions each, including Obsidian long-note diagnostics lines 412384-412504 / traces lines 27824-27834, Chrome textarea diagnostics lines 413133-413420 / traces lines 27932-27989, and Chrome contenteditable diagnostics lines 413430-413717 / traces lines 27992-28051. Current-build Obsidian default proof refreshed on 2026-05-28T13:48:08Z at commit `707b7c95c614` with diagnostics lines 932538-932695 / traces lines 30739-30761, 2 accepted insertions, strict visual evidence, and a proof-vault launch that forces Electron renderer accessibility after default Obsidian 1.12.7 exposed only window chrome through AX. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c` with 2 accepted insertions after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-font-zoom --manual-gate`: passed on 2026-05-26T00:21:08Z at commit `73c85c56109b` with diagnostics lines 409510-409632 / traces lines 27370-27381, 2 accepted insertions, strict visual trace evidence, and restored Obsidian zoom. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z at commit `70cc9b29b59c` with diagnostics lines 410919-411071 / traces lines 27597-27618, 2 accepted insertions, strict visual trace evidence, and the suggestion staying on the dash-list row. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z at commit `1953b49a6e21` with diagnostics lines 413977-414128 / traces lines 28065-28085, 2 accepted insertions, strict visual evidence, and the caret repaired back to the bold line before the second suggestion. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-multiline --manual-gate`: passed on 2026-05-26T02:23:05Z at commit `db5bc6ffcd72` with diagnostics lines 414135-414268 / traces lines 28086-28099, 2 accepted insertions, and strict visual evidence on the lower multiline caret. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with diagnostics lines 574487-574600 / traces lines 28182-28188, 1 accepted insertion, strict visual trace evidence, and prompt no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed for the same Codex bounded prompt slice. | The 10 beta-safe writing lanes plus Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline variants and Codex one-word no-submit proof are covered by recorded rows, but the claim is still intentionally narrow. Prompt apps remain proof-only, terminal hosts need current insertion-source proof, and production browser apps, hosted docs, and chat surfaces remain unclaimed. The Markdown-list full-accept pass uses the disposable proof-vault direct-value gate after a verified unchanged retry, so it does not broaden production Obsidian insertion claims by itself. | Keep `./script/check_prompt_app_manifest_proof.sh` green after each app/source change, then record a live prompt full-accept no-submit row before broadening prompt/chat claims. |
| Tab safety | 88/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `e2da385b0ece`, with Tab/full-accept insertion proof across TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c`; Tab accepted the next word and Option+Tab accepted the remaining visible phrase after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z with Tab accepting `instant` inside a dash-list row instead of turning into indentation, then full accept verifying through the proof-vault retry path. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z with Tab and full accept staying in the bold Markdown line. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with one-word Tab accept, strict visual evidence, and no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed with prompt safety counters at 0. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after adding explicit full-accept no-submit proof mode with required manifest, smoke-row, accepted-event, and verified-insertion evidence. | Prompt/chat apps are not normal beta writing surfaces. Codex one-word no-submit is current, but full accept stays off for prompt apps until exact full-accept no-submit proof exists, production browser apps stay unclaimed, and Markdown-list/full accept variants are still proof-vault lanes rather than broad Obsidian production guarantees. | Run `./script/check_prompt_app_manifest_proof.sh` after the next app/source change, then record a live separate full-accept no-submit proof before enabling full accept in any prompt/chat surface. |
| Latency | 80/100 | `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-model-latency`: passed on 2026-05-28 with 5 model-backed visible samples, first-visible `avg=253ms p95=258ms`, first-token `avg=228ms p95=233ms`, total generation `avg=252ms p95=293ms`, event-tap overhead `avg=40us p99=89us`, AX read summaries `p99Max=25ms max=25ms`, and zero late shown suggestions, event-tap failures, AX slow markers, or AX skips. executable-sha256=`bbf596398145cbf1b1ca4c639fedaa56f9cbc8a731ca2d447bc66bb7eae29e4d`; TextEdit strict selector `./script/select_latency_window.py`: selected diagnosticsLine=833735, traceStartLine=30421, firstVisibleSamples=5, modelSamples=5, fastWordVisibleSamples=0. `swift test --jobs 1 --filter TypingBurstPolicyTests`: 5 tests passed after the default fast-typing detector started catching roughly 70 wpm typing with 6 inserted characters inside 1.1 seconds while leaving word completion eligible. The Claude desktop latency lane is retired for now because its current task UI is not a safe prompt proof surface; the helper now refuses task/start buttons and only uses a safe chat composer. `./script/packaged_latency_proof_self_test.sh`: passed after the packaged proof wrapper default moved to the beta-safe TextEdit latency lane while keeping Claude as an explicit target. | Current dev-smoke latency is fast and model-backed in a beta-safe writing app, but the release-packaged app cannot collect current latency samples until Accessibility is granted for `bar.r3d.steadytype` after notarized install. | Grant Accessibility to the notarized `dist/SteadyType.app`, then rerun `./script/packaged_latency_proof.sh textedit-model-latency` and `./script/select_latency_window.py`. |
| Privacy | 95/100 | `./script/beta_readiness.sh --check-only`: runtime no-egress proof, redacted report export, current build privacy export proof, issue template, clipboard fallback disabled, prompt app proof gate, and prompt/chat safety counters all passed after the release-signed proof refresh. `python3 ./script/check_runtime_network_egress.py --pid 25216 --phase autocomplete --duration 12 --interval 1 --activity-note "current release-signed packaged runtime after package_release archive" --proof-out docs/product/runtime-network-egress-latest.md --json-out docs/product/runtime-network-egress-latest.json`: passed on 2026-05-28T05:48:01Z with 13 samples, 0 non-loopback remote endpoints, and wrote redacted packaged-runtime proof to `docs/product/runtime-network-egress-latest.md` and `docs/product/runtime-network-egress-latest.json` for executable SHA-256 `b6a899a2949d5eebcbd13a4a37015508c038dbe95ba132e6b9564f6cae4006b6`. `python3 ./script/check_runtime_network_egress.py --validate-proof docs/product/runtime-network-egress-latest.json --diagnostics-log "$HOME/Library/Logs/SteadyType/diagnostics.log" --require-newer-than-latest-launch --max-proof-age-seconds 86400 --min-samples 10 --app-binary dist/SteadyType.app/Contents/MacOS/SteadyType`: passed. `./script/check_sensitive_field_proof_self_test.sh`: passed after the gate expanded required suppressed categories and required browser-hosted suppression rows for Google Docs, Notion, ChatGPT, Slack, Discord, browser login/payment/password-manager/private-search/address-bar/developer-tool, and unproven browser pages. `swift test --jobs 1 --filter 'SensitiveTextFieldPolicyTests|BrowserHostedSurfacePolicyTests'`: 30 tests passed, including the expanded Chrome/Safari/Brave/Arc/Firefox/Chromium browser-hosted fail-closed policy. | Privacy proof is current, but the beta privacy claim still depends on the human onboarding walkthrough and the packaged-app Accessibility recovery proof. | Rerun `./script/beta_readiness.sh --check-only` after onboarding proof and packaged-app Accessibility proof are complete. |
| App coverage | 83/100 | `./script/check_proof_manifest.sh --require-all`: passed with 7 complete surfaces, 20 profile coverage rows, 20 host policy rows, 12 graduation decision rows, and 24 verified trace slices. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `e2da385b0ece` for the 10 beta-safe writing rows. Current app proof also includes Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline, Codex one-word no-submit, Chrome textarea/contenteditable split persistence, and Claude Code terminal-host Terminal/iTerm2 one-word no-submit rows. The Ghostty branch now has prompt-row recovery, terminal prompt-row caret estimation, visible prompt-marker modeling, proof-only caret focus click, bounded diagnostics scanning, fresh-process detached proof retries, opt-in proof/probe-only host reset, exact-process focus reassertion, title-scoped fallback focus, terminal-ready launch gating, no-restore proof-owned host cleanup, no-child-process and configured-window launch classification, configured-window shell-readiness classification, timeout-bounded native Ghostty action/input/paste attempts, app-owned in-process native input, direct and shell-launched front-window native input, direct and shell-launched marker-scanned native input, terminal-scoped send-key/System Events paths, foregrounded direct and shell-launched bulk System Events probes, targeted and global hardware-key attempts, bundled/in-process Unicode helpers, pasteboard fallbacks, paced synthetic key events, an opt-in session-tap pasteboard probe, opt-in native-prefix/final-key probe env forwarding, separate prefix verification, and fail-closed gating before generic insertion. `20260527T203149Z-ghostty` found prompt-row suggestions, captured Tab on the fresh second context, tried foregrounded direct bulk System Events, shell-launched bulk System Events, per-character System Events, native Ghostty actions, terminal-scoped send key, hardware-key sources, bundled Unicode helpers, direct Unicode events, and pasteboard insertion, then failed closed because every app-owned insertion transport left the disposable prompt unchanged. `20260527T213259Z-ghostty` again reached hot Tab accept on a fresh prompt-row suggestion, ran the full ladder, proved targeted/global pasteboard misses left the prompt unchanged, queued clipboard restore, and failed closed instead of hanging after global paste. `20260528T025919Z-ghostty` reached prompt-row Tab accept, proved the opt-in session-tap paste miss at diagnostics lines `819221`-`819224`, continued through the full ladder, and still failed closed at `819271` / `819273`. `20260528T030442Z-ghostty` then proved the default ladder skips the session probe, keeps unchanged-prompt baselines, and still fails closed at `821995` / `821997`. `20260528T031735Z-ghostty` accepted the next-word proof at diagnostics line `823023`, tried pasteboard plus native input families, and stopped at diagnostics line `823052` before the slower action-text rung because the default 8s Ghostty insertion budget was exceeded. `20260528T033921Z-ghostty` proved the detached opt-in env reached the app, reached `ghosttyNativePrefixFinalKeyText` at line `825139`, and kept the prompt unchanged at lines `825141` / `825142`; the follow-up `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared in one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at lines `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at lines `832488` / `832489` with handled-false Tab at line `832491`. The latest direct `claude-code-ghostty` pass found the prompt-row suggestion at diagnostics line `800174`, tried the new app-owned in-process native input rung at line `800768`, verified the unchanged baseline at line `800769`, then tried the subprocess front-window/native paths and still failed closed at line `800816`. The latest detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. The AppleScript-health proof `20260528T074034Z-ghostty` moves past preflight: it records `preflight-version:1.3.1` and reaches `new-window-start`, then fails before `new-window-created` or a Claude pidfile; local `--command`, `--initial-command`, surface-configuration, and CLI `+new-window` probes did not produce a working pidfile launch path. `20260528T080441Z-ghostty` records `new-window-front-window-start` and never reaches `new-window-front-window-resolved`, proving the disposable launch blocker moved to Ghostty's front-window object lookup. A removed System Events launch experiment proved a fresh AX window-count increase after that stall, but still failed before pidfile. A separate stage-log probe reached `launch-action-finished` and `launch-finished` without `script-started` or a pidfile, so the current code now submits the Ghostty `text:` action with explicit Enter once launch reaches the target terminal. The fresh detached proof `20260528T082327Z-ghostty` exited `42` at `new-window-front-window-start`; `20260528T082847Z-ghostty` enabled the proof-only reset and still exited `42`; `20260528T083459Z-ghostty` then proved the reset can remove a proof/probe-only pid before launch and still failed at `new-window-front-window-start` under launchd. `20260528T083919Z-ghostty` with the `nohup` launcher got through `launch-action-enter-sent` and `retry-launch-action-enter-sent`, then still failed before pidfile. `20260528T084711Z-ghostty` and `20260528T085044Z-ghostty` exercised the new working-directory readiness gate and never reached `terminal-working-directory-present`; `20260528T085401Z-ghostty` added `window-save-state=never` before preflight and still did not reach a shell-ready terminal; `20260528T090002Z-ghostty` recorded `owns no-restore host pid(s): 55808`, failed closed at `new-window-front-window-start` with exit `42`, and left no proof runner or proof-created Ghostty process afterward; `20260528T091930Z-ghostty` recorded `no-restore-host-no-child-process` for proof-owned Ghostty pid `94700`, still failed closed at `new-window-front-window-start` with exit `42`, and cleaned the proof-owned pid. `20260528T094943Z-ghostty` started with `--initial-window=false`, reached `configured-window-start`, recorded `configured-window API stalled before disposable window creation`, exited `42`, cleaned proof-owned pid `5157`, and left no Ghostty/proof process behind. `20260528T095836Z-ghostty` reached `configured-window-created` and `new-window-created` on both disposable attempts, but never reached `terminal-working-directory-present`, `retry-terminal-working-directory-present`, or `claude.pid`; it failed closed with exit `1`, cleaned proof-owned Ghostty pid(s), and narrowed the red lane to making the configured Ghostty window become shell-ready enough to exec the disposable proof command. `20260528T102120Z-ghostty` then proved direct `open --args -e` can write the pidfile and launch proof-owned Ghostty pid `42748`, with the patched detached runner publishing/protecting live child pid `39108`; it still failed before insertion because AX saw only part of the typed prompt text and the retry context was terminated, so the red lane moved to stable prompt readiness/retry handling after direct command-open. `20260528T114032Z-ghostty` then proved the dirty-prompt fallback: attempt one disabled direct command-open after launch-command AX text persisted; attempt two used script-owned/no-restore launch, reached a prompt-row suggestion at diagnostics line `903324`, handled Tab, and failed closed at `ghostty-initial-insertion-noop-cluster` after `ghosttySendKey`, bulk System Events, and pasteboard left the prompt unchanged. `./script/real_app_smoke_self_test.sh`: passed after adding source checks for bulk System Events ordering, shell-launched bulk System Events, System Events foregrounding, fail-closed baselines, native paste action ordering, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, prompt focus click, in-process native input, front-window input text ordering, shell-launched marker-scanned native input, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification, paced Command-V checks, nonblocking session miss handoff, terminal-ready Ghostty launch checks, the Ghostty AppleScript preflight hard-fail, the `new-window-created` and configured-window launch-stall classifiers, explicit Enter submission after Ghostty launch actions, working-directory readiness before command submission, no-restore proof-owned host cleanup, no-child-process launch classification, configured-window shell-readiness classification, and the opt-in proof/probe-only host reset. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner command, status, tail, stop-mode guardrails, proof-only reset env forwarding, and no raw custom proof-text persistence checks. | Coverage is intentionally narrow. Codex now has a current one-word no-submit proof-only lane, but Claude, chat apps, Mail, terminal hosts, public browser pages, and production browser apps stay proof-only or unclaimed unless exact current proof exists. Ghostty can anchor to the prompt row and route Tab into the expanded fail-closed insertion ladder when launch succeeds, but verified one-word Tab insertion is still not proven and the current detached lane is red at verified Ghostty one-word insertion after the known initial no-op cluster. Obsidian Markdown-list, Markdown-bold, and multiline are covered only for disposable proof-vault lanes. | Keep the script-owned/no-restore Ghostty fallback reaching prompt-row Tab, replace or prove an app-owned Ghostty insertion transport, then rerun `./script/claude_code_ghostty_detached_proof.sh start` plus `./script/claude_code_ghostty_detached_proof.sh wait` until verified one-word no-submit insertion exits `0`. Only count Ghostty when the detached run exits `0`. |
| Onboarding | 70/100 | Documented manual gate: `docs/product/onboarding-permission-qa-checklist.md`. `./script/onboarding_walkthrough_evidence_helper_self_test.sh`: passed for the redacted before-delete/after-delete evidence helper, including fail-closed checks that the TextEdit practice-start event has `model=ready`, `textEditEnabled=true`, and `globalPaused=false`. `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready`: failed on the current local logs because no `textedit-practice-started` event exists, even though older TextEdit Tab, Esc, pause, and trace events exist; this proves the helper will not assemble a false walkthrough from scattered old sessions or from a practice start where the model was not ready, TextEdit was disabled, or suggestions were globally paused. `./script/check_onboarding_walkthrough_proof_self_test.sh`: passed for the fail-closed guided TextEdit proof validator, and the template now prints the helper commands plus `./script/build_and_run.sh --verify`, diagnostics paths, and trace log paths before recording. `./script/check_onboarding_walkthrough_proof.py`: failed because no completed passing walkthrough proof row exists yet; row 1 is still Pending. `./script/check_onboarding_permission_qa.sh --check`: failed with 48 unchecked items and 3 Pending proof rows after adding the helper step to the checklist. | The first-run path is documented and now has executable pre-delete and post-delete evidence checks for Accessibility, app-owned runtime readiness, TextEdit enabled, suggestions unpaused, TextEdit practice, Tab, Esc, pause, and trace deletion, but the checklist still has no real clean-user tester-walkthrough row. | Record one guided TextEdit practice run in `docs/product/onboarding-permission-qa-checklist.md` using `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready` before Delete Local Logs and `./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready` after deletion, then rerun `./script/check_onboarding_walkthrough_proof.py` and `./script/beta_readiness.sh --check-only`. |
| Controls | 84/100 | `./script/check_controls_diagnostics_readiness.sh`: Settings, Diagnostics, pause scheduling, disabled-app selection, raw-trace expiry, redacted export, privacy export proof, diagnostics log self-test, and local trace deletion all passed. `script/delete_local_traces.sh` now removes `diagnostics.log` too. | Pause/delete/export controls now have better automated parity proof, but the latest score run still does not include a human walkthrough across every visible surface. | Run a documented manual gate that toggles pause, disabled apps, trace delete, and redacted export from Settings, menu bar, and Diagnostics. |
| Diagnostics | 92/100 | `./script/check_controls_diagnostics_readiness.sh`: Diagnostics state tests, RawTraceReportExport tests, diagnostics log self-test, redacted report export, and current-build privacy export proof passed. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `e2da385b0ece`, so the beta-safe manual proof rows now have current diagnostics and trace slices. `./script/beta_readiness.sh --check-only`: runtime production gate OK and redacted report export OK. | Diagnostics are healthy for local beta work, but onboarding walkthrough and packaged-app Accessibility recovery proof are not complete. | Rerun `./script/check_diagnostics_log.sh`, `./script/check_current_build_privacy_export.sh`, and `./script/manual_smoke_status.sh --strict` after the next app/source change. |
| Model readiness | 94/100 | `./script/check_model_asset.py --quiet`: Qwen3.5 4B MLX verified at revision `32f3e8ecf65426fc3306969496342d504bfa13f3` with `.steadytype-model-integrity.json`. `./script/package_release.sh --check --require-developer-id --require-notary-profile`: Preferred MLX model ready. `./script/check_model_asset_self_test.sh`: passed and proves checksum-skip env no longer bypasses known-good file checks. `./script/download_mlx_model_self_test.sh`: passed and checks immutable revision validation. `swift test --jobs 1 --filter 'AppModelRuntimeFactoryTests|ModelAssetInstallerTests|LocalModelAssetInstallerTests|RuntimePolicyTests'`: 48 tests passed, including immutable 40-character commit revision requirements, absent/tampered integrity receipt rejection, checksum mismatch, duplicate, unsafe path, absent referenced file, extra file, and byte-count mismatch coverage. | The app-owned model path and integrity receipt checks are strong, but beta trust still depends on onboarding and distribution proof. | Keep `./script/check_model_asset.py` green, then rerun `./script/beta_readiness.sh --check-only` after onboarding proof and the primary beta DMG exist. |
| Beta readiness | 80/100 | `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`: created a current Developer ID signed `dist/SteadyType.dmg` and `dist/SteadyType.zip` after the default parallel release build died during compile. `./script/package_release.sh --notarize`: Apple notarization accepted submission `bf39ea78-ed19-4a74-95ba-714ed6c474b6`, stapled the DMG, verified Gatekeeper, and refreshed the secondary ZIP. The current `./script/beta_readiness.sh --check-only` run uses the bounded prompt manifest gate instead of the whole historical trace: model asset, runtime production gate, release-signed runtime no-egress proof, controls/diagnostics, redacted export, issue template validation, clipboard fallback disabled, production mock fallback disabled, prompt app manifest proof, visual placement proof, release package prerequisites, Developer ID DMG/archive signature, notarized install proof, and private beta packet passed. The same run found 3 real blockers: no onboarding walkthrough proof, onboarding permission QA with 48 unchecked items and 3 proof rows waiting for a clean-user run, and no eligible packaged latency launch until Accessibility is granted for the notarized app. The strict manual app proof has since been refreshed on the current build. `./script/packaged_latency_proof_self_test.sh`: passed and keeps the TextEdit packaged-latency rerun path one command. | Onboarding proof and packaged Accessibility latency still need current human runs before testers should get the build. | Grant Accessibility to the notarized app for packaged latency, then record onboarding proof / complete the onboarding checklist and rerun `./script/beta_readiness.sh --check-only`. |
| Test/proof coverage | 85/100 | `swift test --jobs 1`: 1508 tests passed after instant fast-phrase-to-model refinement, model-failure visible fallback preservation, and Ghostty insertion diagnostics changes. `swift test --jobs 1 --filter ClaudeCodeTerminalHostProofPolicyTests`: 90 tests passed after the paced Command-V/session-paste proof change. Focused Swift suites for keyboard capture/safety, synthetic caret placement, Chrome same-text split preservation, Codex proof geometry, and Obsidian insertion retry all passed in the current proof set. `./script/real_app_smoke_self_test.sh`: passed after adding bounded log-slice scanning, fast Ghostty focus reassertion, insertion-rung ordering, timeout fail-closed guards, stdin-only helper input, safe apostrophes, unsupported-scalar diagnostics, hardware key-event ordering checks, bulk and paced per-character System Events checks, shell-launched System Events checks, System Events foregrounding checks, native paste-action checks, in-process native input checks, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification checks, paced Command-V checks, nonblocking session miss handoff, terminal-ready Ghostty launch checks, the Ghostty AppleScript preflight hard-fail, and the `new-window-created` launch-stall classifier. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner's help, dry-run, status, tail, `nohup` launch path, stop-mode guardrails, and no raw custom proof-text persistence checks. `swift build --product SteadyType`: passed after adding separate native-prefix verification. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `e2da385b0ece` for all 10 beta-safe writing rows. Direct `AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate`: failed closed after finding a prompt-row suggestion at diagnostics line `800174`, posting the new `ghosttyInProcessInputText` rung at line `800768`, verifying the unchanged baseline at line `800769`, and failing closed at line `800816` with `keyboard-action handled=false reason=insert-failed`. `./script/claude_code_ghostty_detached_proof.sh start` plus `./script/claude_code_ghostty_detached_proof.sh wait`: `20260528T025919Z-ghostty` found a prompt-row suggestion at diagnostics line `818560`, captured Tab, ran targeted paste, opt-in session-tap paste, global paste, native Ghostty, System Events, hardware, bundled-helper, and Unicode rungs, then failed closed with `ghosttyFastFailClosed` plus `keyboard-action handled=false reason=insert-failed` at lines `819271` / `819273`. The default follow-up `20260528T030442Z-ghostty` found the prompt-row suggestion at diagnostics line `821100`, consumed Tab at `821919`, skipped the session probe at `821948`, kept pasteboard baselines unchanged, and failed closed at `821995` / `821997`. The bounded follow-up `20260528T031735Z-ghostty` accepted the next-word proof at line `823023`, logged `ghosttyFastInsertionBudget` at line `823052` with `elapsedMilliseconds=9886` and `budgetMilliseconds=8000`, then failed closed at lines `823053` / `823055` before slower exploratory rungs. `20260528T033921Z-ghostty` proved opt-in env propagation into the detached app and reached `ghosttyNativePrefixFinalKeyText`, but the prompt stayed unchanged at lines `825141` / `825142`; `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared after one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at `832488` / `832489` with handled-false Tab at `832491`. The current detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. The follow-up `20260528T074034Z-ghostty` records `preflight-version:1.3.1` and reaches `new-window-start`, then fails before `new-window-created` or a Claude pidfile, proving the current blocker moved from preflight to Ghostty disposable window creation. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after the prompt gate gained an explicit full-accept no-submit proof mode while still requiring `prompt no-submit confirmed` for every normal prompt-app proof claim. `./script/check_prompt_app_manifest_proof.sh`: passed for the Codex bounded prompt slice. `./script/beta_readiness_self_test.sh` now proves beta readiness uses that bounded manifest gate instead of scanning old prompt trace history, and the current `./script/beta_readiness.sh --check-only` run shows the prompt app manifest proof gate passing. `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/claude_code_ghostty_detached_proof.sh script/claude_code_ghostty_detached_proof_self_test.sh script/beta_readiness.sh script/beta_readiness_self_test.sh script/check_prompt_app_manifest_proof.sh script/check_prompt_app_proof.sh`, `./script/check_test_coverage_manifest.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/check_steadytype_scorecard.py --live`, `AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=5 ./script/build_and_run.sh --verify`, `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/beta_readiness.sh --check-only`, and `git diff --check`: passed or failed only on the known human proof gates. Earlier proof includes `./script/private_beta_packet.sh --check`, runtime no-egress validation, visual placement evidence validation, prompt proof validation, and focused model-integrity tests. | The proof loop now covers current beta-safe writing lanes, Obsidian run-on, Obsidian font-zoom, Obsidian Markdown-list, Obsidian Markdown-bold, Obsidian multiline, Codex one-word no-submit, Chrome same-text split persistence, virtual-host suggestion preservation, release-signed no-egress proof, Developer ID signed/notarized beta artifacts, private beta packet regeneration, Ghostty fail-closed prompt-row placement trust, Ghostty prompt-row suggestion evidence, Ghostty Tab delivery into the expanded insertion ladder when launch succeeds, detached proof cleanup safety, terminal-ready Ghostty launch failure proof, Ghostty AppleScript preflight repair proof, prompt proof bounded to manifest slices, and a detached Ghostty proof runner. Onboarding, Ghostty verified insertion proof, and packaged Accessibility latency proof are the named non-green proof lanes. Proof-only prompt/chat/terminal/browser-production lanes do not count as beta-safe support without live host proof. | Keep `./script/check_steadytype_scorecard.py --live`, `./script/check_prompt_app_manifest_proof.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/claude_code_ghostty_detached_proof.sh start && ./script/claude_code_ghostty_detached_proof.sh wait`, `./script/packaged_latency_proof.sh textedit-model-latency`, `./script/private_beta_packet.sh --check`, and `./script/beta_readiness.sh --check-only` in the loop. |

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
