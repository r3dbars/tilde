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

if [[ "$MODE" == "check-only" ]]; then
  failures=0

  run_check "Model asset" ./script/check_model_asset.py || failures=$((failures + 1))
  run_check "Runtime production gate" env \
    AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
    AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    ./script/check_diagnostics_log.sh || failures=$((failures + 1))
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
