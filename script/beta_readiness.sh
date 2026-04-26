#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Smoke =="
./script/smoke_test.sh

echo
echo "== Manual app proof =="
./script/manual_smoke_status.sh --require-all

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
