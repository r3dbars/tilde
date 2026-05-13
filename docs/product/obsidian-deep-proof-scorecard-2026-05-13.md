# Obsidian Deep Proof Scorecard - 2026-05-13

Goal: get every Obsidian lane to 100/100 with real typed text, accepted words, and screenshot proof.

Current branch: `codex/obsidian-deep-proof-390d`

## Current Grades

| Category | Grade | Evidence |
| --- | ---: | --- |
| Default note writing | 90 | Fresh foreground Obsidian proof accepted one visible word suffix in the disposable proof note and the Markdown file ended as `Smoke proof feed` with no literal tab. Needs repetition across many notes before 100. |
| Non-default theme | 100 | `obsidian-theme` smoke passed with 2 verified insertions and strict screenshots. |
| Split pane / same-pane insertion | 100 | `obsidian-pane` smoke passed after focused-editor insertion fix. |
| Accepted words appear on screen | 85 | Fresh Computer Use proof showed the suggestion, then Tab produced `Smoke proof feed` on screen and in the Markdown file. This is a pass for the core issue, but not enough repetitions yet. |
| CodeMirror stale cursor repair | 90 | Focused repair tests pass, and the live repair recovered from Obsidian's Tab/CodeMirror drift with `keyboard-action ... reason=obsidian-tab-passthrough-repaired`. Long-note caret placement still needs more proof. |
| Long scrolled note | 60 | The old AX value-replacement path could truncate off-screen lines. The latest live run preserved line 01 through line 90 and appended `Smoke proof feels` at document end, but the harness still received SIGTERM before the second acceptance and formal verification. |
| Font/zoom/dynamic layout | 60 | Theme and pane geometry passed; explicit font-size/zoom sweep is still pending. |
| Markdown formatting stress | 60 | Plain prose and pane cases passed; bold, dash list, blank lines, and run-on sentence sweeps are still pending. |

## Fixes Landed In This Pass

- Obsidian now avoids destructive AX value replacement for insertion because long virtualized notes can expose only the visible viewport through AX.
- Obsidian acceptance now has a System Events paste path using Obsidian's own `Command-V` behavior instead of replacing the AX value.
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

## Fresh Findings This Pass

- Computer Use screenshot proof showed the long note split-pane state with line 01 visible in the right pane and lines 76-90 visible in the left pane.
- Computer Use typing wrote `Smoke proof feels` to the visible Obsidian editor and the file preserved line 01 and line 90.
- Computer Use Tab did not trigger a verified accept; Obsidian inserted a literal tab/indent.
- Foreground Obsidian proof on this branch reached `md.obsidian`, profile `yellow: Obsidian`, render mode `floatingMirror`, insertion mode `keyEvents`, and presented a word-completion suggestion with screenshot evidence.
- Earlier foreground Computer Use Tab proof was red: `placement-proof.md` contained `Autocomplete Lab Obsidian proof\n\n[TAB]Smoke proof fee` after Tab.
- Fresh foreground Computer Use Tab proof is green: `placement-proof.md` contained `Autocomplete Lab Obsidian proof\nSmoke proof feed` after Tab, with no `[TAB]`.
- Fresh diagnostics recorded `obsidian-tab-passthrough-repair`, `obsidian-tab-passthrough-direct-repair success=true`, `keyboard-action ... handled=true ... reason=obsidian-tab-passthrough-repaired`, and `insert-verification ... result=verified`.
- Screenshot evidence:
  - `docs/product/obsidian-proof-screenshots/default-computeruse-before-tab-foreground-obsidian-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/default-computeruse-after-tab-foreground-obsidian-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/frontmost-obsidian-before-tab-2026-05-13.png`
  - `docs/product/obsidian-proof-screenshots/frontmost-obsidian-after-tab-2026-05-13.png`
- Manual click testing can still place the caret before the suffix, producing `moke proof feelsS` instead of the intended text.
- A separate `steadytype-score-loop` heartbeat in the old `25ed` worktree repeatedly flipped proof mode to TextEdit and killed/invalidated Obsidian proof attempts. That heartbeat was paused during this goal.
- Even after the automation file showed `status = "PAUSED"`, already-running stale TextEdit proof jobs continued spawning from the old `25ed` context and repeatedly killed the current app. These runs are not valid Obsidian proof.
- After pausing and killing the stale `25ed` jobs, `obsidian-long-note` reached a real Obsidian suggestion and consumed Tab, but the smoke harness still received SIGTERM before it could record a clean pass.
- Fresh file evidence: `/Users/redbars/Documents/claudebrain-lab/Autocomplete Lab Obsidian Proof Codex.md` kept the long-note body and ended with `Long note filler line 90 ... Smoke proof feels`.
- Fresh bad evidence: `/Users/redbars/Documents/claudebrain-lab/Autocomplete Lab Obsidian proof.md` ended up as `Smoke proof feelsAutocomplete Lab Obsidian proof`, which is not acceptable insertion behavior.
- Superseded bad evidence: `/Users/redbars/Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md` previously showed `[TAB]Smoke proof fee`; after the repair it showed `Smoke proof feed`.

## Remaining Gates To Reach 100

- Get `obsidian-long-note` to a clean recorded pass on this branch.
- Keep the direct repair green and only rely on the undo/paste fallback when direct AX repair fails in live proof.
- Fix or harden end-of-document caret placement so clicks and AX range repair land after the suffix, not before it.
- Run a font-size/zoom sweep.
- Run markdown formatting cases: bold, dash list, blank lines, indented line, long run-on sentence, and three-line down movement.
- Repeat default/theme/pane/long-note enough times to turn this from smoke proof into a real reliability sample.
