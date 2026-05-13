#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_TEXT="$(cat script/build_and_run.sh)"

require_contains() {
  local expected="$1"
  if ! grep -Fq -- "$expected" <<<"$SCRIPT_TEXT"; then
    echo "missing expected build/run script text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local rejected="$1"
  if grep -Fq -- "$rejected" <<<"$SCRIPT_TEXT"; then
    echo "stale build/run script reference remains: $rejected" >&2
    exit 1
  fi
}

require_contains "stop_running_apps()"
require_contains "open_app()"
require_contains "running_app_process_rows()"
require_contains "command_matches_binary()"
require_contains "current_bundle_is_running()"
require_contains "current_bundle_pid()"
require_contains "pid_is_current_bundle()"
require_contains "quarantine_stale_app_bundles"
require_contains "AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES"
require_contains "AUTOCOMPLETE_LAB_MOVE_STALE_APP_BUNDLES"
require_contains "AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN"
require_contains "AUTOCOMPLETE_LAB_DIST_DIR"
require_contains "wait_for_proof_locks_if_needed"
require_contains "AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE"
require_contains "Waiting for active proof run before build/run relaunch."
require_contains '--privacy-export-proof([[:space:]]|$)'
require_contains "scrub_proof_model_root_if_needed"
require_contains "AUTOCOMPLETE_LAB_ALLOW_PROOF_MODEL_ROOT"
require_contains "unset AUTOCOMPLETE_LAB_MODEL_ROOT"
require_contains "launchctl unsetenv AUTOCOMPLETE_LAB_MODEL_ROOT"
require_contains "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
require_contains "AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION"
require_contains "AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
require_contains "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK"
require_contains "AUTOCOMPLETE_LAB_PROOF_SCENARIO"
require_contains "AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING"
require_contains 'current_pid="$(current_bundle_pid || true)"'
require_contains 'pid_is_current_bundle "$current_pid"'
require_contains "exited or restarted during the verification stability window"
require_contains 'command ~ ("^/.*/" app_name "\\.app/Contents/MacOS/" app_name "([[:space:]]|$)")'
require_contains 'command_matches_binary "$command" "$APP_BINARY"'
reject_contains "pgrep -f"
reject_contains 'pkill -x "$APP_NAME"'
reject_contains "kill_running_app_instances"
reject_contains "is_target_app_running"

if grep -Fq "AUTOCOMPLETE_LAB_MOVE_STALE_APP_BUNDLES=1" script/real_app_smoke.sh; then
  echo "real app smoke should not move sibling worktree app bundles during proof runs" >&2
  exit 1
fi

echo "Build and run self-test passed."
