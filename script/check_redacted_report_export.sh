#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SWIFT_TEST_ARGS=()
SWIFT_TEST_ARGS_CONFIGURED=0

if [[ -n "${AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH:-}" ]]; then
  SWIFT_TEST_ARGS+=(--scratch-path "$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH/swift-tests")
  SWIFT_TEST_ARGS_CONFIGURED=1
fi

if [[ "${AUTOCOMPLETE_LAB_SWIFT_SKIP_BUILD:-0}" =~ ^(1|true|yes|on)$ ]]; then
  SWIFT_TEST_ARGS+=(--skip-build)
  SWIFT_TEST_ARGS_CONFIGURED=1
fi

if [[ "$SWIFT_TEST_ARGS_CONFIGURED" == "1" ]]; then
  swift test "${SWIFT_TEST_ARGS[@]}" --filter 'RawTraceReportExportTests'
else
  swift test --filter 'RawTraceReportExportTests'
fi
