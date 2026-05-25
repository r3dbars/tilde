#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "missing expected packaged latency proof text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local file="$1"
  local rejected="$2"
  if grep -Fq -- "$rejected" "$file"; then
    echo "unsafe packaged latency proof text is present: $rejected" >&2
    exit 1
  fi
}

script/packaged_latency_proof.sh --help >"$TMP_DIR/help.txt"
require_contains "$TMP_DIR/help.txt" "accessibility-permission-lost"
require_contains "$TMP_DIR/help.txt" "bar.r3d.steadytype"
require_contains "$TMP_DIR/help.txt" "This script cannot grant macOS Accessibility"

script/packaged_latency_proof.sh --dry-run >"$TMP_DIR/dry-run.txt"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1"
require_contains "$TMP_DIR/dry-run.txt" "--skip-build"
require_contains "$TMP_DIR/dry-run.txt" "launchctl setenv AUTOCOMPLETE_LAB_PROOF_SCENARIO claude-model-latency"
require_contains "$TMP_DIR/dry-run.txt" "com.anthropic.claudefordesktop"
require_contains "$TMP_DIR/dry-run.txt" "select_latency_window.py"
require_contains "$TMP_DIR/dry-run.txt" "--expected-executable-sha256"
require_contains "$TMP_DIR/dry-run.txt" "--app-binary"
require_contains "$TMP_DIR/dry-run.txt" "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

SCRIPT_TEXT="$TMP_DIR/script.txt"
cat script/packaged_latency_proof.sh >"$SCRIPT_TEXT"
require_contains "$SCRIPT_TEXT" "set -euo pipefail"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1"
require_contains "$SCRIPT_TEXT" "accessibility-permission-lost"
require_contains "$SCRIPT_TEXT" "This script cannot grant Accessibility or edit TCC directly."
reject_contains "$SCRIPT_TEXT" "TCC.db"
reject_contains "$SCRIPT_TEXT" "tccutil reset"

echo "Packaged latency proof self-test passed."
