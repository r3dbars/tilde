#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="${1:-}"
DRY_RUN=0
MANUAL_GATE=0
SKIP_BUILD="${AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD:-0}"

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|chrome|codex|claude-code> [--dry-run] [--manual-gate] [--skip-build]

Runs a real app smoke pass where it is safe to automate. Codex and Claude Code
are manual-gated so this script never types into an agent prompt by surprise.
EOF
}

shift || true
while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --manual-gate)
      MANUAL_GATE=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    -h|--help)
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

case "$APP" in
  textedit|chrome|codex|claude-code)
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"

line_count() {
  local path="$1"
  if [[ -f "$path" ]]; then
    wc -l <"$path" | tr -d ' '
  else
    echo 0
  fi
}

wait_for_log_pattern() {
  local start_line="$1"
  local pattern="$2"
  local label="$3"
  local timeout_seconds="${4:-12}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | grep -E "$pattern" >/dev/null; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for $label." >&2
  echo "Pattern: $pattern" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

wait_for_log_fields() {
  local start_line="$1"
  local label="$2"
  local timeout_seconds="$3"
  local prefix="$4"
  shift 4
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local lines
    lines="$(tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | grep -F "$prefix" || true)"
    local field
    for field in "$@"; do
      lines="$(grep -F "$field" <<<"$lines" || true)"
    done
    if [[ -n "$lines" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for $label." >&2
  echo "Required fields: $prefix $*" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

wait_for_frontmost_app() {
  local expected="$1"
  local timeout_seconds="${2:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local frontmost
    frontmost="$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
    if [[ "$frontmost" == "$expected" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for $expected to become frontmost." >&2
  exit 1
}

press_key_code() {
  local key_code="$1"

  osascript <<APPLESCRIPT
tell application "System Events"
  key code $key_code
end tell
APPLESCRIPT
}

describe_plan() {
  echo "Real app smoke: $APP"
  echo "Diagnostics log: $LOG_PATH"
  echo "Trace log: $TRACE_PATH"
  case "$APP" in
    textedit)
      echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file, type a test fragment, then validate logs and traces."
      ;;
    chrome)
      echo "Plan: build/relaunch AutocompleteLab, open a disposable Chrome textarea, type a test fragment, then validate logs and traces."
      ;;
    codex|claude-code)
      echo "Plan: manual-gated prompt smoke. The script prints the checklist and validates after you run it."
      echo "Safety: pass --manual-gate to continue."
      ;;
  esac
}

build_if_needed() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  ./script/build_and_run.sh --verify
}

run_manual_gated() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "$APP real smoke requires --manual-gate because it focuses an agent prompt." >&2
    exit 2
  fi

  build_if_needed
  ./script/manual_smoke_session.sh "$APP"
}

run_textedit() {
  build_if_needed

  local start_line trace_start_line tmp_dir tmp_file
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"
  tmp_dir="$(mktemp -d)"
  tmp_file="$tmp_dir/autocomplete-lab-textedit-smoke.txt"
  trap 'rm -rf "$tmp_dir"' RETURN

  : >"$tmp_file"
  open -a TextEdit "$tmp_file"
  sleep 1

  osascript <<'APPLESCRIPT'
tell application "TextEdit" to activate
delay 0.4
tell application "System Events"
  keystroke "a" using command down
  key code 51
  keystroke "Can we make this feel "
end tell
APPLESCRIPT

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit suggestion"
  press_key_code 48
  wait_for_log_fields "$start_line" "TextEdit Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.TextEdit .*result=verified" "TextEdit first verified insertion"
  press_key_code 50

  sleep 1
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh textedit --check
}

run_chrome() {
  if ! osascript -e 'id of application "Google Chrome"' >/dev/null 2>&1; then
    echo "Google Chrome is not installed or not scriptable on this machine." >&2
    exit 1
  fi

  build_if_needed

  local start_line trace_start_line tmp_dir html_file
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"
  tmp_dir="$(mktemp -d)"
  html_file="$tmp_dir/autocomplete-lab-chrome-smoke.html"
  trap 'rm -rf "$tmp_dir"' RETURN

  cat >"$html_file" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Smoke</title>
<textarea autofocus style="font: 18px -apple-system; width: 720px; height: 180px; margin: 80px;"></textarea>
<script>document.querySelector("textarea").focus();</script>
HTML

  local chrome_url="file://$html_file"

  osascript >/dev/null <<APPLESCRIPT
tell application "Google Chrome"
  activate
  if not (exists window 1) then make new window
  set URL of active tab of front window to "$chrome_url"
end tell
delay 1.2
tell application "System Events"
  tell process "Google Chrome"
    set frontmost to true
    set chromePosition to position of window 1
    click at {(item 1 of chromePosition) + 180, (item 2 of chromePosition) + 190}
  end tell
end tell
APPLESCRIPT

  wait_for_frontmost_app "Google Chrome" 5

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "Can we make this feel "
end tell
APPLESCRIPT

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome suggestion"
  press_key_code 48
  wait_for_log_fields "$start_line" "Chrome Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.google.Chrome" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.google.Chrome .*result=verified" "Chrome first verified insertion"
  press_key_code 50

  sleep 1
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh chrome --check
}

describe_plan

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

case "$APP" in
  textedit)
    run_textedit
    ;;
  chrome)
    run_chrome
    ;;
  codex|claude-code)
    run_manual_gated
    ;;
esac
