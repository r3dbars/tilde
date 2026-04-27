# Script Folder Guide

Project-local build and run scripts live here.

- Keep `build_and_run.sh` as the main app entrypoint.
- Keep `smoke_test.sh` as the fast local verification entrypoint.
- Keep `package_release.sh` as the local release archive and notarization-readiness entrypoint.
- Keep `beta_readiness.sh` as the full local pre-beta gate.
- The script may build and launch the app, but product UX must not require users to run model servers.
