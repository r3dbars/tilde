#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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
echo "== Proof manifest =="
./script/check_proof_manifest.sh --require-all

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
