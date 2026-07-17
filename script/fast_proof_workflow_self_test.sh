#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/fast-proof.yml"

require_line() {
  local pattern="$1"
  if ! grep -Fqx "$pattern" "$WORKFLOW"; then
    echo "fast proof workflow self-test: missing '$pattern'" >&2
    exit 1
  fi
}

require_line "  workflow_dispatch:"
require_line "  manual-fast-proof:"
require_line "  manual-fast-proof-macos:"

if grep -Eq '^  (pull_request|push):' "$WORKFLOW"; then
  echo "fast proof workflow self-test: hosted workflow must not trigger on PRs or pushes" >&2
  exit 1
fi

if grep -Eq '^  (fast-proof|fast-proof-macos):' "$WORKFLOW"; then
  echo "fast proof workflow self-test: old required-gate job names remain" >&2
  exit 1
fi

[ "$(grep -Fc 'run: bash script/proof.sh fast' "$WORKFLOW")" -eq 2 ]
[ "$(grep -Fc 'PROOF_DIFF_BASE: origin/main' "$WORKFLOW")" -eq 2 ]
[ "$(grep -Fc 'uses: actions/setup-python@v5' "$WORKFLOW")" -eq 2 ]

echo "fast proof workflow self-test: PASS"
