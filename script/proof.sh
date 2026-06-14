#!/usr/bin/env bash
# proof.sh — pre-merge gate for SteadyType.
#
# Usage:
#   ./script/proof.sh fast    # Run cheap checks; exits non-zero if any fail.
#
# "fast" composes the existing check scripts — no logic is reimplemented here.
# Swift tests require macOS + the full toolchain; this script is not Linux-safe.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-}"

usage() {
  echo "Usage: $0 fast" >&2
  exit 1
}

run_fast() {
  local failed=0

  echo "==> swift test"
  swift test --jobs 1 || failed=1

  echo ""
  echo "==> check_test_coverage_manifest"
  ./script/check_test_coverage_manifest.sh || failed=1

  echo ""
  echo "==> check_proof_manifest"
  ./script/check_proof_manifest.sh || failed=1

  echo ""
  echo "==> git diff --check (no whitespace errors)"
  git diff --check || failed=1

  if [[ "$failed" -ne 0 ]]; then
    echo "" >&2
    echo "proof fast: one or more checks failed." >&2
    exit 1
  fi

  echo ""
  echo "proof fast: all checks passed."
}

case "$MODE" in
  fast) run_fast ;;
  *) usage ;;
esac
