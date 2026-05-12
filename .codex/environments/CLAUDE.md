# Claude Code Guide

Environment action files live here.

Use this folder when changing how Codex launches or verifies the app locally.

Rules:

- Keep the Run action pointed at `./script/build_and_run.sh`.
- Avoid duplicate actions that do the same job.
- Prefer project scripts over long inline shell commands.
- If an action depends on a model, make that dependency explicit in the action label or docs.
