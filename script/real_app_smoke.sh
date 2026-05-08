#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="${1:-}"
REQUESTED_APP="$APP"
NOTES_SESSION_APP=""
DRY_RUN=0
MANUAL_GATE=0
SKIP_BUILD="${AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD:-0}"
CHROME_FIXTURE="${AUTOCOMPLETE_LAB_CHROME_FIXTURE:-textarea}"
CHROME_FIXTURE_WAS_SET=0
TEMP_ENABLE_ENV_KEY="AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=0
TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|chrome|notes-title|notes-body|notes-checklist|notes|obsidian|codex|claude-code|claude> [--dry-run] [--manual-gate] [--skip-build] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|chat-like|all>]

Runs a real app smoke pass where it is safe to automate. Notes, Obsidian,
Codex, and Claude desktop are manual-gated so this script never types into
private notes, vaults, or agent prompts by surprise. Claude Code is currently
diagnostics-only until a terminal-host adapter exists.

Notes proof must use notes-title, notes-body, or notes-checklist. A generic
notes run only prints the surface picker and does not record proof.

Chrome defaults to the textarea fixture. Use --fixture chat-like to prove
Tab/full-accept do not submit a chat-style composer. Use --fixture monaco-real
or --fixture prosemirror-real for pinned upstream editor-engine fixtures in an
isolated Chrome process with renderer accessibility forced. Use --fixture all
to run every local Chrome browser/editor fixture with one app build.
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
  notes-title)
    APP="notes"
    NOTES_SESSION_APP="notes-title"
    ;;
  notes-body)
    APP="notes"
    NOTES_SESSION_APP="notes-body"
    ;;
  notes-checklist)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist"
    ;;
esac

case "$APP" in
  textedit|chrome|notes|obsidian|codex|claude-code|claude)
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

case "$CHROME_FIXTURE" in
  textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|chat-like|all)
    ;;
  *)
    echo "Unknown Chrome fixture: $CHROME_FIXTURE" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "$APP" != "chrome" && "$CHROME_FIXTURE_WAS_SET" == "1" ]]; then
  echo "--fixture is only supported for the Chrome smoke pass." >&2
  usage >&2
  exit 2
fi

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.autocomplete-lab}"
declare -a SMOKE_TMP_DIRS=()
declare -a SMOKE_CHROME_PIDS=()
CHROME_FIXTURE_ASSET_URL=""
CHROME_FIXTURE_SCRIPT_URL=""

cleanup_smoke_tmp_dirs() {
  if ((${#SMOKE_TMP_DIRS[@]})); then
    rm -rf "${SMOKE_TMP_DIRS[@]}"
  fi
}

cleanup_smoke_chrome_pids() {
  if ((${#SMOKE_CHROME_PIDS[@]})); then
    local pid
    for pid in "${SMOKE_CHROME_PIDS[@]}"; do
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    done
  fi
}

cleanup_smoke() {
  cleanup_smoke_chrome_pids
  cleanup_smoke_tmp_dirs

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$TEMP_ENABLE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi
}

trap cleanup_smoke EXIT

make_tmp_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  SMOKE_TMP_DIRS+=("$tmp_dir")
  printf '%s\n' "$tmp_dir"
}

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

latest_runtime_is_ready() {
  local latest_runtime_line
  latest_runtime_line="$(grep -E " runtime .*readinessStage=" "$LOG_PATH" 2>/dev/null | tail -n 1 || true)"
  [[ "$latest_runtime_line" == *"readinessStage=ready"* ]]
}

wait_for_runtime_ready() {
  local start_line="$1"
  local label="${2:-runtime ready}"
  local timeout_seconds="${3:-60}"
  local allow_existing_ready="${4:-0}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | grep -E " runtime .*readinessStage=ready" >/dev/null; then
      return 0
    fi

    if [[ "$allow_existing_ready" == "1" ]] && latest_runtime_is_ready; then
      return 0
    fi

    sleep 0.2
  done

  echo "Timed out waiting for $label." >&2
  echo "Pattern: runtime readinessStage=ready" >&2
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

assert_frontmost_app() {
  local expected="$1"
  local label="$2"
  local frontmost
  frontmost="$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
  if [[ "$frontmost" != "$expected" ]]; then
    echo "$label lost focus before accept. Expected frontmost app '$expected', got '${frontmost:-unknown}'." >&2
    exit 1
  fi
}

frontmost_process_id() {
  swift - <<'SWIFT'
import AppKit
print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
SWIFT
}

wait_for_frontmost_process_id() {
  local expected_pid="$1"
  local timeout_seconds="${2:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local frontmost_pid
    frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
    if [[ "$frontmost_pid" == "$expected_pid" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Chrome process $expected_pid to become frontmost." >&2
  exit 1
}

assert_frontmost_process_id() {
  local expected_pid="$1"
  local label="$2"
  local frontmost_pid
  frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
  if [[ "$frontmost_pid" != "$expected_pid" ]]; then
    echo "$label lost focus before accept. Expected frontmost pid '$expected_pid', got '${frontmost_pid:-unknown}'." >&2
    exit 1
  fi
}

screenshot_trace_requested() {
  [[ "${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-}" =~ ^(1|true|yes|on)$ ]]
}

wait_for_screenshot_capture_if_enabled() {
  local start_line="$1"
  local bundle_id="$2"
  local label="$3"

  if screenshot_trace_requested; then
    wait_for_log_pattern "$start_line" "screenshot-captured .*app=$bundle_id" "$label screenshot" 8
  fi
}

manual_gate_reason() {
  case "$APP" in
    notes)
      echo "it can focus private Apple Notes content"
      ;;
    obsidian)
      echo "it can focus a private Obsidian vault"
      ;;
    codex|claude-code|claude)
      echo "it focuses an agent prompt"
      ;;
    *)
      echo "it focuses user content"
      ;;
  esac
}

smoke_target_bundle_ids() {
  case "$APP" in
    textedit)
      printf 'com.apple.TextEdit\n'
      ;;
    chrome)
      printf 'com.google.Chrome\n'
      ;;
    notes)
      printf 'com.apple.Notes\n'
      ;;
    obsidian)
      printf 'md.obsidian\n'
      ;;
    codex)
      printf 'com.openai.codex\n'
      ;;
    claude-code)
      printf 'com.anthropic.claude-code\n'
      ;;
    claude)
      printf 'com.anthropic.claudefordesktop\n'
      ;;
  esac
}

prepare_temporary_app_enablement() {
  local bundle_ids
  bundle_ids="$(smoke_target_bundle_ids | paste -sd, -)"
  if [[ -z "$bundle_ids" ]]; then
    return 0
  fi

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    TEMP_ENABLE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$TEMP_ENABLE_ENV_KEY" 2>/dev/null || true)"
    TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS="$bundle_ids"
  launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  echo "Temporary app enablement for smoke: $bundle_ids"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so temporary enablement only applies if the app was launched with this environment." >&2
  fi
}

accept_all_shortcut() {
  local configured="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-}"
  if [[ -z "$configured" ]]; then
    configured="$(defaults read "$DEFAULTS_DOMAIN" AcceptAllShortcut 2>/dev/null || true)"
  fi

  case "$configured" in
    optionTab)
      printf 'optionTab\n'
      ;;
    backtick|"")
      printf 'backtick\n'
      ;;
    *)
      echo "Unknown accept-all shortcut '$configured'; expected backtick or optionTab." >&2
      exit 2
      ;;
  esac
}

press_accept_all_shortcut() {
  case "$(accept_all_shortcut)" in
    optionTab)
      osascript <<'APPLESCRIPT'
tell application "System Events"
  key code 48 using option down
end tell
APPLESCRIPT
      ;;
    backtick)
      press_key_code 50
      ;;
  esac
}

notes_session_app() {
  if [[ -n "$NOTES_SESSION_APP" ]]; then
    printf '%s\n' "$NOTES_SESSION_APP"
    return 0
  fi

  case "${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-}" in
    notes-title|notes-body|notes-checklist)
      printf '%s\n' "$AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL"
      return 0
      ;;
  esac

  return 1
}

print_notes_surface_commands() {
  cat <<'EOF'
Choose one Notes surface:
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
EOF
}

press_key_code() {
  local key_code="$1"

  osascript <<APPLESCRIPT
tell application "System Events"
  key code $key_code
end tell
APPLESCRIPT
}

file_url() {
  local path="$1"
  printf 'file://%s\n' "$path"
}

prepare_chrome_fixture_assets() {
  local fixture="$1"
  local tmp_dir="$2"

  CHROME_FIXTURE_ASSET_URL=""
  CHROME_FIXTURE_SCRIPT_URL=""

  case "$fixture" in
    monaco-real)
      if ! command -v npm >/dev/null 2>&1; then
        echo "npm is required for the real Monaco smoke fixture." >&2
        exit 1
      fi
      local deps_dir="$tmp_dir/monaco-real-deps"
      npm install --silent --no-audit --no-fund --prefix "$deps_dir" monaco-editor@0.55.1 >/dev/null
      CHROME_FIXTURE_ASSET_URL="$(file_url "$deps_dir/node_modules/monaco-editor/min/vs")"
      ;;
    prosemirror-real)
      if ! command -v npm >/dev/null 2>&1; then
        echo "npm is required for the real ProseMirror smoke fixture." >&2
        exit 1
      fi
      local deps_dir="$tmp_dir/prosemirror-real-deps"
      local source_file="$deps_dir/prosemirror-real-entry.js"
      local bundle_file="$tmp_dir/prosemirror-real.bundle.js"
      npm install --silent --no-audit --no-fund --prefix "$deps_dir" \
        esbuild@0.28.0 \
        prosemirror-model@1.25.4 \
        prosemirror-schema-basic@1.2.4 \
        prosemirror-state@1.4.4 \
        prosemirror-view@1.41.8 >/dev/null
      cat >"$source_file" <<'JAVASCRIPT'
import { schema } from "prosemirror-schema-basic";
import { EditorState, TextSelection } from "prosemirror-state";
import { EditorView } from "prosemirror-view";

window.AutocompleteLabRealProseMirrorSmoke = {
  mount(element) {
    const view = new EditorView(element, {
      state: EditorState.create({ schema }),
      attributes: {
        "aria-label": "Real ProseMirror smoke editor",
        "aria-multiline": "true",
        "data-smoke-editor": "true",
        "role": "textbox",
        "spellcheck": "false"
      }
    });

    window.autocompleteSmokeEditorText = function () {
      return view.state.doc.textContent;
    };
    window.focusSmokeEditor = function () {
      view.focus();
      const transaction = view.state.tr.setSelection(TextSelection.atEnd(view.state.doc));
      view.dispatch(transaction);
    };
    window.autocompleteSmokeReady = true;
    window.focusSmokeEditor();
  }
};
JAVASCRIPT
      "$deps_dir/node_modules/.bin/esbuild" "$source_file" \
        --bundle \
        --format=iife \
        --global-name=AutocompleteLabRealProseMirrorBundle \
        --outfile="$bundle_file" \
        --log-level=error
      CHROME_FIXTURE_SCRIPT_URL="$(file_url "$bundle_file")"
      ;;
  esac
}

wait_for_chrome_smoke_ready() {
  local fixture="$1"
  local timeout_seconds="${2:-20}"
  local chrome_pid="${3:-}"
  local deadline=$((SECONDS + timeout_seconds))

  case "$fixture" in
    monaco-real|prosemirror-real)
      ;;
    *)
      return 0
      ;;
  esac

  while ((SECONDS <= deadline)); do
    local tab_title
    if [[ -n "$chrome_pid" ]]; then
      tab_title="$(chrome_window_title_for_pid "$chrome_pid" 2>/dev/null || true)"
    else
      tab_title="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Google Chrome"
  try
    return title of active tab of front window
  on error
    return ""
  end try
end tell
APPLESCRIPT
)"
    fi
    if [[ "$tab_title" == *"[ready=1]"* ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Chrome $fixture fixture readiness." >&2
  exit 1
}

chrome_fixture_uses_isolated_accessibility_chrome() {
  case "$1" in
    monaco-real|prosemirror-real)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_window_title_for_pid() {
  local chrome_pid="$1"

  swift - "$chrome_pid" <<'SWIFT'
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2,
      let rawPID = Int32(CommandLine.arguments[1]) else {
    exit(2)
}
let pid = pid_t(rawPID)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }

    return value
}

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)

if let window = copyAttribute(appElement, kAXFocusedWindowAttribute) {
    let windowElement = window as! AXUIElement
    if let title = copyAttribute(windowElement, kAXTitleAttribute) as? String {
        print(title)
        exit(0)
    }
}

exit(1)
SWIFT
}

launch_isolated_chrome_fixture() {
  local chrome_url="$1"
  local tmp_dir="$2"
  local profile_dir="$tmp_dir/chrome-profile"
  local chrome_binary="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

  if [[ ! -x "$chrome_binary" ]]; then
    echo "Google Chrome binary is missing: $chrome_binary" >&2
    exit 1
  fi

  "$chrome_binary" \
    --user-data-dir="$profile_dir" \
    --force-renderer-accessibility \
    --no-first-run \
    --no-default-browser-check \
    --disable-default-apps \
    --disable-sync \
    --new-window "$chrome_url" >/dev/null 2>&1 &

  local chrome_pid="$!"
  SMOKE_CHROME_PIDS+=("$chrome_pid")
  printf '%s\n' "$chrome_pid"
}

focus_chrome_process_window() {
  local chrome_pid="$1"
  local click_x_offset="$2"
  local click_y_offset="$3"

  swift - "$chrome_pid" "$click_x_offset" "$click_y_offset" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 4,
      let rawPID = Int32(CommandLine.arguments[1]),
      let clickXOffset = Double(CommandLine.arguments[2]),
      let clickYOffset = Double(CommandLine.arguments[3]) else {
    exit(2)
}
let pid = pid_t(rawPID)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }

    return value
}

func bounds(for element: AXUIElement) -> CGRect? {
    guard let positionValue = copyAttribute(element, kAXPositionAttribute),
          let sizeValue = copyAttribute(element, kAXSizeAttribute) else {
        return nil
    }

    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
          AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
        return nil
    }

    return CGRect(origin: position, size: size)
}

if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate(options: [.activateAllWindows])
}

Thread.sleep(forTimeInterval: 0.35)

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)

guard let windowValue = copyAttribute(appElement, kAXFocusedWindowAttribute),
      let windowBounds = bounds(for: windowValue as! AXUIElement),
      let source = CGEventSource(stateID: .hidSystemState) else {
    exit(1)
}

let point = CGPoint(x: windowBounds.minX + clickXOffset, y: windowBounds.minY + clickYOffset)
for eventType in [CGEventType.leftMouseDown, .leftMouseUp] {
    guard let event = CGEvent(
        mouseEventSource: source,
        mouseType: eventType,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        exit(1)
    }
    event.post(tap: .cghidEventTap)
}
SWIFT
}

chrome_fixture_click_offsets() {
  local fixture="$1"

  case "$fixture" in
    prosemirror-real)
      printf '180 260\n'
      ;;
    *)
      printf '180 190\n'
      ;;
  esac
}

focus_chrome_smoke_editor() {
  local fixture="${1:-$CHROME_FIXTURE}"
  local chrome_pid="${2:-}"
  local click_x_offset click_y_offset
  read -r click_x_offset click_y_offset < <(chrome_fixture_click_offsets "$fixture")

  if [[ -n "$chrome_pid" ]]; then
    focus_chrome_process_window "$chrome_pid" "$click_x_offset" "$click_y_offset"
    return 0
  fi

  osascript >/dev/null <<APPLESCRIPT
tell application "Google Chrome"
  activate
  try
    tell active tab of front window to execute javascript "window.focusSmokeEditor && window.focusSmokeEditor();"
  end try
end tell
delay 0.1
tell application "System Events"
  tell process "Google Chrome"
    set frontmost to true
    set chromePosition to position of window 1
    click at {(item 1 of chromePosition) + $click_x_offset, (item 2 of chromePosition) + $click_y_offset}
  end tell
end tell
APPLESCRIPT
  wait_for_frontmost_app "Google Chrome" 5
}

focus_textedit_smoke_editor() {
  local window_title="${1:-}"

  if [[ -n "$window_title" ]]; then
    osascript - "$window_title" >/dev/null <<'APPLESCRIPT'
on run argv
  set targetTitle to item 1 of argv
  tell application "System Events"
    tell process "TextEdit"
      set foundTarget to false
      set frontmost to true
      repeat with candidateWindow in windows
        if name of candidateWindow is targetTitle then
          set foundTarget to true
          perform action "AXRaise" of candidateWindow
          exit repeat
        end if
      end repeat
      if foundTarget is false then
        error "No TextEdit smoke window named " & targetTitle number 1000
      end if
    end tell
  end tell
end run
APPLESCRIPT
  else
    osascript >/dev/null <<'APPLESCRIPT'
tell application "System Events"
  tell process "TextEdit"
    set frontmost to true
  end tell
end tell
APPLESCRIPT
  fi

  wait_for_frontmost_app "TextEdit" 5
}

click_textedit_smoke_editor() {
  local window_title="${1:-}"

  if [[ -n "$window_title" ]]; then
    osascript - "$window_title" >/dev/null <<'APPLESCRIPT'
on run argv
  set targetTitle to item 1 of argv
  tell application "System Events"
    tell process "TextEdit"
      set foundTarget to false
      set frontmost to true
      repeat with candidateWindow in windows
        if name of candidateWindow is targetTitle then
          set foundTarget to true
          perform action "AXRaise" of candidateWindow
          set windowPosition to position of candidateWindow
          set windowSize to size of candidateWindow
          click at {(item 1 of windowPosition) + ((item 1 of windowSize) / 2), (item 2 of windowPosition) + 160}
          exit repeat
        end if
      end repeat
      if foundTarget is false then
        error "No TextEdit smoke window named " & targetTitle number 1000
      end if
    end tell
  end tell
end run
APPLESCRIPT
  else
    osascript >/dev/null <<'APPLESCRIPT'
tell application "System Events"
  tell process "TextEdit"
    set frontmost to true
    if exists window 1 then
      set windowPosition to position of window 1
      set windowSize to size of window 1
      click at {(item 1 of windowPosition) + ((item 1 of windowSize) / 2), (item 2 of windowPosition) + 160}
    end if
  end tell
end tell
APPLESCRIPT
  fi

  wait_for_frontmost_app "TextEdit" 5
}

assert_chrome_chat_fixture_not_submitted() {
  local label="$1"
  local tab_title submit_count

  tab_title="$(osascript <<'APPLESCRIPT'
tell application "Google Chrome"
  try
    return title of active tab of front window
  on error
    return "unknown"
  end try
end tell
APPLESCRIPT
)"

  if [[ "$tab_title" =~ submits=([0-9]+) ]]; then
    submit_count="${BASH_REMATCH[1]}"
  else
    echo "Could not read Chrome chat-like submit count during $label; expected tab title to contain [submits=N], got: $tab_title" >&2
    exit 1
  fi

  if [[ "$submit_count" != "0" ]]; then
    echo "Chrome chat-like fixture submitted unexpectedly during $label; submit count was $submit_count." >&2
    exit 1
  fi
}

chrome_fixture_html() {
  local fixture="${1:-$CHROME_FIXTURE}"

  case "$fixture" in
    textarea)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Textarea Smoke</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<textarea data-smoke-editor autofocus aria-label="Smoke textarea" style="font: 18px -apple-system; width: 720px; height: 180px; margin: 80px;"></textarea>
<script>
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  editor.setSelectionRange(editor.value.length, editor.value.length);
};
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
    contenteditable)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Contenteditable Smoke</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<main data-smoke-editor role="textbox" aria-label="Smoke rich text editor" contenteditable="true" spellcheck="false" style="font: 18px -apple-system; width: 720px; min-height: 180px; margin: 80px; padding: 12px; border: 1px solid #bbb; outline: none;"></main>
<script>
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
};
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
    editor-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Editor-Like Smoke</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<div class="cm-editor" role="application" aria-label="Local editor-like smoke fixture" style="display: grid; grid-template-columns: 48px 1fr; font: 18px -apple-system; width: 720px; min-height: 180px; margin: 80px; border: 1px solid #bbb;">
  <div aria-hidden="true" style="padding-top: 14px; border-right: 1px solid #ddd; background: #f5f5f2; color: #777; font: 14px Menlo, monospace; text-align: center;">1</div>
  <div data-smoke-editor class="cm-content" role="textbox" aria-label="CodeMirror-style editor" aria-multiline="true" contenteditable="true" spellcheck="false" style="min-height: 160px; padding: 12px; outline: none; white-space: pre-wrap; overflow-wrap: anywhere;"></div>
</div>
<script>
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
};
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
    monaco-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Monaco-Like Smoke</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<style>
body { margin: 0; background: #f7f7f7; }
.monaco-editor {
  display: grid;
  grid-template-columns: 56px 1fr;
  width: 760px;
  min-height: 220px;
  margin: 80px;
  border: 1px solid #c7c7c7;
  background: #1e1e1e;
  color: #d4d4d4;
  font: 16px Menlo, Monaco, Consolas, monospace;
}
.margin {
  padding: 18px 12px 0 0;
  text-align: right;
  color: #858585;
  background: #252526;
  border-right: 1px solid #333;
}
.overflow-guard { min-width: 0; overflow: hidden; }
.monaco-scrollable-element { min-height: 220px; overflow: auto; }
.view-lines { min-height: 180px; padding: 18px 20px; }
[data-smoke-editor] {
  min-height: 160px;
  outline: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  caret-color: #ffffff;
}
</style>
<section class="monaco-editor" role="application" aria-label="Local Monaco-like smoke fixture">
  <div class="margin" aria-hidden="true">1</div>
  <div class="overflow-guard">
    <div class="monaco-scrollable-element">
      <div class="view-lines">
        <div data-smoke-editor class="view-line inputarea monaco-mouse-cursor-text" role="textbox" aria-label="Monaco-like editor input" aria-multiline="true" contenteditable="true" spellcheck="false"></div>
      </div>
    </div>
  </div>
</section>
<script>
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
};
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
    monaco-real)
      cat <<HTML
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Real Monaco Smoke [ready=0]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' file: blob:; worker-src blob: file:; connect-src 'none'; img-src 'self' data: file:">
<style>
body { margin: 0; background: #f7f7f7; }
.monaco-host {
  width: 780px;
  height: 240px;
  margin: 80px;
  border: 1px solid #c7c7c7;
}
.label {
  margin: 0 80px;
  color: #555;
  font: 13px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
</style>
<div class="label">Real Monaco editor smoke fixture</div>
<div data-smoke-editor class="monaco-host" aria-label="Real Monaco smoke editor"></div>
<script src="$CHROME_FIXTURE_ASSET_URL/loader.js"></script>
<script>
window.autocompleteSmokeReady = false;
require.config({ paths: { vs: "$CHROME_FIXTURE_ASSET_URL" } });
require(["vs/editor/editor.main"], function () {
  const container = document.querySelector("[data-smoke-editor]");
  const editor = monaco.editor.create(container, {
    value: "",
    language: "plaintext",
    automaticLayout: true,
    fontSize: 16,
    fontFamily: "Menlo, Monaco, Consolas, monospace",
    lineNumbers: "on",
    minimap: { enabled: false },
    quickSuggestions: false,
    suggestOnTriggerCharacters: false,
    acceptSuggestionOnCommitCharacter: false,
    acceptSuggestionOnEnter: "off",
    tabCompletion: "off",
    wordBasedSuggestions: "off",
    scrollBeyondLastLine: false,
    wordWrap: "on",
    accessibilitySupport: "on",
    ariaLabel: "Real Monaco smoke editor"
  });

  window.autocompleteSmokeEditorText = function () {
    return editor.getValue();
  };
  window.focusSmokeEditor = function () {
    const model = editor.getModel();
    const lineNumber = model.getLineCount();
    const column = model.getLineMaxColumn(lineNumber);
    editor.setPosition({ lineNumber, column });
    editor.focus();
  };
  window.autocompleteSmokeReady = true;
  document.title = "Autocomplete Lab Chrome Real Monaco Smoke [ready=1]";
  window.focusSmokeEditor();
});
</script>
HTML
      ;;
    prosemirror-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome ProseMirror-Like Smoke</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<style>
body { margin: 0; background: #fbfbfb; }
.editor-shell {
  width: 760px;
  min-height: 220px;
  margin: 80px;
  border: 1px solid #cfcfcf;
  background: #ffffff;
  font: 18px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.menubar {
  display: flex;
  gap: 12px;
  padding: 10px 14px;
  border-bottom: 1px solid #e1e1e1;
  color: #555;
  font-size: 13px;
}
.ProseMirror {
  min-height: 170px;
  padding: 18px 22px;
  outline: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.ProseMirror p { margin: 0 0 12px; }
</style>
<article class="editor-shell" aria-label="Local ProseMirror-like smoke fixture">
  <div class="menubar" aria-hidden="true"><span>B</span><span>I</span><span>H1</span></div>
  <div data-smoke-editor class="ProseMirror" role="textbox" aria-label="ProseMirror-like editor" aria-multiline="true" contenteditable="true" spellcheck="false"><p><br></p></div>
</article>
<script>
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  const paragraph = editor.querySelector("p") || editor;
  const range = document.createRange();
  range.selectNodeContents(paragraph);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
};
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
    prosemirror-real)
      cat <<HTML
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Real ProseMirror Smoke [ready=0]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' file:; connect-src 'none'; img-src 'self' data: file:">
<style>
body { margin: 0; background: #fbfbfb; }
.editor-shell {
  width: 760px;
  min-height: 220px;
  margin: 80px;
  border: 1px solid #cfcfcf;
  background: #ffffff;
  font: 18px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.menubar {
  display: flex;
  gap: 12px;
  padding: 10px 14px;
  border-bottom: 1px solid #e1e1e1;
  color: #555;
  font-size: 13px;
}
.ProseMirror {
  min-height: 170px;
  padding: 18px 22px;
  outline: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
.ProseMirror p { margin: 0 0 12px; }
</style>
<article class="editor-shell" aria-label="Real ProseMirror smoke fixture">
  <div class="menubar" aria-hidden="true"><span>B</span><span>I</span><span>H1</span></div>
  <div data-prosemirror-mount></div>
</article>
<script src="$CHROME_FIXTURE_SCRIPT_URL"></script>
<script>
window.autocompleteSmokeReady = false;
window.AutocompleteLabRealProseMirrorSmoke.mount(document.querySelector("[data-prosemirror-mount]"));
document.title = "Autocomplete Lab Chrome Real ProseMirror Smoke [ready=1]";
</script>
HTML
      ;;
    chat-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Chrome Chat-Like No-Submit Smoke [submits=0]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<style>
body {
  margin: 0;
  background: #f6f6f6;
  color: #1f2328;
  font: 16px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.thread {
  width: 760px;
  margin: 70px auto;
}
.message {
  max-width: 520px;
  padding: 12px 14px;
  border-radius: 14px;
  background: white;
  border: 1px solid #ddd;
}
form {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 10px;
  align-items: end;
  margin-top: 22px;
  padding: 12px;
  border: 1px solid #d7d7d7;
  border-radius: 16px;
  background: white;
}
[data-smoke-editor] {
  min-height: 44px;
  max-height: 140px;
  padding: 10px 12px;
  border: 1px solid #cfcfcf;
  border-radius: 10px;
  outline: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
button {
  min-width: 72px;
  min-height: 38px;
}
.meter {
  margin-top: 10px;
  color: #666;
  font-size: 13px;
}
</style>
<section class="thread" aria-label="Local chat-like smoke fixture">
  <div class="message">Local disposable chat fixture.</div>
  <form data-smoke-form>
    <div data-smoke-editor role="textbox" aria-label="Chat message composer" aria-multiline="true" contenteditable="true" spellcheck="false"></div>
    <button type="submit">Send</button>
  </form>
  <div class="meter" aria-live="polite">Submits: <span data-smoke-submit-count>0</span></div>
</section>
<script>
window.autocompleteSmokeSubmitCount = 0;
window.updateSmokeSubmitCount = function () {
  document.title = "Autocomplete Lab Chrome Chat-Like No-Submit Smoke [submits=" + window.autocompleteSmokeSubmitCount + "]";
  document.querySelector("[data-smoke-submit-count]").textContent = String(window.autocompleteSmokeSubmitCount);
};
window.autocompleteSmokeEditorText = function () {
  return document.querySelector("[data-smoke-editor]").innerText;
};
window.focusSmokeEditor = function () {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
};
document.querySelector("[data-smoke-form]").addEventListener("submit", function (event) {
  event.preventDefault();
  window.autocompleteSmokeSubmitCount += 1;
  window.updateSmokeSubmitCount();
});
window.updateSmokeSubmitCount();
window.addEventListener("load", window.focusSmokeEditor);
</script>
HTML
      ;;
  esac
}

describe_plan() {
  echo "Real app smoke: $APP"
  echo "Diagnostics log: $LOG_PATH"
  echo "Trace log: $TRACE_PATH"
  case "$APP" in
    textedit)
      echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file, type a test fragment, then validate logs and traces."
      echo "Safety: the smoke launch temporarily enables TextEdit only for this proof pass."
      ;;
    chrome)
      echo "Chrome fixture: $CHROME_FIXTURE"
      if [[ "$CHROME_FIXTURE" == "all" ]]; then
        echo "Plan: build/relaunch AutocompleteLab, then run disposable Chrome textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and chat-like no-submit local fixtures."
      else
        echo "Plan: build/relaunch AutocompleteLab, open a disposable Chrome $CHROME_FIXTURE fixture, type a test fragment, then validate logs and traces."
      fi
      echo "Safety: the smoke launch temporarily enables Chrome only for this proof pass."
      ;;
    notes)
      local notes_app notes_surface
      if notes_app="$(notes_session_app)"; then
        notes_surface="${notes_app#notes-}"
        echo "Plan: manual-gated Apple Notes $notes_surface proof. The script validates only that surface after you run it."
      else
        echo "Plan: choose a manual-gated Apple Notes surface before recording proof."
        print_notes_surface_commands
      fi
      echo "Safety: pass --manual-gate to continue. Use only the disposable autocomplete smoke note."
      ;;
    obsidian)
      echo "Plan: manual-gated disposable Obsidian smoke. The script prints the checklist and validates after you run it."
      echo "Safety: pass --manual-gate to continue. Use only a disposable vault note."
      ;;
    codex)
      echo "Plan: manual-gated prompt smoke. The script validates one-word Tab accept without submit after you run it."
      echo "Safety: pass --manual-gate to continue. Do not press Enter; full accept waits for separate full-accept no-submit proof."
      ;;
    claude-code)
      echo "Plan: Claude Code remains a terminal-host proof gap. The installed com.anthropic.claude-code bundle is usually a background-only CLI helper, not the interactive typing surface."
      echo "Safety: Terminal-hosted Claude Code is blocked until a separate adapter proves one-word Tab accept without submitting shell input or an agent prompt."
      echo "Proof target: a future foreground Claude Code prompt must still validate one-word Tab accept without submit before graduation."
      ;;
    claude)
      echo "Plan: manual-gated prompt smoke. The script validates one-word Tab accept without submit after you run it."
      echo "Safety: pass --manual-gate to continue. Do not press Enter; full accept waits for separate full-accept no-submit proof."
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
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local manual_app="$APP"
  if [[ "$APP" == "notes" ]]; then
    if ! manual_app="$(notes_session_app)"; then
      echo "Notes real smoke cannot record a generic Notes proof." >&2
      print_notes_surface_commands >&2
      exit 2
    fi
  fi

  prepare_temporary_app_enablement
  build_if_needed
  local full_accept_key
  full_accept_key="$(accept_all_shortcut)"
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
    ./script/manual_smoke_session.sh "$manual_app"
}

run_claude_code_blocked() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  echo "Claude Code direct real smoke is blocked for this build." >&2
  echo "The com.anthropic.claude-code bundle is treated as diagnostics-only because the live typing surface is terminal-hosted CLI input." >&2
  echo "Add a terminal-host adapter and no-submit proof before recording Claude Code as complete." >&2
  exit 2
}

run_textedit() {
  local runtime_start_line start_line textedit_file textedit_tmp_dir textedit_window_title trace_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "TextEdit runtime readiness" 60 "$SKIP_BUILD"

  textedit_tmp_dir="$(make_tmp_dir)"
  textedit_file="$textedit_tmp_dir/textedit-smoke-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  textedit_window_title="$(basename "$textedit_file")"
  : >"$textedit_file"
  open -a TextEdit "$textedit_file"
  wait_for_frontmost_app "TextEdit" 5
  sleep 0.8

  focus_textedit_smoke_editor "$textedit_window_title"
  click_textedit_smoke_editor "$textedit_window_title"
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "a" using command down
  key code 51
  key code 53
end tell
delay 0.4
APPLESCRIPT
  click_textedit_smoke_editor "$textedit_window_title"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "Smoke proof feels inst"
  key code 53
end tell
APPLESCRIPT

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.TextEdit" "TextEdit"
  assert_frontmost_app "TextEdit" "TextEdit"
  focus_textedit_smoke_editor "$textedit_window_title"
  press_key_code 48
  wait_for_log_fields "$start_line" "TextEdit Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.TextEdit .*result=verified" "TextEdit first verified insertion"
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"
  second_start_line="$(line_count "$LOG_PATH")"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke " and stays inst"
  key code 53
end tell
APPLESCRIPT

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.TextEdit" "TextEdit second"
  assert_frontmost_app "TextEdit" "TextEdit"
  focus_textedit_smoke_editor "$textedit_window_title"
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "TextEdit full acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"

  sleep 1
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh textedit --check
}

run_chrome_fixture() {
  local fixture="$1"
  local start_line trace_start_line tmp_dir html_file
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"
  tmp_dir="$(make_tmp_dir)"
  html_file="$tmp_dir/autocomplete-lab-chrome-$fixture-smoke.html"

  prepare_chrome_fixture_assets "$fixture" "$tmp_dir"
  chrome_fixture_html "$fixture" >"$html_file"

  local chrome_url="file://$html_file"
  local click_x_offset click_y_offset
  read -r click_x_offset click_y_offset < <(chrome_fixture_click_offsets "$fixture")
  local chrome_pid=""

  echo "Running Chrome fixture: $fixture"

  if chrome_fixture_uses_isolated_accessibility_chrome "$fixture"; then
    chrome_pid="$(launch_isolated_chrome_fixture "$chrome_url" "$tmp_dir")"
    sleep 2.2
    focus_chrome_smoke_editor "$fixture" "$chrome_pid"
  else
    osascript >/dev/null <<APPLESCRIPT
tell application "Google Chrome"
  activate
  if not (exists window 1) then make new window
  set URL of active tab of front window to "$chrome_url"
end tell
delay 1.2
tell application "Google Chrome"
  try
    tell active tab of front window to execute javascript "window.focusSmokeEditor && window.focusSmokeEditor();"
  end try
end tell
delay 0.2
tell application "System Events"
  tell process "Google Chrome"
    set frontmost to true
    set chromePosition to position of window 1
    click at {(item 1 of chromePosition) + $click_x_offset, (item 2 of chromePosition) + $click_y_offset}
  end tell
end tell
APPLESCRIPT
  fi

  if [[ -n "$chrome_pid" ]]; then
    wait_for_frontmost_process_id "$chrome_pid" 5
  else
    wait_for_frontmost_app "Google Chrome" 5
  fi
  wait_for_chrome_smoke_ready "$fixture" 20 "$chrome_pid"
  focus_chrome_smoke_editor "$fixture" "$chrome_pid"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "Smoke proof feels inst"
end tell
APPLESCRIPT

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.google.Chrome" "Chrome $fixture"
  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture"
  fi
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  press_key_code 48
  wait_for_log_fields "$start_line" "Chrome $fixture Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.google.Chrome" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.google.Chrome .*result=verified" "Chrome $fixture first verified insertion"
  if [[ "$fixture" == "chat-like" ]]; then
    assert_chrome_chat_fixture_not_submitted "Tab acceptance"
  fi
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"
  second_start_line="$(line_count "$LOG_PATH")"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke " and stays inst"
end tell
APPLESCRIPT

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.google.Chrome" "Chrome $fixture second"
  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture"
  fi
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "Chrome $fixture full acceptance" 12 \
    "keyboard-action" \
    "app=com.google.Chrome" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"

  if [[ "$fixture" == "chat-like" ]]; then
    assert_chrome_chat_fixture_not_submitted "full acceptance"
  fi

  sleep 1
  AUTOCOMPLETE_LAB_CHROME_FIXTURE="$fixture" \
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh chrome --check
}

run_chrome() {
  if ! osascript -e 'id of application "Google Chrome"' >/dev/null 2>&1; then
    echo "Google Chrome is not installed or not scriptable on this machine." >&2
    exit 1
  fi

  local runtime_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "Chrome runtime readiness" 60 "$SKIP_BUILD"

  if [[ "$CHROME_FIXTURE" == "all" ]]; then
    run_chrome_fixture textarea
    run_chrome_fixture contenteditable
    run_chrome_fixture editor-like
    run_chrome_fixture monaco-like
    run_chrome_fixture prosemirror-like
    run_chrome_fixture monaco-real
    run_chrome_fixture prosemirror-real
    run_chrome_fixture chat-like
  else
    run_chrome_fixture "$CHROME_FIXTURE"
  fi
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
  notes|obsidian|codex|claude-code|claude)
    if [[ "$APP" == "claude-code" ]]; then
      run_claude_code_blocked
    else
      run_manual_gated
    fi
    ;;
esac
