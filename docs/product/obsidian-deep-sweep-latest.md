# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T07:46:39Z
- Recorded attempts: 7
- Lanes: obsidian obsidian-theme obsidian-pane obsidian-long-note obsidian-font-zoom obsidian-markdown-bold obsidian-markdown-list obsidian-multiline obsidian-run-on

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |
| 1 | `obsidian` | `pass` | `script/real_app_smoke.sh obsidian --manual-gate` |
| 1 | `obsidian-theme` | `pass` | `script/real_app_smoke.sh obsidian-theme --manual-gate --skip-build` |
| 1 | `obsidian-pane` | `pass` | `script/real_app_smoke.sh obsidian-pane --manual-gate --skip-build` |
| 1 | `obsidian-long-note` | `fail` | `script/real_app_smoke.sh obsidian-long-note --manual-gate --skip-build` |
| 2 | `obsidian-long-note` | `fail` | `AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR=/tmp/autocomplete-lab-obsidian-long-note-clean2.lock script/real_app_smoke.sh obsidian-long-note --manual-gate` |
| 3 | `obsidian-long-note` | `fail` | `AUTOCOMPLETE_LAB_REAL_APP_DIRECT_LAUNCH=0 script/real_app_smoke.sh obsidian-long-note --manual-gate` |
| 4 | `obsidian-long-note` | `fail` | `script/real_app_smoke.sh obsidian-long-note --manual-gate --skip-build` |
| 5 | `obsidian-long-note` | `fail` | `AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR=/tmp/autocomplete-lab-obsidian-long-note-resume.lock script/real_app_smoke.sh obsidian-long-note --manual-gate` |
| 6 | `obsidian-long-note` | `fail` | `AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR=/tmp/autocomplete-lab-obsidian-long-note-after-tab-close.lock script/real_app_smoke.sh obsidian-long-note --manual-gate` |
| 7 | `obsidian-long-note` | `core-pass-runner-sigterm` | `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR=/tmp/autocomplete-lab-obsidian-long-note-optiontab-proof4.lock script/real_app_smoke.sh obsidian-long-note --manual-gate` |

Latest note: current branch reaches Obsidian visible-tail suggestion presentation and screenshot capture, and logs verified insertions for Tab and Option-Tab full accept. Iteration 7 ended with `/Users/redbars/Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md` and the live Computer Use view both showing `Smoke proof feels instant and stays instant`. The wrapper still exited 143/SIGTERM after proof, so this is recorded as a core behavior pass with a runner blocker, not a clean strict pass.
