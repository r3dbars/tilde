#!/usr/bin/env bash
# Automatic real-app smoke entry point used by AppProofCommandRunner.
#
# This intentionally owns only the two automatic app lanes. Build and bundle
# setup stay in build_and_run.sh; fixtures are disposable and output is limited
# to privacy-safe status metadata.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BINARY="$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
SMOKE_TIMEOUT_SECONDS="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_TIMEOUT_SECONDS:-30}"
LOCK_DIR="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-real-app-smoke.lock}"

APP="${1:-}"
CHROME_FIXTURE="textarea"
CHROME_FIXTURE_WAS_SET=0
DRY_RUN=0
SKIP_BUILD=0
TEMP_DIR=""
TEXTEDIT_WINDOW_TITLE=""
CHROME_PID=""
LOCK_HELD=0

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|chrome> [--fixture <textarea|contenteditable>] [--skip-build] [--dry-run]

Runs a bounded automatic smoke against a disposable TextEdit document or an
isolated local Chrome fixture. It never reads, prints, or removes user content.
EOF
}

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

fail() {
  echo "real_app_smoke: $1" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEXTEDIT_WINDOW_TITLE" ]]; then
    osascript - "$TEXTEDIT_WINDOW_TITLE" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set smokeWindowTitle to item 1 of argv
  tell application "TextEdit"
    repeat with documentRef in documents
      try
        if name of documentRef is smokeWindowTitle then
          close documentRef saving no
          exit repeat
        end if
      end try
    end repeat
  end tell
end run
APPLESCRIPT
  fi

  if [[ -n "$CHROME_PID" ]] && kill -0 "$CHROME_PID" >/dev/null 2>&1; then
    kill "$CHROME_PID" >/dev/null 2>&1 || true
    wait "$CHROME_PID" >/dev/null 2>&1 || true
  fi

  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi

  if [[ "$LOCK_HELD" == "1" ]]; then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if [[ -z "$APP" ]]; then
  usage >&2
  exit 2
fi
shift

while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --fixture)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      CHROME_FIXTURE="$1"
      CHROME_FIXTURE_WAS_SET=1
      ;;
    --fixture=*)
      CHROME_FIXTURE="${1#--fixture=}"
      CHROME_FIXTURE_WAS_SET=1
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

case "$APP" in
  textedit)
    if [[ "$CHROME_FIXTURE_WAS_SET" == "1" ]]; then
      echo "real_app_smoke: --fixture is only supported for Chrome" >&2
      exit 2
    fi
    ;;
  chrome)
    case "$CHROME_FIXTURE" in
      textarea | contenteditable) ;;
      *)
        echo "real_app_smoke: unsupported Chrome fixture '$CHROME_FIXTURE'" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if is_truthy "${AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD:-}"; then
  SKIP_BUILD=1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "real_app_smoke: DRY RUN app=$APP fixture=$CHROME_FIXTURE skipBuild=$SKIP_BUILD"
  exit 0
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --verify
fi

[[ -x "$APP_BINARY" ]] || fail "current app bundle is unavailable; run script/build_and_run.sh --verify first"

current_app_is_running() {
  local pid command
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$command" == "$APP_BINARY" || "$command" == "$APP_BINARY "* ]]; then
      return 0
    fi
  done < <(pgrep -x SteadyType 2>/dev/null || true)
  return 1
}

current_app_is_running || fail "current checkout's SteadyType app is not running"

# build_and_run.sh waits for this same lock, so acquire it only after any
# delegated build has finished.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail "another real-app smoke is already running"
fi
LOCK_HELD=1
printf '%s\n' "$$" >"$LOCK_DIR/pid"

line_count() {
  if [[ -f "$1" ]]; then
    wc -l <"$1" | tr -d ' '
  else
    echo 0
  fi
}

wait_for_suggestion() {
  local start_line="$1"
  local bundle_identifier="$2"
  local deadline=$((SECONDS + SMOKE_TIMEOUT_SECONDS))

  while ((SECONDS < deadline)); do
    if [[ -f "$LOG_PATH" ]] &&
      tail -n "+$((start_line + 1))" "$LOG_PATH" |
        grep -Eq "suggestion-presented .*app=${bundle_identifier}([[:space:]]|$)"; then
      return 0
    fi
    sleep 0.25
  done

  fail "timed out waiting for a privacy-safe suggestion-presented event for $bundle_identifier"
}

type_disposable_text() {
  local process_name="$1"
  local process_pid="${2:-}"
  local expected_window_title="${3:-}"
  osascript - "$process_name" "$process_pid" "$expected_window_title" <<'APPLESCRIPT' >/dev/null
on run argv
  set targetProcessName to item 1 of argv
  set targetProcessPID to item 2 of argv
  set expectedWindowTitle to item 3 of argv
  tell application "System Events"
    if targetProcessPID is "" then
      set targetProcess to process targetProcessName
    else
      set targetProcess to first process whose unix id is (targetProcessPID as integer)
    end if
    set frontmost of targetProcess to true
    if expectedWindowTitle is not "" then
      if not (exists window expectedWindowTitle of targetProcess) then error "disposable smoke window is unavailable"
      perform action "AXRaise" of window expectedWindowTitle of targetProcess
    end if
    delay 0.2
    if expectedWindowTitle is not "" and name of front window of targetProcess is not expectedWindowTitle then
      error "disposable smoke window is not frontmost"
    end if
    keystroke "Smoke proof feels inst"
  end tell
end run
APPLESCRIPT
}

run_textedit() {
  local fixture_file start_line
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-textedit-smoke.XXXXXX")"
  fixture_file="$TEMP_DIR/textedit-smoke-$$.txt"
  TEXTEDIT_WINDOW_TITLE="$(basename "$fixture_file")"
  : >"$fixture_file"

  open -a TextEdit "$fixture_file"
  sleep 0.8
  start_line="$(line_count "$LOG_PATH")"
  type_disposable_text "TextEdit" "" "$TEXTEDIT_WINDOW_TITLE"
  wait_for_suggestion "$start_line" "com.apple.TextEdit"
  echo "real_app_smoke: PASS app=textedit fixture=disposable"
}

run_chrome() {
  local chrome_binary fixture_file fixture_markup start_line
  chrome_binary="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  [[ -x "$chrome_binary" ]] || fail "Google Chrome is unavailable"

  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/steadytype-chrome-smoke.XXXXXX")"
  fixture_file="$TEMP_DIR/fixture.html"
  case "$CHROME_FIXTURE" in
    textarea) fixture_markup='<textarea id="editor" autofocus></textarea>' ;;
    contenteditable) fixture_markup='<div id="editor" contenteditable="true" autofocus></div>' ;;
  esac
  cat >"$fixture_file" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>SteadyType Chrome Smoke</title>
<style>#editor { width: 720px; min-height: 180px; font: 18px system-ui; }</style>
$fixture_markup
<script>addEventListener('load', () => document.querySelector('#editor').focus())</script>
EOF

  "$chrome_binary" \
    --user-data-dir="$TEMP_DIR/profile" \
    --no-first-run \
    --disable-background-networking \
    --disable-component-update \
    --disable-sync \
    --force-renderer-accessibility \
    --new-window "file://$fixture_file" \
    >/dev/null 2>&1 &
  CHROME_PID="$!"
  sleep 1.5

  start_line="$(line_count "$LOG_PATH")"
  type_disposable_text "Google Chrome" "$CHROME_PID"
  wait_for_suggestion "$start_line" "com.google.Chrome"
  echo "real_app_smoke: PASS app=chrome fixture=$CHROME_FIXTURE"
}

case "$APP" in
  textedit) run_textedit ;;
  chrome) run_chrome ;;
esac
