# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T06:55:33Z
- Iterations: 1
- Lanes: obsidian-font-zoom obsidian-markdown-bold obsidian-markdown-list obsidian-multiline obsidian-run-on

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |
| 1 | `obsidian-font-zoom` | `fail` | `script/real_app_smoke.sh obsidian-font-zoom --manual-gate` |

## Summary

- Attempts recorded: 1
- Passes: 0
- Failures: 1
- Blocker: `obsidian-font-zoom` did not reach verified Tab acceptance. The zoomed Obsidian editor exposed the smoke marker with a visual/AX line break and the first run placed typed text before `Obsidian proof` instead of at the true visual end.
- Interference: a stale `25ed` TextEdit latency loop later spawned a watchdog that killed this `390d` worktree during the same sweep window, so remaining lanes were not validly attempted in this report.
