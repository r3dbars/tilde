# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T09:52:28Z
- Mode: one-pass sweep attempted, then direct-lane fallback because stale proof jobs kept sending SIGTERM
- Lanes: obsidian obsidian-theme obsidian-long-note obsidian-font-zoom obsidian-markdown-bold obsidian-markdown-list obsidian-multiline obsidian-run-on obsidian-pane

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |
| 1 | `obsidian` | `wrapper-sigterm; direct-pass` | `script/obsidian_deep_sweep.sh --iterations 1`; fallback `script/real_app_smoke.sh obsidian --manual-gate` |
| 1 | `obsidian-theme` | `direct-pass` | `script/real_app_smoke.sh obsidian-theme --manual-gate` |
| 1 | `obsidian-long-note` | `direct-pass` | `script/real_app_smoke.sh obsidian-long-note --manual-gate` |
| 1 | `obsidian-font-zoom` | `direct-pass` | `script/real_app_smoke.sh obsidian-font-zoom --manual-gate` |
| 1 | `obsidian-markdown-bold` | `direct-pass` | `script/real_app_smoke.sh obsidian-markdown-bold --manual-gate` |
| 1 | `obsidian-markdown-list` | `runner-blocked` | `script/real_app_smoke.sh obsidian-markdown-list --manual-gate` |
| 1 | `obsidian-multiline` | `not-rerun-after-reset-fix` | `script/real_app_smoke.sh obsidian-multiline --manual-gate` |
| 1 | `obsidian-run-on` | `not-rerun-after-reset-fix` | `script/real_app_smoke.sh obsidian-run-on --manual-gate` |
| 1 | `obsidian-pane` | `historical-pass; moved-last` | `script/real_app_smoke.sh obsidian-pane --manual-gate` |

## Summary

- Direct strict passes recorded this pass: default, theme, font/zoom, bold Markdown.
- Current-branch long-note strict pass recorded earlier in this pass at 09:34 UTC.
- List reached `suggestion-presented ... app=md.obsidian ... afterChars=0` in LaunchServices mode, but strict screenshot proof failed there because Screen Recording was blocked.
- The matrix is not 100/100 yet. The next loop should first eliminate stale `25ed`/abandoned proof runners, then rerun list, multiline, run-on, pane-last, and repeated sweeps.
