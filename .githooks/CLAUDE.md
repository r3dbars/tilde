# Claude Code Guide

Opt-in git hooks live here. Enable them for this clone with:

    git config core.hookspath .githooks

Start with:

- `pre-push` — runs `script/proof.sh fast` (the fast proof gate) before every push.

Rules:

- Hooks stay opt-in (`core.hookspath`) and bypassable (`git push --no-verify`).
- Keep hooks fast and privacy-first; never print raw typed text.
- A hook should delegate to a script under `script/`, not embed its own logic.
