# Script Folder Guide

Project-local build and run scripts live here.

- Keep `steadytype` as the public command facade with exactly five operations:
  `build`, `test`, `smoke`, `eval`, and `release`. Validate its dispatch with
  `steadytype_self_test.sh`.
- Keep `build_and_run.sh`, `proof.sh`, `smoke_test.sh`,
  `check_quality_eval.sh`, and `package_release.sh` as the initial internal
  implementations behind those operations.
- Keep `proof.sh` green and fast (target < ~10 min). CI and the pre-push hook
  still call that internal entrypoint directly.
- Keep `beta_readiness.sh` as the internal full local pre-beta gate.
- The script may build and launch the app, but product UX must not require users to run model servers.
