#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
MODE="print"

usage() {
  cat <<'EOF'
Usage: script/no_accessibility_smoke.sh [--print|--check|--open-settings]

Prints or verifies the manual no-Accessibility-permission smoke path.
This script does not reset TCC or revoke permissions. Disable SteadyType
in System Settings manually, relaunch the app, then run --check.
EOF
}

while (($#)); do
  case "$1" in
    --print)
      MODE="print"
      ;;
    --check)
      MODE="check"
      ;;
    --open-settings)
      MODE="open-settings"
      ;;
    -h | --help)
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

print_steps() {
  cat <<EOF
No-Accessibility smoke path

1. Record a diagnostics mark:
   START_LINE=\$(wc -l < "$LOG_PATH" | tr -d ' ')
2. Open System Settings > Privacy & Security > Accessibility.
3. Turn off SteadyType.
4. Relaunch the app:
   ./script/build_and_run.sh --verify
5. Verify the blocked slice:
   AUTOCOMPLETE_LAB_LOG_START_LINE=\$START_LINE script/no_accessibility_smoke.sh --check

Pass means the app logs missing Accessibility, hides suggestions, and does not
handle accept keys.
EOF
}

scan_lines() {
  if [[ ! -f "$LOG_PATH" ]]; then
    echo "diagnostics log not found: $LOG_PATH" >&2
    exit 1
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" ]]; then
    tail -n +"$((AUTOCOMPLETE_LAB_LOG_START_LINE + 1))" "$LOG_PATH" 2>/dev/null || true
  else
    cat "$LOG_PATH"
  fi
}

require_pattern() {
  local lines="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -E "$pattern" <<<"$lines" >/dev/null; then
    echo "No-Accessibility smoke failed: missing $label." >&2
    echo "Pattern: $pattern" >&2
    echo "Log: $LOG_PATH" >&2
    exit 1
  fi
}

reject_pattern() {
  local lines="$1"
  local pattern="$2"
  local label="$3"
  if grep -E "$pattern" <<<"$lines" >/dev/null; then
    echo "No-Accessibility smoke failed: saw $label." >&2
    echo "Pattern: $pattern" >&2
    echo "Log: $LOG_PATH" >&2
    exit 1
  fi
}

check_log() {
  local lines
  lines="$(scan_lines)"
  if [[ -z "$lines" ]]; then
    echo "No-Accessibility smoke failed: empty diagnostics slice." >&2
    echo "Log: $LOG_PATH" >&2
    exit 1
  fi

  require_pattern "$lines" 'launch accessibility=false' "launch Accessibility=false"
  require_pattern "$lines" 'status .*accessibility=AX missing' "AX missing status"
  require_pattern "$lines" 'Blocked: Accessibility permission missing' "blocked permission decision"
  reject_pattern "$lines" 'suggestion-presented ' "a presented suggestion"
  reject_pattern "$lines" 'keyboard-action .*action=accept[^ ]* .*handled=true' "a handled accept key"

  echo "No-Accessibility smoke verified: $LOG_PATH"
}

case "$MODE" in
  print)
    print_steps
    ;;
  check)
    check_log
    ;;
  open-settings)
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ;;
esac
