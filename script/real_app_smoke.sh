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
PROOF_DISABLE_FAST_WORD_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=0
PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
PROOF_DISABLE_PHRASE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=0
PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
PROOF_SCENARIO_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_SCENARIO"
PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=0
PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
ACCEPT_ALL_SHORTCUT_DEFAULT_WAS_PREPARED=0
ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS_EXISTS=0
ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS=""
TEXTEDIT_APPEARANCE_WAS_SET=0
TEXTEDIT_PREVIOUS_DARK_MODE=""
CODEX_DRAFT_BACKUP_PATH=""
CODEX_DRAFT_BACKUP_ACTIVE=0
SMOKE_PHASE="startup"

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|textedit-light|textedit-dark|textedit-long-wrap|textedit-wrapped|textedit-narrow|textedit-scrolled|textedit-selected-suppression|textedit-undo-one-word|textedit-undo-full|textedit-fast-typing|textedit-model-latency|chrome|notes-title|notes-title-short|notes-title-long|notes-body|notes-body-short|notes-body-long|notes-checklist|notes-checklist-checked|notes-checklist-long|notes-title-undo|notes-body-undo|notes-checklist-undo|notes|obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on|codex|claude-code|claude-code-terminal|claude-code-iterm2|claude-code-warp|claude-code-ghostty|claude-code-kitty|claude-code-alacritty|claude-code-wezterm|claude|claude-empty|claude-long|claude-wrapped|claude-narrow|claude-context|claude-light|claude-dark> [--dry-run] [--manual-gate] [--skip-build] [--native-undo-proof] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|google-docs|notion|browser-chatgpt|browser-slack|browser-discord|all>] [--chrome-accessibility <forced|default>] [--include-default-real-editor-proof] [--host <terminal|iterm2|warp|ghostty|kitty|alacritty|wezterm|auto>]

Runs a real app smoke pass where it is safe to automate. Notes title/body/
checklist proof has guarded disposable-note drivers; Obsidian, Codex,
Claude Code, and Claude desktop are manual-gated so this script never types
into private notes, vaults, terminal prompts, or agent prompts by surprise.
The Codex lane uses a targeted disposable proof helper after the manual gate:
it seeds AUTOCOMPLETE_LAB_CODEX_PROOF text into a safe composer, presses Tab
once, and never presses Enter.

Notes proof must use notes-title, notes-body, notes-checklist, their
notes-*-undo variants, or explicit Notes variant lanes such as
notes-title-short, notes-title-long, notes-body-short, notes-body-long,
notes-checklist-checked, and notes-checklist-long. A generic notes run only
prints the surface picker and does not record proof.

TextEdit proof can use textedit-light, textedit-dark, textedit-long-wrap,
textedit-narrow, textedit-scrolled, textedit-selected-suppression, textedit-undo-one-word,
textedit-undo-full, textedit-fast-typing, or textedit-model-latency. These are
still narrow TextEdit lanes, not a generic native-app claim. The TextEdit undo
lanes automatically use native single-edit Command-Z proof.

Obsidian proof must keep default, theme, pane, long-note, font-zoom,
markdown-bold, markdown-list, multiline, and run-on lanes separate before it can
be complete.

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
The google-docs, notion, browser-chatgpt, browser-slack, and browser-discord
fixtures are blocked preflight labels: they document the next high-value
surfaces but refuse to type until a safe disposable proof path exists.
Use
--fixture all to run every local Chrome browser/editor fixture with one app
build. Add --include-default-real-editor-proof with --fixture all to rerun real
Monaco and ProseMirror in default Chrome AX mode after the forced lane.

Claude Code is proof-only through supported terminal hosts. Use --host or the
claude-code-<host> aliases to record host-specific proof labels without enabling
normal terminal suggestions.

--skip-build reuses the already-running AutocompleteLab app. It fails closed unless
the only running SteadyType process is this checkout's dist/SteadyType.app binary
and that process already has any proof-mode environment needed by the smoke pass.
The textedit-model-latency lane does not allow --skip-build because it must
relaunch SteadyType with fast word completions disabled before sampling.

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
  textedit-scrolled)
    APP="textedit"
    TEXTEDIT_VARIANT="scrolled"
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
  textedit-model-latency)
    APP="textedit"
    TEXTEDIT_VARIANT="model-latency"
    ;;
  notes-title)
    APP="notes"
    NOTES_SESSION_APP="notes-title"
    ;;
  notes-title-short)
    APP="notes"
    NOTES_SESSION_APP="notes-title-short"
    ;;
  notes-title-long)
    APP="notes"
    NOTES_SESSION_APP="notes-title-long"
    ;;
  notes-title-undo)
    APP="notes"
    NOTES_SESSION_APP="notes-title-undo"
    ;;
  notes-body)
    APP="notes"
    NOTES_SESSION_APP="notes-body"
    ;;
  notes-body-short)
    APP="notes"
    NOTES_SESSION_APP="notes-body-short"
    ;;
  notes-body-long)
    APP="notes"
    NOTES_SESSION_APP="notes-body-long"
    ;;
  notes-body-undo)
    APP="notes"
    NOTES_SESSION_APP="notes-body-undo"
    ;;
  notes-checklist)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist"
    ;;
  notes-checklist-checked)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist-checked"
    ;;
  notes-checklist-long)
    APP="notes"
    NOTES_SESSION_APP="notes-checklist-long"
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
  obsidian-font-zoom)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-font-zoom"
    ;;
  obsidian-markdown-bold)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-markdown-bold"
    ;;
  obsidian-markdown-list)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-markdown-list"
    ;;
  obsidian-multiline)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-multiline"
    ;;
  obsidian-run-on)
    APP="obsidian"
    OBSIDIAN_SESSION_APP="obsidian-run-on"
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
  textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|google-docs|notion|browser-chatgpt|browser-slack|browser-discord|all)
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

if [[ "$APP" == "textedit" && "$TEXTEDIT_VARIANT" == "model-latency" && "$SKIP_BUILD" == "1" ]]; then
  echo "textedit-model-latency cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$NATIVE_UNDO_PROOF" =~ ^(1|true|yes|on)$ && "$APP" != "textedit" && "$APP" != "chrome" ]]; then
  echo "--native-undo-proof is currently automated only for TextEdit and Chrome." >&2
  usage >&2
  exit 2
fi

LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.steadytype}"
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
SMOKE_INTERFERENCE_GUARD_PID=""
SMOKE_INTERFERENCE_GUARD_POLL_SECONDS="${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_POLL_SECONDS:-0.5}"
SMOKE_SCRIPT_PID="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_SELF_PID:-${BASHPID:-$$}}"

if [[ ! "$SMOKE_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS must be a non-negative integer." >&2
  exit 2
fi

if [[ ! "$SMOKE_INTERFERENCE_GUARD_POLL_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_POLL_SECONDS must be a non-negative number." >&2
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
    osascript "${SMOKE_TEXTEDIT_WINDOW_TITLES[@]}" <<'APPLESCRIPT' >/dev/null 2>&1 &
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
    local osascript_pid="$!"
    wait_for_background_process "$osascript_pid" 4 "TextEdit smoke cleanup" >/dev/null 2>&1 || true
  fi
}

cleanup_stale_textedit_smoke_windows() {
  dismiss_textedit_modal_panels
  osascript <<'APPLESCRIPT' >/dev/null 2>&1 &
on run argv
  tell application "TextEdit"
    repeat with docRef in documents
      try
        set docName to name of docRef
        if docName starts with "textedit-smoke-" or docName starts with "textedit-model-latency-" or docName starts with "autocomplete-lab-typing-soak-" or docName starts with "textedit-ax-retention-proof." or docName starts with "textedit-retention-proof." then
          close docRef saving no
        end if
      end try
    end repeat
  end tell
end run
APPLESCRIPT
  local osascript_pid="$!"
  wait_for_background_process "$osascript_pid" 4 "stale TextEdit smoke cleanup" >/dev/null 2>&1 || true
  force_quit_textedit_if_only_smoke_windows
}

dismiss_textedit_modal_panels() {
  run_osascript_with_timeout 2 "TextEdit modal cleanup" <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  if exists process "TextEdit" then
    tell process "TextEdit"
      repeat with windowRef in windows
        try
          set windowName to name of windowRef
          set windowSubrole to subrole of windowRef
          if windowName is "Open" or windowSubrole is "AXDialog" then
            key code 53
            delay 0.1
            exit repeat
          end if
        end try
      end repeat
    end tell
  end if
end tell
APPLESCRIPT
}

force_quit_textedit_if_only_smoke_windows() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let smokePrefixes = [
    "textedit-smoke-",
    "textedit-model-latency-",
    "autocomplete-lab-typing-soak-",
    "textedit-ax-retention-proof.",
    "textedit-retention-proof."
]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

let textEditApps = NSWorkspace.shared.runningApplications.filter {
    $0.bundleIdentifier == "com.apple.TextEdit"
}

for app in textEditApps {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement],
          !windows.isEmpty else {
        continue
    }

    let titles = windows.compactMap { copyAttribute($0, kAXTitleAttribute) as? String }
    guard !titles.isEmpty,
          titles.allSatisfy({ title in smokePrefixes.contains { title.hasPrefix($0) } }) else {
        continue
    }

    app.forceTerminate()
}
SWIFT
}

cleanup_smoke() {
  if [[ -n "$SMOKE_INTERFERENCE_GUARD_PID" ]]; then
    kill "$SMOKE_INTERFERENCE_GUARD_PID" >/dev/null 2>&1 || true
    wait "$SMOKE_INTERFERENCE_GUARD_PID" >/dev/null 2>&1 || true
    SMOKE_INTERFERENCE_GUARD_PID=""
  fi

  cleanup_smoke_textedit_windows
  restore_codex_draft_if_needed
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

  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_DISABLE_PHRASE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$ACCEPT_ALL_SHORTCUT_DEFAULT_WAS_PREPARED" == "1" ]]; then
    if [[ "$ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS_EXISTS" == "1" ]]; then
      defaults write "$DEFAULTS_DOMAIN" AcceptAllShortcut "$ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS" >/dev/null 2>&1 || true
    else
      defaults delete "$DEFAULTS_DOMAIN" AcceptAllShortcut >/dev/null 2>&1 || true
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

diagnose_smoke_signal() {
  local signal_name="$1"
  echo "real_app_smoke received $signal_name during phase: $SMOKE_PHASE" >&2
  echo "Smoke lock: $SMOKE_LOCK_DIR" >&2
  echo "Running SteadyType processes:" >&2
  ps ax -o pid=,ppid=,pgid=,etime=,command= 2>/dev/null |
    awk '$0 ~ /\/SteadyType\.app\/Contents\/MacOS\/SteadyType([[:space:]]|$)/ { print }' >&2
  echo "Tracked TextEdit smoke windows: ${SMOKE_TEXTEDIT_WINDOW_TITLES[*]:-none}" >&2
  if [[ -f "$LOG_PATH" ]]; then
    echo "Last diagnostics line:" >&2
    tail -n 1 "$LOG_PATH" >&2 || true
  fi
}

handle_smoke_term() {
  diagnose_smoke_signal "SIGTERM"
  exit 143
}

trap handle_smoke_term TERM

acquire_smoke_lock() {
  local deadline=$((SECONDS + SMOKE_LOCK_WAIT_SECONDS))
  local announced=0

  while true; do
    if mkdir "$SMOKE_LOCK_DIR" >/dev/null 2>&1; then
      SMOKE_LOCK_HELD=1
      echo "$SMOKE_SCRIPT_PID" >"$SMOKE_LOCK_DIR/pid"
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
  current_pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d ' ' || true)"
  if [[ "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST+x}" == "x" ]]; then
    process_list="$AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST"
  else
    process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"
  fi

  awk -v self="$SMOKE_SCRIPT_PID" -v selfPGID="$current_pgid" '
    {
      pid = $1
      pgid = $3
      command = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      directScript = command ~ /^(\.\/)?script\/(real_app_smoke|fresh_latency_proof|smoke_test|build_and_run)\.sh([[:space:]]|$)/
      shellWrapper = command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?(bash|zsh)|\/usr\/bin\/env[[:space:]]+(bash|zsh))([[:space:]]|$)/
      hasSmokeScript = index(command, "script/real_app_smoke.sh") > 0 ||
        index(command, "script/fresh_latency_proof.sh") > 0 ||
        index(command, "script/smoke_test.sh") > 0 ||
        index(command, "script/build_and_run.sh") > 0
      if (pid == self) next
      if (selfPGID != "" && pgid == selfPGID) next
      if (directScript || (shellWrapper && hasSmokeScript)) {
        print
      }
    }
  ' <<<"$process_list"
}

other_autocomplete_proof_pgids() {
  local process_list current_pgid
  current_pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d ' ' || true)"
  [[ -z "$current_pgid" ]] && return 0
  process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"

  awk -v self="$SMOKE_SCRIPT_PID" -v selfPGID="$current_pgid" '
    {
      pid = $1
      pgid = $3
      command = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      directScript = command ~ /^(\.\/)?script\/(real_app_smoke|fresh_latency_proof|obsidian_deep_sweep|build_and_run)\.sh([[:space:]]|$)/
      shellWrapper = command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?(bash|zsh)|\/usr\/bin\/env[[:space:]]+(bash|zsh))([[:space:]]|$)/
      hasProofScript = index(command, "script/real_app_smoke.sh") > 0 ||
        index(command, "script/fresh_latency_proof.sh") > 0 ||
        index(command, "script/obsidian_deep_sweep.sh") > 0 ||
        index(command, "script/build_and_run.sh") > 0
      if (pid == self) next
      if (selfPGID != "" && pgid == selfPGID) next
      if (directScript || (shellWrapper && hasProofScript)) {
        print pgid
      }
    }
  ' <<<"$process_list" | sort -u
}

terminate_other_autocomplete_proof_runs() {
  local pgid
  while IFS= read -r pgid; do
    [[ -z "$pgid" ]] && continue
    kill -TERM "-$pgid" >/dev/null 2>&1 || true
  done < <(other_autocomplete_proof_pgids)
}

start_smoke_interference_guard() {
  if [[ ! "${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi

  terminate_other_autocomplete_proof_runs
  (
    while kill -0 "$SMOKE_SCRIPT_PID" >/dev/null 2>&1; do
      terminate_other_autocomplete_proof_runs
      sleep "$SMOKE_INTERFERENCE_GUARD_POLL_SECONDS"
    done
  ) &
  SMOKE_INTERFERENCE_GUARD_PID="$!"
}

refuse_other_smoke_processes() {
  local deadline=$((SECONDS + SMOKE_LOCK_WAIT_SECONDS))
  local announced=0
  local processes

  while true; do
    if [[ "${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-0}" =~ ^(1|true|yes|on)$ ]]; then
      terminate_other_autocomplete_proof_runs
      sleep "$SMOKE_INTERFERENCE_GUARD_POLL_SECONDS"
    fi

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

log_since_matches() {
  local start_line="$1"
  local pattern="$2"

  [[ -f "$LOG_PATH" ]] || return 1
  awk -v start="$start_line" -v pattern="$pattern" '
    NR > start && $0 ~ pattern {
      found = 1
      exit
    }
    END {
      if (found) {
        exit 0
      }
      exit 1
    }
  ' "$LOG_PATH" 2>/dev/null
}

wait_for_log_pattern() {
  local start_line="$1"
  local pattern="$2"
  local label="$3"
  local timeout_seconds="${4:-12}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_matches "$start_line" "$pattern"; then
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

wait_for_log_fields_optional() {
  local start_line="$1"
  local timeout_seconds="$2"
  local prefix="$3"
  shift 3
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

  return 1
}

wait_for_textedit_acceptance_with_stale_retry() {
  local start_line="$1"
  local label="$2"
  local key_name="$3"
  local action_name="$4"
  local window_title="$5"
  local attempt attempt_start

  for attempt in 1 2 3; do
    attempt_start="$(line_count "$LOG_PATH")"
    case "$action_name" in
      acceptNextWord)
        press_key_code 48
        ;;
      acceptAllVisible)
        press_accept_all_shortcut
        ;;
      *)
        echo "unknown TextEdit acceptance action: $action_name" >&2
        exit 2
        ;;
    esac

    if wait_for_log_fields_optional "$attempt_start" 4 \
      "keyboard-action" \
      "app=com.apple.TextEdit" \
      "key=$key_name" \
      "action=$action_name" \
      "handled=true"; then
      return 0
    fi

    if wait_for_log_fields_optional "$attempt_start" 1 \
      "keyboard-action" \
      "app=com.apple.TextEdit" \
      "key=$key_name" \
      "action=$action_name" \
      "handled=false" \
      "reason=text-before-cursor-changed-before-accept"; then
      wait_for_log_pattern "$attempt_start" "suggestion-presented .*app=com.apple.TextEdit" "$label refreshed suggestion" 12
      wait_for_screenshot_capture_if_enabled "$attempt_start" "com.apple.TextEdit" "$label refreshed"
      focus_textedit_smoke_editor "$window_title"
      assert_textedit_frontmost_window "$window_title" "$label refreshed"
      continue
    fi

    if wait_for_log_fields_optional "$attempt_start" 1 \
      "keyboard-action" \
      "app=com.apple.TextEdit" \
      "key=$key_name" \
      "action=$action_name" \
      "handled=false" \
      "reason=text-after-cursor-changed-before-accept"; then
      wait_for_log_pattern "$attempt_start" "suggestion-presented .*app=com.apple.TextEdit" "$label refreshed suggestion" 12
      wait_for_screenshot_capture_if_enabled "$attempt_start" "com.apple.TextEdit" "$label refreshed"
      focus_textedit_smoke_editor "$window_title"
      assert_textedit_frontmost_window "$window_title" "$label refreshed"
      continue
    fi
  done

  wait_for_log_fields "$start_line" "$label" 1 \
    "keyboard-action" \
    "app=com.apple.TextEdit" \
    "key=$key_name" \
    "action=$action_name" \
    "handled=true"
}

latest_runtime_is_ready() {
  local latest_runtime_line
  latest_runtime_line="$(grep -E " runtime .*readinessStage=" "$LOG_PATH" 2>/dev/null | tail -n 1 || true)"
  [[ "$latest_runtime_line" == *"readinessStage=ready"* ]]
}

latest_accessibility_is_ready() {
  local latest_accessibility_line
  latest_accessibility_line="$(
    grep -E "launch accessibility=(true|trusted)|status .*accessibility=AX ok" "$LOG_PATH" 2>/dev/null |
      tail -n 1 || true
  )"
  [[ -n "$latest_accessibility_line" ]]
}

wait_for_accessibility_ready() {
  local start_line="$1"
  local label="${2:-Accessibility readiness}"
  local timeout_seconds="${3:-20}"
  local allow_existing_ready="${4:-0}"
  local deadline=$((SECONDS + timeout_seconds))
  local saw_missing=0

  while ((SECONDS <= deadline)); do
    if log_since_matches "$start_line" "launch accessibility=(true|trusted)|status .*accessibility=AX ok"; then
      return 0
    fi

    if [[ "$allow_existing_ready" == "1" ]] && latest_accessibility_is_ready; then
      return 0
    fi

    if log_since_matches "$start_line" "launch accessibility=false|status .*accessibility=AX missing"; then
      saw_missing=1
    fi

    sleep 0.2
  done

  echo "Timed out waiting for $label." >&2
  echo "Pattern: launch accessibility=true or status accessibility=AX ok" >&2
  if [[ "$saw_missing" == "1" ]]; then
    echo "SteadyType Accessibility permission is missing. Enable SteadyType in System Settings > Privacy & Security > Accessibility, then rerun this smoke lane." >&2
  fi
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

wait_for_runtime_ready() {
  local start_line="$1"
  local label="${2:-runtime ready}"
  local timeout_seconds="${3:-60}"
  local allow_existing_ready="${4:-0}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_matches "$start_line" " runtime .*readinessStage=ready"; then
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

textedit_model_latency_runtime_ready_timeout_seconds() {
  if [[ -n "${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_RUNTIME_READY_TIMEOUT_SECONDS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_RUNTIME_READY_TIMEOUT_SECONDS"
    return 0
  fi

  printf '180\n'
}

chrome_runtime_ready_timeout_seconds() {
  if [[ -n "${AUTOCOMPLETE_LAB_RUNTIME_READY_TIMEOUT_SECONDS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_RUNTIME_READY_TIMEOUT_SECONDS"
    return 0
  fi

  if chrome_fixture_is_official_demo "$CHROME_FIXTURE" && ! chrome_fixture_is_public_text_field_demo "$CHROME_FIXTURE"; then
    printf '180\n'
    return 0
  fi

  printf '60\n'
}

wait_for_frontmost_app() {
  local expected="$1"
  local timeout_seconds="${2:-5}"

  if try_wait_for_frontmost_app "$expected" "$timeout_seconds"; then
    return 0
  fi

  echo "Timed out waiting for $expected to become frontmost." >&2
  exit 1
}

try_wait_for_frontmost_app() {
  local expected="$1"
  local timeout_seconds="${2:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local frontmost
    frontmost="$(run_osascript_with_timeout 1 "frontmost app wait probe" -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
    if [[ "$frontmost" == "$expected" ]]; then
      return 0
    fi
    sleep 0.2
  done

  return 1
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

run_osascript_with_timeout() {
  local timeout_seconds="$1"
  local label="$2"
  shift 2

  local run_dir stdout_path stderr_path status
  run_dir="$(make_tmp_dir)"
  stdout_path="$run_dir/osascript-stdout.txt"
  stderr_path="$run_dir/osascript-stderr.txt"

  osascript "$@" >"$stdout_path" 2>"$stderr_path" &
  local osascript_pid="$!"
  if wait_for_background_process "$osascript_pid" "$timeout_seconds" "$label"; then
    cat "$stdout_path"
    return 0
  fi

  status=$?
  return "$status"
}

activate_process_id() {
  local target_pid="$1"

  local swift_activation_pid
  {
    swift - "$target_pid" <<'SWIFT' >/dev/null
import AppKit

guard CommandLine.arguments.count == 2,
      let rawPID = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid_t(rawPID)) else {
    exit(1)
}

app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
SWIFT
  } &
  swift_activation_pid="$!"
  wait_for_background_process "$swift_activation_pid" 2 "Swift activation for pid $target_pid" >/dev/null 2>&1 || true

  if [[ "${AUTOCOMPLETE_LAB_SKIP_SYSTEM_EVENTS_PROCESS_ACTIVATION:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi

  activate_process_id_osascript "$target_pid" &
  local osascript_pid="$!"
  wait_for_background_process "$osascript_pid" 2 "System Events process activation" >/dev/null 2>&1 || true
}

activate_process_id_osascript() {
  local target_pid="$1"

  osascript - "$target_pid" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
  set targetPID to (item 1 of argv) as integer
  tell application "System Events"
    repeat with procRef in application processes
      try
        if unix id of procRef is targetPID then
          set frontmost of procRef to true
          return
        end if
      end try
    end repeat
  end tell
end run
APPLESCRIPT
  activation_pid="$!"
  wait_for_background_process "$activation_pid" 2 "System Events activation for pid $target_pid" >/dev/null 2>&1 || true
}

assert_frontmost_app() {
  local expected="$1"
  local label="$2"
  local frontmost
  frontmost="$(run_osascript_with_timeout 2 "frontmost app assertion probe" -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
  if [[ "$frontmost" != "$expected" ]]; then
    echo "$label lost focus before accept. Expected frontmost app '$expected', got '${frontmost:-unknown}'." >&2
    exit 1
  fi
}

activate_app_by_process_name() {
  local process_name="$1"

  swift - "$process_name" <<'SWIFT' >/dev/null 2>&1 || true
import AppKit

guard CommandLine.arguments.count == 2 else {
    exit(1)
}

let processName = CommandLine.arguments[1]
guard let app = NSWorkspace.shared.runningApplications.first(where: {
    $0.localizedName == processName || $0.bundleURL?.lastPathComponent == "\(processName).app"
}) else {
    exit(1)
}

app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
SWIFT

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
  prepare_accept_all_shortcut_default

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

prepare_accept_all_shortcut_default() {
  local configured="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-}"
  case "$configured" in
    "")
      return 0
      ;;
    backtick|optionTab)
      ;;
    *)
      echo "Unknown accept-all shortcut '$configured'; expected backtick or optionTab." >&2
      exit 2
      ;;
  esac

  if [[ "$ACCEPT_ALL_SHORTCUT_DEFAULT_WAS_PREPARED" != "1" ]]; then
    if ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS="$(defaults read "$DEFAULTS_DOMAIN" AcceptAllShortcut 2>/dev/null)"; then
      ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS_EXISTS=1
    else
      ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS_EXISTS=0
      ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS=""
    fi
    ACCEPT_ALL_SHORTCUT_DEFAULT_WAS_PREPARED=1
  fi

  defaults write "$DEFAULTS_DOMAIN" AcceptAllShortcut "$configured" >/dev/null 2>&1 || true
  echo "Temporary smoke whole-suggestion shortcut: $configured"
}

prepare_model_latency_runtime_options() {
  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" 2>/dev/null || true)"
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-model-latency"
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "textedit-model-latency" >/dev/null 2>&1 || true
  echo "TextEdit model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "TextEdit model latency proof scenario: textedit-model-latency"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so model-latency proof mode only applies if the app was launched with this environment." >&2
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
    notes-title|notes-title-short|notes-title-long|notes-body|notes-body-short|notes-body-long|notes-checklist|notes-checklist-checked|notes-checklist-long|notes-title-undo|notes-body-undo|notes-checklist-undo)
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
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-short --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-long --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-short --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-long --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-checked --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-long --manual-gate
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
    obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on)
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
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-font-zoom --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-markdown-bold --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-markdown-list --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-multiline --manual-gate
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-run-on --manual-gate
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

  case "$manual_app" in
    obsidian-markdown-bold)
      printf '%s\n\n**' "$marker"
      return 0
      ;;
    obsidian-markdown-list)
      printf '%s\n\n**Bold context line**\n\n- ' "$marker"
      return 0
      ;;
    obsidian-multiline)
      printf '%s\n\n\n' "$marker"
      return 0
      ;;
    obsidian-run-on)
      printf '%s\n\nThis deliberately long Obsidian run on sentence keeps moving across the editor so wrapping, scrolling, and caret geometry have to stay calm before the proof line appears ' "$marker"
      return 0
      ;;
  esac

  printf '%s\n' "$marker"
}

obsidian_marker_text_area_count() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "Autocomplete Lab Obsidian proof"
let normalizedMarker = marker
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")

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
    let normalizedValue = value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    var count = (role == kAXTextAreaRole as String && normalizedValue.contains(normalizedMarker)) ? 1 : 0
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

restore_obsidian_single_pane_if_needed() {
  activate_obsidian_for_smoke

  local pane_count attempt
  pane_count="$(obsidian_marker_text_area_count 2>/dev/null || echo 0)"
  attempt=0
  while (( pane_count > 1 && attempt < 4 )); do
    osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  tell application process "Obsidian"
    set frontmost to true
    key code 13 using command down
  end tell
end tell
APPLESCRIPT
    sleep 0.5
    activate_obsidian_for_smoke
    pane_count="$(obsidian_marker_text_area_count 2>/dev/null || echo 0)"
    attempt=$((attempt + 1))
  done
}

set_obsidian_zoom_for_font_proof() {
  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  key code 29 using command down
  delay 0.1
  key code 24 using command down
  delay 0.1
  key code 24 using command down
end tell
APPLESCRIPT
  sleep 0.4
}

restore_obsidian_zoom_after_font_proof() {
  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  key code 29 using command down
end tell
APPLESCRIPT
  sleep 0.2
}

prepare_obsidian_variant_state() {
  local manual_app="$1"

  case "$manual_app" in
    obsidian-pane)
      prepare_obsidian_pane_variant_if_needed
      focus_obsidian_visible_tail_line
      set_obsidian_caret_to_value_end
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
    obsidian-font-zoom)
      if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_FONT_ZOOM_APPLIED:-0}" != "1" ]]; then
        export AUTOCOMPLETE_LAB_OBSIDIAN_FONT_ZOOM_APPLIED=1
        set_obsidian_zoom_for_font_proof
      else
        activate_obsidian_for_smoke
      fi
      move_obsidian_caret_to_document_end
      ;;
    obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on)
      activate_obsidian_for_smoke
      case "$manual_app" in
        obsidian-markdown-list|obsidian-run-on)
          move_obsidian_caret_to_document_end
          ;;
        obsidian-multiline)
          set_obsidian_caret_to_value_end
          ;;
      esac
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

chrome_fixture_is_blocked_high_value_surface() {
  case "$1" in
    google-docs|notion|browser-chatgpt|browser-slack|browser-discord)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_blocked_high_value_surface_reason() {
  case "$1" in
    google-docs)
      printf 'Google Docs is blocked until a disposable document proves placement, safe Tab, insertion verification, undo/recovery, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
      ;;
    notion)
      printf 'Notion is blocked until a disposable page proves ProseMirror placement, safe Tab, insertion verification, undo/recovery, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
      ;;
    browser-chatgpt)
      printf 'Browser ChatGPT is blocked until a disposable prompt proves one-word Tab accept, no submit/send, insertion verification, undo/recovery, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
      ;;
    browser-slack)
      printf 'Browser Slack is blocked until a disposable workspace/channel proves one-word Tab accept, no send, insertion verification, undo/recovery, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
      ;;
    browser-discord)
      printf 'Browser Discord is blocked until a disposable server/channel proves one-word Tab accept, no send, insertion verification, undo/recovery, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
      ;;
  esac
}

chrome_fixture_is_official_rich_editor_demo() {
  case "$1" in
    codemirror-official|monaco-official|prosemirror-official)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_fixture_requires_ax_readable_setup() {
  case "$1" in
    monaco-official)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

chrome_fixture_requires_default_ax_official_focus() {
  [[ "$CHROME_ACCESSIBILITY_MODE" == "default" && "$1" == "monaco-official" ]]
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
      printf '%s\n' "https://codemirror.net/try/#c=U21va2UgcHJvb2YgZmVlbHMgaW5zdA=="
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

    if [[ -n "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
      while ((SECONDS <= deadline)); do
        local ready
        ready="$(chrome_official_demo_ready_with_devtools "$fixture" | tr -d '[:space:]')"
        if [[ "$ready" == "true" ]]; then
          return 0
        fi
        sleep 0.3
      done

      echo "Timed out waiting for Chrome $fixture official demo readiness through DevTools." >&2
      exit 1
    fi

    if chrome_fixture_requires_default_ax_official_focus "$fixture"; then
      while ((SECONDS <= deadline)); do
        if chrome_focus_official_demo_editor_with_ax "$fixture" "$chrome_pid" >/dev/null 2>&1; then
          return 0
        fi
        sleep 0.3
      done

      echo "Chrome $fixture default-AX proof could not focus the official editor through macOS Accessibility." >&2
      echo "No Chrome typing was attempted. This lane needs normal Chrome to expose the Monaco editor as a focused AXTextArea/AXTextField before it can claim default AX proof." >&2
      echo "Use the isolated forced-renderer lane for current Monaco proof, or rerun after Chrome exposes page editor AX content." >&2
      exit 1
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

chrome_official_demo_devtools_action() {
  local fixture="$1"
  local mode="$2"
  local text="${3:-}"

  if [[ -z "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
    return 1
  fi

  node - "$CHROME_REMOTE_DEBUGGING_PORT" "$fixture" "$mode" "$text" <<'NODE'
const port = process.argv[2];
const fixture = process.argv[3];
const mode = process.argv[4];
const text = process.argv[5] || "";

const urlMarkers = new Map([
  ["codemirror-official", "codemirror.net/try"],
  ["monaco-official", "microsoft.github.io/monaco-editor/playground"],
  ["prosemirror-official", "prosemirror.net/examples/basic"],
]);

async function fetchJSON(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  return response.json();
}

async function tabWebSocketURL() {
  const marker = urlMarkers.get(fixture) || "";
  const deadline = Date.now() + 10000;
  while (Date.now() <= deadline) {
    try {
      const tabs = await fetchJSON(`http://127.0.0.1:${port}/json`);
      const pages = tabs.filter((tab) => tab.type === "page" && !String(tab.url || "").startsWith("devtools://"));
      const page = pages.find((tab) => String(tab.url || "").includes(marker)) || pages[0];
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

function readyExpression() {
  switch (fixture) {
    case "codemirror-official":
      return `Boolean(document.querySelector('.cm-content'))`;
    case "monaco-official":
      return `Boolean(document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea'))`;
    case "prosemirror-official":
      return `Boolean(document.querySelector('.ProseMirror'))`;
    default:
      return `false`;
  }
}

function focusExpression() {
  switch (fixture) {
    case "codemirror-official":
      return `(() => {
        const editor = document.querySelector('.cm-content');
        if (!editor) return { ok: false, reason: 'missing codemirror editor' };
        editor.setAttribute('aria-label', 'Official CodeMirror proof editor');
        editor.scrollIntoView({ block: 'center', inline: 'center' });
        editor.focus();
        return { ok: true, role: 'codemirror' };
      })()`;
    case "monaco-official":
      return `(() => {
        const input = document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea');
        const editor = document.querySelector('.monaco-editor');
        if (!input || !editor) return { ok: false, reason: 'missing monaco editor' };
        input.setAttribute('aria-label', 'Official Monaco proof editor');
        editor.scrollIntoView({ block: 'center', inline: 'center' });
        input.focus();
        return { ok: true, role: 'monaco' };
      })()`;
    case "prosemirror-official":
      return `(() => {
        const editor = document.querySelector('.ProseMirror');
        if (!editor) return { ok: false, reason: 'missing prosemirror editor' };
        editor.setAttribute('aria-label', 'Official ProseMirror proof editor');
        editor.scrollIntoView({ block: 'center', inline: 'center' });
        editor.focus();
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(editor);
        range.collapse(false);
        selection.removeAllRanges();
        selection.addRange(range);
        return { ok: true, role: 'prosemirror' };
      })()`;
    default:
      return `({ ok: false, reason: 'unsupported fixture' })`;
  }
}

function readExpression() {
  const encodedText = JSON.stringify(text);
  switch (fixture) {
    case "codemirror-official":
      return `(() => {
        const editor = document.querySelector('.cm-content');
        const value = String(editor?.textContent || '');
        return { ok: value.includes(${encodedText}), role: 'codemirror', valueLength: value.length };
      })()`;
    case "monaco-official":
      return `(() => {
        const expected = ${encodedText};
        const modelValue = Array.from((window.monaco?.editor?.getModels?.() || []))
          .map((model) => String(model.getValue?.() || ''))
          .join('\\n');
        const visibleValue = String(document.querySelector('.monaco-editor .view-lines')?.textContent || '');
        const inputValue = String((document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea'))?.value || '');
        const value = [modelValue, visibleValue, inputValue].join('\\n');
        return { ok: value.includes(expected), role: 'monaco', valueLength: value.length };
      })()`;
    case "prosemirror-official":
      return `(() => {
        const editor = document.querySelector('.ProseMirror');
        const value = String(editor?.textContent || '');
        return { ok: value.includes(${encodedText}), role: 'prosemirror', valueLength: value.length };
      })()`;
    default:
      return `({ ok: false, reason: 'unsupported fixture' })`;
  }
}

async function withSocket(wsURL, callback) {
  const socket = new WebSocket(wsURL);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  let nextID = 1;
  function send(method, params = {}) {
    const id = nextID++;
    const responsePromise = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error(`Timed out waiting for ${method}.`)), 10000);
      const handler = (event) => {
        const message = JSON.parse(event.data);
        if (message.id !== id) return;
        clearTimeout(timeout);
        socket.removeEventListener("message", handler);
        resolve(message);
      };
      socket.addEventListener("message", handler);
    });
    socket.send(JSON.stringify({ id, method, params }));
    return responsePromise;
  }

  try {
    return await callback(send);
  } finally {
    socket.close();
  }
}

function valueFromEvaluate(message) {
  if (message.error) {
    throw new Error(message.error.message || "Runtime.evaluate failed.");
  }
  if (message.result?.exceptionDetails) {
    throw new Error(message.result.exceptionDetails.text || "Runtime.evaluate exception.");
  }
  return message.result?.result?.value;
}

async function evaluate(send, expression) {
  return valueFromEvaluate(await send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  }));
}

async function dispatchEndKey(send) {
  for (const type of ["keyDown", "keyUp"]) {
    await send("Input.dispatchKeyEvent", {
      type,
      key: "End",
      code: "End",
      windowsVirtualKeyCode: 35,
      nativeVirtualKeyCode: 0,
    });
  }
}

try {
  const wsURL = await tabWebSocketURL();
  const result = await withSocket(wsURL, async (send) => {
    if (mode === "ready") {
      return Boolean(await evaluate(send, readyExpression()));
    }

    if (mode === "contains") {
      const value = await evaluate(send, readExpression());
      return Boolean(value?.ok);
    }

    const focused = await evaluate(send, focusExpression());
    if (!focused?.ok) {
      return { ok: false, reason: focused?.reason || "focus failed" };
    }

    if (mode === "focus") {
      return { ok: true, role: focused.role || "official" };
    }

    if (mode === "insert") {
      if (fixture === "codemirror-official") {
        await dispatchEndKey(send);
        await new Promise((resolve) => setTimeout(resolve, 100));
        const current = await evaluate(send, readExpression());
        if (current?.ok) {
          return { ok: true, role: current.role || "codemirror", valueLength: current.valueLength || 0 };
        }

        await send("Input.insertText", { text });
        await dispatchEndKey(send);
        await new Promise((resolve) => setTimeout(resolve, 250));
        const value = await evaluate(send, readExpression());
        if (!value?.ok) {
          return { ok: false, reason: "codemirror text not observed", role: value?.role || "codemirror", valueLength: value?.valueLength || 0 };
        }
        return { ok: true, role: value.role || "codemirror", valueLength: value.valueLength || 0 };
      }

      if (fixture === "monaco-official") {
        const encodedText = JSON.stringify(text);
        const value = await evaluate(send, `(() => {
          const text = ${encodedText};
          const editors = Array.from(window.monaco?.editor?.getEditors?.() || [])
            .filter((editor) => editor?.getModel?.());
          const editor = editors[0];
          if (!editor) return { ok: false, reason: 'missing monaco editor instance' };
          const model = editor.getModel();
          const nextText = text.startsWith(' ') ? String(model.getValue()) + text : text;
          editor.setValue(nextText);
          const position = model.getPositionAt(nextText.length);
          editor.setPosition(position);
          editor.focus();
          const input = document.querySelector('.monaco-editor textarea') || document.querySelector('.monaco-editor .inputarea');
          if (input) {
            input.setAttribute('aria-label', 'Official Monaco proof editor');
            input.value = nextText;
            input.textContent = nextText;
            input.focus();
            if (input.setSelectionRange) input.setSelectionRange(nextText.length, nextText.length);
            input.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
          }
          return {
            ok: String(model.getValue()).includes(text) && String(input?.value || '').includes(text),
            role: 'monaco',
            valueLength: model.getValue().length
          };
        })()`);
        if (!value?.ok) {
          return { ok: false, reason: "monaco model setup failed", role: "monaco", valueLength: value?.valueLength || 0 };
        }
        return { ok: true, role: "monaco", valueLength: value.valueLength || 0 };
      }

      await send("Input.dispatchKeyEvent", {
        type: "keyDown",
        key: "a",
        code: "KeyA",
        windowsVirtualKeyCode: 65,
        nativeVirtualKeyCode: 0,
        modifiers: 4,
      });
      await send("Input.dispatchKeyEvent", {
        type: "keyUp",
        key: "a",
        code: "KeyA",
        windowsVirtualKeyCode: 65,
        nativeVirtualKeyCode: 0,
        modifiers: 4,
      });
      await new Promise((resolve) => setTimeout(resolve, 100));
      await send("Input.insertText", { text });
      await evaluate(send, focusExpression());
      await new Promise((resolve) => setTimeout(resolve, 250));
      const value = await evaluate(send, readExpression());
      if (!value?.ok) {
        return { ok: false, reason: "inserted text not observed", role: value?.role || focused.role, valueLength: value?.valueLength || 0 };
      }
      return { ok: true, role: value.role || focused.role || "official", valueLength: value.valueLength || 0 };
    }

    return { ok: false, reason: "unsupported mode" };
  });

  if (mode === "ready" || mode === "contains") {
    console.log(result ? "true" : "false");
  } else if (result?.ok) {
    console.log(`${mode}:${result.role || "official"}:${result.valueLength || 0}`);
  } else {
    console.error(`Chrome ${fixture} DevTools ${mode} failed: ${result?.reason || "unknown"}`);
    process.exit(1);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
NODE
}

chrome_official_demo_ready_with_devtools() {
  chrome_official_demo_devtools_action "$1" ready
}

chrome_focus_official_demo_editor_with_devtools() {
  chrome_official_demo_devtools_action "$1" focus >/dev/null
}

chrome_official_demo_text_contains_with_devtools() {
  local fixture="$1"
  local text="$2"
  chrome_official_demo_devtools_action "$fixture" contains "$text"
}

chrome_public_setup_text_with_devtools() {
  local fixture="$1"
  local text="$2"

  if [[ -z "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
    return 1
  fi

  if chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    chrome_official_demo_devtools_action "$fixture" insert "$text"
    return $?
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
          return rect.width >= 300 && rect.height >= 30;
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

  if chrome_fixture_requires_default_ax_official_focus "$fixture"; then
    echo "Chrome $fixture default-AX proof could not refocus the official editor through macOS Accessibility." >&2
    echo "No Apple Events JavaScript fallback was used because this lane is specifically proving normal Chrome AX exposure." >&2
    exit 1
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

  if [[ -n "$CHROME_REMOTE_DEBUGGING_PORT" ]] && chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    chrome_focus_official_demo_editor_with_devtools "$fixture"
    return 0
  fi

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

  if chrome_fixture_is_public_text_field_demo "$1"; then
    return 1
  fi

  return 0
}

chrome_fixture_uses_default_browser_accessibility() {
  if [[ "$CHROME_ACCESSIBILITY_MODE" != "default" ]]; then
    return 1
  fi

  if chrome_fixture_is_official_demo "$1" && [[ "$1" != "monaco-official" ]]; then
    return 1
  fi

  return 0
}

chrome_fixture_prefers_script_focus_only() {
  if [[ "$CHROME_ACCESSIBILITY_MODE" != "default" ]]; then
    return 1
  fi

  case "$1" in
    monaco-real|prosemirror-real)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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
            && candidate.frame.height >= 30
    case "contenteditable-public":
        return candidate.role == "AXTextArea"
            && candidate.frame.width >= 300
            && candidate.frame.height >= 30
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
        if fixture == "textarea-public", role == "AXTextArea", value.isEmpty, frame.height >= 30 {
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

chrome_focus_smoke_editor_with_devtools() {
  local fixture="$1"

  if [[ -z "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
    return 1
  fi

  node - "$CHROME_REMOTE_DEBUGGING_PORT" "$fixture" <<'NODE'
const port = process.argv[2];

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
  const focused = await evaluateExpression(wsURL, `(() => {
    if (typeof window.focusSmokeEditor === 'function') {
      window.focusSmokeEditor();
      return true;
    }

    const editor = document.querySelector('[data-smoke-editor]');
    if (!editor) return false;
    editor.focus();
    if (typeof editor.setSelectionRange === 'function') {
      const length = String(editor.value || '').length;
      editor.setSelectionRange(length, length);
      return true;
    }

    const range = document.createRange();
    range.selectNodeContents(editor);
    range.collapse(false);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    return true;
  })()`);
  process.exit(focused ? 0 : 1);
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
NODE
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

  if [[ -n "$chrome_pid" ]] && [[ -n "$CHROME_REMOTE_DEBUGGING_PORT" ]] && chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    focus_chrome_process_window "$chrome_pid" "$click_x_offset" "$click_y_offset"
    chrome_focus_official_demo_editor_with_devtools "$fixture"
    return 0
  fi

  if [[ -n "$chrome_pid" ]]; then
    focus_chrome_process_window "$chrome_pid" "$click_x_offset" "$click_y_offset"
    chrome_focus_smoke_editor_with_devtools "$fixture" >/dev/null 2>&1 || true
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

  if chrome_fixture_prefers_script_focus_only "$fixture"; then
    osascript >/dev/null <<'APPLESCRIPT'
tell application "Google Chrome"
  activate
  try
    tell active tab of front window to execute javascript "window.focusSmokeEditor && window.focusSmokeEditor();"
  end try
end tell
delay 0.2
APPLESCRIPT
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
tell application "Google Chrome"
  try
    tell active tab of front window to execute javascript "window.focusSmokeEditor && window.focusSmokeEditor();"
  end try
end tell
APPLESCRIPT
  wait_for_frontmost_app "Google Chrome" 5
}

raise_textedit_smoke_window() {
  local window_title="$1"
  local single_window_fallback="${AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK:-0}"

  AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK="$single_window_fallback" swift - "$window_title" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]
let allowSingleWindowFallback = ["1", "true", "yes", "on"].contains(
    (ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK"] ?? "").lowercased()
)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    let targetWindow = windows.first(where: {
        textEditTitleMatches(copyAttribute($0, kAXTitleAttribute) as? String)
    }) ?? (allowSingleWindowFallback && windows.count == 1 && {
        let title = copyAttribute(windows[0], kAXTitleAttribute) as? String ?? ""
        return title.hasPrefix("textedit-smoke-") ||
            title.hasPrefix("textedit-model-latency-") ||
            title.hasPrefix("autocomplete-lab-typing-soak-") ||
            title.hasPrefix("textedit-ax-retention-proof.") ||
            title.hasPrefix("textedit-retention-proof.")
    }() ? windows[0] : nil)

    if let window = targetWindow {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        let deadline = Date().addingTimeInterval(2.0)
        while Date() <= deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        print(app.processIdentifier)
        exit(0)
    }
}

exit(1)
SWIFT
}

click_textedit_smoke_window() {
  local window_title="$1"
  local single_window_fallback="${AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK:-0}"

  AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK="$single_window_fallback" swift - "$window_title" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]
let allowSingleWindowFallback = ["1", "true", "yes", "on"].contains(
    (ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK"] ?? "").lowercased()
)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
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

    let targetWindow = windows.first(where: {
        textEditTitleMatches(copyAttribute($0, kAXTitleAttribute) as? String)
    }) ?? (allowSingleWindowFallback && windows.count == 1 && {
        let title = copyAttribute(windows[0], kAXTitleAttribute) as? String ?? ""
        return title.hasPrefix("textedit-smoke-") ||
            title.hasPrefix("textedit-model-latency-") ||
            title.hasPrefix("autocomplete-lab-typing-soak-") ||
            title.hasPrefix("textedit-ax-retention-proof.") ||
            title.hasPrefix("textedit-retention-proof.")
    }() ? windows[0] : nil)

    if let window = targetWindow {
        let textInput = firstTextInput(in: window)
        if let textInput {
            AXUIElementSetAttributeValue(textInput, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }

        guard let targetBounds = bounds(for: textInput ?? window),
              let source = CGEventSource(stateID: .hidSystemState) else {
            exit(1)
        }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
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
        print(app.processIdentifier)
        exit(0)
    }
}

exit(1)
SWIFT
}

nudge_textedit_frontmost() {
  open -a TextEdit >/dev/null 2>&1 || true
}

textedit_frontmost_window_is() {
  local window_title="$1"

  swift - "$window_title" <<'SWIFT' 2>/dev/null || true
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("0")
    exit(0)
}

let targetTitle = CommandLine.arguments[1]
let allowSingleWindowFallback = ["1", "true", "yes", "on"].contains(
    (ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK"] ?? "").lowercased()
)

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
}

guard let frontmost = NSWorkspace.shared.frontmostApplication,
      frontmost.bundleIdentifier == "com.apple.TextEdit" else {
    print("0")
    exit(0)
}

let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.5)

for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
    if let rawWindow = copyAttribute(appElement, attribute) {
        let window = rawWindow as! AXUIElement
        if textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
            print("1")
            exit(0)
        }
    }
}

if let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] {
    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
        print("1")
        exit(0)
    }

    if allowSingleWindowFallback && windows.count == 1 {
        let title = copyAttribute(windows[0], kAXTitleAttribute) as? String ?? ""
        guard title.hasPrefix("textedit-smoke-") ||
            title.hasPrefix("textedit-model-latency-") ||
            title.hasPrefix("autocomplete-lab-typing-soak-") ||
            title.hasPrefix("textedit-ax-retention-proof.") ||
            title.hasPrefix("textedit-retention-proof.") else {
            print("0")
            exit(0)
        }
        print("1")
        exit(0)
    }
}

print("0")
SWIFT
}

wait_for_textedit_frontmost_window() {
  local window_title="$1"
  local target_pid="$2"
  local timeout_seconds="${3:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if [[ -n "$target_pid" ]]; then
      activate_process_id "$target_pid"
    fi
    if [[ "$(textedit_frontmost_window_is "$window_title")" == "1" ]]; then
      return 0
    fi
    sleep 0.25
  done

  echo "Timed out waiting for TextEdit smoke window '$window_title' to become frontmost." >&2
  return 1
}

assert_textedit_frontmost_window() {
  local window_title="$1"
  local label="$2"

  if [[ "$(textedit_frontmost_window_is "$window_title")" != "1" ]]; then
    local frontmost
    frontmost="$(run_osascript_with_timeout 2 "frontmost app probe" -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"
    echo "$label lost focus before accept. Expected frontmost TextEdit window '$window_title', got frontmost app '${frontmost:-unknown}'." >&2
    exit 1
  fi
}

focus_textedit_smoke_editor() {
  local window_title="${1:-}"

  if [[ -n "$window_title" ]]; then
    local target_pid
    target_pid="$(raise_textedit_smoke_window "$window_title" | tr -d '\r\n' || true)"
    if [[ -z "$target_pid" ]]; then
      echo "Could not resolve TextEdit smoke window pid for '$window_title'." >&2
      return 1
    fi
    activate_process_id "$target_pid"
    wait_for_textedit_frontmost_window "$window_title" "$target_pid" 8
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
    target_pid="$(click_textedit_smoke_window "$window_title" | tr -d '\r\n' || true)"
    if [[ -z "$target_pid" ]]; then
      echo "Could not resolve TextEdit smoke window pid for '$window_title'." >&2
      return 1
    fi
    activate_process_id "$target_pid"
    wait_for_textedit_frontmost_window "$window_title" "$target_pid" 8
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

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
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
        guard textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) else {
            continue
        }

        print(textValue(in: window) ?? "")
        exit(0)
    }
}

print("")
SWIFT
}

set_textedit_document_text() {
  local window_title="$1"
  local text="$2"

  swift - "$window_title" "$text" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]
let replacementText = CommandLine.arguments[2]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
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

func setSelectedTextRange(_ range: CFRange, in element: AXUIElement) -> Bool {
    var mutableRange = range
    guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
        return false
    }
    return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
        guard let textInput = firstTextInput(in: window) else {
            exit(1)
        }

        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(textInput, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        let currentValue = copyAttribute(textInput, kAXValueAttribute) as? String ?? ""
        guard setSelectedTextRange(CFRange(location: 0, length: currentValue.utf16.count), in: textInput) else {
            exit(1)
        }
        guard AXUIElementSetAttributeValue(textInput, kAXSelectedTextAttribute as CFString, replacementText as CFString) == .success else {
            exit(1)
        }
        guard setSelectedTextRange(CFRange(location: replacementText.utf16.count, length: 0), in: textInput) else {
            exit(1)
        }
        exit(0)
    }
}

exit(1)
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

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
        print("1")
        exit(0)
    }
}

print("0")
SWIFT
}

textedit_document_name_exists() {
  local window_title="$1"
  local result

  result="$(run_osascript_with_timeout "${AUTOCOMPLETE_LAB_TEXTEDIT_DOCUMENT_NAME_PROBE_TIMEOUT_SECONDS:-2}" "TextEdit document-name probe" - "$window_title" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  set targetTitle to item 1 of argv
  tell application "TextEdit"
    repeat with docRef in documents
      if (name of docRef) is targetTitle then
        return "1"
      end if
    end repeat
  end tell
  return "0"
end run
APPLESCRIPT
)"

  if [[ "$result" == "1" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

textedit_single_smoke_window_ready() {
  swift - <<'SWIFT' 2>/dev/null || true
import AppKit
import ApplicationServices
import Foundation

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

var titles: [String] = []
for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    if let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] {
        titles.append(contentsOf: windows.map {
            copyAttribute($0, kAXTitleAttribute) as? String ?? ""
        })
    }
}

if titles.count == 1 {
    let title = titles[0]
    if title.hasPrefix("textedit-smoke-") ||
        title.hasPrefix("textedit-model-latency-") ||
        title.hasPrefix("autocomplete-lab-typing-soak-") ||
        title.hasPrefix("textedit-ax-retention-proof.") ||
        title.hasPrefix("textedit-retention-proof.") {
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
    if [[ "$(textedit_document_name_exists "$window_title")" == "1" ]]; then
      nudge_textedit_frontmost
      if [[ "$(textedit_single_smoke_window_ready)" == "1" ]]; then
        return 0
      fi
    fi
    sleep 0.2
  done

  return 1
}

describe_open_textedit_documents() {
  run_osascript_with_timeout "${AUTOCOMPLETE_LAB_TEXTEDIT_DOCUMENT_LIST_TIMEOUT_SECONDS:-2}" "TextEdit document-list diagnostic" <<'APPLESCRIPT' 2>/dev/null || true
tell application "TextEdit"
  set out to ""
  repeat with docRef in documents
    set out to out & (name of docRef) & linefeed
  end repeat
  return out
end tell
APPLESCRIPT
}

open_textedit_smoke_document() {
  local file_path="$1"
  local window_title="$2"

  dismiss_textedit_modal_panels
  open -F -a TextEdit "$file_path"
  if wait_for_textedit_document_open "$window_title" 8; then
    return 0
  fi

  dismiss_textedit_modal_panels
  run_osascript_with_timeout 4 "TextEdit AppleScript open" - "$file_path" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    activate
    open (POSIX file targetPath)
  end tell
end run
APPLESCRIPT
  wait_for_background_process "$!" 5 "TextEdit disposable document AppleScript open" >/dev/null 2>&1 || true

  if wait_for_textedit_document_open "$window_title" 6; then
    return 0
  fi

  dismiss_textedit_modal_panels
  open -a TextEdit "$file_path"
  if wait_for_textedit_document_open "$window_title" 8; then
    return 0
  fi

  echo "Timed out waiting for TextEdit to open disposable document '$window_title'." >&2
  echo "Open TextEdit documents:" >&2
  describe_open_textedit_documents >&2
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

  echo "Timed out waiting for TextEdit document text during $label." >&2
  echo "Expected: $expected_text" >&2
  echo "Actual: $(textedit_document_text "$window_title")" >&2
  exit 1
}

wait_for_textedit_document_exact_or_return() {
  local window_title="$1"
  local expected_text="$2"
  local timeout_seconds="${3:-3}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local current_text
    current_text="$(textedit_document_text "$window_title")"
    if [[ "$current_text" == "$expected_text" ]]; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

clear_textedit_document_for_proof() {
  local window_title="$1"
  local label="$2"

  set_textedit_document_text "$window_title" "" || true
  if wait_for_textedit_document_exact_or_return "$window_title" "" 2; then
    return 0
  fi

  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  run_osascript_with_timeout 3 "TextEdit proof reset" <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  tell process "TextEdit"
    key code 53
    keystroke "a" using command down
    key code 51
  end tell
end tell
APPLESCRIPT

  wait_for_textedit_document_exact "$window_title" "" "$label" 5
}

wait_for_textedit_document_prefix() {
  local window_title="$1"
  local expected_prefix="$2"
  local label="$3"
  local timeout_seconds="${4:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local current_text
    current_text="$(textedit_document_text "$window_title")"
    if [[ "$current_text" == "$expected_prefix"* ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for TextEdit typed prefix during $label." >&2
  echo "Expected prefix: $expected_prefix" >&2
  echo "Actual: $(textedit_document_text "$window_title")" >&2
  exit 1
}

trim_textedit_native_completion_suffix() {
  local window_title="$1"
  local expected_text="$2"
  local label="$3"
  local current_text suffix_length

  current_text="$(textedit_document_text "$window_title")"
  if [[ "$current_text" == "$expected_text" ]]; then
    return 0
  fi
  if [[ "$current_text" != "$expected_text"* ]]; then
    return 0
  fi

  suffix_length=$((${#current_text} - ${#expected_text}))
  if ((suffix_length <= 0)); then
    return 0
  fi
  if ((suffix_length > 20)); then
    echo "TextEdit native completion suffix during $label was unexpectedly long ($suffix_length chars)." >&2
    echo "Expected prefix: $expected_text" >&2
    echo "Actual: $current_text" >&2
    exit 1
  fi

  assert_textedit_frontmost_window "$window_title" "$label native completion trim"
  if ! AUTOCOMPLETE_LAB_TEXTEDIT_SUFFIX_DELETE_COUNT="$suffix_length" \
    run_osascript_with_timeout 3 "$label native completion trim" <<'APPLESCRIPT' >/dev/null
set deleteCountText to system attribute "AUTOCOMPLETE_LAB_TEXTEDIT_SUFFIX_DELETE_COUNT"
set deleteCount to deleteCountText as integer
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.apple.TextEdit" then
    error "TextEdit is not frontmost for native completion trim."
  end if
  repeat deleteCount times
    key code 117
  end repeat
end tell
APPLESCRIPT
  then
    echo "TextEdit native completion trim during $label fell back to AX replacement." >&2
    set_textedit_document_text "$window_title" "$expected_text" || true
  fi

  if ! wait_for_textedit_document_exact_or_return "$window_title" "$expected_text" 3; then
    set_textedit_document_text "$window_title" "$expected_text" || true
  fi
  wait_for_textedit_document_exact "$window_title" "$expected_text" "$label native completion trim" 5
}

verify_textedit_native_undo() {
  local window_title="$1"
  local expected_text="$2"
  local label="$3"
  local timeout_seconds="${4:-8}"
  local deadline=$((SECONDS + timeout_seconds))
  local expected_caret
  expected_caret="$(printf '%s' "$expected_text" | perl -CS -MEncode -e 'local $/; my $text = <STDIN>; $text = "" unless defined $text; print length(encode("UTF-16LE", $text)) / 2')"

  while ((SECONDS <= deadline)); do
    local current_text current_caret
    current_text="$(textedit_document_text "$window_title")"
    current_caret="$(textedit_document_caret_location "$window_title")"
    if [[ "$current_text" == "$expected_text" && "$current_caret" == "$expected_caret" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for TextEdit setup during $label." >&2
  echo "Expected exact text: $expected_text" >&2
  echo "Actual exact text: $(textedit_document_text "$window_title")" >&2
  echo "Expected caret: $expected_caret" >&2
  echo "Actual caret: $(textedit_document_caret_location "$window_title")" >&2
  return 1
}

set_textedit_document_text() {
  local window_title="$1"
  local replacement_text="$2"

  swift - "$window_title" "$replacement_text" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3 else {
    exit(2)
}

let targetTitle = CommandLine.arguments[1]
let replacementText = CommandLine.arguments[2]

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else {
        return nil
    }
    return value
}

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
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

func moveCaret(_ element: AXUIElement, to location: Int) -> Bool {
    var range = CFRange(location: location, length: 0)
    guard let rangeValue = AXValueCreate(.cfRange, &range) else {
        return false
    }
    return AXUIElementSetAttributeValue(
        element,
        kAXSelectedTextRangeAttribute as CFString,
        rangeValue
    ) == .success
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
        guard let textInput = firstTextInput(in: window) else {
            exit(1)
        }
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(textInput, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        let valueResult = AXUIElementSetAttributeValue(
            textInput,
            kAXValueAttribute as CFString,
            replacementText as CFString
        )
        let caretResult = moveCaret(textInput, to: replacementText.utf16.count)
        exit(valueResult == .success && caretResult ? 0 : 1)
    }
}

exit(1)
SWIFT
}

textedit_smoke_allows_ax_proof_typing() {
  [[ "${AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION:-0}" =~ ^(1|true|yes|on)$ ]]
}

type_textedit_smoke_fragment() {
  local window_title="$1"
  local fragment="$2"

  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  move_textedit_caret_to_document_end "$window_title"
  if textedit_smoke_allows_ax_proof_typing && insert_textedit_smoke_fragment "$window_title" "$fragment"; then
    move_textedit_caret_to_document_end "$window_title"
    return 0
  fi

  assert_textedit_frontmost_window "$window_title" "TextEdit proof typing"
  (
    AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_TEXT="$fragment" osascript <<'APPLESCRIPT'
set smokeText to system attribute "AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_TEXT"
set keyDelayText to system attribute "AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_KEY_DELAY_SECONDS"
set keyDelay to 0
try
  if keyDelayText is not "" then set keyDelay to keyDelayText as real
end try
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.apple.TextEdit" then
    error "TextEdit is not frontmost for proof typing."
  end if
  if keyDelay > 0 then
    repeat with characterIndex from 1 to count characters of smokeText
      keystroke (character characterIndex of smokeText)
      delay keyDelay
    end repeat
  else
    keystroke smokeText
  end if
end tell
APPLESCRIPT
  ) &
  local osascript_pid="$!"
  wait_for_background_process "$osascript_pid" "${AUTOCOMPLETE_LAB_TEXTEDIT_KEY_TYPING_TIMEOUT_SECONDS:-4}" "TextEdit proof key typing"
}

type_textedit_smoke_fragment_and_confirm() {
  local window_title="$1"
  local fragment="$2"
  local label="$3"
  local before_text expected_text
  before_text="$(textedit_document_text "$window_title")"
  expected_text="${before_text}${fragment}"

  type_textedit_smoke_fragment "$window_title" "$fragment"
  if wait_for_textedit_document_fragment "$window_title" "$fragment" "$label" 5; then
    move_textedit_caret_to_document_end "$window_title"
    return 0
  fi

  echo "TextEdit did not receive the $label fragment; refocusing and retrying once." >&2
  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  set_textedit_document_text "$window_title" ""
  type_textedit_smoke_fragment "$window_title" "$fragment"
  wait_for_textedit_document_fragment "$window_title" "$fragment" "$label retry" 5
  move_textedit_caret_to_document_end "$window_title"
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

textedit_scrolled_prefill() {
  local index
  for index in $(seq 1 45); do
    printf 'Scroll line %02d.\n' "$index"
  done
}

textedit_model_latency_fragments() {
  cat <<'EOF'
The local runtime hardening pass keeps every model checksum verif
Private beta recovery should explain each local repair step verif
Offline launch proof needs the embedded model checksum verif
The app owned runtime should catch corrupt weight checks verif
The tester facing failure state should keep recovery steps verif
EOF
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

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
}

for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.TextEdit" {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(appElement, 0.5)
    guard let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else {
        continue
    }

    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
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

func textEditTitleMatches(_ title: String?) -> Bool {
    guard let title else {
        return false
    }
    if title == targetTitle {
        return true
    }

    let stem = (targetTitle as NSString).deletingPathExtension
    let candidates = [targetTitle, stem].filter { !$0.isEmpty }
    return candidates.contains { candidate in
        title == candidate ||
            title.hasPrefix(candidate + " ") ||
            title.hasPrefix(candidate + " -")
    }
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

    for window in windows where textEditTitleMatches(copyAttribute(window, kAXTitleAttribute) as? String) {
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

textedit_utf16_length() {
  python3 -c 'import sys; text = sys.stdin.read(); print(len(text.encode("utf-16-le")) // 2)'
}

move_textedit_caret_to_document_end() {
  local window_title="$1"
  local current_text utf16_length

  current_text="$(textedit_document_text "$window_title")"
  utf16_length="$(printf '%s' "$current_text" | textedit_utf16_length)"
  set_textedit_selected_range "$window_title" "$utf16_length" 0
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
          set titleMatches to tabTitle contains ("SteadyType Chrome") and tabTitle contains ("[ready=1]")
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
fputs("Chrome \(fixture) smoke refused to insert setup text during \(label): AX value replacement, targeted text events, AX selected-text fallback, foreground text events, and guarded paste did not update the focused Chrome editor (beforeChars=\(initialValue.count), afterChars=\(finalValue.count), selectedTextResult=\(selectedTextResult.rawValue), valueReplacementResult=\(valueReplacementResult.rawValue)).\n", stderr)
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

wait_for_chrome_setup_text_visible_to_ax() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_fragment="$3"
  local label="$4"
  local timeout_seconds="${5:-4}"

  if ! chrome_fixture_requires_ax_readable_setup "$fixture"; then
    return 0
  fi

  if chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    chrome_focus_official_demo_editor_with_ax "$fixture" "$chrome_pid" >/dev/null 2>&1 || true
  fi

  local deadline=$((SECONDS + timeout_seconds))
  local current_text=""
  while ((SECONDS <= deadline)); do
    current_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
    if [[ "$current_text" == *"$expected_fragment"* ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Chrome $fixture setup text reached the page model during $label, but the focused macOS Accessibility editor did not expose it." >&2
  echo "Expected AX fragment chars: ${#expected_fragment}; observed AX chars: ${#current_text}." >&2
  echo "No keyboard, paste, or screenshot fallback was attempted. Failing closed because Monaco official/default proof requires AX-readable setup text before SteadyType can claim an accept." >&2
  exit 1
}

wait_for_chrome_focused_text_contains() {
  local fixture="$1"
  local chrome_pid="$2"
  local expected_fragment="$3"
  local label="$4"
  local timeout_seconds="${5:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  if [[ -n "$CHROME_REMOTE_DEBUGGING_PORT" ]] && chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    while ((SECONDS <= deadline)); do
      local devtools_contains
      devtools_contains="$(chrome_official_demo_text_contains_with_devtools "$fixture" "$expected_fragment" | tr -d '[:space:]')"
      if [[ "$devtools_contains" == "true" ]]; then
        wait_for_chrome_setup_text_visible_to_ax "$fixture" "$chrome_pid" "$expected_fragment" "$label"
        return 0
      fi
      sleep 0.2
    done
  fi

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
  local backup_path="${2:-}"

  swift - "$proof_text" "$backup_path" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("missing Codex proof text\n", stderr)
    exit(2)
}

let proofText = CommandLine.arguments[1]
let backupPath = CommandLine.arguments[2]
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
        let focused = boolAttribute(element, kAXFocusedAttribute)
        let focusedDraftCanBeRestored = focused
            && !value.isEmpty
            && !value.contains(marker)
        if looksDisposable || focusedDraftCanBeRestored {
            var score = frame.width
            if focused {
                score += 1_000
            }
            if focusedDraftCanBeRestored {
                score += 650
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
    fputs("Could not find a safe Codex composer. Clear the prompt, open a new Codex start screen, or keep focus in the draft prompt so it can be backed up and restored.\n", stderr)
    exit(1)
}

let shouldRestoreDraft = !candidate.value.isEmpty && !candidate.value.contains(marker)
if shouldRestoreDraft {
    do {
        try candidate.value.write(toFile: backupPath, atomically: true, encoding: .utf8)
    } catch {
        fputs("Could not back up the existing Codex draft before proof seeding: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
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

if let focused = focusedElement(in: appElement) {
    let focusedRole = stringAttribute(focused, kAXRoleAttribute)
    let focusedText = stringAttribute(focused, kAXValueAttribute)
    let focusedCursorAtEnd = focusedText == proofText
        && selectedRangeMatches(focused, location: cursorOffset, length: 0)
    if !focusedCursorAtEnd {
        fputs("Codex proof composer was seeded, but focused AX verification is deferred to the click/refocus step (focusedRole=\(focusedRole.isEmpty ? "unknown" : focusedRole), focusedChars=\(focusedText.count), focusedHasMarker=\(focusedText.contains(marker)), focusedRange=\(rangeDescription(focused))).\n", stderr)
    }
} else {
    fputs("Codex proof composer was seeded, but no focused AX element was exposed; deferring to the click/refocus step.\n", stderr)
}

print("Seeded Codex proof composer: chars=\(proofText.count) rect=x=\(Int(candidate.frame.minX)),y=\(Int(candidate.frame.minY)),w=\(Int(candidate.frame.width)),h=\(Int(candidate.frame.height))")
if shouldRestoreDraft {
    print("Backed up existing Codex draft for restoration after proof.")
}
SWIFT
}

restore_codex_draft_if_needed() {
  if [[ -z "$CODEX_DRAFT_BACKUP_PATH" || ! -s "$CODEX_DRAFT_BACKUP_PATH" ]]; then
    return 0
  fi

  swift - "$CODEX_DRAFT_BACKUP_PATH" <<'SWIFT' || true
import AppKit
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2 else {
    exit(0)
}

let backupPath = CommandLine.arguments[1]
let marker = "AUTOCOMPLETE_LAB_CODEX_PROOF"
guard let restoreText = try? String(contentsOfFile: backupPath, encoding: .utf8) else {
    fputs("Codex draft restore skipped: backup could not be read.\n", stderr)
    exit(0)
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

func collectMarkedTextAreas(in element: AXUIElement, depth: Int = 0, results: inout [AXUIElement]) {
    guard depth <= 32 else {
        return
    }

    if stringAttribute(element, kAXRoleAttribute) == kAXTextAreaRole as String,
       stringAttribute(element, kAXValueAttribute).contains(marker) {
        results.append(element)
    }

    for child in children(of: element) {
        collectMarkedTextAreas(in: child, depth: depth + 1, results: &results)
    }
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.openai.codex"
).first else {
    exit(0)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)
var markedTextAreas: [AXUIElement] = []
collectMarkedTextAreas(in: appElement, results: &markedTextAreas)
guard let target = markedTextAreas.first else {
    fputs("Codex draft restore skipped: proof marker is no longer present.\n", stderr)
    exit(0)
}

AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
let result = AXUIElementSetAttributeValue(target, kAXValueAttribute as CFString, restoreText as CFTypeRef)
if result == .success {
    setSelectedRange(target, location: restoreText.utf16.count, length: 0)
    print("Restored existing Codex draft after proof: chars=\(restoreText.count)")
} else {
    fputs("Codex draft restore failed (AX result \(result.rawValue)).\n", stderr)
}
SWIFT

  rm -f "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true
  CODEX_DRAFT_BACKUP_PATH=""
  CODEX_DRAFT_BACKUP_ACTIVE=0
}

focus_codex_proof_prompt() {
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

func setSelectedRange(_ element: AXUIElement, location: Int, length: Int) {
    var range = CFRange(location: location, length: length)
    guard let rangeValue = AXValueCreate(.cfRange, &range) else {
        return
    }
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
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

func clickInside(_ frame: CGRect) {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        return
    }

    let x = min(frame.maxX - 16, max(frame.minX + 16, frame.minX + frame.width * 0.62))
    let point = CGPoint(x: x, y: frame.midY)
    guard let mouseDown = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    ),
    let mouseUp = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        return
    }

    mouseDown.post(tap: .cghidEventTap)
    mouseUp.post(tap: .cghidEventTap)
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

func collectMarkedTextAreas(in element: AXUIElement, depth: Int = 0, results: inout [AXUIElement]) {
    guard depth <= 32 else {
        return
    }

    if stringAttribute(element, kAXRoleAttribute) == kAXTextAreaRole as String,
       stringAttribute(element, kAXValueAttribute).contains(marker) {
        results.append(element)
    }

    for child in children(of: element) {
        collectMarkedTextAreas(in: child, depth: depth + 1, results: &results)
    }
}

func focusedElement(in appElement: AXUIElement) -> AXUIElement? {
    guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute) else {
        return nil
    }
    return (focusedValue as! AXUIElement)
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.openai.codex"
).first else {
    fputs("Codex is not running.\n", stderr)
    exit(1)
}

app.activate(options: [.activateAllWindows])
Thread.sleep(forTimeInterval: 0.15)

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)
var markedTextAreas: [AXUIElement] = []
collectMarkedTextAreas(in: appElement, results: &markedTextAreas)
guard let target = markedTextAreas.first else {
    fputs("Could not refocus Codex proof prompt: marker text area not found.\n", stderr)
    exit(1)
}

let text = stringAttribute(target, kAXValueAttribute)
let cursorOffset = text.utf16.count
if let frame = rect(for: target) {
    clickInside(frame)
    Thread.sleep(forTimeInterval: 0.12)
}
for _ in 0..<4 {
    AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    setSelectedRange(target, location: cursorOffset, length: 0)
    postCommandRight(to: app.processIdentifier)
    Thread.sleep(forTimeInterval: 0.08)
    if selectedRangeMatches(target, location: cursorOffset, length: 0) {
        break
    }
}

guard let focused = focusedElement(in: appElement),
      stringAttribute(focused, kAXValueAttribute).contains(marker),
      selectedRangeMatches(focused, location: cursorOffset, length: 0) else {
    fputs("Could not keep Codex proof prompt focused at the end before Tab.\n", stderr)
    exit(1)
}

print("Focused Codex proof composer before Tab: chars=\(text.count)")
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
  if chrome_fixture_is_official_rich_editor_demo "$fixture"; then
    if [[ -z "$CHROME_REMOTE_DEBUGGING_PORT" ]]; then
      echo "Chrome $fixture setup text has no isolated DevTools channel during $label." >&2
      echo "No keyboard or paste fallback was attempted for this official public editor lane." >&2
      echo "Use the isolated forced-renderer lane, or a default-AX lane that can expose AX-readable setup text before typing." >&2
      exit 1
    fi
    echo "Chrome $fixture setup text failed through isolated DevTools during $label; refusing guarded global typing fallback for an official public editor lane." >&2
    exit 1
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
<title>SteadyType Chrome Textarea Fixture Smoke [ready=1]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<textarea data-smoke-editor autofocus aria-label="Local smoke textarea fixture" style="font: 18px -apple-system; width: 720px; height: 180px; margin: 80px;"></textarea>
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
<title>SteadyType Chrome Contenteditable Fixture Smoke [ready=1]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<main data-smoke-editor role="textbox" aria-label="Local smoke rich text fixture" contenteditable="true" spellcheck="false" style="font: 18px -apple-system; width: 720px; min-height: 180px; margin: 80px; padding: 12px; border: 1px solid #bbb; outline: none;"></main>
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
<title>SteadyType Chrome Editor-Like Smoke</title>
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
<title>SteadyType Chrome Monaco-Like Smoke</title>
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
<title>SteadyType Chrome Real Monaco Smoke [ready=0]</title>
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
  document.title = "SteadyType Chrome Real Monaco Smoke [ready=1]";
  window.focusSmokeEditor();
});
</script>
HTML
      ;;
    prosemirror-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>SteadyType Chrome ProseMirror-Like Smoke</title>
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
<title>SteadyType Chrome Real ProseMirror Smoke [ready=0]</title>
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
document.title = "SteadyType Chrome Real ProseMirror Smoke [ready=1]";
</script>
HTML
      ;;
    chat-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>SteadyType Chrome Chat-Like No-Submit Smoke [submits=0]</title>
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
  document.title = "SteadyType Chrome Chat-Like No-Submit Smoke [submits=" + window.autocompleteSmokeSubmitCount + "]";
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
<title>SteadyType Browser Chat Proof Harness [submits=0 sendKeys=0 promptMutations=0 wrongContext=0]</title>
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
  document.title = "SteadyType Browser Chat Proof Harness [submits=" + counters.submits
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
        model-latency)
          echo "Plan: build/relaunch AutocompleteLab once, allow a cold local model warmup, type several disposable TextEdit fragments, and require real model-backed suggestions in one launch."
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
      if [[ "$TEXTEDIT_VARIANT" == "model-latency" ]]; then
        echo "Safety: model latency proof seeds stable context into the disposable TextEdit AX target, then types the final partial word through live key events."
        echo "Safety: model latency proof disables fast word completions and phrase continuations for that launch so local word-completion model timing is required."
        echo "Safety: model latency proof tags the runtime launch with scenario textedit-model-latency so generic TextEdit samples cannot satisfy the beta gate."
      else
        echo "Safety: proof fragments are typed through System Events key events by default, so the latency proof exercises the live key-capture path."
      fi
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
        echo "Plan: build the app bundle, seed disposable Chrome fixtures, launch SteadyType only for proof, then run textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and chat-like no-submit local fixtures."
        if [[ "$CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF" == "1" ]]; then
          echo "Plan add-on: rerun real Monaco and real ProseMirror in default Chrome AX mode after the forced renderer lane."
        fi
      elif [[ "$CHROME_FIXTURE" == "production-text-fields" ]]; then
        echo "Plan: build the app bundle, seed disposable Chrome fixtures, launch SteadyType only for proof, then run bounded public Chrome textarea and contenteditable proof on top-level demo pages."
        echo "Proof path: production text-field lanes use public URLs plus guarded coordinate focus and AX verification; Chrome JavaScript-from-Apple-Events is not required for these two lanes."
      elif chrome_fixture_is_public_text_field_demo "$CHROME_FIXTURE"; then
        echo "Plan: build the app bundle, open the public top-level $CHROME_FIXTURE demo page in Chrome, seed disposable text, launch SteadyType only for proof, then validate logs and traces."
        echo "Proof path: public text-field proof uses guarded coordinate focus and AX verification; Chrome JavaScript-from-Apple-Events is not required for this lane."
      elif chrome_fixture_is_official_demo "$CHROME_FIXTURE"; then
        echo "Plan: build the app bundle, open the public official $CHROME_FIXTURE demo page in Chrome, seed disposable text, launch SteadyType only for proof, then validate logs and traces."
        echo "Proof path: official rich-editor demo lanes use an isolated temporary Chrome profile plus localhost DevTools focus/setup when available; otherwise they try Accessibility editor focus before the Apple Events fallback."
        if [[ "$CHROME_FIXTURE" == "monaco-official" ]]; then
          echo "Proof gate: Monaco official must expose setup text through the focused macOS AX editor before SteadyType can accept; otherwise the lane fails closed without keyboard, paste, or screenshot fallback."
          if [[ "$CHROME_ACCESSIBILITY_MODE" == "default" ]]; then
            echo "Proof path: monaco-official default AX uses normal Chrome AX focus only for the proof claim, with no DevTools or Apple Events fallback."
          fi
        fi
        echo "Requirement: SteadyType must already be allowed in macOS Accessibility; the lane fails closed before typing if AX is missing."
        echo "Runtime: official demo lanes allow up to $(chrome_runtime_ready_timeout_seconds)s for cold current-build MLX warmup before touching Chrome."
      elif [[ "$CHROME_FIXTURE" == "browser-chat-harness" ]]; then
        echo "Plan: build the app bundle, serve the bounded HTTP browser-chat no-submit proof harness on 127.0.0.1, seed disposable text, launch SteadyType only for proof, then validate trace and harness counters."
        echo "Scope: this proves only the disposable harness surface. It does not enable Slack, Discord, ChatGPT, or broad browser chat support."
      elif chrome_fixture_is_blocked_high_value_surface "$CHROME_FIXTURE"; then
        echo "Plan: blocked preflight only. This fixture records the next high-value surface but refuses to type into the live service."
        echo "Blocked: $(chrome_blocked_high_value_surface_reason "$CHROME_FIXTURE")"
      else
        echo "Plan: build the app bundle, open a disposable Chrome $CHROME_FIXTURE fixture, seed disposable text, launch SteadyType only for proof, then validate logs and traces."
      fi
      echo "Safety: the smoke launch temporarily enables Chrome only for this proof pass."
      echo "Safety: before Chrome typing, the smoke requires Chrome to expose a focused editable web text target through Accessibility."
      echo "Safety: Chrome setup text is seeded before SteadyType launches whenever the smoke builds the app itself."
      echo "Safety: later Chrome setup pauses SteadyType while disposable text is seeded, then relaunches the current app bundle before proof resumes."
      echo "Safety: Chrome setup text first tries DevTools/DOM or AX value replacement, then guarded key/paste fallbacks only after the disposable editor is rechecked as frontmost and editable."
      ;;
    notes)
      local notes_app notes_surface
      if notes_app="$(notes_session_app)"; then
        notes_surface="${notes_app#notes-}"
        case "$notes_app" in
          notes-title)
            echo "Plan: guarded Apple Notes title proof. The script creates a fresh blank note, verifies the focused title line is blank, types smoke fragments, then validates logs and traces."
            ;;
          notes-title-short)
            echo "Plan: guarded Apple Notes short title proof. The script creates a fresh blank note, verifies the focused title line is blank, types a short title smoke fragment, then validates logs and traces."
            ;;
          notes-title-long)
            echo "Plan: guarded Apple Notes long title proof. The script creates a fresh blank note, verifies the focused title line is blank, types a longer title smoke fragment, then validates logs and traces."
            ;;
          notes-body)
            echo "Plan: guarded Apple Notes body proof. The script verifies the open note body contains the disposable marker, appends smoke fragments, then validates logs and traces."
            ;;
          notes-body-short)
            echo "Plan: guarded Apple Notes short body proof. The script verifies the disposable body marker, appends a short smoke line, then validates logs and traces."
            ;;
          notes-body-long)
            echo "Plan: guarded Apple Notes long body proof. The script verifies the disposable body marker, appends a longer smoke line, then validates logs and traces."
            ;;
          notes-checklist)
            echo "Plan: guarded Apple Notes checklist proof. The script creates a fresh disposable note, toggles Checklist from Notes' Format menu, verifies the disposable prefix, types smoke fragments, then validates logs and traces."
            ;;
          notes-checklist-checked)
            echo "Plan: guarded Apple Notes checked checklist proof. The script creates a fresh checklist row, marks it checked through Notes' Format menu, types smoke fragments, then validates logs and traces."
            ;;
          notes-checklist-long)
            echo "Plan: guarded Apple Notes long checklist proof. The script creates a fresh checklist row, types a longer checklist smoke fragment, then validates logs and traces."
            ;;
          notes-title-undo)
            echo "Plan: guarded Apple Notes title undo proof. The script creates a fresh blank note, verifies the title, accepts one suggestion, presses Command-Z, then validates same-slice undo logs and traces."
            ;;
          notes-body-undo)
            echo "Plan: guarded Apple Notes body undo proof. The script verifies the disposable body marker, accepts one suggestion, presses Command-Z, then validates same-slice undo logs and traces."
            ;;
          notes-checklist-undo)
            echo "Plan: guarded Apple Notes checklist undo proof. The script creates a fresh checklist row, accepts one suggestion, presses Command-Z, then validates same-slice undo logs and traces."
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
          echo "Plan: guarded Obsidian non-default theme proof. The script opens the disposable proof-vault note, types smoke fragments, then validates logs and traces."
          ;;
        obsidian-pane)
          echo "Plan: manual-gated Obsidian split/side-pane proof. The script validates same-pane placement and insertion after you run it."
          ;;
        obsidian-long-note)
          echo "Plan: manual-gated Obsidian long scrolled note proof. The script validates visible scrolled-caret placement after you run it."
          ;;
        obsidian-font-zoom)
          echo "Plan: guarded Obsidian font/zoom proof. The script increases Obsidian zoom, types smoke fragments, validates screenshots and insertion, then resets zoom."
          ;;
        obsidian-markdown-bold)
          echo "Plan: guarded Obsidian bold Markdown proof. The script types smoke fragments after a bold marker prefix and validates visual placement plus insertion."
          ;;
        obsidian-markdown-list)
          echo "Plan: guarded Obsidian list Markdown proof. The script types smoke fragments in a dash-list context and validates visual placement plus insertion."
          ;;
        obsidian-multiline)
          echo "Plan: guarded Obsidian multiline proof. The script starts several blank lines below the marker and validates visual placement plus insertion."
          ;;
        obsidian-run-on)
          echo "Plan: guarded Obsidian run-on/wrapped sentence proof. The script types after a long wrapping sentence and validates visual placement plus insertion."
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
      echo "Safety: if the focused Codex prompt already has a draft, the helper backs it up privately and restores it after the no-submit proof."
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
  SMOKE_PHASE="build/relaunch current SteadyType"
  if [[ "$SKIP_BUILD" != "1" ]]; then
    local build_run_env=(
      AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES=1
    )
    if [[ ! "${AUTOCOMPLETE_LAB_REAL_APP_DIRECT_LAUNCH:-1}" =~ ^(0|false|no|off)$ ]]; then
      build_run_env+=(AUTOCOMPLETE_LAB_DIRECT_LAUNCH=1)
    fi
    env "${build_run_env[@]}" ./script/build_and_run.sh run
  fi

  wait_for_current_autocomplete_lab_process
  refresh_build_archive_proof
}

build_bundle_if_needed() {
  if [[ "$SKIP_BUILD" != "1" ]]; then
    AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES=1 \
      ./script/build_and_run.sh bundle-only
  else
    wait_for_current_autocomplete_lab_process
  fi

  refresh_build_archive_proof
  SMOKE_PHASE="build proof refreshed"
}

steadytype_app_process_rows() {
  ps ax -o pid=,pgid=,command= 2>/dev/null |
    awk '
      {
        pid = $1
        pgid = $2
        command = $0
        sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      }
      command ~ /^\/.*\/SteadyType\.app\/Contents\/MacOS\/SteadyType([[:space:]]|$)/ {
        print pid "\t" pgid "\t" command
      }
    '
}

command_matches_steadytype_binary() {
  local command="$1"
  local app_binary="$2"
  [[ "$command" == "$app_binary" || "$command" == "$app_binary "* ]]
}

current_steadytype_app_bundle_pids() {
  local app_binary="$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType"
  local current_pgid
  current_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ' || true)"

  while IFS=$'\t' read -r pid pgid command; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" == "$$" ]] && continue
    [[ -n "$current_pgid" && "$pgid" == "$current_pgid" ]] && continue
    command_matches_steadytype_binary "$command" "$app_binary" || continue
    printf '%s\n' "$pid"
  done < <(steadytype_app_process_rows)
}

stop_current_steadytype_app_bundle() {
  local pid

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(current_steadytype_app_bundle_pids)

  for _ in {1..20}; do
    if [[ -z "$(current_steadytype_app_bundle_pids)" ]]; then
      return 0
    fi
    sleep 0.1
  done
}

pause_steadytype_for_chrome_setup() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  stop_current_steadytype_app_bundle
}

launch_steadytype_after_chrome_setup() {
  local fixture="$1"
  local start_line="$2"
  local chrome_pid="${3:-}"
  local chrome_url="${4:-}"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  local app_binary="$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType"
  if [[ ! -x "$app_binary" ]]; then
    echo "SteadyType app binary is missing after build: $app_binary" >&2
    exit 1
  fi

  local launch_env=(
    AUTOCOMPLETE_LAB_DIRECT_LAUNCH=1
  )
  local env_key
  for env_key in \
    AUTOCOMPLETE_LAB_SCREENSHOT_TRACE \
    AUTOCOMPLETE_LAB_RAW_TRACE \
    AUTOCOMPLETE_LAB_TRACE \
    AUTOCOMPLETE_LAB_MODEL \
    AUTOCOMPLETE_LAB_VISIBLE_WORDS \
    AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS \
    AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION \
    AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION \
    AUTOCOMPLETE_LAB_PROOF_SCENARIO \
    AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS \
    AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS \
    AUTOCOMPLETE_LAB_ACCEPTED_INSERTION_UNDO_RECOVERY; do
    if [[ -n "${!env_key+x}" ]]; then
      launch_env+=("$env_key=${!env_key}")
    fi
  done

  env "${launch_env[@]}" \
    nohup "$app_binary" >"$ROOT_DIR/dist/SteadyType.launch.log" 2>&1 </dev/null &
  disown "$!" 2>/dev/null || true

  wait_for_current_autocomplete_lab_process
  if [[ -n "$chrome_url" ]]; then
    focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"
  fi
  wait_for_accessibility_ready "$start_line" "Chrome $fixture post-setup Accessibility readiness" 20 0
  wait_for_runtime_ready "$start_line" "Chrome $fixture post-setup runtime readiness" "$(chrome_runtime_ready_timeout_seconds)" 0
  if [[ -n "$chrome_url" ]]; then
    focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"
  fi
}

wait_for_current_autocomplete_lab_process() {
  local expected_binary="$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType"
  local deadline=$((SECONDS + 20))

  while ((SECONDS <= deadline)); do
    local found_current=0
    local current_pids=()
    local stale_processes=""
    local pid command
    while IFS=$'\t' read -r pid _pgid command; do
      [[ -z "$pid" ]] && continue
      [[ -z "$command" ]] && continue
      if command_matches_steadytype_binary "$command" "$expected_binary"; then
        found_current=1
        current_pids+=("$pid")
      else
        stale_processes+="${pid} ${command}"$'\n'
      fi
    done < <(steadytype_app_process_rows)

    if ((${#current_pids[@]} > 1)); then
      local keep_pid=""
      for pid in "${current_pids[@]}"; do
        if [[ -z "$keep_pid" || "$pid" -gt "$keep_pid" ]]; then
          keep_pid="$pid"
        fi
      done
      for pid in "${current_pids[@]}"; do
        [[ "$pid" == "$keep_pid" ]] && continue
        kill "$pid" >/dev/null 2>&1 || true
      done
      sleep 0.25
      continue
    fi

    if [[ "$found_current" == "1" && -z "$stale_processes" ]]; then
      return 0
    fi
    sleep 0.25
  done

  echo "SteadyType smoke launch did not settle on this checkout's app bundle." >&2
  echo "Expected binary: $expected_binary" >&2
  echo "Running SteadyType processes:" >&2
  steadytype_app_process_rows |
    awk -F '\t' '{ print $1 " " $3 }' >&2
  exit 1
}

refresh_build_archive_proof() {
  local app_bundle="dist/SteadyType.app"
  local archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/smoke-proof/SteadyType.zip}"
  local archive_dir archive_name archive_abs

  [[ -d "$app_bundle" ]] || return 0

  export AUTOCOMPLETE_LAB_ARCHIVE_PATH="$archive_path"
  archive_dir="$(dirname "$archive_path")"
  archive_name="$(basename "$archive_path")"
  mkdir -p "$archive_dir"
  archive_abs="$(cd "$archive_dir" && pwd -P)/$archive_name"

  local release_archive_abs
  release_archive_abs="$(cd "$ROOT_DIR/dist" && pwd -P)/SteadyType.zip"
  if [[ "$archive_abs" == "$release_archive_abs" ]]; then
    echo "Refusing to write smoke proof archive over release artifact: $archive_path" >&2
    echo "Use ./script/package_release.sh archive or --notarize to refresh dist/SteadyType.zip." >&2
    exit 1
  fi

  rm -f "$archive_abs"
  (cd dist && ditto -c -k --keepParent "SteadyType.app" "$archive_abs")

  local archive_sha
  archive_sha="$(shasum -a 256 "$archive_abs" | awk '{print $1}')"
  if [[ -n "$archive_sha" ]]; then
    echo "Archive proof: $archive_path archive-sha256:$archive_sha"
  fi
}

run_codex() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local runtime_start_line start_line trace_start_line proof_text backup_dir
  runtime_start_line="$(line_count "$LOG_PATH")"
  proof_text="$(codex_proof_text)"
  backup_dir="$(make_tmp_dir)"
  CODEX_DRAFT_BACKUP_PATH="$backup_dir/codex-draft-backup.txt"
  : >"$CODEX_DRAFT_BACKUP_PATH"
  chmod 600 "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Codex Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Codex runtime readiness" 60 "$SKIP_BUILD"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  seed_codex_proof_prompt "$proof_text" "$CODEX_DRAFT_BACKUP_PATH"
  if [[ -s "$CODEX_DRAFT_BACKUP_PATH" ]]; then
    CODEX_DRAFT_BACKUP_ACTIVE=1
  fi
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.openai.codex" "Codex proof suggestion" 20
  wait_for_screenshot_capture_if_enabled "$start_line" "com.openai.codex" "Codex proof"
  seed_codex_proof_prompt "$proof_text"
  assert_frontmost_app "Codex" "Codex proof"
  focus_codex_proof_prompt
  sleep 0.2
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
let titleMarker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE"] ?? "SteadyType Checklist Smoke"

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

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "SteadyType Obsidian proof"
let expectedSuffix = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX"] ?? ""
let normalizedMarker = marker
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")

func normalizedForMarkerMatch(_ value: String) -> String {
    value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

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
guard normalizedForMarkerMatch(text).localizedCaseInsensitiveContains(normalizedMarker) else {
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

assert_obsidian_initial_smoke_target() {
  case "$1" in
    obsidian-long-note)
      AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER="Autocomplete Lab Obsidian" assert_obsidian_smoke_target
      ;;
    *)
      assert_obsidian_smoke_target
      ;;
  esac
}

ensure_notes_title_smoke_note() {
  open -a Notes
  wait_for_frontmost_app "Notes" 8
  create_notes_blank_smoke_note
  assert_notes_title_smoke_target
}

ensure_notes_checklist_smoke_note() {
  local smoke_title="${AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE:-SteadyType Checklist Smoke}"

  open -a Notes
  wait_for_frontmost_app "Notes" 8
  create_notes_blank_smoke_note
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
  local smoke_title="${AUTOCOMPLETE_LAB_NOTES_SMOKE_TITLE:-SteadyType Smoke}"
  local smoke_marker="${AUTOCOMPLETE_LAB_NOTES_SMOKE_MARKER:-Autocomplete smoke}"

  open -a Notes
  wait_for_frontmost_app "Notes" 8
  create_notes_blank_smoke_note
  type_notes_raw_smoke_text "$smoke_title"$'\n'"$smoke_marker"
  sleep 0.8
}

create_notes_blank_smoke_note() {
  osascript <<'APPLESCRIPT'
tell application "Notes" to activate
delay 0.2
tell application "System Events"
  tell process "Notes"
    set frontmost to true
    click menu item "New Note" of menu "File" of menu bar item "File" of menu bar 1
  end tell
end tell
delay 0.8
APPLESCRIPT
}

create_notes_smoke_note() {
  create_notes_blank_smoke_note
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

mark_notes_checklist_row_checked() {
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Notes"
    set frontmost to true
    click menu item "Mark as Checked" of menu "Format" of menu bar item "Format" of menu bar 1
  end tell
end tell
APPLESCRIPT
  sleep 0.3
}

try_press_accepted_insertion_undo() {
  local app_bundle_id="$1"
  local label="$2"
  local undo_start_line

  undo_start_line="$(line_count "$LOG_PATH")"
  osascript <<'APPLESCRIPT'
tell application "System Events"
  keystroke "z" using command down
end tell
APPLESCRIPT
  if ! wait_for_log_fields_optional "$undo_start_line" 8 \
    "keyboard-action" \
    "app=$app_bundle_id" \
    "action=undoAcceptedInsertion" \
    "handled=true"; then
    return 1
  fi
  wait_for_log_fields "$undo_start_line" "$label accepted insertion undo" 8 \
    "accepted-insertion-undone" \
    "app=$app_bundle_id"
}

press_and_wait_for_accepted_insertion_undo() {
  local app_bundle_id="$1"
  local label="$2"

  if try_press_accepted_insertion_undo "$app_bundle_id" "$label"; then
    return 0
  fi

  echo "Timed out waiting for $label undo keyboard action." >&2
  echo "Required fields: keyboard-action app=$app_bundle_id action=undoAcceptedInsertion handled=true" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n 80 "$LOG_PATH" 2>/dev/null >&2
  exit 1
}

type_obsidian_raw_smoke_text() {
  local text="$1"

  activate_obsidian_for_smoke
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE:-0}" != "1" ]] &&
    [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_AX_TYPE:-0}" == "1" ]] &&
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
let expectedLocation = text.utf16.count
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

let deadline = Date().addingTimeInterval(1.2)
while Date() < deadline {
    if let selectedValue = copyAttribute(editor, kAXSelectedTextRangeAttribute) {
        var selectedRange = CFRange()
        if AXValueGetValue(selectedValue as! AXValue, .cfRange, &selectedRange),
           selectedRange.location >= max(0, expectedLocation - 1) {
            exit(0)
        }
    }

    _ = AXUIElementSetAttributeValue(
        editor,
        kAXSelectedTextRangeAttribute as CFString,
        rangeValue
    )
    Thread.sleep(forTimeInterval: 0.12)
}
SWIFT
  sleep 0.25
}

focus_obsidian_visible_tail_line() {
  activate_obsidian_for_smoke
  swift - <<'SWIFT' >/dev/null
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    copyAttribute(element, attribute) as? String ?? ""
}

func children(of element: AXUIElement) -> [AXUIElement] {
    copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
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

func collectElements(in element: AXUIElement, depth: Int = 0, results: inout [AXUIElement]) {
    guard depth <= 32 else {
        return
    }

    results.append(element)
    for child in children(of: element) {
        collectElements(in: child, depth: depth + 1, results: &results)
    }
}

func clickInside(_ point: CGPoint) {
    let source = CGEventSource(stateID: .hidSystemState)
    guard let mouseDown = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseDown,
        mouseCursorPosition: point,
        mouseButton: .left
    ),
    let mouseUp = CGEvent(
        mouseEventSource: source,
        mouseType: .leftMouseUp,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        return
    }

    mouseDown.post(tap: .cghidEventTap)
    mouseUp.post(tap: .cghidEventTap)
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "md.obsidian").first else {
    exit(3)
}

app.activate(options: [.activateAllWindows])
Thread.sleep(forTimeInterval: 0.15)

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)
let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "Autocomplete Lab Obsidian proof"
let normalizedMarker = marker
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
let requireLongNoteLine = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90"] != "0"

func normalizedForMarkerMatch(_ value: String) -> String {
    value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

var elements: [AXUIElement] = []
collectElements(in: appElement, results: &elements)

let textAreas = elements.filter {
    stringAttribute($0, kAXRoleAttribute) == kAXTextAreaRole as String
}

guard let target = textAreas
    .filter({
        let value = stringAttribute($0, kAXValueAttribute)
        return normalizedForMarkerMatch(value).contains(normalizedMarker)
            && (!requireLongNoteLine || value.contains("Autocomplete Lab Obsidian scroll filler line 90"))
    })
    .sorted(by: {
        (rect(for: $0)?.maxY ?? 0) > (rect(for: $1)?.maxY ?? 0)
    })
    .first,
    let targetRect = rect(for: target) else {
    exit(3)
}

let value = stringAttribute(target, kAXValueAttribute)
let visibleLines = value
    .split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
let tailLine = visibleLines.last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""

var targetChildren: [AXUIElement] = []
collectElements(in: target, results: &targetChildren)
let tailElement = targetChildren
    .filter { stringAttribute($0, kAXValueAttribute) == tailLine }
    .compactMap { element -> (AXUIElement, CGRect)? in
        guard let frame = rect(for: element),
              frame.height > 0,
              targetRect.intersects(frame) else {
            return nil
        }
        return (element, frame)
    }
    .sorted { $0.1.maxY > $1.1.maxY }
    .first

let clickPoint: CGPoint
if let (_, lineRect) = tailElement {
    let tailX = min(targetRect.maxX - 8, max(lineRect.minX + 8, lineRect.maxX + 8))
    clickPoint = CGPoint(
        x: tailX,
        y: lineRect.height > 30 ? lineRect.maxY - 11 : lineRect.midY
    )
} else {
    clickPoint = CGPoint(x: targetRect.minX + 28, y: targetRect.maxY - 18)
}

AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
clickInside(clickPoint)
SWIFT
  sleep 0.2
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
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL:-0}" == "1" ]]; then
    focus_obsidian_visible_tail_line
    set_obsidian_caret_to_value_end
  fi
  sleep 0.35
}

reset_obsidian_smoke_note() {
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT:-${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER:-Autocomplete Lab Obsidian proof}}"

  activate_obsidian_for_smoke
  AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT="$marker" swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let markerText = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT"] ?? "SteadyType Obsidian proof"
let appendNewlineFallback = (ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN"] == "1") ? 0 : 1
let appendNewlines = max(0, Int(ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_RESET_APPEND_NEWLINES"] ?? "") ?? appendNewlineFallback)
let resetText = markerText + String(repeating: "\n", count: appendNewlines)

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
    resetText as CFTypeRef
) == .success else {
    fputs("Could not reset the disposable Obsidian smoke note text.\n", stderr)
    exit(3)
}

AXUIElementSetAttributeValue(focused, kAXFocusedAttribute as CFString, kCFBooleanTrue)
var endRange = CFRange(location: resetText.utf16.count, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}
SWIFT

  activate_obsidian_for_smoke
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_LEGACY_RESET_KEYS:-0}" == "1" ]]; then
    osascript <<'APPLESCRIPT'
tell application "System Events"
  tell application process "Obsidian" to set frontmost to true
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "md.obsidian" then
    error "Obsidian is not frontmost for smoke-note reset."
  end if
  if (system attribute "AUTOCOMPLETE_LAB_OBSIDIAN_MOVE_TO_DOCUMENT_END") is "1" then
    key code 125 using command down
  else
    key code 124 using command down
  end if
  delay 0.2
  if (system attribute "AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN") is not "1" then
    key code 36
  end if
end tell
APPLESCRIPT
  fi
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

wait_for_obsidian_smoke_note_file_suffix() {
  local expected_suffix="$1"
  local timeout_seconds="${2:-5}"
  local smoke_file deadline current_suffix
  smoke_file="$(obsidian_smoke_file_path)"
  deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    current_suffix="$(tail -c "${#expected_suffix}" "$smoke_file" 2>/dev/null || true)"
    if [[ "$current_suffix" == "$expected_suffix" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Obsidian smoke note to end with expected disposable text." >&2
  echo "Expected suffix: $expected_suffix" >&2
  echo "Current tail:" >&2
  tail -c 240 "$smoke_file" >&2 || true
  echo >&2
  exit 3
}

obsidian_smoke_note_file_char_count() {
  LC_ALL=C wc -m <"$(obsidian_smoke_file_path)" | tr -d ' '
}

assert_obsidian_long_note_file_preserved() {
  local expected_suffix="$1"
  local smoke_file
  smoke_file="$(obsidian_smoke_file_path)"

  if ! grep -Fq "Autocomplete Lab Obsidian scroll filler line 01" "$smoke_file" ||
     ! grep -Fq "Autocomplete Lab Obsidian scroll filler line 90" "$smoke_file"; then
    echo "Obsidian long-note proof lost off-screen note content." >&2
    echo "Current head:" >&2
    head -n 8 "$smoke_file" >&2 || true
    echo "Current tail:" >&2
    tail -n 8 "$smoke_file" >&2 || true
    exit 3
  fi

  wait_for_obsidian_smoke_note_file_suffix "$expected_suffix" 5
}

activate_neutral_smoke_setup_app() {
  open -a Finder >/dev/null 2>&1 || true
  try_wait_for_frontmost_app "Finder" 3 >/dev/null 2>&1 || true
  sleep 0.2
}

obsidian_reset_text_for_variant() {
  local variant="$1"
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER:-Autocomplete Lab Obsidian proof}"

  if [[ "$variant" != "obsidian-long-note" ]]; then
    printf '%s' "$marker"
    return 0
  fi

  local index
  for index in $(seq 1 45); do
    printf 'AL scroll %s\n' "$index"
  done
  printf '%s' "$marker"
}

seed_obsidian_proof_vault_note() {
  local reset_text="$1"
  local proof_vault="$HOME/Library/Application Support/AutocompleteLab/ObsidianProofVault"
  local proof_note="$proof_vault/Proof/placement-proof.md"

  mkdir -p "$(dirname "$proof_note")"
  printf '%s\n' "$reset_text" >"$proof_note"
}

open_obsidian_smoke_note_if_configured() {
  local smoke_uri="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI:-}"
  if [[ -n "$smoke_uri" ]]; then
    open "$smoke_uri"
    sleep "${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI_WAIT_SECONDS:-2}"
    activate_obsidian_for_smoke
    return 0
  fi

  local proof_vault="$HOME/Library/Application Support/AutocompleteLab/ObsidianProofVault"
  if [[ -f "$proof_vault/Proof/placement-proof.md" ]]; then
    open "obsidian://open?vault=ObsidianProofVault&file=Proof%2Fplacement-proof"
    sleep "${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI_WAIT_SECONDS:-2}"
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
  case "$manual_app" in
    obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on)
      ;;
    *)
      run_manual_gated
      return 0
      ;;
  esac

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line obsidian_marker first_fragment
  runtime_start_line="$(line_count "$LOG_PATH")"
  obsidian_marker="$(obsidian_smoke_marker_text "$manual_app")"
  first_fragment="Smoke proof feels"
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    first_fragment="moke proof feels"
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=1
  elif [[ "$manual_app" == "obsidian-pane" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
  elif [[ "$manual_app" == "obsidian-font-zoom" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
  elif [[ "$manual_app" == "obsidian-markdown-list" || "$manual_app" == "obsidian-run-on" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
  elif [[ "$manual_app" == "obsidian-multiline" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
  fi
  if [[ "$manual_app" == "obsidian-markdown-bold" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_RESET_APPEND_NEWLINES=0
  elif [[ "$manual_app" == "obsidian-markdown-list" || "$manual_app" == "obsidian-run-on" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_RESET_APPEND_NEWLINES=0
  elif [[ "$manual_app" == "obsidian-multiline" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_RESET_APPEND_NEWLINES=3
  else
    unset AUTOCOMPLETE_LAB_OBSIDIAN_SKIP_RESET_RETURN
    export AUTOCOMPLETE_LAB_OBSIDIAN_RESET_APPEND_NEWLINES=1
  fi
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_BASE:-Autocomplete Lab Obsidian proof}"
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT="$obsidian_marker"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Obsidian Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Obsidian runtime readiness" 60 "$SKIP_BUILD"

  full_accept_key="$(accept_all_shortcut)"

  local obsidian_reset_text
  obsidian_reset_text="$(obsidian_reset_text_for_variant "$manual_app")"
  seed_obsidian_proof_vault_note "$obsidian_reset_text"
  open_obsidian_smoke_note_if_configured
  wait_for_frontmost_app "Obsidian" 8
  if [[ "$manual_app" != "obsidian-pane" ]]; then
    restore_obsidian_single_pane_if_needed
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
  fi
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
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_ESCAPE_BEFORE_TYPING:-0}" == "1" ]]; then
    press_key_code 53
    sleep 0.35
  else
    sleep 0.15
  fi
  prepare_obsidian_variant_state "$manual_app"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  type_obsidian_raw_smoke_text "$first_fragment"
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=md.obsidian" "Obsidian suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "md.obsidian" "Obsidian"
  if [[ "$manual_app" == "obsidian-font-zoom" ]]; then
    local zoom_resync_line
    zoom_resync_line="$(line_count "$LOG_PATH")"
    sleep 0.8
    if log_since_matches "$zoom_resync_line" "suggestion-presented .*app=md.obsidian"; then
      wait_for_screenshot_capture_if_enabled "$zoom_resync_line" "md.obsidian" "Obsidian zoom-resynced"
    fi
  fi
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

  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    press_key_code 53
    sleep 0.2
    activate_neutral_smoke_setup_app
    assert_obsidian_long_note_file_preserved "Smoke proof feels instant"
    append_obsidian_smoke_note_file_text " and stays inst"
    second_start_line="$(line_count "$LOG_PATH")"
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
    move_obsidian_caret_to_document_end
    assert_obsidian_smoke_target "Smoke proof feels instant and stays inst"
  else
    assert_obsidian_smoke_target "Smoke proof feels instant"
    if [[ "$manual_app" == "obsidian-pane" ]]; then
      move_obsidian_caret_to_line_end
    elif [[ "$manual_app" == "obsidian-markdown-list" || "$manual_app" == "obsidian-run-on" ]]; then
      move_obsidian_caret_to_document_end
    elif [[ "$manual_app" == "obsidian-multiline" ]]; then
      set_obsidian_caret_to_value_end
    fi
    # In Obsidian/CodeMirror, Escape can mark the focused editor as suppressed.
    # Let normal typing invalidate the previous suggestion unless we are explicitly testing Escape.
    if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_ESCAPE_BETWEEN_ACCEPTS:-0}" == "1" ]]; then
      press_key_code 53
      sleep 0.25
    else
      sleep 0.15
    fi
    second_start_line="$(line_count "$LOG_PATH")"
    type_obsidian_raw_smoke_text " and stays"
  fi
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    wait_for_log_fields "$second_start_line" "Obsidian second suggestion" 12 \
      "suggestion-presented" \
      "app=md.obsidian" \
      "afterChars=0"
  else
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=md.obsidian" "Obsidian second suggestion"
  fi
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Obsidian long-note full acceptance" 12 \
      "keyboard-action" \
      "app=md.obsidian" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"
    wait_for_log_pattern "$full_start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian long-note second verified insertion"
    assert_obsidian_long_note_file_preserved "Smoke proof feels instant and stays instant"
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

  if [[ "$manual_app" == "obsidian-font-zoom" ]]; then
    restore_obsidian_zoom_after_font_proof
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

  local notes_surface notes_variant="default" notes_requires_undo=0
  case "$manual_app" in
    notes-title|notes-title-short)
      notes_surface="title"
      notes_variant="short"
      ;;
    notes-title-long)
      notes_surface="title"
      notes_variant="long"
      ;;
    notes-title-undo)
      notes_surface="title"
      notes_variant="undo"
      notes_requires_undo=1
      ;;
    notes-body|notes-body-short)
      notes_surface="body"
      notes_variant="short"
      ;;
    notes-body-long)
      notes_surface="body"
      notes_variant="long"
      ;;
    notes-body-undo)
      notes_surface="body"
      notes_variant="undo"
      notes_requires_undo=1
      ;;
    notes-checklist)
      notes_surface="checklist"
      notes_variant="unchecked"
      ;;
    notes-checklist-checked)
      notes_surface="checklist"
      notes_variant="checked"
      ;;
    notes-checklist-long)
      notes_surface="checklist"
      notes_variant="long"
      ;;
    notes-checklist-undo)
      notes_surface="checklist"
      notes_variant="undo"
      notes_requires_undo=1
      ;;
    *)
      run_manual_gated
      return 0
      ;;
  esac

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Notes Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Notes runtime readiness" 60 "$SKIP_BUILD"

  full_accept_key="$(accept_all_shortcut)"

  if [[ "$notes_surface" == "title" ]]; then
    ensure_notes_title_smoke_note
    start_line="$(line_count "$LOG_PATH")"
    trace_start_line="$(line_count "$TRACE_PATH")"

    local first_fragment="Smoke proof feels"
    if [[ "$notes_variant" == "long" ]]; then
      first_fragment="Long title proof keeps the same caret path while Smoke proof feels"
    fi
    local expected_after_first="Smoke proof feels instant"
    if [[ "$notes_variant" == "long" ]]; then
      expected_after_first="$first_fragment instant"
    fi
    local second_fragment=" and stays"

    assert_notes_title_smoke_target
    type_notes_raw_smoke_text "$first_fragment"
    wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes title suggestion"
    assert_frontmost_app "Notes" "Notes title"
    press_key_code 48
    wait_for_log_fields "$start_line" "Notes title Tab acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"
    wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes title first verified insertion"
    wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes title"

    if (( notes_requires_undo == 1 )); then
      press_and_wait_for_accepted_insertion_undo "com.apple.Notes" "Notes title"
      assert_notes_title_smoke_target "$first_fragment"
    fi

    second_start_line="$(line_count "$LOG_PATH")"
    if (( notes_requires_undo == 0 )); then
      assert_notes_title_smoke_target "$expected_after_first"
    fi
    type_notes_raw_smoke_text "$second_fragment"
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes title second suggestion"
    assert_frontmost_app "Notes" "Notes title"
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Notes title full acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes title second"

    sleep 1
    local manual_check_args=("$manual_app" --check)
    if screenshot_trace_requested; then
      manual_check_args+=(--visual)
    fi
    AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
      AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
      AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
      ./script/manual_smoke_session.sh "${manual_check_args[@]}"
    return 0
  fi

  if [[ "$notes_surface" == "checklist" ]]; then
    local checklist_title="${AUTOCOMPLETE_LAB_NOTES_CHECKLIST_TITLE:-SteadyType Checklist Smoke}"
    ensure_notes_checklist_smoke_note
    start_line="$(line_count "$LOG_PATH")"
    trace_start_line="$(line_count "$TRACE_PATH")"

    local first_fragment="Smoke proof feels"
    if [[ "$notes_variant" == "long" ]]; then
      first_fragment="Long checklist proof keeps the caret visible while Smoke proof feels"
    fi
    local expected_after_first="$checklist_title"$'\n'"Smoke proof feels instant"
    if [[ "$notes_variant" == "long" ]]; then
      expected_after_first="$checklist_title"$'\n'"$first_fragment instant"
    fi
    local expected_after_undo="$checklist_title"$'\n'"$first_fragment"
    local second_fragment=" and stays"

    assert_notes_checklist_smoke_target
    if [[ "$notes_variant" == "checked" ]]; then
      mark_notes_checklist_row_checked
      assert_notes_checklist_smoke_target
    fi
    type_notes_raw_smoke_text "$first_fragment"
    wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes checklist suggestion"
    assert_frontmost_app "Notes" "Notes checklist"
    press_key_code 48
    wait_for_log_fields "$start_line" "Notes checklist Tab acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"
    wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes checklist first verified insertion"
    wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes checklist"

    if (( notes_requires_undo == 1 )); then
      local checklist_acceptance_id
      checklist_acceptance_id="$(latest_log_field_since "$start_line" "accepted-insertion-undo-armed" "acceptanceID")"
      if ! try_press_accepted_insertion_undo "com.apple.Notes" "Notes checklist"; then
        assert_notes_checklist_smoke_target "$expected_after_undo"
        record_native_undo_proof "com.apple.Notes" "$checklist_acceptance_id" "acceptNextWord" "Notes checklist"
      fi
      assert_notes_checklist_smoke_target "$expected_after_undo"
    fi

    second_start_line="$(line_count "$LOG_PATH")"
    if (( notes_requires_undo == 0 )); then
      assert_notes_checklist_smoke_target "$expected_after_first"
    fi
    type_notes_raw_smoke_text "$second_fragment"
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes checklist second suggestion"
    assert_frontmost_app "Notes" "Notes checklist"
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Notes checklist full acceptance" 12 \
      "keyboard-action" \
      "app=com.apple.Notes" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes checklist second"

    sleep 1
    local manual_check_args=("$manual_app" --check)
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

  local body_first_fragment=$'\nSmoke proof feels'
  if [[ "$notes_variant" == "long" ]]; then
    body_first_fragment=$'\nLong body proof keeps a wrapped Notes line stable while Smoke proof feels'
  fi
  local body_second_fragment=" and stays"

  assert_notes_body_smoke_target
  type_notes_raw_smoke_text "$body_first_fragment"
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.apple.Notes" "Notes body suggestion"
  assert_frontmost_app "Notes" "Notes body"
  press_key_code 48
  wait_for_log_fields "$start_line" "Notes body Tab acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.Notes" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.apple.Notes .*result=verified" "Notes body first verified insertion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.Notes" "Notes body"

  if (( notes_requires_undo == 1 )); then
    press_and_wait_for_accepted_insertion_undo "com.apple.Notes" "Notes body"
    assert_notes_body_smoke_target
  fi

  second_start_line="$(line_count "$LOG_PATH")"
  assert_notes_body_smoke_target
  type_notes_raw_smoke_text "$body_second_fragment"
  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.Notes" "Notes body second suggestion"
  assert_frontmost_app "Notes" "Notes body"
  full_start_line="$(line_count "$LOG_PATH")"
  press_accept_all_shortcut
  wait_for_log_fields "$full_start_line" "Notes body full acceptance" 12 \
    "keyboard-action" \
    "app=com.apple.Notes" \
    "key=$full_accept_key" \
    "action=acceptAllVisible" \
    "handled=true"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.Notes" "Notes body second"

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

run_claude_code_blocked() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  run_manual_gated
}

run_textedit() {
  local runtime_start_line start_line textedit_file textedit_tmp_dir textedit_window_title trace_start_line
  SMOKE_PHASE="TextEdit setup"
  runtime_start_line="$(line_count "$LOG_PATH")"

  if [[ "$TEXTEDIT_VARIANT" == "model-latency" ]]; then
    run_textedit_model_latency
    return 0
  fi

  if [[ "$TEXTEDIT_VARIANT" == "fast-typing" ]]; then
    prepare_temporary_app_enablement
    build_if_needed
    wait_for_accessibility_ready "$runtime_start_line" "TextEdit Accessibility readiness" 20 "$SKIP_BUILD"
    wait_for_runtime_ready "$runtime_start_line" "TextEdit runtime readiness" 60 "$SKIP_BUILD"

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
  export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1

  SMOKE_PHASE="TextEdit stale smoke cleanup"
  cleanup_stale_textedit_smoke_windows
  textedit_tmp_dir="$(make_tmp_dir)"
  textedit_file="$textedit_tmp_dir/textedit-smoke-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  textedit_window_title="$(basename "$textedit_file")"
  SMOKE_TEXTEDIT_WINDOW_TITLES+=("$textedit_window_title")
  : >"$textedit_file"
  if [[ "$SKIP_BUILD" != "1" ]]; then
    stop_current_steadytype_app_bundle
  fi
  cleanup_stale_textedit_smoke_windows
  open_textedit_smoke_document "$textedit_file" "$textedit_window_title"
  sleep 0.8

  case "$TEXTEDIT_VARIANT" in
    long-wrap|narrow|scrolled)
      set_textedit_window_frame "$textedit_window_title" 120 120 420 420
      sleep 0.3
      ;;
  esac

  wait_for_textedit_smoke_editor "$textedit_window_title"
  focus_textedit_smoke_editor "$textedit_window_title"
  click_textedit_smoke_editor "$textedit_window_title"
  set_textedit_document_text "$textedit_window_title" ""
  wait_for_textedit_document_exact "$textedit_window_title" "" "TextEdit initial reset" 5
  click_textedit_smoke_editor "$textedit_window_title"
  move_textedit_caret_to_document_end "$textedit_window_title"

  if [[ "$TEXTEDIT_VARIANT" == "scrolled" ]]; then
    local scrolled_prefill
    scrolled_prefill="$(textedit_scrolled_prefill)"
    insert_textedit_smoke_fragment "$textedit_window_title" "$scrolled_prefill"
    wait_for_textedit_document_fragment "$textedit_window_title" "Scroll line 45" "scrolled prefill" 8
    focus_textedit_smoke_editor "$textedit_window_title"
    click_textedit_smoke_editor "$textedit_window_title"
    sleep 0.4
  fi

  runtime_start_line="$(line_count "$LOG_PATH")"
  prepare_temporary_app_enablement
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "TextEdit Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "TextEdit runtime readiness" 60 "$SKIP_BUILD"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local first_fragment manual_app
  first_fragment="$(textedit_first_fragment)"
  manual_app="$(textedit_smoke_session_app)"

  SMOKE_PHASE="TextEdit first suggestion"
  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" "$first_fragment" "first typed"
  wait_for_textedit_document_exact "$textedit_window_title" "$first_fragment" "TextEdit first typed exact" 5
  move_textedit_caret_to_document_end "$textedit_window_title"

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
  focus_textedit_smoke_editor "$textedit_window_title"
  assert_textedit_frontmost_window "$textedit_window_title" "TextEdit"
  local before_one_word_accept_text
  before_one_word_accept_text="$(textedit_document_text "$textedit_window_title")"
  SMOKE_PHASE="TextEdit Tab acceptance"
  wait_for_textedit_acceptance_with_stale_retry "$start_line" "TextEdit Tab acceptance" "tab" "acceptNextWord" "$textedit_window_title"
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

  SMOKE_PHASE="TextEdit second suggestion"
  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" " and stays inst" "second typed"

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit second suggestion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.TextEdit" "TextEdit second"
  focus_textedit_smoke_editor "$textedit_window_title"
  assert_textedit_frontmost_window "$textedit_window_title" "TextEdit"
  local before_full_accept_text
  before_full_accept_text="$(textedit_document_text "$textedit_window_title")"
  full_start_line="$(line_count "$LOG_PATH")"
  SMOKE_PHASE="TextEdit full acceptance"
  wait_for_textedit_acceptance_with_stale_retry "$full_start_line" "TextEdit full acceptance" "$full_accept_key" "acceptAllVisible" "$textedit_window_title"
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
  else
    wait_for_log_fields "$full_start_line" "TextEdit accepted-and-kept survival" 45 \
      "annoyance-signal" \
      "app=com.apple.TextEdit" \
      "reason=thirty-second-finalized" \
      "signal=acceptedAndKept"
  fi

  sleep 1
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="$full_accept_key" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh "$manual_app" --check
  SMOKE_PHASE="TextEdit proof complete"
}

run_textedit_model_latency() {
  local runtime_start_line start_line textedit_file textedit_tmp_dir textedit_window_title trace_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"
  export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1

  prepare_temporary_app_enablement
  prepare_model_latency_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "TextEdit model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "TextEdit model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"

  textedit_tmp_dir="$(make_tmp_dir)"
  textedit_file="$textedit_tmp_dir/textedit-model-latency-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  textedit_window_title="$(basename "$textedit_file")"
  SMOKE_TEXTEDIT_WINDOW_TITLES+=("$textedit_window_title")
  : >"$textedit_file"
  cleanup_stale_textedit_smoke_windows
  open_textedit_smoke_document "$textedit_file" "$textedit_window_title"
  sleep 0.8

  wait_for_textedit_smoke_editor "$textedit_window_title"
  focus_textedit_smoke_editor "$textedit_window_title"
  click_textedit_smoke_editor "$textedit_window_title"
  clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency initial reset"
  move_textedit_caret_to_document_end "$textedit_window_title"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local sample_index=0 fragment sample_start seed_start stable_context trigger_text
  while IFS= read -r fragment; do
    [[ -z "$fragment" ]] && continue
    sample_index=$((sample_index + 1))
    stable_context="${fragment% *} "
    trigger_text="${fragment##* }"
    if [[ -z "$trigger_text" || "$stable_context" == "$fragment " ]]; then
      echo "TextEdit model latency sample $sample_index does not contain a stable context plus trigger word." >&2
      exit 1
    fi

    clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency reset $sample_index"
    move_textedit_caret_to_document_end "$textedit_window_title"
    seed_start="$(line_count "$LOG_PATH")"
    if ! insert_textedit_smoke_fragment "$textedit_window_title" "$stable_context"; then
      echo "TextEdit model latency sample $sample_index could not seed the stable AX context." >&2
      exit 1
    fi
    wait_for_textedit_document_exact "$textedit_window_title" "$stable_context" "TextEdit model latency stable context $sample_index" 5
    move_textedit_caret_to_document_end "$textedit_window_title"
    if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION:-}" =~ ^(1|true|yes|on)$ ]]; then
      wait_for_log_fields "$seed_start" "TextEdit model latency disabled phrase seed $sample_index" 8 \
        "phrase-continuation-disabled" \
        "app=com.apple.TextEdit"
      echo "TextEdit model latency seed settled by disabled phrase continuation $sample_index."
    elif wait_for_log_fields_optional "$seed_start" 4 \
      "mlx-completion-timing" \
      "app=com.apple.TextEdit" \
      "mode=phraseContinuation"; then
      echo "TextEdit model latency seed settled $sample_index."
    else
      echo "TextEdit model latency seed produced no model timing before sample $sample_index."
    fi
    move_textedit_caret_to_document_end "$textedit_window_title"

    sample_start="$(line_count "$LOG_PATH")"
    AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0 \
    AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_KEY_DELAY_SECONDS="${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_KEY_DELAY_SECONDS:-0}" \
      type_textedit_smoke_fragment "$textedit_window_title" "$trigger_text"
    wait_for_textedit_document_prefix "$textedit_window_title" "$fragment" "TextEdit model latency sample $sample_index" 5
    trim_textedit_native_completion_suffix "$textedit_window_title" "$fragment" "TextEdit model latency sample $sample_index"
    wait_for_log_fields "$sample_start" "TextEdit model latency timing $sample_index" 20 \
      "mlx-completion-timing" \
      "app=com.apple.TextEdit"
    wait_for_log_fields "$sample_start" "TextEdit model latency visible $sample_index" 20 \
      "suggestion-presented" \
      "app=com.apple.TextEdit" \
      "candidateSelectionSource=app-model-result"
    sleep 0.4
  done < <(textedit_model_latency_fragments)

  if ((sample_index < 5)); then
    echo "TextEdit model latency proof expected at least 5 samples, got $sample_index." >&2
    exit 1
  fi

  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/latency_benchmark_report.py --beta-gate
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
    if ! chrome_fixture_is_official_rich_editor_demo "$fixture"; then
      focus_chrome_smoke_editor "$fixture" "$chrome_pid"
    fi
  else
    # Default-Chrome proof must not reuse the isolated browser DevTools port.
    CHROME_REMOTE_DEBUGGING_PORT=""
    if chrome_fixture_prefers_script_focus_only "$fixture"; then
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
APPLESCRIPT
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

  pause_steadytype_for_chrome_setup
  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "first fragment" "$first_fragment"
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"
  launch_steadytype_after_chrome_setup "$fixture" "$start_line" "$chrome_pid" "$chrome_url"
  focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"

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

  if [[ -z "$chrome_pid" ]]; then
    focus_chrome_smoke_editor "$fixture" "" "$chrome_url"
  fi
  pause_steadytype_for_chrome_setup
  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "second fragment" "$second_fragment"
  second_start_line="$(line_count "$LOG_PATH")"
  launch_steadytype_after_chrome_setup "$fixture" "$second_start_line" "$chrome_pid" "$chrome_url"
  focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"

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
  if [[ "$SKIP_BUILD" == "1" ]]; then
    build_if_needed
    wait_for_accessibility_ready "$runtime_start_line" "Chrome Accessibility readiness" 20 "$SKIP_BUILD"
    wait_for_runtime_ready "$runtime_start_line" "Chrome runtime readiness" "$(chrome_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  else
    build_bundle_if_needed
  fi

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

if [[ "$APP" == "chrome" ]] && chrome_fixture_is_blocked_high_value_surface "$CHROME_FIXTURE"; then
  echo "Blocked Chrome fixture: $CHROME_FIXTURE" >&2
  chrome_blocked_high_value_surface_reason "$CHROME_FIXTURE" >&2
  echo "No Chrome typing was attempted." >&2
  exit 1
fi

refuse_other_smoke_processes
acquire_smoke_lock
start_smoke_interference_guard

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
