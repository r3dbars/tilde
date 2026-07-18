#!/usr/bin/env bash
# Release gate — run on macOS before cutting a release build.
#
# Usage:
#   script/release_check.sh [--release]
#
# Lanes (all blocking):
#   1. build_and_run.sh --verify   the app bundle builds and validates
#   2. check_app_bundle.sh         bundle shape, signature, hardened runtime
#                                  (--release also requires Developer ID)
#   3. check_model_asset.py        the app-owned MLX model asset is present + intact
#   4. check_runtime_network_egress.py
#                                  the running app opens no unexpected network
#                                  sockets — the privacy promise, observed live.
#                                  Requires SteadyType to be running; launch it and
#                                  type in a few apps while this samples.
#
# This replaces the old beta_readiness.sh. Cheap pre-merge checks live in
# script/proof.sh (CI + pre-push).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --release) RELEASE_FLAG="--release" ;;
    -h | --help)
      awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "release_check.sh: unknown option '$arg'" >&2
      exit 2
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "release_check.sh: this gate needs macOS (builds the app bundle and observes the live process)." >&2
  exit 2
fi

echo "== [1/4] build + verify app bundle =="
./script/build_and_run.sh --verify

echo
echo "== [2/4] app bundle shape / signature =="
if [ -n "$RELEASE_FLAG" ]; then
  ./script/check_app_bundle.sh "$RELEASE_FLAG"
else
  ./script/check_app_bundle.sh
fi

echo
echo "== [3/4] model asset =="
python3 script/check_model_asset.py

echo
echo "== [4/4] runtime network egress (privacy proof) =="
if ! pgrep -x SteadyType >/dev/null 2>&1; then
  echo "SteadyType is not running. Launch the built app (./script/build_and_run.sh)," >&2
  echo "type in a couple of apps so autocomplete is exercised, then re-run this gate." >&2
  exit 1
fi
python3 script/check_runtime_network_egress.py --phase autocomplete --duration 120

echo
echo "PASS: release gate green (bundle, model asset, no runtime network egress)."
