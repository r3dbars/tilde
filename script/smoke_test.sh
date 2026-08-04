#!/usr/bin/env bash
# Local smoke test: resolve, patch, test, and verify the app bundle builds.
# Heavier than proof.sh (runs the full Swift suite + a bundle build); run it
# when you want end-to-end confidence on macOS without launching the app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift package resolve
./script/patch_mlx_swift_lm.sh
swift test --jobs 1
./script/build_and_run.sh --verify

echo "smoke_test: PASS"
