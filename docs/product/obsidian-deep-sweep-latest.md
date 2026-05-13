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
| 1 | `obsidian-markdown-list` | `direct-pass` | `script/real_app_smoke.sh obsidian-markdown-list --manual-gate` |
| 1 | `obsidian-multiline` | `direct-pass` | `script/real_app_smoke.sh obsidian-multiline --manual-gate` |
| 1 | `obsidian-run-on` | `direct-pass` | `script/real_app_smoke.sh obsidian-run-on --manual-gate` |
| 1 | `obsidian-pane` | `direct-red; insertion verified, strict visual/annoyance failed` | `script/real_app_smoke.sh obsidian-pane --manual-gate` |

## Summary

- Direct strict passes recorded this pass: default, theme, font/zoom, bold Markdown, list, multiline, run-on.
- Current-branch long-note strict pass recorded earlier in this pass at 09:34 UTC.
- Pane is the current red lane: the latest reruns verified accepted text insertion, but extra typed-over suggestions made strict visual evidence and annoyance scoring fail.
- The old `25ed` watchdog process group that killed `390d` proof jobs was found and terminated. The next loop should fix pane noise, then run repeated sweeps toward the 150+ sample target.
