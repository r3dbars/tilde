#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -s "$LOG_PATH" ]]; then
  echo "diagnostics log is missing or empty: $LOG_PATH" >&2
  exit 1
fi

scan_log_lines() {
  if [[ -n "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" ]]; then
    local start_line=$((AUTOCOMPLETE_LAB_LOG_START_LINE + 1))
    tail -n +"$start_line" "$LOG_PATH" 2>/dev/null || true
    return
  fi

  cat "$LOG_PATH"
}

latest_launch_lines() {
  local launch_line

  if [[ -n "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" ]]; then
    local start_line=$((AUTOCOMPLETE_LAB_LOG_START_LINE + 1))
    local relative_line
    relative_line="$(
      tail -n +"$start_line" "$LOG_PATH" 2>/dev/null |
        grep -F -n "launch accessibility=" |
        tail -n 1 |
        cut -d: -f1
    )"
    [[ -n "$relative_line" ]] || return 0
    launch_line=$((start_line + relative_line - 1))
  else
    launch_line="$(
      grep -F -n "launch accessibility=" "$LOG_PATH" |
        tail -n 1 |
        cut -d: -f1
    )"
    [[ -n "$launch_line" ]] || return 0
  fi

  tail -n +"$launch_line" "$LOG_PATH" 2>/dev/null || true
}

RECENT_LINES="$(scan_log_lines | tail -n "${AUTOCOMPLETE_LAB_LOG_LINES:-120}")"
LATEST_LAUNCH_LINES="$(latest_launch_lines)"

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

require_latest_launch_status_or_heartbeat() {
  if grep -F "status accessibility=" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
    return
  fi

  if grep -F "runtime-resource-sample" <<<"$LATEST_LAUNCH_LINES" >/dev/null; then
    return
  fi

  echo "missing latest-launch diagnostics pattern: status accessibility= or runtime-resource-sample" >&2
  echo "log: $LOG_PATH" >&2
  exit 1
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
    LATEST_LAUNCH_LINES="$(latest_launch_lines)"

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
  RECENT_LINES="$(scan_log_lines | tail -n "${AUTOCOMPLETE_LAB_LOG_LINES:-120}")"
fi

require_latest_launch_line "launch accessibility="
require_latest_launch_line "runtime-bootstrap"
require_latest_launch_line "readinessStage="
require_latest_launch_status_or_heartbeat

if [[ -n "${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-}" ]]; then
  require_latest_launch_line "asset=${AUTOCOMPLETE_LAB_EXPECTED_ASSET}"
fi

if [[ "${AUTOCOMPLETE_LAB_REQUIRE_READY:-0}" == "1" ]]; then
  require_latest_launch_line "allowsUserManagedServer=false"
  require_latest_launch_line "readinessAction=none readinessStage=ready state=ready (MLX)"
  reject_latest_launch_pattern "runtime-warm-failed"
  reject_latest_launch_pattern "activeCandidate=(mock|unavailable)"
  reject_latest_launch_pattern "fallbackReason="
fi

if [[ "${AUTOCOMPLETE_LAB_REQUIRE_TYPING_FAST:-0}" == "1" ]]; then
  reject_recent_pattern "keyboard-action .*key=other"
  reject_recent_pattern "keyboard-event-tap-disabled"
  reject_recent_pattern "keyboard-event-tap-latency-slow"
  "$SCRIPT_DIR/check_typing_performance_log.sh"
fi

echo "Diagnostics log verified: $LOG_PATH"
