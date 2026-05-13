# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T10:35:36Z
- Mode: repeat sweep after pane proof fix
- Lanes: obsidian obsidian-theme obsidian-long-note obsidian-font-zoom obsidian-markdown-bold obsidian-markdown-list obsidian-multiline obsidian-run-on obsidian-pane

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |
| 1 | `obsidian` | `pass` | `script/real_app_smoke.sh obsidian --manual-gate` |
| 1 | `obsidian-theme` | `pass` | `script/real_app_smoke.sh obsidian-theme --manual-gate --skip-build` |
| 1 | `obsidian-long-note` | `fail` | `script/real_app_smoke.sh obsidian-long-note --manual-gate --skip-build` |
| 1 | `obsidian-font-zoom` | `fail` | `script/real_app_smoke.sh obsidian-font-zoom --manual-gate --skip-build` |
| 1 | `obsidian-markdown-bold` | `fail` | `script/real_app_smoke.sh obsidian-markdown-bold --skip-build` |

## Summary

- Default and theme repeated strict screenshot-backed passes on commit `44c3b52c`.
- The long-note repeat exposed stale CodeMirror cursor state: the accepted words were visible in Obsidian, but AX sometimes reported the caret in the middle of the visible tail line, so suggestion triggering blocked as `middleOfLine` or later hit cadence policy.
- Font/zoom and bold were not valid product failures in isolation; they ran after the long-note miss with `--skip-build`, which let quiet/cadence state and app-process loss poison the batch.
- A stale `25ed` `script/manual_proof_refresh.sh` watchdog repeatedly targeted this `390d` worktree and killed current proof runs. The proof guard now protects ancestor process groups and treats `manual_proof_refresh` as competing proof work.
- The long-note harness now types the setup phrase, repairs the caret to the visible value end, then types the final trigger character live before waiting for screenshot-backed suggestions.

## Next Gate

Run fresh no-skip Obsidian lanes after confirming no stale proof watchdog is active. The goal is still open: repeat 150+ strict screenshot-backed Obsidian attempts before raising every category to 100/100.
