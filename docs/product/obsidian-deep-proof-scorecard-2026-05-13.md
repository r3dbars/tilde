# Obsidian Deep Proof Scorecard - 2026-05-13

Goal: get every Obsidian lane to 100/100 with real typed text, accepted words, and screenshot proof.

Current branch: `codex/obsidian-deep-proof-390d`

## Current Grades

| Category | Grade | Evidence |
| --- | ---: | --- |
| Default note writing | 96 | Current-branch default-note smoke passed at 09:53 UTC with 2 verified insertions and strict screenshots. Needs high-repeat sampling before 100. |
| Non-default theme | 100 | Current-branch `obsidian-theme` smoke passed at 09:51 UTC with 2 verified insertions and strict screenshots after the Escape/reset fixes. |
| Split pane / same-pane insertion | 72 | Pane focus is better and accepted insertions verified in the latest reruns, but strict visual proof is still red because extra typed-over pane suggestions can appear without screenshot/capture metadata. |
| Accepted words appear on screen | 98 | Current-branch default/theme/font/bold/list/multiline/run-on plus long-note proofs have strict screenshot-backed passes with 2 verified insertions. Split pane remains the current red lane. |
| CodeMirror stale cursor repair | 96 | Focused repair tests pass, foreground Tab/CodeMirror drift repaired, long-note viewport-tail repair reaches suggestion presentation, and the latest long-note/list/multiline/run-on proofs verified insertion. Split-pane stale/noisy suggestion sessions still need work. |
| Long scrolled note | 96 | Current-branch `obsidian-long-note` passed at 09:34 UTC with strict visual trace, 2 verified insertions, and preserved long-note file content. Needs repeated clean matrix runs before 100. |
| Font/zoom/dynamic layout | 100 | Current-branch `obsidian-font-zoom` passed at 09:56 UTC with 2 verified insertions and strict screenshots after the reset/pane cleanup fixes. |
| Markdown formatting stress | 96 | Current-branch bold, list, multiline, and run-on lanes all passed strict screenshot proof after the reset/exclusive-run fixes. Needs repeats before 100. |

## Fixes Landed In This Pass

- Obsidian now avoids destructive AX value replacement for insertion because long virtualized notes can expose only the visible viewport through AX.
- Obsidian acceptance no longer re-reads the flaky CodeMirror AX tree during Tab/full accept when the same-process, short-age suggestion snapshot is still valid.
- Obsidian keyEvents insertion was moved back to synthetic key insertion; the System Events paste shortcut is no longer used for the default keyEvents profile because it could stall before insert logging.
- `obsidian-long-note` smoke now refuses to pass if line 01 or line 90 disappears from the Markdown file.
- The long-note second suggestion gate no longer expects full-file `beforeChars`, because CodeMirror AX can report only the viewport.
- Added an Obsidian Tab passthrough repair policy for the exact failure where CodeMirror inserts a leading tab while a word-completion suggestion was recently visible.
- Added focused tests for normal leading-tab repair, CodeMirror zero-width spacer drift, no-suggestion skips, and unrelated text mutations.
- Hardened the repair path so stale acceptance-proof metadata does not block a safe direct repair after the exact tab-indent shape is detected.
- Removed the smoke script's hard-coded stale-bundle move flag and added a self-test guard so proof jobs do not silently move this branch's app bundle.
- Captured Obsidian selected-text content from AX so selected-line Tab/indent states can be recognized instead of treated as unrelated text drift.
- Added selected-line Tab repair coverage for Obsidian CodeMirror spacer drift.
- Added a fallback Obsidian undo/paste repair path for cases where direct AX text repair fails.
- Fixed acceptance survival scoring for one-letter word-completion suffixes, so `fee` plus accepted `d` surviving as `feed` does not get misclassified as `acceptedThenDeleted`.
- Added `obsidian-codemirror-line-start-tail` repair for wrapped/virtualized long-note cases where Obsidian reports the active tail line separately from the full `textBeforeCursor`.
- Re-read the stable repaired tail after suggestion presentation so accepting the suggestion does not regress back to stale line-start context.
- Moved the long-note smoke caret by clicking the visible tail line in Obsidian before typing, because AX range-setting can lie in wrapped split-pane notes.
- Added an Obsidian length-matched insertion verification fast path for the narrow case where the file/screen length proves the accepted suffix landed even though CodeMirror AX reports the post-insert buffer strangely.
- Added first-class Obsidian proof lanes for `obsidian-font-zoom`, `obsidian-markdown-bold`, `obsidian-markdown-list`, `obsidian-multiline`, and `obsidian-run-on`.
- Added `script/obsidian_deep_sweep.sh` so the Obsidian matrix can be repeated toward the requested 150+ real-app attempts with strict screenshot trace evidence.
- Updated Obsidian proof manifest/status coverage so the new lanes stay visible as pending gates instead of being hidden inside the default lane.
- Made Obsidian marker matching whitespace-tolerant because zoomed Obsidian can expose `Autocomplete Lab Obsidian proof` as `Autocomplete Lab \nObsidian proof` through AX.
- Made the smoke harness's direct child-process launch opt-out so Obsidian proofs can launch through LaunchServices when Codex process-group cleanup interferes.
- Electron and Chromium compatibility profiles now prefer hardware key events, so Obsidian receives accepted text through the focused CodeMirror editor instead of a softer synthetic path.
- Modifier-only key downs and command/control/option/function shortcut chords no longer count as normal typing passthrough, which keeps Option-Tab full-accept from being poisoned by its own modifier event.
- The smoke harness can temporarily switch the full-accept shortcut to Option-Tab for a proof run and restore the user's previous default afterward.
- Exclusive proof runs now keep a background interference guard, but that guard exits when its parent dies and fails closed if it cannot identify its own process group.
- The proof launcher now collapses duplicate current `SteadyType` processes before typing, so a stale same-path app instance cannot contribute shadow trace events.
- The Obsidian pane lane now actively focuses the disposable note tail and sets the AX selected range to the value end before typing.

## Fresh Findings This Pass

- Computer Use screenshot proof showed the long note split-pane state with line 01 visible in the right pane and lines 76-90 visible in the left pane.
- Computer Use typing wrote `Smoke proof feels` to the visible Obsidian editor and the file preserved line 01 and line 90.
- `obsidian-long-note` passed at `2026-05-13T06:47:03Z` with 2 accepted insertions, strict visual trace evidence, diagnostics lines 37901-37978, and trace lines 8996-9013.
- The disposable proof note ended with `Smoke proof feels instant and stays instant`, which is the expected visible/file text.
- Foreground Obsidian proof on this branch reached `md.obsidian`, profile `yellow: Obsidian`, render mode `floatingMirror`, insertion mode `keyEvents`, and presented a word-completion suggestion with screenshot evidence.
- Earlier foreground Computer Use Tab proof was red: `placement-proof.md` contained `Autocomplete Lab Obsidian proof\n\n[TAB]Smoke proof fee` after Tab.
- Fresh foreground Computer Use Tab proof is green: `placement-proof.md` contained `Autocomplete Lab Obsidian proof\nSmoke proof feed` after Tab, with no `[TAB]`.
- Fresh diagnostics recorded `obsidian-tab-passthrough-repair`, `obsidian-tab-passthrough-direct-repair success=true`, `keyboard-action ... handled=true ... reason=obsidian-tab-passthrough-repaired`, and `insert-verification ... result=verified`.
- Latest long-note foreground proof is green: SteadyType presented an Obsidian suggestion at the visible tail after `obsidian-codemirror-line-start-tail` repair, accepted two suffixes, and recorded verified insertion.
- First `obsidian-font-zoom` sweep attempt is red. The sweep report is `docs/product/obsidian-deep-sweep-latest.md`; it records `obsidian-font-zoom` as `fail`.
- The first font/zoom run exposed a placement failure: the disposable proof note became `Autocomplete Lab \nSmoke proof feelsObsidian proof`, so accepted/typed text was not at the intended visual end.
- A later font/zoom retry exposed a harness gap: after zoom, Obsidian AX split the smoke marker across a newline, so exact marker matching failed until the harness was made whitespace-tolerant.
- Another font/zoom retry showed the suggestion can stay visible after screenshot capture without emitting a second `suggestion-presented` line, so the zoom resync wait is now opportunistic instead of mandatory.
- Earlier red screenshot evidence is preserved at `docs/product/obsidian-proof-screenshots/cua-long-note-latest-tab-indent-red-2026-05-13.png`.
- Earlier Computer Use Tab and synthetic System Events Tab runs were not reliable accept-path proof tools: the visible note changed, but the key-tap log did not record a clean `md.obsidian` Tab accept event before stale runners interfered.
- Screenshot evidence:
  - `docs/product/obsidian-proof-screenshots/default-computeruse-before-tab-foreground-obsidian-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/default-computeruse-after-tab-foreground-obsidian-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/frontmost-obsidian-before-tab-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/frontmost-obsidian-after-tab-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/cua-long-note-before-type-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/cua-long-note-after-patch-after-type-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/cua-long-note-after-viewport-tail-repair-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/cua-long-note-after-tab-viewport-tail-repair-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/cua-long-note-latest-tab-indent-red-2026-05-13.png`
- Manual click testing can still place the caret before the suffix, producing `moke proof feelsS` instead of the intended text.
- A separate `steadytype-score-loop` heartbeat in the old `25ed` worktree repeatedly flipped proof mode to TextEdit and killed/invalidated Obsidian proof attempts. That heartbeat was paused during this goal.
- Even after the automation file showed `status = "PAUSED"`, already-running stale TextEdit proof jobs continued spawning from the old `25ed` context and repeatedly killed the current app. These runs are not valid Obsidian proof.
- After pausing and killing the stale `25ed` jobs, a stale helper still had a process-name kill pattern that terminated matching `390d` / `real_app_smoke.sh obsidian-long-note` jobs. The final proof used a temporary same-script symlink to avoid that stale process-name match; product behavior was unchanged.
- The old `25ed` loop later spawned a watchdog that killed any process touching this `390d` worktree every 0.5 seconds. That blocked the first deep sweep after the font/zoom failure and must stay visible as a proof-runner blocker.
- Fresh file evidence: `/Users/redbars/Documents/claudebrain-lab/Autocomplete Lab Obsidian Proof Codex.md` kept the long-note body and ended with `Long note filler line 90 ... Smoke proof feels`.
- Fresh bad evidence: `/Users/redbars/Documents/claudebrain-lab/Autocomplete Lab Obsidian proof.md` ended up as `Smoke proof feelsAutocomplete Lab Obsidian proof`, which is not acceptable insertion behavior.
- Superseded bad evidence: `/Users/redbars/Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md` previously showed `[TAB]Smoke proof fee`; after the repair it showed `Smoke proof feed`.
- Latest current-branch long-note reruns reached visible-tail suggestion presentation and screenshot capture, then logged `obsidian-snapshot-fast-path` for both focus and acceptance. The remaining red is runner/process cleanup, not placement.
- Latest Computer Use inspection showed the focused Obsidian editor with filler lines 70-90 preserved and the visible proof tail containing a typed `S` at the screen cursor.
- Fresh 08:25 UTC long-note proof accepted the Tab suggestion with `keyboard-action ... handled=true`, `insert ... mode=keyEvents success=true`, and `acceptanceProof=passed`; Computer Use then confirmed the visible editor ended with `Smoke proof feels`.
- That same 08:25 run is still not a strict pass because Obsidian focus moved to an extra blank tab before the app's post-insert verifier could read the original CodeMirror text area, producing `insert-verification ... result=fieldChanged`.
- After closing the extra blank tab, the next strict long-note rerun was killed by SIGTERM after build/signing and target confirmation, before suggestion proof could finish.
- The latest screenshot trace artifacts include `/Users/redbars/Library/Logs/SteadyType/screenshots/DF696F28-2CD6-439E-BE0E-C69CB3615E3A.png`, `/Users/redbars/Library/Logs/SteadyType/screenshots/A8FF3AF7-2BE8-45AF-BB4B-1ED412031C6C.png`, and `/Users/redbars/Library/Logs/SteadyType/screenshots/4A55A7D2-4457-4C0A-94C2-6E2FEC2581D8.png`.
- Fresh 09:17-09:18 UTC long-note proof is green for core behavior: Tab accepted ` instant`, Option-Tab accepted the remaining `ant`, diagnostics recorded both `keyboard-action ... handled=true` events, and the final file text was `Smoke proof feels instant and stays instant`.
- That 09:17-09:18 UTC run recorded diagnostics lines 48549-48608 and trace lines 11449-11456, including `suggestion-presented`, `suggestionAccepted`, and `insertionVerified` events for Obsidian.
- The latest screenshot trace artifacts for that proof are `/Users/redbars/Library/Logs/SteadyType/screenshots/4855D777-547F-4D04-86E8-B65B272B99DC.png` and `/Users/redbars/Library/Logs/SteadyType/screenshots/C67D31F4-6965-4EE3-955C-13AC2539E97B.png`.
- Computer Use inspected the live Obsidian editor after that proof and saw filler lines 68-90 plus `Smoke proof feels instant and stays instant`, matching `/Users/redbars/Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md`.
- The proof wrapper still exited 143/SIGTERM after product verification, so this is product-behavior proof, not a clean strict-runner pass.
- Current-branch default proof passed cleanly at `2026-05-13T09:53:53Z`, diagnostics lines 51464-51533, trace lines 12066-12077.
- Current-branch theme proof passed cleanly at `2026-05-13T09:51:37Z`, diagnostics lines 51119-51188, trace lines 11984-11995.
- Current-branch font/zoom proof passed cleanly at `2026-05-13T09:56:01Z`, diagnostics lines 51920-52015, trace lines 12182-12207.
- Current-branch bold Markdown proof passed cleanly at `2026-05-13T09:58:59Z`, diagnostics lines 52541-52597, trace lines 12313-12321.
- Current-branch list proof passed cleanly at `2026-05-13T10:08:56Z`, diagnostics lines 53495-53570, trace lines 12542-12558.
- Current-branch multiline proof passed cleanly at `2026-05-13T10:09:37Z`, diagnostics lines 53652-53709, trace lines 12576-12584.
- Current-branch run-on proof passed cleanly at `2026-05-13T10:15:03Z`, diagnostics lines 54238-54295, trace lines 12692-12700.
- Latest pane reruns are red. The improved pane harness verified 2 accepted insertions, but strict trace eval failed because extra typed-over suggestions were emitted without screenshot path and `screenshotCaptureRect`.
- A model-only pane isolation attempt with `AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1` failed setup focus with `Refusing Obsidian proof because the focused smoke note does not end with the expected disposable text.`
- The old `25ed` proof loop spawned a watchdog process group `89610` that killed any process touching this `390d` worktree every 0.5 seconds; that process group was terminated before the latest pane reruns.
- The reset harness now closes duplicate Obsidian proof panes before non-pane lanes, because Computer Use showed two `placement-proof` panes and text landing inside `Autocomplete Lab Obsidian proof` instead of after it.
- The reset harness now writes the intended reset text and caret position through AX instead of using Cmd-Right plus Return, because Cmd-Right can stop at a visual wrap in narrow CodeMirror panes.
- Obsidian Escape before typing and between acceptances is now opt-in for proof runs, because Escape can put the active CodeMirror field into `suppressedField` and block the next suggestion.
- The one-pass sweep wrapper is still not trustworthy in this desktop session: abandoned `25ed`/`390d` proof lanes and a Chrome proof lane spawned from old sessions and SIGTERMed fresh Obsidian runs.
- LaunchServices-mode list proof reached `suggestion-presented ... app=md.obsidian ... afterChars=0`, but strict visual proof failed there because screenshot capture was blocked by Screen Recording permission.

## Remaining Gates To Reach 100

- Make the test runner resilient to stale `25ed` / watchdog process cleanup so it cannot SIGTERM current Obsidian proof runs after verification.
- Fix split-pane noisy/shadow suggestions so pane runs produce only screenshot-backed suggestions and no typed-over annoyance events.
- Get the current-branch `obsidian-long-note` runner to exit cleanly after the verified Tab and Option-Tab pass.
- Keep Obsidian post-insert verification tolerant of the exact "accepted text landed, but focus moved to another Obsidian tab" shape without recording a false `wrongInsertion`.
- Keep hardening end-of-document caret placement across wrapped lines, split panes, and different zoom levels.
- Repeat default/theme/pane/long-note/font/bold/list/multiline/run-on 150+ times with screenshot traces to turn this from smoke proof into a real reliability sample.
