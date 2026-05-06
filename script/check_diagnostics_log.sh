#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"

if [[ ! -s "$LOG_PATH" ]]; then
  echo "diagnostics log is missing or empty: $LOG_PATH" >&2
  exit 1
fi

if [[ -n "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" ]]; then
  START_LINE=$((AUTOCOMPLETE_LAB_LOG_START_LINE + 1))
  SCAN_LINES="$(tail -n +"$START_LINE" "$LOG_PATH" 2>/dev/null || true)"
else
  SCAN_LINES="$(cat "$LOG_PATH")"
fi

RECENT_LINES="$(tail -n "${AUTOCOMPLETE_LAB_LOG_LINES:-120}" <<<"$SCAN_LINES")"
LATEST_LAUNCH_LINES="$(
  awk '
    /launch accessibility=/ {
      buffer = $0 ORS
      found = 1
      next
    }
    found {
      buffer = buffer $0 ORS
    }
    END {
      printf "%s", buffer
    }
  ' <<<"$SCAN_LINES"
)"

if [[ -z "$LATEST_LAUNCH_LINES" ]]; then
  LATEST_LAUNCH_LINES="$RECENT_LINES"
fi

require_recent_line() {
  local pattern="$1"
  if ! grep -F "$pattern" <<<"$RECENT_LINES" >/dev/null; then
    echo "missing diagnostics pattern: $pattern" >&2
    echo "log: $LOG_PATH" >&2
    exit 1
  fi
}

require_latest_launch_line() {
  local pattern="$1"
  if ! grep -F "$pattern" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
    echo "missing latest-launch diagnostics pattern: $pattern" >&2
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

reject_latest_launch_pattern() {
  local pattern="$1"
  if grep -E "$pattern" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
    echo "latest launch contains disallowed diagnostics pattern: $pattern" >&2
    echo "log: $LOG_PATH" >&2
    exit 1
  fi
}

wait_for_latest_launch_ready() {
  local timeout_seconds="${AUTOCOMPLETE_LAB_READY_TIMEOUT_SECONDS:-60}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS <= deadline )); do
    if [[ -n "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" ]]; then
      START_LINE=$((AUTOCOMPLETE_LAB_LOG_START_LINE + 1))
      SCAN_LINES="$(tail -n +"$START_LINE" "$LOG_PATH" 2>/dev/null || true)"
    else
      SCAN_LINES="$(cat "$LOG_PATH")"
    fi

    LATEST_LAUNCH_LINES="$(
      awk '
        /launch accessibility=/ {
          buffer = $0 ORS
          found = 1
          next
        }
        found {
          buffer = buffer $0 ORS
        }
        END {
          printf "%s", buffer
        }
      ' <<<"$SCAN_LINES"
    )"

    if [[ -z "$LATEST_LAUNCH_LINES" ]]; then
      sleep 1
      continue
    fi

    if grep -F "runtime-warm-failed" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
      echo "latest launch failed while warming the local runtime" >&2
      echo "log: $LOG_PATH" >&2
      exit 1
    fi

    if grep -F "runtime-warm-succeeded" <<<"$LATEST_LAUNCH_LINES" >/dev/null &&
      grep -F "readinessStage=ready" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
      return 0
    fi

    sleep 1
  done

  echo "timed out waiting for latest launch to reach ready MLX runtime" >&2
  echo "log: $LOG_PATH" >&2
  exit 1
}

reject_recent_pattern '(^| )(textBeforeCursor|textAfterCursor|selectedText|rawText|value)='

if [[ "${AUTOCOMPLETE_LAB_REQUIRE_READY:-0}" == "1" ]]; then
  wait_for_latest_launch_ready
  RECENT_LINES="$(tail -n "${AUTOCOMPLETE_LAB_LOG_LINES:-120}" <<<"$SCAN_LINES")"
fi

require_recent_line "launch accessibility="
require_latest_launch_line "runtime-bootstrap"
require_latest_launch_line "readinessStage="
require_recent_line "status accessibility="

if [[ -n "${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-}" ]]; then
  require_latest_launch_line "asset=${AUTOCOMPLETE_LAB_EXPECTED_ASSET}"
fi

if [[ "${AUTOCOMPLETE_LAB_REQUIRE_READY:-0}" == "1" ]]; then
  require_latest_launch_line "readinessAction=none readinessStage=ready state=ready (MLX)"
  reject_latest_launch_pattern "runtime-warm-failed"
fi

if [[ "${AUTOCOMPLETE_LAB_REQUIRE_TYPING_FAST:-0}" == "1" ]]; then
  reject_recent_pattern "keyboard-action .*key=other"
  reject_recent_pattern "keyboard-event-tap-disabled"
  reject_recent_pattern "keyboard-event-tap-latency-slow"
fi

echo "Diagnostics log verified: $LOG_PATH"
