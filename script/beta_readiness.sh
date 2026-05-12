#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="full"

usage() {
  cat <<'EOF'
Usage: script/beta_readiness.sh [--check-only]

Runs the full private-beta gate by default.

--check-only  Report current blockers without building archives or creating the
              private beta packet.
EOF
}

while (($#)); do
  case "$1" in
    --check-only)
      MODE="check-only"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run_check() {
  local label="$1"
  shift

  echo
  echo "== $label =="
  if "$@"; then
    echo "$label: OK"
    return 0
  fi

  echo "$label: blocked"
  return 1
}

check_clipboard_fallback_disabled() {
  local failed=0

  if rg -n \
    'NSPasteboard\.general|pasteboard\.clearContents|pasteboard\.setString|writeObjects\(|keyboardEventSource: nil, virtualKey: 9' \
    Sources/AutocompleteLabApp/Mac/InsertionEngine.swift; then
    failed=1
  fi

  if rg -n 'acceptMode: \.clipboardFallback' \
    Sources/AutocompleteLabCore/Compatibility/AppCompatibilityProfile.swift; then
    failed=1
  fi

  if ((failed > 0)); then
    echo "clipboard fallback insertion is not beta-safe"
    return 1
  fi

  echo "clipboard fallback insertion disabled"
}

check_notarized_install_proof() {
  local proof_dir="$ROOT_DIR/dist/release-proof"
  local blocker_path="$proof_dir/notarization-blocker.txt"
  local failed=0

  if [[ -s "$blocker_path" ]]; then
    cat "$blocker_path"
    return 1
  fi

  for path in \
    "$proof_dir/notarytool-submit.txt" \
    "$proof_dir/stapler-validate.txt" \
    "$proof_dir/spctl-dmg.txt" \
    "$proof_dir/spctl-installed-app.txt" \
    "$proof_dir/fresh-install-gatekeeper-proof.md"; do
    if [[ ! -s "$path" ]]; then
      echo "missing release proof: $path"
      failed=1
    fi
  done

  if ((failed > 0)); then
    return 1
  fi

  echo "notarization, stapling, and fresh-install proof files are present"
}

latency_beta_gate() {
  local start_env=()

  if [[ -z "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" && -z "${AUTOCOMPLETE_LAB_TRACE_START_LINE:-}" ]]; then
    while IFS= read -r assignment; do
      [[ -n "$assignment" ]] && start_env+=("$assignment")
    done < <(python3 - \
      "${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}" \
      "${AUTOCOMPLETE_LAB_TRACE_LOG:-$HOME/Library/Logs/SteadyType/traces.jsonl}" <<'PY'
import json
import sys
from pathlib import Path

diagnostics_path = Path(sys.argv[1])
trace_path = Path(sys.argv[2])

latest_launch_line = 0
latest_launch_timestamp = ""

if diagnostics_path.exists():
    with diagnostics_path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            if "launch accessibility=" not in line:
                continue
            latest_launch_line = line_number
            latest_launch_timestamp = line.split(maxsplit=1)[0]

if latest_launch_line:
    print(f"AUTOCOMPLETE_LAB_LOG_START_LINE={max(0, latest_launch_line - 1)}")

if latest_launch_timestamp and trace_path.exists():
    trace_start_line = 0
    with trace_path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line_number, line in enumerate(handle, start=1):
            try:
                timestamp = json.loads(line).get("timestamp", "")
            except json.JSONDecodeError:
                continue
            if timestamp >= latest_launch_timestamp:
                trace_start_line = max(0, line_number - 1)
                break
    if trace_start_line:
        print(f"AUTOCOMPLETE_LAB_TRACE_START_LINE={trace_start_line}")
PY
    )
  fi

  if ((${#start_env[@]})); then
    echo "Latency window: ${start_env[*]}"
    env "${start_env[@]}" ./script/latency_benchmark_report.py --beta-gate
    return
  fi

  ./script/latency_benchmark_report.py --beta-gate
}

if [[ "$MODE" == "check-only" ]]; then
  failures=0

  run_check "Model asset" ./script/check_model_asset.py || failures=$((failures + 1))
  run_check "Runtime production gate" env \
    AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
    AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    ./script/check_diagnostics_log.sh || failures=$((failures + 1))
  run_check "Latency beta gate" latency_beta_gate || failures=$((failures + 1))
  run_check "Redacted report export" ./script/check_redacted_report_export.sh || failures=$((failures + 1))
  run_check "Issue template validation" ./script/validate_beta_issue_template.sh || failures=$((failures + 1))
  run_check "Clipboard fallback disabled" check_clipboard_fallback_disabled || failures=$((failures + 1))
  run_check "Prompt app proof gate" ./script/check_prompt_app_proof.sh || failures=$((failures + 1))
  run_check "Manual app proof" ./script/manual_smoke_status.sh --require-all || failures=$((failures + 1))
  run_check "Visual placement proof" ./script/check_visual_placement_evidence.sh --require-all || failures=$((failures + 1))
  run_check "Release package prerequisites" ./script/package_release.sh --check || failures=$((failures + 1))

  echo
  echo "== Private beta archive =="
  if [[ -s "$ROOT_DIR/dist/SteadyType.zip" ]]; then
    echo "Private beta archive: OK"
    run_check "Notarized install proof" check_notarized_install_proof || failures=$((failures + 1))
  else
    echo "Private beta archive: blocked"
    echo "missing archive: $ROOT_DIR/dist/SteadyType.zip"
    failures=$((failures + 1))
  fi

  if [[ -s "$ROOT_DIR/dist/SteadyType.zip" ]]; then
    run_check "Private beta packet" ./script/private_beta_packet.sh --check || failures=$((failures + 1))
  else
    echo
    echo "== Private beta packet =="
    echo "Private beta packet: skipped until archive exists"
  fi

  if ((failures > 0)); then
    echo
    echo "Beta readiness check-only found $failures blocker(s)."
    exit 1
  fi

  echo
  echo "Beta readiness check-only passed."
  exit 0
fi

echo "== Model asset =="
./script/check_model_asset.py

echo
echo "== Smoke =="
./script/smoke_test.sh

echo
echo "== Runtime production gate =="
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
  ./script/check_diagnostics_log.sh
echo
echo "== Latency beta gate =="
latency_beta_gate


echo
echo "== Redacted report export =="
./script/check_redacted_report_export.sh

echo
echo "== Issue template validation =="
./script/validate_beta_issue_template.sh

echo
echo "== Clipboard fallback disabled =="
check_clipboard_fallback_disabled

echo
echo "== Prompt app proof gate =="
./script/check_prompt_app_proof.sh

echo
echo "== Manual app proof =="
./script/manual_smoke_status.sh --require-all

echo
echo "== Visual placement proof =="
./script/check_visual_placement_evidence.sh --require-all

echo
echo "== Release package =="
./script/package_release.sh --check
./script/package_release.sh archive

echo
echo "== Private beta packet =="
./script/private_beta_packet.sh create
./script/private_beta_packet.sh --check

echo
echo "Beta readiness passed."
echo "Archive: $ROOT_DIR/dist/SteadyType.zip"
echo "Private beta packet: $ROOT_DIR/dist/private-beta"

if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "Notarization is still pending: set NOTARYTOOL_PROFILE before submitting to Apple."
fi
