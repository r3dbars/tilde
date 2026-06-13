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
    echo "missing expected beta proof close-out text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local file="$1"
  local rejected="$2"
  if grep -Fq -- "$rejected" "$file"; then
    echo "unsafe beta proof close-out text is present: $rejected" >&2
    exit 1
  fi
}

script/beta_proof_closeout.sh --help >"$TMP_DIR/help.txt"
require_contains "$TMP_DIR/help.txt" "Front-door beta proof close-out command"
require_contains "$TMP_DIR/help.txt" "It does not cut, notarize, publish, deploy"
require_contains "$TMP_DIR/help.txt" "--run-packaged-latency"

script/beta_proof_closeout.sh --print-plan >"$TMP_DIR/plan.txt"
require_contains "$TMP_DIR/plan.txt" "./script/check_onboarding_walkthrough_proof.py"
require_contains "$TMP_DIR/plan.txt" "./script/check_onboarding_permission_qa.sh --check"
require_contains "$TMP_DIR/plan.txt" "5 consecutive green dogfood days"
require_contains "$TMP_DIR/plan.txt" "3-5 testers"

script/beta_proof_closeout.sh --dry-run --app-bundle /tmp/SteadyType.app >"$TMP_DIR/dry-run.txt"
require_contains "$TMP_DIR/dry-run.txt" "Beta proof close-out front door"
require_contains "$TMP_DIR/dry-run.txt" "+ ./script/check_onboarding_walkthrough_proof.py"
require_contains "$TMP_DIR/dry-run.txt" "+ ./script/check_onboarding_permission_qa.sh --check"
require_contains "$TMP_DIR/dry-run.txt" "+ ./script/packaged_latency_proof.sh textedit-model-latency --app-bundle /tmp/SteadyType.app --dry-run"
require_contains "$TMP_DIR/dry-run.txt" "Packaged latency proof not observed in this pass."
require_contains "$TMP_DIR/dry-run.txt" "invite 3-5 testers only after those 5 rows stay green"

script/beta_proof_closeout.sh --dry-run --target claude-model-latency >"$TMP_DIR/claude.txt"
require_contains "$TMP_DIR/claude.txt" "Target: claude-model-latency"
require_contains "$TMP_DIR/claude.txt" "packaged_latency_proof.sh claude-model-latency"

SCRIPT_TEXT="$TMP_DIR/script.txt"
cat script/beta_proof_closeout.sh >"$SCRIPT_TEXT"
require_contains "$SCRIPT_TEXT" "set -euo pipefail"
require_contains "$SCRIPT_TEXT" "check_onboarding_walkthrough_proof.py"
require_contains "$SCRIPT_TEXT" "packaged_latency_proof.sh"
reject_contains "$SCRIPT_TEXT" "package_release.sh --notarize"
reject_contains "$SCRIPT_TEXT" "notarytool submit"
reject_contains "$SCRIPT_TEXT" "gh pr merge"

echo "Beta proof close-out self-test passed."
