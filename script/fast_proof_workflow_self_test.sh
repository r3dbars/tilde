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

trigger_keys="$(awk '
  /^on:/ { in_triggers=1; next }
  /^permissions:/ { in_triggers=0 }
  in_triggers && /^  [[:alnum:]_-]+:/ {
    key = $1
    sub(/:$/, "", key)
    print key
  }
' "$WORKFLOW")"
if [ "$trigger_keys" != "workflow_dispatch" ]; then
  echo "fast proof workflow self-test: only workflow_dispatch may trigger hosted proof" >&2
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
