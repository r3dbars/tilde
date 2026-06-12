#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS_DIR="$ROOT_DIR/docs/diagnostics/runs"
APP_BINARY_NAME="AutocompleteLab"
APP_BUNDLE_ID="bar.r3d.steadytype"

PROFILE="frontmost"
REQUESTED_APP=""
DELAY_SECONDS="6"
LOG_MINUTES="10"
SCREENSHOT_MODE="select"

usage() {
  cat <<'USAGE'
usage: ./script/diagnose_target_app.sh [options]

Options:
  --profile NAME       textedit, notes, composer, browser, obsidian, or frontmost
  --app NAME           Target app process name, like TextEdit or Google Chrome
  --delay SECONDS      Seconds to wait before capture so you can switch apps
  --log-minutes N      Minutes of AutocompleteLab logs to include
  --select             Capture a selected screenshot region (default)
  --full-screen        Capture the full screen
  --no-screenshot      Skip screenshot capture
  -h, --help           Show this help

Privacy:
  This script does not read Accessibility text values, clipboard contents,
  keystrokes, browser history, or document contents. Screenshots can still show
  visible text, so use throwaway text and crop tightly.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 2
}

is_non_negative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

slugify() {
  local value="$1"
  local slug
  slug="$(printf '%s' "$value" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c '[:alnum:]' '-' \
    | sed -e 's/^-*//' -e 's/-*$//' -e 's/--*/-/g')"

  if [[ -z "$slug" ]]; then
    slug="frontmost"
  fi

  printf '%s' "$slug"
}

target_process_names() {
  printf '%s\n' "$APP_BINARY_NAME"

  case "$PROFILE" in
    textedit)
      printf '%s\n' "TextEdit"
      ;;
    notes)
      printf '%s\n' "Notes"
      ;;
    composer)
      printf '%s\n' "ChatGPT" "Codex" "Safari" "Google Chrome" "Arc" "Firefox" "Brave Browser" "Microsoft Edge" "Cursor" "Code"
      ;;
    browser|browsers)
      printf '%s\n' "Safari" "Google Chrome" "Arc" "Firefox" "Brave Browser" "Microsoft Edge"
      ;;
    obsidian|editor|editors)
      printf '%s\n' "Obsidian" "Logseq" "Bear" "Cursor" "Code"
      ;;
    frontmost)
      ;;
    *)
      printf '%s\n' "$PROFILE"
      ;;
  esac

  if [[ -n "$REQUESTED_APP" ]]; then
    printf '%s\n' "$REQUESTED_APP"
  fi
}

collect_frontmost_app() {
  local run_dir="$1"
  local out="$run_dir/frontmost-app.txt"
  local err="$run_dir/frontmost-app-error.txt"

  if /usr/bin/osascript >"$out" 2>"$err" <<'APPLESCRIPT'
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  set appName to name of frontApp
  set appBundle to bundle identifier of frontApp
  set appPID to unix id of frontApp
  return "name=" & appName & linefeed & "bundle_id=" & appBundle & linefeed & "pid=" & appPID
end tell
APPLESCRIPT
  then
    rm -f "$err"
  else
    {
      echo "frontmost_app=unavailable"
      echo "reason=System Events did not return frontmost app metadata."
    } >"$out"
  fi
}

collect_process_context() {
  local run_dir="$1"
  local out="$run_dir/process-context.txt"

  {
    echo "# Process context"
    echo "Captured fields: pid, parent pid, elapsed time, status, executable path."
    echo "Command arguments are intentionally omitted."

    target_process_names | while IFS= read -r process_name; do
      if [[ -z "$process_name" ]]; then
        continue
      fi

      echo
      echo "## $process_name"

      local pids
      if pids="$(/usr/bin/pgrep -x "$process_name" 2>/dev/null)"; then
        local pid_list
        pid_list="$(printf '%s\n' "$pids" | /usr/bin/paste -sd, -)"
        /bin/ps -p "$pid_list" -o pid=,ppid=,etime=,stat=,comm= || true
      else
        echo "not running"
      fi
    done
  } >"$out"
}

collect_system_context() {
  local run_dir="$1"
  local out="$run_dir/system-context.txt"

  {
    echo "# System context"
    echo "captured_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    /usr/bin/sw_vers
    /usr/bin/uname -a
    echo "cpu=$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
    echo "memory_bytes=$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || true)"
  } >"$out"
}

collect_autocomplete_logs() {
  local run_dir="$1"
  local out="$run_dir/autocomplete-log.txt"
  local err="$run_dir/autocomplete-log-error.txt"
  local predicate
  predicate="subsystem == \"$APP_BUNDLE_ID\" OR process == \"$APP_BINARY_NAME\""

  if /usr/bin/log show --style compact --last "${LOG_MINUTES}m" --info --predicate "$predicate" >"$out" 2>"$err"; then
    rm -f "$err"
  else
    {
      echo "# AutocompleteLab logs unavailable"
      echo "predicate=$predicate"
      echo "last_minutes=$LOG_MINUTES"
      echo "See autocomplete-log-error.txt for the local log command error."
    } >"$out"
  fi
}

capture_screenshot() {
  local run_dir="$1"
  local screenshot="$run_dir/screenshot.png"
  local status_file="$run_dir/screenshot-status.txt"

  case "$SCREENSHOT_MODE" in
    select)
      echo "Select a tight screenshot region around the caret/suggestion. Press Esc to skip."
      if /usr/sbin/screencapture -ix "$screenshot"; then
        echo "screenshot=screenshot.png" >"$status_file"
      else
        rm -f "$screenshot"
        echo "screenshot=skipped_or_failed" >"$status_file"
      fi
      ;;
    full)
      if /usr/sbin/screencapture -x "$screenshot"; then
        echo "screenshot=screenshot.png" >"$status_file"
      else
        rm -f "$screenshot"
        echo "screenshot=failed" >"$status_file"
      fi
      ;;
    none)
      echo "screenshot=skipped" >"$status_file"
      ;;
    *)
      die "unknown screenshot mode: $SCREENSHOT_MODE"
      ;;
  esac
}

write_notes_template() {
  local run_dir="$1"

  cat >"$run_dir/notes.md" <<'NOTES'
# Diagnostic Notes

Target:
Profile:
Scenario:

Observed:
- Placement:
- Font/color fit:
- Tab accepts next word:
- Shift-Tab accepts all visible:
- Backtick/tilde stays typed text:
- Esc dismisses:
- Any app-specific conflict:

Privacy review before sharing:
- [ ] Screenshot uses throwaway text only.
- [ ] Logs reviewed.
- [ ] No real notes, chats, emails, prompts, or drafts are visible.
NOTES
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --app)
      [[ $# -ge 2 ]] || die "--app requires a value"
      REQUESTED_APP="$2"
      shift 2
      ;;
    --delay)
      [[ $# -ge 2 ]] || die "--delay requires a value"
      DELAY_SECONDS="$2"
      shift 2
      ;;
    --log-minutes)
      [[ $# -ge 2 ]] || die "--log-minutes requires a value"
      LOG_MINUTES="$2"
      shift 2
      ;;
    --select)
      SCREENSHOT_MODE="select"
      shift
      ;;
    --full-screen)
      SCREENSHOT_MODE="full"
      shift
      ;;
    --no-screenshot)
      SCREENSHOT_MODE="none"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

is_non_negative_int "$DELAY_SECONDS" || die "--delay must be a non-negative integer"
is_non_negative_int "$LOG_MINUTES" || die "--log-minutes must be a non-negative integer"

TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
LABEL_SOURCE="${REQUESTED_APP:-$PROFILE}"
LABEL="$(slugify "$LABEL_SOURCE")"
RUN_DIR="$RUNS_DIR/$TIMESTAMP-$LABEL"

mkdir -p "$RUN_DIR"

cat >"$RUN_DIR/manifest.txt" <<MANIFEST
# AutocompleteLab target-app diagnostic
timestamp_utc=$TIMESTAMP
profile=$PROFILE
requested_app=$REQUESTED_APP
delay_seconds=$DELAY_SECONDS
log_minutes=$LOG_MINUTES
screenshot_mode=$SCREENSHOT_MODE
privacy_boundary=No Accessibility text values, clipboard contents, keystrokes, browser history, or document contents are read.
MANIFEST

echo "Diagnostic bundle: $RUN_DIR"
echo "Switch to the target app now. Capture starts in ${DELAY_SECONDS}s."
sleep "$DELAY_SECONDS"

collect_frontmost_app "$RUN_DIR"
collect_process_context "$RUN_DIR"
collect_system_context "$RUN_DIR"
collect_autocomplete_logs "$RUN_DIR"
capture_screenshot "$RUN_DIR"
write_notes_template "$RUN_DIR"

echo "Done: $RUN_DIR"
