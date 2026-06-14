# Script Folder Guide

Project-local build and run scripts live here.

- Keep `build_and_run.sh` as the main app entrypoint.
- Keep `proof.sh` as the fast proof gate — the cheap pre-merge tier. CI runs `proof.sh fast` on every PR to `main`, and the `.githooks/pre-push` hook runs it on push. It must stay green and fast (target < ~10 min); validate it with `proof_self_test.sh`.
- Keep `smoke_test.sh` as the fast local verification entrypoint.
- Keep `package_release.sh` as the local release archive and notarization-readiness entrypoint.
- Keep `beta_readiness.sh` as the full local pre-beta gate.
- The script may build and launch the app, but product UX must not require users to run model servers.
