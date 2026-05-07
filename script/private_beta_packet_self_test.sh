#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FEEDBACK_TEMPLATE="$(./script/private_beta_packet.sh --print-feedback-template)"
SESSION_TEMPLATE="$(./script/private_beta_packet.sh --print-session-report-template)"

require_contains() {
  local text="$1"
  local expected="$2"
  if ! grep -Fq "$expected" <<<"$text"; then
    echo "missing expected beta packet copy: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local text="$1"
  local rejected="$2"
  if grep -Fq "$rejected" <<<"$text"; then
    echo "unsafe beta packet copy is still present: $rejected" >&2
    exit 1
  fi
}

require_contains "$FEEDBACK_TEMPLATE" "Use one short row per real writing session."
require_contains "$FEEDBACK_TEMPLATE" "Do not include raw typed text"
require_contains "$FEEDBACK_TEMPLATE" "trace excerpts"
require_contains "$FEEDBACK_TEMPLATE" "Redacted report exported?"
require_contains "$FEEDBACK_TEMPLATE" "Notes (no private text)"

require_contains "$SESSION_TEMPLATE" 'Use one short row in `feedback-log.md` after each real beta writing session.'
require_contains "$SESSION_TEMPLATE" "Do not paste raw typed text"
require_contains "$SESSION_TEMPLATE" "Copy only redacted repeated-miss titles"
require_contains "$SESSION_TEMPLATE" "one short disposable sentence"

reject_contains "$SESSION_TEMPLATE" "Copy the top repeated misses from Diagnostics or the trace eval report."
reject_contains "$SESSION_TEMPLATE" "type one short sentence"

echo "Private beta packet self-test passed."
