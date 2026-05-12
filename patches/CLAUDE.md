# Claude Code Guide

Local dependency patches live here.

Start with `mlx-swift-lm/` for MLX-related patches.

Rules:

- Treat patches as temporary and explicit.
- Keep each patch tied to a dependency version or upstream issue when possible.
- Prefer fixing app code over patching dependencies unless the dependency behavior is the real blocker.
- Re-run package resolution and relevant runtime tests after patch changes.
