# SteadyType Product Scorecard

Updated: 2026-05-28 America/Chicago.
Base app/source evidence checked through the current score-loop commits.
Latest beta gate evidence checked with `./script/beta_readiness.sh --check-only`, `./script/manual_smoke_status.sh --strict`, `./script/check_runtime_network_egress.py --validate-proof`, `./script/select_latency_window.py`, `./script/private_beta_packet.sh --check`, `./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/package_release.sh --check --require-developer-id --require-notary-profile`, `./script/check_prompt_app_manifest_proof.sh`, the guided TextEdit walkthrough proof gate self-test, fresh beta-safe app proof, current TextEdit model-latency proof, retired Claude desktop model-latency proof lane, packaged TextEdit model-latency proof wrapper, runtime no-egress freshness gating, Claude Code terminal-host insertion source proof, detached Ghostty launchd/nohup proof failure evidence, direct Ghostty command-open prompt-readiness evidence, detached Ghostty proof runner self-test, focused daily-driver activation/trigger Swift tests, full Swift test, focused model-integrity Swift tests, current Obsidian run-on proof, current Obsidian font-zoom proof, current Obsidian Markdown-list proof, current Obsidian Markdown-bold proof, current Obsidian multiline proof, current Codex one-word/full-accept no-submit proof, current Chrome textarea/contenteditable split-persistence proof, and the latest strict manual smoke status passing on the current build.
Overall score: 86/100.

This is the single current product scorecard. Older scorecards are historical
inputs only. Do not raise a score unless the evidence in the row changes.
Stale proof can explain progress, but it cannot make a row green.

Strict manual smoke is green again after the latest proof refresh. Targeted
reruns prove the manual app proof, runtime no-egress proof, and private beta
packet blockers are gone; the umbrella beta readiness run is still blocked by
the remaining human onboarding and packaged Accessibility gates.
`./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit
`1969992ddcf5`. TextEdit, Notes title/body/checklist, Obsidian
default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable all
have current or source-compatible rows with 2 accepted insertions and strict
visual trace evidence. The refreshed rows include TextEdit diagnostics lines
`952925`-`953019`, Notes checklist lines `954328`-`954420`, Obsidian
default/theme/pane/long-note lines `954425`-`955313`, Chrome textarea lines
`953772`-`953982`, and Chrome contenteditable lines `953989`-`954228`.

Current Codex prompt full-accept evidence is green for the exact proven default
composer. `./script/check_prompt_app_manifest_proof.sh` now passes with two
bounded prompt slices: default one-word Tab no-submit at traces lines
`31519`-`31530`, and full-accept no-submit at traces lines `31585`-`31599`.
Full accept stays limited to the proven Codex default composer; other prompt,
chat, terminal, and hosted browser surfaces remain proof-gated.

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
current SteadyType app bundle. The newest red evidence keeps the score flat:
`20260528T185115Z-ghostty` disabled deferred insertion and still failed the
same unchanged-prompt ladder, while `20260528T191017Z-ghostty` rebuilt the app,
found a prompt-row suggestion at diagnostics line `1002533`, consumed Tab at
`19:14:13Z`, and posted
`ghosttyPrePromptFocusBundleSystemEventsRawKeystroke` with
`keyboardTapStopped=false` at `19:14:16Z`; it verified `false`, its unchanged
baseline verified `true`, and the ladder failed closed at `19:14:43Z` after
`ghosttyInitialNoopClusterBaseline verified=true`. That rules out deferred
timing, prompt-click timing, and event-tap stopping as cheap fixes. The proof
harness now has an opt-in post-Tab/pre-insert external mutability comparator
for the next run, using an explicitly longer deferred insertion delay to test
whether Tab capture itself poisons the prompt before SteadyType insertion starts.
The immediate follow-up `20260528T192014Z-ghostty` failed before prompt
readiness with `textNodes=0`, `markerWindows=0`, and no marker, so it does not
count as insertion evidence. A direct command-open probe,
`20260528T192514Z-ghostty`, proved the dirty-prompt fallback still works:
attempt one detected launch-command text, attempt two reached a prompt-row
suggestion at diagnostics line `1009314`, and both native and System Events
pre-accept mutation probes verified and restored prompt mutation before
app-owned insertion. That run then lost the visible suggestion during Tab
injection and received SIGTERM while retrying under the nohup launcher, so
nohup is back to an explicit fallback and the detached proof defaults to
launchd for long-running evidence. The launchd comparator run
`20260528T193340Z-ghostty` used the new post-Tab/pre-insert mutation probe and
the 3s deferred insertion delay, but it failed before Tab or comparator
sampling: both disposable attempts exposed `textNodes=0`, `markerWindows=0`,
and no marker. That keeps the next proof lane split in two: first make the
script-owned/no-restore launch reliably reach the prompt row, then rerun the
post-Tab comparator before changing the insertion ladder again. Detached runs
now persist each disposable `claude.pid`, `claude.exit`, and
`ghostty-launch.log` under the run directory's `proof-artifacts/` folder. The
rerun `20260528T194141Z-ghostty` proved those artifacts survive cleanup for two
disposable contexts and captured the launch stages through
`configured-window-created`, `script-wrote-pidfile`, `script-starting-claude`,
and `shell-delay-finished`; the proof still failed before Tab with
`textNodes=0`, `markerWindows=0`, and no marker, so the next blocker is prompt
AX readiness after a shell-started Claude process, not missing launch-stage
evidence. The patched follow-up `20260528T194828Z-ghostty` removed one more
harness ambiguity: both attempts recorded `terminal-ready`,
`terminal-working-directory-empty`, `title-marked`, and
`configured-window-command-owned-launch` with no duplicate `launch-action-start`,
so the configured Ghostty window owns command execution and the harness no
longer types the launch command a second time. That run still failed before Tab
with `textNodes=0`, `titles=0`, `markerWindows=0`, and `marker=false`, so the
next blocker is Ghostty prompt AX discovery after clean configured-window
command launch, before rerunning the post-Tab comparator or changing insertion
again.
The newest launchd proofs moved that blocker forward but still keep Ghostty red:
`20260528T200606Z-ghostty` and `20260528T201412Z-ghostty` accepted native
title-scoped screen-copy readiness after AX exposed `textNodes=0`, proved exact
typed prompt readiness, and verified native Ghostty pre-accept prompt mutation
and restore before app-owned insertion. Both reached prompt-row suggestions, but
CGEvent Tab produced no `key=tab` diagnostic, the System Events fallback did not
produce an immediate Tab diagnostic, and the visible suggestion disappeared
before app-owned insertion could run. The third run then received SIGTERM during
the second native pre-accept probe, so the harness now records the active
Claude Code prompt/Tab/insertion phase on SIGTERM instead of reporting the stale
build phase. The next Ghostty lane is an observable accept driver for the
prompt-row suggestion, not configured-window launch or AX prompt discovery.
The post-commit one-attempt launchd proof `20260528T202618Z-ghostty` exited
cleanly with status `1` and confirmed the new accept-driver diagnosis: prompt
screen-copy readiness, exact typed prompt readiness, and native pre-accept
mutation/restore all passed; session CGEvent Tab, HID CGEvent Tab, and System
Events Tab all produced no `key=tab` diagnostic; the run failed with
`Tab delivery did not reach key capture`.
The follow-up `20260528T203530Z-ghostty` added a non-mutating key-capture
sentinel before Tab. It reached a prompt-row suggestion at diagnostics line
`1029172` with key capture started at line `1029158`, then session CGEvent
Shift and HID CGEvent Shift both produced no `keyboard-event-tap-latency`
diagnostic with `key=other`. The proof now fails before Tab with
`key capture probe did not reach event tap`, so the next Ghostty work is a
detached-runner key source that reaches the SteadyType event tap at all.
The latest bounded launchd proof `20260528T210138Z-ghostty` keeps that as the
active blocker and adds a sharper diagnostic: macOS Accessibility/System
Settings can steal focus during the key-probe window, so future runs classify
that permission-UI focus steal separately from a plain no-diagnostic key miss.
Follow-up run `20260528T210954Z-ghostty` kept the proof bounded and reached the
same prompt-row key-probe miss; the classifier now waits briefly for late
focus-change diagnostics before printing the final reason.
`20260528T211636Z-ghostty` confirmed the same bounded path and late System
Settings focus-change timing, so the final post-suggestion failure aggregator
now also rewrites the final reason when permission UI is the real focus thief.
The default detached probe now skips System Events Shift because it can trigger
macOS permission UI and steal focus; use
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1` only
for an explicit permission-risk key-source experiment.
Live run `20260528T213048Z-ghostty` proved the new default path: it reached a
prompt-row suggestion, tried session HID, HID-tap, and combined-session CGEvent
Shift probes, skipped System Events Shift with the default opt-out env, and
failed cleanly with `key capture probe did not reach event tap`.
The next source delta adds a PID-targeted CGEvent Shift helper mode against the
exact frontmost title-marked Ghostty proof process, so the next detached proof
can rule in or rule out one more permission-safe key source before any System
Events opt-in.
Live run `20260528T214421Z-ghostty` ruled it out twice: attempts 1 and 2 reached
prompt-row suggestions, targeted Ghostty pids `57277` and `91391`, missed the
event tap, and skipped System Events with the default opt-out env. The run was
stopped after it continued into extra disposable contexts; the detached wrapper
now defaults `AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1` so the next
key-source proof exits after one clean red sample unless explicitly overridden.
The follow-up source slice adds process-id breadcrumbs to the app-side
`keyboard-event-tap-latency` diagnostics when macOS exposes them:
`eventSourcePID` and `eventTargetPID`. This does not make Ghostty green because
the current synthetic Ghostty key sources still do not reach the event tap, but
it will make the next observed key-capture sample distinguish helper-origin,
target-process, and user-key paths without logging typed text.
The next harness slice adds private-state CGEvent Shift and Tab rungs after the
session/HID/combined/PID probes and before the System Events opt-in path. This
keeps the default Ghostty proof permission-safe while ruling out one more local
synthetic key source that might reach SteadyType's event tap.
Live run `20260528T221035Z-ghostty` did not reach those new rungs: it got
through native screen-copy prompt readiness, typed-prompt readiness, and native
pre-accept mutation/restore, then received SIGTERM while waiting for the
suggestion on attempt 1. Cleanup stopped both the proof Ghostty pid and the
proof command pid. The wrapper now prints periodic wait progress and the
key-capture refocus path has an explicit timeout knob, so future long detached
runs should explain their current phase instead of going quiet.
The next harness hardening keeps the optional `nohup` detached launcher out of
the Codex app-server process group by starting the runner through Python with
`start_new_session=True`. This does not count as Ghostty support, but it removes
one more false-red source when comparing launchd and nohup evidence: a nohup
proof should now live or die by the proof script, not by the shell that invoked
it.
The pre-accept mutability comparator now restores native Ghostty mutations with
Ghostty-native clear-and-input instead of a one-character System Events
backspace. That keeps the prompt restore proportional to the whole proof text
after native probes, reducing false red runs where native Ghostty input mutates
the prompt but the cleanup path cannot restore the original prompt.
Ghostty fresh disposable contexts now skip the initial prompt clear by default;
the exact typed-prompt readiness check remains the dirty-state guard. This
removes another focus-sensitive key path before the proof text is typed while
still failing closed if stale prompt content is present.
Typed Ghostty prompt readiness can now use the native screen-copy path even when
the AX helper reports text nodes, as long as the exact typed proof text is being
checked. That keeps the fallback from being limited to complete AX misses while
still requiring an exact prompt match before the proof can advance.
The latest detached-runner slice removes the extra job-control smoke child shell
and launches `real_app_smoke.sh` as the direct child process through `exec env`.
`20260528T222807Z-ghostty` was generated before that patch and got as far as
typed-prompt readiness, but it still reported through the old child-shell
wrapper after native, bulk System Events, and paced System Events prompt typing
were incomplete. `20260528T223417Z-ghostty` used the direct-child runner and no
longer emitted any smoke-child-shell diagnostics; the real smoke process itself
received SIGTERM during `claude-code Ghostty open fresh disposable context`
after the stale-only host check and before prompt readiness. Ghostty is still
red, but the next blocker is now the disposable open lifecycle or external TERM
source, not detached wrapper ambiguity.
The TERM handler now prints the smoke pid, parent, process group, session,
guard pids, tracked Claude Code terminal proof pids, lock owner, process-group
members, and proof-related process rows before cleanup. The next red run should
name whether the signal is coming from proof cleanup, wrapper/session teardown,
or a separate watcher.
The current
insertion pass adds two verified
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

The latest Ghostty transport slice rules out a separate bundled-helper
AppleScript identity without broadening support. `SteadyTypeTextEventHelper`
now has a proof-scoped `--ghostty-input-text` mode that keeps accepted text on
stdin, requires the exact Ghostty PID and proof title markers, and exits
fail-closed on missing proof context. `20260528T162233Z-ghostty` rebuilt the app,
reached a prompt-row suggestion at diagnostics line `951482`, reasserted the
exact Ghostty PID at line `952563`, ran `bundledGhosttyInputTextHelper` at line
`952565`, verified `false`, proved the original prompt unchanged at line
`952566`, and failed closed at `ghostty-initial-insertion-noop-cluster` on lines
`952578`-`952581`. Because it is a proven no-op, the helper remains opt-in behind
`AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE=1`; the default fast
path does not spend extra time on it. Ghostty remains unsupported until a
different app-owned insertion architecture mutates and verifies the disposable
Claude prompt.

The current fail-fast follow-up moved Ghostty's native paste action into the
initial no-op cluster before generic Command-V and in-process native-input
fallbacks. `20260528T172019Z-ghostty` first proved that ordering on the patched
build; the cleaner follow-up `20260528T172507Z-ghostty` rebuilt the app, reached
a prompt-row suggestion at diagnostics line `960450`, handled Tab, recorded
`ghosttyFocusedActionText` as `verified=false` with
`nativeNoopClassified=true` at lines `961342`-`961344`, then ran
`ghosttyPerformActionPasteFromClipboard` before generic pasteboard probes at
lines `961346`-`961347`. The prompt stayed unchanged through
`ghosttyInProcessInputText` at lines `961358`-`961361` and
`ghosttyFrontWindowInputText` at lines `961363`-`961364`, then failed closed at
`ghostty-initial-insertion-noop-cluster` on lines `961365`-`961367`. The
intervening `20260528T172055Z-ghostty` record was startup-only lock/TERM
evidence with exit `143`; the no-defer and extended-probe follow-ups
`20260528T172842Z-ghostty` and `20260528T172932Z-ghostty` also terminated during
startup before prompt-row insertion. None of those startup records count as
insertion proof. Ghostty remains unsupported until a detached proof exits `0`
with verified one-word no-submit insertion.

The current action-return pass makes those native Ghostty probes more honest:
SteadyType now preserves the AppleScript `perform action` boolean for focused
text action, native paste, and screen-copy verification instead of forcing a
successful post. `20260528T173408Z-ghostty` reached prompt-row suggestion line
`962043`, proved the native prefix/final-key probe did not mutate the prompt at
lines `962959`-`962962`, and failed closed at lines `962970`-`962972`. The
immediate rerun `20260528T174209Z-ghostty` confirmed the new metadata:
prompt-row suggestion line `963531`, `actionPerformed=true` on focused native
action text at lines `964428`-`964430`, native paste at lines
`964432`-`964433`, front-window input plus native screen-copy no-op at lines
`964449`-`964451`, and fail-closed insert lines `964452`-`964454`. App coverage
stays at `83` until Ghostty produces a verified one-word no-submit insertion.

The follow-up no-op trust pass made the default Ghostty fail-fast stricter:
focused native action, native paste action, and front-window native input must
now all carry Ghostty-native screen-copy no-op classification before the initial
cluster can fail closed. `20260528T175216Z-ghostty` reached prompt-row
suggestion line `965236`, retried Tab through System Events after CGEvent Tab
produced no key diagnostic, then recorded `nativeNoopClassified=true` for
focused native action at lines `966289`-`966291`, paste action screen-copy at
lines `966293`-`966295`, and front-window input screen-copy at lines
`966311`-`966313`. The stricter gate failed closed at lines `966314`-`966316`,
and the proof log's post-fail external native insertion probe still did not
verify prompt mutation. App coverage stays at `83`, but the red Ghostty decision
is now backed by multiple Ghostty-native screen reads.

The current harness comparator now tests whether the same failed context is
still externally mutable after app-owned insertion fails closed. `20260528T180004Z-ghostty`
reached prompt-row suggestion line `967039`, repeated the classified no-op proof
for focused action at lines `967919`-`967921`, paste action at lines
`967923`-`967925`, and front-window input at lines `967941`-`967943`, then
failed closed at lines `967944`-`967946`. The post-fail comparator typed one
native Ghostty suffix and one System Events suffix without Enter; neither
verified prompt mutation. App coverage stays at `83`, and the next blocker is
now sharper: prove why the disposable Ghostty prompt stops accepting external
text after the fail-closed insertion cluster, or avoid entering that state with
a different insertion architecture.

The follow-up comparator removed the simple focus explanation and proved the
before/after split. `20260528T181801Z-ghostty` first typed one external native
Ghostty suffix and one external System Events suffix before Tab; both mutated
the prompt and restored the original text. The same run then reached prompt-row
suggestion line `975159`, failed closed after Tab, typed one external native
suffix without Enter, clicked the latest terminal-screen prompt caret at
`x=633 y=723`, then typed one external System Events suffix without Enter.
Neither post-fail external path verified prompt mutation after the prompt-row
refocus. App coverage stays at `83`; Ghostty is still unsupported until a
detached proof exits `0` with verified one-word no-submit insertion.

The newest proof-only transport pass ruled out one more likely Ghostty path
without raising the score. The detached proof lane now forwards an opt-in flag
so SteadyType tries a smoke-equivalent frontmost bundle System Events raw
keystroke before the exact-PID focused System Events rung, while normal app
launches skip that unproven rung.
`20260528T183440Z-ghostty` found prompt-row suggestions on two disposable
contexts; attempt 1 lost the visible suggestion during Tab injection, and attempt
2 consumed Tab at diagnostics line `989460`, clicked the prompt-row caret at
line `989486`, then posted `ghosttyBundleSystemEventsRawKeystroke` at line
`989490`. That new rung exited `0` but verified `false`, its unchanged-prompt
baseline verified `true` at line `989491`, focused System Events stayed false at
lines `989493`-`989494`, send-key stayed false at lines `989496`-`989497`, and
the proof failed closed at lines `989529`-`989532`. The pre-accept external
native/System Events probes still mutated and restored the prompt, while the
post-fail external probes did not mutate after prompt-row refocus. App coverage
stays at `83`; Ghostty is still unsupported until a detached proof exits `0`
with verified one-word no-submit insertion.

The latest Ghostty comparator added one more negative proof without changing the
score. `20260528T185553Z-ghostty` ran with
`AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=1`
and reached deferred Tab accept on attempt 2. Before the prompt-row click,
SteadyType posted `ghosttyPrePromptFocusBundleSystemEventsRawKeystroke` at
diagnostics line `999928`; it exited `0` but verified `false`, and the
unchanged-prompt baseline verified `true` at line `999929`. The regular
prompt-click raw System Events rung, focused System Events, send-key, pasteboard,
and native Ghostty follow-ups also no-oped against the same original prompt, and
the proof failed closed at lines `999973`-`999976`. App coverage stays at `83`;
Ghostty is still unsupported until a detached proof exits `0` with verified
one-word no-submit insertion.

The current Ghostty prompt-readiness pass moves the red bar again, but still
does not broaden support. The harness now uses Ghostty native
`write_screen_file:copy,plain` as a pasteboard-restoring fallback when AX prompt
discovery returns `textNodes=0`, allows safe macOS temp screen-file paths,
rejects launcher-command scrollback, logs only redacted shape metadata, and
requires the expected prompt text for typed prompt proof. The Ghostty launch path
also starts Claude with `--permission-mode plan`, returns immediately after a
successful native clear, leaves System Events clear opt-in, and bounds raw
System Events typing probes. Live run `20260528T201412Z-ghostty` proved empty
and typed prompt readiness through native screen copy, then verified and
restored a pre-accept native Ghostty prompt mutation. It still did not prove
accept: CGEvent Tab produced no `key=tab` diagnostic, System Events Tab produced
no immediate `key=tab`, the visible suggestion was lost during Tab injection,
and the detached retry loop was stopped after the second disposable context
began. Follow-up launchd run `20260528T203530Z-ghostty` reached prompt-row
suggestion evidence again, but a non-mutating Shift sentinel did not reach
SteadyType's event tap through either session or HID CGEvents, so the harness
failed before Tab with `key capture probe did not reach event tap`. The key
source probe now also tries combined-session CGEvents and guarded System Events
Shift only when explicitly opted in before Tab, and the detached wrapper
forwards those probe knobs. Launcher
comparison run `20260528T204242Z-ghostty` used `nohup`, reached prompt typing,
verified a pre-accept native Ghostty mutation, then failed because it could not
restore the original prompt before suggestion proof. Post-patch launchd run
`20260528T204741Z-ghostty` forwarded the new key-capture env into detached
status, then was SIGTERMed during startup before build or prompt setup, so it is
not support evidence. Follow-up run `20260528T204810Z-ghostty` reached native
screen-copy prompt readiness, restored the pre-accept native Ghostty mutation,
then showed the pre-accept System Events comparator did not mutate the prompt
before the run was stopped. That exposed a detached cleanup gap: `stop` could
leave the proof-owned Ghostty/Claude context alive, so the wrapper now cleans
context pids from `claude.pid` and the proof-owned Ghostty pid in `proof.log`.
The Ghostty pre-accept comparator now also wraps quiet prompt-readiness checks in
an outer timeout guard so a no-op System Events probe cannot wedge the detached
run while proving the prompt stayed unchanged. App coverage stays at `83`; the
next Ghostty blocker is observable key delivery into SteadyType's event tap
under a detached runner, not prompt AX discovery.
The next launchd pass, `20260528T210138Z-ghostty`, kept that diagnosis current:
native Ghostty text mutated and restored the proof prompt, System Events did not
mutate it, a prompt-row suggestion appeared, and every non-mutating key-capture
sentinel missed the event tap. Diagnostics also showed macOS
Accessibility/System Settings stealing focus during that key probe window, so
the harness now classifies that permission-UI focus steal explicitly. Follow-up
run `20260528T210954Z-ghostty` stayed bounded and again reached a prompt-row
suggestion, then showed the System Settings focus-change line can flush just
after the generic key-capture miss; the classifier now waits briefly after the
probe so that focus-steal evidence is not missed.
Latest run `20260528T211636Z-ghostty` confirmed the same bounded prompt-row
suggestion and late System Settings focus-change timing; the final
post-suggestion failure aggregator now also waits briefly and rewrites the final
reason when permission UI is the real focus thief. The follow-up harness guard
now makes the System Events Shift key-capture probe opt-in with
`AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1`;
default Ghostty proof runs stop after the session/HID/combined-session and
PID-targeted CGEvent sentinels miss the event tap, report `key capture probe did
not reach event tap`, and refresh the disposable prompt instead of triggering
macOS permission UI by default.
The detached Ghostty wrapper now also forwards the foreground smoke path's
key-capture focus-steal wait plus session/HID/fallback Tab probe windows. That
keeps future long-running detached proof experiments tunable from one command
instead of silently using foreground-only defaults. It also defaults
`AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1`, after
`20260528T214421Z-ghostty` showed repeated disposable contexts can spend minutes
reconfirming the same key-source miss.
Follow-up run `20260528T222807Z-ghostty` exposed a harness-only typed-prompt
red bar before it could retest the key source: SteadyType's terminal prompt
anchor repeatedly saw the full 42-character proof prompt and placed the
synthetic caret, but the AX readiness helper still treated the prompt as
incomplete because the native screen-copy fallback only ran for `textNodes=0`
failures. Typed Ghostty prompt readiness now lets a title-scoped native
`write_screen_file:copy,plain` proof certify the exact stripped prompt text on
any AX failure, while the empty-prompt path still requires the older
`textNodes=0` guard. `./script/real_app_smoke_self_test.sh` and
`./script/claude_code_ghostty_detached_proof_self_test.sh` pass for the new
guard. App coverage stays at `83`; the next live proof should rerun the bounded
detached Ghostty lane and should fail or pass on suggestion/key delivery rather
than on a false typed-prompt readiness miss.

Latest daily-driver source delta: `swift test --jobs 1 --filter
CommonPhraseContinuationPredictorTests` passed on 2026-05-28 after expanding
the instant writing bridge layer with safe writing-surface continuations such
as `The problem is` -> `where the current flow breaks`, `What I need is` ->
`a clearer next step`, `I'm trying to figure out` -> `what needs to happen
next`, `It would be useful if` -> `this showed up at the right time`, and
`The reason this matters is` -> `what it changes for the user`; email,
casual-chat, prompt, search, form, and code profiles stay gated out of that
broader writing fallback path.

Latest Obsidian source delta: `swift test --jobs 1 --filter
'CommonPhraseContinuationPredictorTests|SuggestionAggressivenessTests'` passed
on 2026-05-28 after extending the instant markdown-label predictor for common
project-note labels such as `Summary:`, `Context:`, `Next action:`,
`Evidence:`, `Follow-up:`, and `Open loops:`. The Obsidian daily-driver trigger
path now also requests phrase continuations for one-word note labels like
`Context:` when the daily-driver line-start opt-in is active, while non-Obsidian
defaults stay quiet there.

Latest dogfood-report source delta: `./script/daily_driver_dogfood_session_self_test.sh`
passes after the sample gate started printing redacted instant phrase
match-family counts such as writing-bridge, markdown, reply, sentence-boundary,
daily-driver, and prior, without exposing `predictivePhraseMatch` text.

Latest Obsidian proof-harness source delta:
`script/obsidian_ax_editor.swift` now prints a redacted AX snapshot when it
cannot resolve the focused editor, including window count, text-entry count,
visited-node count, and role counts only. `./script/real_app_smoke_self_test.sh`
guards the diagnostic and renderer-accessibility guidance, so Obsidian
AX misses are actionable without leaking note text.

Latest manual proof refresh: `script/manual_proof_refresh.sh --verify-target
textedit`, `notes-title`, `chrome-textarea`, `chrome-contenteditable`, and
`obsidian-long-note` passed on 2026-05-28, and the proof sweep added current
Notes body/checklist plus Obsidian default/theme/pane rows. The beta-safe proof
grid is current again: TextEdit, Notes title/body/checklist, Chrome
textarea/contenteditable, and Obsidian default/theme/pane/long-note all have
strict visual rows with two verified accepts.

## Scores

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Suggestion quality | 95/100 | `./script/check_quality_eval.sh`: completion quality, word-completion quality, offline-model quality, and the deterministic 500-case completion-prediction suite all passed on 2026-05-28 after the generic-filler suppression, concrete suffix examples, 8-word default phrase posture, first-pass 3-8 word prompt label, and instant short-reply / thinking-flow predictors in `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`, `Sources/AutocompleteLabCore/Engine/CommonPhraseContinuationPredictor.swift`, `Sources/AutocompleteLabCore/Session/AutocompleteBehaviorProfile.swift`, `Sources/AutocompleteLabCore/Session/SuggestionAggressiveness.swift`, and `script/local_completion_runtime.py`. `./script/check_daily_driver_local_quality_audit_report.sh`: passed for `docs/evals/daily-driver-local-quality-audit-2026-05-25.md` with 45 disposable rows, 36 display-eligible rows, 9 expected suppression rows, 100/100 overall, 100/100 relevance, and no raw output persisted. `swift test --jobs 1 --filter SuggestionOrchestratorTests`: 36 tests passed after a shown 0ms phrase fallback stopped ending the request early; it now queues the model for refinement, stays visible during fast typing instead of being hidden by the model typing-burst gate, and remains visible if the follow-up model continuation fails for the same live request. `swift test --jobs 1 --filter CompletionPromptBuilderTests`: 33 tests passed after the primary default 8-word prompt started asking for `Next 3-8 words, or <NO_SUGGESTION>:` before retry instead of waiting for the short-candidate repair path. `swift test --jobs 1 --filter CommonPhraseContinuationPredictorTests`: 22 tests passed after the instant predictor added everyday writing bridge continuations such as "The problem is" -> "where the current flow breaks", "What I need is" -> "a clearer next step", "I'm trying to figure out" -> "what needs to happen next", "It would be useful if" -> "this showed up at the right time", and "The reason this matters is" -> "what it changes for the user", Obsidian/writing-flow continuations such as "One thing I noticed is" -> "that the flow breaks there", "What I know so far is" -> "the next step is clear", "The next pass should" -> "make the point clearer", "I am thinking about" -> "what needs to happen next", "What I actually want is" -> "the simplest version that works", "The thing I am worried about is" -> "where this breaks trust", "The next obvious move is" -> "to test it in context", project-note markdown label continuations such as "Summary:" -> "capture the useful version", "Context:" -> "what led to this note", "Next action:" -> "take the smallest useful step", "Evidence:" -> "link the current source of truth", "Follow-up:" -> "close the loop today", and "Open loops:" -> "name what still needs attention", daily-driver reach-test continuations such as "The difference is" -> "whether it feels magical", "This breaks trust when" -> "it appears in the wrong field", and "The reach test is" -> "whether i keep using it", field-safety trust continuations such as "If the focused field looks risky, it should" -> "fail closed before typing", "When the wrong field should" -> "stay silent until proof", and "If placement feels weird, it should" -> "stay quiet until proof", and guarded next-sentence boundary continuations such as "Suggestions feel too timid." / "Suggestions feel too timid. " -> "It should predict the next phrase", "Placement keeps showing in the wrong field." / "Placement keeps showing in the wrong field. " -> "That has to fail closed", and "Typing feels slow when suggestions lag." -> "Speed has to feel invisible" while keeping email, casual-chat, prompt, search, and code contexts off for the broader writing-bridge path. `swift test --jobs 1 --filter 'AutocompleteBehaviorProfileTests|CommonPhraseContinuationPredictorTests'`: 32 tests passed after the instant predictor added short messaging/email reply continuations such as "Sounds good" -> "to me", "Let me" -> "take a look", "Thanks for" -> "sending this over", while Messages and Telegram resolve to the casual-chat profile and prompt/search/form/code profiles remain off for that fallback path. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SuggestionTriggerPolicyTests|CompletionActivationPolicyTests'`: 61 tests passed after very-proactive writing surfaces started preferring phrase continuation for word fragments with enough context, requesting next-sentence phrase continuations at sentence boundaries, and allowing an Obsidian-only daily-driver line-start phrase path after one word while prompt surfaces keep the old quiet gate. `swift test --jobs 1 --filter 'SuggestionAggressivenessTests|SettingsWindowControllerStateTests|SuggestionOrchestratorTests|ModelPolicyTests|CommonPhraseContinuationPredictorTests'`: 102 tests passed after the default visible phrase cap moved to 8 words, old 3-word and 5-word defaults gained a version 6 migration, and the default cap now asks for 3-8 word phrase guidance. `./script/daily_driver_dogfood_session_self_test.sh`: passed after the redacted dogfood gate started reporting instant draft model follow-up results, model replacements shown, visible preservation after empty model results, per-outcome instant phrase counts, and instant phrase match-family counts. | Deterministic and disposable local-model quality proof is green, and the default tuning is less timid at sentence boundaries, natural period-plus-space boundaries, partial-word phrase starts, first-pass 3-8 word requests, guarded instant next-sentence phrases, common reply phrasing, common notes/Obsidian thinking-flow starts, project-note markdown labels, everyday writing bridges, reach-test complaint language, field-safety trust language, and instant-then-model phrase refinement, but this is still not broad live writing volume with real accepted-kept, typed-over, annoyance, and reach-for-it signals. | Run a real writing dogfood session, fill the Manual Trust Row, then gate it with `./script/daily_driver_dogfood_session.sh review --report <report>`. |
| Placement | 91/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `1969992ddcf5` for TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. The refreshed rows include strict visual trace evidence and 2 accepted insertions each, including TextEdit diagnostics lines 952925-953019, Notes checklist diagnostics lines 954328-954420, Obsidian default/theme/pane/long-note diagnostics lines 954425-955313, Chrome textarea diagnostics lines 953772-953982, and Chrome contenteditable diagnostics lines 953989-954228. Current-build Obsidian default proof refreshed on 2026-05-28T13:48:08Z at commit `707b7c95c614` with diagnostics lines 932538-932695 / traces lines 30739-30761, 2 accepted insertions, strict visual evidence, and a proof-vault launch that forces Electron renderer accessibility after default Obsidian 1.12.7 exposed only window chrome through AX. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c` with 2 accepted insertions after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-font-zoom --manual-gate`: passed on 2026-05-26T00:21:08Z at commit `73c85c56109b` with diagnostics lines 409510-409632 / traces lines 27370-27381, 2 accepted insertions, strict visual trace evidence, and restored Obsidian zoom. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z at commit `70cc9b29b59c` with diagnostics lines 410919-411071 / traces lines 27597-27618, 2 accepted insertions, strict visual trace evidence, and the suggestion staying on the dash-list row. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z at commit `1953b49a6e21` with diagnostics lines 413977-414128 / traces lines 28065-28085, 2 accepted insertions, strict visual evidence, and the caret repaired back to the bold line before the second suggestion. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-multiline --manual-gate`: passed on 2026-05-26T02:23:05Z at commit `db5bc6ffcd72` with diagnostics lines 414135-414268 / traces lines 28086-28099, 2 accepted insertions, and strict visual evidence on the lower multiline caret. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with diagnostics lines 574487-574600 / traces lines 28182-28188, 1 accepted insertion, strict visual trace evidence, and prompt no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed for the same Codex bounded prompt slice. | The 10 beta-safe writing lanes plus Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline variants and Codex one-word/full-accept no-submit proof are covered by recorded rows, but the claim is still intentionally narrow. Prompt apps remain proof-only, terminal hosts need current insertion-source proof, and production browser apps, hosted docs, and chat surfaces remain unclaimed. The Markdown-list full-accept pass uses the disposable proof-vault direct-value gate after a verified unchanged retry, so it does not broaden production Obsidian insertion claims by itself. | Keep `./script/check_prompt_app_manifest_proof.sh` green after each app/source change, and add more prompt-layout rows before broadening prompt/chat claims. |
| Tab safety | 88/100 | `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `1969992ddcf5`, with Tab/full-accept insertion proof across TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-run-on --manual-gate`: passed on 2026-05-25 at commit `747042be5c2c`; Tab accepted the next word and Option+Tab accepted the remaining visible phrase after Obsidian AX teleported to document start. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-list --manual-gate`: passed on 2026-05-26T00:59:47Z with Tab accepting `instant` inside a dash-list row instead of turning into indentation, then full accept verifying through the proof-vault retry path. `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh obsidian-markdown-bold --manual-gate`: passed on 2026-05-26T02:14:59Z with Tab and full accept staying in the bold Markdown line. `AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh codex --manual-gate`: passed on 2026-05-26T14:06:32Z with one-word Tab accept, strict visual evidence, and no-submit confirmed. `./script/check_prompt_app_manifest_proof.sh`: passed with prompt safety counters at 0. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after adding explicit full-accept no-submit proof mode with required manifest, smoke-row, accepted-event, and verified-insertion evidence. | Prompt/chat apps are not normal beta writing surfaces. Codex default-composer one-word and full-accept no-submit proof is recorded, but other prompt/chat apps stay off until exact no-submit proof exists, production browser apps stay unclaimed, and Markdown-list/full accept variants are still proof-vault lanes rather than broad Obsidian production guarantees. | Run `./script/check_prompt_app_manifest_proof.sh` after the next app/source change, then add more Codex prompt-layout proof before enabling broader prompt/chat support. |
| Latency | 80/100 | `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh textedit-model-latency`: passed on 2026-05-28 with 5 model-backed visible samples, first-visible `avg=253ms p95=258ms`, first-token `avg=228ms p95=233ms`, total generation `avg=252ms p95=293ms`, event-tap overhead `avg=40us p99=89us`, AX read summaries `p99Max=25ms max=25ms`, and zero late shown suggestions, event-tap failures, AX slow markers, or AX skips. executable-sha256=`bbf596398145cbf1b1ca4c639fedaa56f9cbc8a731ca2d447bc66bb7eae29e4d`; TextEdit strict selector `./script/select_latency_window.py`: selected diagnosticsLine=833735, traceStartLine=30421, firstVisibleSamples=5, modelSamples=5, fastWordVisibleSamples=0. `swift test --jobs 1 --filter TypingBurstPolicyTests`: 5 tests passed after the default fast-typing detector started catching roughly 70 wpm typing with 6 inserted characters inside 1.1 seconds while leaving word completion eligible. The Claude desktop latency lane is retired for now because its current task UI is not a safe prompt proof surface; the helper now refuses task/start buttons and only uses a safe chat composer. `./script/packaged_latency_proof_self_test.sh`: passed after the packaged proof wrapper default moved to the beta-safe TextEdit latency lane while keeping Claude as an explicit target. | Current dev-smoke latency is fast and model-backed in a beta-safe writing app, but the release-packaged app cannot collect current latency samples until Accessibility is granted for `bar.r3d.steadytype` after notarized install. | Grant Accessibility to the notarized `dist/SteadyType.app`, then rerun `./script/packaged_latency_proof.sh textedit-model-latency` and `./script/select_latency_window.py`. |
| Privacy | 95/100 | Latest targeted privacy checks: controls/diagnostics, redacted report export, current build privacy export proof, issue template, clipboard fallback disabled, prompt app proof gate, and prompt/chat safety counters passed after the privacy-export proof path stopped waiting on its own beta-readiness parent process. `./script/check_runtime_network_egress.py --phase autocomplete --duration 12 --interval 1 --activity-note "current runtime after beta-safe proof refresh" --proof-out docs/product/runtime-network-egress-latest.md --json-out docs/product/runtime-network-egress-latest.json`: passed on 2026-05-28T17:04:35Z with 13 samples and 0 remote endpoints, then `./script/check_runtime_network_egress.py --validate-proof docs/product/runtime-network-egress-latest.json --diagnostics-log /Users/redbars/Library/Logs/SteadyType/diagnostics.log --require-newer-than-latest-launch --max-proof-age-seconds 86400 --min-samples 10 --app-binary dist/SteadyType.app/Contents/MacOS/SteadyType` passed. `./script/check_sensitive_field_proof_self_test.sh`: passed after the gate expanded required suppressed categories and required browser-hosted suppression rows for Google Docs, Notion, ChatGPT, Slack, Discord, browser login/payment/password-manager/private-search/address-bar/developer-tool, and unproven browser pages. `swift test --jobs 1 --filter 'SensitiveTextFieldPolicyTests|BrowserHostedSurfacePolicyTests'`: 30 tests passed, including the expanded Chrome/Safari/Brave/Arc/Firefox/Chromium browser-hosted fail-closed policy. | Privacy export and runtime no-egress proof are healthy, but beta privacy still depends on the human onboarding walkthrough and packaged-app Accessibility recovery proof. | Rerun `./script/beta_readiness.sh --check-only` after onboarding proof and packaged-app Accessibility proof are complete. |
| App coverage | 83/100 | `./script/check_proof_manifest.sh --require-all`: passed with 7 complete surfaces, 20 profile coverage rows, 20 host policy rows, 12 graduation decision rows, and 24 verified trace slices. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `1969992ddcf5` for the 10 beta-safe writing rows. Current app proof also includes Obsidian run-on/font-zoom/Markdown-list/Markdown-bold/multiline, Codex one-word no-submit, Chrome textarea/contenteditable split persistence, and Claude Code terminal-host Terminal/iTerm2 one-word no-submit rows. The Ghostty branch now has prompt-row recovery, terminal prompt-row caret estimation, visible prompt-marker modeling, proof-only caret focus click, bounded diagnostics scanning, fresh-process detached proof retries, opt-in proof/probe-only host reset, exact-process focus reassertion, title-scoped fallback focus, terminal-ready launch gating, no-restore proof-owned host cleanup, no-child-process and configured-window launch classification, configured-window shell-readiness classification, timeout-bounded native Ghostty action/input/paste attempts, app-owned in-process native input, direct and shell-launched front-window native input, direct and shell-launched marker-scanned native input, terminal-scoped send-key/System Events paths, foregrounded direct and shell-launched bulk System Events probes, targeted and global hardware-key attempts, bundled/in-process Unicode helpers, pasteboard fallbacks, paced synthetic key events, an opt-in session-tap pasteboard probe, opt-in native-prefix/final-key probe env forwarding, separate prefix verification, and fail-closed gating before generic insertion. `20260527T203149Z-ghostty` found prompt-row suggestions, captured Tab on the fresh second context, tried foregrounded direct bulk System Events, shell-launched bulk System Events, per-character System Events, native Ghostty actions, terminal-scoped send key, hardware-key sources, bundled Unicode helpers, direct Unicode events, and pasteboard insertion, then failed closed because every app-owned insertion transport left the disposable prompt unchanged. `20260527T213259Z-ghostty` again reached hot Tab accept on a fresh prompt-row suggestion, ran the full ladder, proved targeted/global pasteboard misses left the prompt unchanged, queued clipboard restore, and failed closed instead of hanging after global paste. `20260528T025919Z-ghostty` reached prompt-row Tab accept, proved the opt-in session-tap paste miss at diagnostics lines `819221`-`819224`, continued through the full ladder, and still failed closed at `819271` / `819273`. `20260528T030442Z-ghostty` then proved the default ladder skips the session probe, keeps unchanged-prompt baselines, and still fails closed at `821995` / `821997`. `20260528T031735Z-ghostty` accepted the next-word proof at diagnostics line `823023`, tried pasteboard plus native input families, and stopped at diagnostics line `823052` before the slower action-text rung because the default 8s Ghostty insertion budget was exceeded. `20260528T033921Z-ghostty` proved the detached opt-in env reached the app, reached `ghosttyNativePrefixFinalKeyText` at line `825139`, and kept the prompt unchanged at lines `825141` / `825142`; the follow-up `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared in one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at lines `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at lines `832488` / `832489` with handled-false Tab at line `832491`. The latest direct `claude-code-ghostty` pass found the prompt-row suggestion at diagnostics line `800174`, tried the new app-owned in-process native input rung at line `800768`, verified the unchanged baseline at line `800769`, then tried the subprocess front-window/native paths and still failed closed at line `800816`. The latest detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. The AppleScript-health proof `20260528T074034Z-ghostty` moves past preflight: it records `preflight-version:1.3.1` and reaches `new-window-start`, then fails before `new-window-created` or a Claude pidfile; local `--command`, `--initial-command`, surface-configuration, and CLI `+new-window` probes did not produce a working pidfile launch path. `20260528T080441Z-ghostty` records `new-window-front-window-start` and never reaches `new-window-front-window-resolved`, proving the disposable launch blocker moved to Ghostty's front-window object lookup. A removed System Events launch experiment proved a fresh AX window-count increase after that stall, but still failed before pidfile. A separate stage-log probe reached `launch-action-finished` and `launch-finished` without `script-started` or a pidfile, so the current code now submits the Ghostty `text:` action with explicit Enter once launch reaches the target terminal. The fresh detached proof `20260528T082327Z-ghostty` exited `42` at `new-window-front-window-start`; `20260528T082847Z-ghostty` enabled the proof-only reset and still exited `42`; `20260528T083459Z-ghostty` then proved the reset can remove a proof/probe-only pid before launch and still failed at `new-window-front-window-start` under launchd. `20260528T083919Z-ghostty` with the `nohup` launcher got through `launch-action-enter-sent` and `retry-launch-action-enter-sent`, then still failed before pidfile. `20260528T084711Z-ghostty` and `20260528T085044Z-ghostty` exercised the new working-directory readiness gate and never reached `terminal-working-directory-present`; `20260528T085401Z-ghostty` added `window-save-state=never` before preflight and still did not reach a shell-ready terminal; `20260528T090002Z-ghostty` recorded `owns no-restore host pid(s): 55808`, failed closed at `new-window-front-window-start` with exit `42`, and left no proof runner or proof-created Ghostty process afterward; `20260528T091930Z-ghostty` recorded `no-restore-host-no-child-process` for proof-owned Ghostty pid `94700`, still failed closed at `new-window-front-window-start` with exit `42`, and cleaned the proof-owned pid. `20260528T094943Z-ghostty` started with `--initial-window=false`, reached `configured-window-start`, recorded `configured-window API stalled before disposable window creation`, exited `42`, cleaned proof-owned pid `5157`, and left no Ghostty/proof process behind. `20260528T095836Z-ghostty` reached `configured-window-created` and `new-window-created` on both disposable attempts, but never reached `terminal-working-directory-present`, `retry-terminal-working-directory-present`, or `claude.pid`; it failed closed with exit `1`, cleaned proof-owned Ghostty pid(s), and narrowed the red lane to making the configured Ghostty window become shell-ready enough to exec the disposable proof command. `20260528T102120Z-ghostty` then proved direct `open --args -e` can write the pidfile and launch proof-owned Ghostty pid `42748`, with the patched detached runner publishing/protecting live child pid `39108`; it still failed before insertion because AX saw only part of the typed prompt text and the retry context was terminated, so the red lane moved to stable prompt readiness/retry handling after direct command-open. `20260528T114032Z-ghostty` then proved the dirty-prompt fallback: attempt one disabled direct command-open after launch-command AX text persisted; attempt two used script-owned/no-restore launch, reached a prompt-row suggestion at diagnostics line `903324`, handled Tab, and failed closed at `ghostty-initial-insertion-noop-cluster` after `ghosttySendKey`, bulk System Events, and pasteboard left the prompt unchanged. `./script/real_app_smoke_self_test.sh`: passed after adding source checks for bulk System Events ordering, shell-launched bulk System Events, System Events foregrounding, fail-closed baselines, native paste action ordering, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, prompt focus click, in-process native input, front-window input text ordering, shell-launched marker-scanned native input, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification, paced Command-V checks, nonblocking session miss handoff, terminal-ready Ghostty launch checks, the Ghostty AppleScript preflight hard-fail, the `new-window-created` and configured-window launch-stall classifiers, explicit Enter submission after Ghostty launch actions, working-directory readiness before command submission, no-restore proof-owned host cleanup, no-child-process launch classification, configured-window shell-readiness classification, and the opt-in proof/probe-only host reset. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner command, status, tail, stop-mode guardrails, proof-only reset env forwarding, and no raw custom proof-text persistence checks. | Coverage is intentionally narrow. Codex now has a current one-word no-submit proof-only lane, but Claude, chat apps, Mail, terminal hosts, public browser pages, and production browser apps stay proof-only or unclaimed unless exact current proof exists. Ghostty can anchor to the prompt row and route Tab into the expanded fail-closed insertion ladder when launch succeeds, but verified one-word Tab insertion is still not proven and the current detached lane is red at verified Ghostty one-word insertion after the known initial no-op cluster. Obsidian Markdown-list, Markdown-bold, and multiline are covered only for disposable proof-vault lanes. | Build or prove an observable Ghostty accept driver that keeps the prompt-row suggestion visible long enough for SteadyType to capture `Tab`, then rerun `AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=3 AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE=1 ./script/claude_code_ghostty_detached_proof.sh start` plus `./script/claude_code_ghostty_detached_proof.sh wait`. Only count Ghostty when the detached run exits `0` with verified one-word no-submit insertion. |
| Onboarding | 70/100 | Documented manual gate: `docs/product/onboarding-permission-qa-checklist.md`. `./script/onboarding_walkthrough_evidence_helper_self_test.sh`: passed for the redacted before-delete/after-delete evidence helper, including fail-closed checks that the TextEdit practice-start event has `model=ready`, `textEditEnabled=true`, and `globalPaused=false`, and that Tab/Esc/Pause proof is newer than the latest TextEdit practice-start line. `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready`: failed on the current local logs because no `textedit-practice-started` event exists, even though older TextEdit Tab, Esc, pause, and trace events exist; this proves the helper will not assemble a false walkthrough from scattered old sessions or from a practice start where the model was not ready, TextEdit was disabled, suggestions were globally paused, or action evidence belonged to an older practice start. `./script/check_onboarding_walkthrough_proof_self_test.sh`: passed for the fail-closed guided TextEdit proof validator, and the template now prints the helper commands plus `./script/build_and_run.sh --verify`, diagnostics paths, and trace log paths before recording. `./script/check_onboarding_walkthrough_proof.py`: failed because no completed passing walkthrough proof row exists yet; row 1 is still Pending. `./script/check_onboarding_permission_qa.sh --check`: failed with 48 unchecked items and 3 Pending proof rows after adding the helper step to the checklist. | The first-run path is documented and now has executable pre-delete and post-delete evidence checks for Accessibility, app-owned runtime readiness, TextEdit enabled, suggestions unpaused, TextEdit practice, Tab, Esc, pause, and trace deletion, but the checklist still has no real clean-user tester-walkthrough row. | Record one guided TextEdit practice run in `docs/product/onboarding-permission-qa-checklist.md` using `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready` before Delete Local Logs and `./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready` after deletion, then rerun `./script/check_onboarding_walkthrough_proof.py` and `./script/beta_readiness.sh --check-only`. |
| Controls | 84/100 | `./script/check_controls_diagnostics_readiness.sh`: Settings, Diagnostics, pause scheduling, disabled-app selection, raw-trace expiry, redacted export, privacy export proof, diagnostics log self-test, and local trace deletion all passed. `script/delete_local_traces.sh` now removes `diagnostics.log` too. | Pause/delete/export controls now have better automated parity proof, but the latest score run still does not include a human walkthrough across every visible surface. | Run a documented manual gate that toggles pause, disabled apps, trace delete, and redacted export from Settings, menu bar, and Diagnostics. |
| Diagnostics | 92/100 | Latest `./script/beta_readiness.sh --check-only` reached and passed controls/diagnostics after the privacy-export self-wait fix. `./script/check_controls_diagnostics_readiness.sh`: Diagnostics state tests, RawTraceReportExport tests, diagnostics log self-test, redacted report export, and current-build privacy export proof passed. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `1969992ddcf5`, so the beta-safe manual proof rows have recent diagnostics and trace slices, including the refreshed Obsidian long-note row. Runtime production gate, runtime no-egress proof, and redacted report export are OK. | Diagnostics are healthy for local beta work, but onboarding walkthrough and packaged-app Accessibility recovery proof are not complete. | Rerun `./script/check_diagnostics_log.sh`, `./script/check_current_build_privacy_export.sh`, runtime no-egress proof, and `./script/manual_smoke_status.sh --strict` after the next app/source change. |
| Model readiness | 94/100 | `./script/check_model_asset.py --quiet`: Qwen3.5 4B MLX verified at revision `32f3e8ecf65426fc3306969496342d504bfa13f3` with `.steadytype-model-integrity.json`. `./script/package_release.sh --check --require-developer-id --require-notary-profile`: Preferred MLX model ready. `./script/check_model_asset_self_test.sh`: passed and proves checksum-skip env no longer bypasses known-good file checks. `./script/download_mlx_model_self_test.sh`: passed and checks immutable revision validation. `swift test --jobs 1 --filter 'AppModelRuntimeFactoryTests|ModelAssetInstallerTests|LocalModelAssetInstallerTests|RuntimePolicyTests'`: 48 tests passed, including immutable 40-character commit revision requirements, absent/tampered integrity receipt rejection, checksum mismatch, duplicate, unsafe path, absent referenced file, extra file, and byte-count mismatch coverage. | The app-owned model path and integrity receipt checks are strong, but beta trust still depends on onboarding and distribution proof. | Keep `./script/check_model_asset.py` green, then rerun `./script/beta_readiness.sh --check-only` after onboarding proof and the primary beta DMG exist. |
| Beta readiness | 75/100 | `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`: created a current Developer ID signed `dist/SteadyType.dmg` and `dist/SteadyType.zip` after the default parallel release build died during compile. `./script/package_release.sh --notarize`: Apple notarization accepted submission `bf39ea78-ed19-4a74-95ba-714ed6c474b6`, stapled the DMG, verified Gatekeeper, and refreshed the secondary ZIP. Latest readiness checks prove the manual app proof, runtime no-egress proof, and private packet blockers are gone: model asset, runtime production gate, runtime no-egress proof, controls/diagnostics, redacted export, issue template validation, clipboard fallback disabled, production mock fallback disabled, prompt app manifest proof, manual app proof, visual placement proof, release package prerequisites, Developer ID DMG/archive signature, notarized install proof, and `./script/private_beta_packet.sh --check` passed. The current blocker list is 3 real blockers: no onboarding walkthrough proof, onboarding permission QA with 48 unchecked items and 3 proof rows waiting for a clean-user run, and no eligible packaged latency launch until Accessibility is granted for the notarized app. `./script/packaged_latency_proof_self_test.sh`: passed and keeps the TextEdit packaged-latency rerun path one command. | Onboarding proof and packaged Accessibility latency still need current runs before testers should get the build. | Grant Accessibility to the notarized app for packaged latency, then record onboarding proof / complete the onboarding checklist and rerun `./script/beta_readiness.sh --check-only`. |
| Test/proof coverage | 85/100 | `swift test --jobs 1`: 1508 tests passed after instant fast-phrase-to-model refinement, model-failure visible fallback preservation, and Ghostty insertion diagnostics changes. `swift test --jobs 1 --filter ClaudeCodeTerminalHostProofPolicyTests`: 90 tests passed after the paced Command-V/session-paste proof change. Focused Swift suites for keyboard capture/safety, synthetic caret placement, Chrome same-text split preservation, Codex proof geometry, and Obsidian insertion retry all passed in the current proof set. `./script/real_app_smoke_self_test.sh`: passed after adding bounded log-slice scanning, fast Ghostty focus reassertion, insertion-rung ordering, timeout fail-closed guards, stdin-only helper input, safe apostrophes, unsupported-scalar diagnostics, hardware key-event ordering checks, bulk and paced per-character System Events checks, shell-launched System Events checks, System Events foregrounding checks, native paste-action checks, in-process native input checks, exact-PID focus, safe pasteboard cloning, async final pasteboard cleanup, opt-in session-tap Command-V, default session-probe skip, Ghostty insertion budget opt-in/override checks, native-prefix/final-key prefix verification checks, paced Command-V checks, nonblocking session miss handoff, terminal-ready Ghostty launch checks, the Ghostty AppleScript preflight hard-fail, and the `new-window-created` launch-stall classifier. `./script/claude_code_ghostty_detached_proof_self_test.sh`: passed for the detached runner's help, dry-run, status, tail, `nohup` launch path, stop-mode guardrails, and no raw custom proof-text persistence checks. `swift build --product SteadyType`: passed after adding separate native-prefix verification. `./script/manual_smoke_status.sh --strict`: passed on 2026-05-28 at commit `1969992ddcf5` for all 10 beta-safe writing rows. Direct `AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate`: failed closed after finding a prompt-row suggestion at diagnostics line `800174`, posting the new `ghosttyInProcessInputText` rung at line `800768`, verifying the unchanged baseline at line `800769`, and failing closed at line `800816` with `keyboard-action handled=false reason=insert-failed`. `./script/claude_code_ghostty_detached_proof.sh start` plus `./script/claude_code_ghostty_detached_proof.sh wait`: `20260528T025919Z-ghostty` found a prompt-row suggestion at diagnostics line `818560`, captured Tab, ran targeted paste, opt-in session-tap paste, global paste, native Ghostty, System Events, hardware, bundled-helper, and Unicode rungs, then failed closed with `ghosttyFastFailClosed` plus `keyboard-action handled=false reason=insert-failed` at lines `819271` / `819273`. The default follow-up `20260528T030442Z-ghostty` found the prompt-row suggestion at diagnostics line `821100`, consumed Tab at `821919`, skipped the session probe at `821948`, kept pasteboard baselines unchanged, and failed closed at `821995` / `821997`. The bounded follow-up `20260528T031735Z-ghostty` accepted the next-word proof at line `823023`, logged `ghosttyFastInsertionBudget` at line `823052` with `elapsedMilliseconds=9886` and `budgetMilliseconds=8000`, then failed closed at lines `823053` / `823055` before slower exploratory rungs. `20260528T033921Z-ghostty` proved opt-in env propagation into the detached app and reached `ghosttyNativePrefixFinalKeyText`, but the prompt stayed unchanged at lines `825141` / `825142`; `20260528T034406Z-ghostty` failed before insertion because no visible suggestion appeared after one disposable context; `20260528T040957Z-ghostty` and `20260528T041228Z-ghostty` reached prompt-row suggestions again; the latest activated Ghostty after title-scoped terminal focus at `832453` / `832454`, then proved `ghosttySendKey`, bulk System Events, pasteboard, native-prefix/final-key, in-process native text, front-window input text, and action-text all left the prompt unchanged before failing closed on budget at `832488` / `832489` with handled-false Tab at `832491`. The current detached launch proof `20260528T054054Z-ghostty` failed before insertion with no pidfile and launch state `windows=5 proofTitleWindows=0 frontWindowHasProofTitle=false focusedTerminalWorkingDirectoryPresent=false`, proving unready Ghostty windows no longer count as disposable proof command launches. The follow-up `20260528T074034Z-ghostty` records `preflight-version:1.3.1` and reaches `new-window-start`, then fails before `new-window-created` or a Claude pidfile, proving the current blocker moved from preflight to Ghostty disposable window creation. `./script/check_prompt_app_proof_self_test.sh` and `./script/check_prompt_app_manifest_proof_self_test.sh`: passed after the prompt gate gained an explicit full-accept no-submit proof mode while still requiring `prompt no-submit confirmed` for every normal prompt-app proof claim. `./script/check_prompt_app_manifest_proof.sh`: passed for the Codex bounded prompt slice. `./script/beta_readiness_self_test.sh` now proves beta readiness uses that bounded manifest gate instead of scanning old prompt trace history, and the current `./script/beta_readiness.sh --check-only` run shows the prompt app manifest proof gate passing. `bash -n script/real_app_smoke.sh script/real_app_smoke_self_test.sh script/claude_code_ghostty_detached_proof.sh script/claude_code_ghostty_detached_proof_self_test.sh script/beta_readiness.sh script/beta_readiness_self_test.sh script/check_prompt_app_manifest_proof.sh script/check_prompt_app_proof.sh`, `./script/check_test_coverage_manifest.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/check_steadytype_scorecard.py --live`, `AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=5 ./script/build_and_run.sh --verify`, `AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS=1 ./script/package_release.sh archive`, `./script/package_release.sh --notarize`, `./script/beta_readiness.sh --check-only`, and `git diff --check`: passed or failed only on the known human proof gates. Earlier proof includes `./script/private_beta_packet.sh --check`, runtime no-egress validation, visual placement evidence validation, prompt proof validation, and focused model-integrity tests. | The proof loop now covers current beta-safe writing lanes, Obsidian run-on, Obsidian font-zoom, Obsidian Markdown-list, Obsidian Markdown-bold, Obsidian multiline, Codex one-word no-submit, Chrome same-text split persistence, virtual-host suggestion preservation, release-signed no-egress proof, Developer ID signed/notarized beta artifacts, private beta packet regeneration, Ghostty fail-closed prompt-row placement trust, Ghostty prompt-row suggestion evidence, Ghostty Tab delivery into the expanded insertion ladder when launch succeeds, detached proof cleanup safety, terminal-ready Ghostty launch failure proof, Ghostty AppleScript preflight repair proof, prompt proof bounded to manifest slices, and a detached Ghostty proof runner. Onboarding, Ghostty verified insertion proof, and packaged Accessibility latency proof are the named non-green proof lanes. Proof-only prompt/chat/terminal/browser-production lanes do not count as beta-safe support without live host proof. | Keep `./script/check_steadytype_scorecard.py --live`, `./script/check_prompt_app_manifest_proof.sh`, `./script/check_proof_manifest.sh --require-all`, `./script/claude_code_ghostty_detached_proof.sh start && ./script/claude_code_ghostty_detached_proof.sh wait`, `./script/packaged_latency_proof.sh textedit-model-latency`, `./script/private_beta_packet.sh --check`, and `./script/beta_readiness.sh --check-only` in the loop. |

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
| Proof freshness | 10 beta-safe target app rows from strict manual smoke. | Recent strict manual smoke passed for all 10 beta-safe rows; the gate should ask for another refresh after the next app/source change. |
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
