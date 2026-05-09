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

if [[ "$MODE" == "check-only" ]]; then
  failures=0

  run_check "Model asset" ./script/check_model_asset.py || failures=$((failures + 1))
  run_check "Runtime production gate" env \
    AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
    AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    ./script/check_diagnostics_log.sh || failures=$((failures + 1))
  run_check "Latency beta gate" ./script/latency_benchmark_report.py --beta-gate || failures=$((failures + 1))
  run_check "Redacted report export" ./script/check_redacted_report_export.sh || failures=$((failures + 1))
  run_check "Issue template validation" ./script/validate_beta_issue_template.sh || failures=$((failures + 1))
  run_check "Clipboard fallback disabled" check_clipboard_fallback_disabled || failures=$((failures + 1))
  run_check "Prompt app proof gate" ./script/check_prompt_app_proof.sh || failures=$((failures + 1))
  run_check "Manual app proof" ./script/manual_smoke_status.sh --require-all || failures=$((failures + 1))
  run_check "Visual placement proof" ./script/check_visual_placement_evidence.sh --require-all || failures=$((failures + 1))
  run_check "Release package prerequisites" ./script/package_release.sh --check || failures=$((failures + 1))

  echo
  echo "== Private beta archive =="
  if [[ -s "$ROOT_DIR/dist/AutocompleteLab.zip" ]]; then
    echo "Private beta archive: OK"
  else
    echo "Private beta archive: blocked"
    echo "missing archive: $ROOT_DIR/dist/AutocompleteLab.zip"
    failures=$((failures + 1))
  fi

  if [[ -s "$ROOT_DIR/dist/AutocompleteLab.zip" ]]; then
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
./script/latency_benchmark_report.py --beta-gate


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
echo "Archive: $ROOT_DIR/dist/AutocompleteLab.zip"
echo "Private beta packet: $ROOT_DIR/dist/private-beta"

if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "Notarization is still pending: set NOTARYTOOL_PROFILE before submitting to Apple."
fi
