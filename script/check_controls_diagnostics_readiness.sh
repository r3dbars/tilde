#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test --filter SettingsWindowControllerStateTests
swift test --filter DiagnosticsWindowControllerStateTests
swift test --filter SuggestionControlPolicyTests
swift test --filter SuggestionPauseSchedulePolicyTests
swift test --filter DisabledAppSelectionTests
swift test --filter RawTracePrivacyExpiryTests
swift test --filter RawTraceReportExportTests
swift test --filter PrivacyExportProofCommandTests

./script/delete_local_traces_self_test.sh
./script/check_diagnostics_log_self_test.sh
./script/check_redacted_report_export.sh

proof_output="$(mktemp -d)"
trap 'rm -rf "$proof_output"' EXIT
AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT="$proof_output" \
  ./script/check_current_build_privacy_export.sh >/tmp/autocomplete-current-build-privacy-export-proof.txt

echo "Controls and diagnostics readiness passed."
