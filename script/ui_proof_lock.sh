#!/usr/bin/env bash

autocomplete_lab_ui_lock_path() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_UI_PROOF_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-ui-proof.lock}"
}

acquire_autocomplete_lab_ui_lock() {
  local label="${1:-AutocompleteLab UI proof}"

  if [[ "${AUTOCOMPLETE_LAB_UI_PROOF_LOCK_HELD:-0}" == "1" ]]; then
    return 0
  fi

  local lock_dir pid holder_label
  lock_dir="$(autocomplete_lab_ui_lock_path)"

  for _ in 1 2; do
    if mkdir "$lock_dir" 2>/dev/null; then
      AUTOCOMPLETE_LAB_UI_PROOF_LOCK_ACQUIRED=1
      AUTOCOMPLETE_LAB_UI_PROOF_LOCK_PATH="$lock_dir"
      printf '%s\n' "$$" >"$lock_dir/pid"
      printf '%s\n' "$label" >"$lock_dir/label"
      return 0
    fi

    pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
      rm -rf "$lock_dir"
      continue
    fi

    holder_label="$(cat "$lock_dir/label" 2>/dev/null || true)"
    echo "AutocompleteLab UI proof lock is held by pid $pid${holder_label:+ ($holder_label)}." >&2
    echo "Stop the other proof/build launch before running another UI smoke." >&2
    return 75
  done

  echo "Could not acquire AutocompleteLab UI proof lock at $lock_dir." >&2
  return 75
}

release_autocomplete_lab_ui_lock() {
  if [[ "${AUTOCOMPLETE_LAB_UI_PROOF_LOCK_ACQUIRED:-0}" != "1" ]]; then
    return 0
  fi

  local lock_dir
  lock_dir="${AUTOCOMPLETE_LAB_UI_PROOF_LOCK_PATH:-$(autocomplete_lab_ui_lock_path)}"
  rm -rf "$lock_dir"
  AUTOCOMPLETE_LAB_UI_PROOF_LOCK_ACQUIRED=0
}
