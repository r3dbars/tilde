#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
LOG_START_LINE=0
if [[ -f "$LOG_PATH" ]]; then
  LOG_START_LINE="$(wc -l <"$LOG_PATH" | tr -d ' ')"
fi

swift package resolve
./script/patch_mlx_swift_lm.sh
swift test
./script/check_test_coverage_manifest.sh
./script/manual_smoke_self_test.sh
./script/check_trace_eval_self_test.sh
./script/model_latency_report_self_test.sh
./script/package_release.sh --check
./script/build_and_run.sh --verify
./script/check_app_bundle.sh
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_REQUIRE_TYPING_FAST=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="Qwen3.5-4B-4bit" \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$LOG_START_LINE" \
  ./script/check_diagnostics_log.sh

echo
echo "Manual app smoke checklist: docs/product/manual-smoke-checklist.md"
echo "Manual app smoke recorder: script/manual_smoke_session.sh <textedit|notes|obsidian|chrome|codex|claude-code>"
echo "Manual app smoke status: script/manual_smoke_status.sh"
echo "Diagnostics log: $HOME/Library/Logs/AutocompleteLab/diagnostics.log"
