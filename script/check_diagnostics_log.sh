#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"

if [[ ! -s "$LOG_PATH" ]]; then
  echo "diagnostics log is missing or empty: $LOG_PATH" >&2
  exit 1
fi

RECENT_LINES="$(tail -n "${AUTOCOMPLETE_LAB_LOG_LINES:-120}" "$LOG_PATH")"

require_recent_line() {
  local pattern="$1"
  if ! grep -F "$pattern" <<<"$RECENT_LINES" >/dev/null; then
    echo "missing diagnostics pattern: $pattern" >&2
    echo "log: $LOG_PATH" >&2
    exit 1
  fi
}

reject_recent_pattern() {
  local pattern="$1"
  if grep -E "$pattern" <<<"$RECENT_LINES" >/dev/null; then
    echo "diagnostics log contains disallowed pattern: $pattern" >&2
    echo "log: $LOG_PATH" >&2
    exit 1
  fi
}

require_recent_line "launch accessibility="
require_recent_line "runtime-bootstrap"
require_recent_line "readinessStage="
require_recent_line "status accessibility="

reject_recent_pattern '(^| )(textBeforeCursor|textAfterCursor|selectedText|rawText|value)='

echo "Diagnostics log verified: $LOG_PATH"
