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
    echo "missing expected detached Ghostty proof text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local file="$1"
  local rejected="$2"
  if grep -Fq -- "$rejected" "$file"; then
    echo "unsafe detached Ghostty proof text is present: $rejected" >&2
    exit 1
  fi
}

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh --help >"$TMP_DIR/help.txt"
require_contains "$TMP_DIR/help.txt" "start|status|wait|tail"
require_contains "$TMP_DIR/help.txt" "outside the Codex"
require_contains "$TMP_DIR/help.txt" "custom proof text"
require_contains "$TMP_DIR/help.txt" "LaunchAgent"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/dry-run.txt"
require_contains "$TMP_DIR/dry-run.txt" "Dry run only; detached Ghostty proof would run:"
require_contains "$TMP_DIR/dry-run.txt" "Launcher: launchd"
require_contains "$TMP_DIR/dry-run.txt" "LaunchAgent:"
require_contains "$TMP_DIR/dry-run.txt" "launchctl bootstrap"
require_contains "$TMP_DIR/dry-run.txt" "script/real_app_smoke.sh claude-code-ghostty --manual-gate"
require_contains "$TMP_DIR/dry-run.txt" "proof.log"
require_contains "$TMP_DIR/dry-run.txt" "status.env"

FAKE_RUN="$TMP_DIR/proofs/fake-run"
mkdir -p "$FAKE_RUN"
cat >"$FAKE_RUN/status.env" <<EOF
state=passed
pid=999999
started_at=2026-05-27T00:00:00Z
finished_at=2026-05-27T00:00:01Z
exit_status=0
run_dir=$FAKE_RUN
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'fake detached log\n' >"$FAKE_RUN/proof.log"
printf '%s\n' "$FAKE_RUN" >"$TMP_DIR/proofs/latest-run.txt"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status >"$TMP_DIR/status.txt"
require_contains "$TMP_DIR/status.txt" "state=passed"
require_contains "$TMP_DIR/status.txt" "runner_process=not-running"
require_contains "$TMP_DIR/status.txt" "script/real_app_smoke.sh claude-code-ghostty --manual-gate"

PENDING_RUN="$TMP_DIR/proofs/pending-run"
mkdir -p "$PENDING_RUN"
cat >"$PENDING_RUN/status.env" <<EOF
state=starting
pid=
started_at=2026-05-27T00:00:02Z
run_dir=$PENDING_RUN
launcher=launchd
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'pending detached log\n' >"$PENDING_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$PENDING_RUN" >"$TMP_DIR/pending-status.txt"
require_contains "$TMP_DIR/pending-status.txt" "runner_process=pending"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh tail >"$TMP_DIR/tail.txt"
require_contains "$TMP_DIR/tail.txt" "fake detached log"

SCRIPT_TEXT="$TMP_DIR/script.txt"
cp script/claude_code_ghostty_detached_proof.sh "$SCRIPT_TEXT"
require_contains "$SCRIPT_TEXT" "launchctl bootstrap"
require_contains "$SCRIPT_TEXT" "<key>EnvironmentVariables</key>"
require_contains "$SCRIPT_TEXT" "cleanup_launchd_job_if_terminal"
require_contains "$SCRIPT_TEXT" 'nohup "$runner_script"'
require_contains "$SCRIPT_TEXT" 'AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN="${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-1}"'
require_contains "$SCRIPT_TEXT" 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE="${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-1}"'
require_contains "$SCRIPT_TEXT" "./script/real_app_smoke.sh claude-code-ghostty --manual-gate"
require_contains "$SCRIPT_TEXT" "custom proof text is not persisted here"
reject_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_TEXTS="
reject_contains "$SCRIPT_TEXT" "Make this setting the feature"

if AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh unknown >/dev/null 2>&1; then
  echo "detached Ghostty proof should reject unknown modes" >&2
  exit 1
fi

echo "Detached Ghostty proof self-test passed."
