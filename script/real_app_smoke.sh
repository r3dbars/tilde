#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="${1:-}"
REQUESTED_APP="$APP"
NOTES_SESSION_APP=""
OBSIDIAN_SESSION_APP=""
CLAUDE_SESSION_APP=""
TEXTEDIT_VARIANT=""
DRY_RUN=0
MANUAL_GATE=0
SKIP_BUILD="${AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD:-0}"
CHROME_FIXTURE="${AUTOCOMPLETE_LAB_CHROME_FIXTURE:-textarea}"
CHROME_FIXTURE_WAS_SET=0
CHROME_ACCESSIBILITY_MODE="${AUTOCOMPLETE_LAB_CHROME_ACCESSIBILITY_MODE:-forced}"
CHROME_ACCESSIBILITY_MODE_WAS_SET=0
CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF=0
CHROME_REMOTE_DEBUGGING_PORT=""
NATIVE_UNDO_PROOF="${AUTOCOMPLETE_LAB_NATIVE_UNDO_PROOF:-0}"
CLAUDE_CODE_HOST_VARIANT="${AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT:-auto}"
CLAUDE_CODE_HOST_WAS_SET=0
TEMP_ENABLE_ENV_KEY="AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=0
TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""
PROOF_MODE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
PROOF_MODE_LAUNCHCTL_WAS_PREPARED=0
PROOF_MODE_LAUNCHCTL_PREVIOUS=""
UNDO_RECOVERY_ENV_KEY="AUTOCOMPLETE_LAB_ACCEPTED_INSERTION_UNDO_RECOVERY"
UNDO_RECOVERY_LAUNCHCTL_WAS_PREPARED=0
UNDO_RECOVERY_LAUNCHCTL_PREVIOUS=""
TEXTEDIT_APPEARANCE_WAS_SET=0
TEXTEDIT_PREVIOUS_DARK_MODE=""

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|textedit-light|textedit-dark|textedit-long-wrap|textedit-wrapped|textedit-narrow|textedit-selected-suppression|textedit-undo-one-word|textedit-undo-full|textedit-fast-typing|chrome|notes-title|notes-body|notes-checklist|notes-title-undo|notes-body-undo|notes-checklist-undo|notes|obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|codex|claude-code|claude-code-terminal|claude-code-iterm2|claude-code-warp|claude-code-ghostty|claude-code-kitty|claude-code-alacritty|claude-code-wezterm|claude|claude-empty|claude-long|claude-wrapped|claude-narrow|claude-context|claude-light|claude-dark> [--dry-run] [--manual-gate] [--skip-build] [--native-undo-proof] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|all>] [--chrome-accessibility <forced|default>] [--include-default-real-editor-proof] [--host <terminal|iterm2|warp|ghostty|kitty|alacritty|wezterm|auto>]

Runs a real app smoke pass where it is safe to automate. Notes title/body/
checklist proof has guarded disposable-note drivers; Obsidian, Codex,
Claude Code, and Claude desktop are manual-gated so this script never types
into private notes, vaults, terminal prompts, or agent prompts by surprise.
The Codex lane uses a targeted disposable proof helper after the manual gate:
it seeds AUTOCOMPLETE_LAB_CODEX_PROOF text into a safe composer, presses Tab
once, and never presses Enter.

Notes proof must use notes-title, notes-body, notes-checklist, or their
notes-*-undo variants. A generic notes run only prints the surface picker and
does not record proof.

TextEdit proof can use textedit-light, textedit-dark, textedit-long-wrap,
textedit-narrow, textedit-selected-suppression, textedit-undo-one-word,
textedit-undo-full, or textedit-fast-typing. These are still narrow TextEdit
lanes, not a generic native-app claim. The TextEdit undo lanes automatically
use native single-edit Command-Z proof.

Obsidian proof must keep obsidian, obsidian-theme, obsidian-pane, and
obsidian-long-note as separate manual-gated lanes before it can be complete.

Claude desktop proof can use claude-empty, claude-long, claude-wrapped,
claude-narrow, claude-context, claude-light, or claude-dark to record bounded
one-word no-submit layout variants. Full accept stays disabled until a separate
safe no-submit proof lane exists.

Chrome defaults to the textarea fixture in an isolated Chrome process with
renderer accessibility forced. Use --fixture chat-like to prove Tab/full-accept
do not submit a chat-style composer. Use --fixture monaco-real or
--fixture prosemirror-real for pinned upstream editor-engine fixtures. Use
--chrome-accessibility default to run local fixtures in the normal frontmost
Chrome window as an experimental default-AX exposure proof. Use
--fixture codemirror-official, monaco-official, or prosemirror-official to run
bounded proof against the public official editor demo pages in normal Chrome.
Use --fixture textarea-public, contenteditable-public, or production-text-fields
to run bounded proof against top-level public demo pages with disposable text.
Use --fixture browser-chat-harness, or script/real_browser_chat_proof.sh, for a
bounded HTTP browser-chat no-submit proof harness. That harness proves only the
disposable harness surface, not Slack, Discord, ChatGPT, or broad chat support.
Use
--fixture all to run every local Chrome browser/editor fixture with one app
build. Add --include-default-real-editor-proof with --fixture all to rerun real
Monaco and ProseMirror in default Chrome AX mode after the forced lane.

Claude Code is proof-only through supported terminal hosts. Use --host or the
claude-code-<host> aliases to record host-specific proof labels without enabling
normal terminal suggestions.

--skip-build reuses the already-running AutocompleteLab app and requires that process
to have been launched from this checkout with any proof-mode environment needed
by the smoke pass.

--native-undo-proof relaunches AutocompleteLab with app rollback disabled,
passes Command-Z through to the target app, and records native single-edit undo
proof only after the target text returns to its pre-accept value.
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
    --native-undo-proof)
      NATIVE_UNDO_PROOF=1
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
    --host)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      CLAUDE_CODE_HOST_VARIANT="$1"
      CLAUDE_CODE_HOST_WAS_SET=1
      ;;
    --host=*)
      CLAUDE_CODE_HOST_VARIANT="${1#--host=}"
      CLAUDE_CODE_HOST_WAS_SET=1
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
  textedit-light)
    APP="textedit"
    TEXTEDIT_VARIANT="light"
    ;;
  textedit-dark)
    APP="textedit"
    TEXTEDIT_VARIANT="dark"
    ;;
  textedit-long-wrap | textedit-wrapped)
    APP="textedit"
    TEXTEDIT_VARIANT="long-wrap"
    ;;
  textedit-narrow)
    APP="textedit"
    TEXTEDIT_VARIANT="narrow"
    ;;
  textedit-selected-suppression)
    APP="textedit"
    TEXTEDIT_VARIANT="selected-suppression"
    ;;
  textedit-undo-one-word)
    APP="textedit"
    TEXTEDIT_VARIANT="undo-one-word"
    NATIVE_UNDO_PROOF=1
    ;;
  textedit-undo-full)
    APP="textedit"
    TEXTEDIT_VARIANT="undo-full"
    NATIVE_UNDO_PROOF=1
    ;;
  textedit-fast-typing)
    APP="textedit"
    TEXTEDIT_VARIANT="fast-typing"
    ;;
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
  obsidian-theme)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-theme"
    ;;
  obsidian-pane)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-pane"
    ;;
  obsidian-long-note)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-long-note"
    ;;
  claude-code-terminal)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="terminal"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-iterm2)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="iterm2"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-warp)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="warp"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-ghostty)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="ghostty"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-kitty)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="kitty"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-alacritty)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="alacritty"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-code-wezterm)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="wezterm"
    CLAUDE_CODE_HOST_WAS_SET=1
    ;;
  claude-empty|claude-long|claude-wrapped|claude-narrow|claude-context|claude-light|claude-dark)
    CLAUDE_SESSION_APP="$APP"
    APP="claude"
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
  textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|all)
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

case "$CLAUDE_CODE_HOST_VARIANT" in
  auto|terminal|iterm2|warp|ghostty|kitty|alacritty|wezterm)
    ;;
  *)
    echo "Unknown Claude Code terminal host: $CLAUDE_CODE_HOST_VARIANT" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "$APP" != "claude-code" && "$CLAUDE_CODE_HOST_WAS_SET" == "1" ]]; then
  echo "--host is only supported for the Claude Code smoke pass." >&2
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

if [[ "$NATIVE_UNDO_PROOF" =~ ^(1|true|yes|on)$ && "$SKIP_BUILD" == "1" ]]; then
  echo "--native-undo-proof cannot be combined with --skip-build because the app must relaunch with app rollback disabled." >&2
  usage >&2
  exit 2
fi

if [[ "$NATIVE_UNDO_PROOF" =~ ^(1|true|yes|on)$ && "$APP" != "textedit" && "$APP" != "chrome" ]]; then
  echo "--native-undo-proof is currently automated only for TextEdit and Chrome." >&2
  usage >&2
  exit 2
fi

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.autocomplete-lab}"
declare -a SMOKE_TMP_DIRS=()
declare -a SMOKE_CHROME_PIDS=()
declare -a SMOKE_HTTP_PIDS=()
declare -a SMOKE_TEXTEDIT_WINDOW_TITLES=()
CHROME_FIXTURE_ASSET_URL=""
CHROME_FIXTURE_SCRIPT_URL=""
CHROME_FIXTURE_SERVER_URL=""
CHROME_LAST_LAUNCHED_PID=""
SMOKE_LOCK_DIR="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-real-app-smoke.lock}"
SMOKE_LOCK_WAIT_SECONDS="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS:-300}"
SMOKE_LOCK_HELD=0

if [[ ! "$SMOKE_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS must be a non-negative integer." >&2
  exit 2
fi

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

cleanup_smoke_http_pids() {
  if ((${#SMOKE_HTTP_PIDS[@]})); then
    local pid
    for pid in "${SMOKE_HTTP_PIDS[@]}"; do
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    done
  fi
}

cleanup_smoke_textedit_windows() {
  if ((${#SMOKE_TEXTEDIT_WINDOW_TITLES[@]})); then
    osascript "${SMOKE_TEXTEDIT_WINDOW_TITLES[@]}" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  tell application "TextEdit"
    repeat with targetTitle in argv
      repeat with docRef in documents
        try
          if name of docRef is targetTitle then
            close docRef saving no
          end if
        end try
      end repeat
    end repeat
  end tell
end run
APPLESCRIPT
  fi
}

cleanup_smoke() {
  cleanup_smoke_textedit_windows
  cleanup_smoke_chrome_pids
  cleanup_smoke_http_pids
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

  if [[ "$UNDO_RECOVERY_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$UNDO_RECOVERY_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$UNDO_RECOVERY_ENV_KEY" "$UNDO_RECOVERY_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$UNDO_RECOVERY_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$TEXTEDIT_APPEARANCE_WAS_SET" == "1" ]]; then
    osascript - "$TEXTEDIT_PREVIOUS_DARK_MODE" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set previousDarkMode to item 1 of argv
  tell application "System Events"
    tell appearance preferences
      if previousDarkMode is "true" then
        set dark mode to true
      else if previousDarkMode is "false" then
        set dark mode to false
      end if
    end tell
  end tell
end run
APPLESCRIPT
  fi
}

trap cleanup_smoke EXIT

acquire_smoke_lock() {
  local deadline=$((SECONDS + SMOKE_LOCK_WAIT_SECONDS))
  local announced=0

  while true; do
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
      if ((SECONDS >= deadline)); then
        echo "Another real app smoke run is already active (pid $existing_pid)." >&2
        echo "Timed out waiting for the real app smoke lock: $SMOKE_LOCK_DIR" >&2
        exit 1
      fi
      if [[ "$announced" == "0" ]]; then
        echo "Waiting for active real app smoke run to finish (pid $existing_pid)." >&2
        announced=1
      fi
      sleep 2
      continue
    fi

    rm -rf "$SMOKE_LOCK_DIR" >/dev/null 2>&1 || true
  done
}

other_smoke_process_lines() {
  local process_list current_pgid
  current_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ' || true)"
  if [[ "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST+x}" == "x" ]]; then
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
  local deadline=$((SECONDS + SMOKE_LOCK_WAIT_SECONDS))
  local announced=0
  local processes

  while true; do
    processes="$(other_smoke_process_lines || true)"
    if [[ -z "$processes" ]]; then
      return 0
    fi

    if ((SECONDS >= deadline)); then
      echo "Another real app smoke process is already active." >&2
      echo "Timed out waiting because smoke runs can type into frontmost apps." >&2
      echo "$processes" >&2
      exit 1
    fi

    if [[ "$announced" == "0" ]]; then
      echo "Waiting for active real app smoke process to finish before starting this proof." >&2
      echo "$processes" >&2
      announced=1
    fi
    sleep 2
  done
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

activate_app_by_process_name() {
  local process_name="$1"

  osascript - "$process_name" <<'APPLESCRIPT' >/dev/null 2>&1 || true
set processName to item 1 of argv
tell application "System Events"
  if exists application process processName then
    tell application process processName
      set frontmost to true
    end tell
  end if
end tell
APPLESCRIPT
}

activate_obsidian_for_smoke() {
  activate_app_by_process_name "Obsidian"
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

claude_code_host_display_name() {
  case "$CLAUDE_CODE_HOST_VARIANT" in
    auto)
      printf 'Any supported host\n'
      ;;
    terminal)
      printf 'Terminal\n'
      ;;
    iterm2)
      printf 'iTerm2\n'
      ;;
    warp)
      printf 'Warp\n'
      ;;
    ghostty)
      printf 'Ghostty\n'
      ;;
    kitty)
      printf 'kitty\n'
      ;;
    alacritty)
      printf 'Alacritty\n'
      ;;
    wezterm)
      printf 'WezTerm\n'
      ;;
  esac
}

claude_code_host_bundle_id() {
  case "$CLAUDE_CODE_HOST_VARIANT" in
    auto)
      printf 'auto\n'
      ;;
    terminal)
      printf 'com.apple.Terminal\n'
      ;;
    iterm2)
      printf 'com.googlecode.iterm2\n'
      ;;
    warp)
      printf 'dev.warp.Warp\n'
      ;;
    ghostty)
      printf 'com.mitchellh.ghostty\n'
      ;;
    kitty)
      printf 'net.kovidgoyal.kitty\n'
      ;;
    alacritty)
      printf 'org.alacritty\n'
      ;;
    wezterm)
      printf 'com.github.wez.wezterm\n'
      ;;
  esac
}

claude_code_host_proof_label() {
  case "$CLAUDE_CODE_HOST_VARIANT" in
    auto)
      printf 'default\n'
      ;;
    *)
      printf 'claude-code-%s\n' "$CLAUDE_CODE_HOST_VARIANT"
      ;;
  esac
}

claude_code_host_installed() {
  local bundle_id="$1"
  if [[ "$bundle_id" == "com.apple.Terminal" ]]; then
    [[ -d "/System/Applications/Utilities/Terminal.app" ]]
    return $?
  fi

  [[ -n "$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null | head -n 1)" ]]
}

require_claude_code_host_if_requested() {
  if [[ "$APP" != "claude-code" || "$CLAUDE_CODE_HOST_VARIANT" == "auto" ]]; then
    return 0
  fi

  local host_bundle host_name
  host_bundle="$(claude_code_host_bundle_id)"
  host_name="$(claude_code_host_display_name)"
  if claude_code_host_installed "$host_bundle"; then
    return 0
  fi

  echo "Claude Code $host_name proof requested, but $host_bundle is not installed on this Mac." >&2
  echo "Leaving this as an honest host-variant proof gap; normal terminal suggestions remain blocked." >&2
  exit 1
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

  if [[ "$NATIVE_UNDO_PROOF" =~ ^(1|true|yes|on)$ ]]; then
    if [[ "$UNDO_RECOVERY_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
      UNDO_RECOVERY_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$UNDO_RECOVERY_ENV_KEY" 2>/dev/null || true)"
      UNDO_RECOVERY_LAUNCHCTL_WAS_PREPARED=1
    fi
    export AUTOCOMPLETE_LAB_ACCEPTED_INSERTION_UNDO_RECOVERY="nativeProofOnly"
    launchctl setenv "$UNDO_RECOVERY_ENV_KEY" "nativeProofOnly" >/dev/null 2>&1 || true
    echo "Native undo proof mode: app rollback disabled; Command-Z passes to the target app."
  fi

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

obsidian_session_app() {
  if [[ -n "$OBSIDIAN_SESSION_APP" ]]; then
    printf '%s\n' "$OBSIDIAN_SESSION_APP"
    return 0
  fi

  case "${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-}" in
    obsidian-theme|obsidian-pane|obsidian-long-note)
      printf '%s\n' "$AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL"
      return 0
      ;;
  esac

  printf 'obsidian\n'
}

print_obsidian_variant_commands() {
  cat <<'EOF'
Required Obsidian proof lanes:
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate
EOF
}

obsidian_smoke_marker_text() {
  local manual_app="$1"
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_BASE:-Autocomplete Lab Obsidian proof}"

  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    printf '%s\n' "$marker"
    local line
    for line in $(seq 1 90); do
      printf 'Autocomplete Lab Obsidian scroll filler line %02d\n' "$line"
    done
    printf '%s\n' "$marker"
    printf 'S\n'
    return 0
  fi

  printf '%s\n' "$marker"
}

obsidian_marker_text_area_count() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "Autocomplete Lab Obsidian proof"

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func countMarkerTextAreas(in element: AXUIElement, depth: Int = 0) -> Int {
    if depth > 24 {
        return 0
    }

    let role = copyAttribute(element, kAXRoleAttribute) as? String
    let value = copyAttribute(element, kAXValueAttribute) as? String ?? ""
    var count = (role == kAXTextAreaRole as String && value.contains(marker)) ? 1 : 0
    for child in children(of: element) {
        count += countMarkerTextAreas(in: child, depth: depth + 1)
    }
    return count
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    print(0)
    exit(0)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
print(countMarkerTextAreas(in: appElement))
SWIFT
}

prepare_obsidian_pane_variant_if_needed() {
  activate_obsidian_for_smoke
  local pane_count
  pane_count="$(obsidian_marker_text_area_count 2>/dev/null || echo 0)"
  if (( pane_count >= 2 )); then
    return 0
  fi

  osascript <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  tell application process "Obsidian"
    set frontmost to true
    click menu item "Split Right" of menu "View" of menu bar item "View" of menu bar 1
  end tell
end tell
APPLESCRIPT
  sleep 0.8
  activate_obsidian_for_smoke

  pane_count="$(obsidian_marker_text_area_count 2>/dev/null || echo 0)"
  if (( pane_count < 2 )); then
    echo "Could not verify two Obsidian editor panes for pane proof." >&2
    exit 3
  fi
}

prepare_obsidian_variant_state() {
  local manual_app="$1"

  case "$manual_app" in
    obsidian-pane)
      prepare_obsidian_pane_variant_if_needed
      ;;
    obsidian-theme)
      # The smoke lane must be run in a vault/theme setup that visibly differs
      # from the default Obsidian editor. The proof vault used by this project
      # carries the Autocomplete Lab Proof theme.
      activate_obsidian_for_smoke
      ;;
    obsidian-long-note)
      activate_obsidian_for_smoke
      move_obsidian_caret_to_document_end
      ;;
    obsidian)
      activate_obsidian_for_smoke
      ;;
  esac
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

allocate_local_port() {
  python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

chrome_fixture_is_official_demo() {
  case "$1" in
    textarea-public|contenteditable-public|codemirror-official|monaco-official|prosemirror-official)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_fixture_is_public_text_field_demo() {
  case "$1" in
    textarea-public|contenteditable-public)
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
    textarea-public)
      printf '%s\n' "https://www.editpad.org/"
      ;;
    contenteditable-public)
      printf '%s\n' "https://yabwe.github.io/medium-editor/"
      ;;
    codemirror-official)
      printf '%s\n' "https://codemirror.net/try/"
      ;;
    monaco-official)
      printf '%s\n' "https://microsoft.github.io/monaco-editor/playground.html"
      ;;
    prosemirror-official)
      printf '%s\n' "https://prosemirror.net/examples/basic/"
      ;;
    browser-chat-harness)
      if [[ -z "$CHROME_FIXTURE_SERVER_URL" ]]; then
        echo "Chrome browser-chat-harness server is not ready." >&2
        exit 1
      fi
      printf '%s/%s\n' "$CHROME_FIXTURE_SERVER_URL" "$(basename "$local_html_file")"
      ;;
    *)
      file_url "$local_html_file"
      ;;
  esac
}

start_chrome_fixture_http_server() {
  local tmp_dir="$1"
  local port
  port="$(allocate_local_port)"

  if [[ -z "$port" ]]; then
    echo "Could not allocate a local browser-chat proof port." >&2
    exit 1
  fi

  (cd "$tmp_dir" && python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) &
  local http_pid="$!"
  SMOKE_HTTP_PIDS+=("$http_pid")
  CHROME_FIXTURE_SERVER_URL="http://127.0.0.1:$port"

  local deadline=$((SECONDS + 5))
  while ((SECONDS <= deadline)); do
    if curl -fsS --max-time 1 "$CHROME_FIXTURE_SERVER_URL/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  echo "Timed out waiting for browser-chat proof HTTP server." >&2
  exit 1
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
    if chrome_fixture_is_public_text_field_demo "$fixture"; then
      # Public top-level text-field demos are proofed through URL loading,
      # guarded coordinate focus, and AX-focused-editor verification below.
      # They do not need Chrome's "Allow JavaScript from Apple Events" setting.
      sleep 1
      return 0
    fi

    if chrome_focus_official_demo_editor_with_ax "$fixture" "$chrome_pid" >/dev/null 2>&1; then
      return 0
    fi

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

chrome_public_setup_text_with_devtools() {
  local fixture="$1"
  local text="$2"

  if [[ -z "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
    return 1
  fi

  node - "$CHROME_REMOTE_DEBUGGING_PORT" "$fixture" "$text" <<'NODE'
const port = process.argv[2];
const fixture = process.argv[3];
const text = process.argv[4];

async function fetchJSON(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  return response.json();
}

async function tabWebSocketURL() {
  const deadline = Date.now() + 8000;
  while (Date.now() <= deadline) {
    try {
      const tabs = await fetchJSON(`http://127.0.0.1:${port}/json`);
      const page = tabs.find((tab) => tab.type === "page" && !String(tab.url || "").startsWith("devtools://"));
      if (page?.webSocketDebuggerUrl) {
        return page.webSocketDebuggerUrl;
      }
    } catch {
      // Chrome may still be bringing up the DevTools endpoint.
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error("Timed out waiting for Chrome DevTools page target.");
}

function expressionForFixture() {
  const encodedText = JSON.stringify(text);
  if (!fixture.endsWith("-public") && !fixture.endsWith("-official")) {
    return `(() => {
      const text = ${encodedText};
      if (typeof window.insertAutocompleteSmokeText === 'function') {
        const result = window.insertAutocompleteSmokeText(text);
        return { ok: true, role: result?.role || 'custom', valueLength: result?.valueLength || 0 };
      }
      const editor = document.querySelector('[data-smoke-editor]');
      if (!editor) return { ok: false, reason: 'missing smoke editor' };
      editor.focus();
      if (editor.tagName === 'TEXTAREA' || editor.tagName === 'INPUT') {
        const nextValue = String(editor.value || '') + text;
        editor.value = nextValue;
        editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
        if (typeof editor.setSelectionRange === 'function') {
          editor.setSelectionRange(editor.value.length, editor.value.length);
        }
        return { ok: true, role: 'textarea', valueLength: editor.value.length };
      }
      const current = String(editor.textContent || '').replace(/^\\s+$/, '');
      const nextValue = current + text;
      editor.textContent = nextValue;
      const range = document.createRange();
      range.selectNodeContents(editor);
      range.collapse(false);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
      return { ok: true, role: 'contenteditable', valueLength: editor.textContent.length };
    })()`;
  }

  if (fixture === "textarea-public") {
    return `(() => {
      const text = ${encodedText};
      const editors = Array.from(document.querySelectorAll('textarea'))
        .filter((editor) => {
          const rect = editor.getBoundingClientRect();
          return rect.width >= 300 && rect.height >= 120;
        })
        .sort((a, b) => {
          const ar = a.getBoundingClientRect();
          const br = b.getBoundingClientRect();
          return (br.width * br.height) - (ar.width * ar.height);
        });
      const editor = editors[0];
      if (!editor) return { ok: false, reason: 'missing textarea' };
      editor.focus();
      const nextValue = String(editor.value || '') + text;
      editor.value = nextValue;
      editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
      editor.setSelectionRange(editor.value.length, editor.value.length);
      return {
        ok: true,
        role: 'textarea',
        valueLength: editor.value.length,
        selectionStart: editor.selectionStart,
        selectionEnd: editor.selectionEnd
      };
    })()`;
  }

  if (fixture === "contenteditable-public") {
    return `(() => {
      const text = ${encodedText};
      const editors = Array.from(document.querySelectorAll('[contenteditable="true"], [role="textbox"]'))
        .filter((editor) => {
          const rect = editor.getBoundingClientRect();
          return rect.width >= 300 && rect.height >= 60;
        })
        .sort((a, b) => {
          const av = /dead simple inline editor/i.test(a.textContent || '') ? 1000000 : 0;
          const bv = /dead simple inline editor/i.test(b.textContent || '') ? 1000000 : 0;
          const ar = a.getBoundingClientRect();
          const br = b.getBoundingClientRect();
          return (bv + br.width * br.height) - (av + ar.width * ar.height);
        });
      const editor = editors[0];
      if (!editor) return { ok: false, reason: 'missing contenteditable' };
      editor.focus();
      const current = String(editor.textContent || '');
      const separator = current.length > 0 && !/\\s$/.test(current) && !/^\\s/.test(text) ? ' ' : '';
      editor.textContent = current + separator + text;
      const range = document.createRange();
      range.selectNodeContents(editor);
      range.collapse(false);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      editor.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
      return {
        ok: true,
        role: 'contenteditable',
        valueLength: editor.textContent.length,
        selectionText: selection.toString()
      };
    })()`;
  }

  return `({ ok: false, reason: 'unsupported fixture' })`;
}

async function evaluateExpression(wsURL, expression) {
  const socket = new WebSocket(wsURL);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  const id = 1;
  const responsePromise = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Timed out waiting for Runtime.evaluate.")), 8000);
    socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      clearTimeout(timeout);
      resolve(message);
    });
  });

  socket.send(JSON.stringify({
    id,
    method: "Runtime.evaluate",
    params: {
      expression,
      awaitPromise: true,
      returnByValue: true
    }
  }));

  const message = await responsePromise;
  socket.close();
  if (message.error) {
    throw new Error(message.error.message || "Runtime.evaluate failed.");
  }
  if (message.result?.exceptionDetails) {
    throw new Error(message.result.exceptionDetails.text || "Runtime.evaluate exception.");
  }
  return message.result?.result?.value;
}

try {
  const wsURL = await tabWebSocketURL();
  const value = await evaluateExpression(wsURL, expressionForFixture());
  if (!value?.ok) {
    console.error(`Chrome ${fixture} DevTools setup failed: ${value?.reason || "unknown"}`);
    process.exit(1);
  }
  console.log(`Chrome ${fixture} DevTools setup focused ${value.role} valueLength=${value.valueLength}`);
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
NODE
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
    textarea-public)
      javascript="Boolean(document.querySelector('textarea'))"
      ;;
    contenteditable-public)
      javascript="Boolean(document.querySelector('[contenteditable=\"true\"], [role=\"textbox\"]'))"
      ;;
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
  local expected_url="${2:-}"
  local javascript

  if [[ -n "$expected_url" ]]; then
    focus_default_chrome_smoke_tab "$fixture" "$expected_url" >/dev/null
  fi

  if chrome_focus_official_demo_editor_with_ax "$fixture" "" >/dev/null 2>&1; then
    return 0
  fi

  case "$fixture" in
    textarea-public)
      javascript="(() => { const editor = document.querySelector('textarea'); if (!editor) return 'missing'; editor.setAttribute('aria-label', 'Public textarea proof field'); editor.scrollIntoView({block: 'center', inline: 'center'}); editor.focus(); editor.setSelectionRange(editor.value.length, editor.value.length); return 'ok'; })()"
      ;;
    contenteditable-public)
      javascript="(() => { const editor = document.querySelector('[contenteditable=\"true\"], [role=\"textbox\"]'); if (!editor) return 'missing'; editor.setAttribute('aria-label', 'Public contenteditable proof field'); editor.scrollIntoView({block: 'center', inline: 'center'}); editor.focus(); const range = document.createRange(); range.selectNodeContents(editor); range.collapse(false); const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range); return 'ok'; })()"
      ;;
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

chrome_focus_official_demo_editor_with_ax() {
  local fixture="$1"
  local chrome_pid="${2:-0}"

  swift - "$fixture" "${chrome_pid:-0}" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let rawPID = Int32(CommandLine.arguments[2]) else {
    exit(2)
}

let fixture = CommandLine.arguments[1]
let pid: pid_t
if rawPID > 0 {
    pid = pid_t(rawPID)
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
          let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" {
    pid = frontmostPID
} else {
    fputs("Chrome \(fixture) official proof could not find a frontmost Chrome process.\n", stderr)
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

func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
    copyAttribute(element, attribute) as? Bool ?? false
}

func rect(for element: AXUIElement) -> CGRect? {
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

func hasWebAreaAncestor(_ element: AXUIElement) -> Bool {
    var current = element
    for _ in 0..<18 {
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

func setCaretToEnd(_ element: AXUIElement, value: String) {
    var range = CFRange(location: value.utf16.count, length: 0)
    if let rangeValue = AXValueCreate(.cfRange, &range) {
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
    }
}

struct Candidate {
    let element: AXUIElement
    let role: String
    let title: String
    let description: String
    let value: String
    let frame: CGRect
    let focused: Bool
    let score: Double
}

func scoreCandidate(role: String, title: String, description: String, value: String, frame: CGRect, focused: Bool) -> Double? {
    guard role == "AXTextArea" || role == "AXTextField" else {
        return nil
    }
    guard frame.width >= 100, frame.height >= 10 else {
        return nil
    }

    var score = frame.width * frame.height
    if focused {
        score += 500_000
    }

    let haystack = "\(title)\n\(description)\n\(value)".lowercased()
    switch fixture {
    case "codemirror-official":
        guard role == "AXTextArea", frame.width >= 300, frame.height >= 80 else {
            return nil
        }
        if haystack.contains("console.log") || haystack.contains("hello") {
            score += 1_000_000
        }
    case "monaco-official":
        if haystack.contains("editor") || haystack.contains("monaco") || haystack.contains("press alt") {
            score += 1_000_000
        }
        if frame.height < 24 {
            score -= 250_000
        }
    case "prosemirror-official":
        guard frame.width >= 250, frame.height >= 40 else {
            return nil
        }
        if haystack.contains("prosemirror") || haystack.contains("this is editable") {
            score += 1_000_000
        }
    default:
        break
    }
    return score
}

func collectCandidates(in element: AXUIElement, depth: Int = 0, candidates: inout [Candidate]) {
    guard depth <= 42 else {
        return
    }

    let role = stringAttribute(element, kAXRoleAttribute)
    let title = stringAttribute(element, kAXTitleAttribute)
    let description = stringAttribute(element, kAXDescriptionAttribute)
    let value = stringAttribute(element, kAXValueAttribute)
    if hasWebAreaAncestor(element),
       let frame = rect(for: element),
       let score = scoreCandidate(
            role: role,
            title: title,
            description: description,
            value: value,
            frame: frame,
            focused: boolAttribute(element, kAXFocusedAttribute)
       ) {
        candidates.append(Candidate(
            element: element,
            role: role,
            title: title,
            description: description,
            value: value,
            frame: frame,
            focused: boolAttribute(element, kAXFocusedAttribute),
            score: score
        ))
    }

    for child in children(of: element) {
        collectCandidates(in: child, depth: depth + 1, candidates: &candidates)
    }
}

if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate(options: [.activateAllWindows])
}

Thread.sleep(forTimeInterval: 0.2)

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 1.0)

var candidates: [Candidate] = []
for _ in 0..<40 {
    candidates.removeAll(keepingCapacity: true)
    collectCandidates(in: appElement, candidates: &candidates)
    if !candidates.isEmpty {
        break
    }
    Thread.sleep(forTimeInterval: 0.2)
}

guard let candidate = candidates.max(by: { lhs, rhs in
    if lhs.score == rhs.score {
        return lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
    }
    return lhs.score < rhs.score
}) else {
    fputs("Chrome \(fixture) official proof could not find a web-backed editor through AX.\n", stderr)
    exit(1)
}

if let focusedWindowValue = copyAttribute(appElement, kAXFocusedWindowAttribute) {
    AXUIElementPerformAction((focusedWindowValue as! AXUIElement), kAXRaiseAction as CFString)
}

if let source = CGEventSource(stateID: .hidSystemState) {
    let point = CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)
    for eventType in [CGEventType.leftMouseDown, .leftMouseUp] {
        if let event = CGEvent(
            mouseEventSource: source,
            mouseType: eventType,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            event.post(tap: .cghidEventTap)
        }
    }
}

Thread.sleep(forTimeInterval: 0.15)
AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
setCaretToEnd(candidate.element, value: candidate.value)
Thread.sleep(forTimeInterval: 0.15)

guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Chrome \(fixture) official proof could not verify the focused AX editor.\n", stderr)
    exit(1)
}

let focused = focusedValue as! AXUIElement
let focusedRole = stringAttribute(focused, kAXRoleAttribute)
let focusedWebBacked = hasWebAreaAncestor(focused)
guard focusedRole == "AXTextArea" || (focusedRole == "AXTextField" && focusedWebBacked) else {
    fputs("Chrome \(fixture) official proof focused wrong AX role \(focusedRole.isEmpty ? "unknown" : focusedRole).\n", stderr)
    exit(1)
}

print("Chrome \(fixture) official AX focused \(candidate.role) frame=x=\(Int(candidate.frame.minX)),y=\(Int(candidate.frame.minY)),w=\(Int(candidate.frame.width)),h=\(Int(candidate.frame.height))")
SWIFT
}

chrome_fixture_uses_isolated_accessibility_chrome() {
  if [[ "$CHROME_ACCESSIBILITY_MODE" != "forced" ]]; then
    return 1
  fi

  if chrome_fixture_is_official_demo "$1" && ! chrome_fixture_is_public_text_field_demo "$1"; then
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

chrome_fixture_has_chat_no_submit_guard() {
  case "$1" in
    chat-like|browser-chat-harness)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_fixture_requires_full_accept() {
  case "$1" in
    browser-chat-harness)
      return 1
      ;;
    *)
      return 0
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

  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    echo "Google Chrome app is missing: /Applications/Google Chrome.app" >&2
    exit 1
  fi

  local chrome_args=(
    --user-data-dir="$profile_dir" \
    --force-renderer-accessibility \
    --no-first-run \
    --no-default-browser-check \
    --disable-default-apps \
    --disable-sync
  )
  if [[ -n "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
    chrome_args+=(
      --remote-debugging-port="$CHROME_REMOTE_DEBUGGING_PORT"
      --remote-allow-origins="http://127.0.0.1:$CHROME_REMOTE_DEBUGGING_PORT"
    )
  fi
  chrome_args+=(--new-window "$chrome_url")

  open -na "Google Chrome" --args "${chrome_args[@]}" >/dev/null 2>&1

  local chrome_pid
  chrome_pid="$(wait_for_isolated_chrome_pid "$profile_dir" 10)"
  SMOKE_CHROME_PIDS+=("$chrome_pid")
  CHROME_LAST_LAUNCHED_PID="$chrome_pid"
}

wait_for_isolated_chrome_pid() {
  local profile_dir="$1"
  local timeout_seconds="${2:-10}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local pid
    pid="$(ps -axo pid=,command= | awk -v profile="$profile_dir" '
      /Contents\/MacOS\/Google Chrome/ && index($0, "--user-data-dir=" profile) {
        print $1
        exit
      }
    ')"
    if [[ -n "$pid" ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for isolated Chrome profile process: $profile_dir" >&2
  exit 1
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
      let source = CGEventSource(stateID: .hidSystemState) else {
    exit(1)
}

let focusedWindow = windowValue as! AXUIElement
let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
let smokeWindow = windows.first {
    (copyAttribute($0, "AXDocument") as? String ?? "").contains("autocomplete-lab-chrome-")
}
let windowElement = smokeWindow ?? focusedWindow
AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)

guard let windowBounds = bounds(for: windowElement) else {
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
    textarea-public|contenteditable-public)
      printf '760 310\n'
      ;;
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
    chat-like|browser-chat-harness)
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

focus_chrome_public_text_field_editor() {
  local fixture="$1"
  local chrome_pid="${2:-0}"

  swift - "$fixture" "$chrome_pid" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let rawPID = Int32(CommandLine.arguments[2]) else {
    exit(2)
}

let fixture = CommandLine.arguments[1]
let pid: pid_t
if rawPID > 0 {
    pid = pid_t(rawPID)
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
          let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" {
    pid = frontmostPID
} else {
    fputs("Chrome \(fixture) public proof could not find a frontmost Chrome process.\n", stderr)
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

func rect(for element: AXUIElement) -> CGRect? {
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

struct Candidate {
    let element: AXUIElement
    let role: String
    let title: String
    let value: String
    let frame: CGRect
    let score: Double
}

func isExpectedPublicCandidate(_ candidate: Candidate) -> Bool {
    switch fixture {
    case "textarea-public":
        return candidate.role == "AXTextArea"
            && candidate.frame.width >= 300
            && candidate.frame.height >= 120
    case "contenteditable-public":
        return candidate.role == "AXTextArea"
            && candidate.frame.width >= 300
            && candidate.frame.height >= 60
    default:
        return true
    }
}

func collectCandidates(in element: AXUIElement, depth: Int = 0, candidates: inout [Candidate]) {
    guard depth <= 40 else {
        return
    }

    let role = stringAttribute(element, kAXRoleAttribute)
    let title = stringAttribute(element, kAXTitleAttribute)
    if (role == "AXTextArea" || role == "AXTextField"),
       hasWebAreaAncestor(element),
       let frame = rect(for: element),
       frame.width >= 100,
       frame.height >= 20 {
        var score = frame.width * frame.height
        let value = stringAttribute(element, kAXValueAttribute)
        if fixture == "textarea-public", role == "AXTextArea", value.isEmpty, frame.height >= 120 {
            score += 1_000_000
        }
        if fixture == "contenteditable-public",
           role == "AXTextArea",
           value.localizedCaseInsensitiveContains("dead simple inline editor") {
            score += 1_000_000
        } else if fixture == "contenteditable-public", role == "AXTextArea" || role == "AXTextField" {
            score += 100_000
        }
        candidates.append(Candidate(element: element, role: role, title: title, value: value, frame: frame, score: score))
    }

    for child in children(of: element) {
        collectCandidates(in: child, depth: depth + 1, candidates: &candidates)
    }
}

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 1.0)

var candidates: [Candidate] = []
for _ in 0..<40 {
    candidates.removeAll(keepingCapacity: true)
    collectCandidates(in: appElement, candidates: &candidates)
    if candidates.contains(where: isExpectedPublicCandidate) {
        break
    }
    Thread.sleep(forTimeInterval: 0.2)
}

let eligibleCandidates = candidates.filter(isExpectedPublicCandidate)
guard let candidate = eligibleCandidates.max(by: { $0.score < $1.score }) else {
    fputs("Chrome \(fixture) public proof could not find a web-backed editable text target through AX.\n", stderr)
    exit(1)
}

if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate(options: [.activateAllWindows])
}

if let focusedWindowValue = copyAttribute(appElement, kAXFocusedWindowAttribute) {
    AXUIElementPerformAction((focusedWindowValue as! AXUIElement), kAXRaiseAction as CFString)
}

if let source = CGEventSource(stateID: .hidSystemState) {
    let point = CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)
    for eventType in [CGEventType.leftMouseDown, .leftMouseUp] {
        if let event = CGEvent(
            mouseEventSource: source,
            mouseType: eventType,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            event.post(tap: .cghidEventTap)
        }
    }
}

Thread.sleep(forTimeInterval: 0.15)
AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
let value = stringAttribute(candidate.element, kAXValueAttribute)
var range = CFRange(location: value.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &range) {
    AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
Thread.sleep(forTimeInterval: 0.15)

guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Chrome \(fixture) public proof could not verify focused AX element after focusing candidate.\n", stderr)
    exit(1)
}

let focused = focusedValue as! AXUIElement
let focusedRole = stringAttribute(focused, kAXRoleAttribute)
let focusedWebBacked = hasWebAreaAncestor(focused)
guard focusedRole == "AXTextArea" || (focusedRole == "AXTextField" && focusedWebBacked) else {
    fputs(
        "Chrome \(fixture) public proof focused candidate at x=\(Int(candidate.frame.midX)),y=\(Int(candidate.frame.midY)), but focused AX role is \(focusedRole.isEmpty ? "unknown" : focusedRole).\n",
        stderr
    )
    exit(1)
}

print("Chrome \(fixture) public proof focused \(candidate.role) title=\(candidate.title.isEmpty ? "none" : candidate.title) frame=x=\(Int(candidate.frame.minX)),y=\(Int(candidate.frame.minY)),w=\(Int(candidate.frame.width)),h=\(Int(candidate.frame.height))")
SWIFT
}

focus_chrome_smoke_editor() {
  local fixture="${1:-$CHROME_FIXTURE}"
  local chrome_pid="${2:-}"
  local expected_url="${3:-${CHROME_CURRENT_FIXTURE_URL:-}}"
  local click_x_offset click_y_offset
  read -r click_x_offset click_y_offset < <(chrome_fixture_click_offsets "$fixture")

  if chrome_fixture_is_public_text_field_demo "$fixture"; then
    focus_chrome_public_text_field_editor "$fixture" "${chrome_pid:-0}"
    if [[ -n "$chrome_pid" ]]; then
      wait_for_frontmost_process_id "$chrome_pid" 5
    else
      wait_for_frontmost_app "Google Chrome" 5
    fi
    return 0
  fi

  if [[ -n "$chrome_pid" ]]; then
    focus_chrome_process_window "$chrome_pid" "$click_x_offset" "$click_y_offset"
    return 0
  fi

  if chrome_fixture_is_official_demo "$fixture"; then
    if chrome_fixture_is_public_text_field_demo "$fixture"; then
      osascript >/dev/null <<APPLESCRIPT
tell application "Google Chrome"
  activate
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
      wait_for_frontmost_app "Google Chrome" 5
      return 0
    fi

    osascript >/dev/null <<'APPLESCRIPT'
tell application "Google Chrome"
  activate
end tell
delay 0.1
APPLESCRIPT
    chrome_focus_official_demo_editor "$fixture" "$expected_url"
    wait_for_frontmost_app "Google Chrome" 5
    return 0
  fi

  if [[ -n "$expected_url" ]]; then
    focus_default_chrome_smoke_tab "$fixture" "$expected_url" >/dev/null
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
        let deadline = Date().addingTimeInterval(2.0)
        while Date() <= deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? app.processIdentifier)
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
        let deadline = Date().addingTimeInterval(2.0)
        while Date() <= deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? app.processIdentifier)
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
    wait_for_frontmost_process_id "$target_pid" 5 "TextEdit smoke window"
  else
    osascript >/dev/null <<'APPLESCRIPT'
tell application "System Events"
  tell process "TextEdit"
    set frontmost to true
  end tell
end tell
APPLESCRIPT
    wait_for_frontmost_app "TextEdit" 5
  fi
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
    wait_for_frontmost_process_id "$target_pid" 5 "TextEdit smoke window"
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
    wait_for_frontmost_app "TextEdit" 5
  fi
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

native_undo_proof_requested() {
  [[ "$NATIVE_UNDO_PROOF" =~ ^(1|true|yes|on)$ ]]
}

latest_log_field_since() {
  local start_line="$1"
  local event_name="$2"
  local field_name="$3"

  python3 - "$LOG_PATH" "$start_line" "$event_name" "$field_name" <<'PY'
import re
import sys

path, start_line, event_name, field_name = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
pattern = re.compile(r"(^| )" + re.escape(field_name) + r"=([^ ]+)")
value = ""
try:
    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line or event_name not in line:
                continue
            match = pattern.search(line)
            if match:
                value = match.group(2)
except FileNotFoundError:
    pass
print(value)
PY
}

record_native_undo_proof() {
  local app_bundle_id="$1"
  local acceptance_id="$2"
  local accept_mode="$3"
  local label="$4"

  if [[ -z "$acceptance_id" ]]; then
    echo "Cannot record native undo proof for $label: missing acceptanceID." >&2
    exit 1
  fi

  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '%s accepted-insertion-native-undo-verified acceptMode=%s acceptanceID=%s app=%s proofSource=real_app_smoke restoredOriginalTarget=true sameSliceUndoProof=true undoMechanism=nativeSingleEdit\n' \
    "$timestamp" "$accept_mode" "$acceptance_id" "$app_bundle_id" >>"$LOG_PATH"

  python3 - "$TRACE_PATH" "$timestamp" "$app_bundle_id" "$acceptance_id" "$accept_mode" <<'PY'
import json
import sys
import uuid

path, timestamp, app, acceptance_id, accept_mode = sys.argv[1:6]
event = {
    "id": str(uuid.uuid4()),
    "schemaVersion": 3,
    "privacyVersion": 2,
    "experimentArm": "length_3_word",
    "timestamp": timestamp,
    "sessionID": "real-app-smoke",
    "suggestionID": acceptance_id,
    "type": "acceptedInsertionUndone",
    "appBundleIdentifier": app,
    "fieldIdentity": "",
    "requestMode": "",
    "triggerReason": "",
    "textBeforeCursor": "",
    "textAfterCursor": "",
    "systemPrompt": "",
    "userPrompt": "",
    "rawOutput": "",
    "cleanedVisibleText": "",
    "displayedText": "",
    "acceptedText": "",
    "remainingVisibleText": "",
    "outcome": accept_mode,
    "reason": "native-single-edit-undo-verified",
    "screenshotPath": "",
    "metadata": {
        "acceptanceID": acceptance_id,
        "acceptMode": accept_mode,
        "undoMechanism": "nativeSingleEdit",
        "sameSliceUndoProof": "true",
        "restoredOriginalTarget": "true",
        "proofSource": "real_app_smoke"
    }
}
with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(event, separators=(",", ":")) + "\n")
PY
}

wait_for_textedit_document_exact() {
  local window_title="$1"
  local expected_text="$2"
  local label="$3"
  local timeout_seconds="${4:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local current_text
    current_text="$(textedit_document_text "$window_title")"
    if [[ "$current_text" == "$expected_text" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for TextEdit native undo during $label." >&2
  echo "Expected: $expected_text" >&2
  echo "Actual: $(textedit_document_text "$window_title")" >&2
  exit 1
}

verify_textedit_native_undo() {
  local window_title="$1"
  local expected_text="$2"
  local start_line="$3"
  local label="$4"
  local accept_mode="$5"
  local acceptance_id
  acceptance_id="$(latest_log_field_since "$start_line" "accepted-insertion-undo-armed" "acceptanceID")"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "z" using command down
end tell
APPLESCRIPT
  wait_for_textedit_document_exact "$window_title" "$expected_text" "$label" 8
  record_native_undo_proof "com.apple.TextEdit" "$acceptance_id" "$accept_mode" "$label"
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

textedit_smoke_session_app() {
  case "$TEXTEDIT_VARIANT" in
    "")
      printf 'textedit\n'
      ;;
    *)
      printf 'textedit-%s\n' "$TEXTEDIT_VARIANT"
      ;;
  esac
}

textedit_first_fragment() {
  case "$TEXTEDIT_VARIANT" in
    long-wrap)
      printf '%s\n' "This disposable TextEdit proof intentionally uses a long wrapped line in a narrow native document so the caret lands after wrapping and still feels inst"
      ;;
    *)
      printf '%s\n' "Smoke proof feels inst"
      ;;
  esac
}

set_textedit_appearance() {
  local desired="$1"

  if [[ "$TEXTEDIT_APPEARANCE_WAS_SET" != "1" ]]; then
    TEXTEDIT_PREVIOUS_DARK_MODE="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  tell appearance preferences
    return dark mode
  end tell
end tell
APPLESCRIPT
)"
    TEXTEDIT_APPEARANCE_WAS_SET=1
  fi

  osascript - "$desired" <<'APPLESCRIPT' >/dev/null
on run argv
  set desiredMode to item 1 of argv
  tell application "System Events"
    tell appearance preferences
      if desiredMode is "dark" then
        set dark mode to true
      else
        set dark mode to false
      end if
    end tell
  end tell
end run
APPLESCRIPT
  sleep 0.8
}

set_textedit_window_frame() {
  local window_title="$1"
  local x="$2"
  local y="$3"
  local width="$4"
  local height="$5"

  swift - "$window_title" "$x" "$y" "$width" "$height" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 6,
      let x = Double(CommandLine.arguments[2]),
      let y = Double(CommandLine.arguments[3]),
      let width = Double(CommandLine.arguments[4]),
      let height = Double(CommandLine.arguments[5]) else {
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
        var position = CGPoint(x: x, y: y)
        var size = CGSize(width: width, height: height)
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            exit(1)
        }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        exit(0)
    }
}

exit(1)
SWIFT
}

set_textedit_selected_range() {
  local window_title="$1"
  local location="$2"
  local length="$3"

  swift - "$window_title" "$location" "$length" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 4,
      let location = Int(CommandLine.arguments[2]),
      let length = Int(CommandLine.arguments[3]) else {
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
        var range = CFRange(location: location, length: length)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            exit(1)
        }
        let result = AXUIElementSetAttributeValue(textInput, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        exit(result == .success ? 0 : 1)
    }
}

exit(1)
SWIFT
}

assert_chrome_chat_safety_counters_zero() {
  local fixture="$1"
  local label="$2"
  local tab_title submit_count send_key_count prompt_mutation_count wrong_context_count

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

  case "$fixture" in
    browser-chat-harness)
      if [[ "$tab_title" =~ submits=([0-9]+).*sendKeys=([0-9]+).*promptMutations=([0-9]+).*wrongContext=([0-9]+) ]]; then
        submit_count="${BASH_REMATCH[1]}"
        send_key_count="${BASH_REMATCH[2]}"
        prompt_mutation_count="${BASH_REMATCH[3]}"
        wrong_context_count="${BASH_REMATCH[4]}"
      else
        echo "Could not read Chrome browser-chat harness counters during $label; expected title counters, got: $tab_title" >&2
        exit 1
      fi

      if [[ "$submit_count" != "0" || "$send_key_count" != "0" || "$prompt_mutation_count" != "0" || "$wrong_context_count" != "0" ]]; then
        echo "Chrome browser-chat harness recorded unsafe counter(s) during $label: submits=$submit_count sendKeys=$send_key_count promptMutations=$prompt_mutation_count wrongContext=$wrong_context_count." >&2
        exit 1
      fi
      ;;
    *)
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
      ;;
  esac
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

focus_default_chrome_smoke_tab() {
  local fixture="$1"
  local expected_url="$2"
  local expected_leaf=""

  if [[ "$expected_url" == file://* ]]; then
    expected_leaf="$(basename "${expected_url#file://}")"
  fi

  osascript - "$fixture" "$expected_url" "$expected_leaf" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  set fixtureName to item 1 of argv
  set expectedURL to item 2 of argv
  set expectedLeaf to item 3 of argv

  tell application "Google Chrome"
    try
      activate
      repeat with chromeWindow in windows
        set tabIndex to 1
        repeat with chromeTab in tabs of chromeWindow
          set tabURL to URL of chromeTab
          set tabTitle to title of chromeTab
          set urlMatches to tabURL starts with expectedURL
          set leafMatches to false
          if expectedLeaf is not "" then
            set leafMatches to tabURL contains expectedLeaf
          end if
          set titleMatches to tabTitle contains ("Autocomplete Lab Chrome") and tabTitle contains ("[ready=1]")
          if urlMatches or leafMatches or titleMatches then
            set active tab index of chromeWindow to tabIndex
            set index of chromeWindow to 1
            return "ok"
          end if
          set tabIndex to tabIndex + 1
        end repeat
      end repeat
    end try
  end tell

  return "missing:" & fixtureName
end run
APPLESCRIPT
}

chrome_active_tab_url_for_pid() {
  local chrome_pid="$1"

  swift - "$chrome_pid" <<'SWIFT'
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2,
      let rawPID = Int32(CommandLine.arguments[1]) else {
    exit(2)
}

let appElement = AXUIElementCreateApplication(pid_t(rawPID))
AXUIElementSetMessagingTimeout(appElement, 0.5)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

let focusedWindow: AXUIElement?
if let focusedWindowValue = copyAttribute(appElement, kAXFocusedWindowAttribute) {
    focusedWindow = (focusedWindowValue as! AXUIElement)
} else {
    focusedWindow = nil
}
let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] ?? []
let smokeWindow = windows.first {
    (copyAttribute($0, "AXDocument") as? String ?? "").contains("autocomplete-lab-chrome-")
}
let firstWindow = windows.first
guard let window = smokeWindow ?? focusedWindow ?? firstWindow else {
    print("")
    exit(1)
}

print(copyAttribute(window, "AXDocument") as? String ?? "")
SWIFT
}

assert_chrome_expected_tab() {
  local fixture="$1"
  local expected_url="$2"
  local label="$3"
  local chrome_pid="${4:-}"
  local active_url

  if [[ -n "$chrome_pid" ]]; then
    active_url="$(chrome_active_tab_url_for_pid "$chrome_pid")"
  else
    focus_default_chrome_smoke_tab "$fixture" "$expected_url" >/dev/null
    active_url="$(chrome_active_tab_url)"
  fi
  if [[ -z "$active_url" ]]; then
    echo "Chrome $fixture smoke refused to type during $label: no active Chrome tab URL." >&2
    return 1
  fi

  if chrome_fixture_is_official_demo "$fixture"; then
    if [[ "$active_url" != "$expected_url"* ]]; then
      echo "Chrome $fixture smoke refused to type during $label: expected official demo URL '$expected_url', got '$active_url'." >&2
      return 1
    fi
    return 0
  fi

  if [[ "$expected_url" == file://* && "$active_url" != file://*autocomplete-lab-chrome-"$fixture"-smoke.html* ]]; then
    echo "Chrome $fixture smoke refused to type during $label: expected local smoke fixture, got '$active_url'." >&2
    return 1
  fi

  if [[ "$expected_url" == http://127.0.0.1:* && "$active_url" != "$expected_url"* ]]; then
    echo "Chrome $fixture smoke refused to type during $label: expected bounded local harness '$expected_url', got '$active_url'." >&2
    return 1
  fi
}

wait_for_chrome_expected_tab() {
  local fixture="$1"
  local expected_url="$2"
  local label="$3"
  local chrome_pid="${4:-}"
  local timeout_seconds="${5:-10}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if assert_chrome_expected_tab "$fixture" "$expected_url" "$label" "$chrome_pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  assert_chrome_expected_tab "$fixture" "$expected_url" "$label" "$chrome_pid"
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
func currentFocusedValue() -> String {
    copyAttribute(focusedElement, kAXValueAttribute) as? String ?? ""
}

func selectedTextRange() -> CFRange? {
    guard let rangeValue = copyAttribute(focusedElement, kAXSelectedTextRangeAttribute) else {
        return nil
    }

    var range = CFRange(location: 0, length: 0)
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return nil
    }

    return range
}

func setCursorToEnd(of value: String) {
    var cursorRange = CFRange(location: value.utf16.count, length: 0)
    if let rangeValue = AXValueCreate(.cfRange, &cursorRange) {
        AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
    }
}

func cursorIsAtEnd(of value: String) -> Bool {
    guard let range = selectedTextRange() else {
        return false
    }

    return range.location >= value.utf16.count && range.length == 0
}

func waitForInsertedText() -> Bool {
    for _ in 0..<30 {
        let currentValue = currentFocusedValue()
        if currentValue.contains(text)
            && (currentValue.count >= initialValue.count + text.count || currentValue.count >= text.count) {
            setCursorToEnd(of: currentValue)
            return true
        }
        usleep(100_000)
    }

    return false
}

func waitForInsertedTextAtEnd(_ expectedValue: String) -> Bool {
    for _ in 0..<30 {
        let currentValue = currentFocusedValue()
        if currentValue == expectedValue && cursorIsAtEnd(of: expectedValue) {
            return true
        }
        usleep(100_000)
    }

    return false
}

guard let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create a CGEvent source.\n", stderr)
    exit(1)
}

if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate(options: [.activateAllWindows])
}

Thread.sleep(forTimeInterval: 0.1)

enum TextEventDestination {
    case pid
    case eventTap
}

func postTextEvents(destination: TextEventDestination) {
    for codeUnit in text.utf16 {
        var unit = codeUnit
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create text events.\n", stderr)
            exit(1)
        }

        keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
        switch destination {
        case .pid:
            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
        case .eventTap:
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
        usleep(15_000)
    }
}

func postPasteShortcut(destination: TextEventDestination) {
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
        fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create paste events.\n", stderr)
        exit(1)
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    switch destination {
    case .pid:
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    case .eventTap:
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

func postCommandRight(destination: TextEventDestination) {
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
        fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): could not create cursor-end events.\n", stderr)
        exit(1)
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    switch destination {
    case .pid:
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    case .eventTap:
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

postTextEvents(destination: .pid)
if waitForInsertedText() {
    exit(0)
}

let selectedTextResult = AXUIElementSetAttributeValue(
    focusedElement,
    kAXSelectedTextAttribute as CFString,
    text as CFTypeRef
)
if selectedTextResult == .success && waitForInsertedText() {
    exit(0)
}

let valueReplacement = initialValue + text
let valueReplacementResult = AXUIElementSetAttributeValue(
    focusedElement,
    kAXValueAttribute as CFString,
    valueReplacement as CFTypeRef
)
if valueReplacementResult == .success {
    setCursorToEnd(of: valueReplacement)
    postCommandRight(destination: .pid)
    setCursorToEnd(of: valueReplacement)
    postCommandRight(destination: .eventTap)
    setCursorToEnd(of: valueReplacement)
    if waitForInsertedTextAtEnd(valueReplacement) {
        exit(0)
    }
}

postTextEvents(destination: .eventTap)
if waitForInsertedText() {
    exit(0)
}

let pasteboard = NSPasteboard.general
let previousPasteboardString = pasteboard.string(forType: .string)
pasteboard.clearContents()
if pasteboard.setString(text, forType: .string) {
    postPasteShortcut(destination: .pid)
    if waitForInsertedText() {
        pasteboard.clearContents()
        if let previousPasteboardString {
            pasteboard.setString(previousPasteboardString, forType: .string)
        }
        exit(0)
    }

    postPasteShortcut(destination: .eventTap)
    if waitForInsertedText() {
        pasteboard.clearContents()
        if let previousPasteboardString {
            pasteboard.setString(previousPasteboardString, forType: .string)
        }
        exit(0)
    }
}
pasteboard.clearContents()
if let previousPasteboardString {
    pasteboard.setString(previousPasteboardString, forType: .string)
}

let finalValue = currentFocusedValue()
fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): targeted text events, AX selected-text fallback, AX value replacement, foreground text events, and guarded paste did not update the focused Chrome editor (beforeChars=\(initialValue.count), afterChars=\(finalValue.count), selectedTextResult=\(selectedTextResult.rawValue), valueReplacementResult=\(valueReplacementResult.rawValue)).\n", stderr)
exit(1)
SWIFT
}

chrome_focused_editor_text() {
  local fixture="$1"
  local chrome_pid="$2"

  swift - "$fixture" "${chrome_pid:-0}" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3,
      let rawPID = Int32(CommandLine.arguments[2]) else {
    exit(2)
}

let pid: pid_t
if rawPID > 0 {
    pid = pid_t(rawPID)
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
          let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" {
    pid = frontmostPID
} else {
    print("")
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

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)
guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    print("")
    exit(1)
}

let focusedElement = focusedValue as! AXUIElement
print(copyAttribute(focusedElement, kAXValueAttribute) as? String ?? "")
SWIFT
}

reset_chrome_focused_editor_text() {
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
} else if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
          let frontmost = NSWorkspace.shared.frontmostApplication,
          frontmost.bundleIdentifier == "com.google.Chrome" || frontmost.localizedName == "Google Chrome" {
    pid = frontmostPID
} else {
    fputs("Chrome \(fixture) smoke could not reset setup text during \(label): frontmost app is not Google Chrome.\n", stderr)
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

let appElement = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(appElement, 0.5)
guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Chrome \(fixture) smoke could not reset setup text during \(label): Chrome has no focused AX element.\n", stderr)
    exit(1)
}

let focusedElement = focusedValue as! AXUIElement
let role = stringAttribute(focusedElement, kAXRoleAttribute)
guard role == "AXTextArea" || role == "AXTextField" else {
    fputs("Chrome \(fixture) smoke could not reset setup text during \(label): focused AX role is \(role.isEmpty ? "unknown" : role).\n", stderr)
    exit(1)
}

let result = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, "" as CFTypeRef)
guard result == .success else {
    fputs("Chrome \(fixture) smoke could not reset setup text during \(label): AX result \(result.rawValue).\n", stderr)
    exit(1)
}

var cursorRange = CFRange(location: 0, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &cursorRange) {
    AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
SWIFT
}

wait_for_chrome_focused_text_contains() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_fragment="$3"
  local label="$4"
  local timeout_seconds="${5:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local current_text
    current_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
    if [[ "$current_text" == *"$expected_fragment"* ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Chrome setup text during $label." >&2
  echo "Expected fragment: $expected_fragment" >&2
  echo "Actual: $(chrome_focused_editor_text "$fixture" "$chrome_pid")" >&2
  exit 1
}

chrome_focused_text_stably_contains() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_fragment="$3"
  local stable_samples="${4:-6}"
  local sample_delay="${5:-0.15}"
  local matched_samples=0

  while ((matched_samples < stable_samples)); do
    local current_text
    current_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
    if [[ "$current_text" != *"$expected_fragment"* ]]; then
      return 1
    fi
    matched_samples=$((matched_samples + 1))
    sleep "$sample_delay"
  done

  return 0
}

wait_for_chrome_focused_text_exact() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_text="$3"
  local label="$4"
  local timeout_seconds="${5:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local current_text
    current_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
    if [[ "$current_text" == "$expected_text" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Chrome native undo during $label." >&2
  echo "Expected: $expected_text" >&2
  echo "Actual: $(chrome_focused_editor_text "$fixture" "$chrome_pid")" >&2
  exit 1
}

verify_chrome_native_undo() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_text="$3"
  local start_line="$4"
  local label="$5"
  local accept_mode="$6"
  local acceptance_id
  acceptance_id="$(latest_log_field_since "$start_line" "accepted-insertion-undo-armed" "acceptanceID")"

  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "z" using command down
end tell
APPLESCRIPT
  wait_for_chrome_focused_text_exact "$fixture" "$chrome_pid" "$expected_text" "$label" 8
  record_native_undo_proof "com.google.Chrome" "$acceptance_id" "$accept_mode" "$label"
}

escape_applescript_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

type_chrome_smoke_text_with_system_events() {
  local text="$1"
  local escaped_text
  escaped_text="$(escape_applescript_string "$text")"

  osascript <<APPLESCRIPT
tell application "System Events"
  keystroke "$escaped_text"
end tell
APPLESCRIPT
}

assert_chrome_ready_for_input() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_url="$3"
  local label="$4"

  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture $label"
    assert_chrome_expected_tab "$fixture" "$expected_url" "$label" "$chrome_pid"
    assert_chrome_focused_editable_ax "$fixture" "$chrome_pid" "$label"
    return 0
  fi

  assert_frontmost_app "Google Chrome" "Chrome $fixture $label"
  assert_chrome_expected_tab "$fixture" "$expected_url" "$label"
  assert_chrome_focused_editable_ax "$fixture" "" "$label"
}

codex_proof_text() {
  local proof_text="${AUTOCOMPLETE_LAB_CODEX_PROOF_TEXT:-AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this dicta}"
  if [[ "$proof_text" != *"AUTOCOMPLETE_LAB_CODEX_PROOF"* ]]; then
    echo "Codex proof text must include AUTOCOMPLETE_LAB_CODEX_PROOF." >&2
    exit 2
  fi
  if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
    echo "Codex proof text must be a single line." >&2
    exit 2
  fi
  printf '%s\n' "$proof_text"
}

seed_codex_proof_prompt() {
  local proof_text="$1"

  swift - "$proof_text" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("missing Codex proof text\n", stderr)
    exit(2)
}

let proofText = CommandLine.arguments[1]
let marker = "AUTOCOMPLETE_LAB_CODEX_PROOF"

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

func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
    copyAttribute(element, attribute) as? Bool ?? false
}

func rect(for element: AXUIElement) -> CGRect? {
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

func setSelectedRange(_ element: AXUIElement, location: Int, length: Int) {
    var range = CFRange(location: location, length: length)
    guard let rangeValue = AXValueCreate(.cfRange, &range) else {
        return
    }
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}

func focusedElement(in appElement: AXUIElement) -> AXUIElement? {
    guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
        return nil
    }
    return (focusedValue as! AXUIElement)
}

func rangeDescription(_ element: AXUIElement) -> String {
    guard let rangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute) else {
        return "missing"
    }

    var range = CFRange()
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return "unreadable"
    }
    return "location=\(range.location),length=\(range.length)"
}

func postCommandRight(to pid: pid_t) {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
        return
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.postToPid(pid)
    keyUp.postToPid(pid)
}

func selectedRangeMatches(_ element: AXUIElement, location: Int, length: Int) -> Bool {
    guard let rangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute) else {
        return false
    }

    var range = CFRange()
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return false
    }
    return range.location == location && range.length == length
}

struct Candidate {
    let element: AXUIElement
    let value: String
    let frame: CGRect
    let focused: Bool
    let score: Double
}

func collectTextAreas(in element: AXUIElement, depth: Int = 0, candidates: inout [Candidate]) {
    guard depth <= 32 else {
        return
    }

    let role = stringAttribute(element, kAXRoleAttribute)
    if role == kAXTextAreaRole as String,
       let frame = rect(for: element),
       frame.width >= 260,
       frame.height >= 20,
       frame.height <= 260 {
        let value = stringAttribute(element, kAXValueAttribute)
        let looksDisposable = value.isEmpty
            || value.contains(marker)
            || value.localizedCaseInsensitiveContains("Ask Codex anything")
            || value.localizedCaseInsensitiveContains("Describe a task or ask a question")
        if looksDisposable {
            let focused = boolAttribute(element, kAXFocusedAttribute)
            var score = frame.width
            if focused {
                score += 1_000
            }
            if value.contains(marker) {
                score += 800
            }
            if value.localizedCaseInsensitiveContains("Ask Codex anything")
                || value.localizedCaseInsensitiveContains("Describe a task or ask a question") {
                score += 500
            }
            candidates.append(Candidate(
                element: element,
                value: value,
                frame: frame,
                focused: focused,
                score: score
            ))
        }
    }

    for child in children(of: element) {
        collectTextAreas(in: child, depth: depth + 1, candidates: &candidates)
    }
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.openai.codex"
).first else {
    fputs("Codex is not running.\n", stderr)
    exit(1)
}

app.activate(options: [.activateAllWindows])
Thread.sleep(forTimeInterval: 0.35)

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)

var candidates: [Candidate] = []
collectTextAreas(in: appElement, candidates: &candidates)

guard let candidate = candidates.sorted(by: { lhs, rhs in
    if lhs.score == rhs.score {
        return lhs.frame.minY < rhs.frame.minY
    }
    return lhs.score > rhs.score
}).first else {
    fputs("Could not find a safe disposable Codex composer. Clear the prompt, open a new Codex start screen, or seed AUTOCOMPLETE_LAB_CODEX_PROOF manually.\n", stderr)
    exit(1)
}

AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
let setResult = AXUIElementSetAttributeValue(
    candidate.element,
    kAXValueAttribute as CFString,
    proofText as CFTypeRef
)
guard setResult == .success else {
    fputs("Could not seed the Codex proof composer through Accessibility (AX result \(setResult.rawValue)).\n", stderr)
    exit(1)
}

let cursorOffset = proofText.utf16.count
for _ in 0..<4 {
    AXUIElementSetAttributeValue(candidate.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    setSelectedRange(candidate.element, location: cursorOffset, length: 0)
    postCommandRight(to: app.processIdentifier)
    Thread.sleep(forTimeInterval: 0.12)
    if selectedRangeMatches(candidate.element, location: cursorOffset, length: 0) {
        break
    }
}

let currentText = stringAttribute(candidate.element, kAXValueAttribute)
guard currentText == proofText else {
    fputs("Codex proof composer did not retain the disposable marker text after seeding.\n", stderr)
    exit(1)
}

let cursorState = selectedRangeMatches(candidate.element, location: cursorOffset, length: 0)
guard cursorState else {
    fputs("Codex proof composer did not place the cursor at the end of the disposable marker text.\n", stderr)
    exit(1)
}

guard let focused = focusedElement(in: appElement) else {
    fputs("Codex proof composer could not verify the focused AX element after seeding.\n", stderr)
    exit(1)
}

let focusedRole = stringAttribute(focused, kAXRoleAttribute)
let focusedText = stringAttribute(focused, kAXValueAttribute)
let focusedCursorAtEnd = focusedText == proofText
    && selectedRangeMatches(focused, location: cursorOffset, length: 0)
guard focusedCursorAtEnd else {
    fputs("Codex proof composer was seeded, but the focused AX element is not the disposable prompt at the end cursor (focusedRole=\(focusedRole.isEmpty ? "unknown" : focusedRole), focusedChars=\(focusedText.count), focusedHasMarker=\(focusedText.contains(marker)), focusedRange=\(rangeDescription(focused))).\n", stderr)
    exit(1)
}

print("Seeded Codex proof composer: chars=\(proofText.count) rect=x=\(Int(candidate.frame.minX)),y=\(Int(candidate.frame.minY)),w=\(Int(candidate.frame.width)),h=\(Int(candidate.frame.height))")
SWIFT
}

assert_codex_prompt_retains_marker() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = "AUTOCOMPLETE_LAB_CODEX_PROOF"

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

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func containsMarkerTextArea(_ element: AXUIElement, depth: Int = 0) -> Bool {
    guard depth <= 32 else {
        return false
    }

    if stringAttribute(element, kAXRoleAttribute) == kAXTextAreaRole as String,
       stringAttribute(element, kAXValueAttribute).contains(marker) {
        return true
    }

    return children(of: element).contains { child in
        containsMarkerTextArea(child, depth: depth + 1)
    }
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.openai.codex"
).first else {
    fputs("Codex is not running after proof accept.\n", stderr)
    exit(1)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)

guard containsMarkerTextArea(appElement) else {
    fputs("Codex proof marker is no longer present in a composer after Tab accept; refusing to claim no-submit proof.\n", stderr)
    exit(1)
}

print("Codex proof marker still present after Tab accept.")
SWIFT
}

type_chrome_smoke_text() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_url="$3"
  local label="$4"
  local text="$5"

  assert_chrome_ready_for_input "$fixture" "$chrome_pid" "$expected_url" "$label"
  if chrome_public_setup_text_with_devtools "$fixture" "$text"; then
    wait_for_chrome_focused_text_contains "$fixture" "$chrome_pid" "$text" "$label" 8
    return 0
  fi

  if insert_chrome_smoke_text_with_ax "$fixture" "$chrome_pid" "$label" "$text"; then
    if chrome_focused_text_stably_contains "$fixture" "$chrome_pid" "$text"; then
      return 0
    fi
    echo "Chrome $fixture setup text was not stable after AX insertion during $label; retrying through guarded System Events." >&2
    reset_chrome_focused_editor_text "$fixture" "$chrome_pid" "$label"
  fi

  focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$expected_url"
  sleep 0.2
  assert_chrome_ready_for_input "$fixture" "$chrome_pid" "$expected_url" "$label"
  type_chrome_smoke_text_with_system_events "$text"
  wait_for_chrome_focused_text_contains "$fixture" "$chrome_pid" "$text" "$label" 8
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
window.insertAutocompleteSmokeText = function (text) {
  const editor = document.querySelector("[data-smoke-editor]");
  editor.focus();
  editor.value = editor.value + text;
  editor.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
  editor.setSelectionRange(editor.value.length, editor.value.length);
  return { role: "textarea", valueLength: editor.value.length };
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
  window.insertAutocompleteSmokeText = function (text) {
    const model = editor.getModel();
    const lineNumber = model.getLineCount();
    const column = model.getLineMaxColumn(lineNumber);
    editor.executeEdits("autocomplete-lab-smoke", [{
      range: new monaco.Range(lineNumber, column, lineNumber, column),
      text,
      forceMoveMarkers: true
    }]);
    window.focusSmokeEditor();
    return { role: "monaco", valueLength: editor.getValue().length };
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
    browser-chat-harness)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Autocomplete Lab Browser Chat Proof Harness [submits=0 sendKeys=0 promptMutations=0 wrongContext=0]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<style>
body {
  margin: 0;
  background: #f4f6f8;
  color: #1f2328;
  font: 16px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
.shell {
  width: 780px;
  margin: 68px auto;
}
.message {
  max-width: 540px;
  padding: 12px 14px;
  border: 1px solid #d5dbe3;
  border-radius: 8px;
  background: #ffffff;
}
form {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 10px;
  align-items: end;
  margin-top: 22px;
  padding: 12px;
  border: 1px solid #cad2dc;
  border-radius: 8px;
  background: #ffffff;
}
[data-smoke-editor],
[data-smoke-wrong-context] {
  min-height: 44px;
  max-height: 140px;
  padding: 10px 12px;
  border: 1px solid #c4ccd6;
  border-radius: 6px;
  outline: none;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
button {
  min-width: 72px;
  min-height: 38px;
}
.meter,
.guard {
  margin-top: 10px;
  color: #56616f;
  font-size: 13px;
}
.wrong-context {
  position: absolute;
  left: -10000px;
  top: 0;
  width: 240px;
  height: 48px;
  overflow: hidden;
}
</style>
<section class="shell" aria-label="Bounded browser-chat proof harness">
  <div class="message">Disposable browser-chat proof harness. Safe local text only.</div>
  <form data-smoke-form>
    <div data-smoke-editor role="textbox" aria-label="Disposable chat composer" aria-multiline="true" contenteditable="true" spellcheck="false"></div>
    <button type="submit">Send</button>
  </form>
  <div class="meter" aria-live="polite">
    Submits: <span data-smoke-submit-count>0</span>
    Send-key collisions: <span data-smoke-send-key-count>0</span>
    Prompt mutations: <span data-smoke-prompt-mutation-count>0</span>
    Wrong-context insertions: <span data-smoke-wrong-context-count>0</span>
  </div>
  <div class="guard" data-smoke-context>Context guard text must not change.</div>
  <div class="wrong-context" aria-hidden="true">
    <div data-smoke-wrong-context role="textbox" aria-label="Wrong context guard" contenteditable="true"></div>
  </div>
</section>
<script>
window.autocompleteSmokeCounters = {
  submits: 0,
  sendKeys: 0,
  promptMutations: 0,
  wrongContext: 0
};
window.updateSmokeCounters = function () {
  const counters = window.autocompleteSmokeCounters;
  document.title = "Autocomplete Lab Browser Chat Proof Harness [submits=" + counters.submits
    + " sendKeys=" + counters.sendKeys
    + " promptMutations=" + counters.promptMutations
    + " wrongContext=" + counters.wrongContext + "]";
  document.querySelector("[data-smoke-submit-count]").textContent = String(counters.submits);
  document.querySelector("[data-smoke-send-key-count]").textContent = String(counters.sendKeys);
  document.querySelector("[data-smoke-prompt-mutation-count]").textContent = String(counters.promptMutations);
  document.querySelector("[data-smoke-wrong-context-count]").textContent = String(counters.wrongContext);
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
  window.autocompleteSmokeCounters.submits += 1;
  window.updateSmokeCounters();
});
document.querySelector("[data-smoke-editor]").addEventListener("keydown", function (event) {
  const enterSend = event.key === "Enter" && (!event.shiftKey || event.metaKey || event.ctrlKey);
  if (enterSend) {
    event.preventDefault();
    window.autocompleteSmokeCounters.sendKeys += 1;
    window.updateSmokeCounters();
  }
});
document.querySelector("button").addEventListener("click", function (event) {
  event.preventDefault();
  window.autocompleteSmokeCounters.sendKeys += 1;
  window.updateSmokeCounters();
});
const contextGuard = document.querySelector("[data-smoke-context]");
const contextObserver = new MutationObserver(function () {
  window.autocompleteSmokeCounters.promptMutations += 1;
  window.updateSmokeCounters();
});
contextObserver.observe(contextGuard, {
  characterData: true,
  childList: true,
  subtree: true
});
document.querySelector("[data-smoke-wrong-context]").addEventListener("input", function () {
  window.autocompleteSmokeCounters.wrongContext += 1;
  window.updateSmokeCounters();
});
window.updateSmokeCounters();
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
      if [[ -n "$TEXTEDIT_VARIANT" ]]; then
        echo "TextEdit variant: $TEXTEDIT_VARIANT"
      fi
      case "$TEXTEDIT_VARIANT" in
        "")
          echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file, type a test fragment, then validate logs and traces."
          ;;
        selected-suppression)
          echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file, select text, then prove suggestions stay suppressed with no insertion."
          ;;
        fast-typing)
          echo "Plan: build/relaunch AutocompleteLab, run the disposable TextEdit typing soak, then record pass-through proof."
          ;;
        undo-one-word)
          echo "Plan: build/relaunch AutocompleteLab with app rollback disabled, prove TextEdit Tab accept, then Command-Z the one-word insertion through native TextEdit undo."
          ;;
        undo-full)
          echo "Plan: build/relaunch AutocompleteLab with app rollback disabled, prove TextEdit Tab/full accept, then Command-Z the full accepted insertion through native TextEdit undo."
          ;;
        *)
          echo "Plan: build/relaunch AutocompleteLab, open a disposable TextEdit file for the $TEXTEDIT_VARIANT variant, type a test fragment, then validate logs and traces."
          ;;
      esac
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
      elif [[ "$CHROME_FIXTURE" == "production-text-fields" ]]; then
        echo "Plan: build/relaunch AutocompleteLab, then run bounded public Chrome textarea and contenteditable proof on top-level demo pages with disposable text."
        echo "Proof path: production text-field lanes use public URLs plus guarded coordinate focus and AX verification; Chrome JavaScript-from-Apple-Events is not required for these two lanes."
      elif chrome_fixture_is_public_text_field_demo "$CHROME_FIXTURE"; then
        echo "Plan: build/relaunch AutocompleteLab, open the public top-level $CHROME_FIXTURE demo page in Chrome, type a disposable test fragment, then validate logs and traces."
        echo "Proof path: public text-field proof uses guarded coordinate focus and AX verification; Chrome JavaScript-from-Apple-Events is not required for this lane."
      elif chrome_fixture_is_official_demo "$CHROME_FIXTURE"; then
        echo "Plan: build/relaunch AutocompleteLab, open the public official $CHROME_FIXTURE demo page in Chrome, type a disposable test fragment, then validate logs and traces."
        echo "Proof path: official Chrome demo lanes first use Accessibility to focus and verify the editor, then fall back to Chrome's JavaScript-from-Apple-Events setting if AX cannot find the editor."
      elif [[ "$CHROME_FIXTURE" == "browser-chat-harness" ]]; then
        echo "Plan: build/relaunch AutocompleteLab, serve the bounded HTTP browser-chat no-submit proof harness on 127.0.0.1, type disposable text, then validate trace and harness counters."
        echo "Scope: this proves only the disposable harness surface. It does not enable Slack, Discord, ChatGPT, or broad browser chat support."
      else
        echo "Plan: build/relaunch AutocompleteLab, open a disposable Chrome $CHROME_FIXTURE fixture, type a test fragment, then validate logs and traces."
      fi
      echo "Safety: the smoke launch temporarily enables Chrome only for this proof pass."
      echo "Safety: before Chrome typing, the smoke requires Chrome to expose a focused editable web text target through Accessibility."
      echo "Safety: Chrome setup text first uses process-targeted events, then a guarded System Events fallback only after the disposable editor is rechecked as frontmost and editable."
      ;;
    notes)
      local notes_app notes_surface
      if notes_app="$(notes_session_app)"; then
        notes_surface="${notes_app#notes-}"
        case "$notes_app" in
          notes-title)
            echo "Plan: guarded Apple Notes title proof. The script creates a fresh blank note, verifies the focused title line is blank, types smoke fragments, then validates logs and traces."
            ;;
          notes-body)
            echo "Plan: guarded Apple Notes body proof. The script verifies the open note body contains the disposable marker, appends smoke fragments, then validates logs and traces."
            ;;
          notes-checklist)
            echo "Plan: guarded Apple Notes checklist proof. The script creates a fresh disposable note, toggles Checklist from Notes' Format menu, verifies the disposable prefix, types smoke fragments, then validates logs and traces."
            ;;
          *)
            echo "Plan: manual-gated Apple Notes $notes_surface proof. The script validates only that surface after you run it."
            ;;
        esac
      else
        echo "Plan: choose a manual-gated Apple Notes surface before recording proof."
        print_notes_surface_commands
      fi
      echo "Safety: pass --manual-gate to continue. Use only the disposable autocomplete smoke note with body marker 'Autocomplete smoke'."
      ;;
    obsidian)
      local obsidian_app
      obsidian_app="$(obsidian_session_app)"
      case "$obsidian_app" in
        obsidian-theme)
          echo "Plan: manual-gated Obsidian non-default theme proof. The script validates caret-bound placement after you run it."
          ;;
        obsidian-pane)
          echo "Plan: manual-gated Obsidian split/side-pane proof. The script validates same-pane placement and insertion after you run it."
          ;;
        obsidian-long-note)
          echo "Plan: manual-gated Obsidian long scrolled note proof. The script validates visible scrolled-caret placement after you run it."
          ;;
        *)
          echo "Plan: manual-gated disposable Obsidian default-note smoke. The script prints the checklist and validates after you run it."
          ;;
      esac
      echo "Safety: pass --manual-gate to continue. Use only a disposable vault note."
      print_obsidian_variant_commands
      ;;
    codex)
      echo "Plan: manual-gated Codex prompt smoke. The script seeds disposable AUTOCOMPLETE_LAB_CODEX_PROOF text and validates one-word Tab accept without submit."
      echo "Safety: pass --manual-gate to continue. The helper never presses Enter; full accept waits for separate full-accept no-submit proof."
      echo "Safety: the helper refuses to overwrite non-disposable prompt text unless it already contains the Codex proof marker."
      ;;
    claude-code)
      local host_bundle host_name host_status proof_label
      host_bundle="$(claude_code_host_bundle_id)"
      host_name="$(claude_code_host_display_name)"
      proof_label="$(claude_code_host_proof_label)"
      if [[ "$CLAUDE_CODE_HOST_VARIANT" == "auto" ]]; then
        host_status="not pinned; default proof label"
      elif claude_code_host_installed "$host_bundle"; then
        host_status="installed"
      else
        host_status="not installed; honest proof gap"
      fi
      echo "Plan: manual-gated terminal-host Claude Code proof. The script validates one-word Tab accept without submit after you run it."
      echo "Claude Code host: $host_name ($host_bundle), $host_status"
      echo "Claude Code proof label: $proof_label"
      echo "Safety: pass --manual-gate to continue. Use the named supported terminal host, include AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF, and do not press Enter."
      echo "Proof target: terminal-hosted Claude Code must validate one-word Tab accept without submitting shell input or an agent prompt."
      ;;
    claude)
      echo "Plan: manual-gated prompt smoke. The script validates one-word Tab accept without submit after you run it."
      if [[ -n "$CLAUDE_SESSION_APP" ]]; then
        echo "Claude layout proof: $CLAUDE_SESSION_APP"
      fi
      echo "Safety: pass --manual-gate to continue. Do not press Enter; full accept waits for separate full-accept no-submit proof."
      ;;
  esac
}

build_if_needed() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  AUTOCOMPLETE_LAB_DIRECT_LAUNCH=1 \
    AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN=1 \
    ./script/build_and_run.sh run
  wait_for_current_autocomplete_lab_process
}

wait_for_current_autocomplete_lab_process() {
  local expected_binary="$ROOT_DIR/dist/AutocompleteLab.app/Contents/MacOS/AutocompleteLab"
  local deadline=$((SECONDS + 20))

  while ((SECONDS <= deadline)); do
    local found_current=0
    local stale_processes=""
    local pid command
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
      [[ -z "$command" ]] && continue
      if [[ "$command" == "$expected_binary" ]]; then
        found_current=1
      else
        stale_processes+="${pid} ${command}"$'\n'
      fi
    done < <(pgrep -f "/[A]utocompleteLab.app/Contents/MacOS/AutocompleteLab" 2>/dev/null || true)

    if [[ "$found_current" == "1" && -z "$stale_processes" ]]; then
      return 0
    fi
    sleep 0.25
  done

  echo "AutocompleteLab smoke launch did not settle on this checkout's app bundle." >&2
  echo "Expected binary: $expected_binary" >&2
  echo "Running AutocompleteLab processes:" >&2
  pgrep -f "/[A]utocompleteLab.app/Contents/MacOS/AutocompleteLab" 2>/dev/null |
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      ps -p "$pid" -o pid=,command= 2>/dev/null || true
    done >&2
  exit 1
}

run_codex() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local runtime_start_line start_line trace_start_line proof_text
  runtime_start_line="$(line_count "$LOG_PATH")"
  proof_text="$(codex_proof_text)"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "Codex runtime readiness" 60 "$SKIP_BUILD"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  seed_codex_proof_prompt "$proof_text"
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.openai.codex" "Codex proof suggestion" 20
  wait_for_screenshot_capture_if_enabled "$start_line" "com.openai.codex" "Codex proof"
  seed_codex_proof_prompt "$proof_text"
  assert_frontmost_app "Codex" "Codex proof"
  press_key_code 48
  wait_for_log_fields "$start_line" "Codex Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.openai.codex" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert .*app=com.openai.codex .*success=true" "Codex successful insertion" 12
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.openai.codex .*result=verified" "Codex verified insertion" 12
  assert_codex_prompt_retains_marker

  sleep 1
  AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh codex --check --visual
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
  elif [[ "$APP" == "obsidian" ]]; then
    manual_app="$(obsidian_session_app)"
  fi
  require_claude_code_host_if_requested

  prepare_temporary_app_enablement
  build_if_needed
  local full_accept_key
  local proof_label_env
  full_accept_key="$(accept_all_shortcut)"
  proof_label_env="${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-}"
  if [[ "$APP" == "claude" && -n "$CLAUDE_SESSION_APP" ]]; then
    proof_label_env="$CLAUDE_SESSION_APP"
  elif [[ "$APP" == "claude-code" ]]; then
    proof_label_env="$(claude_code_host_proof_label)"
  fi
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
  AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$proof_label_env" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT="$CLAUDE_CODE_HOST_VARIANT" \
    ./script/manual_smoke_session.sh "$manual_app"
}

assert_notes_body_smoke_target() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_SMOKE_MARKER"] ?? "Autocomplete smoke"

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Notes" else {
    fputs("Notes is not frontmost for the Notes body smoke target.\n", stderr)
    exit(3)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Notes" }) else {
    fputs("Apple Notes is not running. Open the disposable Autocomplete smoke note first.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard let body = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    fputs("Could not read the focused Notes body text view.\n", stderr)
    exit(3)
}

AXUIElementSetMessagingTimeout(body, 1.0)
let role = copyAttribute(body, kAXRoleAttribute) as? String
guard role == kAXTextAreaRole as String else {
    fputs("Focused Notes element is not the body text view.\n", stderr)
    exit(3)
}

let bodyText = copyAttribute(body, kAXValueAttribute) as? String ?? ""
guard bodyText.localizedCaseInsensitiveContains(marker) else {
    fputs("Refusing to type in Notes because the open note body does not contain the marker '\(marker)'.\n", stderr)
    exit(3)
}

AXUIElementSetAttributeValue(body, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: bodyText.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(body, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
print("Notes body smoke target confirmed")
SWIFT
}

assert_notes_title_smoke_target() {
  AUTOCOMPLETE_LAB_NOTES_EXPECTED_PREFIX="${1:-}" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let expectedPrefix = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_EXPECTED_PREFIX"] ?? ""

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Notes" else {
    fputs("Notes is not frontmost for the Notes title smoke target.\n", stderr)
    exit(3)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Notes" }) else {
    fputs("Apple Notes is not running. Open the disposable Autocomplete smoke note first.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard let title = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    fputs("Could not read the focused Notes title text view.\n", stderr)
    exit(3)
}

AXUIElementSetMessagingTimeout(title, 1.0)
let role = copyAttribute(title, kAXRoleAttribute) as? String
guard role == kAXTextAreaRole as String else {
    fputs("Focused Notes element is not the title text view.\n", stderr)
    exit(3)
}

let titleText = copyAttribute(title, kAXValueAttribute) as? String ?? ""
guard !titleText.contains("\n") else {
    fputs("Refusing Notes title proof because the focused editor already spans multiple lines.\n", stderr)
    exit(3)
}

if expectedPrefix.isEmpty {
    guard titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        fputs("Refusing Notes title proof because the fresh title line is not blank.\n", stderr)
        exit(3)
    }
} else {
    guard titleText.hasPrefix(expectedPrefix) else {
        fputs("Refusing Notes title proof because the focused title does not start with the expected disposable text.\n", stderr)
        exit(3)
    }
}

AXUIElementSetAttributeValue(title, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: titleText.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(title, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
print("Notes title smoke target confirmed")
SWIFT
}

assert_notes_checklist_smoke_target() {
  AUTOCOMPLETE_LAB_NOTES_EXPECTED_PREFIX="${1:-}" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let expectedPrefix = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_EXPECTED_PREFIX"] ?? ""
let titleMarker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE"] ?? "Autocomplete Lab Checklist Smoke"

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Notes" else {
    fputs("Notes is not frontmost for the Notes checklist smoke target.\n", stderr)
    exit(3)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Notes" }) else {
    fputs("Apple Notes is not running. Open the disposable Autocomplete smoke note first.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard let checklist = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    fputs("Could not read the focused Notes checklist text view.\n", stderr)
    exit(3)
}

AXUIElementSetMessagingTimeout(checklist, 1.0)
let role = copyAttribute(checklist, kAXRoleAttribute) as? String
guard role == kAXTextAreaRole as String else {
    fputs("Focused Notes element is not the checklist text view.\n", stderr)
    exit(3)
}

let text = copyAttribute(checklist, kAXValueAttribute) as? String ?? ""
let requiredPrefix = expectedPrefix.isEmpty ? "\(titleMarker)\n" : expectedPrefix
guard text.hasPrefix(requiredPrefix) else {
    fputs("Refusing Notes checklist proof because the focused note does not start with the expected disposable checklist prefix.\n", stderr)
    exit(3)
}

AXUIElementSetAttributeValue(checklist, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: text.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(checklist, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
print("Notes checklist smoke target confirmed")
SWIFT
}

assert_obsidian_smoke_target() {
  activate_obsidian_for_smoke
  AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX="${1:-}" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "Autocomplete Lab Obsidian proof"
let expectedSuffix = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX"] ?? ""

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "md.obsidian" else {
    fputs("Obsidian is not frontmost for the Obsidian smoke target.\n", stderr)
    exit(3)
}

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    fputs("Obsidian is not running. Open a disposable smoke note first.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard let editor = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    fputs("Could not read the focused Obsidian editor.\n", stderr)
    exit(3)
}

AXUIElementSetMessagingTimeout(editor, 1.0)
let role = copyAttribute(editor, kAXRoleAttribute) as? String
guard role == kAXTextAreaRole as String || role == "AXWebArea" else {
    fputs("Focused Obsidian element is not a CodeMirror text surface.\n", stderr)
    exit(3)
}

let text = copyAttribute(editor, kAXValueAttribute) as? String ?? ""
guard text.localizedCaseInsensitiveContains(marker) else {
    fputs("Refusing to type in Obsidian because the focused note does not contain the disposable smoke marker.\n", stderr)
    exit(3)
}

if !expectedSuffix.isEmpty {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasSuffix(expectedSuffix) else {
        fputs("Refusing Obsidian proof because the focused smoke note does not end with the expected disposable text.\n", stderr)
        exit(3)
    }
}

AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: text.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(editor, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
print("Obsidian smoke target confirmed")
SWIFT
}

ensure_notes_title_smoke_note() {
  open -a Notes
  wait_for_frontmost_app "Notes" 8
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "n" using command down
end tell
delay 0.4
APPLESCRIPT
  assert_notes_title_smoke_target
}

ensure_notes_checklist_smoke_note() {
  local smoke_title="${AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE:-Autocomplete Lab Checklist Smoke}"

  open -a Notes
  wait_for_frontmost_app "Notes" 8
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "n" using command down
end tell
delay 0.4
APPLESCRIPT
  type_notes_raw_smoke_text "$smoke_title"$'\n'
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Notes"
    set frontmost to true
    click menu item "Checklist" of menu "Format" of menu bar item "Format" of menu bar 1
  end tell
end tell
return ""
APPLESCRIPT
  sleep 0.3
  assert_notes_checklist_smoke_target
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

  AUTOCOMPLETE_LAB_NOTES_RAW_TEXT="$text" osascript <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_NOTES_RAW_TEXT"
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.apple.Notes" then
    error "Notes is not frontmost for smoke-note setup."
  end if
  keystroke rawText
end tell
APPLESCRIPT
}

type_obsidian_raw_smoke_text() {
  local text="$1"

  activate_obsidian_for_smoke
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_AX_TYPE:-0}" == "1" ]] &&
    AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT="$text" swift - <<'SWIFT' >/dev/null 2>&1; then
import AppKit
import ApplicationServices
import Foundation

let fragment = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT"] ?? ""

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "md.obsidian",
      let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

guard let editor = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    exit(3)
}

AXUIElementSetMessagingTimeout(editor, 1.0)
let role = copyAttribute(editor, kAXRoleAttribute) as? String
guard role == kAXTextAreaRole as String || role == "AXWebArea" else {
    exit(3)
}

let text = copyAttribute(editor, kAXValueAttribute) as? String ?? ""
var endRange = CFRange(location: text.utf16.count, length: 0)
guard let rangeValue = AXValueCreate(.cfRange, &endRange) else {
    exit(3)
}
AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue)
AXUIElementSetAttributeValue(editor, kAXSelectedTextRangeAttribute as CFString, rangeValue)
guard AXUIElementSetAttributeValue(
    editor,
    kAXSelectedTextAttribute as CFString,
    fragment as CFTypeRef
) == .success else {
    exit(3)
}
SWIFT
    return 0
  fi

  AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT="$text" osascript <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT"
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "md.obsidian" then
    error "Obsidian is not frontmost for smoke-note setup."
  end if
  keystroke rawText
end tell
APPLESCRIPT
}

move_obsidian_caret_to_line_end() {
  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  key code 124 using command down
end tell
APPLESCRIPT
  sleep 0.15
}

set_obsidian_caret_to_value_end() {
  activate_obsidian_for_smoke
  swift - <<'SWIFT' >/dev/null
import AppKit
import ApplicationServices
import Foundation

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func focusedElement(from element: AXUIElement) -> AXUIElement? {
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        element,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
          let focusedValue else {
        return nil
    }

    return (focusedValue as! AXUIElement)
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "md.obsidian",
      let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 1.0)

guard let editor = focusedElement(from: appElement) ?? focusedElement(from: systemWide) else {
    exit(3)
}

AXUIElementSetMessagingTimeout(editor, 1.0)
let text = copyAttribute(editor, kAXValueAttribute) as? String ?? ""
var endRange = CFRange(location: text.utf16.count, length: 0)
guard let rangeValue = AXValueCreate(.cfRange, &endRange) else {
    exit(3)
}

AXUIElementSetAttributeValue(editor, kAXFocusedAttribute as CFString, kCFBooleanTrue)
guard AXUIElementSetAttributeValue(
    editor,
    kAXSelectedTextRangeAttribute as CFString,
    rangeValue
) == .success else {
    exit(3)
}
SWIFT
  sleep 0.15
}

move_obsidian_caret_to_document_end() {
  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  key code 125 using command down
end tell
APPLESCRIPT
  set_obsidian_caret_to_value_end
  sleep 0.25
}

reset_obsidian_smoke_note() {
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT:-${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER:-Autocomplete Lab Obsidian proof}}"

  activate_obsidian_for_smoke
  AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT="$marker" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let markerText = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT"] ?? "Autocomplete Lab Obsidian proof"

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "md.obsidian",
      let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "md.obsidian" }) else {
    fputs("Obsidian is not frontmost for smoke-note reset.\n", stderr)
    exit(3)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 1.0)
guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
    fputs("Could not read focused Obsidian editor for smoke-note reset.\n", stderr)
    exit(3)
}

let focused = (focusedValue as! AXUIElement)
AXUIElementSetMessagingTimeout(focused, 1.0)
guard AXUIElementSetAttributeValue(
    focused,
    kAXValueAttribute as CFString,
    markerText as CFTypeRef
) == .success else {
    fputs("Could not reset the disposable Obsidian smoke note text.\n", stderr)
    exit(3)
}

AXUIElementSetAttributeValue(focused, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: markerText.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
SWIFT

  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "md.obsidian" then
    error "Obsidian is not frontmost for smoke-note reset."
  end if
  key code 124 using command down
  delay 0.2
  key code 36
end tell
APPLESCRIPT
  set_obsidian_caret_to_value_end
}

obsidian_smoke_file_path() {
  local configured="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_FILE:-}"
  if [[ -n "$configured" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi

  printf '%s\n' "$HOME/Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md"
}

reset_obsidian_smoke_note_file() {
  local marker="$1"
  local smoke_file
  smoke_file="$(obsidian_smoke_file_path)"

  case "$smoke_file" in
    "$HOME/Library/Application Support/AutocompleteLab/ObsidianProofVault/"*.md)
      ;;
    *)
      echo "Refusing file reset outside the disposable Autocomplete Lab Obsidian proof vault: $smoke_file" >&2
      exit 3
      ;;
  esac

  mkdir -p "$(dirname "$smoke_file")"
  printf '%s' "$marker" >"$smoke_file"
}

append_obsidian_smoke_note_file_text() {
  local fragment="$1"
  local smoke_file
  smoke_file="$(obsidian_smoke_file_path)"

  case "$smoke_file" in
    "$HOME/Library/Application Support/AutocompleteLab/ObsidianProofVault/"*.md)
      ;;
    *)
      echo "Refusing file append outside the disposable Autocomplete Lab Obsidian proof vault: $smoke_file" >&2
      exit 3
      ;;
  esac

  printf '%s' "$fragment" >>"$smoke_file"
}

open_obsidian_smoke_note_if_configured() {
  local smoke_uri="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI:-}"
  if [[ -n "$smoke_uri" ]]; then
    open "$smoke_uri"
    sleep "${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI_WAIT_SECONDS:-2}"
    activate_obsidian_for_smoke
    return 0
  fi

  open -a Obsidian
  sleep 0.2
  activate_obsidian_for_smoke
}

run_obsidian() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local manual_app
  manual_app="$(obsidian_session_app)"

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line obsidian_marker first_fragment
  runtime_start_line="$(line_count "$LOG_PATH")"
  obsidian_marker="$(obsidian_smoke_marker_text "$manual_app")"
  first_fragment="Smoke proof feels"
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    first_fragment="moke proof feels"
  fi
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_BASE:-Autocomplete Lab Obsidian proof}"
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT="$obsidian_marker"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "Obsidian runtime readiness" 60 "$SKIP_BUILD"

  full_accept_key="$(accept_all_shortcut)"

  open_obsidian_smoke_note_if_configured
  wait_for_frontmost_app "Obsidian" 8
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    reset_obsidian_smoke_note_file "$obsidian_marker"
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
  fi
  prepare_obsidian_variant_state "$manual_app"
  assert_obsidian_smoke_target
  if [[ "$manual_app" != "obsidian-long-note" ]]; then
    reset_obsidian_smoke_note
  fi
  prepare_obsidian_variant_state "$manual_app"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  type_obsidian_raw_smoke_text "$first_fragment"
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=md.obsidian" "Obsidian suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "md.obsidian" "Obsidian"
  activate_obsidian_for_smoke
  assert_frontmost_app "Obsidian" "Obsidian"
  press_key_code 48
  wait_for_log_fields "$start_line" "Obsidian Tab acceptance" 12 \
    "keyboard-action" \
    "app=md.obsidian" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian first verified insertion"

  second_start_line="$(line_count "$LOG_PATH")"
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
    move_obsidian_caret_to_document_end
  fi
  assert_obsidian_smoke_target "Smoke proof feels instant"
  if [[ "$manual_app" == "obsidian-pane" ]]; then
    move_obsidian_caret_to_line_end
  fi
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    append_obsidian_smoke_note_file_text " and stays"
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
    move_obsidian_caret_to_document_end
  else
    type_obsidian_raw_smoke_text " and stays"
  fi
  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=md.obsidian" "Obsidian second suggestion"
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    sleep 0.15
    full_start_line="$(line_count "$LOG_PATH")"
    press_key_code 48
    wait_for_log_fields "$full_start_line" "Obsidian long-note second Tab acceptance" 12 \
      "keyboard-action" \
      "app=md.obsidian" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"
    wait_for_log_pattern "$full_start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian long-note second verified insertion"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "md.obsidian" "Obsidian second"
  else
    wait_for_screenshot_capture_if_enabled "$second_start_line" "md.obsidian" "Obsidian second"
    activate_obsidian_for_smoke
    assert_frontmost_app "Obsidian" "Obsidian"
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Obsidian full acceptance" 12 \
      "keyboard-action" \
      "app=md.obsidian" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"
    wait_for_log_pattern "$full_start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian full verified insertion"
  fi

  sleep 1
  local manual_check_args=("$manual_app" --check)
  if screenshot_trace_requested; then
    manual_check_args+=(--visual)
  fi
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh "${manual_check_args[@]}"
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

  if [[ "$manual_app" != "notes-title" && "$manual_app" != "notes-body" && "$manual_app" != "notes-checklist" ]]; then
    run_manual_gated
    return 0
  fi

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_runtime_ready "$runtime_start_line" "Notes runtime readiness" 60 "$SKIP_BUILD"

  full_accept_key="$(accept_all_shortcut)"

  if [[ "$manual_app" == "notes-title" ]]; then
    ensure_notes_title_smoke_note
    start_line="$(line_count "$LOG_PATH")"
    trace_start_line="$(line_count "$TRACE_PATH")"

    assert_notes_title_smoke_target
    type_notes_raw_smoke_text "Smoke proof feels"
    wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes title suggestion"
    wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes title"
    assert_frontmost_app "Notes" "Notes title"
    press_key_code 48
    wait_for_log_fields "$start_line" "Notes title Tab acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"
    wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes title first verified insertion"

    second_start_line="$(line_count "$LOG_PATH")"
    assert_notes_title_smoke_target "Smoke proof feels instant"
    type_notes_raw_smoke_text " and stays"
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes title second suggestion"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes title second"
    assert_frontmost_app "Notes" "Notes title"
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Notes title full acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"

    sleep 1
    local manual_check_args=(notes-title --check)
    if screenshot_trace_requested; then
      manual_check_args+=(--visual)
    fi
    AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
      AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
      AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
      ./script/manual_smoke_session.sh "${manual_check_args[@]}"
    return 0
  fi

  if [[ "$manual_app" == "notes-checklist" ]]; then
    local checklist_title="${AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE:-Autocomplete Lab Checklist Smoke}"
    ensure_notes_checklist_smoke_note
    start_line="$(line_count "$LOG_PATH")"
    trace_start_line="$(line_count "$TRACE_PATH")"

    assert_notes_checklist_smoke_target
    type_notes_raw_smoke_text "Smoke proof feels"
    wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes checklist suggestion"
    wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes checklist"
    assert_frontmost_app "Notes" "Notes checklist"
    press_key_code 48
    wait_for_log_fields "$start_line" "Notes checklist Tab acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"
    wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes checklist first verified insertion"

    second_start_line="$(line_count "$LOG_PATH")"
    assert_notes_checklist_smoke_target "$checklist_title"$'\n'"Smoke proof feels instant"
    type_notes_raw_smoke_text " and stays"
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes checklist second suggestion"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes checklist second"
    assert_frontmost_app "Notes" "Notes checklist"
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Notes checklist full acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"

    sleep 1
    local manual_check_args=(notes-checklist --check)
    if screenshot_trace_requested; then
      manual_check_args+=(--visual)
    fi
    AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
      AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
      AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
      ./script/manual_smoke_session.sh "${manual_check_args[@]}"
    return 0
  fi

  ensure_notes_body_smoke_note
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  assert_notes_body_smoke_target
  type_notes_raw_smoke_text $'\nSmoke proof feels'
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
  assert_notes_body_smoke_target
  type_notes_raw_smoke_text " and stays"
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

  if [[ "$TEXTEDIT_VARIANT" == "fast-typing" ]]; then
    local typing_start_line typing_trace_start_line manual_app
    typing_start_line="$(line_count "$LOG_PATH")"
    typing_trace_start_line="$(line_count "$TRACE_PATH")"
    manual_app="$(textedit_smoke_session_app)"
    ./script/typing_performance_soak.sh \
      --skip-build \
      --characters 1200 \
      --chunk-size 60 \
      --strict-ax \
      --require-ax-samples 5
    AUTOCOMPLETE_LAB_LOG_START_LINE="$typing_start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$typing_trace_start_line" \
    AUTOCOMPLETE_LAB_TEXTEDIT_FAST_TYPING_VERIFIED=1 \
      ./script/manual_smoke_session.sh "$manual_app" --check
    return 0
  fi

  case "$TEXTEDIT_VARIANT" in
    light)
      set_textedit_appearance light
      ;;
    dark)
      set_textedit_appearance dark
      ;;
  esac

  textedit_tmp_dir="$(make_tmp_dir)"
  textedit_file="$textedit_tmp_dir/textedit-smoke-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  textedit_window_title="$(basename "$textedit_file")"
  SMOKE_TEXTEDIT_WINDOW_TITLES+=("$textedit_window_title")
  : >"$textedit_file"
  open_textedit_smoke_document "$textedit_file" "$textedit_window_title"
  sleep 0.8

  case "$TEXTEDIT_VARIANT" in
    long-wrap|narrow)
      set_textedit_window_frame "$textedit_window_title" 120 120 420 420
      sleep 0.3
      ;;
  esac

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

  local first_fragment manual_app
  first_fragment="$(textedit_first_fragment)"
  manual_app="$(textedit_smoke_session_app)"

  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" "$first_fragment" "first typed"

  if [[ "$TEXTEDIT_VARIANT" == "selected-suppression" ]]; then
    set_textedit_selected_range "$textedit_window_title" 0 8
    wait_for_log_pattern "$start_line" "suggestion-blocked .*app=com.apple.TextEdit .*reason=selected-text" "TextEdit selected-text suppression" 12
    AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
      ./script/manual_smoke_session.sh "$manual_app" --check
    return 0
  fi

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.TextEdit" "TextEdit"
  assert_frontmost_app "TextEdit" "TextEdit"
  focus_textedit_smoke_editor "$textedit_window_title"
  local before_one_word_accept_text
  before_one_word_accept_text="$(textedit_document_text "$textedit_window_title")"
  press_key_code 48
  wait_for_log_fields "$start_line" "TextEdit Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.TextEdit .*result=verified" "TextEdit first verified insertion"
  if native_undo_proof_requested; then
    verify_textedit_native_undo "$textedit_window_title" "$before_one_word_accept_text" "$start_line" "TextEdit one-word native undo" "acceptNextWord"
  elif [[ "$TEXTEDIT_VARIANT" != "undo-full" ]]; then
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
  fi
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"
  second_start_line="$(line_count "$LOG_PATH")"

  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" " and stays inst" "second typed"

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.TextEdit" "TextEdit second"
  assert_frontmost_app "TextEdit" "TextEdit"
  focus_textedit_smoke_editor "$textedit_window_title"
  local before_full_accept_text
  before_full_accept_text="$(textedit_document_text "$textedit_window_title")"
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "TextEdit full acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"
  wait_for_log_pattern "$full_start_line" "insert-verification .*app=com.apple.TextEdit .*result=verified" "TextEdit full verified insertion"

  if native_undo_proof_requested; then
    verify_textedit_native_undo "$textedit_window_title" "$before_full_accept_text" "$full_start_line" "TextEdit full native undo" "acceptAllVisible"
  elif [[ "$TEXTEDIT_VARIANT" == "undo-full" ]]; then
    local full_undo_start_line
    full_undo_start_line="$(line_count "$LOG_PATH")"
    osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "z" using command down
end tell
APPLESCRIPT
    wait_for_log_fields "$full_undo_start_line" "TextEdit full-accept undo keyboard action" 8 \
      "keyboard-action" \
      "app=com.apple.TextEdit" \
      "action=undoAcceptedInsertion" \
      "handled=true"
    wait_for_log_fields "$full_undo_start_line" "TextEdit full accepted insertion undo" 8 \
      "accepted-insertion-undone" \
      "app=com.apple.TextEdit"
  fi

  sleep 1
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh "$manual_app" --check
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
  if [[ "$fixture" == "browser-chat-harness" ]]; then
    start_chrome_fixture_http_server "$tmp_dir"
  fi

  local chrome_url
  chrome_url="$(chrome_fixture_url "$fixture" "$html_file")"
  CHROME_CURRENT_FIXTURE_URL="$chrome_url"
  local click_x_offset click_y_offset
  read -r click_x_offset click_y_offset < <(chrome_fixture_click_offsets "$fixture")
  local chrome_pid=""

  echo "Running Chrome fixture: $fixture"

  if chrome_fixture_uses_isolated_accessibility_chrome "$fixture"; then
    CHROME_REMOTE_DEBUGGING_PORT="$(allocate_local_port)"
    launch_isolated_chrome_fixture "$chrome_url" "$tmp_dir"
    chrome_pid="$CHROME_LAST_LAUNCHED_PID"
    wait_for_chrome_expected_tab "$fixture" "$chrome_url" "initial isolated fixture load" "$chrome_pid" 12
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
    focus_default_chrome_smoke_tab "$fixture" "$chrome_url" >/dev/null
  fi

  if [[ -n "$chrome_pid" ]]; then
    wait_for_frontmost_process_id "$chrome_pid" 5
  else
    wait_for_frontmost_app "Google Chrome" 5
  fi
  wait_for_chrome_smoke_ready "$fixture" 20 "$chrome_pid"
  focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"
  require_default_chrome_web_accessibility "$fixture"

  local first_fragment="Smoke proof feels inst"
  local second_fragment=" and stays inst"
  if [[ "$fixture" == "codemirror-official" ]]; then
    first_fragment="Smoke proof feels dicta"
    second_fragment=" and stays dicta"
  fi

  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "first fragment" "$first_fragment"

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.google.Chrome" "Chrome $fixture"
  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture" "" "$chrome_url"
  fi
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  local before_one_word_accept_text
  before_one_word_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
  press_key_code 48
  wait_for_log_fields "$start_line" "Chrome $fixture Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.google.Chrome" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.google.Chrome .*result=verified" "Chrome $fixture first verified insertion"
  if native_undo_proof_requested; then
    verify_chrome_native_undo "$fixture" "$chrome_pid" "$before_one_word_accept_text" "$start_line" "Chrome $fixture one-word native undo" "acceptNextWord"
  fi
  if chrome_fixture_has_chat_no_submit_guard "$fixture"; then
    assert_chrome_chat_safety_counters_zero "$fixture" "Tab acceptance"
  fi
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"

  if ! chrome_fixture_requires_full_accept "$fixture"; then
    sleep 1
    local proof_label
    proof_label="$(chrome_smoke_proof_label "$fixture")"
    AUTOCOMPLETE_LAB_PROMPT_PROOF_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_PROMPT_PROOF_START_LINE="$((trace_start_line + 1))" \
    AUTOCOMPLETE_LAB_PROMPT_PROOF_EXTRA_BUNDLES="com.google.Chrome" \
    AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="$proof_label" \
    AUTOCOMPLETE_LAB_PROMPT_PROOF_REQUIRE_BROWSER_CHAT_SURFACE=1 \
      ./script/check_prompt_app_proof.sh
    AUTOCOMPLETE_LAB_CHROME_FIXTURE="$fixture" \
    AUTOCOMPLETE_LAB_CHROME_ACCESSIBILITY_MODE="$CHROME_ACCESSIBILITY_MODE" \
    AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$proof_label" \
    AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
    AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
    AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
      ./script/manual_smoke_session.sh chrome --check
    return 0
  fi

  second_start_line="$(line_count "$LOG_PATH")"

  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture" "" "$chrome_url"
  fi
  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "second fragment" "$second_fragment"

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.google.Chrome" "Chrome $fixture second"
  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture" "" "$chrome_url"
  fi
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  local before_full_accept_text
  before_full_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "Chrome $fixture full acceptance" 12 \
    "keyboard-action" \
    "app=com.google.Chrome" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"
  wait_for_log_pattern "$full_start_line" "insert-verification .*app=com.google.Chrome .*result=verified" "Chrome $fixture full verified insertion"
  if native_undo_proof_requested; then
    verify_chrome_native_undo "$fixture" "$chrome_pid" "$before_full_accept_text" "$full_start_line" "Chrome $fixture full native undo" "acceptAllVisible"
  fi

  if chrome_fixture_has_chat_no_submit_guard "$fixture"; then
    assert_chrome_chat_safety_counters_zero "$fixture" "full acceptance"
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
  elif [[ "$CHROME_FIXTURE" == "production-text-fields" ]]; then
    run_chrome_fixture textarea-public
    run_chrome_fixture contenteditable-public
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
  codex)
    run_codex
    ;;
  notes)
    run_notes
    ;;
  obsidian)
    run_obsidian
    ;;
  claude-code|claude)
    run_manual_gated
    ;;
esac
