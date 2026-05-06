#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/real_app_smoke.sh textedit --dry-run >"$TMP_DIR/textedit.txt"
if ! grep -F "Real app smoke: textedit" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --dry-run >"$TMP_DIR/chrome.txt"
if ! grep -F "disposable Chrome textarea" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh codex --dry-run >"$TMP_DIR/codex.txt"
if ! grep -F "manual-gated prompt smoke" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex manual gate" >&2
  exit 1
fi

if script/real_app_smoke.sh unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown apps to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/codex-fail.txt"; then
  echo "real app smoke self-test expected Codex to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/codex-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex safety gate" >&2
  exit 1
fi

echo "Real app smoke self-test passed."
