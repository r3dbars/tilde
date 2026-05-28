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
require_contains 'HELPER_NAME="SteadyTypeTextEventHelper"'
require_contains 'HELPER_BINARY="$APP_MACOS/$HELPER_NAME"'
require_contains 'ENTITLEMENTS_PLIST="$ROOT_DIR/script/SteadyType.entitlements"'
require_contains 'run_swift_build_product "$HELPER_NAME"'
require_contains 'BUILD_HELPER_BINARY="$(swift_build_bin_path)/$HELPER_NAME"'
require_contains 'cp "$BUILD_HELPER_BINARY" "$HELPER_BINARY"'
require_contains 'codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$HELPER_BINARY"'
require_contains 'codesign --force --options runtime --sign - "$HELPER_BINARY"'
require_contains '--entitlements "$ENTITLEMENTS_PLIST" --sign "$identity" "$APP_BUNDLE"'
require_contains '--entitlements "$ENTITLEMENTS_PLIST" --sign - "$APP_BUNDLE"'
require_contains 'SWIFT_BUILD_ROOT="${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build}"'
require_contains 'MLX_METALLIB="$SWIFT_BUILD_ROOT/mlx-metal/default.metallib"'
require_contains 'local mlx_checkout="$SWIFT_BUILD_ROOT/checkouts/mlx-swift"'
require_contains "wait_for_proof_locks_if_needed"
require_contains "AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE"
require_contains "print_proof_lock_status"
require_contains "--proof-lock-status"
require_contains "Waiting for active proof run before build/run relaunch."
require_contains "Timed out after \${PROOF_LOCK_WAIT_SECONDS}s waiting for active proof run"
require_contains "elapsed: \${elapsed:-unknown}"
require_contains "command: \${command:-unknown}"
require_contains "Retry after the proof run finishes"
require_contains "Fail fast instead of waiting"
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SMOKE_LOCK_DIR="$TMP_DIR/smoke.lock"
FRESH_LOCK_DIR="$TMP_DIR/fresh.lock"
mkdir -p "$SMOKE_LOCK_DIR"
echo "$$" >"$SMOKE_LOCK_DIR/pid"

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$SMOKE_LOCK_DIR" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$FRESH_LOCK_DIR" \
  script/build_and_run.sh --proof-lock-status >"$TMP_DIR/status-active.txt" 2>&1; then
  echo "build/run proof-lock status should return non-zero while a proof lock is active" >&2
  exit 1
fi

for expected in \
  "Proof lock status for SteadyType build/run:" \
  "real app smoke: active" \
  "pid: $$" \
  "elapsed:" \
  "command:" \
  "lock: $SMOKE_LOCK_DIR" \
  "Build/run would wait up to 300s before relaunching." \
  "Check lock status without launching: ./script/build_and_run.sh --proof-lock-status" \
  "Retry your original build/run command after the proof run finishes." \
  "Common retry: ./script/build_and_run.sh --verify" \
  "Fail fast instead of waiting by setting AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS=0 on the build/run command."; do
  if ! grep -F "$expected" "$TMP_DIR/status-active.txt" >/dev/null; then
    echo "build/run proof-lock status output missing: $expected" >&2
    exit 1
  fi
done

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$SMOKE_LOCK_DIR" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$FRESH_LOCK_DIR" \
  AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS=0 \
  script/build_and_run.sh --verify >"$TMP_DIR/lock-timeout.txt" 2>&1; then
  echo "build/run should fail closed instead of relaunching during an active proof lock" >&2
  exit 1
fi

for expected in \
  "Timed out after 0s waiting for active proof run; refusing to relaunch SteadyType." \
  "real app smoke: active" \
  "pid: $$" \
  "elapsed:" \
  "command:" \
  "Retry after the proof run finishes: ./script/build_and_run.sh --verify" \
  "Check lock status without launching: ./script/build_and_run.sh --proof-lock-status" \
  "Fail fast instead of waiting: AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS=0 ./script/build_and_run.sh --verify"; do
  if ! grep -F "$expected" "$TMP_DIR/lock-timeout.txt" >/dev/null; then
    echo "build/run proof-lock timeout output missing: $expected" >&2
    exit 1
  fi
done

rm -rf "$SMOKE_LOCK_DIR" "$FRESH_LOCK_DIR"

if ! AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$SMOKE_LOCK_DIR" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$FRESH_LOCK_DIR" \
  script/build_and_run.sh --proof-lock-status >"$TMP_DIR/status-clear.txt" 2>&1; then
  echo "build/run proof-lock status should pass when no proof locks are active" >&2
  exit 1
fi

for expected in \
  "real app smoke: idle" \
  "fresh latency proof: idle" \
  "No active proof locks. Build/run can proceed."; do
  if ! grep -F "$expected" "$TMP_DIR/status-clear.txt" >/dev/null; then
    echo "build/run clear proof-lock status output missing: $expected" >&2
    exit 1
  fi
done

echo "Build and run self-test passed."
