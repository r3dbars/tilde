#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
cleanup() {
  release_autocomplete_lab_ui_lock >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

export AUTOCOMPLETE_LAB_UI_PROOF_LOCK_DIR="$tmp_dir/ui-proof.lock"

# shellcheck source=script/ui_proof_lock.sh
source "$ROOT_DIR/script/ui_proof_lock.sh"

acquire_autocomplete_lab_ui_lock "self-test parent"

if bash -c 'source "$1"; acquire_autocomplete_lab_ui_lock "self-test child"' bash "$ROOT_DIR/script/ui_proof_lock.sh" 2>"$tmp_dir/child.err"; then
  echo "expected second UI proof lock acquisition to fail" >&2
  exit 1
fi

if ! grep -F "AutocompleteLab UI proof lock is held" "$tmp_dir/child.err" >/dev/null; then
  echo "expected child failure to explain the held lock" >&2
  cat "$tmp_dir/child.err" >&2
  exit 1
fi

release_autocomplete_lab_ui_lock

bash -c 'source "$1"; acquire_autocomplete_lab_ui_lock "self-test second"; release_autocomplete_lab_ui_lock' bash "$ROOT_DIR/script/ui_proof_lock.sh"

echo "UI proof lock self-test passed."
