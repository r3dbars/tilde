# Obsidian Deep Sweep Latest

- Started UTC: 2026-05-13T11:36:24Z
- Iterations: 1
- Lanes: obsidian obsidian-theme obsidian-pane

| Iteration | Lane | Result | Command |
| ---: | --- | --- | --- |

## Summary

- The focused subset sweep started at `2026-05-13T11:36:24Z`, but it did not produce trustworthy lane rows.
- It reached the `obsidian-theme` lane and showed the old failure mode again: a stale `25ed` SteadyType app instance (`/Users/redbars/.codex/worktrees/25ed/.../dist/SteadyType.app`) entered the proof process group and the lane stopped producing a clean result.
- Diagnostics around `2026-05-13T11:40:01Z` showed Obsidian suggestions and screenshot capture, but then focus returned to Codex and the field fell into typed-over / quiet-mode behavior. This is not a valid pass.
- The runner was patched after this miss so exclusive proof runs terminate stale SteadyType app bundles from other worktrees while waiting for the current app and while the interference guard is active.
- The sweep wrapper also no longer overrides `AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR` per lane; future matrix runs should serialize through the shared real-app smoke lock instead of letting overlapping Obsidian proof lanes kill each other.
- A lingering `manual_proof_refresh.sh --run --target obsidian-theme` process group from the old `25ed` checkout was found and terminated; it was the source of the repeated stale app/runtime spawns during this pass.
- After cleanup, the current checkout rebuilt `dist/SteadyType.app` successfully with `script/build_and_run.sh bundle-only`.
- The goal is still open. This is not a 150+ attempt reliability sample and not a 100/100 Obsidian result.

## Next Gate

Rerun at least default/theme/pane with the stale-app guard and shared smoke lock active, then expand back to long-note/font-zoom/bold/list/multiline/run-on.
