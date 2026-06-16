# Agent Guide

Opt-in git hooks for this repo. They are tracked so the whole team shares one
gate, but they only run after a developer enables them:

    git config core.hookspath .githooks

- `pre-push` delegates to `script/proof.sh fast` (the fast proof gate) and blocks
  a push when a blocking check is red. Bypass with `git push --no-verify`.

Keep hooks thin: delegate to a `script/` entry point, stay fast, stay
privacy-first (no raw typed text, prompts, or model output in output).
