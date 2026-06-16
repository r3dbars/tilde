# Claude Code Guide

Local automation scripts live here.

Start with:

- `proof.sh fast` for the fast proof gate — the cheap pre-merge tier (what CI runs on PRs to `main`, and the `.githooks/pre-push` hook runs on push). Validated by `proof_self_test.sh`.
- `build_and_run.sh` for running the app.
- `smoke_test.sh` if present, or the focused `*_self_test.sh` scripts for script validation.
- `beta_readiness.sh` for the broad pre-beta gate.
- `check_proof_manifest.sh`, `check_score_targets.sh`, and related `check_*` scripts for proof claims.

Rules:

- Keep scripts privacy-first and local by default.
- Product UX must not require users to run model servers.
- Every new script should have a narrow purpose and, when practical, a `*_self_test.sh`.
- Avoid printing raw typed text, clipboard contents, prompts, URLs, or document names.
