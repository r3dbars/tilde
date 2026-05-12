#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0
proof_output="$(mktemp -d)"
LOG_DIR="$(mktemp -d)"
SWIFT_TEST_ARGS=()
CURRENT_BUILD_ENV=(AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT="$proof_output")

if [[ -n "${AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH:-}" ]]; then
  SWIFT_SCRATCH_PATH="$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"
  mkdir -p "$SWIFT_SCRATCH_PATH"
  SWIFT_TEST_ARGS=(--scratch-path "$SWIFT_SCRATCH_PATH/swift-tests")
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

run_swift_test() {
  local filter="$1"

  if ((${#SWIFT_TEST_ARGS[@]})); then
    swift test "${SWIFT_TEST_ARGS[@]}" --filter "$filter"
  else
    swift test --filter "$filter"
  fi
}

for script_path in \
  ./script/delete_local_traces.sh \
  ./script/delete_local_traces_self_test.sh \
  ./script/check_diagnostics_log_self_test.sh \
  ./script/check_redacted_report_export.sh \
  ./script/check_current_build_privacy_export.sh; do
  run_check "Executable $(basename "$script_path")" require_executable "$script_path" || failures=$((failures + 1))
done

for filter in \
  SettingsWindowControllerStateTests \
  DiagnosticsWindowControllerStateTests \
  SuggestionControlPolicyTests \
  SuggestionPauseSchedulePolicyTests \
  DisabledAppSelectionTests \
  RawTracePrivacyExpiryTests \
  RawTraceReportExportTests \
  PrivacyExportProofCommandTests; do
  run_logged_check "Swift test $filter" run_swift_test "$filter" || failures=$((failures + 1))
done

run_check "Delete local traces self-test" ./script/delete_local_traces_self_test.sh || failures=$((failures + 1))
run_check "Diagnostics log self-test" ./script/check_diagnostics_log_self_test.sh || failures=$((failures + 1))
run_check "Redacted report export" ./script/check_redacted_report_export.sh || failures=$((failures + 1))

run_logged_check "Current build privacy export proof" env \
  "${CURRENT_BUILD_ENV[@]}" \
  ./script/check_current_build_privacy_export.sh || failures=$((failures + 1))

if ((failures > 0)); then
  echo
  echo "Controls and diagnostics readiness found $failures blocker(s)." >&2
  exit 1
fi

echo "Controls and diagnostics readiness passed."
