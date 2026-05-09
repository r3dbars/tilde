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
CHROME_ACCESSIBILITY_MODE="${AUTOCOMPLETE_LAB_CHROME_ACCESSIBILITY_MODE:-forced}"
CHROME_ACCESSIBILITY_MODE_WAS_SET=0
CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF=0
TEMP_ENABLE_ENV_KEY="AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=0
TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""
PROOF_MODE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
PROOF_MODE_LAUNCHCTL_WAS_PREPARED=0
PROOF_MODE_LAUNCHCTL_PREVIOUS=""

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|chrome|notes-title|notes-body|notes-checklist|notes-title-undo|notes-body-undo|notes-checklist-undo|notes|obsidian|codex|claude-code|claude> [--dry-run] [--manual-gate] [--skip-build] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|codemirror-official|monaco-official|prosemirror-official|chat-like|all>] [--chrome-accessibility <forced|default>] [--include-default-real-editor-proof]

Runs a real app smoke pass where it is safe to automate. Notes body proof has
a guarded disposable-note driver; other Notes surfaces, Obsidian, Codex,
Claude Code, and Claude desktop are manual-gated so this script never types
into private notes, vaults, terminal prompts, or agent prompts by surprise.

Notes proof must use notes-title, notes-body, notes-checklist, or their
notes-*-undo variants. A generic notes run only prints the surface picker and
does not record proof.

Chrome defaults to the textarea fixture in an isolated Chrome process with
renderer accessibility forced. Use --fixture chat-like to prove Tab/full-accept
do not submit a chat-style composer. Use --fixture monaco-real or
--fixture prosemirror-real for pinned upstream editor-engine fixtures. Use
--chrome-accessibility default to run local fixtures in the normal frontmost
Chrome window as an experimental default-AX exposure proof. Use
--fixture codemirror-official, monaco-official, or prosemirror-official to run
bounded proof against the public official editor demo pages in normal Chrome.
Use
--fixture all to run every local Chrome browser/editor fixture with one app
build. Add --include-default-real-editor-proof with --fixture all to rerun real
Monaco and ProseMirror in default Chrome AX mode after the forced lane.

--skip-build reuses the already-running AutocompleteLab app and requires that process
to have been launched from this checkout with any proof-mode environment needed
by the smoke pass.
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
    --chrome-accessibility)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      CHROME_ACCESSIBILITY_MODE="$1"
      CHROME_ACCESSIBILITY_MODE_WAS_SET=1
      ;;
    --chrome-accessibility=*)
      CHROME_ACCESSIBILITY_MODE="${1#--chrome-accessibility=}"
      CHROME_ACCESSIBILITY_MODE_WAS_SET=1
      ;;
    --include-default-real-editor-proof)
      CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF=1
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
  notes-title-undo)
    APP="notes"
    NOTES_SESSION_APP="notes-title-undo"
    ;;
  notes-body)
    APP="notes"
    NOTES_SESSION_APP="notes-body"
    ;;
  notes-body-undo)
    APP="notes"
    NOTES_SESSION_APP="notes-body-undo"
    ;;
  notes-checklist)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist"
    ;;
  notes-checklist-undo)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist-undo"
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
  textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|codemirror-official|monaco-official|prosemirror-official|chat-like|all)
    ;;
  *)
    echo "Unknown Chrome fixture: $CHROME_FIXTURE" >&2
    usage >&2
    exit 2
    ;;
esac

case "$CHROME_ACCESSIBILITY_MODE" in
  forced|default)
    ;;
  *)
    echo "Unknown Chrome accessibility mode: $CHROME_ACCESSIBILITY_MODE" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "$APP" != "chrome" && "$CHROME_FIXTURE_WAS_SET" == "1" ]]; then
  echo "--fixture is only supported for the Chrome smoke pass." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" != "chrome" && "$CHROME_ACCESSIBILITY_MODE_WAS_SET" == "1" ]]; then
  echo "--chrome-accessibility is only supported for the Chrome smoke pass." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" != "chrome" && "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" ]]; then
  echo "--include-default-real-editor-proof is only supported for the Chrome smoke pass." >&2
  usage >&2
  exit 2
fi

if [[ "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" && "$CHROME_FIXTURE" != "all" ]]; then
  echo "--include-default-real-editor-proof requires --fixture all." >&2
  usage >&2
  exit 2
fi

if [[ "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" && "$CHROME_ACCESSIBILITY_MODE" != "forced" ]]; then
  echo "--include-default-real-editor-proof starts from the forced Chrome accessibility lane." >&2
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
SMOKE_LOCK_DIR="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-real-app-smoke.lock}"
SMOKE_LOCK_HELD=0

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

  if [[ "$SMOKE_LOCK_HELD" == "1" ]]; then
    rm -rf "$SMOKE_LOCK_DIR" >/dev/null 2>&1 || true
    SMOKE_LOCK_HELD=0
  fi

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$TEMP_ENABLE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_MODE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_MODE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_MODE_ENV_KEY" "$PROOF_MODE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_MODE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi
}

trap cleanup_smoke EXIT

acquire_smoke_lock() {
  if mkdir "$SMOKE_LOCK_DIR" >/dev/null 2>&1; then
    SMOKE_LOCK_HELD=1
    echo "$$" >"$SMOKE_LOCK_DIR/pid"
    return 0
  fi

  local existing_pid=""
  if [[ -f "$SMOKE_LOCK_DIR/pid" ]]; then
    existing_pid="$(cat "$SMOKE_LOCK_DIR/pid" 2>/dev/null || true)"
  fi

  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
    echo "Another real app smoke run is already active (pid $existing_pid)." >&2
    echo "Refusing to run concurrently because smoke runs can type into frontmost apps." >&2
    exit 1
  fi

  rm -rf "$SMOKE_LOCK_DIR" >/dev/null 2>&1 || true
  if mkdir "$SMOKE_LOCK_DIR" >/dev/null 2>&1; then
    SMOKE_LOCK_HELD=1
    echo "$$" >"$SMOKE_LOCK_DIR/pid"
    return 0
  fi

  echo "Could not acquire real app smoke lock: $SMOKE_LOCK_DIR" >&2
  exit 1
}

other_smoke_process_lines() {
  local process_list current_pgid
  current_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ' || true)"
  if [[ -n "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST:-}" ]]; then
    process_list="$AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST"
  else
    process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"
  fi

  awk -v self="$$" -v selfPGID="$current_pgid" '
    {
      pid = $1
      pgid = $3
      command = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
    }
    pid != self &&
      (selfPGID == "" || pgid != selfPGID) &&
      command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?bash|\/usr\/bin\/env[[:space:]]+bash)[[:space:]]+(\.\/)?script\/real_app_smoke\.sh([[:space:]]|$)/ {
        print
      }
  ' <<<"$process_list"
}

refuse_other_smoke_processes() {
  local processes
  processes="$(other_smoke_process_lines || true)"
  if [[ -z "$processes" ]]; then
    return 0
  fi

  echo "Another real app smoke process is already active." >&2
  echo "Refusing to run concurrently because smoke runs can type into frontmost apps." >&2
  echo "$processes" >&2
  exit 1
}

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

wait_for_background_process() {
  local pid="$1"
  local timeout_seconds="$2"
  local label="$3"
  local deadline=$((SECONDS + timeout_seconds))

  while kill -0 "$pid" >/dev/null 2>&1; do
    if ((SECONDS > deadline)); then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 0.2
      kill -9 "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
      echo "Timed out waiting for $label." >&2
      return 124
    fi
    sleep 0.1
  done

  if wait "$pid"; then
    return 0
  fi

  return $?
}

activate_process_id() {
  local target_pid="$1"

  swift - "$target_pid" <<'SWIFT' >/dev/null
import AppKit

guard CommandLine.arguments.count == 2,
      let rawPID = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid_t(rawPID)) else {
    exit(1)
}

app.activate(options: [.activateAllWindows])
SWIFT
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
  local label="${3:-process}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local frontmost_pid
    frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
    if [[ "$frontmost_pid" == "$expected_pid" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for $label $expected_pid to become frontmost." >&2
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
  if [[ "$PROOF_MODE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_MODE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_MODE_ENV_KEY" 2>/dev/null || true)"
    PROOF_MODE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS="$bundle_ids"
  export AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS="$bundle_ids"
  launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_MODE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  echo "Temporary app enablement for smoke: $bundle_ids"
  echo "Temporary proof mode for smoke: $bundle_ids"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so temporary enablement/proof mode only applies if the app was launched with this environment." >&2
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
    notes-title|notes-body|notes-checklist|notes-title-undo|notes-body-undo|notes-checklist-undo)
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
Optional undo proof:
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-undo --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-undo --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-undo --manual-gate
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

chrome_fixture_is_official_demo() {
  case "$1" in
    codemirror-official|monaco-official|prosemirror-official)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_fixture_url() {
  local fixture="$1"
  local local_html_file="$2"

  case "$fixture" in
    codemirror-official)
      printf '%s\n' "https://codemirror.net/try/"
      ;;
    monaco-official)
      printf '%s\n' "https://microsoft.github.io/monaco-editor/playground.html"
      ;;
    prosemirror-official)
      printf '%s\n' "https://prosemirror.net/examples/basic/"
      ;;
    *)
      file_url "$local_html_file"
      ;;
  esac
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

  if chrome_fixture_is_official_demo "$fixture"; then
    require_chrome_javascript_from_apple_events "$fixture"
    while ((SECONDS <= deadline)); do
      local ready
      ready="$(chrome_official_demo_ready "$fixture" | tr -d '[:space:]')"
      if [[ "$ready" == "true" ]]; then
        return 0
      fi
      sleep 0.3
    done

    echo "Timed out waiting for Chrome $fixture official demo readiness." >&2
    exit 1
  fi

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

chrome_active_tab_javascript() {
  local javascript="$1"

  osascript - "$javascript" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  set scriptText to item 1 of argv
  tell application "Google Chrome"
    try
      tell active tab of front window to execute javascript scriptText
    on error
      return ""
    end try
  end tell
end run
APPLESCRIPT
}

require_chrome_javascript_from_apple_events() {
  local fixture="$1"
  local result

  result="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Google Chrome"
  try
    return execute active tab of front window javascript "String(1 + 1)"
  on error errMsg
    return "error: " & errMsg
  end try
end tell
APPLESCRIPT
)"

  if [[ "$result" == "2" ]]; then
    return 0
  fi

  echo "Chrome $fixture official-demo proof requires JavaScript from Apple Events." >&2
  echo "In Chrome, enable View > Developer > Allow JavaScript from Apple Events, then rerun this smoke lane." >&2
  echo "Failing closed before typing because the script cannot focus or verify the official demo editor without that permission." >&2
  exit 1
}

chrome_official_demo_ready() {
  local fixture="$1"
  local javascript

  case "$fixture" in
    codemirror-official)
      javascript="Boolean(document.querySelector('.cm-content'))"
      ;;
    monaco-official)
      javascript="Boolean(document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea'))"
      ;;
    prosemirror-official)
      javascript="Boolean(document.querySelector('.ProseMirror'))"
      ;;
    *)
      printf 'true\n'
      return 0
      ;;
  esac

  chrome_active_tab_javascript "$javascript"
}

chrome_focus_official_demo_editor() {
  local fixture="$1"
  local javascript

  case "$fixture" in
    codemirror-official)
      javascript="(() => { const editor = document.querySelector('.cm-content'); if (!editor) return 'missing'; editor.scrollIntoView({block: 'center', inline: 'center'}); editor.focus(); const selection = window.getSelection(); const range = document.createRange(); range.selectNodeContents(editor); range.collapse(false); selection.removeAllRanges(); selection.addRange(range); return 'ok'; })()"
      ;;
    monaco-official)
      javascript="(() => { const input = document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea'); const editor = document.querySelector('.monaco-editor'); if (!input || !editor) return 'missing'; editor.scrollIntoView({block: 'center', inline: 'center'}); input.focus(); return 'ok'; })()"
      ;;
    prosemirror-official)
      javascript="(() => { const editor = document.querySelector('.ProseMirror'); if (!editor) return 'missing'; editor.scrollIntoView({block: 'center', inline: 'center'}); editor.focus(); const selection = window.getSelection(); const range = document.createRange(); range.selectNodeContents(editor); range.collapse(false); selection.removeAllRanges(); selection.addRange(range); return 'ok'; })()"
      ;;
    *)
      return 0
      ;;
  esac

  local result
  result="$(chrome_active_tab_javascript "$javascript" | tr -d '[:space:]')"
  if [[ "$result" != "ok" ]]; then
    echo "Could not focus Chrome $fixture official demo editor; JavaScript result: ${result:-empty}" >&2
    exit 1
  fi
}

chrome_fixture_uses_isolated_accessibility_chrome() {
  if [[ "$CHROME_ACCESSIBILITY_MODE" != "forced" ]]; then
    return 1
  fi

  if chrome_fixture_is_official_demo "$1"; then
    return 1
  fi

  return 0
}

chrome_fixture_uses_default_browser_accessibility() {
  if [[ "$CHROME_ACCESSIBILITY_MODE" != "default" ]]; then
    return 1
  fi

  if chrome_fixture_is_official_demo "$1"; then
    return 1
  fi

  return 0
}

chrome_default_accessibility_exposes_web_content() {
  osascript -l JavaScript <<'JXA' 2>/dev/null
const se = Application('System Events');
const chrome = se.processes.byName('Google Chrome');

function safe(fn) {
  try {
    return fn();
  } catch (error) {
    return '';
  }
}

function hasWebContent(element, depth) {
  if (depth > 12) return false;
  const role = safe(() => element.role());
  if (role === 'AXWebArea' || role === 'AXTextArea') {
    return true;
  }

  let children = [];
  try {
    children = element.uiElements();
  } catch (error) {}

  for (const child of children) {
    if (hasWebContent(child, depth + 1)) return true;
  }
  return false;
}

let exposed = false;
try {
  chrome.frontmost = true;
  delay(0.2);
  const windows = chrome.windows();
  for (const window of windows) {
    if (hasWebContent(window, 0)) {
      exposed = true;
      break;
    }
  }
} catch (error) {}

exposed ? 'true' : 'false';
JXA
}

require_default_chrome_web_accessibility() {
  local fixture="$1"

  if ! chrome_fixture_uses_default_browser_accessibility "$fixture"; then
    return 0
  fi

  local exposed
  exposed="$(chrome_default_accessibility_exposes_web_content | tr -d '[:space:]')"
  if [[ "$exposed" == "true" ]]; then
    return 0
  fi

  echo "Default Chrome did not expose page editor content through macOS Accessibility." >&2
  echo "The active window is ready, but the AX tree contains only browser chrome, not AXWebArea/AXTextArea content." >&2
  echo "Use --chrome-accessibility forced for the isolated proof lane, or enable Chrome renderer accessibility before claiming default-Chrome browser proof." >&2
  exit 1
}

chrome_smoke_proof_label() {
  local fixture="$1"

  if [[ "$CHROME_ACCESSIBILITY_MODE" == "default" ]] && ! chrome_fixture_is_official_demo "$fixture"; then
    printf '%s-default\n' "$fixture"
    return 0
  fi

  printf '%s\n' "$fixture"
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
    codemirror-official)
      printf '260 430\n'
      ;;
    monaco-official)
      printf '560 430\n'
      ;;
    prosemirror-like)
      printf '180 260\n'
      ;;
    prosemirror-real)
      printf '180 260\n'
      ;;
    chat-like)
      printf '420 260\n'
      ;;
    prosemirror-official)
      printf '220 500\n'
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

  if chrome_fixture_is_official_demo "$fixture"; then
    osascript >/dev/null <<'APPLESCRIPT'
tell application "Google Chrome"
  activate
end tell
delay 0.1
APPLESCRIPT
    chrome_focus_official_demo_editor "$fixture"
    wait_for_frontmost_app "Google Chrome" 5
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

raise_textedit_smoke_window() {
  local window_title="$1"

  swift - "$window_title" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where (copyAttribute(window, kAXTitleAttribute) as? String) == targetTitle {
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        print(app.processIdentifier)
        exit(0)
    }
}

exit(1)
SWIFT
}

click_textedit_smoke_window() {
  local window_title="$1"

  swift - "$window_title" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]

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

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func firstTextInput(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth <= 8 else {
        return nil
    }

    let role = copyAttribute(element, kAXRoleAttribute) as? String
    if role == kAXTextAreaRole as String || role == kAXTextFieldRole as String {
        return element
    }

    for child in children(of: element) {
        if let found = firstTextInput(in: child, depth: depth + 1) {
            return found
        }
    }

    return nil
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where (copyAttribute(window, kAXTitleAttribute) as? String) == targetTitle {
        let textInput = firstTextInput(in: window)
        if let textInput {
            AXUIElementSetAttributeValue(textInput, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }

        guard let targetBounds = bounds(for: textInput ?? window),
              let source = CGEventSource(stateID: .hidSystemState) else {
            exit(1)
        }
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        Thread.sleep(forTimeInterval: 0.2)

        let point = CGPoint(x: targetBounds.midX, y: targetBounds.midY)
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
        print(app.processIdentifier)
        exit(0)
    }
}

exit(1)
SWIFT
}

focus_textedit_smoke_editor() {
  local window_title="${1:-}"

  if [[ -n "$window_title" ]]; then
    local target_pid
    target_pid="$(raise_textedit_smoke_window "$window_title" | tr -d '\r\n')"
    if [[ -z "$target_pid" ]]; then
      echo "Could not resolve TextEdit smoke window pid for '$window_title'." >&2
      return 1
    fi
    activate_process_id "$target_pid"
    wait_for_frontmost_process_id "$target_pid" 5 "TextEdit process"
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
    local target_pid
    target_pid="$(click_textedit_smoke_window "$window_title" | tr -d '\r\n')"
    if [[ -z "$target_pid" ]]; then
      echo "Could not resolve TextEdit smoke window pid for '$window_title'." >&2
      return 1
    fi
    activate_process_id "$target_pid"
    wait_for_frontmost_process_id "$target_pid" 5 "TextEdit process"
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

textedit_document_text() {
  local window_title="$1"

  swift - "$window_title" <<'SWIFT' 2>/dev/null || true
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func textValue(in element: AXUIElement, depth: Int = 0) -> String? {
    guard depth <= 8 else {
        return nil
    }

    let role = copyAttribute(element, kAXRoleAttribute) as? String
    if role == kAXTextAreaRole as String || role == kAXTextFieldRole as String {
        if let value = copyAttribute(element, kAXValueAttribute) as? String {
            return value
        }
    }

    for child in children(of: element) {
        if let value = textValue(in: child, depth: depth + 1) {
            return value
        }
    }

    return nil
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows {
        guard (copyAttribute(window, kAXTitleAttribute) as? String) == targetTitle else {
            continue
        }

        print(textValue(in: window) ?? "")
        exit(0)
    }
}

print("")
SWIFT
}

textedit_document_exists() {
  local window_title="$1"

  swift - "$window_title" <<'SWIFT' 2>/dev/null || true
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where (copyAttribute(window, kAXTitleAttribute) as? String) == targetTitle {
        print("1")
        exit(0)
    }
}

print("0")
SWIFT
}

wait_for_textedit_document_open() {
  local window_title="$1"
  local timeout_seconds="${2:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if [[ "$(textedit_document_exists "$window_title")" == "1" ]]; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

open_textedit_smoke_document() {
  local file_path="$1"
  local window_title="$2"

  open -F -n -a TextEdit "$file_path"
  if wait_for_textedit_document_open "$window_title" 8; then
    return 0
  fi

  osascript - "$file_path" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    activate
    open (POSIX file targetPath)
  end tell
end run
APPLESCRIPT

  if wait_for_textedit_document_open "$window_title" 6; then
    return 0
  fi

  open -a TextEdit "$file_path"
  if wait_for_textedit_document_open "$window_title" 8; then
    return 0
  fi

  echo "Timed out waiting for TextEdit to open disposable document '$window_title'." >&2
  return 1
}

textedit_document_contains_fragment() {
  local window_title="$1"
  local fragment="$2"

  textedit_document_text "$window_title" | grep -F "$fragment" >/dev/null
}

wait_for_textedit_document_fragment() {
  local window_title="$1"
  local fragment="$2"
  local label="$3"
  local timeout_seconds="${4:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if textedit_document_contains_fragment "$window_title" "$fragment"; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for TextEdit document text for $label." >&2
  echo "Window: $window_title" >&2
  echo "Expected fragment: $fragment" >&2
  return 1
}

insert_textedit_smoke_fragment() {
  local window_title="$1"
  local fragment="$2"

  swift - "$window_title" "$fragment" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]
let fragment = CommandLine.arguments[2]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func firstTextInput(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth <= 8 else {
        return nil
    }

    let role = copyAttribute(element, kAXRoleAttribute) as? String
    if role == kAXTextAreaRole as String || role == kAXTextFieldRole as String {
        return element
    }

    for child in children(of: element) {
        if let found = firstTextInput(in: child, depth: depth + 1) {
            return found
        }
    }

    return nil
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where (copyAttribute(window, kAXTitleAttribute) as? String) == targetTitle {
        guard let textInput = firstTextInput(in: window) else {
            exit(1)
        }
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(textInput, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        let currentValue = copyAttribute(textInput, kAXValueAttribute) as? String ?? ""
        var range = CFRange(location: currentValue.utf16.count, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            exit(1)
        }
        AXUIElementSetAttributeValue(textInput, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        let result = AXUIElementSetAttributeValue(textInput, kAXSelectedTextAttribute as CFString, fragment as CFString)
        exit(result == .success ? 0 : 1)
    }
}

exit(1)
SWIFT
}

type_textedit_smoke_fragment() {
  local window_title="$1"
  local fragment="$2"

  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  if insert_textedit_smoke_fragment "$window_title" "$fragment"; then
    return 0
  fi

  osascript - "$fragment" <<'APPLESCRIPT'
on run argv
  set smokeText to item 1 of argv
  tell application "System Events"
    keystroke smokeText
    key code 53
  end tell
end run
APPLESCRIPT
}

type_textedit_smoke_fragment_and_confirm() {
  local window_title="$1"
  local fragment="$2"
  local label="$3"

  type_textedit_smoke_fragment "$window_title" "$fragment"
  if wait_for_textedit_document_fragment "$window_title" "$fragment" "$label" 5; then
    return 0
  fi

  echo "TextEdit did not receive the $label fragment; refocusing and retrying once." >&2
  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "a" using command down
  key code 51
  key code 53
end tell
delay 0.2
APPLESCRIPT
  type_textedit_smoke_fragment "$window_title" "$fragment"
  wait_for_textedit_document_fragment "$window_title" "$fragment" "$label retry" 5
}

wait_for_textedit_smoke_editor() {
  local window_title="$1"
  local timeout_seconds="${2:-45}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if focus_textedit_smoke_editor "$window_title" 2>/dev/null; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for TextEdit smoke window '$window_title'." >&2
  exit 1
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

chrome_active_tab_url() {
  osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "Google Chrome"
  try
    return URL of active tab of front window
  on error
    return ""
  end try
end tell
APPLESCRIPT
}

assert_chrome_expected_tab() {
  local fixture="$1"
  local expected_url="$2"
  local label="$3"
  local active_url

  active_url="$(chrome_active_tab_url)"
  if [[ -z "$active_url" ]]; then
    echo "Chrome $fixture smoke refused to type during $label: no active Chrome tab URL." >&2
    exit 1
  fi

  if chrome_fixture_is_official_demo "$fixture"; then
    if [[ "$active_url" != "$expected_url"* ]]; then
      echo "Chrome $fixture smoke refused to type during $label: expected official demo URL '$expected_url', got '$active_url'." >&2
      exit 1
    fi
    return 0
  fi

  if [[ "$expected_url" == file://* && "$active_url" != file://*autocomplete-lab-chrome-"$fixture"-smoke.html* ]]; then
    echo "Chrome $fixture smoke refused to type during $label: expected local smoke fixture, got '$active_url'." >&2
    exit 1
  fi
}

assert_chrome_focused_editable_ax() {
  local fixture="$1"
  local chrome_pid="$2"
  local label="$3"

  swift - "$fixture" "${chrome_pid:-0}" "$label" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 4,
      let rawPID = Int32(CommandLine.arguments[2]) else {
    exit(2)
}

let fixture = CommandLine.arguments[1]
let label = CommandLine.arguments[3]
let pid: pid_t
if rawPID > 0 {
    pid = pid_t(rawPID)
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier {
    guard let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" else {
        fputs("Chrome \(fixture) smoke refused to type during \(label): frontmost app is not Google Chrome.\n", stderr)
        exit(1)
    }
    pid = frontmostPID
} else {
    fputs("Chrome \(fixture) smoke refused to type during \(label): no frontmost process.\n", stderr)
    exit(1)
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }

    return value
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    copyAttribute(element, attribute) as? String ?? ""
}

func hasWebAreaAncestor(_ element: AXUIElement) -> Bool {
    var current = element
    for _ in 0..<16 {
        if stringAttribute(current, kAXRoleAttribute) == "AXWebArea" {
            return true
        }

        guard let parentValue = copyAttribute(current, kAXParentAttribute) else {
            return false
        }
        current = parentValue as! AXUIElement
    }

    return false
}

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)

guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Chrome \(fixture) smoke refused to type during \(label): Chrome has no focused AX element.\n", stderr)
    exit(1)
}

let focusedElement = focusedValue as! AXUIElement
let role = stringAttribute(focusedElement, kAXRoleAttribute)
let title = stringAttribute(focusedElement, kAXTitleAttribute)
let description = stringAttribute(focusedElement, kAXDescriptionAttribute)
let identifier = stringAttribute(focusedElement, "AXIdentifier")
let webBacked = hasWebAreaAncestor(focusedElement)

if role == "AXTextArea" {
    exit(0)
}

if role == "AXTextField" && webBacked {
    exit(0)
}

fputs(
    "Chrome \(fixture) smoke refused to type during \(label): focused AX element is not a web editable text target (role=\(role.isEmpty ? "unknown" : role), title=\(title.isEmpty ? "none" : title), description=\(description.isEmpty ? "none" : description), identifier=\(identifier.isEmpty ? "none" : identifier), webBacked=\(webBacked)).\n",
    stderr
)
exit(1)
SWIFT
}

insert_chrome_smoke_text_with_ax() {
  local fixture="$1"
  local chrome_pid="$2"
  local label="$3"
  local text="$4"

  swift - "$fixture" "${chrome_pid:-0}" "$label" "$text" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 5,
      let rawPID = Int32(CommandLine.arguments[2]) else {
    exit(2)
}

let fixture = CommandLine.arguments[1]
let label = CommandLine.arguments[3]
let text = CommandLine.arguments[4]
let pid: pid_t
if rawPID > 0 {
    pid = pid_t(rawPID)
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier {
    guard let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" else {
        fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): frontmost app is not Google Chrome.\n", stderr)
        exit(1)
    }
    pid = frontmostPID
} else {
    fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): no frontmost process.\n", stderr)
    exit(1)
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }

    return value
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    copyAttribute(element, attribute) as? String ?? ""
}

func hasWebAreaAncestor(_ element: AXUIElement) -> Bool {
    var current = element
    for _ in 0..<16 {
        if stringAttribute(current, kAXRoleAttribute) == "AXWebArea" {
            return true
        }

        guard let parentValue = copyAttribute(current, kAXParentAttribute) else {
            return false
        }
        current = parentValue as! AXUIElement
    }

    return false
}

func isEditableWebTarget(_ element: AXUIElement) -> Bool {
    let role = stringAttribute(element, kAXRoleAttribute)
    if role == "AXTextArea" {
        return true
    }

    return role == "AXTextField" && hasWebAreaAncestor(element)
}

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)

guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): Chrome has no focused AX element.\n", stderr)
    exit(1)
}

let focusedElement = focusedValue as! AXUIElement
let role = stringAttribute(focusedElement, kAXRoleAttribute)
guard isEditableWebTarget(focusedElement) else {
    fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): focused AX element is not editable web text (role=\(role.isEmpty ? "unknown" : role)).\n", stderr)
    exit(1)
}

let initialValue = copyAttribute(focusedElement, kAXValueAttribute) as? String ?? ""
guard let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create a CGEvent source.\n", stderr)
    exit(1)
}

if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate(options: [.activateAllWindows])
}

Thread.sleep(forTimeInterval: 0.1)

for codeUnit in text.utf16 {
    var unit = codeUnit
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create text events.\n", stderr)
        exit(1)
    }

    keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
    keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
    keyDown.postToPid(pid)
    keyUp.postToPid(pid)
    usleep(15_000)
}

for _ in 0..<30 {
    let currentValue = copyAttribute(focusedElement, kAXValueAttribute) as? String ?? ""
    if currentValue.contains(text)
        && (currentValue.count >= initialValue.count + text.count || currentValue.count >= text.count) {
        exit(0)
    }
    usleep(100_000)
}

let finalValue = copyAttribute(focusedElement, kAXValueAttribute) as? String ?? ""
fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): targeted text events did not update the focused Chrome editor (beforeChars=\(initialValue.count), afterChars=\(finalValue.count)).\n", stderr)
exit(1)
SWIFT
}

assert_chrome_ready_for_input() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_url="$3"
  local label="$4"

  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture $label"
    assert_chrome_focused_editable_ax "$fixture" "$chrome_pid" "$label"
    return 0
  fi

  assert_frontmost_app "Google Chrome" "Chrome $fixture $label"
  assert_chrome_expected_tab "$fixture" "$expected_url" "$label"
  assert_chrome_focused_editable_ax "$fixture" "" "$label"
}

type_chrome_smoke_text() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_url="$3"
  local label="$4"
  local text="$5"

  assert_chrome_ready_for_input "$fixture" "$chrome_pid" "$expected_url" "$label"
  insert_chrome_smoke_text_with_ax "$fixture" "$chrome_pid" "$label" "$text"
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
  local proof_bundle_ids
  proof_bundle_ids="$(smoke_target_bundle_ids | paste -sd, -)"
  echo "Real app smoke: $APP"
  echo "Diagnostics log: $LOG_PATH"
  echo "Trace log: $TRACE_PATH"
  echo "Proof mode bundle(s): $proof_bundle_ids"
  case "$APP" in
    textedit)
      echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file, type a test fragment, then validate logs and traces."
      echo "Safety: the smoke launch temporarily enables TextEdit only for this proof pass."
      ;;
    chrome)
      echo "Chrome fixture: $CHROME_FIXTURE"
      case "$CHROME_ACCESSIBILITY_MODE" in
        forced)
          echo "Chrome accessibility: isolated Chrome with forced renderer accessibility for local fixtures"
          ;;
        default)
          echo "Chrome accessibility: default Chrome accessibility exposure; experimental proof lane, weaker than isolated forced renderer mode"
          ;;
      esac
      if [[ "$CHROME_FIXTURE" == "all" ]]; then
        echo "Plan: build/relaunch AutocompleteLab, then run disposable Chrome textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and chat-like no-submit local fixtures."
        if [[ "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" ]]; then
          echo "Plan add-on: rerun real Monaco and real ProseMirror in default Chrome AX mode after the forced renderer lane."
        fi
      elif chrome_fixture_is_official_demo "$CHROME_FIXTURE"; then
        echo "Plan: build/relaunch AutocompleteLab, open the public official $CHROME_FIXTURE demo page in Chrome, type a disposable test fragment, then validate logs and traces."
        echo "Requirement: official Chrome demo lanes need Chrome's View > Developer > Allow JavaScript from Apple Events setting so the script can focus and verify the editor."
      else
        echo "Plan: build/relaunch AutocompleteLab, open a disposable Chrome $CHROME_FIXTURE fixture, type a test fragment, then validate logs and traces."
      fi
      echo "Safety: the smoke launch temporarily enables Chrome only for this proof pass."
      echo "Safety: before Chrome typing, the smoke requires Chrome to expose a focused editable web text target through Accessibility."
      echo "Safety: Chrome setup text is sent to the Chrome process and verified through the focused AX editor, not global keystrokes."
      ;;
    notes)
      local notes_app notes_surface
      if notes_app="$(notes_session_app)"; then
        notes_surface="${notes_app#notes-}"
        if [[ "$notes_app" == "notes-body" ]]; then
          echo "Plan: guarded Apple Notes body proof. The script verifies the open note body contains the disposable marker, appends smoke fragments, then validates logs and traces."
        else
          echo "Plan: manual-gated Apple Notes $notes_surface proof. The script validates only that surface after you run it."
        fi
      else
        echo "Plan: choose a manual-gated Apple Notes surface before recording proof."
        print_notes_surface_commands
      fi
      echo "Safety: pass --manual-gate to continue. Use only the disposable autocomplete smoke note with body marker 'Autocomplete smoke'."
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
      echo "Plan: manual-gated terminal-host Claude Code proof. The script validates one-word Tab accept without submit after you run it."
      echo "Safety: pass --manual-gate to continue. Use a supported terminal host, include AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF, and do not press Enter."
      echo "Proof target: terminal-hosted Claude Code must validate one-word Tab accept without submitting shell input or an agent prompt."
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

  ./script/build_and_run.sh run
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

type_notes_body_smoke_fragment() {
  local fragment="$1"

  AUTOCOMPLETE_LAB_NOTES_SMOKE_FRAGMENT="$fragment" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_SMOKE_MARKER"] ?? "Autocomplete smoke"
let fragment = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_SMOKE_FRAGMENT"] ?? ""

guard !fragment.isEmpty else {
    fputs("Notes smoke fragment is empty.\n", stderr)
    exit(2)
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func children(of element: AXUIElement) -> [AXUIElement] {
    var result: [AXUIElement] = []
    for attribute in [kAXChildrenAttribute, kAXContentsAttribute] {
        if let values = copyAttribute(element, attribute) as? [AXUIElement] {
            result.append(contentsOf: values)
        }
    }
    return result
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

func noteBody(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth <= 10 else {
        return nil
    }

    let role = copyAttribute(element, kAXRoleAttribute) as? String
    let description = copyAttribute(element, kAXDescriptionAttribute) as? String
    let value = copyAttribute(element, kAXValueAttribute) as? String
    if role == kAXTextAreaRole as String,
       (description == "Note Body Text View" || value?.localizedCaseInsensitiveContains(marker) == true) {
        return element
    }

    for child in children(of: element) {
        if let found = noteBody(in: child, depth: depth + 1) {
            return found
        }
    }

    return nil
}

func postClick(at point: CGPoint, source: CGEventSource) {
    for eventType in [CGEventType.leftMouseDown, .leftMouseUp] {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: eventType,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            continue
        }
        event.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.03)
    }
}

func postText(_ text: String, source: CGEventSource) {
    for scalar in text.unicodeScalars {
        guard scalar.value <= UInt16.max else {
            continue
        }
        var chars = [UniChar(scalar.value)]
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            exit(1)
        }
        keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.025)
    }
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Notes" }) else {
    fputs("Apple Notes is not running. Open the disposable Autocomplete smoke note first.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []

guard let body = windows.lazy.compactMap({ noteBody(in: $0) }).first ?? noteBody(in: appElement) else {
    fputs("Could not find a Notes body text view. Open the disposable Autocomplete smoke note and put focus in the note body.\n", stderr)
    exit(3)
}

let bodyText = copyAttribute(body, kAXValueAttribute) as? String ?? ""
guard bodyText.localizedCaseInsensitiveContains(marker) else {
    fputs("Refusing to type in Notes because the focused/open note body does not contain the marker '\(marker)'.\n", stderr)
    fputs("Open a disposable note whose body contains that marker, then rerun the Notes smoke.\n", stderr)
    exit(3)
}

guard let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("Could not create a CGEvent source for Notes smoke typing.\n", stderr)
    exit(1)
}

app.activate(options: [.activateAllWindows])
if let window = windows.first {
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
}
Thread.sleep(forTimeInterval: 0.25)
AXUIElementSetAttributeValue(body, kAXFocusedAttribute as CFString, kCFBooleanTrue)

if let rect = bounds(for: body) {
    postClick(at: CGPoint(x: rect.midX, y: min(rect.maxY - 24, rect.midY)), source: source)
    Thread.sleep(forTimeInterval: 0.12)
}

var endRange = CFRange(location: bodyText.utf16.count, length: 0)
guard let rangeValue = AXValueCreate(.cfRange, &endRange) else {
    fputs("Could not create a selected-range value for Notes smoke typing.\n", stderr)
    exit(1)
}
AXUIElementSetAttributeValue(body, kAXSelectedTextRangeAttribute as CFString, rangeValue)
Thread.sleep(forTimeInterval: 0.12)
postText(fragment, source: source)
print("typed Notes body smoke fragment")
SWIFT
}

ensure_notes_body_smoke_note() {
  local smoke_title="${AUTOCOMPLETE_LAB_NOTES_SMOKE_TITLE:-Autocomplete Lab Smoke}"
  local smoke_marker="${AUTOCOMPLETE_LAB_NOTES_SMOKE_MARKER:-Autocomplete smoke}"

  open -a Notes
  wait_for_frontmost_app "Notes" 8
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "n" using command down
end tell
delay 0.4
APPLESCRIPT
  type_notes_raw_smoke_text "$smoke_title"$'\n'"$smoke_marker"
  sleep 0.8
}

type_notes_raw_smoke_text() {
  local text="$1"

  AUTOCOMPLETE_LAB_NOTES_RAW_TEXT="$text" swift - <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let text = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_RAW_TEXT"] ?? ""

guard NSWorkspace.shared.frontmostApplication?.localizedName == "Notes" else {
    fputs("Notes is not frontmost for smoke-note setup.\n", stderr)
    exit(1)
}

guard let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("Could not create a CGEvent source for Notes smoke-note setup.\n", stderr)
    exit(1)
}

for scalar in text.unicodeScalars {
    guard scalar.value <= UInt16.max else {
        continue
    }
    var chars = [UniChar(scalar.value)]
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        exit(1)
    }
    keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
    keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.025)
}
SWIFT
}

run_notes() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local manual_app
  if ! manual_app="$(notes_session_app)"; then
    echo "Notes real smoke cannot record a generic Notes proof." >&2
    print_notes_surface_commands >&2
    exit 2
  fi

  if [[ "$manual_app" != "notes-body" ]]; then
    run_manual_gated
    return 0
  fi

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "Notes runtime readiness" 60 "$SKIP_BUILD"
  ensure_notes_body_smoke_note

  full_accept_key="$(accept_all_shortcut)"
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  type_notes_body_smoke_fragment $'\nSmoke proof feels inst'
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes body suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes body"
  assert_frontmost_app "Notes" "Notes body"
  press_key_code 48
  wait_for_log_fields "$start_line" "Notes body Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.Notes" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes body first verified insertion"

  second_start_line="$(line_count "$LOG_PATH")"
  type_notes_body_smoke_fragment " and stays inst"
  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes body second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes body second"
  assert_frontmost_app "Notes" "Notes body"
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "Notes body full acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.Notes" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"

  sleep 1
  local manual_check_args=(notes-body --check)
  if screenshot_trace_requested; then
    manual_check_args+=(--visual)
  fi
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh "${manual_check_args[@]}"
}

run_claude_code_blocked() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  run_manual_gated
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
  open_textedit_smoke_document "$textedit_file" "$textedit_window_title"
  sleep 0.8

  wait_for_textedit_smoke_editor "$textedit_window_title"
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

  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" "Smoke proof feels inst" "first typed"

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
  local undo_start_line
  undo_start_line="$(line_count "$LOG_PATH")"
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "z" using command down
end tell
APPLESCRIPT
  wait_for_log_fields "$undo_start_line" "TextEdit undo keyboard action" 8 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "action=undoAcceptedInsertion" \
    "handled=true"
  wait_for_log_fields "$undo_start_line" "TextEdit accepted insertion undo" 8 \
    "accepted-insertion-undone" \
    "app=com.apple.TextEdit"
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"
  second_start_line="$(line_count "$LOG_PATH")"

  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" " and stays inst" "second typed"

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
  if ! chrome_fixture_is_official_demo "$fixture"; then
    chrome_fixture_html "$fixture" >"$html_file"
  fi

  local chrome_url
  chrome_url="$(chrome_fixture_url "$fixture" "$html_file")"
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
  require_default_chrome_web_accessibility "$fixture"

  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "first fragment" "Smoke proof feels inst"

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

  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture"
  fi
  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "second fragment" " and stays inst"

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
  local proof_label
  proof_label="$(chrome_smoke_proof_label "$fixture")"
  AUTOCOMPLETE_LAB_CHROME_FIXTURE="$fixture" \
  AUTOCOMPLETE_LAB_CHROME_ACCESSIBILITY_MODE="$CHROME_ACCESSIBILITY_MODE" \
  AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$proof_label" \
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
    if [[ "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" ]]; then
      local original_chrome_accessibility_mode="$CHROME_ACCESSIBILITY_MODE"
      CHROME_ACCESSIBILITY_MODE="default"
      run_chrome_fixture monaco-real
      run_chrome_fixture prosemirror-real
      CHROME_ACCESSIBILITY_MODE="$original_chrome_accessibility_mode"
    fi
  else
    run_chrome_fixture "$CHROME_FIXTURE"
  fi
}

describe_plan

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

refuse_other_smoke_processes
acquire_smoke_lock

case "$APP" in
  textedit)
    run_textedit
    ;;
  chrome)
    run_chrome
    ;;
  notes)
    run_notes
    ;;
  obsidian|codex|claude-code|claude)
    run_manual_gated
    ;;
esac
