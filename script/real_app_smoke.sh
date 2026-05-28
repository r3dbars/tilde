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
ALLOW_MODEL_LATENCY_SKIP_BUILD="${AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD:-0}"
CHROME_FIXTURE="${AUTOCOMPLETE_LAB_CHROME_FIXTURE:-textarea}"
CHROME_FIXTURE_WAS_SET=0
CHROME_ACCESSIBILITY_MODE="${AUTOCOMPLETE_LAB_CHROME_ACCESSIBILITY_MODE:-forced}"
CHROME_ACCESSIBILITY_MODE_WAS_SET=0
CHROME_INCLUDE_DEFAULT_REAL_EDITOR_PROOF=0
CHROME_MODEL_LATENCY=0
CODEX_MODEL_LATENCY=0
CODEX_FULL_ACCEPT_PROOF=0
CLAUDE_CODE_MODEL_LATENCY=0
CLAUDE_MODEL_LATENCY=0
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
PROOF_DISABLE_WORD_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION"
PROOF_DISABLE_WORD_LAUNCHCTL_WAS_PREPARED=0
PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS=""
PROOF_DISABLE_PHRASE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=0
PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
PROOF_DISABLE_FAST_PHRASE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK"
PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_WAS_PREPARED=0
PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS=""
PROOF_SCENARIO_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_SCENARIO"
PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=0
PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
PROOF_SUPPRESS_ANNOYANCE_ENV_KEY="AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING"
PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=0
PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
ACCEPT_ALL_SHORTCUT_DEFAULT_WAS_PREPARED=0
ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS_EXISTS=0
ACCEPT_ALL_SHORTCUT_DEFAULT_PREVIOUS=""
TEXTEDIT_APPEARANCE_WAS_SET=0
TEXTEDIT_PREVIOUS_DARK_MODE=""
CODEX_DRAFT_BACKUP_PATH=""
CODEX_DRAFT_BACKUP_ACTIVE=0
CLAUDE_CODE_TERMINAL_PROOF_TITLE=""
CLAUDE_CODE_TERMINAL_WAS_RUNNING=0
CLAUDE_DRAFT_BACKUP_PATH=""
CLAUDE_CODE_TERMINAL_PROOF_PIDS=""
CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME=""
CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE=""
CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE=""
CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=1
CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=0
CLAUDE_CODE_GHOSTTY_USED_DIRECT_COMMAND_OPEN=0
CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT=0
CLAUDE_CODE_GHOSTTY_SKIP_DIRECT_COMMAND_OPEN=0
CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED=0
SMOKE_PHASE="startup"

allow_model_latency_skip_build() {
  [[ "$ALLOW_MODEL_LATENCY_SKIP_BUILD" =~ ^(1|true|yes|on)$ ]]
}

is_model_latency_lane() {
  [[ "$TEXTEDIT_VARIANT" == "model-latency" ]] ||
    [[ "$TEXTEDIT_VARIANT" == "default-model-latency" ]] ||
    [[ "$CHROME_MODEL_LATENCY" == "1" ]] ||
    [[ "$CODEX_MODEL_LATENCY" == "1" ]] ||
    [[ "$CLAUDE_CODE_MODEL_LATENCY" == "1" ]] ||
    [[ "$CLAUDE_MODEL_LATENCY" == "1" ]]
}

usage() {
  cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|textedit-light|textedit-dark|textedit-long-wrap|textedit-wrapped|textedit-narrow|textedit-scrolled|textedit-selected-suppression|textedit-undo-one-word|textedit-undo-full|textedit-fast-typing|textedit-model-latency|textedit-default-model-latency|chrome|chrome-textarea-model-latency|chrome-contenteditable-model-latency|notes-title|notes-title-short|notes-title-long|notes-body|notes-body-short|notes-body-long|notes-checklist|notes-checklist-checked|notes-checklist-long|notes-title-undo|notes-body-undo|notes-checklist-undo|notes|obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on|codex|codex-full-accept|codex-model-latency|claude-code|claude-code-terminal|claude-code-model-latency|claude-code-terminal-model-latency|claude-code-iterm2|claude-code-warp|claude-code-ghostty|claude-code-kitty|claude-code-alacritty|claude-code-wezterm|claude|claude-model-latency|claude-empty|claude-long|claude-wrapped|claude-narrow|claude-context|claude-light|claude-dark> [--dry-run] [--manual-gate] [--skip-build] [--native-undo-proof] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|google-docs|notion|browser-webmail|browser-gmail|browser-outlook|browser-chatgpt|browser-slack|browser-discord|all>] [--chrome-accessibility <forced|default>] [--include-default-real-editor-proof] [--host <terminal|iterm2|warp|ghostty|kitty|alacritty|wezterm|auto>]

Runs a real app smoke pass where it is safe to automate. Notes title/body/
checklist proof has guarded disposable-note drivers; Obsidian, Codex,
Claude Code, and Claude desktop are manual-gated so this script never types
into private notes, vaults, terminal prompts, or agent prompts by surprise.
The Codex and Terminal-host Claude Code lanes use targeted disposable proof
helpers after the manual gate: they seed marked proof text, press Tab once, and
never press Enter. Use codex-full-accept for the separate bounded no-submit
full-accept proof lane; it is tagged with a proof-only runtime scenario.

Notes proof must use notes-title, notes-body, notes-checklist, their
notes-*-undo variants, or explicit Notes variant lanes such as
notes-title-short, notes-title-long, notes-body-short, notes-body-long,
notes-checklist-checked, and notes-checklist-long. A generic notes run only
prints the surface picker and does not record proof.

TextEdit proof can use textedit-light, textedit-dark, textedit-long-wrap,
textedit-narrow, textedit-scrolled, textedit-selected-suppression, textedit-undo-one-word,
textedit-undo-full, textedit-fast-typing, textedit-model-latency, or
textedit-default-model-latency. These are still narrow TextEdit lanes, not a
generic native-app claim. The TextEdit undo lanes automatically use native
single-edit Command-Z proof.

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
The google-docs, notion, browser-webmail, browser-gmail, browser-outlook, browser-chatgpt, browser-slack, and browser-discord
fixtures are blocked preflight labels: they document the next high-value
surfaces but refuse to type until a safe disposable proof path exists.
Use
--fixture all to run every local Chrome browser/editor fixture with one app
build. Add --include-default-real-editor-proof with --fixture all to rerun real
Monaco and ProseMirror in default Chrome AX mode after the forced lane.
Use chrome-textarea-model-latency or chrome-contenteditable-model-latency to
relaunch SteadyType with fast completions and phrase continuations disabled,
then prove the local model path in a disposable Chrome fixture.
Use codex-model-latency with --manual-gate to seed disposable Codex prompt text,
keep Enter untouched, and prove prompt no-submit local model timing in one
bounded launch.
Use claude-model-latency with --manual-gate to seed disposable Claude desktop
prompt text, keep Enter untouched, and prove prompt no-submit local model timing
in one bounded launch.
Use claude-code-model-latency with --manual-gate to open a disposable Terminal
Claude Code prompt, type marked disposable proof context and trigger
characters, and prove terminal-host no-submit local model timing without Tab,
Enter, or full accept.

Claude Code is proof-only through supported terminal hosts. Use --host or the
claude-code-<host> aliases to record host-specific proof labels without enabling
normal terminal suggestions.

--skip-build reuses the already-running AutocompleteLab app. It fails closed unless
the only running SteadyType process is this checkout's dist/SteadyType.app binary
and that process already has any proof-mode environment needed by the smoke pass.
The model-latency lanes do not allow --skip-build because they must relaunch
SteadyType with fast word completions disabled before sampling. For packaged
release artifact proof only, set AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1
after launching that exact app with the required proof-mode environment; the
strict latency selector must still prove the tagged runtime launch.

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
  textedit-default-model-latency)
    APP="textedit"
    TEXTEDIT_VARIANT="default-model-latency"
    ;;
  chrome-textarea-model-latency)
    APP="chrome"
    CHROME_FIXTURE="textarea"
    CHROME_FIXTURE_WAS_SET=1
    CHROME_MODEL_LATENCY=1
    ;;
  chrome-contenteditable-model-latency)
    APP="chrome"
    CHROME_FIXTURE="contenteditable"
    CHROME_FIXTURE_WAS_SET=1
    CHROME_MODEL_LATENCY=1
    ;;
  codex-model-latency)
    APP="codex"
    CODEX_MODEL_LATENCY=1
    ;;
  codex-full-accept)
    APP="codex"
    CODEX_FULL_ACCEPT_PROOF=1
    ;;
  claude-model-latency)
    APP="claude"
    CLAUDE_MODEL_LATENCY=1
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
  claude-code-model-latency|claude-code-terminal-model-latency)
    APP="claude-code"
    CLAUDE_CODE_HOST_VARIANT="terminal"
    CLAUDE_CODE_HOST_WAS_SET=1
    CLAUDE_CODE_MODEL_LATENCY=1
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
  textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|google-docs|notion|browser-webmail|browser-gmail|browser-outlook|browser-chatgpt|browser-slack|browser-discord|all)
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

if [[ "$APP" == "textedit" && "$TEXTEDIT_VARIANT" == "model-latency" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "textedit-model-latency cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "textedit" && "$TEXTEDIT_VARIANT" == "default-model-latency" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "textedit-default-model-latency cannot be combined with --skip-build because the app must relaunch with word completions and the fast phrase fallback disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "chrome" && "$CHROME_MODEL_LATENCY" == "1" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "$REQUESTED_APP cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "codex" && "$CODEX_MODEL_LATENCY" == "1" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "codex-model-latency cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "codex" && "$CODEX_FULL_ACCEPT_PROOF" == "1" && "$SKIP_BUILD" == "1" ]]; then
  echo "codex-full-accept cannot be combined with --skip-build because the app must relaunch with the codex-full-accept-no-submit proof scenario before accepting a whole suggestion." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "claude" && "$CLAUDE_MODEL_LATENCY" == "1" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "claude-model-latency cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
  usage >&2
  exit 2
fi

if [[ "$APP" == "claude-code" && "$CLAUDE_CODE_MODEL_LATENCY" == "1" && "$SKIP_BUILD" == "1" ]] && ! allow_model_latency_skip_build; then
  echo "claude-code-model-latency cannot be combined with --skip-build because the app must relaunch with fast word completions and phrase continuations disabled before sampling." >&2
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
SMOKE_QUARANTINE_GUARD_PID=""
EXCLUSIVE_PROOF_RUN="${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-0}"
SMOKE_STARTUP_MARKER_PATH="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_STARTUP_MARKER_PATH:-}"

smoke_startup_marker() {
  local phase="$1"
  local pgid
  [[ -n "$SMOKE_STARTUP_MARKER_PATH" ]] || return 0
  mkdir -p "$(dirname "$SMOKE_STARTUP_MARKER_PATH")" >/dev/null 2>&1 || true
  pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d '[:space:]' || true)"
  printf '%s phase=%s pid=%s pgid=%s app=%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$phase" "$SMOKE_SCRIPT_PID" "${pgid:-unknown}" "$APP" \
    >>"$SMOKE_STARTUP_MARKER_PATH" 2>/dev/null || true
}

smoke_startup_marker "config-ready"

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
        if docName starts with "textedit-smoke-" or docName starts with "textedit-model-latency-" or docName starts with "textedit-default-model-latency-" or docName starts with "autocomplete-lab-typing-soak-" or docName starts with "textedit-ax-retention-proof." or docName starts with "textedit-retention-proof." then
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
    "textedit-default-model-latency-",
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
  if [[ -n "$SMOKE_QUARANTINE_GUARD_PID" ]]; then
    kill "$SMOKE_QUARANTINE_GUARD_PID" >/dev/null 2>&1 || true
    wait "$SMOKE_QUARANTINE_GUARD_PID" >/dev/null 2>&1 || true
    SMOKE_QUARANTINE_GUARD_PID=""
  fi
  if [[ -n "$SMOKE_INTERFERENCE_GUARD_PID" ]]; then
    kill "$SMOKE_INTERFERENCE_GUARD_PID" >/dev/null 2>&1 || true
    wait "$SMOKE_INTERFERENCE_GUARD_PID" >/dev/null 2>&1 || true
    SMOKE_INTERFERENCE_GUARD_PID=""
  fi

  cleanup_smoke_textedit_windows
  restore_codex_draft_if_needed
  cleanup_claude_code_terminal_proof
  restore_claude_draft_if_needed
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

  if [[ "$PROOF_DISABLE_WORD_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_DISABLE_WORD_ENV_KEY" "$PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_DISABLE_WORD_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_DISABLE_PHRASE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY" "$PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" >/dev/null 2>&1 || true
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
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

smoke_signal_pid_list() {
  local pid
  for pid in "$@"; do
    [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] || continue
    printf '%s\n' "$pid"
  done | awk '!seen[$0]++' | paste -sd, -
}

diagnose_smoke_signal() {
  local signal_name="$1"
  local self_pid self_ppid self_pgid self_sess tracked_pids snapshot_pids lock_owner
  self_pid="${SMOKE_SCRIPT_PID:-${BASHPID:-$$}}"
  self_ppid="$(ps -o ppid= -p "$self_pid" 2>/dev/null | tr -d '[:space:]' || true)"
  self_pgid="$(ps -o pgid= -p "$self_pid" 2>/dev/null | tr -d '[:space:]' || true)"
  self_sess="$(ps -o sess= -p "$self_pid" 2>/dev/null | tr -d '[:space:]' || true)"
  lock_owner=""
  if [[ -f "$SMOKE_LOCK_DIR/pid" ]]; then
    lock_owner="$(head -n 1 "$SMOKE_LOCK_DIR/pid" 2>/dev/null | tr -dc '0-9' || true)"
  fi
  tracked_pids="$(smoke_signal_pid_list \
    "$self_pid" \
    "$self_ppid" \
    "$SMOKE_INTERFERENCE_GUARD_PID" \
    "$SMOKE_QUARANTINE_GUARD_PID" \
    "$lock_owner" \
    ${CLAUDE_CODE_TERMINAL_PROOF_PIDS:-})"
  echo "real_app_smoke received $signal_name during phase: $SMOKE_PHASE" >&2
  echo "Smoke signal self pid=${self_pid:-unknown} ppid=${self_ppid:-unknown} pgid=${self_pgid:-unknown} session=${self_sess:-unknown}" >&2
  echo "Smoke guard pids: interference=${SMOKE_INTERFERENCE_GUARD_PID:-none} quarantine=${SMOKE_QUARANTINE_GUARD_PID:-none}" >&2
  echo "Tracked Claude Code terminal proof pids: ${CLAUDE_CODE_TERMINAL_PROOF_PIDS:-none}" >&2
  echo "Smoke lock owner pid: ${lock_owner:-none}" >&2
  echo "Smoke lock: $SMOKE_LOCK_DIR" >&2
  snapshot_pids="$tracked_pids"
  if [[ -n "$snapshot_pids" ]]; then
    echo "Signal process snapshot:" >&2
    ps -o pid=,ppid=,pgid=,sess=,stat=,etime=,command= -p "$snapshot_pids" >&2 || true
  fi
  if [[ -n "$self_pgid" ]]; then
    echo "Smoke process group members:" >&2
    ps ax -o pid=,ppid=,pgid=,sess=,stat=,etime=,command= 2>/dev/null |
      awk -v pgid="$self_pgid" '$3 == pgid { print }' >&2 || true
  fi
  echo "Proof-related process snapshot:" >&2
  ps ax -o pid=,ppid=,pgid=,sess=,stat=,etime=,command= 2>/dev/null |
    awk '$0 ~ /(claude_code_ghostty_detached_proof|real_app_smoke|terminal_prompt_ax_proof_helper|Ghostty|ghostty|osascript|SteadyType)/ { print }' |
    head -n 60 >&2 || true
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
      if quarantine_foreign_worktree_pid "$existing_pid"; then
        sleep 1
        if ! kill -0 "$existing_pid" >/dev/null 2>&1; then
          rm -rf "$SMOKE_LOCK_DIR" >/dev/null 2>&1 || true
        fi
        continue
      fi
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

quarantine_other_worktrees_enabled() {
  [[ "${AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES:-}" =~ ^(1|true|yes|on)$ ]]
}

process_cwd() {
  local pid="$1"
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null |
    sed -n 's/^n//p' |
    head -n 1 || true
}

descendant_pids() {
  local root_pid="$1"
  ps -axo pid=,ppid= 2>/dev/null |
    awk -v root="$root_pid" '
      {
        pid = $1
        ppid = $2
        if (pid == "") next
        parent[pid] = ppid
        seen[pid] = 1
      }
      END {
        changed = 1
        while (changed) {
          changed = 0
          for (pid in seen) {
            if (parent[pid] == root || family[parent[pid]]) {
              if (!family[pid]) {
                family[pid] = 1
                changed = 1
              }
            }
          }
        }
        for (pid in family) {
          print pid
        }
      }
    '
}

terminate_pid_tree() {
  local pid="$1"
  local child

  descendant_pids "$pid" | sort -rn | while IFS= read -r child; do
    [[ -n "$child" && "$child" != "$SMOKE_SCRIPT_PID" ]] || continue
    kill -TERM "$child" >/dev/null 2>&1 || true
  done
  kill -TERM "$pid" >/dev/null 2>&1 || true
}

command_path_is_foreign_worktree() {
  local command="$1"
  local worktree_root="$HOME/.codex/worktrees"

  [[ "$command" == "$worktree_root/"* ]] || return 1
  [[ "$command" == "$ROOT_DIR" || "$command" == "$ROOT_DIR/"* ]] && return 1
  return 0
}

cwd_is_foreign_worktree() {
  local cwd="$1"
  local worktree_root="$HOME/.codex/worktrees"

  [[ -n "$cwd" && "$cwd" == "$worktree_root/"* ]] || return 1
  [[ "$cwd" == "$ROOT_DIR" || "$cwd" == "$ROOT_DIR/"* ]] && return 1
  return 0
}

quarantine_foreign_worktree_pid() {
  local pid="$1"
  local command="${2:-}"
  local cwd

  quarantine_other_worktrees_enabled || return 1
  [[ -n "$pid" && "$pid" != "$SMOKE_SCRIPT_PID" && "$pid" != "$SMOKE_QUARANTINE_GUARD_PID" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1 || return 1

  if [[ -z "$command" ]]; then
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  fi
  cwd="$(process_cwd "$pid")"

  if ! cwd_is_foreign_worktree "$cwd" && ! command_path_is_foreign_worktree "$command"; then
    return 1
  fi

  echo "Stopping foreign worktree proof process pid $pid (${cwd:-unknown cwd})." >&2
  terminate_pid_tree "$pid"
  return 0
}

quarantine_foreign_smoke_processes() {
  local processes="$1"
  local line
  local pid
  local command
  local stopped=1

  quarantine_other_worktrees_enabled || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    pid="$(awk '{ print $1 }' <<<"$line")"
    command="$line"
    command="${command#"$pid"}"
    command="${command#"${command%%[![:space:]]*}"}"
    if quarantine_foreign_worktree_pid "$pid" "$command"; then
      stopped=0
    fi
  done <<<"$processes"

  return "$stopped"
}

quarantine_foreign_steadytype_apps() {
  local pid
  local command
  local line
  local rows

  quarantine_other_worktrees_enabled || return 0
  rows="$(ps ax -o pid=,command= 2>/dev/null |
    awk '$0 ~ /\/SteadyType\.app\/Contents\/MacOS\/SteadyType([[:space:]]|$)/ { print }' || true)"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    pid="$(awk '{ print $1 }' <<<"$line")"
    command="$line"
    command="${command#"$pid"}"
    command="${command#"${command%%[![:space:]]*}"}"
    quarantine_foreign_worktree_pid "$pid" "$command" >/dev/null 2>&1 || true
  done <<<"$rows"
}

start_foreign_worktree_quarantine_guard() {
  quarantine_other_worktrees_enabled || exclusive_proof_run_enabled || return 0
  (
    while true; do
      terminate_foreign_proof_processes_for_exclusive_run quiet >/dev/null 2>&1 || true
      quarantine_foreign_smoke_processes "$(other_smoke_process_lines || true)" >/dev/null 2>&1 || true
      quarantine_foreign_steadytype_apps >/dev/null 2>&1 || true
      sleep "${AUTOCOMPLETE_LAB_QUARANTINE_GUARD_INTERVAL_SECONDS:-1}"
    done
  ) &
  SMOKE_QUARANTINE_GUARD_PID="$!"
}

current_process_ancestor_pids() {
  local pid="${BASHPID:-$$}"
  local parent
  local ancestors=()

  while parent="$(ps -o ppid= -p "$pid" 2>/dev/null || true)"; do
    parent="${parent//[[:space:]]/}"
    [[ -n "$parent" && "$parent" != "0" && "$parent" != "$pid" ]] || break
    ancestors+=("$parent")
    pid="$parent"
  done

  printf '%s\n' "${ancestors[@]}"
}

exclusive_proof_run_enabled() {
  [[ "$EXCLUSIVE_PROOF_RUN" =~ ^(1|true|yes|on)$ ]]
}

foreign_proof_process_lines() {
  local current_pgid protected_pgids
  current_pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d '[:space:]' || true)"
  protected_pgids="$(current_process_family_pgids | tr '\n' ' ' || true)"

  ps -axo pid=,pgid=,command= 2>/dev/null |
    while read -r pid pgid command; do
      [[ -n "$pid" && "$pid" != "$SMOKE_SCRIPT_PID" ]] || continue
      [[ -n "$current_pgid" && "$pgid" == "$current_pgid" ]] && continue
      case " $protected_pgids " in
        *" $pgid "*) continue ;;
      esac

      case "$command" in
        *script/real_app_smoke.sh*|*script/manual_proof_refresh.sh*|*script/obsidian_deep_sweep.sh*|*script/build_and_run.sh*|*script/local_quality_audit.py*|*script/local_completion_runtime.py*|*/SteadyType.app/Contents/MacOS/SteadyType*)
          ;;
        *)
          continue
          ;;
      esac

      local cwd
      cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true)"
      if [[ "$cwd" == "$ROOT_DIR"* ]]; then
        continue
      fi
      if [[ "$command" == "$ROOT_DIR"/dist/SteadyType.app/Contents/MacOS/SteadyType* ]]; then
        continue
      fi

      if [[ "$cwd" == */transcripted-autocomplete-lab* ||
            "$cwd" == /private/tmp/steadytype-* ||
            "$command" == */transcripted-autocomplete-lab/* ||
            "$command" == /private/tmp/steadytype-* ]]; then
        printf '%s\t%s\t%s\t%s\n' "$pid" "$pgid" "${cwd:-unknown-cwd}" "$command"
      fi
    done
}

terminate_foreign_proof_processes_for_exclusive_run() {
  local quiet="${1:-0}"
  exclusive_proof_run_enabled || return 0

  local lines
  lines="$(foreign_proof_process_lines || true)"
  [[ -n "$lines" ]] || return 0

  if [[ "$quiet" != "quiet" ]]; then
    echo "Exclusive proof run terminating foreign proof process(es):" >&2
    echo "$lines" >&2
  fi

  local pid pgid cwd command
  while IFS=$'\t' read -r pid pgid cwd command; do
    [[ -n "$pid" ]] || continue
    terminate_pid_tree "$pid"
  done <<<"$lines"

  sleep 1
}

other_smoke_process_lines() {
  local process_list ancestor_pids self_pgid protected_pgids
  ancestor_pids="$(current_process_ancestor_pids || true)"
  ancestor_pids="${ancestor_pids//$'\n'/ }"
  self_pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d '[:space:]' || true)"
  protected_pgids="$(current_process_family_pgids | tr '\n' ' ' || true)"
  if [[ "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST+x}" == "x" ]]; then
    process_list="$AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST"
  else
    process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"
  fi

  awk -v self="$SMOKE_SCRIPT_PID" -v selfPgid="$self_pgid" -v ancestorPids="$ancestor_pids" -v protectedPGIDs="$protected_pgids" '
    BEGIN {
      split(ancestorPids, rawAncestors, /[[:space:]]+/)
      for (i in rawAncestors) {
        if (rawAncestors[i] != "") {
          ancestor[rawAncestors[i]] = 1
        }
      }
      split(protectedPGIDs, protectedList, /[[:space:]]+/)
      for (i in protectedList) {
        if (protectedList[i] != "") {
          protected[protectedList[i]] = 1
        }
      }
    }
    {
      pid = $1
      ppid = $2
      pgid = $3
      command = $0
      rawLine[pid] = $0
      parent[pid] = ppid
      processGroup[pid] = pgid
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      readOnlyBetaReadiness[pid] = index(command, "script/beta_readiness.sh --check-only") > 0
      directScript[pid] = !readOnlyBetaReadiness[pid] && command ~ /^(\.\/)?script\/(real_app_smoke|fresh_latency_proof|smoke_test|build_and_run|beta_readiness|check_score_targets|check_controls_diagnostics_readiness|check_current_build_privacy_export)\.sh([[:space:]]|$)/
      shellWrapper = command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?(bash|zsh)|\/usr\/bin\/env[[:space:]]+(bash|zsh))([[:space:]]|$)/
      hasSmokeScript[pid] = index(command, "script/real_app_smoke.sh") > 0 ||
        index(command, "script/fresh_latency_proof.sh") > 0 ||
        index(command, "script/manual_proof_refresh.sh") > 0 ||
        index(command, "script/smoke_test.sh") > 0 ||
        index(command, "script/build_and_run.sh") > 0 ||
        index(command, "script/beta_readiness.sh") > 0 ||
        index(command, "script/check_score_targets.sh") > 0 ||
        index(command, "script/check_controls_diagnostics_readiness.sh") > 0 ||
        index(command, "script/check_current_build_privacy_export.sh") > 0
      if (readOnlyBetaReadiness[pid]) hasSmokeScript[pid] = 0
      shellHasSmokeScript[pid] = shellWrapper && hasSmokeScript[pid]
    }
    function relatedToSelf(pid, parentPid, depth) {
      if (selfPgid != "" && processGroup[pid] == selfPgid) return 1
      if (pid == self || pid in ancestor) return 1
      parentPid = pid
      for (depth = 0; depth < 128; depth++) {
        if (!(parentPid in parent)) return 0
        parentPid = parent[parentPid]
        if (parentPid == self) return 1
        if (parentPid == "" || parentPid == "0" || parentPid == parent[parentPid]) return 0
      }
      return 0
    }
    END {
      for (pid in rawLine) {
        if (relatedToSelf(pid)) continue
        if (processGroup[pid] in protected) continue
        if (directScript[pid] || shellHasSmokeScript[pid]) {
          print rawLine[pid]
        }
      }
    }
  ' <<<"$process_list"
}

current_process_family_pgids() {
  if [[ -n "${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_PROTECTED_PGIDS:-}" ]]; then
    tr ', ' '\n\n' <<<"$AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_PROTECTED_PGIDS" |
      awk 'NF && !seen[$1]++ { print $1 }'
  fi

  local pid="$SMOKE_SCRIPT_PID"
  local seen_pids=" "
  local row parent_pid pgid

  while [[ -n "$pid" && "$pid" != "0" && "$seen_pids" != *" $pid "* ]]; do
    seen_pids+="$pid "
    row="$(ps -o ppid=,pgid= -p "$pid" 2>/dev/null | awk 'NR == 1 { print $1 "\t" $2 }' || true)"
    [[ -z "$row" ]] && break

    IFS=$'\t' read -r parent_pid pgid <<<"$row"
    [[ -n "$pgid" ]] && printf '%s\n' "$pgid"
    [[ -z "$parent_pid" || "$parent_pid" == "$pid" ]] && break
    pid="$parent_pid"
  done | awk 'NF && !seen[$1]++ { print $1 }'
}

other_autocomplete_proof_pgids() {
  local process_list current_pgid protected_pgids
  current_pgid="$(ps -o pgid= -p "$SMOKE_SCRIPT_PID" 2>/dev/null | tr -d ' ' || true)"
  [[ -z "$current_pgid" ]] && return 0
  protected_pgids="$(current_process_family_pgids | tr '\n' ' ' || true)"
  process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"

  awk -v self="$SMOKE_SCRIPT_PID" -v selfPGID="$current_pgid" -v protectedPGIDs="$protected_pgids" -v rootDir="$ROOT_DIR" '
    BEGIN {
      split(protectedPGIDs, protectedList, " ")
      for (i in protectedList) {
        if (protectedList[i] != "") protected[protectedList[i]] = 1
      }
    }
    {
      pid = $1
      pgid = $3
      command = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
      directScript = command ~ /^(\.\/)?script\/(real_app_smoke|fresh_latency_proof|manual_proof_refresh|obsidian_deep_sweep|smoke_test|build_and_run)\.sh([[:space:]]|$)/
      shellWrapper = command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?(bash|zsh)|\/usr\/bin\/env[[:space:]]+(bash|zsh))([[:space:]]|$)/
      hasProofScript = index(command, "script/real_app_smoke.sh") > 0 ||
        index(command, "script/fresh_latency_proof.sh") > 0 ||
        index(command, "script/manual_proof_refresh.sh") > 0 ||
        index(command, "script/obsidian_deep_sweep.sh") > 0 ||
        index(command, "script/smoke_test.sh") > 0 ||
        index(command, "script/build_and_run.sh") > 0
      staleRootWatchdog = index(command, "stale_root") > 0 && index(command, rootDir) > 0
      if (pid == self) next
      if (selfPGID != "" && pgid == selfPGID) next
      if (pgid in protected) next
      if (directScript || (shellWrapper && hasProofScript) || staleRootWatchdog) {
        print pgid
      }
    }
  ' <<<"$process_list" | sort -u
}

terminate_other_autocomplete_proof_runs() {
  local pgid pgids=()
  terminate_stale_steadytype_app_bundles

  while IFS= read -r pgid; do
    [[ -z "$pgid" ]] && continue
    pgids+=("$pgid")
    ps -axo pid=,pgid= 2>/dev/null |
      awk -v pgid="$pgid" '$2 == pgid { print $1 }' |
      while IFS= read -r pid; do
        [[ -n "$pid" && "$pid" != "$SMOKE_SCRIPT_PID" ]] || continue
        kill -TERM "$pid" >/dev/null 2>&1 || true
      done
  done < <(other_autocomplete_proof_pgids)

  ((${#pgids[@]} == 0)) && return 0
  sleep 0.25

  for pgid in "${pgids[@]}"; do
    if ps -axo pgid= 2>/dev/null | awk -v pgid="$pgid" '$1 == pgid { found = 1; exit } END { exit found ? 0 : 1 }'; then
      ps -axo pid=,pgid= 2>/dev/null |
        awk -v pgid="$pgid" '$2 == pgid { print $1 }' |
        while IFS= read -r pid; do
          [[ -n "$pid" && "$pid" != "$SMOKE_SCRIPT_PID" ]] || continue
          kill -KILL "$pid" >/dev/null 2>&1 || true
        done
    fi
  done
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
    if [[ -n "$processes" ]] && quarantine_foreign_smoke_processes "$processes"; then
      sleep 1
      continue
    fi
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

make_claude_code_terminal_proof_dir() {
  local base_dir tmp_dir
  base_dir="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR:-}"
  if [[ -n "$base_dir" ]]; then
    base_dir="${base_dir%/}"
    mkdir -p "$base_dir"
    tmp_dir="$(mktemp -d "$base_dir/steadytype-claude-code-proof.XXXXXX")"
    printf '%s\n' "$tmp_dir"
    return 0
  fi

  base_dir="${TMPDIR:-/tmp}"
  base_dir="${base_dir%/}"
  tmp_dir="$(mktemp -d "$base_dir/steadytype-claude-code-proof.XXXXXX")"
  SMOKE_TMP_DIRS+=("$tmp_dir")
  printf '%s\n' "$tmp_dir"
}

claude_code_terminal_proof_title_for_dir() {
  local proof_dir="$1"
  printf 'Claude Code %s %s\n' "$(claude_code_proof_marker)" "${proof_dir##*/}"
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

MATCHED_LOG_LINE=0
wait_for_log_line_number() {
  local start_line="$1"
  local pattern="$2"
  local label="$3"
  local timeout_seconds="${4:-12}"
  local deadline=$((SECONDS + timeout_seconds))
  local matched_line

  while ((SECONDS <= deadline)); do
    if [[ -f "$LOG_PATH" ]]; then
      matched_line="$(awk -v start="$start_line" -v pattern="$pattern" '
        NR > start && $0 ~ pattern {
          print NR
          exit
        }
      ' "$LOG_PATH" 2>/dev/null || true)"
      if [[ -n "$matched_line" ]]; then
        MATCHED_LOG_LINE="$matched_line"
        return 0
      fi
    fi
    sleep 0.2
  done

  echo "Timed out waiting for $label." >&2
  echo "Pattern: $pattern" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

wait_for_log_line_number_optional() {
  local start_line="$1"
  local pattern="$2"
  local timeout_seconds="${3:-12}"
  local deadline=$((SECONDS + timeout_seconds))
  local matched_line
  MATCHED_LOG_LINE=0

  while ((SECONDS <= deadline)); do
    if [[ -f "$LOG_PATH" ]]; then
      matched_line="$(awk -v start="$start_line" -v pattern="$pattern" '
        NR > start && $0 ~ pattern {
          print NR
          exit
        }
      ' "$LOG_PATH" 2>/dev/null || true)"
      if [[ -n "$matched_line" ]]; then
        MATCHED_LOG_LINE="$matched_line"
        return 0
      fi
    fi
    sleep 0.2
  done

  return 1
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

wait_for_log_pattern_optional() {
  local start_line="$1"
  local pattern="$2"
  local timeout_seconds="${3:-12}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_matches "$start_line" "$pattern"; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

log_since_has_fields() {
  local start_line="$1"
  local prefix="$2"
  shift 2
  local lines
  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    start_line=0
  fi
  lines="$(sed -n "$((start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
    awk -v prefix="$prefix" '
    index($0, prefix) {
      print
    }
  ' 2>/dev/null || true)"
  local field
  for field in "$@"; do
    lines="$(grep -F "$field" <<<"$lines" || true)"
  done
  [[ -n "$lines" ]]
}

claude_code_terminal_suggestion_cancelled_by_screen_geometry() {
  local start_line="$1"
  log_since_has_fields "$start_line" "suggestion-request-cancelled" "reason=invalidate" &&
    log_since_has_fields "$start_line" "screen-geometry-changed" "geometryInvalidationReason=screen-layout-changed"
}

line_has_all_fields() {
  local line="$1"
  shift
  local field

  for field in "$@"; do
    [[ "$line" == *"$field"* ]] || return 1
  done
  return 0
}

find_claude_code_terminal_suggestion_line_optional() {
  local start_line="$1"
  local matched_line
  MATCHED_LOG_LINE=0

  [[ -f "$LOG_PATH" ]] || return 1
  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    start_line=0
  fi

  matched_line="$(sed -n "$((start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
    awk \
    -v start="$start_line" \
    -v host_variant="$CLAUDE_CODE_HOST_VARIANT" '
      {
        absolute_line = NR + start
        is_prompt_caret = index($0, "synthetic-caret") && index($0, "app=com.anthropic.claude-code") && index($0, "source=terminal-screen-prompt")
        is_terminal_proof_suggestion = index($0, "suggestion-presented") && index($0, "app=com.anthropic.claude-code") && index($0, "fieldKindReason=claude-code-terminal-host-proof") && index($0, "fieldKindSuppressed=false") && index($0, "placementAnchorSource=synthetic-caret")
      }

      is_prompt_caret != 0 {
        saw_terminal_screen_prompt = 1
      }

      {
        clear_candidate = 0
        if (index($0, "suggestion-hidden") && index($0, "app=com.anthropic.claude-code")) {
          clear_candidate = 1
        }
        if (index($0, "keyboard-action") && index($0, "app=com.anthropic.claude-code")) {
          clear_candidate = 1
        }
        if (index($0, "insert ") && index($0, "app=com.anthropic.claude-code")) {
          clear_candidate = 1
        }
        if (index($0, "screen-geometry-changed")) {
          clear_candidate = 1
        }
        if (index($0, "workspace-focus-changed app=com.apple.Terminal")) {
          clear_candidate = 1
        }
        if (candidate != "" && clear_candidate) {
          candidate = ""
        }
      }

      is_terminal_proof_suggestion == 0 {
        next
      }

      (host_variant == "ghostty") && (saw_terminal_screen_prompt == 0) {
        next
      }

      {
        candidate = absolute_line
        next
      }

      END {
        if (candidate != "") {
          print candidate
        }
      }
    ' 2>/dev/null || true)"

  if [[ -n "$matched_line" ]]; then
    MATCHED_LOG_LINE="$matched_line"
    return 0
  fi

  return 1
}

find_recent_claude_code_terminal_suggestion_line_optional() {
  local preferred_start_line="$1"
  local current_line recent_window_lines recent_start_line matched_line

  recent_window_lines="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_RECENT_SUGGESTION_SCAN_LINES:-260}"
  [[ "$recent_window_lines" =~ ^[0-9]+$ ]] || recent_window_lines=260
  current_line="$(line_count "$LOG_PATH")"
  recent_start_line=$((current_line > recent_window_lines ? current_line - recent_window_lines : 0))

  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    if ((recent_start_line < preferred_start_line)); then
      recent_start_line="$preferred_start_line"
    fi
    matched_line="$(sed -n "$((recent_start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
      awk \
      -v start="$recent_start_line" '
        {
          absolute_line = NR + start
          is_terminal_proof_suggestion = index($0, "suggestion-presented") && index($0, "app=com.anthropic.claude-code") && index($0, "fieldKindReason=claude-code-terminal-host-proof") && index($0, "fieldKindSuppressed=false") && index($0, "placementAnchorSource=synthetic-caret")
        }

      index($0, "synthetic-caret") && index($0, "app=com.anthropic.claude-code") && index($0, "source=terminal-screen-prompt") {
        saw_terminal_screen_prompt = 1
      }

      is_terminal_proof_suggestion != 0 {
        if (saw_terminal_screen_prompt == 0) {
          next
        }
        candidate = absolute_line
        next
      }

        {
          clear_candidate = 0
          if (index($0, "suggestion-hidden") && index($0, "app=com.anthropic.claude-code")) {
            clear_candidate = 1
          }
          if (index($0, "keyboard-action") && index($0, "app=com.anthropic.claude-code")) {
            clear_candidate = 1
          }
          if (index($0, "insert ") && index($0, "app=com.anthropic.claude-code")) {
            clear_candidate = 1
          }
          if (index($0, "screen-geometry-changed")) {
            clear_candidate = 1
          }
          if (index($0, "workspace-focus-changed app=com.apple.Terminal")) {
            clear_candidate = 1
          }
          if (candidate != "" && clear_candidate) {
            candidate = ""
          }
        }

        END {
          if (candidate != "") {
            print candidate
          }
        }
      ' 2>/dev/null || true)"

    if [[ -n "$matched_line" ]]; then
      MATCHED_LOG_LINE="$matched_line"
      return 0
    fi

    return 1
  fi

  if ((recent_start_line >= preferred_start_line)); then
    return 1
  fi

  find_claude_code_terminal_suggestion_line_optional "$recent_start_line"
}

wait_for_claude_code_terminal_suggestion_line_optional() {
  local start_line="$1"
  local timeout_seconds="${2:-12}"
  local deadline=$((SECONDS + timeout_seconds))
  MATCHED_LOG_LINE=0
  CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_CANCELLED_BY_GEOMETRY=0

  while ((SECONDS <= deadline)); do
    if find_claude_code_terminal_suggestion_line_optional "$start_line"; then
      return 0
    fi
    if find_recent_claude_code_terminal_suggestion_line_optional "$start_line"; then
      return 0
    fi
    if claude_code_terminal_suggestion_cancelled_by_screen_geometry "$start_line"; then
      CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_CANCELLED_BY_GEOMETRY=1
      return 1
    fi
    sleep 0.2
  done

  return 1
}

wait_for_claude_code_terminal_proof_suggestion_ready_optional() {
  local start_line="$1"
  local timeout_seconds="$2"

  if wait_for_claude_code_terminal_suggestion_line_optional \
    "$start_line" \
    "$timeout_seconds"; then
    return 0
  fi

  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    return 1
  fi

  wait_for_log_line_number_optional \
    "$start_line" \
    "suggestion-presented .*app=com.anthropic.claude-code .*fieldKindReason=claude-code-terminal-host-proof .*fieldKindSuppressed=false .*placementAnchorSource=synthetic-caret" \
    2
}

wait_for_claude_code_terminal_log_flush_suggestion_line_optional() {
  local start_line="$1"
  local timeout_seconds="${2:-8}"
  local deadline=$((SECONDS + timeout_seconds))
  MATCHED_LOG_LINE=0

  while ((SECONDS <= deadline)); do
    if find_claude_code_terminal_suggestion_line_optional "$start_line"; then
      return 0
    fi
    sleep 0.5
  done

  return 1
}

find_recent_claude_code_terminal_stale_proof_blocker_optional() {
  local preferred_start_line="$1"
  local current_line recent_window_lines recent_start_line matched
  MATCHED_LOG_LINE=0
  MATCHED_LOG_REASON=""

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -f "$LOG_PATH" ]] || return 1

  recent_window_lines="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_STALE_BLOCKER_SCAN_LINES:-700}"
  [[ "$recent_window_lines" =~ ^[0-9]+$ ]] || recent_window_lines=700
  current_line="$(line_count "$LOG_PATH")"
  recent_start_line=$((current_line > recent_window_lines ? current_line - recent_window_lines : 0))
  if [[ "$preferred_start_line" =~ ^[0-9]+$ && "$preferred_start_line" -gt 0 ]]; then
    recent_start_line=$((recent_start_line < preferred_start_line ? recent_start_line : preferred_start_line))
  fi

  matched="$(sed -n "$((recent_start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
    awk \
    -v start="$recent_start_line" '
      /suggestion-blocked/ && /app=com.anthropic.claude-code/ {
        reason = ""
        if (index($0, "reason=claude-code-terminal-host-missingProofMarker")) {
          reason = "missingProofMarker"
        } else if (index($0, "reason=claude-code-terminal-host-shellCommandDetected")) {
          reason = "shellCommandDetected"
        }
        if (reason != "") {
          candidate_line = NR + start
          candidate_reason = reason
        }
      }

      END {
        if (candidate_line != "") {
          print candidate_line "|" candidate_reason
        }
      }
    ' 2>/dev/null || true)"

  [[ -n "$matched" ]] || return 1
  MATCHED_LOG_LINE="${matched%%|*}"
  MATCHED_LOG_REASON="${matched#*|}"
  return 0
}

print_claude_code_terminal_suggestion_diagnostics_tail() {
  local start_line="$1"
  local host_name="$2"
  local attempt="$3"

  [[ -f "$LOG_PATH" ]] || return 0

  echo "Claude Code $host_name proof attempt $attempt recent prompt/suggestion diagnostics since line $start_line:" >&2
  awk -v start="$start_line" '
    NR <= start {
      next
    }

    /claude-code-terminal-host-proof-input/ ||
    (/synthetic-caret/ && /app=com.anthropic.claude-code/ && /source=terminal-screen-prompt/) ||
    (/suggestion-request-scheduled/ && /app=com.anthropic.claude-code/) ||
    (/mlx-completion/ && /app=com.anthropic.claude-code/) ||
    (/suggestion-presented/ && /app=com.anthropic.claude-code/) ||
    (/suggestion-blocked/ && /app=com.anthropic.claude-code/) ||
    /focused-text-poll-throttled/ ||
    /keyboard-event-tap-stopped/ {
      lines[++count] = NR ":" $0
      if (count > 18) {
        delete lines[count - 18]
      }
    }

    END {
      first = count - 17
      if (first < 1) {
        first = 1
      }
      for (i = first; i <= count; i++) {
        if (i in lines) {
          print lines[i]
        }
      }
    }
  ' "$LOG_PATH" >&2 2>/dev/null || true
}

wait_for_log_fields() {
  local start_line="$1"
  local label="$2"
  local timeout_seconds="$3"
  local prefix="$4"
  shift 4
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_has_fields "$start_line" "$prefix" "$@"; then
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
    if log_since_has_fields "$start_line" "$prefix" "$@"; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

settle_keyboard_event_tap_if_started() {
  local start_line="$1"
  local label="$2"

  if wait_for_log_fields_optional "$start_line" 2 "keyboard-event-tap-started"; then
    sleep "${AUTOCOMPLETE_LAB_EVENT_TAP_SETTLE_SECONDS:-0.2}"
  else
    echo "$label did not log a fresh keyboard-event-tap-started marker before accept; pressing anyway." >&2
  fi
}

codex_tab_diagnostic_seen() {
  local start_line="$1"

  log_since_has_fields "$start_line" \
    "keyboard-action" \
    "app=com.openai.codex" \
    "key=tab" ||
    log_since_has_fields "$start_line" \
      "keyboard-event-tap-latency" \
      "key=tab"
}

wait_for_codex_tab_diagnostic_optional() {
  local start_line="$1"
  local attempts="${2:-5}"
  local delay_seconds="${3:-0.05}"
  local attempt

  if ! [[ "$attempts" =~ ^[0-9]+$ ]] || ((attempts < 1)); then
    attempts=5
  fi

  for ((attempt = 0; attempt < attempts; attempt++)); do
    if codex_tab_diagnostic_seen "$start_line"; then
      return 0
    fi
    sleep "$delay_seconds"
  done

  return 1
}

press_codex_tab_for_smoke() {
  local start_line="$1"

  settle_keyboard_event_tap_if_started "$start_line" "Codex Tab acceptance"
  press_key_code_cgevent_with_timeout \
    48 \
    "${AUTOCOMPLETE_LAB_CODEX_CGEVENT_TAB_TIMEOUT_SECONDS:-2}" \
    "Codex CGEvent Tab" \
    "session" \
    "warm" || true

  if wait_for_codex_tab_diagnostic_optional "$start_line" \
    "${AUTOCOMPLETE_LAB_CODEX_CGEVENT_TAB_DIAGNOSTIC_ATTEMPTS:-5}" \
    "${AUTOCOMPLETE_LAB_CODEX_CGEVENT_TAB_DIAGNOSTIC_DELAY_SECONDS:-0.05}"; then
    return 0
  fi

  echo "Codex CGEvent Tab produced no key=tab diagnostic; retrying with System Events Tab." >&2
  assert_frontmost_app "Codex" "Codex proof System Events retry"
  press_key_code 48
}

keyboard_event_tap_active_since() {
  local start_line="$1"

  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    start_line=0
  fi

  awk -v start="$start_line" '
    NR <= start {
      next
    }
    /keyboard-event-tap-started/ {
      state = "started"
    }
    /keyboard-event-tap-stopped/ ||
    /keyboard-event-tap-start-failed/ ||
    /keyboard-event-tap-failed-closed/ {
      state = "stopped"
    }
    END {
      exit state == "started" ? 0 : 1
    }
  ' "$LOG_PATH" 2>/dev/null
}

assert_codex_full_accept_shortcut_safe() {
  local tap_start_line="$1"
  local suggestion_start_line="$2"
  local label="$3"

  if ! keyboard_event_tap_active_since "$tap_start_line"; then
    echo "$label keyboard capture is not active; refusing to press accept-all." >&2
    echo "Log: $LOG_PATH" >&2
    tail -n +"$((tap_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
    exit 1
  fi

  if log_since_has_fields "$suggestion_start_line" "suggestion-hidden" "app=com.openai.codex"; then
    echo "$label suggestion hid before accept-all; refusing to type the shortcut into Codex." >&2
    echo "Log: $LOG_PATH" >&2
    tail -n +"$((suggestion_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
    exit 1
  fi
}

press_codex_full_accept_shortcut_for_smoke() {
  local tap_start_line="$1"
  local suggestion_start_line="$2"
  local accept_shortcut="$3"
  local shortcut_start_line

  if wait_for_log_fields_optional "$suggestion_start_line" 2 "keyboard-event-tap-started"; then
    sleep "${AUTOCOMPLETE_LAB_EVENT_TAP_SETTLE_SECONDS:-0.2}"
  elif ! keyboard_event_tap_active_since "$tap_start_line"; then
    echo "Codex full accept did not start keyboard capture for the visible phrase." >&2
  fi
  assert_codex_full_accept_shortcut_safe "$tap_start_line" "$suggestion_start_line" "Codex full accept"
  shortcut_start_line="$(line_count "$LOG_PATH")"
  case "$accept_shortcut" in
    backtick)
      press_key_code_cgevent_with_timeout \
        50 \
        "${AUTOCOMPLETE_LAB_CODEX_FULL_ACCEPT_CGEVENT_BACKTICK_TIMEOUT_SECONDS:-2}" \
        "Codex full accept CGEvent backtick" \
        "session" \
        "warm"
      ;;
    optionTab)
      press_accept_all_shortcut
      ;;
  esac

  if ! wait_for_log_fields_optional "$shortcut_start_line" 1 \
    "keyboard-event-tap-latency" \
    "key=$accept_shortcut"; then
    echo "Codex full accept shortcut produced no key diagnostic." >&2
    echo "Required fields: keyboard-action app=com.openai.codex key=$accept_shortcut action=acceptAllVisible handled=true" >&2
    echo "Log: $LOG_PATH" >&2
    tail -n +"$((tap_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
    exit 1
  fi

  if wait_for_log_fields_optional "$shortcut_start_line" 1 \
    "keyboard-event-tap-latency" \
    "key=$accept_shortcut" \
    "decision=passthrough-unsupported"; then
    echo "Codex full accept shortcut passed through instead of being captured." >&2
    echo "Required fields: keyboard-action app=com.openai.codex key=$accept_shortcut action=acceptAllVisible handled=true" >&2
    echo "Log: $LOG_PATH" >&2
    tail -n +"$((tap_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
    exit 1
  fi
}

wait_for_claude_code_terminal_tab_acceptance() {
  local start_line="$1"
  local host_name="$2"
  local timeout_seconds="$3"
  local deadline

  timeout_seconds="${timeout_seconds%%.*}"
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || ((timeout_seconds < 1)); then
    timeout_seconds=30
  fi
  deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_has_fields "$start_line" \
      "keyboard-action" \
      "app=com.anthropic.claude-code" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=true"; then
      return 0
    fi

    if log_since_has_fields "$start_line" \
      "keyboard-action" \
      "app=com.anthropic.claude-code" \
      "key=tab" \
      "action=acceptNextWord" \
      "handled=false"; then
      echo "Claude Code $host_name Tab acceptance failed closed." >&2
      echo "Required fields: keyboard-action app=com.anthropic.claude-code key=tab action=acceptNextWord handled=true" >&2
      echo "Observed handled=false; the app consumed Tab and refused to insert unverified text." >&2
      echo "Log: $LOG_PATH" >&2
      tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
      exit 1
    fi

    if log_since_has_fields "$start_line" \
      "keyboard-event-tap-latency" \
      "key=tab" \
      "decision=passthrough-after-typing"; then
      echo "Claude Code $host_name Tab acceptance went stale before the app could accept it." >&2
      echo "Required fields: keyboard-action app=com.anthropic.claude-code key=tab action=acceptNextWord handled=true" >&2
      echo "Observed keyboard-event-tap-latency key=tab decision=passthrough-after-typing." >&2
      echo "Log: $LOG_PATH" >&2
      tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
      exit 1
    fi

    sleep 0.2
  done

  echo "Timed out waiting for Claude Code $host_name Tab acceptance." >&2
  echo "Required fields: keyboard-action app=com.anthropic.claude-code key=tab action=acceptNextWord handled=true" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

wait_for_claude_code_terminal_insertion_result() {
  local start_line="$1"
  local host_name="$2"
  local timeout_seconds="$3"
  local proof_text="${4:-}"
  local deadline

  timeout_seconds="${timeout_seconds%%.*}"
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || ((timeout_seconds < 1)); then
    timeout_seconds=30
  fi
  deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if log_since_has_fields "$start_line" \
      "insert" \
      "app=com.anthropic.claude-code" \
      "success=true"; then
      return 0
    fi

    if log_since_has_fields "$start_line" \
      "insert" \
      "app=com.anthropic.claude-code" \
      "success=false" ||
       log_since_has_fields "$start_line" \
         "claude-code-terminal-host-proof-deferred-accept" \
         "app=com.anthropic.claude-code" \
         "stage=insert-failed" ||
       log_since_has_fields "$start_line" \
         "claude-code-terminal-host-proof-insert" \
         "app=com.anthropic.claude-code" \
         "source=ghosttyFastFailClosed"; then
      echo "Claude Code $host_name insertion failed closed." >&2
      echo "Required fields: insert app=com.anthropic.claude-code success=true" >&2
      echo "Observed insertion failure or fail-closed Ghostty proof diagnostics." >&2
      run_claude_code_ghostty_post_fail_external_insertion_probe "$proof_text" "$start_line" || true
      echo "Log: $LOG_PATH" >&2
      tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 100 >&2
      exit 1
    fi

    sleep 0.2
  done

  echo "Timed out waiting for Claude Code $host_name insertion result." >&2
  echo "Required fields: insert app=com.anthropic.claude-code success=true or success=false" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 100 >&2
  exit 1
}

find_claude_code_terminal_prompt_caret_point_optional() {
  local start_line="$1"
  local matched
  CLAUDE_CODE_TERMINAL_PROMPT_CARET_X=""
  CLAUDE_CODE_TERMINAL_PROMPT_CARET_Y=""
  CLAUDE_CODE_TERMINAL_PROMPT_CARET_WIDTH=""
  CLAUDE_CODE_TERMINAL_PROMPT_CARET_HEIGHT=""

  [[ -f "$LOG_PATH" ]] || return 1
  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    start_line=0
  fi

  matched="$(sed -n "$((start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
    awk '
      /synthetic-caret/ && /app=com.anthropic.claude-code/ && /source=terminal-screen-prompt/ {
        for (fieldIndex = 1; fieldIndex <= NF; fieldIndex++) {
          if (index($fieldIndex, "caret=x=") == 1) {
            caret = substr($fieldIndex, length("caret=x=") + 1)
            split(caret, parts, ",")
            x = parts[1]
            y = parts[2]
            w = parts[3]
            h = parts[4]
            sub(/^y=/, "", y)
            sub(/^w=/, "", w)
            sub(/^h=/, "", h)
            candidate = x " " y " " w " " h
          }
        }
      }

      END {
        if (candidate != "") {
          print candidate
        }
      }
    ' 2>/dev/null || true)"

  [[ -n "$matched" ]] || return 1
  read -r CLAUDE_CODE_TERMINAL_PROMPT_CARET_X \
    CLAUDE_CODE_TERMINAL_PROMPT_CARET_Y \
    CLAUDE_CODE_TERMINAL_PROMPT_CARET_WIDTH \
    CLAUDE_CODE_TERMINAL_PROMPT_CARET_HEIGHT <<<"$matched"

  [[ "$CLAUDE_CODE_TERMINAL_PROMPT_CARET_X" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "$CLAUDE_CODE_TERMINAL_PROMPT_CARET_Y" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || return 1
  [[ "$CLAUDE_CODE_TERMINAL_PROMPT_CARET_WIDTH" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || CLAUDE_CODE_TERMINAL_PROMPT_CARET_WIDTH=0
  [[ "$CLAUDE_CODE_TERMINAL_PROMPT_CARET_HEIGHT" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || CLAUDE_CODE_TERMINAL_PROMPT_CARET_HEIGHT=0
}

click_screen_point_cgevent() {
  local x="$1"
  local y="$2"
  local label="$3"

  swift - "$x" "$y" <<'SWIFT' >/dev/null
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]),
      x.isFinite,
      y.isFinite,
      let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("screen point CGEvent click failed: invalid point or event source.\n", stderr)
    exit(1)
}

let point = CGPoint(x: x, y: y)
let events: [(CGEventType, useconds_t)] = [
    (.mouseMoved, 20_000),
    (.leftMouseDown, 35_000),
    (.leftMouseUp, 80_000),
]

for (eventType, delay) in events {
    guard let event = CGEvent(
        mouseEventSource: source,
        mouseType: eventType,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        fputs("screen point CGEvent click failed: could not create mouse event.\n", stderr)
        exit(1)
    }
    event.post(tap: .cghidEventTap)
    usleep(delay)
}
SWIFT
}

click_claude_code_ghostty_post_fail_prompt_caret() {
  local start_line="$1"
  local click_x click_y

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  if ! find_claude_code_terminal_prompt_caret_point_optional "$start_line"; then
    echo "Claude Code Ghostty post-fail prompt-row refocus found no synthetic caret to click." >&2
    return 1
  fi

  click_x="$(awk \
    -v x="$CLAUDE_CODE_TERMINAL_PROMPT_CARET_X" \
    -v w="$CLAUDE_CODE_TERMINAL_PROMPT_CARET_WIDTH" \
    'BEGIN { offset = w + 0; if (offset < 1) offset = 1; printf "%.0f", x + offset }')"
  click_y="$(awk \
    -v y="$CLAUDE_CODE_TERMINAL_PROMPT_CARET_Y" \
    -v h="$CLAUDE_CODE_TERMINAL_PROMPT_CARET_HEIGHT" \
    'BEGIN { offset = (h + 0) / 2; if (offset < 1) offset = 1; printf "%.0f", y + offset }')"

  echo "Claude Code Ghostty post-fail prompt-row refocus clicking latest synthetic caret at x=$click_x y=$click_y before System Events probe." >&2
  focus_claude_code_ghostty_proof_window_by_title || return 1
  click_screen_point_cgevent "$click_x" "$click_y" "Claude Code Ghostty post-fail prompt-row refocus"
}

press_claude_code_terminal_external_backspace_key() {
  local label="${1:-external mutation restore}"

  settle_claude_code_terminal_proof_focus "$label" || return 1
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_RESTORE_TIMEOUT_SECONDS:-2}" \
      "Claude Code Ghostty pre-accept external restore" <<'APPLESCRIPT'
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof restore."
  end if
  key code 51
end tell
APPLESCRIPT
}

restore_claude_code_terminal_system_events_backspace() {
  local proof_text="$1"
  local label="${2:-external mutation restore}"
  [[ -n "$proof_text" ]] || return 1
  press_claude_code_terminal_external_backspace_key "$label"
}

restore_claude_code_terminal_ghostty_native_prompt_text() {
  local proof_text="$1"
  local label="${2:-native mutation restore}"
  local clear_delay="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY_SECONDS:-0.12}"

  [[ -n "$proof_text" ]] || return 1
  focus_claude_code_ghostty_proof_window_by_title || return 1
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_RESTORE_TEXT="$proof_text" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY="$clear_delay" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_RESTORE_TIMEOUT_SECONDS:-4}" \
      "$label" <<'APPLESCRIPT' >/dev/null
set restoreText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_RESTORE_TEXT"
set clearDelay to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY") as real
tell application id "com.mitchellh.ghostty"
  set targetWindow to front window
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  focus targetTerminal
  send key "u" modifiers "control" to targetTerminal
  delay clearDelay
  send key "u" modifiers "control" to targetTerminal
  delay clearDelay
  input text restoreText to targetTerminal
  activate
end tell
APPLESCRIPT
}

run_claude_code_ghostty_pre_accept_external_mutation_probe_one() {
  local proof_text="$1"
  local label="$2"
  local probe_text="$3"
  local type_function="$4"
  local restore_function="${5:-restore_claude_code_terminal_system_events_backspace}"
  local verify_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_VERIFY_SECONDS:-3}"

  [[ -n "$probe_text" ]] || return 0
  if [[ "$probe_text" == *$'\n'* || "$probe_text" == *$'\r'* || ${#probe_text} -ne 1 ]]; then
    echo "Claude Code Ghostty pre-accept external $label mutability probe refused non-single-character text." >&2
    return 0
  fi

  echo "Claude Code Ghostty pre-accept external $label mutability probe typing one suffix without Enter." >&2
  if ! "$type_function" "$probe_text"; then
    echo "Claude Code Ghostty pre-accept external $label mutability probe could not post input." >&2
    return 0
  fi
  sleep "$(claude_code_ghostty_typing_drain_seconds)"

  if try_claude_code_terminal_prompt_ready_bounded_quiet \
    "$proof_text$probe_text" \
    "$verify_seconds" \
    "Claude Code Ghostty pre-accept external $label mutation readiness"; then
    echo "Claude Code Ghostty pre-accept external $label mutability probe verified prompt mutation before app-owned insertion." >&2
    if ! "$restore_function" "$proof_text" "Ghostty pre-accept $label restore"; then
      echo "Claude Code Ghostty pre-accept external $label mutability probe could not restore the original prompt." >&2
      return 1
    fi
    sleep "$(claude_code_ghostty_typing_drain_seconds)"
    if try_claude_code_terminal_prompt_ready_bounded_quiet \
      "$proof_text" \
      "$verify_seconds" \
      "Claude Code Ghostty pre-accept external $label restore readiness"; then
      echo "Claude Code Ghostty pre-accept external $label mutability probe restored the original prompt." >&2
      return 0
    fi
    echo "Claude Code Ghostty pre-accept external $label mutability probe could not verify original prompt restore." >&2
    return 1
  fi

  echo "Claude Code Ghostty pre-accept external $label mutability probe did not verify prompt mutation." >&2
  if try_claude_code_terminal_prompt_ready_bounded_quiet \
    "$proof_text" \
    "$verify_seconds" \
    "Claude Code Ghostty pre-accept external $label unchanged readiness"; then
    return 0
  fi
  echo "Claude Code Ghostty pre-accept external $label mutability probe left the prompt in an unverified state." >&2
  return 1
}

run_claude_code_ghostty_pre_accept_external_mutation_probe() {
  local proof_text="$1"
  local native_probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_TEXT:-n}"
  local system_events_probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_TEXT:-s}"

  CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE_RAN=0
  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE:-0}" =~ ^(1|true|yes|on)$ ]] || return 0
  [[ -n "$proof_text" ]] || return 0

  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" =~ ^(1|true|yes|on)$ ]] &&
     [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_PRE_ACCEPT_PROBE:-0}" =~ ^(1|true|yes|on)$ ]]; then
    echo "Claude Code Ghostty pre-accept external mutability probe skipped for proof-only accept driver; set AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_PRE_ACCEPT_PROBE=1 to opt in." >&2
    return 0
  fi

  CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE_RAN=1

  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_PROBE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    run_claude_code_ghostty_pre_accept_external_mutation_probe_one \
      "$proof_text" \
      "native" \
      "$native_probe_text" \
      type_claude_code_terminal_ghostty_native_text \
      restore_claude_code_terminal_ghostty_native_prompt_text || return 1
  fi

  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    run_claude_code_ghostty_pre_accept_external_mutation_probe_one \
      "$proof_text" \
      "System Events" \
      "$system_events_probe_text" \
      type_claude_code_terminal_raw_smoke_text \
      restore_claude_code_terminal_system_events_backspace || return 1
  fi
}

run_claude_code_ghostty_post_tab_pre_insert_external_mutation_probe() {
  local proof_text="$1"
  local start_line="$2"
  local native_probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_TEXT:-p}"
  local system_events_probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_TEXT:-q}"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE:-0}" =~ ^(1|true|yes|on)$ ]] || return 0
  [[ -n "$proof_text" ]] || return 0

  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" =~ ^(1|true|yes|on)$ ]] &&
     [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_POST_TAB_PROBE:-0}" =~ ^(1|true|yes|on)$ ]]; then
    echo "Claude Code Ghostty post-Tab/pre-insert external mutability probe skipped for proof-only accept driver; set AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_POST_TAB_PROBE=1 to opt in." >&2
    return 0
  fi

  if ! wait_for_log_fields_optional \
    "$start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_SCHEDULE_SECONDS:-1}" \
    "claude-code-terminal-host-proof-deferred-accept" \
    "app=com.anthropic.claude-code" \
    "stage=scheduled"; then
    echo "Claude Code Ghostty post-Tab/pre-insert external mutability probe saw no deferred insert schedule yet; skipping comparator." >&2
    return 0
  fi

  echo "Claude Code Ghostty post-Tab/pre-insert external mutability probe checking whether the prompt is still externally writable before SteadyType insertion." >&2
  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    run_claude_code_ghostty_pre_accept_external_mutation_probe_one \
      "$proof_text" \
      "post-Tab/pre-insert native" \
      "$native_probe_text" \
      type_claude_code_terminal_ghostty_native_text \
      restore_claude_code_terminal_ghostty_native_prompt_text || return 1
  fi

  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    run_claude_code_ghostty_pre_accept_external_mutation_probe_one \
      "$proof_text" \
      "post-Tab/pre-insert System Events" \
      "$system_events_probe_text" \
      type_claude_code_terminal_raw_smoke_text \
      restore_claude_code_terminal_system_events_backspace || return 1
  fi
}

run_claude_code_ghostty_post_fail_external_insertion_probe() {
  local proof_text="$1"
  local start_line="${2:-0}"
  local probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_TEXT:-x}"
  local system_events_probe_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_TEXT:-z}"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE:-0}" =~ ^(1|true|yes|on)$ ]] || return 0
  [[ -n "$proof_text" ]] || return 0
  [[ -n "$probe_text" ]] || return 0
  if [[ "$probe_text" == *$'\n'* || "$probe_text" == *$'\r'* ]]; then
    echo "Claude Code Ghostty post-fail external insertion probe refused multiline text." >&2
    return 0
  fi

  echo "Claude Code Ghostty post-fail external native insertion probe typing one suffix without Enter." >&2
  if ! type_claude_code_terminal_ghostty_native_text "$probe_text"; then
    echo "Claude Code Ghostty post-fail external native insertion probe could not post input." >&2
    return 0
  fi
  sleep "$(claude_code_ghostty_typing_drain_seconds)"

  if try_claude_code_terminal_prompt_ready_quiet \
    "$proof_text$probe_text" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_VERIFY_SECONDS:-3}"; then
    echo "Claude Code Ghostty post-fail external native insertion probe verified prompt mutation after app-owned insertion failed." >&2
    return 0
  else
    echo "Claude Code Ghostty post-fail external native insertion probe did not verify prompt mutation." >&2
  fi

  click_claude_code_ghostty_post_fail_prompt_caret "$start_line" || true

  [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE:-1}" =~ ^(1|true|yes|on)$ ]] || return 0
  [[ -n "$system_events_probe_text" ]] || return 0
  if [[ "$system_events_probe_text" == *$'\n'* || "$system_events_probe_text" == *$'\r'* ]]; then
    echo "Claude Code Ghostty post-fail external System Events insertion probe refused multiline text." >&2
    return 0
  fi

  echo "Claude Code Ghostty post-fail external System Events insertion probe typing one suffix without Enter." >&2
  if ! type_claude_code_terminal_raw_smoke_text "$system_events_probe_text"; then
    echo "Claude Code Ghostty post-fail external System Events insertion probe could not post input." >&2
    return 0
  fi
  sleep "$(claude_code_ghostty_typing_drain_seconds)"

  if try_claude_code_terminal_prompt_ready_quiet \
    "$proof_text$system_events_probe_text" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_VERIFY_SECONDS:-3}" ||
    try_claude_code_terminal_prompt_ready_quiet \
      "$proof_text$probe_text$system_events_probe_text" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_VERIFY_SECONDS:-3}"; then
    echo "Claude Code Ghostty post-fail external System Events insertion probe verified prompt mutation after app-owned insertion failed." >&2
  else
    echo "Claude Code Ghostty post-fail external System Events insertion probe did not verify prompt mutation." >&2
  fi
}

wait_for_obsidian_long_note_second_suggestion() {
  local start_line="$1"
  local expected_before_chars="$2"
  local timeout_seconds="${3:-12}"
  local deadline=$((SECONDS + timeout_seconds))
  local max_before_chars=$((expected_before_chars + 2))
  local min_before_chars=$((expected_before_chars - 1))
  local min_visible_before_chars=40
  if (( min_before_chars < 0 )); then
    min_before_chars=0
  fi

  while ((SECONDS <= deadline)); do
    if python3 - "$LOG_PATH" "$start_line" "$min_before_chars" "$max_before_chars" "$min_visible_before_chars" <<'PY'
import re
import sys

path, start_line, min_before, max_before, min_visible_before = (
    sys.argv[1],
    int(sys.argv[2]),
    int(sys.argv[3]),
    int(sys.argv[4]),
    int(sys.argv[5]),
)
field_pattern = re.compile(r"(^| )([A-Za-z][A-Za-z0-9]*)=([^ ]+)")
try:
    with open(path, "r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if line_number <= start_line or "suggestion-presented" not in line:
                continue
            fields = {match.group(2): match.group(3) for match in field_pattern.finditer(line)}
            if fields.get("app") != "md.obsidian" or fields.get("afterChars") != "0":
                continue
            try:
                before_chars = int(fields.get("beforeChars", "-1"))
            except ValueError:
                continue
            full_document_match = min_before <= before_chars <= max_before
            visible_viewport_match = min_visible_before <= before_chars < min_before
            if full_document_match or visible_viewport_match:
                raise SystemExit(0)
except FileNotFoundError:
    pass
raise SystemExit(1)
PY
    then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Obsidian second suggestion." >&2
  echo "Required fields: suggestion-presented app=md.obsidian afterChars=0 and beforeChars=${expected_before_chars}±2 or visible viewport beforeChars>=${min_visible_before_chars}" >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

describe_textedit_model_latency_seed_miss() {
  local seed_start="$1"
  local window_title="$2"
  local sample_index="$3"
  local expected_seed="$4"
  local current_text frontmost

  current_text="$(textedit_document_text "$window_title")"
  frontmost="$(run_osascript_with_timeout 1 "frontmost app probe" -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null || true)"

  echo "TextEdit model latency seed $sample_index did not emit phrase-continuation-disabled before sampling; continuing to the live key trigger." >&2
  echo "Seed diagnostics: window=$window_title frontmost=${frontmost:-unknown} documentChars=${#current_text} expectedSeedChars=${#expected_seed}" >&2
  if [[ "$current_text" != "$expected_seed" ]]; then
    echo "Seed diagnostics: TextEdit document no longer matches the expected stable seed text." >&2
  fi
  echo "Recent TextEdit proof logs since seed start:" >&2
  tail -n +"$((seed_start + 1))" "$LOG_PATH" 2>/dev/null |
    grep -E "app=com\\.apple\\.TextEdit|workspace-focus-changed|focused-text|suggestion-|phrase-continuation-disabled|runtime|status accessibility" |
    tail -n 40 >&2 || true
}

assert_no_runtime_relaunch_since() {
  local guard_line="$1"
  local label="$2"

  if ! log_since_matches "$guard_line" "runtime-bootstrap"; then
    return 0
  fi

  echo "TextEdit model latency proof lost its tagged runtime before $label." >&2
  echo "A newer SteadyType runtime-bootstrap appeared after this proof launch began sampling, probably from another build/run or smoke process." >&2
  echo "Rerun textedit-model-latency when no other SteadyType build/run/smoke lane is active." >&2
  echo "Newer runtime launches:" >&2
  tail -n +"$((guard_line + 1))" "$LOG_PATH" 2>/dev/null |
    grep -F "runtime-bootstrap" |
    tail -n 5 >&2 || true
  exit 1
}

latest_runtime_bootstrap_line_number() {
  local latest_line
  latest_line="$(grep -n "runtime-bootstrap" "$LOG_PATH" 2>/dev/null | tail -n 1 | cut -d: -f1 || true)"
  if [[ "$latest_line" =~ ^[0-9]+$ ]]; then
    echo "$latest_line"
    return 0
  fi
  line_count "$LOG_PATH"
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

expected_frontmost_bundle_id() {
  local expected="$1"

  case "$expected" in
    "Claude") printf 'com.anthropic.claudefordesktop\n' ;;
    "Claude Code") printf 'com.anthropic.claude-code\n' ;;
    "Codex") printf 'com.openai.codex\n' ;;
    "Finder") printf 'com.apple.finder\n' ;;
    "Ghostty") printf 'com.mitchellh.ghostty\n' ;;
    "Google Chrome") printf 'com.google.Chrome\n' ;;
    "iTerm2") printf 'com.googlecode.iterm2\n' ;;
    "Notes") printf 'com.apple.Notes\n' ;;
    "Obsidian") printf 'md.obsidian\n' ;;
    "Terminal") printf 'com.apple.Terminal\n' ;;
    "TextEdit") printf 'com.apple.TextEdit\n' ;;
    "Warp") printf 'dev.warp.Warp-Stable\n' ;;
    com.*|dev.*|md.*) printf '%s\n' "$expected" ;;
    *) printf '\n' ;;
  esac
}

frontmost_app_identity_matches() {
  local identity="$1"
  local expected="$2"
  local frontmost_name="$identity"
  local frontmost_bundle=""
  local expected_bundle

  if [[ "$identity" == *$'\t'* ]]; then
    frontmost_name="${identity%%$'\t'*}"
    frontmost_bundle="${identity#*$'\t'}"
  fi

  expected_bundle="$(expected_frontmost_bundle_id "$expected")"

  [[ "$frontmost_name" == "$expected" ||
     "$frontmost_bundle" == "$expected" ||
     ( -n "$expected_bundle" && "$frontmost_bundle" == "$expected_bundle" ) ]]
}

describe_frontmost_app_identity() {
  local identity="$1"
  local frontmost_name="$identity"
  local frontmost_bundle=""

  if [[ "$identity" == *$'\t'* ]]; then
    frontmost_name="${identity%%$'\t'*}"
    frontmost_bundle="${identity#*$'\t'}"
  fi

  if [[ -n "$frontmost_bundle" ]]; then
    printf '%s (%s)\n' "$frontmost_name" "$frontmost_bundle"
  else
    printf '%s\n' "${frontmost_name:-unknown}"
  fi
}

try_wait_for_frontmost_app() {
  local expected="$1"
  local timeout_seconds="${2:-5}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    local frontmost
    frontmost="$(run_osascript_with_timeout 1 "frontmost app wait probe" \
      -e 'tell application "System Events"' \
      -e 'set frontIdentities to {}' \
      -e 'set frontProcesses to application processes whose frontmost is true' \
      -e 'repeat with frontProcess in frontProcesses' \
      -e 'set frontName to name of frontProcess' \
      -e 'set frontBundle to ""' \
      -e 'try' \
      -e 'set frontBundle to bundle identifier of frontProcess' \
      -e 'end try' \
      -e 'copy (frontName & (ASCII character 9) & frontBundle) to end of frontIdentities' \
      -e 'end repeat' \
      -e 'set AppleScript'\''s text item delimiters to (ASCII character 10)' \
      -e 'return frontIdentities as text' \
      -e 'end tell' 2>/dev/null || true)"
    while IFS= read -r frontmost_identity; do
      [[ -z "$frontmost_identity" ]] && continue
      if frontmost_app_identity_matches "$frontmost_identity" "$expected"; then
        return 0
      fi
    done <<<"$frontmost"
    sleep 0.2
  done

  return 1
}

wait_for_background_process() {
  local pid="$1"
  local timeout_seconds="$2"
  local label="$3"
  local deadline=$((SECONDS + timeout_seconds))
  local wait_status

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

  wait "$pid"
  wait_status=$?
  return "$wait_status"
}

run_osascript_with_timeout() {
  local timeout_seconds="$1"
  local label="$2"
  shift 2

  local run_dir stdout_path stderr_path osascript_stdin_path status
  local should_forward_stdin=0 arg
  run_dir="$(make_tmp_dir)"
  stdout_path="$run_dir/osascript-stdout.txt"
  stderr_path="$run_dir/osascript-stderr.txt"
  osascript_stdin_path="$run_dir/osascript-stdin.applescript"

  if (($# == 0)); then
    should_forward_stdin=1
  else
    for arg in "$@"; do
      if [[ "$arg" == "-" ]]; then
        should_forward_stdin=1
        break
      fi
    done
  fi

  if [[ "$should_forward_stdin" == "1" ]]; then
    cat >"$osascript_stdin_path"
    osascript "$@" <"$osascript_stdin_path" >"$stdout_path" 2>"$stderr_path" &
  else
    osascript "$@" >"$stdout_path" 2>"$stderr_path" &
  fi
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

app.activate(options: [.activateAllWindows])
SWIFT
  } &
  swift_activation_pid="$!"
  wait_for_background_process "$swift_activation_pid" 2 "Swift activation for pid $target_pid" >/dev/null 2>&1 || true

  if [[ "${AUTOCOMPLETE_LAB_SKIP_SYSTEM_EVENTS_PROCESS_ACTIVATION:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi

  if wait_for_appkit_activation_frontmost "$target_pid"; then
    return 0
  fi

  activate_process_id_osascript "$target_pid" &
  local osascript_pid="$!"
  wait_for_background_process "$osascript_pid" 2 "System Events process activation" >/dev/null 2>&1 || true
}

wait_for_appkit_activation_frontmost() {
  local expected_pid="$1"
  local attempts="${2:-5}"
  local attempt frontmost_pid

  for ((attempt = 0; attempt < attempts; attempt++)); do
    frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
    if [[ "$frontmost_pid" == "$expected_pid" ]]; then
      return 0
    fi
    sleep 0.1
  done

  return 1
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
  if try_wait_for_frontmost_app "$expected" 2; then
    return 0
  fi
  frontmost="$(run_osascript_with_timeout 2 "frontmost app assertion probe" \
    -e 'tell application "System Events"' \
    -e 'set frontProcess to first application process whose frontmost is true' \
    -e 'set frontName to name of frontProcess' \
    -e 'set frontBundle to ""' \
    -e 'try' \
    -e 'set frontBundle to bundle identifier of frontProcess' \
    -e 'end try' \
    -e 'return frontName & (ASCII character 9) & frontBundle' \
    -e 'end tell' 2>/dev/null || true)"
  if ! frontmost_app_identity_matches "$frontmost" "$expected"; then
    echo "$label lost focus before accept. Expected frontmost app '$expected', got '$(describe_frontmost_app_identity "$frontmost")'." >&2
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

app.activate(options: [.activateAllWindows])
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
  wait_for_frontmost_app "Obsidian" "${AUTOCOMPLETE_LAB_OBSIDIAN_ACTIVATION_WAIT_SECONDS:-5}"
}

settle_obsidian_focus_for_smoke() {
  local label="${1:-Obsidian}"

  activate_obsidian_for_smoke
  sleep "${AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_SETTLE_SECONDS:-0.25}"
  assert_frontmost_app "Obsidian" "$label"
}

reset_obsidian_zoom_for_smoke() {
  activate_obsidian_for_smoke
  osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events"
  tell application process "Obsidian"
    set frontmost to true
    click menu item "Actual Size" of menu "View" of menu bar item "View" of menu bar 1
  end tell
end tell
APPLESCRIPT
  sleep 0.2
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
  local bundle_id=""
  case "$CLAUDE_CODE_HOST_VARIANT" in
    auto)
      bundle_id="auto"
      ;;
    terminal)
      bundle_id="com.apple.Terminal"
      ;;
    iterm2)
      bundle_id="com.googlecode.iterm2"
      ;;
    warp)
      bundle_id="dev.warp.Warp"
      ;;
    ghostty)
      bundle_id="com.mitchellh.ghostty"
      ;;
    kitty)
      bundle_id="net.kovidgoyal.kitty"
      ;;
    alacritty)
      bundle_id="org.alacritty"
      ;;
    wezterm)
      bundle_id="com.github.wez.wezterm"
      ;;
  esac
  printf '%s\n' "$bundle_id" || true
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

drop_stale_same_value_launchctl_previous() {
  local key="$1"
  local previous_value="$2"
  local owned_value="$3"

  if [[ -n "$owned_value" && "$previous_value" == "$owned_value" ]]; then
    launchctl unsetenv "$key" >/dev/null 2>&1 || true
    return 0
  fi

  return 1
}

proof_scenario_is_smoke_owned() {
  local scenario="$1"

  case "$scenario" in
    codex-full-accept-no-submit|\
    textedit-model-latency|\
    textedit-default-model-latency|\
    chrome-*-model-latency|\
    codex-model-latency|\
    claude-code-model-latency|\
    claude-model-latency)
      return 0
      ;;
  esac

  return 1
}

prepare_default_proof_scenario_baseline() {
  local previous_scenario

  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    previous_scenario="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if proof_scenario_is_smoke_owned "$previous_scenario"; then
      previous_scenario=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$previous_scenario"
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi

  unset AUTOCOMPLETE_LAB_PROOF_SCENARIO
  launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY" >/dev/null 2>&1 || true
}

prepare_temporary_app_enablement() {
  local bundle_ids
  bundle_ids="$(smoke_target_bundle_ids | paste -sd, -)"
  if [[ -z "$bundle_ids" ]]; then
    return 0
  fi

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    TEMP_ENABLE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$TEMP_ENABLE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$TEMP_ENABLE_ENV_KEY" "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" "$bundle_ids"; then
      TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""
    fi
    TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_MODE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_MODE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_MODE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_MODE_ENV_KEY" "$PROOF_MODE_LAUNCHCTL_PREVIOUS" "$bundle_ids"; then
      PROOF_MODE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_MODE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS="$bundle_ids"
  export AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS="$bundle_ids"
  launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_MODE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  prepare_default_proof_scenario_baseline
  echo "Temporary app enablement for smoke: $bundle_ids"
  echo "Temporary proof mode for smoke: $bundle_ids"
  prepare_accept_all_shortcut_default
  prepare_proof_annoyance_learning_suppression

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

prepare_proof_annoyance_learning_suppression() {
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Proof smoke suppresses annoyance learning for synthetic proof keys."
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
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "textedit-model-latency"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-model-latency"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "textedit-model-latency" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "TextEdit model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "TextEdit model latency proof scenario: textedit-model-latency"
  echo "TextEdit model latency proof suppresses annoyance learning for synthetic event-tap probe keys."

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so model-latency proof mode only applies if the app was launched with this environment." >&2
  fi
}

prepare_chrome_model_latency_runtime_options() {
  local scenario="chrome-${CHROME_FIXTURE}-model-latency"
  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "$scenario"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$scenario" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Chrome $CHROME_FIXTURE model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "Chrome $CHROME_FIXTURE model latency proof scenario: $scenario"
  echo "Chrome $CHROME_FIXTURE model latency proof suppresses annoyance learning for synthetic event-tap probe keys."

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so Chrome model-latency proof mode only applies if the app was launched with this environment." >&2
  fi
}

prepare_codex_model_latency_runtime_options() {
  local scenario="codex-model-latency"
  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "$scenario"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$scenario" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Codex model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "Codex model latency proof scenario: $scenario"
  echo "Codex model latency proof suppresses annoyance learning for synthetic prompt refresh samples."

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so Codex model-latency proof mode only applies if the app was launched with this environment." >&2
  fi
}

prepare_codex_full_accept_runtime_options() {
  local scenario="codex-full-accept-no-submit"
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "$scenario"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$scenario" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Codex full accept no-submit proof scenario: $scenario"
  echo "Codex full accept no-submit proof keeps prompt-app full accept proof-only for this launch."
  echo "Codex full accept no-submit proof suppresses annoyance learning for synthetic prompt accept keys."
}

prepare_claude_code_model_latency_runtime_options() {
  local scenario="claude-code-model-latency"
  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "$scenario"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$scenario" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Claude Code model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "Claude Code model latency proof scenario: $scenario"
  echo "Claude Code model latency proof suppresses annoyance learning for synthetic terminal prompt refresh samples."

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so Claude Code model-latency proof mode only applies if the app was launched with this environment." >&2
  fi
}

prepare_claude_model_latency_runtime_options() {
  local scenario="claude-model-latency"
  if [[ "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "$PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_PHRASE_ENV_KEY" "$PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "$scenario"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "$PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"
  export AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1
  launchctl setenv "$PROOF_DISABLE_FAST_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "$scenario" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY" "1" >/dev/null 2>&1 || true
  echo "Claude model latency proof: fast word completions and phrase continuations disabled so every measured sample must hit the local word-completion model path."
  echo "Claude model latency proof scenario: $scenario"
  echo "Claude model latency proof suppresses annoyance learning for synthetic prompt refresh samples."

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so Claude model-latency proof mode only applies if the app was launched with this environment." >&2
  fi
}

prepare_default_model_latency_runtime_options() {
  if [[ "$PROOF_DISABLE_WORD_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_WORD_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_WORD_ENV_KEY" "$PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_WORD_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY" "$PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS" "1"; then
      PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_WAS_PREPARED=1
  fi
  if [[ "$PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    PROOF_SCENARIO_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$PROOF_SCENARIO_ENV_KEY" 2>/dev/null || true)"
    if drop_stale_same_value_launchctl_previous "$PROOF_SCENARIO_ENV_KEY" "$PROOF_SCENARIO_LAUNCHCTL_PREVIOUS" "textedit-default-model-latency"; then
      PROOF_SCENARIO_LAUNCHCTL_PREVIOUS=""
    fi
    PROOF_SCENARIO_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION=1
  export AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK=1
  export AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-default-model-latency"
  launchctl setenv "$PROOF_DISABLE_WORD_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY" "1" >/dev/null 2>&1 || true
  launchctl setenv "$PROOF_SCENARIO_ENV_KEY" "textedit-default-model-latency" >/dev/null 2>&1 || true
  echo "TextEdit default model latency proof: word completions and fast phrase fallback disabled so every measured phrase sample must hit the local model path."
  echo "TextEdit default model latency proof scenario: textedit-default-model-latency"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so default-model-latency proof mode only applies if the app was launched with this environment." >&2
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
    obsidian-pane)
      printf '%s.\n' "$marker"
      return 0
      ;;
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

obsidian_long_note_text_before_trigger() {
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_BASE:-Autocomplete Lab Obsidian proof}"
  local line

  printf '%s\n' "$marker"
  for line in $(seq 1 90); do
    printf 'Autocomplete Lab Obsidian scroll filler line %02d\n' "$line"
  done
  printf '%s\n' "$marker"
  printf 'Smoke proof feel'
}

obsidian_marker_text_area_count() {
  swift - <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let marker = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"] ?? "Autocomplete Lab Obsidian proof"
let normalizedMarker = normalizedWhitespace(marker)
let compactMarker = compactWhitespace(marker)

func normalizedWhitespace(_ value: String) -> String {
    value
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

func compactWhitespace(_ value: String) -> String {
    String(value.filter { !$0.isWhitespace })
}

func containsNormalized(_ haystack: String, _ needle: String) -> Bool {
    normalizedWhitespace(haystack).range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        || compactWhitespace(haystack).range(of: compactMarker, options: [.caseInsensitive, .diacriticInsensitive]) != nil
}

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
    var count = (role == kAXTextAreaRole as String && containsNormalized(value, normalizedMarker)) ? 1 : 0
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

  focus_obsidian_visible_tail_line
  set_obsidian_caret_to_value_end

  local attempt
  for attempt in 1 2 3; do
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
    if (( pane_count >= 2 )); then
      return 0
    fi
    focus_obsidian_visible_tail_line || true
  done

  echo "Could not verify two Obsidian editor panes for pane proof; marker text area count=$pane_count." >&2
  exit 3
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

cgevent_keypress_helper_path() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_CGEVENT_KEYPRESS_HELPER:-${TMPDIR:-/tmp}/steadytype-cgevent-keypress-v6}"
}

ensure_cgevent_keypress_helper() {
  local helper source swiftc_pid build_timeout_seconds
  helper="$(cgevent_keypress_helper_path)"
  if [[ -x "$helper" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$helper")"
  source="${helper}.$$.swift"
  cat >"$source" <<'SWIFT'
import ApplicationServices
import Foundation

guard CommandLine.arguments.count >= 2,
      CommandLine.arguments.count <= 4,
      let keyCode = UInt16(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: cgevent-keypress <keyCode> [hid|session|pid:<pid>] [hidSystem|combinedSession|private]\n".utf8))
    exit(1)
}

let tapArgument = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : "hid"
let targetPid: pid_t?
let tap: CGEventTapLocation?
if tapArgument.hasPrefix("pid:") {
    let pidString = String(tapArgument.dropFirst("pid:".count))
    guard let pid = Int32(pidString), pid > 0 else {
        FileHandle.standardError.write(Data("invalid target pid\n".utf8))
        exit(2)
    }
    targetPid = pid_t(pid)
    tap = nil
} else {
    targetPid = nil
    switch tapArgument {
    case "hid":
        tap = .cghidEventTap
    case "session":
        tap = .cgSessionEventTap
    default:
        FileHandle.standardError.write(Data("unknown CGEvent tap location\n".utf8))
        exit(2)
    }
}

let sourceArgument = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : "hidSystem"
let sourceState: CGEventSourceStateID
switch sourceArgument {
case "hidSystem":
    sourceState = .hidSystemState
case "combinedSession":
    sourceState = .combinedSessionState
case "private":
    sourceState = .privateState
default:
    FileHandle.standardError.write(Data("unknown CGEvent source state\n".utf8))
    exit(3)
}

guard let source = CGEventSource(stateID: sourceState),
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
    FileHandle.standardError.write(Data("failed to create CGEvent key press\n".utf8))
    exit(4)
}

keyDown.flags = []
keyUp.flags = []
if let targetPid {
    keyDown.postToPid(targetPid)
} else if let tap {
    keyDown.post(tap: tap)
}
usleep(20_000)
if let targetPid {
    keyUp.postToPid(targetPid)
} else if let tap {
    keyUp.post(tap: tap)
}
SWIFT

  build_timeout_seconds="${AUTOCOMPLETE_LAB_CGEVENT_KEYPRESS_HELPER_BUILD_TIMEOUT_SECONDS:-8}"
  build_timeout_seconds="${build_timeout_seconds%%.*}"
  if ! [[ "$build_timeout_seconds" =~ ^[0-9]+$ ]] || ((build_timeout_seconds < 1)); then
    build_timeout_seconds=8
  fi

  swiftc "$source" -o "$helper" &
  swiftc_pid="$!"
  if ! wait_for_background_process "$swiftc_pid" "$build_timeout_seconds" "CGEvent keypress helper compile"; then
    rm -f "$source" "$helper" >/dev/null 2>&1 || true
    return 1
  fi
  chmod 700 "$helper" >/dev/null 2>&1 || true
  rm -f "$source" >/dev/null 2>&1 || true
}

press_key_code_cgevent() {
  local key_code="$1"
  local helper

  ensure_cgevent_keypress_helper
  helper="$(cgevent_keypress_helper_path)"
  "$helper" "$key_code"
}

press_key_code_cgevent_with_timeout() {
  local key_code="$1"
  local timeout_seconds="$2"
  local label="$3"
  local tap_location="${4:-hid}"
  local warm_policy="${5:-compile}"
  local source_state="${6:-hidSystem}"
  local helper pid

  helper="$(cgevent_keypress_helper_path)"
  if [[ "$warm_policy" == "warm" && ! -x "$helper" ]]; then
    echo "$label helper is not warm; refusing to compile on the hot accept path." >&2
    return 1
  fi
  ensure_cgevent_keypress_helper
  "$helper" "$key_code" "$tap_location" "$source_state" &
  pid="$!"
  wait_for_background_process "$pid" "$timeout_seconds" "$label"
}

wait_for_claude_code_terminal_key_capture_modifier_probe() {
  local start_line="$1"

  wait_for_log_fields_optional \
    "$start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS:-1}" \
    "keyboard-event-tap-latency" \
    "key=other" \
    "decision=passthrough-modifier"
}

claude_code_terminal_key_capture_permission_ui_since() {
  local start_line="$1"

  [[ -f "$LOG_PATH" ]] || return 1
  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    start_line=0
  fi

  awk -v start="$start_line" '
    NR <= start {
      next
    }
    /workspace-focus-changed/ &&
      (/app=com.apple.accessibility.universalAccessAuthWarn/ ||
       /frontmostApp=com.apple.accessibility.universalAccessAuthWarn/ ||
       /app=com.apple.systempreferences/ ||
       /frontmostApp=com.apple.systempreferences/) {
      found = 1
      exit
    }
    END {
      exit found ? 0 : 1
    }
  ' "$LOG_PATH" 2>/dev/null
}

wait_for_claude_code_terminal_key_capture_permission_ui_since() {
  local start_line="$1"
  local timeout_seconds="${2:-1}"
  local deadline

  timeout_seconds="${timeout_seconds%%.*}"
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS <= deadline)); do
    if claude_code_terminal_key_capture_permission_ui_since "$start_line"; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

probe_claude_code_terminal_host_key_capture() {
  local host_name="${1:-$(claude_code_host_display_name)}"
  local key_capture_start_line probe_start_line proof_pid focus_seconds

  if [[ "$CLAUDE_CODE_HOST_VARIANT" != "ghostty" ||
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE:-1}" == "0" ]]; then
    return 0
  fi

  focus_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS:-2}"
  focus_seconds="${focus_seconds%%.*}"
  if ! [[ "$focus_seconds" =~ ^[0-9]+$ ]] || ((focus_seconds < 1)); then
    focus_seconds=2
  fi
  key_capture_start_line="$(line_count "$LOG_PATH")"

  if ! settle_claude_code_terminal_proof_focus "session key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before key capture probe"
    echo "Claude Code terminal host is not frontmost for key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name probing CGEvent session key capture with non-mutating Shift."
  if ! press_key_code_cgevent_with_timeout \
    56 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent session key-capture probe" \
    "session" \
    "warm"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent session key capture probe helper failed"
    return 1
  fi
  if wait_for_log_fields_optional \
    "$probe_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS:-1}" \
    "keyboard-event-tap-latency" \
    "key=other" \
    "decision=passthrough-modifier"; then
    return 0
  fi

  if ! settle_claude_code_terminal_proof_focus "HID key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before HID key capture probe"
    echo "Claude Code terminal host is not frontmost for HID key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name CGEvent session key capture probe produced no diagnostic; retrying with HID Shift."
  if ! press_key_code_cgevent_with_timeout \
    56 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent HID key-capture probe" \
    "hid" \
    "warm"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent HID key capture probe helper failed"
    return 1
  fi
  if wait_for_log_fields_optional \
    "$probe_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS:-1}" \
    "keyboard-event-tap-latency" \
    "key=other" \
    "decision=passthrough-modifier"; then
    return 0
  fi

  if ! settle_claude_code_terminal_proof_focus "combined-session key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before combined-session key capture probe"
    echo "Claude Code terminal host is not frontmost for combined-session key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name CGEvent HID key capture probe produced no diagnostic; retrying with combined-session Shift."
  if ! press_key_code_cgevent_with_timeout \
    56 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent combined-session key-capture probe" \
    "session" \
    "warm" \
    "combinedSession"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent combined-session key capture probe helper failed"
    return 1
  fi
  if wait_for_claude_code_terminal_key_capture_modifier_probe "$probe_start_line"; then
    return 0
  fi

  proof_pid="$(claude_code_ghostty_frontmost_proof_process_id_by_title 2>/dev/null || true)"
  proof_pid="$(printf '%s' "$proof_pid" | tr -dc '0-9')"
  if [[ -z "$proof_pid" ]]; then
    proof_pid="$(printf '%s\n' ${CLAUDE_CODE_TERMINAL_PROOF_PIDS:-} 2>/dev/null | head -n 1 | tr -dc '0-9')"
  fi
  if [[ -n "$proof_pid" ]]; then
    if ! settle_claude_code_terminal_proof_focus "PID-targeted key-capture probe" "$focus_seconds"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before PID-targeted key capture probe"
      echo "Claude Code terminal host is not frontmost for PID-targeted key capture probe." >&2
      return 1
    fi

    probe_start_line="$(line_count "$LOG_PATH")"
    echo "Claude Code $host_name combined-session key capture probe produced no diagnostic; retrying with PID-targeted Shift for Ghostty pid $proof_pid."
    if ! press_key_code_cgevent_with_timeout \
      56 \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
      "Claude Code $host_name CGEvent PID-targeted key-capture probe" \
      "pid:$proof_pid" \
      "warm"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent PID-targeted key capture probe helper failed"
      return 1
    fi
    if wait_for_claude_code_terminal_key_capture_modifier_probe "$probe_start_line"; then
      return 0
    fi
  else
    echo "Claude Code $host_name combined-session key capture probe produced no diagnostic; could not resolve a Ghostty proof pid for PID-targeted Shift." >&2
  fi

  if ! settle_claude_code_terminal_proof_focus "private-source session key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before private-source session key capture probe"
    echo "Claude Code terminal host is not frontmost for private-source session key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name key capture probes produced no diagnostic; retrying with private-source session Shift."
  if ! press_key_code_cgevent_with_timeout \
    56 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent private-source session key-capture probe" \
    "session" \
    "warm" \
    "private"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent private-source session key capture probe helper failed"
    return 1
  fi
  if wait_for_claude_code_terminal_key_capture_modifier_probe "$probe_start_line"; then
    return 0
  fi

  if ! settle_claude_code_terminal_proof_focus "private-source HID key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before private-source HID key capture probe"
    echo "Claude Code terminal host is not frontmost for private-source HID key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name private-source session key capture probe produced no diagnostic; retrying with private-source HID Shift."
  if ! press_key_code_cgevent_with_timeout \
    56 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent private-source HID key-capture probe" \
    "hid" \
    "warm" \
    "private"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent private-source HID key capture probe helper failed"
    return 1
  fi
  if wait_for_claude_code_terminal_key_capture_modifier_probe "$probe_start_line"; then
    return 0
  fi

  if [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE:-0}" =~ ^(1|true|yes|on)$ ]]; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="key capture probe did not reach event tap"
    echo "Claude Code $host_name key capture probes produced no diagnostic; skipping System Events Shift because it can trigger macOS permission UI. Set AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1 to opt in." >&2
    echo "Claude Code $host_name key capture probe did not reach the SteadyType event tap; refreshing the disposable prompt." >&2
    return 1
  fi

  if ! settle_claude_code_terminal_proof_focus "System Events key-capture probe" "$focus_seconds"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before System Events key capture probe"
    echo "Claude Code terminal host is not frontmost for System Events key capture probe." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name combined-session key capture probe produced no diagnostic; retrying with System Events Shift."
  if ! run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name System Events key-capture probe" <<'APPLESCRIPT'
tell application "System Events"
  key code 56
end tell
APPLESCRIPT
  then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="System Events key capture probe timed out"
    return 1
  fi
  if wait_for_claude_code_terminal_key_capture_modifier_probe "$probe_start_line"; then
    return 0
  fi

  if wait_for_claude_code_terminal_key_capture_permission_ui_since "$key_capture_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS:-2}"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="key capture probe lost focus to macOS permission UI"
    echo "Claude Code $host_name key capture probe lost focus to macOS Accessibility/System Settings permission UI before reaching the SteadyType event tap." >&2
    return 1
  fi

  CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="key capture probe did not reach event tap"
  echo "Claude Code $host_name key capture probe did not reach the SteadyType event tap; refreshing the disposable prompt." >&2
  return 1
}

cgevent_text_helper_path() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_CGEVENT_TEXT_HELPER:-${TMPDIR:-/tmp}/steadytype-cgevent-text-v1}"
}

ensure_cgevent_text_helper() {
  local helper source swiftc_pid build_timeout_seconds
  helper="$(cgevent_text_helper_path)"
  if [[ -x "$helper" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$helper")"
  source="${helper}.$$.swift"
  cat >"$source" <<'SWIFT'
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 2,
      let source = CGEventSource(stateID: .hidSystemState) else {
    FileHandle.standardError.write(Data("failed to create CGEvent text source\n".utf8))
    exit(1)
}

let text = CommandLine.arguments[1]
let delayMicros: useconds_t = 12_000

for character in text {
    var units = Array(String(character).utf16)
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        FileHandle.standardError.write(Data("failed to create CGEvent text key\n".utf8))
        exit(1)
    }

    keyDown.flags = []
    keyUp.flags = []
    keyDown.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
    keyUp.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
    keyDown.post(tap: .cghidEventTap)
    usleep(delayMicros)
    keyUp.post(tap: .cghidEventTap)
    usleep(delayMicros)
}
SWIFT

  build_timeout_seconds="${AUTOCOMPLETE_LAB_CGEVENT_TEXT_HELPER_BUILD_TIMEOUT_SECONDS:-8}"
  build_timeout_seconds="${build_timeout_seconds%%.*}"
  if ! [[ "$build_timeout_seconds" =~ ^[0-9]+$ ]] || ((build_timeout_seconds < 1)); then
    build_timeout_seconds=8
  fi

  swiftc "$source" -o "$helper" &
  swiftc_pid="$!"
  if ! wait_for_background_process "$swiftc_pid" "$build_timeout_seconds" "CGEvent text helper compile"; then
    rm -f "$source" "$helper" >/dev/null 2>&1 || true
    return 1
  fi
  chmod 700 "$helper" >/dev/null 2>&1 || true
  rm -f "$source" >/dev/null 2>&1 || true
}

type_text_cgevent() {
  local text="$1"
  local helper

  [[ -n "$text" ]] || return 0
  ensure_cgevent_text_helper
  helper="$(cgevent_text_helper_path)"
  "$helper" "$text"
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
    google-docs|notion|browser-webmail|browser-gmail|browser-outlook|browser-chatgpt|browser-slack|browser-discord)
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
    browser-webmail|browser-gmail|browser-outlook)
      printf 'Browser webmail is blocked until a disposable reply proves safe one-word Tab accept, no send, insertion verification, undo/recovery, latency, no sensitive-field leak, and screenshot-backed current-head evidence.\n'
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
        "aria-label": "Local real ProseMirror smoke fixture editor",
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

guard let source = CGEventSource(stateID: .hidSystemState) else {
    fputs("Chrome smoke focus failed: could not create a CGEvent source for pid \(pid).\n", stderr)
    exit(1)
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
guard let windowElement = smokeWindow ?? focusedWindow ?? firstWindow else {
    fputs("Chrome smoke focus failed: no accessible Chrome window for pid \(pid).\n", stderr)
    exit(1)
}
AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)

guard let windowBounds = bounds(for: windowElement) else {
    fputs("Chrome smoke focus failed: target Chrome window has no AX bounds for pid \(pid).\n", stderr)
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
        fputs("Chrome smoke focus failed: could not create click event for pid \(pid).\n", stderr)
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
    sleep 0.15
    chrome_focus_official_demo_editor_with_devtools "$fixture"
    return 0
  fi

  if [[ -n "$chrome_pid" ]]; then
    focus_chrome_process_window "$chrome_pid" "$click_x_offset" "$click_y_offset"
    chrome_focus_smoke_editor_with_devtools "$fixture" >/dev/null 2>&1 || true
    sleep 0.15
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
            title.hasPrefix("textedit-default-model-latency-") ||
            title.hasPrefix("autocomplete-lab-typing-soak-") ||
            title.hasPrefix("textedit-ax-retention-proof.") ||
            title.hasPrefix("textedit-retention-proof.")
    }() ? windows[0] : nil)

    if let window = targetWindow {
        app.activate(options: [.activateAllWindows])
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
            title.hasPrefix("textedit-default-model-latency-") ||
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
            title.hasPrefix("textedit-default-model-latency-") ||
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
    focus_textedit_smoke_editor "$window_title" >/dev/null 2>&1 || true
  fi

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
  local run_dir stdout_path stderr_path status swift_pid

  run_dir="$(make_tmp_dir)"
  stdout_path="$run_dir/textedit-ax-write-stdout.txt"
  stderr_path="$run_dir/textedit-ax-write-stderr.txt"

  swift - "$window_title" "$text" >"$stdout_path" 2>"$stderr_path" <<'SWIFT' &
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
  swift_pid="$!"

  if wait_for_background_process "$swift_pid" "${AUTOCOMPLETE_LAB_TEXTEDIT_AX_WRITE_TIMEOUT_SECONDS:-5}" "TextEdit AX value replacement"; then
    cat "$stdout_path"
    return 0
  fi

  status=$?
  cat "$stderr_path" >&2 || true
  return "$status"
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
        title.hasPrefix("textedit-default-model-latency-") ||
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

dismiss_textedit_proof_suggestion() {
  local window_title="$1"
  local expected_text="$2"
  local label="$3"

  assert_textedit_frontmost_window "$window_title" "$label"
  run_osascript_with_timeout 2 "$label" <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  key code 53
end tell
APPLESCRIPT
  wait_for_textedit_document_exact "$window_title" "$expected_text" "$label unchanged" 3
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
    echo "TextEdit native completion suffix during $label was unexpectedly long ($suffix_length chars); falling back to AX replacement." >&2
    set_textedit_document_text "$window_title" "$expected_text" || true
    wait_for_textedit_document_exact "$window_title" "$expected_text" "$label native completion fallback" 5
    return 0
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

normalize_textedit_typed_seed_for_proof() {
  local window_title="$1"
  local expected_text="$2"
  local label="$3"

  set_textedit_document_text "$window_title" "$expected_text" || true
  if ! wait_for_textedit_document_exact_or_return "$window_title" "$expected_text" 2; then
    trim_textedit_native_completion_suffix "$window_title" "$expected_text" "$label typed seed normalize"
  fi
  wait_for_textedit_document_exact "$window_title" "$expected_text" "$label typed seed normalize" 5
  move_textedit_caret_to_document_end "$window_title"
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

textedit_smoke_allows_ax_proof_typing() {
  [[ "${AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION:-0}" =~ ^(1|true|yes|on)$ ]]
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
let insertionText = CommandLine.arguments[2]

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

func selectedTextRange(in element: AXUIElement) -> CFRange? {
    guard let value = copyAttribute(element, kAXSelectedTextRangeAttribute) else {
        return nil
    }
    var range = CFRange(location: 0, length: 0)
    guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
        return nil
    }
    return range
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
        let insertionRange = selectedTextRange(in: textInput) ?? CFRange(location: currentValue.utf16.count, length: 0)
        guard setSelectedTextRange(insertionRange, in: textInput) else {
            exit(1)
        }
        guard AXUIElementSetAttributeValue(textInput, kAXSelectedTextAttribute as CFString, insertionText as CFString) == .success else {
            exit(1)
        }
        let caretRange = CFRange(location: insertionRange.location + insertionText.utf16.count, length: 0)
        guard setSelectedTextRange(caretRange, in: textInput) else {
            exit(1)
        }
        exit(0)
    }
}

exit(1)
SWIFT
}

type_textedit_smoke_fragment() {
  local window_title="$1"
  local fragment="$2"
  local attempt

  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  move_textedit_caret_to_document_end "$window_title"
  if textedit_smoke_allows_ax_proof_typing && insert_textedit_smoke_fragment "$window_title" "$fragment"; then
    move_textedit_caret_to_document_end "$window_title"
    return 0
  fi

  for attempt in 1 2; do
    focus_textedit_smoke_editor "$window_title"
    click_textedit_smoke_editor "$window_title"
    move_textedit_caret_to_document_end "$window_title"
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
    if wait_for_background_process "$osascript_pid" "${AUTOCOMPLETE_LAB_TEXTEDIT_KEY_TYPING_TIMEOUT_SECONDS:-4}" "TextEdit proof key typing"; then
      return 0
    fi
    if ((attempt == 1)); then
      echo "TextEdit proof typing lost focus; refocusing smoke window and retrying once." >&2
      sleep 0.25
      continue
    fi
    return 1
  done
}

press_textedit_event_tap_probe_key() {
  (
    osascript <<'APPLESCRIPT'
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.apple.TextEdit" then
    error "TextEdit is not frontmost for event-tap proof typing."
  end if
  key code 48
end tell
APPLESCRIPT
  ) &
  local osascript_pid="$!"
  wait_for_background_process "$osascript_pid" "${AUTOCOMPLETE_LAB_TEXTEDIT_KEY_TYPING_TIMEOUT_SECONDS:-4}" "TextEdit event-tap proof key typing"
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
    trim_textedit_native_completion_suffix "$window_title" "$expected_text" "$label"
    normalize_textedit_typed_seed_for_proof "$window_title" "$expected_text" "$label"
    return 0
  fi

  echo "TextEdit did not receive the $label fragment; refocusing and retrying once." >&2
  focus_textedit_smoke_editor "$window_title"
  click_textedit_smoke_editor "$window_title"
  set_textedit_document_text "$window_title" ""
  expected_text="$fragment"
  type_textedit_smoke_fragment "$window_title" "$fragment"
  wait_for_textedit_document_fragment "$window_title" "$fragment" "$label retry" 5
  trim_textedit_native_completion_suffix "$window_title" "$expected_text" "$label retry"
  normalize_textedit_typed_seed_for_proof "$window_title" "$expected_text" "$label retry"
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
The local runtime hardening pass keeps every model checksum chec
Private beta recovery should explain each local repair step fixp
Offline launch proof needs the embedded model checksum hash
The app owned runtime should catch corrupt weight checks qchk
The tester facing failure state should keep recovery steps runb
Suggestion placement should stay beside the cursor alig
The diagnostics panel should explain latency proof clea
Privacy checks should keep typed text local priv
Onboarding should make permission prompts feel cal
Beta readiness should require current manual proof fres
Current proof should reject stale latency windows curr
The beta packet should include a quiet recovery note recov
Model readiness should prefer the bundled runtime read
Diagnostics should keep redacted export proof visi
Controls should pause suggestions before tester paus
Tab safety should accept one word without sending subm
EOF
}

textedit_default_model_latency_fragments() {
  cat <<'EOF'
The local model stays responsive when
Private beta recovery feels safer because
Offline startup checks the embedded asset before
The typing loop measures phrase suggestions while
Runtime proof should prefer quiet completions that
App owned inference keeps suggestions private by
Cold launch feels better when the model
Typing responsiveness improves after the runtime
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
    focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$expected_url"
    wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture $label"
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
  local proof_nonce="${AUTOCOMPLETE_LAB_CODEX_PROOF_NONCE:-$(date +%s)}"
  local proof_text="${AUTOCOMPLETE_LAB_CODEX_PROOF_TEXT:-AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce Can we make this dicta}"
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

codex_full_accept_proof_text() {
  local proof_nonce="${AUTOCOMPLETE_LAB_CODEX_PROOF_NONCE:-$(date +%s)}"
  local proof_text="${AUTOCOMPLETE_LAB_CODEX_FULL_ACCEPT_PROOF_TEXT:-AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce full-accept I think the next step should}"
  if [[ "$proof_text" != *"AUTOCOMPLETE_LAB_CODEX_PROOF"* ]]; then
    echo "Codex full accept proof text must include AUTOCOMPLETE_LAB_CODEX_PROOF." >&2
    exit 2
  fi
  if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
    echo "Codex full accept proof text must be a single prompt line." >&2
    exit 2
  fi
  printf '%s\n' "$proof_text"
}

codex_model_latency_proof_texts() {
  if [[ -n "${AUTOCOMPLETE_LAB_CODEX_MODEL_LATENCY_TEXTS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_CODEX_MODEL_LATENCY_TEXTS"
    return
  fi

  local proof_nonce="${AUTOCOMPLETE_LAB_CODEX_PROOF_NONCE:-$(date +%s)}"
  cat <<EOF
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-one Can we make this dicta
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-two The fastest useful prompt should predic
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-three Turn this rough thought into a concise summar
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-four Help me finish this implementation pla
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-five The next response should feel immediate and respons
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-six We need a safer prompt autocomplete validat
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-seven Complete this common phrase The quick brown f
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-eight Complete this common phrase Once upon a t
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-nine Complete this common phrase Thank you for your h
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-ten Complete this common phrase Let me know what you t
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-eleven Complete this common phrase I hope this m
AUTOCOMPLETE_LAB_CODEX_PROOF $proof_nonce sample-twelve Complete this common phrase The next step is to v
EOF
}

claude_code_proof_marker() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER:-STEADYTYPECLAUDECODEPROOF}"
}

claude_code_compact_proof_marker() {
  claude_code_proof_marker | tr -d '[:space:]'
}

claude_code_model_latency_proof_texts() {
  if [[ -n "${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_TEXTS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_TEXTS"
    return
  fi

  local marker
  marker="$(claude_code_proof_marker)"
  cat <<EOF
$marker Privacy note redac
$marker Make this setting configu
$marker Keep overlay visi
$marker Keep writing qui
$marker Make transition transi
$marker Autocomplete should valida
$marker Next response feels immed
$marker Useful suggestion stays conci
$marker Editor placement remains accura
$marker Typed phrase becomes predicta
$marker Model answer stays helpfu
$marker Completion remains respons
EOF
}

claude_code_smoke_proof_text() {
  local marker proof_text
  marker="$(claude_code_proof_marker)"
  proof_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TEXT:-Make this setting $marker the feature con}"
  if [[ "$proof_text" != *"$marker"* ]]; then
    echo "Claude Code proof text must include $marker." >&2
    exit 2
  fi
  if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
    echo "Claude Code proof text must be a single line." >&2
    exit 2
  fi
  printf '%s\n' "$proof_text"
}

claude_code_terminal_smoke_input_text() {
  claude_code_smoke_proof_text
}

claude_code_terminal_smoke_input_texts() {
  if [[ -n "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_TEXTS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_TEXTS"
    return
  fi

  local marker
  marker="$(claude_code_proof_marker)"
  cat <<EOF
$marker Please make this
$marker Make this setting the feature
$marker This should feel
$marker What I want is
$marker It should almost always
$marker When I hit Tab it should
$marker The next suggestion should be a
EOF
}

validate_claude_code_terminal_smoke_input_text() {
  local proof_text="$1"
  local marker
  marker="$(claude_code_proof_marker)"
  if [[ "$proof_text" != *"$marker"* &&
        "${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}" != *"$marker"* ]]; then
    echo "Claude Code terminal proof text or window title must include $marker." >&2
    exit 2
  fi
  if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
    echo "Claude Code terminal proof text must be a single line." >&2
    exit 2
  fi
}

claude_proof_marker() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_CLAUDE_PROOF_MARKER:-AUTOCOMPLETE_LAB_CLAUDE_PROOF}"
}

claude_model_latency_proof_texts() {
  if [[ -n "${AUTOCOMPLETE_LAB_CLAUDE_MODEL_LATENCY_TEXTS:-}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_CLAUDE_MODEL_LATENCY_TEXTS"
    return
  fi

  local proof_nonce marker
  proof_nonce="${AUTOCOMPLETE_LAB_CLAUDE_PROOF_NONCE:-$(date +%s)}"
  marker="$(claude_proof_marker)"
  cat <<EOF
$marker $proof_nonce sample-one Can we make this dicta
$marker $proof_nonce sample-two The fastest useful reply should predic
$marker $proof_nonce sample-three Turn this rough thought into a concise summar
$marker $proof_nonce sample-four Help me finish this implementation pla
$marker $proof_nonce sample-five The next response should feel immediate and respons
$marker $proof_nonce sample-six We need a safer prompt autocomplete validat
$marker $proof_nonce sample-seven Complete this common phrase The quick brown f
$marker $proof_nonce sample-eight Complete this common phrase Once upon a t
$marker $proof_nonce sample-nine Complete this common phrase Thank you for your h
$marker $proof_nonce sample-ten Complete this common phrase Let me know what you t
$marker $proof_nonce sample-eleven Complete this common phrase I hope this m
$marker $proof_nonce sample-twelve Complete this common phrase The next step is to v
EOF
}

claude_ax_helper() {
  local action="$1"
  shift
  swift script/prompt_app_ax_proof_helper.swift "$action" \
    --bundle com.anthropic.claudefordesktop \
    --display Claude \
    --marker "$(claude_proof_marker)" \
    --hint "Ask Claude" \
    --hint "Message Claude" \
    --hint "Reply to Claude" \
    --hint "How can I help" \
    "$@"
}

seed_claude_proof_prompt() {
  local proof_text="$1"
  local backup_path="${2:-}"
  claude_ax_helper seed \
    --text "$proof_text" \
    --backup "$backup_path" \
    --discovery-timeout "${AUTOCOMPLETE_LAB_CLAUDE_COMPOSER_DISCOVERY_TIMEOUT_SECONDS:-10}"
}

restore_claude_draft_if_needed() {
  if [[ -z "$CLAUDE_DRAFT_BACKUP_PATH" ]]; then
    return 0
  fi

  claude_ax_helper restore --backup "$CLAUDE_DRAFT_BACKUP_PATH" --clear-if-no-backup || true
  rm -f "$CLAUDE_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true
  CLAUDE_DRAFT_BACKUP_PATH=""
}

focus_claude_proof_prompt() {
  claude_ax_helper focus
}

assert_claude_proof_prompt_ready() {
  local proof_text="$1"
  claude_ax_helper assert --text "$proof_text"
}

assert_claude_prompt_retains_marker() {
  claude_ax_helper contains-marker
}

claude_code_terminal_ax_helper() {
  local action="$1"
  local proof_pid
  local -a proof_pid_args
  shift

  proof_pid="$(claude_code_terminal_proof_primary_pid)"
  proof_pid_args=()
  if [[ -n "$proof_pid" ]]; then
    proof_pid_args=(--pid "$proof_pid")
  fi

  swift script/terminal_prompt_ax_proof_helper.swift "$action" \
    --bundle "$(claude_code_host_bundle_id)" \
    --display "$(claude_code_host_display_name)" \
    --marker "$(claude_code_proof_marker)" \
    "${proof_pid_args[@]}" \
    --hint "Claude Code" \
    --hint "Try \"fix lint errors\"" \
    --hint "for shortcuts" \
    --hint "❯" \
    "$@"
}

claude_code_host_process_name() {
  case "$CLAUDE_CODE_HOST_VARIANT" in
    terminal)
      printf 'Terminal\n'
      ;;
    iterm2)
      printf 'iTerm2\n'
      ;;
    ghostty)
      printf 'ghostty\n'
      ;;
    *)
      printf '\n'
      ;;
  esac
}

claude_code_host_open_app_name() {
  case "$CLAUDE_CODE_HOST_VARIANT" in
    terminal)
      printf 'Terminal\n'
      ;;
    iterm2)
      printf 'iTerm\n'
      ;;
    ghostty)
      printf 'Ghostty\n'
      ;;
    *)
      printf '\n'
      ;;
  esac
}

terminal_pid_list() {
  local process_name
  process_name="$(claude_code_host_process_name)"
  [[ -n "$process_name" ]] || return 0
  pgrep -x "$process_name" || true
}

pid_list_difference() {
  local after="$1"
  local before="$2"
  local pid

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if ! printf '%s\n' "$before" | grep -qxF "$pid"; then
      printf '%s\n' "$pid"
    fi
  done <<<"$after"
}

wait_for_new_terminal_pids() {
  local before="$1"
  local timeout="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACTIVATION_WAIT_SECONDS:-12}"
  local timeout_seconds="${timeout%%.*}"
  local deadline after new_pids

  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
    timeout_seconds=12
  fi
  if ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS <= deadline)); do
    after="$(terminal_pid_list)"
    new_pids="$(pid_list_difference "$after" "$before" | tr '\n' ' ')"
    new_pids="${new_pids% }"
    if [[ -n "$new_pids" ]]; then
      printf '%s\n' "$new_pids"
      return 0
    fi
    sleep 0.2
  done

  echo "Claude Code Terminal proof did not create a disposable $(claude_code_host_display_name) process." >&2
  return 1
}

frontmost_process_id() {
  swift - <<'SWIFT'
import AppKit
print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
SWIFT
}

frontmost_bundle_identifier() {
  swift - <<'SWIFT'
import AppKit
print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "")
SWIFT
}

system_events_frontmost_process_id_matches() {
  local target_pid="$1"
  local result

  [[ -n "$target_pid" ]] || return 1
  result="$(AUTOCOMPLETE_LAB_TARGET_PID="$target_pid" \
    run_osascript_with_timeout 1 "System Events frontmost pid probe" <<'APPLESCRIPT' || true
set targetPid to (system attribute "AUTOCOMPLETE_LAB_TARGET_PID") as integer
tell application "System Events"
  repeat with procRef in (application processes whose frontmost is true)
    try
      if unix id of procRef is targetPid then return true
    end try
  end repeat
end tell
return false
APPLESCRIPT
)"
  [[ "$result" == "true" ]]
}

activate_process_id() {
  local target_pid="$1"

  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] &&
    focus_claude_code_ghostty_proof_window_by_title "$target_pid"; then
    return 0
  fi

  local swift_activation_pid
  {
    swift - "$target_pid" <<'SWIFT' >/dev/null
import AppKit

guard CommandLine.arguments.count == 2,
      let rawPID = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid_t(rawPID)) else {
    exit(1)
}

app.activate(options: [.activateAllWindows])
SWIFT
  } &
  swift_activation_pid="$!"
  wait_for_background_process "$swift_activation_pid" 2 "Swift activation for pid $target_pid" >/dev/null 2>&1 || true

  if wait_for_appkit_activation_frontmost "$target_pid"; then
    return 0
  fi

  AUTOCOMPLETE_LAB_TARGET_PID="$target_pid" osascript <<'APPLESCRIPT'
set targetPid to (system attribute "AUTOCOMPLETE_LAB_TARGET_PID") as integer
tell application "System Events"
  set frontmost of first application process whose unix id is targetPid to true
end tell
APPLESCRIPT
}

focus_claude_code_ghostty_proof_window_by_title() {
  local target_pid="${1:-}"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}" ]] || return 1

  local focus_result
  focus_result="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE="$CLAUDE_CODE_TERMINAL_PROOF_TITLE" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TARGET_PID="$target_pid" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_TIMEOUT_SECONDS:-2}" \
      "Claude Code Ghostty title-marked proof focus" <<'APPLESCRIPT' || true
set proofTitle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE"
set targetPidText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TARGET_PID"
set targetPid to 0
try
  if targetPidText is not "" then set targetPid to targetPidText as integer
end try
set targetWindow to missing value
set activatedTitleWindow to false
tell application id "com.mitchellh.ghostty"
  repeat with candidateWindow in windows
    set windowName to name of candidateWindow as text
    if windowName contains proofTitle then
      set targetWindow to candidateWindow
      exit repeat
    end if
  end repeat
  if targetWindow is missing value then return false
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  select tab targetTab
  focus targetTerminal
  set activatedTitleWindow to true
  activate
end tell
delay 0.05
tell application "System Events"
  if targetPid is not 0 then
    repeat with procRef in application processes
      try
        if unix id of procRef is targetPid then
          set frontmost of procRef to true
          exit repeat
        end if
      end try
    end repeat
  end if
  delay 0.05
  set sawGhostty to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if targetPid is not 0 and unix id of frontApp is targetPid then return "exact"
      if bundle identifier of frontApp is "com.mitchellh.ghostty" then set sawGhostty to true
    end try
  end repeat
  if sawGhostty and activatedTitleWindow then return "bundle"
end tell
return "false"
APPLESCRIPT
)"
  [[ "$focus_result" == "exact" || "$focus_result" == "bundle" || "$focus_result" == "true" ]]
}

focus_claude_code_ghostty_host_app_after_title_proof() {
  local target_pid="${1:-}"
  local host_focus_result

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ "${CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED:-0}" == "1" ]] || return 1

  host_focus_result="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TARGET_PID="$target_pid" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_HOST_FOCUS_TIMEOUT_SECONDS:-2}" \
      "Claude Code Ghostty host focus after title proof" <<'APPLESCRIPT' || true
set targetPidText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TARGET_PID"
set targetPid to 0
try
  if targetPidText is not "" then set targetPid to targetPidText as integer
end try
tell application id "com.mitchellh.ghostty"
  activate
end tell
delay 0.05
tell application "System Events"
  if targetPid is not 0 then
    repeat with procRef in application processes
      try
        if unix id of procRef is targetPid then
          set frontmost of procRef to true
          exit repeat
        end if
      end try
    end repeat
  end if
  delay 0.05
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is "com.mitchellh.ghostty" then return true
    end try
  end repeat
end tell
return false
APPLESCRIPT
)"
  [[ "$host_focus_result" == "true" ]]
}

allow_claude_code_ghostty_proof_command_alert() {
  local launch_script="$1"
  local timeout_seconds="${2:-2}"
  local allow_result

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$launch_script" ]] || return 1

  allow_result="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_SCRIPT="$launch_script" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ALERT_TIMEOUT_SECONDS="$timeout_seconds" \
    run_osascript_with_timeout \
      "$timeout_seconds" \
      "Claude Code Ghostty proof command alert allow" <<'APPLESCRIPT' || true
set launchScript to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_SCRIPT"
set timeoutSeconds to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ALERT_TIMEOUT_SECONDS") as real
set deadline to (current date) + timeoutSeconds

on appendIfText(existingText, candidateValue)
  try
    if candidateValue is not missing value then return existingText & " " & (candidateValue as text)
  end try
  return existingText
end appendIfText

repeat while (current date) < deadline
  tell application "System Events"
    if exists application process "Ghostty" then
      tell application process "Ghostty"
        if exists front window then
          set windowText to ""
          try
            set windowText to my appendIfText(windowText, name of front window)
          end try
          try
            set windowText to my appendIfText(windowText, value of front window)
          end try
          try
            repeat with elementRef in static texts of front window
              try
                set windowText to my appendIfText(windowText, name of elementRef)
              end try
              try
                set windowText to my appendIfText(windowText, value of elementRef)
              end try
            end repeat
          end try
          if windowText contains "Allow Ghostty to execute" and windowText contains launchScript then
            if exists button "Allow" of front window then
              click button "Allow" of front window
              return "allowed"
            end if
          end if
        end if
      end tell
    end if
  end tell
  delay 0.1
end repeat

return "not-present"
APPLESCRIPT
)"
  if [[ "$allow_result" == "allowed" ]]; then
    echo "Claude Code Ghostty proof allowed command execution alert for disposable proof command."
    return 0
  fi
  return 1
}

frontmost_claude_code_terminal_proof_process_is_active() {
  local frontmost_pid root_pid

  [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]] || return 1
  frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
  frontmost_claude_code_terminal_proof_pid_matches "$frontmost_pid"
}

frontmost_claude_code_terminal_host_app_is_active() {
  local frontmost_pid="${1:-}"
  local host_app host_bundle frontmost_bundle host_process

  guard_ghostty_frontmost_bundle_fallback || return 1
  host_app="$(claude_code_host_open_app_name)"
  host_bundle="$(claude_code_host_bundle_id)"
  frontmost_bundle="$(frontmost_bundle_identifier 2>/dev/null || true)"
  if [[ -n "$host_bundle" && "$frontmost_bundle" == "$host_bundle" ]]; then
    return 0
  fi
  if [[ -n "$host_app" ]] && try_wait_for_frontmost_app "$host_app" 1; then
    return 0
  fi

  host_process="$(claude_code_host_process_name)"
  process_id_has_name "$frontmost_pid" "$host_process"
}

guard_ghostty_frontmost_bundle_fallback() {
  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]
}

frontmost_claude_code_terminal_proof_pid_matches() {
  local frontmost_pid="$1"
  local root_pid

  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    if [[ "$frontmost_pid" == "$root_pid" ]]; then
      return 0
    fi
  done
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
      if system_events_frontmost_process_id_matches "$root_pid"; then
        return 0
      fi
    done
  fi

  frontmost_claude_code_terminal_host_app_is_active "$frontmost_pid"
}

frontmost_claude_code_terminal_proof_root_pid_matches() {
  local frontmost_pid="$1"
  local root_pid

  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    if [[ "$frontmost_pid" == "$root_pid" ]]; then
      return 0
    fi
  done

  return 1
}

claude_code_terminal_proof_primary_pid() {
  local root_pid

  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    printf '%s\n' "$root_pid"
    return 0
  done

  return 0
}

try_wait_for_frontmost_claude_code_terminal_proof_process() {
  local timeout="${1:-${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACTIVATION_WAIT_SECONDS:-12}}"
  local timeout_seconds="${timeout%%.*}"
  local deadline root_pid frontmost_pid activation_attempt

  if [[ -z "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]]; then
    return 1
  fi
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
    timeout_seconds=12
  fi
  if ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      if focus_claude_code_ghostty_proof_window_by_title "$root_pid" >/dev/null 2>&1; then
        return 0
      fi
      if focus_claude_code_ghostty_host_app_after_title_proof "$root_pid" >/dev/null 2>&1; then
        return 0
      fi
    fi
    activate_process_id "$root_pid" >/dev/null 2>&1 || true
    break
  done

  deadline=$((SECONDS + timeout_seconds))
  activation_attempt=0
  while ((SECONDS <= deadline)); do
    frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
    if frontmost_claude_code_terminal_proof_pid_matches "$frontmost_pid"; then
      return 0
    fi
    activation_attempt=$((activation_attempt + 1))
    if ((activation_attempt % 3 == 0)); then
      for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
        if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
          if focus_claude_code_ghostty_proof_window_by_title "$root_pid" >/dev/null 2>&1; then
            return 0
          fi
          if focus_claude_code_ghostty_host_app_after_title_proof "$root_pid" >/dev/null 2>&1; then
            return 0
          fi
        fi
        activate_process_id "$root_pid" >/dev/null 2>&1 || true
        break
      done
    fi
    sleep 0.2
  done

  return 1
}

wait_for_frontmost_claude_code_terminal_proof_process() {
  local frontmost_pid frontmost_bundle

  if [[ -z "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]]; then
    echo "Claude Code Terminal proof did not record a disposable Terminal process." >&2
    exit 1
  fi

  if try_wait_for_frontmost_claude_code_terminal_proof_process; then
    return 0
  fi

  frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
  frontmost_bundle="$(frontmost_bundle_identifier 2>/dev/null || true)"
  echo "Claude Code Terminal proof process did not become frontmost: $CLAUDE_CODE_TERMINAL_PROOF_PIDS (frontmost pid=${frontmost_pid:-unknown} bundle=${frontmost_bundle:-unknown})" >&2
  exit 1
}

settle_claude_code_terminal_proof_focus() {
  local label="$1"
  local timeout="${2:-}"
  local host_name
  host_name="$(claude_code_host_display_name)"

  if [[ -n "$timeout" ]]; then
    if try_wait_for_frontmost_claude_code_terminal_proof_process "$timeout"; then
      return 0
    fi
  elif try_wait_for_frontmost_claude_code_terminal_proof_process; then
    return 0
  fi

  echo "Claude Code $host_name proof could not reactivate its disposable host process for $label." >&2
  return 1
}

prepare_claude_code_terminal_suggestion_for_hot_accept() {
  local suggestion_line="$1"
  local host_name="$2"
  local refresh_wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_SUGGESTION_WAIT_SECONDS:-4}"
  local max_attempts="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS:-3}"
  local attempt=1
  local current_suggestion_line="$suggestion_line"
  CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE="$suggestion_line"

  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || ((max_attempts < 1)); then
    max_attempts=1
  fi

  while ((attempt <= max_attempts)); do
    if log_since_has_fields "$suggestion_line" \
      "keyboard-action" \
      "app=com.anthropic.claude-code" \
      "key=escape" \
      "action=dismiss" \
      "handled=true" ||
      log_since_has_fields "$suggestion_line" \
        "field-suppressed" \
        "app=com.anthropic.claude-code" \
        "reason=escape"; then
      echo "Claude Code $host_name suggestion was dismissed before Tab; refreshing the disposable prompt." >&2
      return 1
    fi

    if log_since_has_fields "$current_suggestion_line" \
      "suggestion-hidden" \
      "app=com.anthropic.claude-code" \
      "reason=focus-changed" ||
      log_since_has_fields "$current_suggestion_line" \
        "suggestion-hidden" \
        "app=com.anthropic.claude-code" \
        "reason=focus-lost"; then
      echo "Claude Code $host_name suggestion hid after focus moved before Tab; refocusing for a fresh suggestion." >&2
      if ! try_wait_for_frontmost_claude_code_terminal_proof_process; then
        return 1
      fi
      if wait_for_claude_code_terminal_proof_suggestion_ready_optional \
        "$current_suggestion_line" \
        "$refresh_wait_seconds"; then
        current_suggestion_line="$MATCHED_LOG_LINE"
        CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE="$current_suggestion_line"
        attempt=$((attempt + 1))
        continue
      fi
      return 1
    fi

    if log_since_has_fields "$current_suggestion_line" \
      "suggestion-hidden" \
      "app=com.anthropic.claude-code"; then
      echo "Claude Code $host_name suggestion is no longer visible before Tab; refreshing the disposable prompt." >&2
      return 1
    fi

    if ! try_wait_for_frontmost_claude_code_terminal_proof_process 1; then
      echo "Claude Code $host_name proof lost focus before Tab; reactivating the disposable host process for the hot accept." >&2
      if ! try_wait_for_frontmost_claude_code_terminal_proof_process; then
        return 1
      fi
      sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_SETTLE_SECONDS:-0.4}"
      attempt=$((attempt + 1))
      continue
    fi

    CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE="$current_suggestion_line"
    MATCHED_LOG_LINE="$current_suggestion_line"
    return 0
  done

  return 1
}

warm_claude_code_terminal_hot_accept_helpers() {
  local host_name="$1"

  if [[ "$CLAUDE_CODE_HOST_VARIANT" != "ghostty" ]]; then
    return 0
  fi

  echo "Claude Code $host_name proof warming CGEvent Tab helper before prompt suggestions."
  ensure_cgevent_keypress_helper
}

process_tree_contains_name() {
  local root_pid="$1"
  local expected_name="$2"
  local child command_name

  [[ -z "$root_pid" || -z "$expected_name" ]] && return 1
  while IFS= read -r child; do
    [[ -z "$child" ]] && continue
    command_name="$(ps -p "$child" -o comm= 2>/dev/null || true)"
    command_name="${command_name##*/}"
    if [[ "$command_name" == "$expected_name" || "$command_name" == "-$expected_name" ]]; then
      return 0
    fi
    if process_tree_contains_name "$child" "$expected_name"; then
      return 0
    fi
  done < <(pgrep -P "$root_pid" 2>/dev/null || true)
  return 1
}

process_id_has_name() {
  local pid="$1"
  local expected_name="$2"
  local command_name

  [[ -z "$pid" || -z "$expected_name" ]] && return 1
  command_name="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
  command_name="${command_name##*/}"
  [[ "$command_name" == "$expected_name" || "$command_name" == "-$expected_name" ]]
}

process_id_or_tree_has_name() {
  local pid="$1"
  local expected_name="$2"

  [[ -z "$pid" || -z "$expected_name" ]] && return 1
  process_id_has_name "$pid" "$expected_name" ||
    process_tree_contains_name "$pid" "$expected_name"
}

process_tree_has_child() {
  local root_pid="$1"

  [[ -n "$root_pid" ]] || return 1
  pgrep -P "$root_pid" >/dev/null 2>&1
}

ghostty_process_tree_has_child() {
  local root_pid

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]] || return 1

  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    if process_tree_has_child "$root_pid"; then
      return 0
    fi
  done

  return 1
}

wait_for_ghostty_process_tree_child_optional() {
  local timeout="${1:-2}"
  local timeout_seconds="${timeout%%.*}"
  local deadline

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]] || return 1
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
    timeout_seconds=2
  fi
  if ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS <= deadline)); do
    if ghostty_process_tree_has_child; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

describe_claude_code_ghostty_process_tree() {
  local root_pid child

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]] || return 0

  echo "Claude Code Ghostty proof process tree:" >&2
  for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
    echo "root_pid=$root_pid" >&2
    ps -p "$root_pid" -o pid,ppid,pgid,stat,comm,args 2>/dev/null >&2 ||
      echo "  root process unavailable to ps" >&2
    while IFS= read -r child; do
      [[ -n "$child" ]] || continue
      ps -p "$child" -o pid,ppid,pgid,stat,comm,args 2>/dev/null >&2 ||
        echo "  child process unavailable to ps: $child" >&2
    done < <(pgrep -P "$root_pid" 2>/dev/null || true)
  done
}

describe_claude_code_terminal_proof_process_state() {
  local expected_name="$1"
  local label="${2:-$expected_name}"
  local proof_pid ps_line exit_state

  if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" &&
        -s "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ]]; then
    proof_pid="$(head -n 1 "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" | tr -dc '0-9')"
    if [[ -n "$proof_pid" ]]; then
      ps_line="$(ps -p "$proof_pid" -o pid=,ppid=,stat=,comm=,args= 2>/dev/null || true)"
      if [[ -n "$ps_line" ]]; then
        echo "Claude Code Terminal proof pidfile process state: $ps_line" >&2
      else
        echo "Claude Code Terminal proof pidfile process no longer exists: $proof_pid" >&2
      fi
    fi
  elif [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ]]; then
    echo "Claude Code Terminal proof pidfile was not written: $CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" >&2
  fi

  if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE" &&
        -s "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE" ]]; then
    exit_state="$(tr '\n' ' ' <"$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE" | head -c 240)"
    echo "Claude Code Terminal proof $label exit state: $exit_state" >&2
  fi
}

describe_claude_code_ghostty_launch_state() {
  local proof_title="$1"
  local launch_state

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "$proof_title" ]] || return 0

  launch_state="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE="$proof_title" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_STATE_TIMEOUT_SECONDS:-4}" \
      "Claude Code Ghostty proof launch state" <<'APPLESCRIPT' 2>/dev/null || true
set proofTitle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE"
set windowCount to 0
set matchedWindowCount to 0
set frontWindowHasProofTitle to false
set focusedTerminalWorkingDirectoryPresent to false
tell application id "com.mitchellh.ghostty"
  set windowCount to count windows
  try
    set frontWindowName to name of front window as text
    if frontWindowName contains proofTitle then set frontWindowHasProofTitle to true
  end try
  repeat with candidateWindow in windows
    try
      set windowName to name of candidateWindow as text
      if windowName contains proofTitle then
        set matchedWindowCount to matchedWindowCount + 1
        try
          set targetTab to selected tab of candidateWindow
          set targetTerminal to focused terminal of targetTab
          set terminalDirectory to working directory of targetTerminal as text
          if terminalDirectory is not "" then set focusedTerminalWorkingDirectoryPresent to true
        end try
      end if
    end try
  end repeat
end tell
return "windows=" & (windowCount as text) & " proofTitleWindows=" & (matchedWindowCount as text) & " frontWindowHasProofTitle=" & (frontWindowHasProofTitle as text) & " focusedTerminalWorkingDirectoryPresent=" & (focusedTerminalWorkingDirectoryPresent as text)
APPLESCRIPT
)"
  if [[ -n "$launch_state" ]]; then
    echo "Claude Code Ghostty proof launch state: $launch_state" >&2
  else
    echo "Claude Code Ghostty proof launch state unavailable." >&2
  fi
}

describe_claude_code_ghostty_launch_stages() {
  local stage_file="$1"
  local stages

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "$stage_file" ]] || return 0

  if [[ -s "$stage_file" ]]; then
    stages="$(tr '\n' ' ' <"$stage_file" | sed 's/[[:space:]]*$//')"
    echo "Claude Code Ghostty proof launch stages: $stages" >&2
  else
    echo "Claude Code Ghostty proof launch stages unavailable: $stage_file" >&2
  fi
}

check_claude_code_ghostty_applescript_health() {
  local stage_file="$1"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "$stage_file" ]] || return 42

  if run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_APPLESCRIPT_PREFLIGHT_TIMEOUT_SECONDS:-2}" \
    "Claude Code Ghostty AppleScript preflight" \
    - "$stage_file" <<'APPLESCRIPT' >/dev/null; then
on recordStage(stageFile, stageName)
  if stageFile is not "" then
    try
      do shell script "/bin/echo " & quoted form of stageName & " >> " & quoted form of stageFile
    end try
  end if
end recordStage

on run argv
set launchStageFile to item 1 of argv
recordStage(launchStageFile, "preflight-begin")
tell application id "com.mitchellh.ghostty"
  my recordStage(launchStageFile, "preflight-tell-entered")
  set ghosttyVersion to version as text
  my recordStage(launchStageFile, "preflight-version:" & ghosttyVersion)
end tell
recordStage(launchStageFile, "preflight-finished")
end run
APPLESCRIPT
    if grep -Fxq "preflight-finished" "$stage_file" 2>/dev/null; then
      return 0
    fi

    describe_claude_code_ghostty_launch_stages "$stage_file"
    echo "Claude Code Ghostty AppleScript bridge preflight exited before recording completion." >&2
    return 42
  fi

  describe_claude_code_ghostty_launch_stages "$stage_file"
  echo "Claude Code Ghostty AppleScript bridge did not answer preflight before disposable launch." >&2
  return 42
}

claude_code_ghostty_launch_stalled_before_stage() {
  local stage_file="$1"
  local required_stage="$2"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$stage_file" && -n "$required_stage" && -s "$stage_file" ]] || return 1

  ! grep -Fx "$required_stage" "$stage_file" >/dev/null 2>&1
}

claude_code_ghostty_configured_window_shell_not_ready() {
  local stage_file="$1"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$stage_file" && -s "$stage_file" ]] || return 1

  grep -Fxq "configured-window-created" "$stage_file" 2>/dev/null &&
    grep -Fxq "shell-delay-finished" "$stage_file" 2>/dev/null &&
    ! grep -Fxq "terminal-ready" "$stage_file" 2>/dev/null
}

claude_code_ghostty_retry_window_shell_not_ready() {
  local stage_file="$1"

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "$stage_file" && -s "$stage_file" ]] || return 1

  grep -Fxq "retry-shell-delay-finished" "$stage_file" 2>/dev/null &&
    ! grep -Fxq "retry-terminal-ready" "$stage_file" 2>/dev/null
}

wait_for_claude_code_terminal_pidfile_process_optional() {
  local timeout="${1:-3}"
  local timeout_seconds="${timeout%%.*}"
  local deadline proof_pid

  if [[ -z "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ||
        -z "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME" ]]; then
    return 1
  fi
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
    timeout_seconds=3
  fi
  if ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS <= deadline)); do
    if [[ -s "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ]]; then
      proof_pid="$(head -n 1 "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" | tr -dc '0-9')"
      if process_id_or_tree_has_name "$proof_pid" "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME"; then
        return 0
      fi
    fi
    sleep 0.1
  done

  return 1
}

ghostty_text_action() {
  local text="$1"
  local byte action

  action="text:"
  while read -r byte; do
    case "$byte" in
      30|31|32|33|34|35|36|37|38|39|41|42|43|44|45|46|47|48|49|4a|4b|4c|4d|4e|4f|50|51|52|53|54|55|56|57|58|59|5a|61|62|63|64|65|66|67|68|69|6a|6b|6c|6d|6e|6f|70|71|72|73|74|75|76|77|78|79|7a)
        action+="$(printf '%b' "\\x$byte")"
        ;;
      *)
        action+="\\x$byte"
        ;;
    esac
  done < <(LC_ALL=C printf '%s' "$text" | od -An -tx1 -v | tr ' ' '\n' | sed '/^$/d')

  printf '%s\n' "$action"
}

try_wait_for_claude_code_terminal_process_name() {
  local expected_name="$1"
  local label="${2:-$expected_name}"
  local timeout="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_DISCOVERY_TIMEOUT_SECONDS:-20}"
  local timeout_seconds="${timeout%%.*}"
  local deadline root_pid proof_pid

  if [[ -z "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" || -z "$expected_name" ]]; then
    echo "Claude Code Terminal proof did not record a disposable Terminal process." >&2
    return 1
  fi
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]]; then
    timeout_seconds=20
  fi
  if ((timeout_seconds < 1)); then
    timeout_seconds=1
  fi

  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS <= deadline)); do
    if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" &&
          -s "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ]]; then
      proof_pid="$(head -n 1 "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" | tr -dc '0-9')"
      if process_id_or_tree_has_name "$proof_pid" "$expected_name"; then
        return 0
      fi
    fi
    for root_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
      if process_tree_contains_name "$root_pid" "$expected_name"; then
        return 0
      fi
    done
    sleep 0.2
  done

  describe_claude_code_terminal_proof_process_state "$expected_name" "$label"
  echo "Claude Code Terminal proof did not start $label under disposable $(claude_code_host_display_name) pid(s): $CLAUDE_CODE_TERMINAL_PROOF_PIDS" >&2
  return 1
}

wait_for_claude_code_terminal_process_name() {
  try_wait_for_claude_code_terminal_process_name "$@" || exit 1
}

wait_for_claude_code_terminal_process() {
  wait_for_claude_code_terminal_process_name "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME" "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME"
}

run_claude_code_ghostty_prompt_screen_copy_probe() {
  local prompt_wait_output="${1:-}"
  local expected_text="${2:-}"
  local target_pid proof_title proof_marker compact_marker old_pasteboard action_output raw_pasteboard
  local screen_text screen_transport screen_chars compact_screen_chars has_marker has_compact_marker has_hint
  local has_expected has_rejected_shell screen_ready screen_normalized expected_normalized tmp_prefix

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  if [[ -z "$expected_text" ||
        ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROMPT_SCREEN_COPY_ON_TYPED_AX_FAILURE:-1}" =~ ^(1|true|yes|on)$ ]]; then
    [[ "$prompt_wait_output" == *"textNodes=0"* ]] || return 1
  fi
  target_pid="$(claude_code_terminal_proof_primary_pid)"
  proof_title="${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}"
  proof_marker="$(claude_code_proof_marker)"
  compact_marker="$(claude_code_compact_proof_marker)"
  [[ -n "$target_pid" && -n "$proof_title" ]] || return 1

  old_pasteboard="$(pbpaste 2>/dev/null || true)"
  : | pbcopy >/dev/null 2>&1 || true
  action_output="$(
    AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE="$proof_title" \
      AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$proof_marker" \
      AUTOCOMPLETE_LAB_CLAUDE_CODE_COMPACT_PROOF_MARKER="$compact_marker" \
      AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID="$target_pid" \
      run_osascript_with_timeout \
        "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROMPT_SCREEN_COPY_TIMEOUT_SECONDS:-3}" \
        "Claude Code Ghostty prompt screen-copy readiness" <<'APPLESCRIPT' 2>/dev/null || true
set proofTitle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE"
set proofMarker to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_COMPACT_PROOF_MARKER"
set targetPidText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"
set targetProcessId to targetPidText as integer
set targetSelectionMode to "none"
set ghosttyWindowCount to 0
tell application id "com.mitchellh.ghostty"
  set ghosttyWindowCount to count windows
  set targetWindow to missing value
  repeat with candidateWindow in windows
    try
      set windowName to name of candidateWindow as text
      if windowName contains proofTitle then
        set targetWindow to candidateWindow
        set targetSelectionMode to "proofTitle"
        exit repeat
      end if
    end try
  end repeat
  if targetWindow is missing value then
    repeat with candidateWindow in windows
      try
        set windowName to name of candidateWindow as text
        if windowName contains proofMarker or windowName contains compactProofMarker then
          set targetWindow to candidateWindow
          set targetSelectionMode to "markerTitle"
          exit repeat
        end if
      end try
    end repeat
  end if
  if targetWindow is missing value and ghosttyWindowCount > 0 then
    set targetWindow to front window
    set targetSelectionMode to "frontWindow"
  end if
  if targetWindow is missing value then return "false|targetSelection:none|windowCount:" & (ghosttyWindowCount as text)
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  select tab targetTab
  focus targetTerminal
  activate
end tell
delay 0.04
tell application "System Events"
  set ghosttyProcess to first application process whose unix id is targetProcessId
  if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
  set frontmost of ghosttyProcess to true
end tell
tell application id "com.mitchellh.ghostty"
  set actionPerformed to perform action "write_screen_file:copy,plain" on targetTerminal
  if actionPerformed is false then return "false|targetSelection:" & targetSelectionMode & "|windowCount:" & (ghosttyWindowCount as text)
  return "true|targetSelection:" & targetSelectionMode & "|windowCount:" & (ghosttyWindowCount as text)
end tell
APPLESCRIPT
  )"
  raw_pasteboard="$(pbpaste 2>/dev/null || true)"
  if [[ -n "$old_pasteboard" ]]; then
    printf '%s' "$old_pasteboard" | pbcopy >/dev/null 2>&1 || true
  else
    : | pbcopy >/dev/null 2>&1 || true
  fi

  screen_transport="pasteboardText"
  screen_text="$raw_pasteboard"
  tmp_prefix="${TMPDIR:-/tmp}"
  tmp_prefix="${tmp_prefix%/}"
  if [[ -n "$raw_pasteboard" && -f "$raw_pasteboard" ]]; then
    case "$raw_pasteboard" in
      "$tmp_prefix"/*|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*)
        screen_text="$(cat "$raw_pasteboard" 2>/dev/null || true)"
        screen_transport="screenFile"
        ;;
      *)
        screen_transport="filePathRejected"
        ;;
    esac
  fi

  screen_chars="${#screen_text}"
  compact_screen_chars="$(printf '%s' "$screen_text" | tr -d '\r\n' | wc -c | tr -d ' ')"
  has_marker="false"
  has_compact_marker="false"
  has_hint="false"
  has_expected="false"
  has_rejected_shell="false"
  screen_ready="false"
  if [[ -n "$proof_marker" ]] && printf '%s' "$screen_text" | grep -Fqi "$proof_marker"; then
    has_marker="true"
  fi
  if [[ -n "$compact_marker" ]] && printf '%s' "$screen_text" | tr -d '\r\n' | grep -Fqi "$compact_marker"; then
    has_compact_marker="true"
  fi
  if printf '%s' "$screen_text" | grep -Eiq 'shortcuts|esc|enter'; then
    has_hint="true"
  fi
  if printf '%s' "$screen_text" | grep -Eiq 'steadytype-claude-code-proof\.command| -e .*steadytype-claude-code-proof\.|exec .*steadytype-claude-code-proof\.'; then
    has_rejected_shell="true"
  fi
  screen_normalized="$(printf '%s' "$screen_text" | awk '{$1=$1; print}')"
  expected_normalized="$(printf '%s' "$expected_text" | awk '{$1=$1; print}')"
  if [[ -z "$expected_normalized" ]] || printf '%s' "$screen_normalized" | grep -Fq "$expected_normalized"; then
    has_expected="true"
  fi
  if [[ "$action_output" == true* &&
        "$screen_chars" =~ ^[1-9][0-9]*$ &&
        "$has_rejected_shell" == "false" &&
        "$has_expected" == "true" &&
        (
          "$has_marker" == "true" ||
          "$has_compact_marker" == "true" ||
          "$has_hint" == "true" ||
          ( "$action_output" == *"targetSelection:proofTitle"* && -n "$screen_normalized" )
        ) ]]; then
    screen_ready="true"
  fi

  echo "Claude Code Ghostty prompt screen-copy readiness: action=${action_output:-empty} transport=$screen_transport screenChars=$screen_chars compactScreenChars=$compact_screen_chars hasMarker=$has_marker hasCompactMarker=$has_compact_marker hasHint=$has_hint hasExpected=$has_expected rejectedShellCommand=$has_rejected_shell ready=$screen_ready" >&2
  [[ "$screen_ready" == "true" ]]
}

run_claude_code_ghostty_prompt_anchor_diagnostics_probe() {
  local proof_text="$1"
  local start_line="${CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE:-0}"
  local expected_chars matched_line

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -f "$LOG_PATH" ]] || return 1
  [[ "$start_line" =~ ^[0-9]+$ ]] || start_line=0
  expected_chars="${#proof_text}"
  ((expected_chars > 0)) || return 1

  matched_line="$(sed -n "$((start_line + 1)),\$p" "$LOG_PATH" 2>/dev/null |
    awk \
      -v start="$start_line" \
      -v expected="$expected_chars" '
        index($0, "claude-code-terminal-host-proof-direct-prompt-anchor-used") &&
        index($0, "app=com.anthropic.claude-code") &&
        index($0, "host=com.mitchellh.ghostty") &&
        $0 ~ ("beforeChars=" expected "([^0-9]|$)") &&
        $0 ~ ("promptLineInputChars=" expected "([^0-9]|$)") {
          candidate = NR + start
        }
        END {
          if (candidate != "") {
            print candidate
          }
        }
      ' 2>/dev/null || true)"

  if [[ -n "$matched_line" ]]; then
    echo "Claude Code Ghostty proof accepted terminal prompt-anchor typed readiness at diagnostics line $matched_line (chars=$expected_chars)." >&2
    return 0
  fi

  return 1
}

mark_claude_code_ghostty_proof_window_title() {
  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}" ]] || return 1

  run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TITLE_MARK_TIMEOUT_SECONDS:-2}" \
    "Claude Code Ghostty proof title mark" \
    - "$CLAUDE_CODE_TERMINAL_PROOF_TITLE" <<'APPLESCRIPT' >/dev/null
on run argv
set proofTitle to item 1 of argv
tell application id "com.mitchellh.ghostty"
  set targetWindow to front window
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  focus targetTerminal
  perform action ("set_surface_title:" & proofTitle) on targetTerminal
  perform action ("set_tab_title:" & proofTitle) on targetTerminal
  activate
end tell
end run
APPLESCRIPT
}

claude_code_ghostty_frontmost_proof_process_id_by_title() {
  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ -n "${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}" ]] || return 1

  local host_app host_bundle frontmost_bundle frontmost_pid
  host_app="$(claude_code_host_open_app_name)"
  host_bundle="$(claude_code_host_bundle_id)"

  focus_claude_code_ghostty_proof_window_by_title || return 1
  CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED=1
  try_wait_for_frontmost_app "$host_app" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TITLE_FRONTMOST_SECONDS:-3}" || return 1

  frontmost_bundle="$(frontmost_bundle_identifier 2>/dev/null || true)"
  if [[ -n "$host_bundle" && "$frontmost_bundle" != "$host_bundle" ]]; then
    return 1
  fi

  frontmost_pid="$(frontmost_process_id 2>/dev/null || true)"
  frontmost_pid="$(printf '%s' "$frontmost_pid" | tr -dc '0-9')"
  [[ -n "$frontmost_pid" ]] || return 1
  printf '%s\n' "$frontmost_pid"
}

open_claude_code_terminal_proof() {
  local proof_dir="$1"
  local proof_title="$2"
  local claude_bin title_sequence launch_script terminal_pids_before host_process host_app
  local ghostty_pid ghostty_launch_command ghostty_launch_action ghostty_launch_action_drain ghostty_launch_stage_file ghostty_shell_ready_delay ghostty_exit_hold_seconds ghostty_preflight_status ghostty_preflight_pids ghostty_configured_window_first ghostty_command_open_ready ghostty_claude_permission_mode
  claude_bin="$(command -v claude || true)"
  if [[ -z "$claude_bin" ]]; then
    echo "Claude Code CLI is not installed or not on PATH." >&2
    exit 1
  fi
  host_process="$(claude_code_host_process_name)"
  host_app="$(claude_code_host_open_app_name)"
  if [[ -z "$host_process" || -z "$host_app" ]]; then
    echo "Claude Code $(claude_code_host_display_name) proof does not have an automated disposable launch path yet." >&2
    echo "Leaving this as an honest host-variant proof gap; normal terminal suggestions remain blocked." >&2
    exit 1
  fi

  if pgrep -x "$host_process" >/dev/null 2>&1; then
    CLAUDE_CODE_TERMINAL_WAS_RUNNING=1
  else
    CLAUDE_CODE_TERMINAL_WAS_RUNNING=0
  fi

  title_sequence=$'\033]0;'"$proof_title"$'\007'
  launch_script="$proof_dir/steadytype-claude-code-proof.command"
  CLAUDE_CODE_TERMINAL_PROOF_LAUNCH_SCRIPT="$launch_script"
  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE="$proof_dir/claude.pid"
  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE="$proof_dir/claude.exit"
  ghostty_launch_stage_file="$proof_dir/ghostty-launch.log"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf '"'"'%%s\\n'"'"' script-started >> %q\n' "$ghostty_launch_stage_file"
    printf 'cd %q\n' "$ROOT_DIR"
    printf 'printf '"'"'%%s\\n'"'"' "$$" > %q\n' "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE"
    printf 'printf '"'"'%%s\\n'"'"' script-wrote-pidfile >> %q\n' "$ghostty_launch_stage_file"
    printf 'printf %q\n' "$title_sequence"
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      ghostty_exit_hold_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_EXIT_HOLD_SECONDS:-20}"
      ghostty_claude_permission_mode="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PERMISSION_MODE:-plan}"
      printf 'printf '"'"'%%s\\n'"'"' script-starting-claude >> %q\n' "$ghostty_launch_stage_file"
      printf '%q --permission-mode %q\n' "$claude_bin" "$ghostty_claude_permission_mode"
      printf 'claude_status=$?\n'
      printf 'printf '"'"'%%s\\n'"'"' "script-claude-returned:$claude_status" >> %q\n' "$ghostty_launch_stage_file"
      printf 'printf '"'"'status=%%s finished_at=%%s\\n'"'"' "$claude_status" "$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ)" > %q\n' "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE"
      printf 'printf '"'"'\\n[SteadyType proof] Claude exited with status %%s; keeping Ghostty open for diagnostics.\\n'"'"' "$claude_status"\n'
      printf 'sleep %q\n' "$ghostty_exit_hold_seconds"
      printf 'exit "$claude_status"\n'
    else
      printf 'exec %q\n' "$claude_bin"
    fi
  } >"$launch_script"
  chmod +x "$launch_script"

  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME="${claude_bin##*/}"
  terminal_pids_before="$(terminal_pid_list)"
  case "$CLAUDE_CODE_HOST_VARIANT" in
    terminal|iterm2)
      CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=1
      open -na "$host_app" "$launch_script"
      CLAUDE_CODE_TERMINAL_PROOF_PIDS="$(wait_for_new_terminal_pids "$terminal_pids_before")"
      ;;
    ghostty)
      CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=0
      ghostty_launch_command="$(printf 'exec %q' "$launch_script")"
      ghostty_launch_action=""
      if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_ACTION_PROBE:-1}" =~ ^(1|true|yes|on)$ ]]; then
        ghostty_launch_action="$(ghostty_text_action "$ghostty_launch_command")"
      fi
      ghostty_launch_action_drain="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_ACTION_DRAIN_SECONDS:-0.2}"
      ghostty_shell_ready_delay="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_SHELL_READY_DELAY_SECONDS:-1.8}"
      ghostty_configured_window_first=0
      ghostty_command_open_ready=0
      : >"$ghostty_launch_stage_file"
      if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]] &&
         [[ "${CLAUDE_CODE_GHOSTTY_SKIP_DIRECT_COMMAND_OPEN:-0}" != "1" ]] &&
         [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NO_RESTORE_OPEN_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]] &&
         ! pgrep -x ghostty >/dev/null 2>&1; then
        echo "Claude Code Ghostty proof opening no-restore host directly with proof command."
        printf '%s\n' "no-restore-command-open-start" >>"$ghostty_launch_stage_file"
        open -na "$host_app" --args \
          --window-save-state=never \
          --quit-after-last-window-closed=true \
          --working-directory="$ROOT_DIR" \
          -e "$launch_script" >/dev/null 2>&1 || true
        printf '%s\n' "no-restore-command-open-finished" >>"$ghostty_launch_stage_file"
        sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NO_RESTORE_OPEN_SETTLE_SECONDS:-1}"
        allow_claude_code_ghostty_proof_command_alert \
          "$launch_script" \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_ALERT_SECONDS:-2}" || true
        ghostty_preflight_pids="$(terminal_pid_list | tr '\n' ' ')"
        ghostty_preflight_pids="${ghostty_preflight_pids% }"
        if [[ -n "$ghostty_preflight_pids" ]]; then
          CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=1
          CLAUDE_CODE_TERMINAL_PROOF_PIDS="$ghostty_preflight_pids"
          CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=1
          echo "Claude Code Ghostty proof owns no-restore command host pid(s): $CLAUDE_CODE_TERMINAL_PROOF_PIDS"
        fi
        if wait_for_claude_code_terminal_pidfile_process_optional \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_PID_SECONDS:-12}"; then
          printf '%s\n' "no-restore-command-open-pidfile-present" >>"$ghostty_launch_stage_file"
          if try_wait_for_frontmost_claude_code_terminal_proof_process \
            "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_FRONTMOST_SECONDS:-5}" &&
             ghostty_window_api_reports_visible_window; then
            printf '%s\n' "no-restore-command-open-frontmost" >>"$ghostty_launch_stage_file"
            ghostty_command_open_ready=1
            CLAUDE_CODE_GHOSTTY_USED_DIRECT_COMMAND_OPEN=1
          else
            printf '%s\n' "no-restore-command-open-not-frontmost" >>"$ghostty_launch_stage_file"
            echo "Claude Code Ghostty proof no-restore command host wrote pidfile but did not expose a frontmost window; falling back to script-owned window launch." >&2
            if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]]; then
              kill $CLAUDE_CODE_TERMINAL_PROOF_PIDS >/dev/null 2>&1 || true
              sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
            fi
            CLAUDE_CODE_TERMINAL_PROOF_PIDS=""
            CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=0
            CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=0
            reset_zero_window_claude_code_ghostty_proof_host
          fi
        else
          printf '%s\n' "no-restore-command-open-no-pidfile" >>"$ghostty_launch_stage_file"
          if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]]; then
            echo "Claude Code Ghostty proof no-restore command host did not write pidfile; cleaning pid(s): $CLAUDE_CODE_TERMINAL_PROOF_PIDS" >&2
            kill $CLAUDE_CODE_TERMINAL_PROOF_PIDS >/dev/null 2>&1 || true
            sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
          fi
          CLAUDE_CODE_TERMINAL_PROOF_PIDS=""
          CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=0
          CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=0
        fi
      fi
      if [[ "$ghostty_command_open_ready" != "1" ]] &&
         [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NO_RESTORE_OPEN_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]] &&
         ! pgrep -x ghostty >/dev/null 2>&1; then
        : >"$ghostty_launch_stage_file"
      fi
      if [[ "$ghostty_command_open_ready" != "1" ]] &&
         [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NO_RESTORE_OPEN_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]] &&
         ! pgrep -x ghostty >/dev/null 2>&1; then
        echo "Claude Code Ghostty proof opening host with window-save-state=never before AppleScript preflight."
        if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_INITIAL_WINDOW_DISABLED:-1}" =~ ^(1|true|yes|on)$ ]]; then
          ghostty_configured_window_first=1
          printf '%s\n' "no-restore-host-initial-window-disabled" >>"$ghostty_launch_stage_file"
          open -na "$host_app" --args --window-save-state=never --initial-window=false --quit-after-last-window-closed=true >/dev/null 2>&1 || true
        else
          open -na "$host_app" --args --window-save-state=never --quit-after-last-window-closed=true >/dev/null 2>&1 || true
        fi
        sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NO_RESTORE_OPEN_SETTLE_SECONDS:-1}"
        ghostty_preflight_pids="$(terminal_pid_list | tr '\n' ' ')"
        ghostty_preflight_pids="${ghostty_preflight_pids% }"
        if [[ -n "$ghostty_preflight_pids" ]]; then
          CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=1
          CLAUDE_CODE_TERMINAL_PROOF_PIDS="$ghostty_preflight_pids"
          CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=1
          echo "Claude Code Ghostty proof owns no-restore host pid(s): $CLAUDE_CODE_TERMINAL_PROOF_PIDS"
          if wait_for_ghostty_process_tree_child_optional \
            "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CHILD_PROCESS_READY_SECONDS:-2}"; then
            echo "Claude Code Ghostty proof no-restore host has a child process before AppleScript preflight."
            printf '%s\n' "no-restore-host-child-present" >>"$ghostty_launch_stage_file"
          else
            echo "Claude Code Ghostty proof no-restore host has no shell child before AppleScript preflight." >&2
            printf '%s\n' "no-restore-host-no-child-process" >>"$ghostty_launch_stage_file"
            describe_claude_code_ghostty_process_tree
          fi
        fi
      fi
      if [[ "$ghostty_command_open_ready" != "1" ]] &&
         check_claude_code_ghostty_applescript_health "$ghostty_launch_stage_file"; then
        ghostty_preflight_status=0
      else
        if [[ "$ghostty_command_open_ready" == "1" ]]; then
          ghostty_preflight_status=0
        else
          ghostty_preflight_status=$?
        fi
      fi
      if ((ghostty_preflight_status != 0)); then
        return "$ghostty_preflight_status"
      fi
      if [[ "$ghostty_command_open_ready" != "1" ]]; then
        reset_stale_only_claude_code_ghostty_proof_host
        if [[ "$ghostty_configured_window_first" == "1" ]]; then
          printf '%s\n' "zero-window-reset-deferred-for-configured-window" >>"$ghostty_launch_stage_file"
        else
          reset_zero_window_claude_code_ghostty_proof_host
        fi
      if ! run_osascript_with_timeout \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NEW_WINDOW_TIMEOUT_SECONDS:-10}" \
          "Claude Code Ghostty proof launch" \
          - "$ghostty_launch_command" "$ghostty_shell_ready_delay" "$proof_title" "$ghostty_launch_action" "$ghostty_launch_action_drain" "$ghostty_launch_stage_file" "$ROOT_DIR" "$launch_script" "$ghostty_configured_window_first" <<'APPLESCRIPT' >/dev/null; then
on recordStage(stageFile, stageName)
  if stageFile is not "" then
    try
      do shell script "/bin/echo " & quoted form of stageName & " >> " & quoted form of stageFile
    end try
  end if
end recordStage

on run argv
set launchCommand to item 1 of argv
set shellReadyDelay to item 2 of argv as real
set proofTitle to item 3 of argv
set launchAction to item 4 of argv
set launchActionDrain to item 5 of argv as real
set launchStageFile to item 6 of argv
set rootDirectory to item 7 of argv
set launchScriptPath to item 8 of argv
set configuredWindowFirst to item 9 of argv
set commandAlreadyLaunched to false
recordStage(launchStageFile, "launch-begin")
tell application id "com.mitchellh.ghostty"
  my recordStage(launchStageFile, "new-window-start")
  if configuredWindowFirst is "1" then
    my recordStage(launchStageFile, "configured-window-start")
    set proofConfig to new surface configuration from {initial working directory:rootDirectory, command:launchScriptPath, wait after command:true}
    set proofWindow to new window with configuration proofConfig
    set commandAlreadyLaunched to true
    my recordStage(launchStageFile, "configured-window-created")
    my recordStage(launchStageFile, "new-window-created")
  else
    my recordStage(launchStageFile, "new-window-count-start")
    set existingWindowCount to count windows
    my recordStage(launchStageFile, "new-window-count:" & (existingWindowCount as text))
    if existingWindowCount is 0 then
      my recordStage(launchStageFile, "configured-window-start")
      set proofConfig to new surface configuration from {initial working directory:rootDirectory, command:launchScriptPath, wait after command:true}
      set proofWindow to new window with configuration proofConfig
      set commandAlreadyLaunched to true
      my recordStage(launchStageFile, "configured-window-created")
      my recordStage(launchStageFile, "new-window-created")
    else
    my recordStage(launchStageFile, "new-window-front-window-start")
    set sourceWindow to missing value
    set sourceWindowCount to 0
    repeat with sourceWindowAttempt from 1 to 20
      try
        set sourceWindowCount to count windows
        if sourceWindowCount > 0 then
          set sourceWindow to front window
          exit repeat
        end if
      end try
      delay 0.1
    end repeat
    my recordStage(launchStageFile, "new-window-source-window-count:" & (sourceWindowCount as text))
    if sourceWindow is missing value then
      my recordStage(launchStageFile, "new-window-no-source-window")
      error "Ghostty proof has no source window for disposable launch."
    end if
    my recordStage(launchStageFile, "new-window-front-window-resolved")
    my recordStage(launchStageFile, "new-window-selected-tab-start")
    my recordStage(launchStageFile, "new-window-focused-terminal-start")
    set sourceTerminal to missing value
    set sourceTerminalReady to false
    repeat with sourceTerminalAttempt from 1 to 20
      try
        set sourceTab to selected tab of sourceWindow
        my recordStage(launchStageFile, "new-window-selected-tab-resolved")
        set sourceTerminal to focused terminal of sourceTab
        set sourceTerminalReady to true
        exit repeat
      end try
      delay 0.1
    end repeat
    if sourceTerminal is missing value or sourceTerminalReady is false then
      my recordStage(launchStageFile, "new-window-source-terminal-not-ready")
      error "Ghostty proof source terminal was not ready for disposable launch."
    end if
    my recordStage(launchStageFile, "new-window-focused-terminal-resolved")
    my recordStage(launchStageFile, "new-window-source-terminal-ready")
    try
      set sourceTerminalDirectory to working directory of sourceTerminal as text
      if sourceTerminalDirectory is not "" then
        my recordStage(launchStageFile, "new-window-source-terminal-working-directory-present")
      else
        my recordStage(launchStageFile, "new-window-source-terminal-working-directory-empty")
      end if
    on error
      my recordStage(launchStageFile, "new-window-source-terminal-working-directory-unavailable")
    end try
    my recordStage(launchStageFile, "new-window-action-ready")
    perform action "new_window" on sourceTerminal
    my recordStage(launchStageFile, "new-window-action-finished")
    delay 0.5
    set proofWindow to front window
    my recordStage(launchStageFile, "new-window-created")
    end if
  end if
  activate window proofWindow
  my recordStage(launchStageFile, "window-activated")
  delay shellReadyDelay
  my recordStage(launchStageFile, "shell-delay-finished")
  set targetTerminal to missing value
  set terminalReady to false
  repeat with readyAttempt from 1 to 60
    try
      set targetTab to selected tab of proofWindow
      set targetTerminal to focused terminal of targetTab
      set terminalReady to true
      exit repeat
    end try
    delay 0.1
  end repeat
  if targetTerminal is missing value or terminalReady is false then error "Ghostty proof terminal was not ready."
  my recordStage(launchStageFile, "terminal-ready")
  try
    set terminalDirectory to working directory of targetTerminal as text
    if terminalDirectory is not "" then
      my recordStage(launchStageFile, "terminal-working-directory-present")
    else
      my recordStage(launchStageFile, "terminal-working-directory-empty")
    end if
  on error
    my recordStage(launchStageFile, "terminal-working-directory-unavailable")
  end try
  focus targetTerminal
  my recordStage(launchStageFile, "terminal-focused")
  perform action ("set_surface_title:" & proofTitle) on targetTerminal
  perform action ("set_tab_title:" & proofTitle) on targetTerminal
  my recordStage(launchStageFile, "title-marked")
  if commandAlreadyLaunched is true then
    my recordStage(launchStageFile, "configured-window-command-owned-launch")
  else if launchAction is not "" then
    my recordStage(launchStageFile, "launch-action-start")
    perform action launchAction on targetTerminal
    my recordStage(launchStageFile, "launch-action-finished")
    send key "enter" to targetTerminal
    my recordStage(launchStageFile, "launch-action-enter-sent")
    delay launchActionDrain
  else
    my recordStage(launchStageFile, "input-text-start")
    input text launchCommand to targetTerminal
    my recordStage(launchStageFile, "input-text-finished")
    send key "enter" to targetTerminal
    my recordStage(launchStageFile, "enter-sent")
  end if
  activate
  my recordStage(launchStageFile, "launch-finished")
end tell
end run
APPLESCRIPT
        describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
        describe_claude_code_ghostty_launch_state "$proof_title"
        describe_claude_code_ghostty_process_tree
        if grep -Fxq "configured-window-start" "$ghostty_launch_stage_file" 2>/dev/null &&
           ! grep -Fxq "configured-window-created" "$ghostty_launch_stage_file" 2>/dev/null; then
          echo "Claude Code Ghostty proof configured-window API stalled before disposable window creation; skipping retry." >&2
          return 42
        fi
        if grep -Fxq "new-window-no-source-window" "$ghostty_launch_stage_file" 2>/dev/null; then
          echo "Claude Code Ghostty proof had no source window for disposable window creation; skipping retry." >&2
          return 42
        fi
        if grep -Fxq "new-window-source-terminal-not-ready" "$ghostty_launch_stage_file" 2>/dev/null; then
          echo "Claude Code Ghostty proof source terminal was not ready for disposable window creation; skipping retry." >&2
          return 42
        fi
        if claude_code_ghostty_launch_stalled_before_stage "$ghostty_launch_stage_file" "new-window-start"; then
          echo "Claude Code Ghostty proof AppleScript bridge stalled before disposable window creation; skipping retry." >&2
          return 42
        fi
        echo "Claude Code Ghostty proof could not create a script-owned disposable proof window." >&2
        return 1
      fi
      if ! wait_for_claude_code_terminal_pidfile_process_optional \
        "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_LAUNCH_PID_SECONDS:-8}"; then
        if grep -Fxq "configured-window-start" "$ghostty_launch_stage_file" 2>/dev/null &&
           ! grep -Fxq "configured-window-created" "$ghostty_launch_stage_file" 2>/dev/null; then
          describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_state "$proof_title"
          describe_claude_code_ghostty_process_tree
          echo "Claude Code Ghostty proof configured-window API stalled before disposable window creation; skipping retry." >&2
          return 42
        fi
        if claude_code_ghostty_launch_stalled_before_stage "$ghostty_launch_stage_file" "new-window-created"; then
          describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_state "$proof_title"
          describe_claude_code_ghostty_process_tree
          echo "Claude Code Ghostty proof AppleScript bridge stalled during disposable window creation; skipping retry." >&2
          return 42
        fi
        if claude_code_ghostty_configured_window_shell_not_ready "$ghostty_launch_stage_file"; then
          printf '%s\n' "configured-window-shell-not-ready" >>"$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_state "$proof_title"
          describe_claude_code_ghostty_process_tree
          echo "Claude Code Ghostty proof configured window opened but did not become shell-ready; retrying command submission." >&2
        fi
        if ! run_osascript_with_timeout \
            "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_RETRY_LAUNCH_TIMEOUT_SECONDS:-10}" \
            "Claude Code Ghostty proof launch retry" \
            - "$ghostty_launch_command" "$ghostty_shell_ready_delay" "$proof_title" "$ghostty_launch_action" "$ghostty_launch_action_drain" "$ghostty_launch_stage_file" <<'APPLESCRIPT' >/dev/null; then
on recordStage(stageFile, stageName)
  if stageFile is not "" then
    try
      do shell script "/bin/echo " & quoted form of stageName & " >> " & quoted form of stageFile
    end try
  end if
end recordStage

on run argv
set launchCommand to item 1 of argv
set shellReadyDelay to item 2 of argv as real
set proofTitle to item 3 of argv
set launchAction to item 4 of argv
set launchActionDrain to item 5 of argv as real
set launchStageFile to item 6 of argv
recordStage(launchStageFile, "retry-begin")
tell application id "com.mitchellh.ghostty"
  set proofWindow to missing value
  repeat with candidateWindow in windows
    try
      set windowName to name of candidateWindow as text
      if windowName contains proofTitle then
        set proofWindow to candidateWindow
        exit repeat
      end if
    end try
  end repeat
  if proofWindow is missing value then set proofWindow to front window
  my recordStage(launchStageFile, "retry-window-selected")
  activate window proofWindow
  my recordStage(launchStageFile, "retry-window-activated")
  delay shellReadyDelay
  my recordStage(launchStageFile, "retry-shell-delay-finished")
  set targetTerminal to missing value
  set terminalReady to false
  repeat with readyAttempt from 1 to 60
    try
      set targetTab to selected tab of proofWindow
      set targetTerminal to focused terminal of targetTab
      set terminalReady to true
      exit repeat
    end try
    delay 0.1
  end repeat
  if targetTerminal is missing value or terminalReady is false then error "Ghostty proof terminal was not ready."
  my recordStage(launchStageFile, "retry-terminal-ready")
  try
    set terminalDirectory to working directory of targetTerminal as text
    if terminalDirectory is not "" then
      my recordStage(launchStageFile, "retry-terminal-working-directory-present")
    else
      my recordStage(launchStageFile, "retry-terminal-working-directory-empty")
    end if
  on error
    my recordStage(launchStageFile, "retry-terminal-working-directory-unavailable")
  end try
  focus targetTerminal
  my recordStage(launchStageFile, "retry-terminal-focused")
  perform action ("set_surface_title:" & proofTitle) on targetTerminal
  perform action ("set_tab_title:" & proofTitle) on targetTerminal
  my recordStage(launchStageFile, "retry-title-marked")
  try
    send key "u" modifiers "control" to targetTerminal
    my recordStage(launchStageFile, "retry-clear-sent")
  end try
  if launchAction is not "" then
    my recordStage(launchStageFile, "retry-launch-action-start")
    perform action launchAction on targetTerminal
    my recordStage(launchStageFile, "retry-launch-action-finished")
    send key "enter" to targetTerminal
    my recordStage(launchStageFile, "retry-launch-action-enter-sent")
    delay launchActionDrain
  else
    my recordStage(launchStageFile, "retry-input-text-start")
    input text launchCommand to targetTerminal
    my recordStage(launchStageFile, "retry-input-text-finished")
    send key "enter" to targetTerminal
    my recordStage(launchStageFile, "retry-enter-sent")
  end if
  activate
  my recordStage(launchStageFile, "retry-launch-finished")
end tell
end run
APPLESCRIPT
          describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_state "$proof_title"
          describe_claude_code_ghostty_process_tree
          echo "Claude Code Ghostty proof could not retry the disposable proof command." >&2
          return 1
        fi
        if ! wait_for_claude_code_terminal_pidfile_process_optional \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_RETRY_PID_SECONDS:-10}"; then
          if claude_code_ghostty_retry_window_shell_not_ready "$ghostty_launch_stage_file"; then
            printf '%s\n' "retry-configured-window-shell-not-ready" >>"$ghostty_launch_stage_file"
          fi
          describe_claude_code_terminal_proof_process_state \
            "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME" \
            "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME"
          describe_claude_code_ghostty_launch_stages "$ghostty_launch_stage_file"
          describe_claude_code_ghostty_launch_state "$proof_title"
          describe_claude_code_ghostty_process_tree
          if claude_code_ghostty_retry_window_shell_not_ready "$ghostty_launch_stage_file"; then
            echo "Claude Code Ghostty proof configured window never became shell-ready enough to exec the disposable proof command." >&2
          else
            echo "Claude Code Ghostty proof shell did not exec the disposable proof command." >&2
          fi
          return 1
        fi
      fi
      fi
      mark_claude_code_ghostty_proof_window_title || {
        echo "Claude Code Ghostty proof could not mark the disposable proof window title." >&2
        return 1
      }
      ghostty_pid="$(claude_code_ghostty_frontmost_proof_process_id_by_title 2>/dev/null || true)"
      ghostty_pid="$(printf '%s' "$ghostty_pid" | tr -dc '0-9')"
      if [[ -z "$ghostty_pid" ]]; then
        if ! try_wait_for_frontmost_app "$host_app" "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NEW_WINDOW_FRONTMOST_SECONDS:-6}"; then
          focus_claude_code_ghostty_proof_window_by_title || true
        fi
        if ! try_wait_for_frontmost_app "$host_app" "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NEW_WINDOW_FRONTMOST_SECONDS:-6}"; then
          echo "Claude Code Ghostty proof window did not become frontmost after script-owned launch." >&2
          return 1
        fi
        ghostty_pid="$(frontmost_process_id 2>/dev/null || true)"
        ghostty_pid="$(printf '%s' "$ghostty_pid" | tr -dc '0-9')"
        if [[ -z "$ghostty_pid" ]]; then
          echo "Claude Code Ghostty proof could not resolve the script-owned frontmost Ghostty pid." >&2
          return 1
        fi
      fi
      CLAUDE_CODE_TERMINAL_PROOF_PIDS="$ghostty_pid"
      ;;
    *)
      echo "Claude Code $(claude_code_host_display_name) proof does not have an automated disposable launch path yet." >&2
      exit 1
      ;;
  esac
  if ! try_wait_for_frontmost_claude_code_terminal_proof_process; then
    echo "Claude Code Terminal proof process did not become frontmost: $CLAUDE_CODE_TERMINAL_PROOF_PIDS" >&2
    return 1
  fi
}

cleanup_claude_code_terminal_proof() {
  if [[ -z "$CLAUDE_CODE_TERMINAL_PROOF_TITLE" ]]; then
    return 0
  fi

  if [[ -n "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" &&
        -s "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" ]]; then
    local proof_process_pid
    proof_process_pid="$(head -n 1 "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" | tr -dc '0-9')"
    if [[ -n "$proof_process_pid" ]]; then
      kill "$proof_process_pid" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS" == "1" &&
        -n "$CLAUDE_CODE_TERMINAL_PROOF_PIDS" ]]; then
    if [[ "$CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO" == "1" ]]; then
      echo "Claude Code Ghostty proof cleaning no-restore host pid(s): $CLAUDE_CODE_TERMINAL_PROOF_PIDS" >&2
    fi
    kill $CLAUDE_CODE_TERMINAL_PROOF_PIDS >/dev/null 2>&1 || true
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
    local proof_pid
    for proof_pid in $CLAUDE_CODE_TERMINAL_PROOF_PIDS; do
      if kill -0 "$proof_pid" >/dev/null 2>&1; then
        kill -KILL "$proof_pid" >/dev/null 2>&1 || true
      fi
    done
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
    if [[ "$CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO" == "1" ]]; then
      reset_zero_window_claude_code_ghostty_proof_host
      reset_stale_only_claude_code_ghostty_proof_host
    fi
  elif [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    close_claude_code_ghostty_proof_window_by_title || true
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
    reset_stale_only_claude_code_ghostty_proof_host
    reset_zero_window_claude_code_ghostty_proof_host
  elif [[ "$CLAUDE_CODE_TERMINAL_WAS_RUNNING" != "1" ]]; then
    local host_process
    host_process="$(claude_code_host_process_name)"
    [[ -n "$host_process" ]] && pkill -x "$host_process" >/dev/null 2>&1 || true
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
  fi
  CLAUDE_CODE_TERMINAL_PROOF_TITLE=""
  CLAUDE_CODE_TERMINAL_PROOF_PIDS=""
  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME=""
  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE=""
  CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE=""
  CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=1
  CLAUDE_CODE_GHOSTTY_PROOF_OPENED_HOST_FROM_ZERO=0
  CLAUDE_CODE_GHOSTTY_USED_DIRECT_COMMAND_OPEN=0
  CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT=0
  CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED=0
  CLAUDE_CODE_TERMINAL_WAS_RUNNING=0
}

ghostty_window_api_reports_visible_window() {
  local window_count

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  window_count="$(run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_WINDOW_CHECK_TIMEOUT_SECONDS:-2}" \
    "Claude Code Ghostty visible-window check" <<'APPLESCRIPT' 2>/dev/null || true
tell application id "com.mitchellh.ghostty"
  return (count windows) as text
end tell
APPLESCRIPT
)"
  window_count="$(printf '%s' "$window_count" | tr -d '[:space:]')"
  [[ "$window_count" =~ ^[1-9][0-9]*$ ]]
}

reset_zero_window_claude_code_ghostty_proof_host() {
  local ghostty_pids window_count ax_window_count proof_pid reset_reason

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  if [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi

  ghostty_pids="$(pgrep -x ghostty 2>/dev/null || true)"
  [[ -n "$ghostty_pids" ]] || return 0

  window_count="$(run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_CHECK_TIMEOUT_SECONDS:-2}" \
    "Claude Code Ghostty zero-window host check" <<'APPLESCRIPT' 2>/dev/null || true
tell application id "com.mitchellh.ghostty"
  return (count windows) as text
end tell
APPLESCRIPT
)"
  window_count="$(printf '%s' "$window_count" | tr -d '[:space:]')"
  if [[ "$window_count" == "0" ]]; then
    reset_reason="Ghostty window API reported zero windows"
  else
    ax_window_count="$(run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_AX_WINDOW_CHECK_TIMEOUT_SECONDS:-2}" \
      "Claude Code Ghostty AX zero-window host check" <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  tell application process "Ghostty"
    return (count windows) as text
  end tell
end tell
APPLESCRIPT
)"
    ax_window_count="$(printf '%s' "$ax_window_count" | tr -d '[:space:]')"
    [[ "$ax_window_count" == "0" ]] || return 0
    reset_reason="System Events reported zero Ghostty AX windows while Ghostty window API reported ${window_count:-unavailable}"
  fi

  echo "Claude Code Ghostty proof resetting zero-window Ghostty host pid(s): $(printf '%s' "$ghostty_pids" | tr '\n' ' ') ($reset_reason)" >&2
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    kill "$proof_pid" >/dev/null 2>&1 || true
  done <<<"$ghostty_pids"
  sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    if kill -0 "$proof_pid" >/dev/null 2>&1; then
      kill -KILL "$proof_pid" >/dev/null 2>&1 || true
    fi
  done <<<"$ghostty_pids"
  sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
}

close_claude_code_ghostty_proof_window_by_title() {
  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  [[ -n "${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}" ]] || return 0

  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE="$CLAUDE_CODE_TERMINAL_PROOF_TITLE" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$(claude_code_proof_marker)" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_COMPACT_PROOF_MARKER="$(claude_code_compact_proof_marker)" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CLOSE_TIMEOUT_SECONDS:-4}" \
      "Claude Code Ghostty proof window close" <<'APPLESCRIPT' >/dev/null || true
set proofTitle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE"
set proofMarker to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_COMPACT_PROOF_MARKER"
tell application id "com.mitchellh.ghostty"
  repeat with candidateWindow in windows
    try
      set windowName to name of candidateWindow as text
      if windowName contains proofTitle or windowName contains proofMarker or windowName contains compactProofMarker then
        close window candidateWindow
        return true
      end if
    end try
  end repeat
end tell
return false
APPLESCRIPT
}

reset_stale_only_claude_code_ghostty_proof_host() {
  local marker ghostty_pids ax_state ax_window_count unsafe_window_count proof_pid reset_reason

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 0
  if [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi

  ghostty_pids="$(pgrep -x ghostty 2>/dev/null || true)"
  [[ -n "$ghostty_pids" ]] || return 0

  marker="$(claude_code_proof_marker)"
  ax_state="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$marker" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_CHECK_TIMEOUT_SECONDS:-2}" \
      "Claude Code Ghostty stale-only host check" <<'APPLESCRIPT' 2>/dev/null || true
set markerText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set proofDirectoryMarker to "steadytype-claude-code-proof"
set steadyTypeGhosttyProbeMarker to "steadytype-ghostty-"
set appleScriptProbePrefix to "SteadyType AppleScript Probe"
set submitProbePrefix to "SteadyType Submit Probe"
set windowCount to 0
set unsafeWindowCount to 0
tell application "System Events"
  if not (exists application process "Ghostty") then return "windows=0 unsafe=0"
  tell application process "Ghostty"
    set windowCount to count windows
    repeat with candidateWindow in windows
      set windowName to ""
      try
        set windowName to name of candidateWindow as text
      end try
      set isProofWindow to false
      if markerText is not "" and windowName contains markerText then set isProofWindow to true
      if windowName contains proofDirectoryMarker then set isProofWindow to true
      if windowName contains steadyTypeGhosttyProbeMarker then set isProofWindow to true
      if windowName starts with appleScriptProbePrefix then set isProofWindow to true
      if windowName starts with submitProbePrefix then set isProofWindow to true
      if isProofWindow is false then set unsafeWindowCount to unsafeWindowCount + 1
    end repeat
  end tell
end tell
return "windows=" & (windowCount as text) & " unsafe=" & (unsafeWindowCount as text)
APPLESCRIPT
)"
  ax_window_count="$(printf '%s' "$ax_state" | sed -n 's/.*windows=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  unsafe_window_count="$(printf '%s' "$ax_state" | sed -n 's/.*unsafe=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  if [[ ! "$ax_window_count" =~ ^[1-9][0-9]*$ || "$unsafe_window_count" != "0" ]]; then
    if [[ "$ax_window_count" =~ ^[0-9]+$ && "$unsafe_window_count" =~ ^[0-9]+$ ]]; then
      echo "Claude Code Ghostty proof not resetting stale-only host: AX windows=$ax_window_count unsafe=$unsafe_window_count" >&2
    fi
    return 0
  fi

  reset_reason="System Events reported only SteadyType proof/probe Ghostty AX windows (${ax_window_count})"
  echo "Claude Code Ghostty proof resetting stale-only Ghostty host pid(s): $(printf '%s' "$ghostty_pids" | tr '\n' ' ') ($reset_reason)" >&2
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    kill "$proof_pid" >/dev/null 2>&1 || true
  done <<<"$ghostty_pids"
  sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    if kill -0 "$proof_pid" >/dev/null 2>&1; then
      kill -KILL "$proof_pid" >/dev/null 2>&1 || true
    fi
  done <<<"$ghostty_pids"
  sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
}

cleanup_stale_claude_code_ghostty_proofs() {
  local marker cleanup_legacy_tmp_windows closed_count
  marker="$(claude_code_proof_marker)"
  cleanup_legacy_tmp_windows="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_LEGACY_TMP_WINDOWS:-0}"

  pgrep -x ghostty >/dev/null 2>&1 || return 0
  reset_stale_only_claude_code_ghostty_proof_host
  pgrep -x ghostty >/dev/null 2>&1 || return 0

  closed_count="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$marker" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_LEGACY_TMP="$cleanup_legacy_tmp_windows" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_CLEANUP_TIMEOUT_SECONDS:-4}" \
      "Claude Code Ghostty stale proof window cleanup" <<'APPLESCRIPT' || true
set markerText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set cleanupLegacyTmpWindows to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_LEGACY_TMP"
set proofDirectoryMarker to "steadytype-claude-code-proof"
set steadyTypeGhosttyProbeMarker to "steadytype-ghostty-"
set appleScriptProbePrefix to "SteadyType AppleScript Probe"
set submitProbePrefix to "SteadyType Submit Probe"
set closedCount to 0
tell application id "com.mitchellh.ghostty"
  repeat with windowIndex from (count windows) to 1 by -1
    try
      set candidateWindow to window windowIndex
      set windowName to name of candidateWindow as text
      if windowName contains markerText or windowName contains proofDirectoryMarker or windowName contains steadyTypeGhosttyProbeMarker or windowName starts with appleScriptProbePrefix or windowName starts with submitProbePrefix then
        close candidateWindow
        set closedCount to closedCount + 1
      else if cleanupLegacyTmpWindows is "1" and windowName starts with "tmp." then
        close candidateWindow
        set closedCount to closedCount + 1
      end if
    end try
  end repeat
end tell
return closedCount as text
APPLESCRIPT
)"
  if [[ "$closed_count" =~ ^[1-9][0-9]*$ ]]; then
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
  fi
  reset_stale_only_claude_code_ghostty_proof_host
  reset_zero_window_claude_code_ghostty_proof_host
}

cleanup_stale_claude_code_terminal_proofs() {
  local marker stale_pids stale_pid cleanup_host_bundle cleanup_legacy_tmp_windows
  marker="$(claude_code_proof_marker)"
  cleanup_host_bundle="$(claude_code_host_bundle_id)"
  cleanup_legacy_tmp_windows="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_LEGACY_TMP_WINDOWS:-1}"
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
        -z "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_LEGACY_TMP_WINDOWS+x}" ]]; then
    cleanup_legacy_tmp_windows=0
  fi
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    cleanup_stale_claude_code_ghostty_proofs
    return
  fi
  stale_pids="$(AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$marker" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_HOST_BUNDLE="$cleanup_host_bundle" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_LEGACY_TMP="$cleanup_legacy_tmp_windows" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_TIMEOUT_SECONDS:-4}" \
      "Claude Code terminal stale proof cleanup" <<'APPLESCRIPT' || true
set markerText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set targetHostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_HOST_BUNDLE"
set cleanupLegacyTmpWindows to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_LEGACY_TMP"
set proofDirectoryMarker to "steadytype-claude-code-proof"
set stalePids to ""
tell application "System Events"
  repeat with terminalProcess in application processes
    try
      set terminalBundle to bundle identifier of terminalProcess
      if terminalBundle is "com.apple.Terminal" or terminalBundle is "com.googlecode.iterm2" or terminalBundle is "com.mitchellh.ghostty" then
        if targetHostBundle is "auto" or terminalBundle is targetHostBundle then
          set hasProofWindow to false
          repeat with terminalWindow in windows of terminalProcess
            try
              set windowName to name of terminalWindow as text
              if windowName contains markerText or windowName contains proofDirectoryMarker then
                set hasProofWindow to true
              else if cleanupLegacyTmpWindows is "1" and windowName starts with "tmp." then
                set hasProofWindow to true
              end if
            end try
          end repeat
          if hasProofWindow then
            set stalePids to stalePids & ((unix id of terminalProcess) as text) & linefeed
          end if
        end if
      end if
    end try
  end repeat
end tell
return stalePids
APPLESCRIPT
)"
  while IFS= read -r stale_pid; do
    [[ -z "$stale_pid" ]] && continue
    kill "$stale_pid" >/dev/null 2>&1 || true
  done <<<"$stale_pids"
  if [[ -n "$stale_pids" ]]; then
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
    while IFS= read -r stale_pid; do
      [[ -z "$stale_pid" ]] && continue
      if kill -0 "$stale_pid" >/dev/null 2>&1; then
        kill -KILL "$stale_pid" >/dev/null 2>&1 || true
      fi
    done <<<"$stale_pids"
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS:-0.4}"
  fi
}

open_fresh_claude_code_terminal_proof_context() {
  local host_name="$1"
  local marker="$2"
  local proof_dir launch_attempt max_launch_attempts open_status
  max_launch_attempts="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CONTEXT_LAUNCH_ATTEMPTS:-2}"
  if ! [[ "$max_launch_attempts" =~ ^[0-9]+$ ]] || ((max_launch_attempts < 1)); then
    max_launch_attempts=1
  fi

  for launch_attempt in $(seq 1 "$max_launch_attempts"); do
    cleanup_claude_code_terminal_proof
    proof_dir="$(make_claude_code_terminal_proof_dir)"
    CLAUDE_CODE_TERMINAL_PROOF_TITLE="$(claude_code_terminal_proof_title_for_dir "$proof_dir")"
    if open_claude_code_terminal_proof "$proof_dir" "$CLAUDE_CODE_TERMINAL_PROOF_TITLE"; then
      open_status=0
    else
      open_status=$?
    fi
    if ((open_status != 0)); then
      echo "Claude Code $host_name proof could not launch disposable context attempt $launch_attempt." >&2
      if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" && "$open_status" == "42" ]]; then
        echo "Claude Code $host_name proof skipped remaining disposable launches because Ghostty AppleScript bridge or disposable window launch failed." >&2
        return "$open_status"
      fi
      continue
    fi
    if ! try_wait_for_frontmost_app "$host_name" "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACTIVATION_WAIT_SECONDS:-12}"; then
      echo "Claude Code $host_name proof host app did not become frontmost for fresh context attempt $launch_attempt." >&2
      continue
    fi
    if ! try_wait_for_claude_code_terminal_prompt; then
      echo "Claude Code $host_name proof prompt was not ready for fresh context attempt $launch_attempt." >&2
      if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
            "${CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT:-0}" == "1" ]]; then
        echo "Claude Code Ghostty proof direct command-open left launch-command text in AX; retrying without direct command-open." >&2
        CLAUDE_CODE_GHOSTTY_SKIP_DIRECT_COMMAND_OPEN=1
        CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT=0
        if ((launch_attempt >= max_launch_attempts)); then
          max_launch_attempts=$((max_launch_attempts + 1))
        fi
      fi
      continue
    fi
    if settle_claude_code_terminal_proof_focus "fresh proof context"; then
      return 0
    fi
    echo "Claude Code $host_name proof could not keep its disposable host focused for fresh context attempt $launch_attempt." >&2
  done

  echo "Claude Code $host_name proof could not launch a fresh disposable context after $max_launch_attempts attempt(s)." >&2
  return 1
}

try_wait_for_claude_code_terminal_prompt() {
  local proof_pid
  local -a proof_pid_args prompt_marker_args
  CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT=0

  if ! try_wait_for_frontmost_claude_code_terminal_proof_process; then
    echo "Claude Code Terminal proof process did not become frontmost: $CLAUDE_CODE_TERMINAL_PROOF_PIDS" >&2
    return 1
  fi
  if ! try_wait_for_claude_code_terminal_process_name \
    "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME" \
    "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_NAME"; then
    return 1
  fi
  proof_pid="$(claude_code_terminal_proof_primary_pid)"
  proof_pid_args=()
  if [[ -n "$proof_pid" ]]; then
    proof_pid_args=(--pid "$proof_pid")
  fi
  prompt_marker_args=()
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    prompt_marker_args=(--allow-missing-marker-for-empty-text --reject-shell-command-text --hint "shortcuts")
  fi

  case "$CLAUDE_CODE_HOST_VARIANT" in
    terminal|iterm2|ghostty)
      local prompt_wait_output prompt_wait_status
      prompt_wait_output="$(swift script/terminal_prompt_ax_proof_helper.swift wait \
        --bundle "$(claude_code_host_bundle_id)" \
        --display "$(claude_code_host_display_name)" \
        --marker "$(claude_code_proof_marker)" \
        "${proof_pid_args[@]}" \
        "${prompt_marker_args[@]}" \
        --discovery-timeout "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_DISCOVERY_TIMEOUT_SECONDS:-20}" 2>&1)"
      prompt_wait_status=$?
      if ((prompt_wait_status != 0)) &&
         [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
            "$prompt_wait_output" == *"rejectedShellCommand=true"* ]]; then
        echo "Claude Code Ghostty proof prompt still contains launch-command text; clearing before readiness retry."
        if clear_claude_code_terminal_prompt_line; then
          prompt_wait_output="$(swift script/terminal_prompt_ax_proof_helper.swift wait \
            --bundle "$(claude_code_host_bundle_id)" \
            --display "$(claude_code_host_display_name)" \
            --marker "$(claude_code_proof_marker)" \
            "${proof_pid_args[@]}" \
            "${prompt_marker_args[@]}" \
            --discovery-timeout "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_DISCOVERY_TIMEOUT_SECONDS:-20}" 2>&1)"
          prompt_wait_status=$?
        fi
      fi
      if ((prompt_wait_status != 0)); then
        if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] &&
           run_claude_code_ghostty_prompt_screen_copy_probe "$prompt_wait_output"; then
          echo "Claude Code Ghostty proof accepted native screen-copy prompt readiness after AX textNodes=0." >&2
          prompt_wait_status=0
        fi
      fi
      if ((prompt_wait_status != 0)); then
        if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
              "${CLAUDE_CODE_GHOSTTY_USED_DIRECT_COMMAND_OPEN:-0}" == "1" &&
              "$prompt_wait_output" == *"rejectedShellCommand=true"* ]]; then
          CLAUDE_CODE_GHOSTTY_DIRECT_COMMAND_OPEN_DIRTY_PROMPT=1
        fi
        printf '%s\n' "$prompt_wait_output" >&2
        return 1
      fi
      ;;
    *)
      echo "Claude Code $(claude_code_host_display_name) prompt readiness is not automated for this host." >&2
      return 1
      ;;
  esac
  sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROMPT_SETTLE_SECONDS:-3}"
}

wait_for_claude_code_terminal_prompt() {
  try_wait_for_claude_code_terminal_prompt || exit 1
}

assert_claude_code_terminal_prompt_ready() {
  local proof_text="$1"
  local proof_pid marker expected_prompt_text
  local -a proof_pid_args

  settle_claude_code_terminal_proof_focus "typed prompt AX check" || return 1
  proof_pid="$(claude_code_terminal_proof_primary_pid)"
  marker="$(claude_code_proof_marker)"
  expected_prompt_text="${proof_text//$marker/}"
  expected_prompt_text="$(printf '%s' "$expected_prompt_text" | awk '{$1=$1; print}')"
  proof_pid_args=()
  if [[ -n "$proof_pid" ]]; then
    proof_pid_args=(--pid "$proof_pid")
  fi
  local prompt_wait_output prompt_wait_status
  if prompt_wait_output="$(swift script/terminal_prompt_ax_proof_helper.swift wait \
    --bundle "$(claude_code_host_bundle_id)" \
    --display "$(claude_code_host_display_name)" \
    --marker "$(claude_code_proof_marker)" \
    --text "$expected_prompt_text" \
    --require-exact-text \
    "${proof_pid_args[@]}" \
    --discovery-timeout "$(claude_code_terminal_text_wait_seconds)" 2>&1)"; then
    prompt_wait_status=0
  else
    prompt_wait_status=$?
  fi
  if ((prompt_wait_status != 0)) &&
     [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] &&
     run_claude_code_ghostty_prompt_screen_copy_probe "$prompt_wait_output" "$expected_prompt_text"; then
    echo "Claude Code Ghostty proof accepted native screen-copy typed prompt readiness after AX miss." >&2
    return 0
  fi
  if ((prompt_wait_status != 0)) &&
     [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] &&
     run_claude_code_ghostty_prompt_anchor_diagnostics_probe "$proof_text"; then
    return 0
  fi
  if ((prompt_wait_status != 0)); then
    printf '%s\n' "$prompt_wait_output" >&2
    return "$prompt_wait_status"
  fi
}

try_claude_code_terminal_prompt_ready_quiet() {
  local proof_text="$1"
  local timeout_seconds="${2:-}"

  if [[ -n "$timeout_seconds" ]]; then
    AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_TEXT_WAIT_SECONDS="$timeout_seconds" \
      assert_claude_code_terminal_prompt_ready "$proof_text" >/dev/null 2>&1
  else
    assert_claude_code_terminal_prompt_ready "$proof_text" >/dev/null 2>&1
  fi
}

try_claude_code_terminal_prompt_ready_bounded_quiet() {
  local proof_text="$1"
  local timeout_seconds="${2:-}"
  local label="${3:-Claude Code terminal prompt readiness}"
  local guard_seconds pid status

  guard_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROMPT_READY_GUARD_SECONDS:-}"
  if [[ -z "$guard_seconds" ]]; then
    guard_seconds="${timeout_seconds:-$(claude_code_terminal_text_wait_seconds)}"
    guard_seconds="${guard_seconds%%.*}"
    if ! [[ "$guard_seconds" =~ ^[0-9]+$ ]] || ((guard_seconds < 1)); then
      guard_seconds=4
    fi
    guard_seconds=$((guard_seconds + 8))
  fi
  guard_seconds="${guard_seconds%%.*}"
  if ! [[ "$guard_seconds" =~ ^[0-9]+$ ]] || ((guard_seconds < 1)); then
    guard_seconds=12
  fi

  try_claude_code_terminal_prompt_ready_quiet "$proof_text" "$timeout_seconds" &
  pid="$!"
  wait_for_background_process "$pid" "$guard_seconds" "$label"
  status=$?
  if ((status == 124)); then
    echo "$label timed out while verifying prompt readiness." >&2
  fi
  return "$status"
}

claude_code_terminal_text_wait_seconds() {
  local wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_TEXT_WAIT_SECONDS:-}"
  if [[ -z "$wait_seconds" ]]; then
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      wait_seconds="12"
    else
      wait_seconds="4"
    fi
  fi
  if [[ "$wait_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$wait_seconds"
  else
    printf '%s\n' "4"
  fi
}

claude_code_terminal_accept_wait_seconds() {
  local wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACCEPT_WAIT_SECONDS:-}"
  if [[ -z "$wait_seconds" ]]; then
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ACCEPT_WAIT_SECONDS:-90}"
    else
      wait_seconds="30"
    fi
  fi
  if [[ "$wait_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$wait_seconds"
  else
    printf '%s\n' "30"
  fi
}

assert_claude_code_terminal_prompt_retains_marker() {
  settle_claude_code_terminal_proof_focus "marker retention AX check" || return 1
  claude_code_terminal_ax_helper contains-marker
}

type_claude_code_terminal_smoke_text() {
  local text="$1"
  local typing_mode="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_TYPING_MODE:-auto}"

  case "$typing_mode" in
    bulk)
      AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE=1 type_claude_code_terminal_raw_smoke_text "$text"
      ;;
    key-events)
      type_claude_code_terminal_raw_smoke_text "$text"
      ;;
    auto)
      case "$CLAUDE_CODE_HOST_VARIANT" in
        terminal)
          AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE=1 type_claude_code_terminal_raw_smoke_text "$text"
          ;;
        iterm2)
          type_claude_code_terminal_raw_smoke_text "$text"
          ;;
        ghostty)
          type_claude_code_terminal_ghostty_paste_then_key_text "$text"
          ;;
        *)
          AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE=1 type_claude_code_terminal_raw_smoke_text "$text"
          ;;
      esac
      ;;
    *)
      echo "Unknown Claude Code terminal typing mode: $typing_mode" >&2
      exit 2
      ;;
  esac
}

type_claude_code_terminal_ghostty_paste_then_key_text() {
  local text="$1"
  local prefix_text final_character drain_seconds

  settle_claude_code_terminal_proof_focus "Ghostty proof CGEvent typing" || return 1
  if (( ${#text} > 1 )); then
    prefix_text="${text:0:${#text}-1}"
    final_character="${text: -1}"
  else
    prefix_text=""
    final_character="$text"
  fi
  drain_seconds="$(claude_code_ghostty_typing_drain_seconds)"

  if [[ -n "$prefix_text" ]]; then
    type_claude_code_terminal_ghostty_native_text "$prefix_text"
    sleep "$drain_seconds"
  fi

  CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE="$(line_count "$LOG_PATH")"
  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_FINAL_TRIGGER_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]]; then
    echo "Claude Code Ghostty proof typing final trigger with native terminal input."
    if ! type_claude_code_terminal_ghostty_native_final_character "$final_character"; then
      echo "Claude Code Ghostty proof native final trigger failed; falling back to CGEvent typing."
      settle_claude_code_terminal_proof_focus "Ghostty proof final trigger typing" || return 1
      type_text_cgevent "$final_character"
    fi
  else
    settle_claude_code_terminal_proof_focus "Ghostty proof final trigger typing" || return 1
    type_text_cgevent "$final_character"
  fi

  sleep "$drain_seconds"
  if try_claude_code_terminal_prompt_ready_quiet "$text" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TYPING_VERIFY_SECONDS:-3}"; then
    return
  fi

  echo "Claude Code Ghostty proof native typed prompt was incomplete; retrying with System Events bulk typing."
  if clear_claude_code_terminal_prompt_line; then
    CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE="$(line_count "$LOG_PATH")"
    AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE=1 \
      type_claude_code_terminal_raw_smoke_text "$text" || return 1
    sleep "$drain_seconds"
    if try_claude_code_terminal_prompt_ready_quiet "$text" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TYPING_VERIFY_SECONDS:-3}"; then
      return
    fi
  fi

  echo "Claude Code Ghostty proof bulk typing was incomplete; retrying with paced System Events typing."
  if clear_claude_code_terminal_prompt_line; then
    CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE="$(line_count "$LOG_PATH")"
    type_claude_code_terminal_raw_smoke_text "$text" || return 1
    sleep "$drain_seconds"
  fi
}

type_claude_code_terminal_ghostty_native_text() {
  local text="$1"

  [[ -n "$text" ]] || return 0
  focus_claude_code_ghostty_proof_window_by_title || return 1
  run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_TYPE_TIMEOUT_SECONDS:-3}" \
    "Claude Code Ghostty native proof typing" \
    - "$text" <<'APPLESCRIPT' >/dev/null
on run argv
set rawText to item 1 of argv
tell application id "com.mitchellh.ghostty"
  set targetWindow to front window
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  focus targetTerminal
  input text rawText to targetTerminal
  activate
end tell
end run
APPLESCRIPT
}

type_claude_code_terminal_ghostty_native_final_character() {
  local text="$1"

  [[ -n "$text" ]] || return 0
  focus_claude_code_ghostty_proof_window_by_title || return 1
  run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_FINAL_TRIGGER_TIMEOUT_SECONDS:-3}" \
    "Claude Code Ghostty native final trigger" \
    - "$text" <<'APPLESCRIPT' >/dev/null
on run argv
set triggerText to item 1 of argv
tell application id "com.mitchellh.ghostty"
  set targetWindow to front window
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  focus targetTerminal
  input text triggerText to targetTerminal
  activate
end tell
end run
APPLESCRIPT
}

claude_code_ghostty_event_drain_seconds() {
  local drain_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_EVENT_DRAIN_SECONDS:-8}"
  if [[ "$drain_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$drain_seconds"
  else
    printf '%s\n' "8"
  fi
}

claude_code_ghostty_typing_drain_seconds() {
  local drain_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TYPING_DRAIN_SECONDS:-0.8}"
  if [[ "$drain_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$drain_seconds"
  else
    printf '%s\n' "0.8"
  fi
}

type_claude_code_terminal_raw_smoke_text() {
  local text="$1"

  settle_claude_code_terminal_proof_focus "proof typing" || return 1
  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE:-0}" == "1" ]]; then
    AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TEXT="$text" \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" \
      run_osascript_with_timeout \
        "${AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TYPE_TIMEOUT_SECONDS:-4}" \
        "Claude Code terminal raw bulk proof typing" <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TEXT"
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof typing."
  end if
  keystroke rawText
end tell
APPLESCRIPT
    return
  fi

  AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TEXT="$text" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_KEY_DELAY="${AUTOCOMPLETE_LAB_CLAUDE_CODE_KEY_DELAY_SECONDS:-0.012}" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TYPE_TIMEOUT_SECONDS:-4}" \
      "Claude Code terminal raw proof typing" <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_RAW_TEXT"
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
set keyDelay to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_KEY_DELAY") as real
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof typing."
  end if
  repeat with characterIndex from 1 to count characters of rawText
    keystroke character characterIndex of rawText
    delay keyDelay
  end repeat
end tell
APPLESCRIPT
}

clear_claude_code_terminal_ghostty_native_line() {
  local clear_delay="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY_SECONDS:-0.12}"

  focus_claude_code_ghostty_proof_window_by_title || return 1
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY="$clear_delay" \
    run_osascript_with_timeout \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_CLEAR_TIMEOUT_SECONDS:-3}" \
      "Claude Code Ghostty native line clear" <<'APPLESCRIPT' >/dev/null
set clearDelay to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY") as real
tell application id "com.mitchellh.ghostty"
  set targetWindow to front window
  activate window targetWindow
  set targetTab to selected tab of targetWindow
  set targetTerminal to focused terminal of targetTab
  focus targetTerminal
  send key "u" modifiers "control" to targetTerminal
  delay clearDelay
  send key "u" modifiers "control" to targetTerminal
  activate
end tell
APPLESCRIPT
}

clear_claude_code_terminal_prompt_line() {
  local ghostty_native_clear_posted=1
  local ghostty_system_events_clear_posted=1

  settle_claude_code_terminal_proof_focus "prompt clearing" || return 1
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_NATIVE_CLEAR_ENABLED:-1}" =~ ^(1|true|yes|on)$ ]] &&
       clear_claude_code_terminal_ghostty_native_line; then
      ghostty_native_clear_posted=0
      sleep "$(claude_code_ghostty_event_drain_seconds)"
      return 0
    fi
    if [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_SYSTEM_EVENTS_CLEAR_ENABLED:-0}" =~ ^(1|true|yes|on)$ ]]; then
      return 1
    fi
    if AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" \
      AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY_SECONDS:-0.12}" osascript <<'APPLESCRIPT'
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
set clearDelay to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY") as real
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof line clearing."
  end if
  keystroke "u" using control down
  delay clearDelay
  keystroke "u" using control down
end tell
APPLESCRIPT
    then
      ghostty_system_events_clear_posted=0
    else
      ghostty_system_events_clear_posted=$?
    fi
    sleep "$(claude_code_ghostty_event_drain_seconds)"
    ((ghostty_native_clear_posted == 0 || ghostty_system_events_clear_posted == 0))
    return
  fi

  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY_SECONDS:-0.12}" osascript <<'APPLESCRIPT'
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
set clearDelay to (system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY") as real
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof line clearing."
  end if
  key code 53
  delay clearDelay
  keystroke "u" using control down
  delay clearDelay
  keystroke "k" using command down
  delay clearDelay
  keystroke "l" using control down
  delay clearDelay
  keystroke "u" using control down
end tell
APPLESCRIPT
}

press_claude_code_terminal_host_tab() {
  local suggestion_line="${1:-0}"
  local host_name="${2:-$(claude_code_host_display_name)}"
  local probe_start_line
  CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="tab delivery did not reach key capture"

  settle_claude_code_terminal_proof_focus "host Tab hot accept" || return 1
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)" osascript <<'APPLESCRIPT'
set hostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE"
tell application "System Events"
  set hostIsFrontmost to false
  repeat with frontApp in (application processes whose frontmost is true)
    try
      if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
    end try
  end repeat
  if hostIsFrontmost is false then
    error "Claude Code terminal host is not frontmost for proof Tab."
  end if
end tell
APPLESCRIPT
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" =~ ^(1|true|yes|on)$ ]]; then
    try_steadytype_proof_only_accept_next_word_driver "$suggestion_line" "$host_name" "proof-only-driver-enabled" ||
      return 1
    return 0
  fi
  if ! probe_claude_code_terminal_host_key_capture "$host_name"; then
    try_steadytype_proof_only_accept_next_word_driver "$suggestion_line" "$host_name" "key-capture-probe-miss" ||
      return 1
    return 0
  fi
  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name proof pressing CGEvent Tab for hot accept."
  if ! press_key_code_cgevent_with_timeout \
    48 \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name CGEvent Tab" \
    "session" \
    "warm"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent session Tab helper failed"
    return 1
  fi
  if wait_for_log_fields_optional \
    "$probe_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS:-1}" \
    "keyboard-event-tap-latency" \
    "key=tab"; then
    return 0
  fi

  if [[ "$suggestion_line" != "0" ]] &&
    log_since_has_fields "$suggestion_line" \
      "suggestion-hidden" \
      "app=com.anthropic.claude-code"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion after CGEvent session Tab"
    echo "Claude Code $host_name suggestion hid after CGEvent session Tab; refreshing the disposable prompt." >&2
    return 1
  fi

  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    if ! settle_claude_code_terminal_proof_focus "HID CGEvent Tab hot accept"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before HID CGEvent Tab"
      echo "Claude Code terminal host is not frontmost for HID CGEvent proof Tab." >&2
      return 1
    fi
    probe_start_line="$(line_count "$LOG_PATH")"
    echo "Claude Code $host_name CGEvent session Tab produced no key=tab diagnostic; retrying with CGEvent HID Tab."
    if ! press_key_code_cgevent_with_timeout \
      48 \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS:-2}" \
      "Claude Code $host_name CGEvent HID Tab" \
      "hid" \
      "warm"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent HID Tab helper failed"
      return 1
    fi
    if wait_for_log_fields_optional \
      "$probe_start_line" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS:-1}" \
      "keyboard-event-tap-latency" \
      "key=tab"; then
      return 0
    fi

    if [[ "$suggestion_line" != "0" ]] &&
      log_since_has_fields "$suggestion_line" \
        "suggestion-hidden" \
        "app=com.anthropic.claude-code"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion after CGEvent HID Tab"
      echo "Claude Code $host_name suggestion hid after CGEvent HID Tab; refreshing the disposable prompt." >&2
      return 1
    fi

    if ! settle_claude_code_terminal_proof_focus "private-source session CGEvent Tab hot accept"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before private-source session CGEvent Tab"
      echo "Claude Code terminal host is not frontmost for private-source session CGEvent proof Tab." >&2
      return 1
    fi
    probe_start_line="$(line_count "$LOG_PATH")"
    echo "Claude Code $host_name CGEvent HID Tab produced no key=tab diagnostic; retrying with private-source session CGEvent Tab."
    if ! press_key_code_cgevent_with_timeout \
      48 \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS:-2}" \
      "Claude Code $host_name CGEvent private-source session Tab" \
      "session" \
      "warm" \
      "private"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent private-source session Tab helper failed"
      return 1
    fi
    if wait_for_log_fields_optional \
      "$probe_start_line" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS:-1}" \
      "keyboard-event-tap-latency" \
      "key=tab"; then
      return 0
    fi

    if [[ "$suggestion_line" != "0" ]] &&
      log_since_has_fields "$suggestion_line" \
        "suggestion-hidden" \
        "app=com.anthropic.claude-code"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion after private-source session CGEvent Tab"
      echo "Claude Code $host_name suggestion hid after private-source session CGEvent Tab; refreshing the disposable prompt." >&2
      return 1
    fi

    if ! settle_claude_code_terminal_proof_focus "private-source HID CGEvent Tab hot accept"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before private-source HID CGEvent Tab"
      echo "Claude Code terminal host is not frontmost for private-source HID CGEvent proof Tab." >&2
      return 1
    fi
    probe_start_line="$(line_count "$LOG_PATH")"
    echo "Claude Code $host_name private-source session CGEvent Tab produced no key=tab diagnostic; retrying with private-source HID CGEvent Tab."
    if ! press_key_code_cgevent_with_timeout \
      48 \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS:-2}" \
      "Claude Code $host_name CGEvent private-source HID Tab" \
      "hid" \
      "warm" \
      "private"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="CGEvent private-source HID Tab helper failed"
      return 1
    fi
    if wait_for_log_fields_optional \
      "$probe_start_line" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS:-1}" \
      "keyboard-event-tap-latency" \
      "key=tab"; then
      return 0
    fi

    if [[ "$suggestion_line" != "0" ]] &&
      log_since_has_fields "$suggestion_line" \
        "suggestion-hidden" \
        "app=com.anthropic.claude-code"; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion after private-source HID CGEvent Tab"
      echo "Claude Code $host_name suggestion hid after private-source HID CGEvent Tab; refreshing the disposable prompt." >&2
      return 1
    fi
  fi

  if [[ "$suggestion_line" != "0" ]] &&
    log_since_has_fields "$suggestion_line" \
      "suggestion-hidden" \
      "app=com.anthropic.claude-code"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion before fallback Tab"
    echo "Claude Code $host_name suggestion hid before fallback Tab; refreshing the disposable prompt." >&2
    return 1
  fi

  if ! settle_claude_code_terminal_proof_focus "fallback Tab hot accept"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not refocus before fallback Tab"
    echo "Claude Code terminal host is not frontmost for fallback proof Tab." >&2
    return 1
  fi

  probe_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name CGEvent Tab attempts produced no key=tab diagnostic; retrying with System Events Tab."
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
    if ! focus_claude_code_ghostty_proof_window_by_title; then
      CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="could not focus title-marked proof window before fallback Tab"
      echo "Claude Code $host_name fallback could not focus the title-marked proof window." >&2
      return 1
    fi
  fi
  if ! run_osascript_with_timeout \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS:-2}" \
    "Claude Code $host_name fallback Tab" <<'APPLESCRIPT'
tell application "System Events"
  key code 48
end tell
APPLESCRIPT
  then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="fallback System Events Tab timed out"
    echo "Claude Code $host_name fallback System Events Tab timed out; refreshing the disposable prompt." >&2
    return 1
  fi

  if wait_for_log_fields_optional \
    "$probe_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS:-2}" \
    "keyboard-event-tap-latency" \
    "key=tab"; then
    return 0
  fi

  CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="Tab delivery did not reach key capture"
  echo "Claude Code $host_name fallback System Events Tab produced no immediate key=tab diagnostic; refreshing the disposable prompt." >&2
  return 1
}

try_steadytype_proof_only_accept_next_word_driver() {
  local suggestion_line="${1:-0}"
  local host_name="${2:-$(claude_code_host_display_name)}"
  local reason="${3:-manual}"
  local app_binary command_start_line

  [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] || return 1
  [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" =~ ^(1|true|yes|on)$ ]] || return 1
  if [[ "${AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS:-0}" != "1" ]]; then
    echo "Claude Code $host_name proof-only accept driver requires AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=1 on the SteadyType launch." >&2
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="proof-only accept driver not enabled in app launch"
    return 1
  fi
  if [[ "$suggestion_line" != "0" ]] &&
    log_since_has_fields "$suggestion_line" \
      "suggestion-hidden" \
      "app=com.anthropic.claude-code"; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="lost its visible suggestion before proof-only accept driver"
    echo "Claude Code $host_name suggestion hid before proof-only accept command; refreshing the disposable prompt." >&2
    return 1
  fi
  settle_claude_code_terminal_proof_focus "proof-only accept command" || return 1

  app_binary="$(steadytype_app_binary)"
  if [[ ! -x "$app_binary" ]]; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="proof-only accept driver app binary missing"
    echo "SteadyType app binary is missing for proof-only accept command: $app_binary" >&2
    return 1
  fi

  command_start_line="$(line_count "$LOG_PATH")"
  echo "Claude Code $host_name proof using SteadyType proof-only accept command after $reason."
  if ! "$app_binary" --proof-only-accept-next-word; then
    CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="proof-only accept command failed to post"
    return 1
  fi
  if wait_for_log_fields_optional \
    "$command_start_line" \
    "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_SECONDS:-4}" \
    "proof-only-accept-command-result" \
    "app=com.anthropic.claude-code" \
    "handled=true"; then
    return 0
  fi

  CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON="proof-only accept command did not handle"
  echo "Claude Code $host_name proof-only accept command did not produce handled=true." >&2
  return 1
}

type_claude_raw_smoke_text() {
  local text="$1"

  AUTOCOMPLETE_LAB_CLAUDE_RAW_TEXT="$text" osascript <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_RAW_TEXT"
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.anthropic.claudefordesktop" then
    error "Claude is not frontmost for prompt proof typing."
  end if
  keystroke rawText
end tell
APPLESCRIPT
}

type_codex_raw_smoke_text() {
  local text="$1"

  AUTOCOMPLETE_LAB_CODEX_RAW_TEXT="$text" osascript <<'APPLESCRIPT'
set rawText to system attribute "AUTOCOMPLETE_LAB_CODEX_RAW_TEXT"
tell application "System Events"
  set frontApp to first application process whose frontmost is true
  if bundle identifier of frontApp is not "com.openai.codex" then
    error "Codex is not frontmost for prompt proof typing."
  end if
  keystroke rawText
end tell
APPLESCRIPT
}

codex_ax_helper() {
  local action="$1"
  shift
  swift script/prompt_app_ax_proof_helper.swift "$action" \
    --bundle com.openai.codex \
    --display Codex \
    --marker "AUTOCOMPLETE_LAB_CODEX_PROOF" \
    --hint "Ask Codex anything" \
    --hint "Ask for follow-up changes" \
    --hint "Describe a task or ask a question" \
    "$@"
}

seed_codex_proof_prompt() {
  local proof_text="$1"
  local backup_path="${2:-}"

  codex_ax_helper seed \
    --text "$proof_text" \
    --backup "$backup_path" \
    --clear-if-no-backup \
    --discovery-timeout "${AUTOCOMPLETE_LAB_CODEX_COMPOSER_DISCOVERY_TIMEOUT_SECONDS:-10}"
  return 0

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

func axElementContains(_ element: AXUIElement, targetIdentifier: Int, depth: Int = 0) -> Bool {
    guard depth <= 12 else {
        return false
    }

    if Int(CFHash(element)) == targetIdentifier {
        return true
    }

    for child in children(of: element) {
        if axElementContains(child, targetIdentifier: targetIdentifier, depth: depth + 1) {
            return true
        }
    }

    return false
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

    guard CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
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
    let hasMarker: Bool
    let looksDisposable: Bool
    let focusedDraftCanBeRestored: Bool
    let score: Double
}

func collectTextAreas(
    in element: AXUIElement,
    focusedRoot: AXUIElement?,
    depth: Int = 0,
    candidates: inout [Candidate]
) {
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
        let hasMarker = value.contains(marker)
        let looksDisposable = value.isEmpty
            || hasMarker
            || value.localizedCaseInsensitiveContains("Ask Codex anything")
            || value.localizedCaseInsensitiveContains("Ask for follow-up changes")
            || value.localizedCaseInsensitiveContains("Describe a task or ask a question")
        let focused = boolAttribute(element, kAXFocusedAttribute)
            || focusedRoot.map { root in
                axElementContains(root, targetIdentifier: Int(CFHash(element)))
            } ?? false
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
            if hasMarker {
                score += 800
            }
            if value.localizedCaseInsensitiveContains("Ask Codex anything")
                || value.localizedCaseInsensitiveContains("Ask for follow-up changes")
                || value.localizedCaseInsensitiveContains("Describe a task or ask a question") {
                score += 500
            }
            candidates.append(Candidate(
                element: element,
                value: value,
                frame: frame,
                focused: focused,
                hasMarker: hasMarker,
                looksDisposable: looksDisposable,
                focusedDraftCanBeRestored: focusedDraftCanBeRestored,
                score: score
            ))
        }
    }

    for child in children(of: element) {
        collectTextAreas(
            in: child,
            focusedRoot: focusedRoot,
            depth: depth + 1,
            candidates: &candidates
        )
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
collectTextAreas(in: appElement, focusedRoot: focusedElement(in: appElement), candidates: &candidates)

guard let candidate = candidates.sorted(by: { lhs, rhs in
    if lhs.hasMarker != rhs.hasMarker {
        return lhs.hasMarker
    }
    if lhs.looksDisposable != rhs.looksDisposable {
        return lhs.looksDisposable
    }
    if lhs.focusedDraftCanBeRestored != rhs.focusedDraftCanBeRestored {
        return lhs.focusedDraftCanBeRestored
    }
    if lhs.focused != rhs.focused {
        return lhs.focused
    }
    if lhs.score == rhs.score {
        return lhs.frame.minY < rhs.frame.minY
    }
    return lhs.score > rhs.score
}).first else {
    fputs("Could not find a safe Codex composer. Clear the prompt, open a new Codex start screen, or keep focus in the draft prompt so it can be backed up and restored.\n", stderr)
    exit(1)
}

let shouldRestoreDraft = !candidate.value.isEmpty
    && !candidate.value.contains(marker)
    && !candidate.value.localizedCaseInsensitiveContains("Ask Codex anything")
    && !candidate.value.localizedCaseInsensitiveContains("Ask for follow-up changes")
    && !candidate.value.localizedCaseInsensitiveContains("Describe a task or ask a question")
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
  if [[ -z "$CODEX_DRAFT_BACKUP_PATH" || ! -f "$CODEX_DRAFT_BACKUP_PATH" ]]; then
    return 0
  fi

  codex_ax_helper restore --backup "$CODEX_DRAFT_BACKUP_PATH" --clear-if-no-backup || true
  rm -f "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true
  CODEX_DRAFT_BACKUP_PATH=""
  CODEX_DRAFT_BACKUP_ACTIVE=0
  return 0

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
    if restoreText.isEmpty {
        print("Cleared Codex proof composer after proof.")
    } else {
        print("Restored existing Codex draft after proof: chars=\(restoreText.count)")
    }
} else {
    fputs("Codex draft restore failed (AX result \(result.rawValue)).\n", stderr)
}
SWIFT

  rm -f "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true
  CODEX_DRAFT_BACKUP_PATH=""
  CODEX_DRAFT_BACKUP_ACTIVE=0
}

focus_codex_proof_prompt() {
  codex_ax_helper focus
  return 0

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

    guard CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
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

func focusedMarkedTextArea(in element: AXUIElement, cursorOffset: Int, depth: Int = 0) -> Bool {
    guard depth <= 12 else {
        return false
    }

    if stringAttribute(element, kAXRoleAttribute) == kAXTextAreaRole as String,
       stringAttribute(element, kAXValueAttribute).contains(marker),
       selectedRangeMatches(element, location: cursorOffset, length: 0) {
        return true
    }

    for child in children(of: element) {
        if focusedMarkedTextArea(in: child, cursorOffset: cursorOffset, depth: depth + 1) {
            return true
        }
    }

    return false
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
      focusedMarkedTextArea(
          in: focused,
          cursorOffset: cursorOffset
      ) else {
    fputs("Could not keep Codex proof prompt focused at the end before Tab.\n", stderr)
    exit(1)
}

print("Focused Codex proof composer before Tab: chars=\(text.count)")
SWIFT
}

assert_codex_proof_prompt_ready() {
  local proof_text="$1"

  codex_ax_helper assert --text "$proof_text"
  return 0

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
let cursorOffset = proofText.utf16.count

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

func selectedRangeMatches(_ element: AXUIElement, location: Int, length: Int) -> Bool {
    guard let rangeValue = copyAttribute(element, kAXSelectedTextRangeAttribute) else {
        return false
    }

    guard CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
        return false
    }

    var range = CFRange()
    guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
        return false
    }
    return range.location == location && range.length == length
}

func matchingFocusedTextArea(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth <= 12 else {
        return nil
    }

    if stringAttribute(element, kAXRoleAttribute) == kAXTextAreaRole as String {
        let value = stringAttribute(element, kAXValueAttribute)
        if value == proofText,
           value.contains(marker),
           selectedRangeMatches(element, location: cursorOffset, length: 0) {
            return element
        }
    }

    for child in children(of: element) {
        if let match = matchingFocusedTextArea(in: child, depth: depth + 1) {
            return match
        }
    }

    return nil
}

guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.openai.codex"
).first else {
    fputs("Codex is not running.\n", stderr)
    exit(1)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(appElement, 0.75)

guard let focusedValue = copyAttribute(appElement, kAXFocusedUIElementAttribute),
      CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
    fputs("Codex proof prompt is not focused before Tab.\n", stderr)
    exit(1)
}

let focusedElement = focusedValue as! AXUIElement
guard matchingFocusedTextArea(in: focusedElement) != nil else {
    fputs("Codex proof prompt is not the focused exact marker text before Tab.\n", stderr)
    exit(1)
}

print("Verified Codex proof composer before Tab: chars=\(proofText.count)")
SWIFT
}

assert_codex_prompt_retains_marker() {
  codex_ax_helper contains-marker
  return 0

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
<title>SteadyType Chrome Local Editor-Like Fixture Smoke [ready=1]</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline'; connect-src 'none'; img-src 'self' data:">
<div class="cm-editor" role="application" aria-label="Local editor-like smoke fixture" style="display: grid; grid-template-columns: 48px 1fr; font: 18px -apple-system; width: 720px; min-height: 180px; margin: 80px; border: 1px solid #bbb;">
  <div aria-hidden="true" style="padding-top: 14px; border-right: 1px solid #ddd; background: #f5f5f2; color: #777; font: 14px Menlo, monospace; text-align: center;">1</div>
  <div data-smoke-editor class="cm-content" role="textbox" aria-label="Local CodeMirror-style smoke fixture editor" aria-multiline="true" contenteditable="true" spellcheck="false" style="min-height: 160px; padding: 12px; outline: none; white-space: pre-wrap; overflow-wrap: anywhere;"></div>
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
<title>SteadyType Chrome Local Monaco-Like Fixture Smoke [ready=1]</title>
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
        <div data-smoke-editor class="view-line inputarea monaco-mouse-cursor-text" role="textbox" aria-label="Local Monaco-like smoke fixture editor input" aria-multiline="true" contenteditable="true" spellcheck="false"></div>
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
<title>SteadyType Chrome Local Real Monaco Fixture Smoke [ready=0]</title>
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
<div class="label">Local real Monaco editor smoke fixture</div>
<div data-smoke-editor class="monaco-host" aria-label="Local real Monaco smoke fixture editor"></div>
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
    ariaLabel: "Local real Monaco smoke fixture editor"
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
  document.title = "SteadyType Chrome Local Real Monaco Fixture Smoke [ready=1]";
  window.focusSmokeEditor();
});
</script>
HTML
      ;;
    prosemirror-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>SteadyType Chrome Local ProseMirror-Like Fixture Smoke [ready=1]</title>
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
  <div data-smoke-editor class="ProseMirror" role="textbox" aria-label="Local ProseMirror-like smoke fixture editor" aria-multiline="true" contenteditable="true" spellcheck="false"><p><br></p></div>
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
<title>SteadyType Chrome Local Real ProseMirror Fixture Smoke [ready=0]</title>
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
<article class="editor-shell" aria-label="Local real ProseMirror smoke fixture">
  <div class="menubar" aria-hidden="true"><span>B</span><span>I</span><span>H1</span></div>
  <div data-prosemirror-mount></div>
</article>
<script src="$CHROME_FIXTURE_SCRIPT_URL"></script>
<script>
window.autocompleteSmokeReady = false;
window.AutocompleteLabRealProseMirrorSmoke.mount(document.querySelector("[data-prosemirror-mount]"));
document.title = "SteadyType Chrome Local Real ProseMirror Fixture Smoke [ready=1]";
</script>
HTML
      ;;
    chat-like)
      cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>SteadyType Chrome Local Chat-Like Fixture No-Submit Smoke [ready=1 submits=0]</title>
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
    <div data-smoke-editor role="textbox" aria-label="Local chat-like smoke fixture message composer" aria-multiline="true" contenteditable="true" spellcheck="false"></div>
    <button type="submit">Send</button>
  </form>
  <div class="meter" aria-live="polite">Submits: <span data-smoke-submit-count>0</span></div>
</section>
<script>
window.autocompleteSmokeSubmitCount = 0;
window.updateSmokeSubmitCount = function () {
  document.title = "SteadyType Chrome Local Chat-Like Fixture No-Submit Smoke [ready=1 submits=" + window.autocompleteSmokeSubmitCount + "]";
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
  if [[ "$SKIP_BUILD" == "1" ]] && is_model_latency_lane && allow_model_latency_skip_build; then
    echo "Packaged model latency proof: reusing the already-running app because AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 is set."
    echo "Safety: strict latency selector must still prove the tagged runtime launch for this app binary."
  fi
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
        default-model-latency)
          echo "Plan: build/relaunch AutocompleteLab once, allow a cold local model warmup, type several disposable TextEdit phrase contexts, and require default phrase model suggestions in one launch."
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
      elif [[ "$TEXTEDIT_VARIANT" == "default-model-latency" ]]; then
        echo "Safety: default model latency proof seeds stable context into the disposable TextEdit AX target, then types a trailing space through live key events."
        echo "Safety: default model latency proof disables word completions and fast phrase fallback for that launch so local phrase-continuation model timing is required."
        echo "Safety: default model latency proof tags the runtime launch with scenario textedit-default-model-latency so generic TextEdit samples cannot satisfy the beta gate."
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
      if [[ "$CHROME_MODEL_LATENCY" == "1" ]]; then
        echo "Safety: Chrome model latency proof disables fast word completions and phrase continuations for each launch so local word-completion model timing is required."
        echo "Safety: Chrome model latency proof tags the runtime launch with scenario chrome-$CHROME_FIXTURE-model-latency so generic Chrome samples cannot satisfy the beta gate."
      fi
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
      if [[ "$CODEX_MODEL_LATENCY" == "1" ]]; then
        echo "Plan: manual-gated Codex prompt model latency proof. The script seeds several stable disposable AUTOCOMPLETE_LAB_CODEX_PROOF prompt contexts, types the trigger character through live key events, and requires model-backed visible word completions in one launch."
        echo "Safety: Codex model latency proof disables fast word completions and phrase continuations for that launch so local word-completion model timing is required."
        echo "Safety: Codex model latency proof tags the runtime launch with scenario codex-model-latency so generic prompt samples cannot satisfy the strict selector."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter or full accept; it runs the prompt no-submit gate on the same trace slice."
        echo "Safety: if the focused Codex prompt already has a draft, the helper backs it up privately and restores it after the no-submit proof; empty proof composers are cleared."
      elif [[ "$CODEX_FULL_ACCEPT_PROOF" == "1" ]]; then
        echo "Plan: manual-gated Codex prompt full-accept no-submit proof. The script seeds disposable AUTOCOMPLETE_LAB_CODEX_PROOF text, waits for a visible short phrase, presses the configured full-accept shortcut once, and validates that the phrase stayed in the composer."
        echo "Safety: Codex full accept is enabled only for the proof-mode Codex bundle and runtime scenario codex-full-accept-no-submit."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter; it runs the prompt full-accept no-submit gate on the same trace slice."
        echo "Safety: if the focused Codex prompt already has a draft, the helper backs it up privately and restores it after the no-submit proof; empty proof composers are cleared."
      else
        echo "Plan: manual-gated Codex prompt smoke. The script seeds disposable AUTOCOMPLETE_LAB_CODEX_PROOF text and validates one-word Tab accept without submit."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter; full accept waits for separate full-accept no-submit proof."
        echo "Safety: if the focused Codex prompt already has a draft, the helper backs it up privately and restores it after the no-submit proof; empty proof composers are cleared."
      fi
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
      if [[ "$CLAUDE_CODE_MODEL_LATENCY" == "1" ]]; then
        echo "Plan: manual-gated terminal-host Claude Code model latency proof. The script opens a fresh title-marked disposable Terminal Claude Code prompt per sample, types disposable proof contexts plus trigger characters, and requires model-backed visible word completions."
        echo "Safety: Claude Code model latency proof disables fast word completions and phrase continuations for that launch so local word-completion model timing is required."
        echo "Safety: Claude Code model latency proof tags the runtime launch with scenario claude-code-model-latency so generic terminal samples cannot satisfy the strict selector."
        echo "Safety: pass --manual-gate to continue. The helper never presses Tab, Enter, or full accept; it runs the prompt no-submit gate on the same trace slice."
      elif [[ "$CLAUDE_CODE_HOST_VARIANT" == "terminal" ]]; then
        echo "Plan: manual-gated automated Terminal-host Claude Code proof. The script opens a fresh title-marked disposable Terminal Claude Code prompt, types marked proof text, presses Tab once, and validates one-word no-submit proof on the same trace slice."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter or full accept."
      elif [[ "$CLAUDE_CODE_HOST_VARIANT" == "iterm2" || "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
        echo "Plan: manual-gated automated $host_name-host Claude Code proof. The script opens a fresh title-marked disposable $host_name Claude Code prompt, types marked proof text, presses Tab once, and validates one-word no-submit proof on the same trace slice."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter or full accept; unsupported terminal hosts stay manual until they have their own disposable launch path."
      else
        echo "Plan: manual-gated terminal-host Claude Code proof. The script validates one-word Tab accept without submit after you run it."
      fi
      echo "Claude Code host: $host_name ($host_bundle), $host_status"
      echo "Claude Code proof label: $proof_label"
      echo "Safety: pass --manual-gate to continue. Use the named supported terminal host, include the configured Claude Code proof marker, and do not press Enter."
      if [[ "$CLAUDE_CODE_MODEL_LATENCY" == "1" ]]; then
        echo "Proof target: terminal-hosted Claude Code must validate model-backed visible suggestions without submitting shell input or an agent prompt."
      else
        echo "Proof target: terminal-hosted Claude Code must validate one-word Tab accept without submitting shell input or an agent prompt."
      fi
      ;;
    claude)
      if [[ "$CLAUDE_MODEL_LATENCY" == "1" ]]; then
        echo "Plan: manual-gated Claude desktop prompt model latency proof. The script seeds several stable disposable AUTOCOMPLETE_LAB_CLAUDE_PROOF prompt contexts, types the trigger character through live key events, and requires model-backed visible word completions in one launch."
        echo "Safety: Claude model latency proof disables fast word completions and phrase continuations for that launch so local word-completion model timing is required."
        echo "Safety: Claude model latency proof tags the runtime launch with scenario claude-model-latency so generic prompt samples cannot satisfy the strict selector."
        echo "Safety: pass --manual-gate to continue. The helper never presses Enter or full accept; it runs the prompt no-submit gate on the same trace slice."
        echo "Safety: if the focused Claude prompt already has a draft, the helper backs it up privately and restores it after the no-submit proof."
      else
        echo "Plan: manual-gated prompt smoke. The script validates one-word Tab accept without submit after you run it."
        if [[ -n "$CLAUDE_SESSION_APP" ]]; then
          echo "Claude layout proof: $CLAUDE_SESSION_APP"
        fi
        echo "Safety: pass --manual-gate to continue. Do not press Enter; full accept waits for separate full-accept no-submit proof."
      fi
      ;;
  esac
}

build_if_needed() {
  SMOKE_PHASE="build/relaunch current SteadyType"
  if [[ "$SKIP_BUILD" != "1" ]]; then
    local build_run_env=(
      AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE=1
      AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES=1
    )
    if [[ "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_SKIP_STALE_APP_SCAN:-}" =~ ^(1|true|yes|on)$ ]]; then
      build_run_env+=(AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN=1)
    fi
    env "${build_run_env[@]}" ./script/build_and_run.sh bundle-only
    launch_current_steadytype_with_smoke_env
  fi

  wait_for_current_autocomplete_lab_process
  refresh_build_archive_proof
}

build_bundle_if_needed() {
  if [[ "$SKIP_BUILD" != "1" ]]; then
    local build_run_env=(
      AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE=1
      AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES=1
    )
    if [[ "${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_SKIP_STALE_APP_SCAN:-}" =~ ^(1|true|yes|on)$ ]]; then
      build_run_env+=(AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN=1)
    fi
    env "${build_run_env[@]}" ./script/build_and_run.sh bundle-only
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

steadytype_dist_dir() {
  printf '%s\n' "${AUTOCOMPLETE_LAB_DIST_DIR:-$ROOT_DIR/dist}"
}

steadytype_app_bundle() {
  printf '%s/SteadyType.app\n' "$(steadytype_dist_dir)"
}

steadytype_app_binary() {
  printf '%s/Contents/MacOS/SteadyType\n' "$(steadytype_app_bundle)"
}

command_matches_steadytype_binary() {
  local command="$1"
  local app_binary="$2"
  [[ "$command" == "$app_binary" || "$command" == "$app_binary "* ]]
}

current_steadytype_app_bundle_pids() {
  local app_binary
  app_binary="$(steadytype_app_binary)"

  while IFS=$'\t' read -r pid pgid command; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" == "$$" ]] && continue
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

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -9 "$pid" >/dev/null 2>&1 || true
  done < <(current_steadytype_app_bundle_pids)

  sleep 0.1
  if [[ -n "$(current_steadytype_app_bundle_pids)" ]]; then
    echo "Timed out stopping current SteadyType app bundle before smoke setup." >&2
    exit 1
  fi
}

stale_steadytype_app_bundle_pids() {
  local expected_binary
  expected_binary="$(steadytype_app_binary)"
  local pid command

  while IFS=$'\t' read -r pid _pgid command; do
    [[ -z "$pid" ]] && continue
    [[ -z "$command" ]] && continue
    command_matches_steadytype_binary "$command" "$expected_binary" && continue
    printf '%s\n' "$pid"
  done < <(steadytype_app_process_rows)
}

terminate_stale_steadytype_app_bundles() {
  local pid
  local stale_pids=()

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    stale_pids+=("$pid")
    kill "$pid" >/dev/null 2>&1 || true
  done < <(stale_steadytype_app_bundle_pids)

  ((${#stale_pids[@]} == 0)) && return 0
  sleep 0.2

  for pid in "${stale_pids[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
  done
}

pause_steadytype_for_chrome_setup() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  stop_current_steadytype_app_bundle
}

launch_current_steadytype_with_smoke_env() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  local app_binary launch_log
  app_binary="$(steadytype_app_binary)"
  launch_log="$(steadytype_dist_dir)/SteadyType.launch.log"
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
    AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION \
    AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION \
    AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK \
    AUTOCOMPLETE_LAB_PROOF_SCENARIO \
    AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING \
    AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS \
    AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS \
    AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS \
    AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER \
    AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS \
    AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE \
    AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE \
    AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES \
    AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS \
    AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE \
    AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE \
    AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_DRAIN_SECONDS \
    AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE \
    AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE \
    AUTOCOMPLETE_LAB_ACCEPTED_INSERTION_UNDO_RECOVERY; do
    if [[ -n "${!env_key+x}" ]]; then
      launch_env+=("$env_key=${!env_key}")
    fi
  done
  if [[ "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" =~ ^(1|true|yes|on)$ ]] &&
     [[ ! -n "${AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS+x}" ]]; then
    launch_env+=(AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=1)
    export AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=1
  fi

  env "${launch_env[@]}" \
    nohup "$app_binary" >"$launch_log" 2>&1 </dev/null &
  disown "$!" 2>/dev/null || true

  wait_for_current_autocomplete_lab_process
}

launch_steadytype_after_chrome_setup() {
  local fixture="$1"
  local start_line="$2"
  local chrome_pid="${3:-}"
  local chrome_url="${4:-}"

  launch_current_steadytype_with_smoke_env

  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

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
  local expected_binary
  expected_binary="$(steadytype_app_binary)"
  local deadline=$((SECONDS + 20))

  while ((SECONDS <= deadline)); do
    terminate_stale_steadytype_app_bundles

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
  local dist_dir app_bundle archive_path
  dist_dir="$(steadytype_dist_dir)"
  app_bundle="$(steadytype_app_bundle)"
  archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-$dist_dir/smoke-proof/SteadyType.zip}"
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

  local archive_attempt archive_status
  archive_status=1
  for archive_attempt in 1 2 3; do
    rm -f "$archive_abs"
    if (cd "$dist_dir" && ditto -c -k --keepParent "SteadyType.app" "$archive_abs"); then
      archive_status=0
      break
    fi
    archive_status=$?
    echo "Archive proof attempt $archive_attempt failed with status $archive_status; retrying." >&2
    sleep 0.5
  done
  if ((archive_status != 0)); then
    echo "Archive proof failed after 3 attempts." >&2
    return "$archive_status"
  fi

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
  ensure_cgevent_keypress_helper

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  seed_codex_proof_prompt "$proof_text" "$CODEX_DRAFT_BACKUP_PATH"
  if [[ -s "$CODEX_DRAFT_BACKUP_PATH" ]]; then
    CODEX_DRAFT_BACKUP_ACTIVE=1
  fi
  focus_codex_proof_prompt
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.openai.codex" "Codex proof suggestion" 20
  wait_for_screenshot_capture_if_enabled "$start_line" "com.openai.codex" "Codex proof"
  assert_frontmost_app "Codex" "Codex proof"
  sleep 0.05
  press_codex_tab_for_smoke "$start_line"
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

run_codex_full_accept() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local runtime_start_line start_line suggestion_start_line trace_start_line proof_text backup_dir accept_shortcut
  runtime_start_line="$(line_count "$LOG_PATH")"
  proof_text="$(codex_full_accept_proof_text)"
  backup_dir="$(make_tmp_dir)"
  CODEX_DRAFT_BACKUP_PATH="$backup_dir/codex-draft-backup.txt"
  : >"$CODEX_DRAFT_BACKUP_PATH"
  chmod 600 "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true

  prepare_temporary_app_enablement
  prepare_codex_full_accept_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Codex full accept Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Codex full accept runtime readiness" 60 "$SKIP_BUILD"
  ensure_cgevent_keypress_helper

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  seed_codex_proof_prompt "$proof_text" "$CODEX_DRAFT_BACKUP_PATH"
  if [[ -s "$CODEX_DRAFT_BACKUP_PATH" ]]; then
    CODEX_DRAFT_BACKUP_ACTIVE=1
  fi
  focus_codex_proof_prompt
  suggestion_start_line="$start_line"
  wait_for_log_fields "$suggestion_start_line" "Codex full accept phrase suggestion" 24 \
    "suggestion-presented" \
    "app=com.openai.codex" \
    "requestMode=phraseContinuation"
  wait_for_screenshot_capture_if_enabled "$suggestion_start_line" "com.openai.codex" "Codex full accept proof"
  assert_frontmost_app "Codex" "Codex full accept proof"
  sleep 0.05
  accept_shortcut="$(accept_all_shortcut)"
  press_codex_full_accept_shortcut_for_smoke "$start_line" "$suggestion_start_line" "$accept_shortcut"
  wait_for_log_fields "$suggestion_start_line" "Codex full accept acceptance" 12 \
    "keyboard-action" \
    "app=com.openai.codex" \
    "key=$accept_shortcut" \
    "action=acceptAllVisible" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert .*app=com.openai.codex .*success=true" "Codex full accept successful insertion" 12
  wait_for_log_pattern "$start_line" "insert-verification .*app=com.openai.codex .*result=verified" "Codex full accept verified insertion" 12
  assert_codex_prompt_retains_marker

  sleep 1
  AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_PROMPT_FULL_ACCEPT_NO_SUBMIT_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="full-accept" \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/manual_smoke_session.sh codex-full-accept --check --visual
}

retry_claude_code_terminal_proof_context() {
  local host_name="$1"
  local marker="$2"
  local attempt="$3"
  local max_attempts="$4"
  local reason="$5"

  if ((max_attempts > 0 && attempt >= max_attempts)); then
    echo "Claude Code $host_name proof attempt $attempt $reason; no disposable attempts remain."
    return 1
  fi
  echo "Claude Code $host_name proof attempt $attempt $reason; launching a fresh disposable context."
  open_fresh_claude_code_terminal_proof_context "$host_name" "$marker"
}

run_claude_code_terminal_host_smoke() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi
  if [[ "$CLAUDE_CODE_HOST_VARIANT" != "terminal" &&
        "$CLAUDE_CODE_HOST_VARIANT" != "iterm2" &&
        "$CLAUDE_CODE_HOST_VARIANT" != "ghostty" ]]; then
    run_manual_gated
    return
  fi

  require_claude_code_host_if_requested

  local runtime_start_line start_line trace_start_line suggestion_start_line pre_trigger_suggestion_start_line accept_start_line proof_text marker host_name
  local attempt max_attempts suggestion_wait_seconds found_suggestion suggestion_line suggestion_ready stale_blocker_line stale_blocker_reason relaxed_suggestion_start_line
  local ghostty_key_capture_miss_count ghostty_max_key_capture_misses
  local post_suggestion_failure_reason post_suggestion_failure_start_line
  runtime_start_line="$(line_count "$LOG_PATH")"
  marker="$(claude_code_proof_marker)"
  host_name="$(claude_code_host_display_name)"
  max_attempts="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS:-0}"
  ghostty_key_capture_miss_count=0
  ghostty_max_key_capture_misses="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES:-2}"
  suggestion_wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS:-20}"
  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]]; then
    echo "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS must be a non-negative integer." >&2
    exit 2
  fi
  if ! [[ "$ghostty_max_key_capture_misses" =~ ^[0-9]+$ ]]; then
    echo "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES must be a non-negative integer." >&2
    exit 2
  fi
  post_suggestion_failure_reason=""
  post_suggestion_failure_start_line=0

  prepare_temporary_app_enablement
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Claude Code Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Claude Code runtime readiness" 60 "$SKIP_BUILD"
  SMOKE_PHASE="claude-code $host_name warm hot-accept helpers"
  warm_claude_code_terminal_hot_accept_helpers "$host_name"
  echo "Claude Code $host_name proof warmed CGEvent helpers."

  SMOKE_PHASE="claude-code $host_name cleanup stale disposable contexts"
  echo "Claude Code $host_name proof cleaning stale disposable contexts."
  cleanup_stale_claude_code_terminal_proofs
  echo "Claude Code $host_name proof stale context cleanup finished."
  SMOKE_PHASE="claude-code $host_name open fresh disposable context"
  echo "Claude Code $host_name proof opening fresh disposable context."
  open_fresh_claude_code_terminal_proof_context "$host_name" "$marker"
  echo "Claude Code $host_name proof fresh disposable context ready."
  if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" && -n "${CLAUDE_CODE_TERMINAL_PROOF_LAUNCH_SCRIPT:-}" ]]; then
    allow_claude_code_ghostty_proof_command_alert \
      "$CLAUDE_CODE_TERMINAL_PROOF_LAUNCH_SCRIPT" \
      "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_ALERT_SECONDS:-2}" || true
  fi
  attempt=0
  found_suggestion=0
  accept_start_line="$(line_count "$LOG_PATH")"
  while IFS= read -r proof_text; do
    [[ -n "$proof_text" ]] || continue
    if ((max_attempts > 0 && attempt >= max_attempts)); then
      break
    fi
    attempt=$((attempt + 1))
    validate_claude_code_terminal_smoke_input_text "$proof_text"

    SMOKE_PHASE="claude-code $host_name prompt focus attempt $attempt"
    echo "Claude Code $host_name proof attempt $attempt waiting for disposable prompt focus."
    wait_for_frontmost_claude_code_terminal_proof_process
    SMOKE_PHASE="claude-code $host_name clear prompt attempt $attempt"
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_SKIP_FRESH_PROMPT_CLEAR:-1}" =~ ^(1|true|yes|on)$ ]]; then
      echo "Claude Code $host_name proof attempt $attempt skipping fresh disposable prompt clear; typed-prompt readiness will catch dirty prompt state."
    else
      echo "Claude Code $host_name proof attempt $attempt clearing disposable prompt line."
      if ! clear_claude_code_terminal_prompt_line; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost focus while clearing" || break
        continue
      fi
      echo "Claude Code $host_name proof attempt $attempt prompt line cleared."
      sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_SETTLE_SECONDS:-0.7}"
    fi

    start_line="$(line_count "$LOG_PATH")"
    trace_start_line="$(line_count "$TRACE_PATH")"

    CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE=0
    suggestion_start_line="$(line_count "$LOG_PATH")"
    pre_trigger_suggestion_start_line="$suggestion_start_line"
    SMOKE_PHASE="claude-code $host_name type proof text attempt $attempt"
    echo "Claude Code $host_name proof attempt $attempt typing proof text."
    if ! type_claude_code_terminal_smoke_text "$proof_text"; then
      retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost focus while typing" || break
      continue
    fi
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      suggestion_start_line="$pre_trigger_suggestion_start_line"
    elif [[ "${CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE:-0}" =~ ^[0-9]+$ &&
          "${CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE:-0}" != "0" ]]; then
      suggestion_start_line="$CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE"
    fi
    SMOKE_PHASE="claude-code $host_name prove typed prompt readiness attempt $attempt"
    if ! assert_claude_code_terminal_prompt_ready "$proof_text"; then
      retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "could not prove typed prompt readiness" || break
      continue
    fi
    if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      SMOKE_PHASE="claude-code $host_name pre-accept external mutation probe attempt $attempt"
      if ! run_claude_code_ghostty_pre_accept_external_mutation_probe "$proof_text"; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "pre-accept external mutation probe could not restore the prompt" || break
        continue
      fi
      if [[ "${CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE_RAN:-0}" == "1" ]]; then
        suggestion_start_line="$(line_count "$LOG_PATH")"
        pre_trigger_suggestion_start_line="$suggestion_start_line"
      fi
    fi
    accept_start_line="$suggestion_start_line"
    suggestion_ready=0
    SMOKE_PHASE="claude-code $host_name wait for suggestion attempt $attempt"
    if wait_for_claude_code_terminal_proof_suggestion_ready_optional \
      "$suggestion_start_line" \
      "$suggestion_wait_seconds"; then
      suggestion_ready=1
    fi
    if [[ "$suggestion_ready" != "1" &&
          "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      echo "Claude Code $host_name proof attempt $attempt primary suggestion wait ended; allowing diagnostics flush grace from line $suggestion_start_line."
      if wait_for_claude_code_terminal_log_flush_suggestion_line_optional \
        "$suggestion_start_line" \
        "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_LOG_FLUSH_GRACE_SECONDS:-8}"; then
        accept_start_line="$suggestion_start_line"
        suggestion_ready=1
      fi
    fi
    if [[ "$suggestion_ready" != "1" &&
          "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" &&
          "${CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE_RAN:-0}" != "1" &&
          "$pre_trigger_suggestion_start_line" != "$suggestion_start_line" ]]; then
      if find_claude_code_terminal_suggestion_line_optional "$pre_trigger_suggestion_start_line"; then
        accept_start_line="$pre_trigger_suggestion_start_line"
        suggestion_ready=1
      fi
    fi
    if [[ "$suggestion_ready" != "1" &&
          "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
      relaxed_suggestion_start_line="$start_line"
      if [[ "${CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE_RAN:-0}" == "1" ]]; then
        relaxed_suggestion_start_line="$suggestion_start_line"
      fi
      if find_recent_claude_code_terminal_suggestion_line_optional "$relaxed_suggestion_start_line" ||
         find_claude_code_terminal_suggestion_line_optional "$relaxed_suggestion_start_line"; then
        accept_start_line="$relaxed_suggestion_start_line"
        suggestion_ready=1
      fi
    fi
    if [[ "$suggestion_ready" != "1" &&
          "${CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_CANCELLED_BY_GEOMETRY:-0}" == "1" ]]; then
      echo "Claude Code $host_name proof attempt $attempt had its pending suggestion invalidated by screen geometry; nudging the same prompt."
      suggestion_start_line="$(line_count "$LOG_PATH")"
      if ! type_claude_code_terminal_smoke_text " "; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost focus while nudging after geometry invalidation" || break
        continue
      fi
      if ! assert_claude_code_terminal_prompt_ready "$proof_text"; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "could not prove prompt readiness after geometry invalidation" || break
        continue
      fi
      accept_start_line="$suggestion_start_line"
      if wait_for_claude_code_terminal_proof_suggestion_ready_optional \
        "$suggestion_start_line" \
        "$suggestion_wait_seconds"; then
        suggestion_ready=1
      fi
      if [[ "$suggestion_ready" != "1" &&
            "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
        echo "Claude Code $host_name proof attempt $attempt geometry nudge wait ended; allowing diagnostics flush grace from line $suggestion_start_line."
        if wait_for_claude_code_terminal_log_flush_suggestion_line_optional \
          "$suggestion_start_line" \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_LOG_FLUSH_GRACE_SECONDS:-8}"; then
          suggestion_ready=1
        fi
      fi
    fi
    if [[ "$suggestion_ready" != "1" &&
          "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]] &&
       find_recent_claude_code_terminal_stale_proof_blocker_optional "$suggestion_start_line"; then
      stale_blocker_line="$MATCHED_LOG_LINE"
      stale_blocker_reason="${MATCHED_LOG_REASON:-terminal-proof-gate}"
      echo "Claude Code $host_name proof attempt $attempt was still gated by $stale_blocker_reason at diagnostics line $stale_blocker_line after typed prompt readiness; nudging the same prompt."
      suggestion_start_line="$(line_count "$LOG_PATH")"
      if ! type_claude_code_terminal_smoke_text " "; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost focus while nudging after stale proof blocker" || break
        continue
      fi
      if ! assert_claude_code_terminal_prompt_ready "$proof_text"; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "could not prove prompt readiness after stale proof blocker" || break
        continue
      fi
      accept_start_line="$suggestion_start_line"
      if wait_for_claude_code_terminal_proof_suggestion_ready_optional \
        "$suggestion_start_line" \
        "$suggestion_wait_seconds"; then
        suggestion_ready=1
      fi
      if [[ "$suggestion_ready" != "1" ]]; then
        echo "Claude Code $host_name proof attempt $attempt stale blocker nudge wait ended; allowing diagnostics flush grace from line $suggestion_start_line."
        if wait_for_claude_code_terminal_log_flush_suggestion_line_optional \
          "$suggestion_start_line" \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_LOG_FLUSH_GRACE_SECONDS:-8}"; then
          suggestion_ready=1
        fi
      fi
    fi
    if [[ "$suggestion_ready" == "1" ]]; then
      suggestion_line="$MATCHED_LOG_LINE"
      echo "Claude Code $host_name proof attempt $attempt found prompt-row suggestion at diagnostics line $suggestion_line."
      SMOKE_PHASE="claude-code $host_name prepare hot accept attempt $attempt"
      if ! prepare_claude_code_terminal_suggestion_for_hot_accept "$suggestion_line" "$host_name"; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost its visible suggestion before Tab" || break
        continue
      fi
      suggestion_line="${CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE:-$suggestion_line}"
      settle_claude_code_terminal_proof_focus "Tab hot accept" || exit 1
      if ! prepare_claude_code_terminal_suggestion_for_hot_accept "$suggestion_line" "$host_name"; then
        retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "lost its visible suggestion during Tab refocus" || break
        continue
      fi
      suggestion_line="${CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE:-$suggestion_line}"
      if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]; then
        SMOKE_PHASE="claude-code $host_name press Tab attempt $attempt"
        if ! press_claude_code_terminal_host_tab "$suggestion_line" "$host_name"; then
          post_suggestion_failure_reason="${CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON:-Tab delivery failed during hot accept}"
          post_suggestion_failure_start_line="$suggestion_line"
          if [[ "$post_suggestion_failure_reason" == "key capture probe did not reach event tap" ]]; then
            ghostty_key_capture_miss_count=$((ghostty_key_capture_miss_count + 1))
            if ((ghostty_max_key_capture_misses > 0 &&
                 ghostty_key_capture_miss_count >= ghostty_max_key_capture_misses)); then
              post_suggestion_failure_reason="key capture probe did not reach event tap after ${ghostty_key_capture_miss_count} prompt-row suggestion(s)"
              echo "Claude Code $host_name proof reached $ghostty_key_capture_miss_count key capture miss(es); failing closed before launching another disposable context." >&2
              break
            fi
          fi
          retry_claude_code_terminal_proof_context \
            "$host_name" \
            "$marker" \
            "$attempt" \
            "$max_attempts" \
            "${CLAUDE_CODE_TERMINAL_HOST_TAB_FAILURE_REASON:-Tab delivery failed during hot accept}" || break
          continue
        fi
        SMOKE_PHASE="claude-code $host_name post-Tab external mutation probe attempt $attempt"
        if ! run_claude_code_ghostty_post_tab_pre_insert_external_mutation_probe "$proof_text" "$accept_start_line"; then
          retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "post-Tab/pre-insert external mutability probe could not restore the prompt" || break
          continue
        fi
      else
        press_key_code_cgevent 48
      fi
      wait_for_claude_code_terminal_tab_acceptance \
        "$accept_start_line" \
        "$host_name" \
        "$(claude_code_terminal_accept_wait_seconds)"
      found_suggestion=1
      break
    fi
    SMOKE_PHASE="claude-code $host_name suggestion diagnostics attempt $attempt"
    print_claude_code_terminal_suggestion_diagnostics_tail "$suggestion_start_line" "$host_name" "$attempt"
    retry_claude_code_terminal_proof_context "$host_name" "$marker" "$attempt" "$max_attempts" "produced no visible suggestion" || break
  done < <(claude_code_terminal_smoke_input_texts)

  if [[ "$found_suggestion" != "1" ]]; then
    if [[ -n "$post_suggestion_failure_reason" ]]; then
      if [[ "$post_suggestion_failure_reason" == key\ capture\ probe\ did\ not\ reach\ event\ tap* ]] &&
        wait_for_claude_code_terminal_key_capture_permission_ui_since \
          "${post_suggestion_failure_start_line:-0}" \
          "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS:-2}"; then
        post_suggestion_failure_reason="key capture probe lost focus to macOS permission UI"
      fi
      echo "Claude Code $host_name proof failed after a visible prompt-row suggestion: $post_suggestion_failure_reason." >&2
      echo "Required fields: keyboard-event-tap-latency app=com.anthropic.claude-code key=tab or key=other." >&2
      echo "Suggestion diagnostics line: ${post_suggestion_failure_start_line:-unknown}" >&2
      echo "Log: $LOG_PATH" >&2
      tail -n +"$((post_suggestion_failure_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 100 >&2
      exit 1
    fi
    echo "Timed out waiting for Claude Code $host_name proof suggestion after $attempt disposable context(s)." >&2
    echo "Pattern: suggestion-presented .*app=com.anthropic.claude-code" >&2
    echo "Log: $LOG_PATH" >&2
    tail -n +"$((suggestion_start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
    exit 1
  fi

  SMOKE_PHASE="claude-code $host_name wait for insertion result"
  wait_for_claude_code_terminal_insertion_result \
    "$accept_start_line" \
    "$host_name" \
    "$(claude_code_terminal_accept_wait_seconds)" \
    "$proof_text"
  wait_for_log_pattern "$accept_start_line" "insert-verification .*app=com.anthropic.claude-code .*result=verified" "Claude Code $host_name verified insertion" 12
  wait_for_screenshot_capture_if_enabled "$accept_start_line" "com.anthropic.claude-code" "Claude Code $host_name proof"
  assert_claude_code_terminal_prompt_retains_marker

  sleep 1
  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
  AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$(claude_code_host_proof_label)" \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT="$CLAUDE_CODE_HOST_VARIANT" \
    ./script/manual_smoke_session.sh claude-code --check --visual
}

run_codex_model_latency() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local runtime_start_line start_line trace_start_line backup_dir proof_runtime_guard_line
  runtime_start_line="$(line_count "$LOG_PATH")"
  backup_dir="$(make_tmp_dir)"
  CODEX_DRAFT_BACKUP_PATH="$backup_dir/codex-draft-backup.txt"
  : >"$CODEX_DRAFT_BACKUP_PATH"
  chmod 600 "$CODEX_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true

  prepare_temporary_app_enablement
  prepare_codex_model_latency_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Codex model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Codex model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local sample_index=0 visible_sample_count=0 empty_sample_count=0 proof_text sample_start stable_context context_prefix trigger_word trigger_text expected_text
  while IFS= read -r proof_text; do
    [[ -z "$proof_text" ]] && continue
    sample_index=$((sample_index + 1))
    if [[ "$proof_text" != *"AUTOCOMPLETE_LAB_CODEX_PROOF"* ]]; then
      echo "Codex model latency sample $sample_index must include AUTOCOMPLETE_LAB_CODEX_PROOF." >&2
      exit 2
    fi
    if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
      echo "Codex model latency sample $sample_index must be a single line." >&2
      exit 2
    fi
    trigger_word="${proof_text##* }"
    context_prefix="${proof_text%"$trigger_word"}"
    trigger_text="${trigger_word:0:1}"
    stable_context="$context_prefix"
    expected_text="${stable_context}${trigger_text}"
    if [[ -z "$trigger_word" || "$stable_context" == "$proof_text" || -z "$trigger_text" ]]; then
      echo "Codex model latency sample $sample_index does not contain a stable context plus trigger word." >&2
      exit 1
    fi

    assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "Codex model latency sample $sample_index"
    seed_codex_proof_prompt "$stable_context" "$CODEX_DRAFT_BACKUP_PATH"
    if [[ -s "$CODEX_DRAFT_BACKUP_PATH" ]]; then
      CODEX_DRAFT_BACKUP_ACTIVE=1
    fi
    focus_codex_proof_prompt
    assert_frontmost_app "Codex" "Codex model latency seed $sample_index"
    assert_codex_proof_prompt_ready "$stable_context"
    sleep "${AUTOCOMPLETE_LAB_CODEX_MODEL_LATENCY_SEED_SETTLE_SECONDS:-0.35}"
    sample_start="$(line_count "$LOG_PATH")"
    type_codex_raw_smoke_text "$trigger_text"
    assert_codex_proof_prompt_ready "$expected_text"
    if wait_for_log_fields_optional "$sample_start" "8" \
      "suggestion-presented" \
      "app=com.openai.codex" \
      "requestMode=wordCompletion" \
      "candidateSelectionSource=app-model-result"; then
      assert_codex_prompt_retains_marker
      visible_sample_count=$((visible_sample_count + 1))
    elif wait_for_log_fields_optional "$sample_start" "1" \
      "suggestion-blocked" \
      "app=com.openai.codex" \
      "reason=empty-suggestion"; then
      empty_sample_count=$((empty_sample_count + 1))
      echo "Codex model latency sample $sample_index produced an empty word candidate; trying the next disposable context." >&2
      assert_codex_prompt_retains_marker
    else
      wait_for_log_fields "$sample_start" "Codex model latency suggestion $sample_index" 1 \
        "suggestion-presented" \
        "app=com.openai.codex" \
        "requestMode=wordCompletion" \
        "candidateSelectionSource=app-model-result"
    fi
    if ((visible_sample_count >= 5)); then
      break
    fi
    sleep 0.35
  done < <(codex_model_latency_proof_texts)

  if ((visible_sample_count < 5)); then
    echo "Codex model latency proof expected at least 5 visible model-backed word-completion samples, got $visible_sample_count visible and $empty_sample_count empty from $sample_index attempted contexts." >&2
    exit 1
  fi

  sleep 1
  AUTOCOMPLETE_LAB_PROMPT_PROOF_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_START_LINE="$((trace_start_line + 1))" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_EXTRA_BUNDLES="com.openai.codex" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="codex-model-latency" \
    ./script/check_prompt_app_proof.sh

  AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/latency_benchmark_report.py --beta-gate
}

run_claude_model_latency() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  local runtime_start_line start_line trace_start_line backup_dir proof_runtime_guard_line marker
  runtime_start_line="$(line_count "$LOG_PATH")"
  backup_dir="$(make_tmp_dir)"
  CLAUDE_DRAFT_BACKUP_PATH="$backup_dir/claude-draft-backup.txt"
  : >"$CLAUDE_DRAFT_BACKUP_PATH"
  chmod 600 "$CLAUDE_DRAFT_BACKUP_PATH" >/dev/null 2>&1 || true
  marker="$(claude_proof_marker)"

  prepare_temporary_app_enablement
  prepare_claude_model_latency_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Claude model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Claude model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"
  open -a Claude
  wait_for_frontmost_app "Claude" "${AUTOCOMPLETE_LAB_CLAUDE_ACTIVATION_WAIT_SECONDS:-12}"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local sample_index=0 visible_sample_count=0 empty_sample_count=0 proof_text sample_start stable_context context_prefix trigger_word trigger_text expected_text
  while IFS= read -r proof_text; do
    [[ -z "$proof_text" ]] && continue
    sample_index=$((sample_index + 1))
    if [[ "$proof_text" != *"$marker"* ]]; then
      echo "Claude model latency sample $sample_index must include $marker." >&2
      exit 2
    fi
    if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
      echo "Claude model latency sample $sample_index must be a single line." >&2
      exit 2
    fi
    trigger_word="${proof_text##* }"
    context_prefix="${proof_text%"$trigger_word"}"
    trigger_text="${trigger_word:0:1}"
    stable_context="$context_prefix"
    expected_text="${stable_context}${trigger_text}"
    if [[ -z "$trigger_word" || "$stable_context" == "$proof_text" || -z "$trigger_text" ]]; then
      echo "Claude model latency sample $sample_index does not contain a stable context plus trigger word." >&2
      exit 1
    fi

    assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "Claude model latency sample $sample_index"
    seed_claude_proof_prompt "$stable_context" "$CLAUDE_DRAFT_BACKUP_PATH"
    focus_claude_proof_prompt
    assert_frontmost_app "Claude" "Claude model latency seed $sample_index"
    assert_claude_proof_prompt_ready "$stable_context"
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_MODEL_LATENCY_SEED_SETTLE_SECONDS:-0.35}"
    sample_start="$(line_count "$LOG_PATH")"
    type_claude_raw_smoke_text "$trigger_text"
    assert_claude_proof_prompt_ready "$expected_text"
    if wait_for_log_fields_optional "$sample_start" "8" \
      "suggestion-presented" \
      "app=com.anthropic.claudefordesktop" \
      "requestMode=wordCompletion"; then
      assert_claude_prompt_retains_marker
      visible_sample_count=$((visible_sample_count + 1))
    elif wait_for_log_fields_optional "$sample_start" "1" \
      "suggestion-blocked" \
      "app=com.anthropic.claudefordesktop" \
      "reason=empty-suggestion"; then
      empty_sample_count=$((empty_sample_count + 1))
      echo "Claude model latency sample $sample_index produced an empty word candidate; trying the next disposable context." >&2
      assert_claude_prompt_retains_marker
    else
      wait_for_log_fields "$sample_start" "Claude model latency suggestion $sample_index" 1 \
        "suggestion-presented" \
        "app=com.anthropic.claudefordesktop" \
        "requestMode=wordCompletion"
    fi
    if ((visible_sample_count >= 5)); then
      break
    fi
    sleep 0.35
  done < <(claude_model_latency_proof_texts)

  if ((visible_sample_count < 5)); then
    echo "Claude model latency proof expected at least 5 visible model-backed word-completion samples, got $visible_sample_count visible and $empty_sample_count empty from $sample_index attempted contexts." >&2
    exit 1
  fi

  sleep 1
  AUTOCOMPLETE_LAB_PROMPT_PROOF_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_START_LINE="$((trace_start_line + 1))" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_EXTRA_BUNDLES="com.anthropic.claudefordesktop" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="claude-model-latency" \
    ./script/check_prompt_app_proof.sh

  AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/latency_benchmark_report.py --beta-gate
}

run_claude_code_model_latency() {
  if [[ "$MANUAL_GATE" != "1" ]]; then
    echo "${REQUESTED_APP:-$APP} real smoke requires --manual-gate because $(manual_gate_reason)." >&2
    exit 2
  fi

  if [[ "$CLAUDE_CODE_HOST_VARIANT" != "terminal" ]]; then
    echo "claude-code-model-latency currently supports only the Terminal host automation lane." >&2
    echo "Use claude-code-terminal-model-latency or --host terminal." >&2
    exit 2
  fi

  require_claude_code_host_if_requested

  local runtime_start_line start_line trace_start_line proof_runtime_guard_line marker proof_dir
  runtime_start_line="$(line_count "$LOG_PATH")"
  marker="$(claude_code_proof_marker)"
  proof_dir="$(make_claude_code_terminal_proof_dir)"
  CLAUDE_CODE_TERMINAL_PROOF_TITLE="$(claude_code_terminal_proof_title_for_dir "$proof_dir")"

  prepare_temporary_app_enablement
  prepare_claude_code_model_latency_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "Claude Code model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "Claude Code model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"

  cleanup_stale_claude_code_terminal_proofs
  open_claude_code_terminal_proof "$proof_dir" "$CLAUDE_CODE_TERMINAL_PROOF_TITLE"
  wait_for_frontmost_app "Terminal" "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACTIVATION_WAIT_SECONDS:-12}"
  wait_for_claude_code_terminal_prompt

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local sample_index=0 visible_sample_count=0 empty_sample_count=0 proof_text sample_iteration_start sample_seed_start sample_start stable_context context_prefix trigger_word trigger_text expected_text expected_user_text expected_before_chars trigger_char_count suggestion_wait_seconds fresh_prompt_per_sample prompt_is_fresh
  if [[ "$CLAUDE_CODE_TERMINAL_PROOF_TITLE" != *"$marker"* ]]; then
    echo "Claude Code model latency proof title must include $marker." >&2
    exit 2
  fi
  trigger_char_count="${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_TRIGGER_CHARS:-3}"
  if ! [[ "$trigger_char_count" =~ ^[1-9][0-9]*$ ]]; then
    echo "AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_TRIGGER_CHARS must be a positive integer." >&2
    exit 2
  fi
  suggestion_wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_SUGGESTION_WAIT_SECONDS:-20}"
  if ! [[ "$suggestion_wait_seconds" =~ ^[1-9][0-9]*$ ]]; then
    echo "AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_SUGGESTION_WAIT_SECONDS must be a positive integer." >&2
    exit 2
  fi
  fresh_prompt_per_sample="${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_FRESH_PROMPT_PER_SAMPLE:-1}"
  case "$fresh_prompt_per_sample" in
    1|true|yes|on) fresh_prompt_per_sample=1 ;;
    0|false|no|off) fresh_prompt_per_sample=0 ;;
    *)
      echo "AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_FRESH_PROMPT_PER_SAMPLE must be a boolean." >&2
      exit 2
      ;;
  esac
  prompt_is_fresh=1
  while IFS= read -r proof_text; do
    [[ -z "$proof_text" ]] && continue
    sample_index=$((sample_index + 1))
    if [[ "$fresh_prompt_per_sample" == "1" && "$prompt_is_fresh" != "1" ]]; then
      cleanup_claude_code_terminal_proof
      proof_dir="$(make_claude_code_terminal_proof_dir)"
      CLAUDE_CODE_TERMINAL_PROOF_TITLE="$(claude_code_terminal_proof_title_for_dir "$proof_dir")"
      open_claude_code_terminal_proof "$proof_dir" "$CLAUDE_CODE_TERMINAL_PROOF_TITLE"
      wait_for_frontmost_app "Terminal" "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_ACTIVATION_WAIT_SECONDS:-12}"
      wait_for_claude_code_terminal_prompt
      prompt_is_fresh=1
    fi
    if [[ "$proof_text" == *$'\n'* || "$proof_text" == *$'\r'* ]]; then
      echo "Claude Code model latency sample $sample_index must be a single line." >&2
      exit 2
    fi
    if [[ "$proof_text" != *"$marker"* ]]; then
      echo "Claude Code model latency sample $sample_index must include $marker." >&2
      exit 2
    fi
    trigger_word="${proof_text##* }"
    context_prefix="${proof_text%"$trigger_word"}"
    trigger_text="${trigger_word:0:trigger_char_count}"
    stable_context="$context_prefix"
    expected_text="${stable_context}${trigger_text}"
    expected_user_text="${expected_text/"$marker"/}"
    while [[ "$expected_user_text" == " "* || "$expected_user_text" == $'\t'* ]]; do
      expected_user_text="${expected_user_text#?}"
    done
    expected_before_chars="${#expected_user_text}"
    if [[ -z "$trigger_word" || "$stable_context" == "$proof_text" || -z "$trigger_text" ]]; then
      echo "Claude Code model latency sample $sample_index does not contain a stable context plus trigger word." >&2
      exit 1
    fi

    assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "Claude Code model latency sample $sample_index"
    assert_frontmost_app "Terminal" "Claude Code model latency seed $sample_index"
    sample_iteration_start="$(line_count "$LOG_PATH")"
    if [[ "$prompt_is_fresh" == "1" ]]; then
      prompt_is_fresh=0
    else
      clear_claude_code_terminal_prompt_line
      sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_CLEAR_SETTLE_SECONDS:-0.7}"
    fi
    sample_seed_start="$(line_count "$LOG_PATH")"
    type_claude_code_terminal_raw_smoke_text "$stable_context"
    assert_claude_code_terminal_prompt_ready "$stable_context"
    sleep "${AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_SEED_SETTLE_SECONDS:-0.35}"
    sample_start="$(line_count "$LOG_PATH")"
    type_claude_code_terminal_raw_smoke_text "$trigger_text"
    assert_claude_code_terminal_prompt_ready "$expected_text"
    if wait_for_log_fields_optional "$sample_iteration_start" "$suggestion_wait_seconds" \
      "suggestion-presented" \
      "app=com.anthropic.claude-code" \
      "beforeChars=$expected_before_chars" \
      "partialWordCharacters=${#trigger_text}" \
      "requestMode=wordCompletion" \
      "candidateSelectionSource=app-model-result"; then
      echo "Claude Code model latency sample $sample_index produced a model-backed visible suggestion during the typed sample window." >&2
      assert_claude_code_terminal_prompt_retains_marker
      visible_sample_count=$((visible_sample_count + 1))
    elif wait_for_log_fields_optional "$sample_iteration_start" "1" \
      "suggestion-blocked" \
      "app=com.anthropic.claude-code" \
      "beforeChars=$expected_before_chars" \
      "reason=empty-suggestion"; then
      empty_sample_count=$((empty_sample_count + 1))
      echo "Claude Code model latency sample $sample_index produced an empty word candidate; trying the next disposable context." >&2
      assert_claude_code_terminal_prompt_retains_marker
    else
      wait_for_log_fields "$sample_start" "Claude Code model latency suggestion $sample_index" 1 \
        "suggestion-presented" \
        "app=com.anthropic.claude-code" \
        "beforeChars=$expected_before_chars" \
        "partialWordCharacters=${#trigger_text}" \
        "requestMode=wordCompletion" \
        "candidateSelectionSource=app-model-result"
    fi
    if ((visible_sample_count >= 5)); then
      break
    fi
    sleep 0.35
  done < <(claude_code_model_latency_proof_texts)

  if ((visible_sample_count < 5)); then
    echo "Claude Code model latency proof expected at least 5 visible model-backed word-completion samples, got $visible_sample_count visible and $empty_sample_count empty from $sample_index attempted contexts." >&2
    exit 1
  fi

  sleep 1
  AUTOCOMPLETE_LAB_PROMPT_PROOF_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_START_LINE="$((trace_start_line + 1))" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_EXTRA_BUNDLES="com.anthropic.claude-code" \
  AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="claude-code-model-latency" \
    ./script/check_prompt_app_proof.sh

  AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/latency_benchmark_report.py --beta-gate
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
  AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX="${1:-}" swift script/obsidian_ax_editor.swift assert
}

wait_for_obsidian_smoke_target_current_value_end() {
  local expected_suffix="$1"
  local timeout_seconds="${2:-6}"
  local deadline=$((SECONDS + timeout_seconds))
  local output=""

  while ((SECONDS <= deadline)); do
    if output="$(
      AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX="$expected_suffix" \
        AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX_REQUIRES_EDITOR=1 \
        AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_CURRENT_VALUE_END=1 \
        swift script/obsidian_ax_editor.swift assert 2>/dev/null
    )"; then
      sleep 0.1
      AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX="$expected_suffix" \
        AUTOCOMPLETE_LAB_OBSIDIAN_EXPECTED_SUFFIX_REQUIRES_EDITOR=1 \
        AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_CURRENT_VALUE_END=1 \
        swift script/obsidian_ax_editor.swift assert >/dev/null 2>&1 || true
      printf '%s\n' "$output"
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Obsidian AX editor to expose expected disposable suffix." >&2
  echo "Expected suffix: $expected_suffix" >&2
  exit 3
}

wait_for_obsidian_smoke_editor_ready() {
  local timeout_seconds="${1:-8}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if swift script/obsidian_ax_editor.swift assert >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for the disposable Obsidian smoke editor." >&2
  exit 1
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

activate_notes_for_smoke() {
  osascript <<'APPLESCRIPT' >/dev/null
tell application "Notes" to activate
APPLESCRIPT
  wait_for_frontmost_app "Notes" 5
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
  if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_AX_TYPE:-0}" == "1" ]] &&
    AUTOCOMPLETE_LAB_OBSIDIAN_RAW_TEXT="$text" swift script/obsidian_ax_editor.swift insert >/dev/null 2>&1; then
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
  key code 125 using command down
  delay 0.2
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
  swift script/obsidian_ax_editor.swift focus >/dev/null
  sleep 0.15
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

let endLocation = value.utf16.count
var endRange = CFRange(location: endLocation, length: 0)
if let rangeValue = AXValueCreate(.cfRange, &endRange) {
    _ = AXUIElementSetAttributeValue(target, kAXSelectedTextRangeAttribute as CFString, rangeValue)
}

let deadline = Date().addingTimeInterval(1.0)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 0.75)
while Date() < deadline {
    var focusedValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(
        systemWide,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    ) == .success,
       let focusedValue {
        let focused = (focusedValue as! AXUIElement)
        if stringAttribute(focused, kAXRoleAttribute) == kAXTextAreaRole as String {
            exit(0)
        }
    }

    _ = AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    if let rangeValue = AXValueCreate(.cfRange, &endRange) {
        _ = AXUIElementSetAttributeValue(target, kAXSelectedTextRangeAttribute as CFString, rangeValue)
    }
    Thread.sleep(forTimeInterval: 0.1)
}
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
  AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT="$marker" swift script/obsidian_ax_editor.swift reset

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

obsidian_smoke_note_trimmed_tail_line() {
  local smoke_file
  smoke_file="$(obsidian_smoke_file_path)"
  tail -n 1 "$smoke_file" 2>/dev/null |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

obsidian_smoke_note_tail_line() {
  local smoke_file
  smoke_file="$(obsidian_smoke_file_path)"
  tail -n 1 "$smoke_file" 2>/dev/null
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
  local smoke_file deadline current_tail
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

  deadline=$((SECONDS + 5))
  while ((SECONDS <= deadline)); do
    current_tail="$(obsidian_smoke_note_trimmed_tail_line)"
    if [[ "$current_tail" == "$expected_suffix" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "Timed out waiting for Obsidian long note to end with expected disposable text." >&2
  echo "Expected trimmed tail: $expected_suffix" >&2
  echo "Current tail:" >&2
  tail -c 240 "$smoke_file" >&2 || true
  echo >&2
  exit 3
}

assert_obsidian_first_accept_tail_for_variant() {
  local manual_app="$1"
  local current_tail="$2"

  case "$manual_app" in
    obsidian-run-on)
      case "$current_tail" in
        *"Smoke proof feels "*)
          return 0
          ;;
      esac
      ;;
    obsidian-markdown-bold)
      case "$current_tail" in
        "**Smoke proof feels "*)
          return 0
          ;;
      esac
      ;;
    obsidian-markdown-list)
      case "$current_tail" in
        "- Smoke proof feels "*)
          return 0
          ;;
      esac
      ;;
    *)
      case "$current_tail" in
        "Smoke proof feels "*)
          return 0
          ;;
      esac
      ;;
  esac

  echo "Obsidian first accept did not preserve the disposable proof prefix." >&2
  echo "Current tail: $current_tail" >&2
  exit 3
}

activate_neutral_smoke_setup_app() {
  open -a Finder >/dev/null 2>&1 || true
  try_wait_for_frontmost_app "Finder" 3 >/dev/null 2>&1 || true
  sleep 0.2
}

obsidian_reset_text_for_variant() {
  local variant="$1"
  local marker="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER:-Autocomplete Lab Obsidian proof}"
  local reset_text="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT:-$marker}"

  if [[ "$variant" != "obsidian-long-note" ]]; then
    printf '%s' "$reset_text"
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

ensure_obsidian_smoke_renderer_accessibility_launch() {
  if pgrep -x Obsidian >/dev/null 2>&1; then
    return 0
  fi

  local app_path="${AUTOCOMPLETE_LAB_OBSIDIAN_APP_PATH:-/Applications/Obsidian.app}"
  if [[ -d "$app_path" ]]; then
    open -na "$app_path" --args --force-renderer-accessibility
  else
    open -na Obsidian --args --force-renderer-accessibility
  fi
  sleep "${AUTOCOMPLETE_LAB_OBSIDIAN_INITIAL_LAUNCH_WAIT_SECONDS:-2}"
}

open_obsidian_smoke_note_if_configured() {
  local smoke_uri="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_URI:-}"
  ensure_obsidian_smoke_renderer_accessibility_launch
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
    activate_obsidian_for_smoke
    return 0
  fi

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

  local runtime_start_line start_line trace_start_line full_accept_key second_start_line full_start_line obsidian_marker first_fragment long_note_second_fragment
  runtime_start_line="$(line_count "$LOG_PATH")"
  local marker_sentinel=$'\034'
  obsidian_marker="$(obsidian_smoke_marker_text "$manual_app"; printf '%s' "$marker_sentinel")"
  obsidian_marker="${obsidian_marker%"$marker_sentinel"}"
  case "$manual_app" in
    obsidian|obsidian-theme|obsidian-pane|obsidian-font-zoom|obsidian-multiline)
      obsidian_marker+=" "
      ;;
  esac
  first_fragment="Smoke proof feels"
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    first_fragment=""
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT=1
  elif [[ "$manual_app" == "obsidian-pane" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
  elif [[ "$manual_app" == "obsidian-font-zoom" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
  elif [[ "$manual_app" == "obsidian-markdown-list" ]]; then
    export AUTOCOMPLETE_LAB_OBSIDIAN_FORCE_KEYSTROKE_TYPE=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_CLICK_VISIBLE_TAIL=1
    export AUTOCOMPLETE_LAB_OBSIDIAN_VISIBLE_TAIL_REQUIRES_LINE_90=0
    export AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT=1
  elif [[ "$manual_app" == "obsidian-run-on" ]]; then
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
  if [[ "$manual_app" =~ ^obsidian-(long-note|run-on)$ && -z "${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-}" ]]; then
    export AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab
  fi
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_BASE:-Autocomplete Lab Obsidian proof}"
  export AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT="$obsidian_marker"

  prepare_temporary_app_enablement
  if [[ "$SKIP_BUILD" == "1" ]]; then
    build_if_needed
    wait_for_accessibility_ready "$runtime_start_line" "Obsidian Accessibility readiness" 20 "$SKIP_BUILD"
    wait_for_runtime_ready "$runtime_start_line" "Obsidian runtime readiness" 60 "$SKIP_BUILD"
  else
    build_bundle_if_needed
    stop_current_steadytype_app_bundle
  fi

  full_accept_key="$(accept_all_shortcut)"

  local obsidian_reset_text
  obsidian_reset_text="$(obsidian_reset_text_for_variant "$manual_app")"
  seed_obsidian_proof_vault_note "$obsidian_reset_text"
  open_obsidian_smoke_note_if_configured
  wait_for_obsidian_smoke_editor_ready 8
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    reset_obsidian_smoke_note_file "$(obsidian_long_note_text_before_trigger)"
    open_obsidian_smoke_note_if_configured
    wait_for_obsidian_smoke_editor_ready 8
  fi
  prepare_obsidian_variant_state "$manual_app"
  assert_obsidian_smoke_target
  if [[ "$manual_app" != "obsidian-long-note" ]]; then
    reset_obsidian_zoom_for_smoke
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

  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    set_obsidian_caret_to_value_end
  fi

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    move_obsidian_caret_to_document_end
    assert_obsidian_smoke_target
    type_obsidian_raw_smoke_text "s"
    wait_for_obsidian_smoke_note_file_suffix "Smoke proof feels" 5
    move_obsidian_caret_to_document_end
    assert_obsidian_smoke_target "Smoke proof feels"
  else
    type_obsidian_raw_smoke_text "$first_fragment"
  fi
  if [[ "$SKIP_BUILD" != "1" ]]; then
    launch_steadytype_after_chrome_setup "obsidian" "$start_line"
    wait_for_log_line_number "$start_line" "app-proof-mode-env apps=.*md[.]obsidian" "Obsidian proof-mode launch" 20
    start_line="$MATCHED_LOG_LINE"
    prepare_obsidian_variant_state "$manual_app"
    if [[ "$manual_app" == "obsidian-long-note" ]]; then
      assert_obsidian_smoke_target "Smoke proof feels"
    else
      assert_obsidian_smoke_target
    fi
  fi
  wait_for_log_pattern "$start_line" "suggestion-presented .*app=md.obsidian" "Obsidian suggestion"
  activate_obsidian_for_smoke
  press_key_code 48
  wait_for_log_fields "$start_line" "Obsidian Tab acceptance" 12 \
    "keyboard-action" \
    "app=md.obsidian" \
    "key=tab" \
    "action=acceptNextWord" \
    "handled=true"
  wait_for_log_pattern "$start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian first verified insertion"
  wait_for_screenshot_capture_if_enabled "$start_line" "md.obsidian" "Obsidian"

  local first_expected_suffix
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    sleep 0.2
    activate_neutral_smoke_setup_app
    assert_obsidian_long_note_file_preserved "Smoke proof feels instant"
    long_note_second_fragment=" and stays"
    if [[ "$(obsidian_smoke_note_tail_line)" =~ [[:space:]]$ ]]; then
      long_note_second_fragment="and stays"
    fi
    append_obsidian_smoke_note_file_text "$long_note_second_fragment"
    second_start_line="$(line_count "$LOG_PATH")"
    open_obsidian_smoke_note_if_configured
    wait_for_frontmost_app "Obsidian" 8
    wait_for_obsidian_smoke_target_current_value_end "Smoke proof feels instant and stays" 8
    long_note_expected_before_chars="$(obsidian_smoke_note_file_char_count)"
  else
    settle_obsidian_focus_for_smoke "Obsidian post-accept setup"
    local first_raw_tail_line second_fragment
    first_expected_suffix="$(obsidian_smoke_note_trimmed_tail_line)"
    assert_obsidian_first_accept_tail_for_variant "$manual_app" "$first_expected_suffix"
    assert_obsidian_smoke_target "$first_expected_suffix"
    first_raw_tail_line="$(obsidian_smoke_note_tail_line)"
    second_fragment=" and stays"
    if [[ "$first_raw_tail_line" =~ [[:space:]]$ ]]; then
      second_fragment="and stays"
    fi
    if [[ "$manual_app" == "obsidian-pane" ]]; then
      move_obsidian_caret_to_line_end
    elif [[ "$manual_app" == "obsidian-markdown-bold" || "$manual_app" == "obsidian-markdown-list" || "$manual_app" == "obsidian-run-on" ]]; then
      move_obsidian_caret_to_document_end
    elif [[ "$manual_app" == "obsidian-multiline" ]]; then
      set_obsidian_caret_to_value_end
    fi
    if [[ "${AUTOCOMPLETE_LAB_OBSIDIAN_ESCAPE_BETWEEN_ACCEPTS:-0}" == "1" ]]; then
      press_key_code 53
      sleep 0.25
    else
      sleep 0.15
    fi
    second_start_line="$(line_count "$LOG_PATH")"
    AUTOCOMPLETE_LAB_OBSIDIAN_AX_TYPE=1 type_obsidian_raw_smoke_text "$second_fragment"
    if [[ "$manual_app" == "obsidian-pane" ]]; then
      set_obsidian_caret_to_value_end
      move_obsidian_caret_to_line_end
    elif [[ "$manual_app" == "obsidian-markdown-bold" || "$manual_app" == "obsidian-markdown-list" ]]; then
      set_obsidian_caret_to_value_end
      move_obsidian_caret_to_document_end
    elif [[ "$manual_app" == "obsidian" || "$manual_app" == "obsidian-theme" ]]; then
      move_obsidian_caret_to_line_end
    fi
  fi
  if [[ "$manual_app" == "obsidian-long-note" ]]; then
    wait_for_obsidian_long_note_second_suggestion "$second_start_line" "$long_note_expected_before_chars" 12
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
    wait_for_screenshot_capture_if_enabled "$second_start_line" "md.obsidian" "Obsidian long-note second"
    assert_obsidian_long_note_file_preserved "Smoke proof feels instant and stays instant"
  else
    if [[ "$manual_app" != "obsidian-run-on" ]]; then
      activate_obsidian_for_smoke
    fi
    full_start_line="$(line_count "$LOG_PATH")"
    press_accept_all_shortcut
    wait_for_log_fields "$full_start_line" "Obsidian full acceptance" 12 \
      "keyboard-action" \
      "app=md.obsidian" \
      "key=$full_accept_key" \
      "action=acceptAllVisible" \
      "handled=true"
    wait_for_log_pattern "$full_start_line" "insert-verification .*app=md.obsidian .*result=verified" "Obsidian full verified insertion"
    wait_for_screenshot_capture_if_enabled "$second_start_line" "md.obsidian" "Obsidian second"
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
    activate_notes_for_smoke
    assert_frontmost_app "Notes" "Notes title"
    settle_keyboard_event_tap_if_started "$start_line" "Notes title Tab acceptance"
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
    activate_notes_for_smoke
    assert_frontmost_app "Notes" "Notes title"
    settle_keyboard_event_tap_if_started "$second_start_line" "Notes title full acceptance"
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
    activate_notes_for_smoke
    assert_frontmost_app "Notes" "Notes checklist"
    settle_keyboard_event_tap_if_started "$start_line" "Notes checklist Tab acceptance"
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
    activate_notes_for_smoke
    assert_frontmost_app "Notes" "Notes checklist"
    settle_keyboard_event_tap_if_started "$second_start_line" "Notes checklist full acceptance"
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
  activate_notes_for_smoke
  assert_frontmost_app "Notes" "Notes body"
  settle_keyboard_event_tap_if_started "$start_line" "Notes body Tab acceptance"
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
  activate_notes_for_smoke
  assert_frontmost_app "Notes" "Notes body"
  settle_keyboard_event_tap_if_started "$second_start_line" "Notes body full acceptance"
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

  if [[ "$TEXTEDIT_VARIANT" == "default-model-latency" ]]; then
    run_textedit_default_model_latency
    return 0
  fi

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
    focus_textedit_smoke_editor "$textedit_window_title"
    click_textedit_smoke_editor "$textedit_window_title"
    assert_textedit_frontmost_window "$textedit_window_title" "TextEdit one-word undo"
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
  wait_for_screenshot_capture_if_enabled "$start_line" "com.apple.TextEdit" "TextEdit"
  local full_start_line full_accept_key second_start_line
  full_accept_key="$(accept_all_shortcut)"
  second_start_line="$(line_count "$LOG_PATH")"

  SMOKE_PHASE="TextEdit second suggestion"
  type_textedit_smoke_fragment_and_confirm "$textedit_window_title" " and the draft is almost" "second typed"

  wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.apple.TextEdit" "TextEdit second suggestion"
  focus_textedit_smoke_editor "$textedit_window_title"
  assert_textedit_frontmost_window "$textedit_window_title" "TextEdit"
  local before_full_accept_text
  before_full_accept_text="$(textedit_document_text "$textedit_window_title")"
  full_start_line="$(line_count "$LOG_PATH")"
  SMOKE_PHASE="TextEdit full acceptance"
  wait_for_textedit_acceptance_with_stale_retry "$full_start_line" "TextEdit full acceptance" "$full_accept_key" "acceptAllVisible" "$textedit_window_title"
  wait_for_log_pattern "$full_start_line" "insert-verification .*app=com.apple.TextEdit .*result=verified" "TextEdit full verified insertion"
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.apple.TextEdit" "TextEdit second"

  if native_undo_proof_requested; then
    verify_textedit_native_undo "$textedit_window_title" "$before_full_accept_text" "$full_start_line" "TextEdit full native undo" "acceptAllVisible"
  elif [[ "$TEXTEDIT_VARIANT" == "undo-full" ]]; then
    local full_undo_start_line
    full_undo_start_line="$(line_count "$LOG_PATH")"
    focus_textedit_smoke_editor "$textedit_window_title"
    click_textedit_smoke_editor "$textedit_window_title"
    assert_textedit_frontmost_window "$textedit_window_title" "TextEdit full-accept undo"
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
	      "reason=30s" \
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
  local runtime_start_line start_line textedit_file textedit_tmp_dir textedit_window_title trace_start_line proof_runtime_guard_line
  runtime_start_line="$(line_count "$LOG_PATH")"
  export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1

  prepare_temporary_app_enablement
  prepare_model_latency_runtime_options
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "TextEdit model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "TextEdit model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"

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

  local sample_index=0 model_sample_count=0 visible_sample_count=0 event_tap_sample_count=0 event_tap_started=0 fragment sample_start seed_start context_prefix stable_context trigger_word trigger_text expected_text attempt max_attempts attempt_had_model attempt_had_visible attempt_had_event_tap event_tap_start
  max_attempts="${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_ATTEMPTS_PER_FRAGMENT:-3}"
  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || ((max_attempts < 1)); then
    echo "AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_ATTEMPTS_PER_FRAGMENT must be a positive integer." >&2
    exit 2
  fi
  while IFS= read -r fragment; do
    [[ -z "$fragment" ]] && continue
    sample_index=$((sample_index + 1))
    trigger_word="${fragment##* }"
    context_prefix="${fragment%"$trigger_word"}"
    stable_context="$context_prefix"
    trigger_text="${trigger_word:0:1}"
    expected_text="${stable_context}${trigger_text}"
    if [[ -z "$trigger_word" || "$stable_context" == "$fragment" || -z "$trigger_text" ]]; then
      echo "TextEdit model latency sample $sample_index does not contain a stable context plus trigger word." >&2
      exit 1
    fi
    if ((${#trigger_word} < 1)); then
      echo "TextEdit model latency sample $sample_index trigger word must contain at least one character." >&2
      exit 1
    fi
    attempt_had_model=0
    attempt_had_visible=0
    attempt_had_event_tap=0
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
      assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "TextEdit model latency seed $sample_index attempt $attempt"
      clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency reset $sample_index attempt $attempt"
      move_textedit_caret_to_document_end "$textedit_window_title"
      seed_start="$(line_count "$LOG_PATH")"
      if ! insert_textedit_smoke_fragment "$textedit_window_title" "$stable_context"; then
        echo "TextEdit model latency sample $sample_index attempt $attempt could not seed the stable AX context." >&2
        exit 1
      fi
      wait_for_textedit_document_exact "$textedit_window_title" "$stable_context" "TextEdit model latency stable context $sample_index attempt $attempt" 5
      move_textedit_caret_to_document_end "$textedit_window_title"
      if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION:-}" =~ ^(1|true|yes|on)$ ]]; then
        if wait_for_log_fields_optional "$seed_start" 8 \
          "phrase-continuation-disabled" \
          "app=com.apple.TextEdit"; then
          echo "TextEdit model latency seed settled by disabled phrase continuation $sample_index attempt $attempt."
        else
          describe_textedit_model_latency_seed_miss "$seed_start" "$textedit_window_title" "$sample_index" "$stable_context"
        fi
      elif wait_for_log_fields_optional "$seed_start" 4 \
        "mlx-completion-timing" \
        "app=com.apple.TextEdit" \
        "mode=phraseContinuation"; then
        echo "TextEdit model latency seed settled $sample_index attempt $attempt."
      else
        echo "TextEdit model latency seed produced no model timing before sample $sample_index attempt $attempt."
      fi
      move_textedit_caret_to_document_end "$textedit_window_title"
      sleep "${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_SEED_SETTLE_SECONDS:-0.6}"

      assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "TextEdit model latency trigger $sample_index attempt $attempt"
      sample_start="$(line_count "$LOG_PATH")"
      AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0 \
      AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_KEY_DELAY_SECONDS="${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_KEY_DELAY_SECONDS:-0.03}" \
        type_textedit_smoke_fragment "$textedit_window_title" "$trigger_text"
      wait_for_textedit_document_prefix "$textedit_window_title" "$expected_text" "TextEdit model latency sample $sample_index attempt $attempt" 5
      trim_textedit_native_completion_suffix "$textedit_window_title" "$expected_text" "TextEdit model latency sample $sample_index attempt $attempt"
      if wait_for_log_fields_optional "$sample_start" 20 \
        "mlx-completion-timing" \
        "app=com.apple.TextEdit"; then
        attempt_had_model=1
      else
        echo "TextEdit model latency sample $sample_index attempt $attempt produced no model timing; retrying this stable context if attempts remain." >&2
        sleep 0.4
        continue
      fi
      if wait_for_log_fields_optional "$sample_start" 20 \
        "suggestion-presented" \
        "app=com.apple.TextEdit" \
        "candidateSelectionSource=app-model-result"; then
        attempt_had_visible=1
        if ((event_tap_started == 0)); then
          wait_for_log_fields "$runtime_start_line" "TextEdit model latency event tap startup" 10 \
            "keyboard-event-tap-started"
          event_tap_started=1
        fi
        assert_textedit_frontmost_window "$textedit_window_title" "TextEdit model latency event-tap proof"
        if wait_for_log_fields_optional "$sample_start" 2 \
          "keyboard-event-tap-started"; then
          sleep "${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_EVENT_TAP_SETTLE_SECONDS:-0.25}"
        fi
        event_tap_start="$(line_count "$LOG_PATH")"
        if ! press_textedit_event_tap_probe_key; then
          echo "TextEdit model latency sample $sample_index attempt $attempt could not type the event-tap Tab probe; retrying this stable context if attempts remain." >&2
          sleep 0.4
          continue
        fi
        if ! wait_for_log_fields_optional "$event_tap_start" 5 \
          "keyboard-event-tap-latency" \
          "key=tab" \
          "decision=consume"; then
          echo "TextEdit model latency sample $sample_index attempt $attempt missed the event-tap Tab consume proof; retrying this stable context if attempts remain." >&2
          sleep 0.4
          continue
        fi
        attempt_had_event_tap=1
        event_tap_sample_count=$((event_tap_sample_count + 1))
        model_sample_count=$((model_sample_count + 1))
        visible_sample_count=$((visible_sample_count + 1))
        break
      else
        echo "TextEdit model latency sample $sample_index attempt $attempt produced no visible model-backed word completion; retrying this stable context if attempts remain." >&2
      fi
      sleep 0.4
    done
    if ((attempt_had_model == 1 && attempt_had_visible == 0)); then
      echo "TextEdit model latency sample $sample_index exhausted $max_attempts attempts with model timing but no visible model-backed word completion." >&2
    fi
    if ((attempt_had_visible == 1 && attempt_had_event_tap == 0)); then
      echo "TextEdit model latency sample $sample_index exhausted $max_attempts attempts with visible model-backed word completion but no event-tap Tab consume proof." >&2
    fi
    if ((visible_sample_count >= 5 && model_sample_count >= 5)); then
      break
    fi
    sleep 0.4
  done < <(textedit_model_latency_fragments)

  if ((visible_sample_count < 5 || model_sample_count < 5)); then
    echo "TextEdit model latency proof expected at least 5 visible model-backed word-completion samples, got $visible_sample_count visible and $model_sample_count model timings from $sample_index attempted contexts." >&2
    exit 1
  fi

  AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/latency_benchmark_report.py --beta-gate \
      --require-event-tap-samples "$event_tap_sample_count"
}

run_textedit_default_model_latency() {
  local runtime_start_line start_line textedit_file textedit_tmp_dir textedit_window_title trace_start_line proof_runtime_guard_line
  runtime_start_line="$(line_count "$LOG_PATH")"
  export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1

  prepare_temporary_app_enablement
  prepare_default_model_latency_runtime_options
  if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION:-}" != "1" ]]; then
    echo "TextEdit default model latency requires AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION=1." >&2
    exit 1
  fi
  build_if_needed
  wait_for_accessibility_ready "$runtime_start_line" "TextEdit default model latency Accessibility readiness" 20 "$SKIP_BUILD"
  wait_for_runtime_ready "$runtime_start_line" "TextEdit default model latency runtime readiness" "$(textedit_model_latency_runtime_ready_timeout_seconds)" "$SKIP_BUILD"
  proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"

  textedit_tmp_dir="$(make_tmp_dir)"
  textedit_file="$textedit_tmp_dir/textedit-default-model-latency-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  textedit_window_title="$(basename "$textedit_file")"
  SMOKE_TEXTEDIT_WINDOW_TITLES+=("$textedit_window_title")
  : >"$textedit_file"
  cleanup_stale_textedit_smoke_windows
  open_textedit_smoke_document "$textedit_file" "$textedit_window_title"
  sleep 0.8
  wait_for_textedit_smoke_editor "$textedit_window_title"
  focus_textedit_smoke_editor "$textedit_window_title"
  click_textedit_smoke_editor "$textedit_window_title"
  clear_textedit_document_for_proof "$textedit_window_title" "TextEdit default model latency initial reset"
  move_textedit_caret_to_document_end "$textedit_window_title"

  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"

  local sample_index=0 visible_sample_count=0 fragment sample_start expected_text
  while IFS= read -r fragment; do
    [[ -z "$fragment" ]] && continue
    sample_index=$((sample_index + 1))
    expected_text="${fragment} "

    assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "TextEdit default model latency seed $sample_index"
    clear_textedit_document_for_proof "$textedit_window_title" "TextEdit default model latency reset $sample_index"
    move_textedit_caret_to_document_end "$textedit_window_title"
    if ! insert_textedit_smoke_fragment "$textedit_window_title" "$fragment"; then
      echo "TextEdit default model latency sample $sample_index could not seed the stable AX context." >&2
      exit 1
    fi
    wait_for_textedit_document_exact "$textedit_window_title" "$fragment" "TextEdit default model latency stable context $sample_index" 5
    move_textedit_caret_to_document_end "$textedit_window_title"

    assert_no_runtime_relaunch_since "$proof_runtime_guard_line" "TextEdit default model latency trigger $sample_index"
    sample_start="$(line_count "$LOG_PATH")"
    AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0 \
    AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_KEY_DELAY_SECONDS="${AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_KEY_DELAY_SECONDS:-0}" \
      type_textedit_smoke_fragment "$textedit_window_title" " "
    wait_for_textedit_document_exact "$textedit_window_title" "$expected_text" "TextEdit default model latency sample $sample_index" 5
    wait_for_log_fields "$sample_start" "TextEdit default model latency timing $sample_index" 25 \
      "mlx-completion-timing" \
      "app=com.apple.TextEdit" \
      "mode=phraseContinuation" \
      "maxTokens=14"
    if wait_for_log_fields_optional "$sample_start" 8 \
      "suggestion-presented" \
      "app=com.apple.TextEdit" \
      "requestMode=phraseContinuation" \
      "candidateSelectionSource=app-model-result"; then
      visible_sample_count=$((visible_sample_count + 1))
    elif wait_for_log_fields_optional "$sample_start" 1 \
      "suggestion-blocked" \
      "app=com.apple.TextEdit" \
      "reason=empty-suggestion"; then
      echo "TextEdit default model latency sample $sample_index produced an empty phrase candidate; trying the next stable context." >&2
    else
      wait_for_log_fields "$sample_start" "TextEdit default model latency visible or empty $sample_index" 1 \
        "suggestion-presented" \
        "app=com.apple.TextEdit" \
        "requestMode=phraseContinuation" \
        "candidateSelectionSource=app-model-result"
    fi
    sleep 0.4
  done < <(textedit_default_model_latency_fragments)

  if ((visible_sample_count < 5)); then
    echo "TextEdit default model latency proof expected at least 5 visible phrase samples, got $visible_sample_count from $sample_index attempted contexts." >&2
    exit 1
  fi

  AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
    ./script/model_latency_report.py --default-model-proof
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
  local second_fragments=()
  if [[ "$fixture" == "codemirror-official" ]]; then
    first_fragment="Smoke proof feels dicta"
    second_fragment=" and stays dicta"
  fi
  second_fragments=("$second_fragment")
  if [[ "$fixture" == "textarea" ]]; then
    second_fragments=(
      "$second_fragment"
      " while the textarea keeps inst"
      " and the browser proof stays inst"
    )
  fi
  if [[ "$fixture" == "contenteditable" ]]; then
    second_fragments=(
      "$second_fragment"
      " while the editor keeps inst"
      " and the rich text field feels inst"
    )
  fi

  pause_steadytype_for_chrome_setup
  type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "first fragment" "$first_fragment"
  start_line="$(line_count "$LOG_PATH")"
  trace_start_line="$(line_count "$TRACE_PATH")"
  launch_steadytype_after_chrome_setup "$fixture" "$start_line" "$chrome_pid" "$chrome_url"
  focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"

  wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture suggestion"
  wait_for_screenshot_capture_if_enabled "$start_line" "com.google.Chrome" "Chrome $fixture"
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  local before_one_word_accept_text
  before_one_word_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
  if [[ -n "$chrome_pid" ]]; then
    wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture before Tab accept"
  else
    wait_for_frontmost_app "Google Chrome" 5
  fi
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

  if [[ "$CHROME_MODEL_LATENCY" == "1" ]]; then
    local latency_fragment latency_index latency_start_line
    local latency_fragments=(
      " and the browser proof stays inst"
      " while the local model stays inst"
      " and the textarea keeps feeling inst"
      " and the final browser sample stays inst"
    )
    latency_index=0
    for latency_fragment in "${latency_fragments[@]}"; do
      latency_index=$((latency_index + 1))
      focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"
      if [[ -n "$chrome_pid" ]]; then
        assert_frontmost_process_id "$chrome_pid" "Chrome $fixture model latency $latency_index"
      else
        assert_frontmost_app "Google Chrome" "Chrome $fixture model latency $latency_index"
      fi
      latency_start_line="$(line_count "$LOG_PATH")"
      type_chrome_smoke_text_with_system_events "$latency_fragment"
      wait_for_chrome_focused_text_contains "$fixture" "$chrome_pid" "$latency_fragment" "Chrome $fixture model latency fragment $latency_index" 8
      wait_for_log_fields "$latency_start_line" "Chrome $fixture model latency suggestion $latency_index" 20 \
        "suggestion-presented" \
        "app=com.google.Chrome" \
        "candidateSelectionSource=app-model-result"
    done

    echo "Chrome $fixture model latency proof collected model-backed visible samples in one launch."
    return 0
  fi

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

  local second_attempt=0 second_suggestion_found=0
  for second_fragment in "${second_fragments[@]}"; do
    second_attempt=$((second_attempt + 1))
    if [[ -z "$chrome_pid" ]]; then
      focus_chrome_smoke_editor "$fixture" "" "$chrome_url"
    fi
    pause_steadytype_for_chrome_setup
    type_chrome_smoke_text "$fixture" "$chrome_pid" "$chrome_url" "second fragment $second_attempt" "$second_fragment"
    second_start_line="$(line_count "$LOG_PATH")"
    launch_steadytype_after_chrome_setup "$fixture" "$second_start_line" "$chrome_pid" "$chrome_url"
    focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"

    if wait_for_log_fields_optional "$second_start_line" 14 \
      "suggestion-presented" \
      "app=com.google.Chrome"; then
      second_suggestion_found=1
      break
    fi
    if wait_for_log_fields_optional "$second_start_line" 1 \
      "suggestion-blocked" \
      "app=com.google.Chrome" \
      "reason=empty-suggestion"; then
      echo "Chrome $fixture second suggestion attempt $second_attempt returned empty; retrying with another disposable fragment." >&2
      continue
    fi
    if wait_for_log_fields_optional "$second_start_line" 1 \
      "suggestion-blocked" \
      "app=com.google.Chrome" \
      "reason=too-slow-to-display"; then
      echo "Chrome $fixture second suggestion attempt $second_attempt was too slow to display; retrying with another disposable fragment." >&2
      continue
    fi
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture second suggestion" 1
  done
  if ((second_suggestion_found == 0)); then
    echo "Chrome $fixture second suggestion exhausted ${#second_fragments[@]} disposable fragments." >&2
    wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=com.google.Chrome" "Chrome $fixture second suggestion" 1
  fi
  wait_for_screenshot_capture_if_enabled "$second_start_line" "com.google.Chrome" "Chrome $fixture second"
  if [[ -n "$chrome_pid" ]]; then
    assert_frontmost_process_id "$chrome_pid" "Chrome $fixture"
  else
    assert_frontmost_app "Google Chrome" "Chrome $fixture"
  fi
  local before_full_accept_text
  before_full_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"
  if [[ -n "$chrome_pid" ]]; then
    wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture before full accept"
  else
    wait_for_frontmost_app "Google Chrome" 5
  fi
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
  if [[ "$CHROME_MODEL_LATENCY" == "1" ]]; then
    prepare_chrome_model_latency_runtime_options
  fi
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

smoke_startup_marker "before-describe-plan"
describe_plan
smoke_startup_marker "after-describe-plan"

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

if [[ "$APP" == "chrome" ]] && chrome_fixture_is_blocked_high_value_surface "$CHROME_FIXTURE"; then
  echo "Blocked Chrome fixture: $CHROME_FIXTURE" >&2
  chrome_blocked_high_value_surface_reason "$CHROME_FIXTURE" >&2
  echo "No Chrome typing was attempted." >&2
  exit 1
fi

smoke_startup_marker "before-exclusive-cleanup"
terminate_foreign_proof_processes_for_exclusive_run
smoke_startup_marker "after-exclusive-cleanup"
start_foreign_worktree_quarantine_guard
smoke_startup_marker "after-quarantine-guard"
refuse_other_smoke_processes
smoke_startup_marker "after-refuse-other-smoke"
acquire_smoke_lock
smoke_startup_marker "after-smoke-lock"
start_smoke_interference_guard
smoke_startup_marker "after-interference-guard"

case "$APP" in
  textedit)
    run_textedit
    ;;
  chrome)
    run_chrome
    ;;
  codex)
    if [[ "$CODEX_MODEL_LATENCY" == "1" ]]; then
      run_codex_model_latency
    elif [[ "$CODEX_FULL_ACCEPT_PROOF" == "1" ]]; then
      run_codex_full_accept
    else
      run_codex
    fi
    ;;
  notes)
    run_notes
    ;;
  obsidian)
    run_obsidian
    ;;
  claude-code)
    if [[ "$CLAUDE_CODE_MODEL_LATENCY" == "1" ]]; then
      run_claude_code_model_latency
    else
      run_claude_code_terminal_host_smoke
    fi
    ;;
  claude)
    if [[ "$CLAUDE_MODEL_LATENCY" == "1" ]]; then
      run_claude_model_latency
    else
      run_manual_gated
    fi
    ;;
esac
