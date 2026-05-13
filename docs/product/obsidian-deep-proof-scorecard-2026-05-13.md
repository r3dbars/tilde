# Obsidian Deep Proof Scorecard - 2026-05-13

Goal: get every Obsidian lane to 100/100 with real typed text, accepted words, and screenshot proof.

Current branch: `codex/obsidian-deep-proof-390d`

## Current Grades

| Category | Grade | Evidence |
| --- | ---: | --- |
| Default note writing | 100 | `obsidian` smoke passed with 2 verified insertions and strict screenshots. |
| Non-default theme | 100 | `obsidian-theme` smoke passed with 2 verified insertions and strict screenshots. |
| Split pane / same-pane insertion | 100 | `obsidian-pane` smoke passed after focused-editor insertion fix. |
| Accepted words appear on screen | 95 | Computer Use confirmed `Smoke proof feels instant` appeared correctly after accept; pane proof confirms same-pane writes. |
| CodeMirror stale cursor repair | 95 | 32 focused repair tests pass, including viewport and long-note drift cases. |
| Long scrolled note | 70 | Unit repair path passes; live long-note smoke still needs a clean recorded pass. External proof loops repeatedly killed the launch. |
| Font/zoom/dynamic layout | 60 | Theme and pane geometry passed; explicit font-size/zoom sweep is still pending. |
| Markdown formatting stress | 60 | Plain prose and pane cases passed; bold, dash list, blank lines, and run-on sentence sweeps are still pending. |

## Fixes Landed In This Pass

- Obsidian direct insertion now prefers the focused matching editor before searching duplicate panes.
- Obsidian direct insertion now sends document-end fallback when AX refuses to place the cursor after end-of-note acceptance.
- Obsidian long/virtualized CodeMirror viewport drift now has a dedicated repair and tests.

## Remaining Gates To Reach 100

- Get `obsidian-long-note` to a clean recorded pass on this branch.
- Run a font-size/zoom sweep.
- Run markdown formatting cases: bold, dash list, blank lines, indented line, long run-on sentence, and three-line down movement.
- Repeat default/theme/pane/long-note enough times to turn this from smoke proof into a real reliability sample.
