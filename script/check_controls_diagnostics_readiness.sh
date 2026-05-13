#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0
proof_output="$(mktemp -d)"
LOG_DIR="$(mktemp -d)"
SWIFT_TEST_ARGS=()
SWIFT_TEST_ARGS_CONFIGURED=0
CURRENT_BUILD_ENV=(
  AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT="$proof_output"
  AUTOCOMPLETE_LAB_REBUILD_PRIVACY_PROOF=1
)

if [[ -n "${AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH:-}" ]]; then
  SWIFT_SCRATCH_PATH="$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"
  mkdir -p "$SWIFT_SCRATCH_PATH"
  SWIFT_TEST_ARGS=(--scratch-path "$SWIFT_SCRATCH_PATH/swift-tests")
  SWIFT_TEST_ARGS_CONFIGURED=1
  CURRENT_BUILD_ENV+=(AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH="$SWIFT_SCRATCH_PATH/current-build")
fi

cleanup() {
  rm -rf "$proof_output" "$LOG_DIR"
}
trap cleanup EXIT

run_check() {
  local label="$1"
  shift

  echo
  echo "== $label =="
  if "$@"; then
    echo "$label: OK"
    return 0
  fi

  echo "$label: blocked" >&2
  return 1
}

run_logged_check() {
  local label="$1"
  shift
  local log_path="$LOG_DIR/$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_').log"

  echo
  echo "== $label =="
  if "$@" >"$log_path" 2>&1; then
    echo "$label: OK"
    return 0
  fi

  echo "$label: blocked" >&2
  cat "$log_path" >&2
  return 1
}

require_executable() {
  local path="$1"

  if [[ ! -x "$path" ]]; then
    echo "required readiness script is missing or not executable: $path" >&2
    return 1
  fi
}

run_swift_tests() {
  local filter="$1"
  local first_attempt_log="$LOG_DIR/swift-controls-first-attempt.log"

  if [[ "$SWIFT_TEST_ARGS_CONFIGURED" == "1" ]]; then
    swift test "${SWIFT_TEST_ARGS[@]}" --filter "$filter" >"$first_attempt_log" 2>&1 && return 0
  else
    swift test --filter "$filter" >"$first_attempt_log" 2>&1 && return 0
  fi

  local first_status=$?
  cat "$first_attempt_log" >&2

  if ! grep -E "cannot load module '.*' built with SDK '.*' when using SDK" "$first_attempt_log" >/dev/null; then
    return "$first_status"
  fi

  echo "SwiftPM module SDK mismatch detected; cleaning package cache and retrying controls tests." >&2
  swift package clean >&2
  if [[ "$SWIFT_TEST_ARGS_CONFIGURED" == "1" ]]; then
    swift test "${SWIFT_TEST_ARGS[@]}" --filter "$filter"
  else
    swift test --filter "$filter"
  fi
}

for script_path in \
  ./script/delete_local_traces.sh \
  ./script/delete_local_traces_self_test.sh \
  ./script/check_diagnostics_log_self_test.sh \
  ./script/check_controls_diagnostics_readiness_self_test.sh \
  ./script/check_redacted_report_export.sh \
  ./script/check_current_build_privacy_export.sh; do
  run_check "Executable $(basename "$script_path")" require_executable "$script_path" || failures=$((failures + 1))
done

CONTROL_FILTER='SettingsWindowControllerStateTests|DiagnosticsWindowControllerStateTests|DiagnosticsTypingHealthTests|SuggestionControlPolicyTests|SuggestionPauseSchedulePolicyTests|DisabledAppSelectionTests|RawTracePrivacyExpiryTests|RawTraceReportExportTests|PrivacyExportProofCommandTests'
run_logged_check "Swift controls and diagnostics tests" run_swift_tests "$CONTROL_FILTER" || failures=$((failures + 1))

run_logged_check "Delete local traces self-test" ./script/delete_local_traces_self_test.sh || failures=$((failures + 1))
run_logged_check "Diagnostics log self-test" ./script/check_diagnostics_log_self_test.sh || failures=$((failures + 1))
run_logged_check "Controls diagnostics readiness self-test" ./script/check_controls_diagnostics_readiness_self_test.sh || failures=$((failures + 1))
run_logged_check "Redacted report export" env \
  AUTOCOMPLETE_LAB_SWIFT_SKIP_BUILD=1 \
  ./script/check_redacted_report_export.sh || failures=$((failures + 1))

run_logged_check "Current build privacy export proof" env \
  "${CURRENT_BUILD_ENV[@]}" \
  ./script/check_current_build_privacy_export.sh || failures=$((failures + 1))

if ((failures > 0)); then
  echo
  echo "Controls and diagnostics readiness found $failures blocker(s)." >&2
  exit 1
fi

echo "Controls and diagnostics readiness passed."
