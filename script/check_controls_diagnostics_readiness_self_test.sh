#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

READINESS_SCRIPT="script/check_controls_diagnostics_readiness.sh"
PRIVACY_SCRIPT="script/check_current_build_privacy_export.sh"

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

require_contains "$READINESS_SCRIPT" 'run_logged_check "Current build privacy export proof"'
require_contains "$READINESS_SCRIPT" 'check_controls_diagnostics_readiness_self_test.sh'
require_contains "$READINESS_SCRIPT" 'DiagnosticsTypingHealthTests'
require_contains "$READINESS_SCRIPT" "SwiftPM module SDK mismatch detected; cleaning package cache and retrying controls tests."
require_contains "$READINESS_SCRIPT" 'swift package clean'
reject_contains "$READINESS_SCRIPT" 'run_check "Current build privacy export proof"'

require_contains "$PRIVACY_SCRIPT" 'BUILD_LOG=/tmp/autocomplete-current-build-privacy-build.log'
require_contains "$PRIVACY_SCRIPT" 'AUTOCOMPLETE_LAB_PRIVACY_EXPORT_LOCK_DIR'
require_contains "$PRIVACY_SCRIPT" 'current build privacy export is already active'
require_contains "$PRIVACY_SCRIPT" 'Waiting for active proof process before current build privacy export.'
require_contains "$PRIVACY_SCRIPT" 'failed to build app bundle for privacy export proof'
require_contains "$PRIVACY_SCRIPT" 'steadytype-privacy-build.XXXXXX'
require_contains "$PRIVACY_SCRIPT" 'AUTOCOMPLETE_LAB_DIST_DIR="$(dirname "$APP_BUNDLE")"'
require_contains "$PRIVACY_SCRIPT" 'find "$OUTPUT_DIR" \( -name '\''traces.jsonl'\'' -o -name '\''raw-traces.jsonl'\'' \)'
require_contains "$PRIVACY_SCRIPT" 'proof-private-|private\.example|private-screenshot|private-recipient|private document|private subject'
require_contains "$PRIVACY_SCRIPT" '"$OUTPUT_DIR/privacy-export/redacted-traces.jsonl"'
reject_contains "$PRIVACY_SCRIPT" 'index(command, "script/check_controls_diagnostics_readiness.sh")'
reject_contains "$PRIVACY_SCRIPT" 'index(command, "script/check_current_build_privacy_export.sh")'
reject_contains "$PRIVACY_SCRIPT" '| tee /tmp/autocomplete-current-build-privacy-build.log'

echo "Controls diagnostics readiness self-test passed."
