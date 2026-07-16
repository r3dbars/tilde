#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

READINESS_SCRIPT="script/check_controls_diagnostics_readiness.sh"

require_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$path"; then
    echo "missing expected readiness proof text in $path: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local path="$1"
  local rejected="$2"
  if grep -Fq "$rejected" "$path"; then
    echo "unsafe or stale readiness proof text remains in $path: $rejected" >&2
    exit 1
  fi
}

require_contains "$READINESS_SCRIPT" 'run_logged_check "Redacted report export"'
require_contains "$READINESS_SCRIPT" 'check_controls_diagnostics_readiness_self_test.sh'
require_contains "$READINESS_SCRIPT" 'DiagnosticsTypingHealthTests'
require_contains "$READINESS_SCRIPT" 'RawTraceReportExportTests'
require_contains "$READINESS_SCRIPT" "SwiftPM module SDK mismatch detected; cleaning package cache and retrying controls tests."
require_contains "$READINESS_SCRIPT" 'swift package clean'
reject_contains "$READINESS_SCRIPT" 'Current build privacy export proof'
reject_contains "$READINESS_SCRIPT" 'PrivacyExportProofCommandTests'
reject_contains "$READINESS_SCRIPT" 'check_current_build_privacy_export.sh'

echo "Controls diagnostics readiness self-test passed."
