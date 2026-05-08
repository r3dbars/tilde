#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FEEDBACK_TEMPLATE="$(./script/private_beta_packet.sh --print-feedback-template)"
SESSION_TEMPLATE="$(./script/private_beta_packet.sh --print-session-report-template)"
MODEL_TEMPLATE="$(./script/private_beta_packet.sh --print-model-asset-template "/tmp/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit")"

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

require_contains "$MODEL_TEMPLATE" "The private beta is not ready if the app falls back to mock output."
require_contains "$MODEL_TEMPLATE" "Confirm Settings says the model is ready."
require_contains "$MODEL_TEMPLATE" 'use the Settings `Install'
require_contains "$MODEL_TEMPLATE" "If that in-app setup"
require_contains "$MODEL_TEMPLATE" "stop the beta session"
require_contains "$MODEL_TEMPLATE" "Do not ask testers to run Python, shell scripts, Ollama, llama.cpp, or any"
require_contains "$MODEL_TEMPLATE" "/tmp/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit"

reject_contains "$MODEL_TEMPLATE" "python3 -m pip install"
reject_contains "$MODEL_TEMPLATE" "./script/download_mlx_model.py"
reject_contains "$MODEL_TEMPLATE" "./script/check_model_asset.py"
reject_contains "$MODEL_TEMPLATE" "Developer fallback"
reject_contains "$MODEL_TEMPLATE" "operator fixes"

SCRIPT_TEXT="$(sed -n '1,260p' script/private_beta_packet.sh)"

for expected_doc in \
  "PRIVACY-BETA.md" \
  "KNOWN-LIMITATIONS.md" \
  "UNINSTALL-DELETE-DATA.md" \
  "DIAGNOSTIC-EXPORT.md" \
  "RELEASE-NOTES.md" \
  ".github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml"; do
  require_contains "$SCRIPT_TEXT" "$expected_doc"
done

echo "Private beta packet self-test passed."
