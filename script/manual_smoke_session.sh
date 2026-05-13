#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

MODE="run"
NOTES_SURFACE=""
NOTES_PROOF_LABEL=""
TEXTEDIT_VARIANT=""
OBSIDIAN_VARIANT=""
REQUIRES_UNDO_ACCEPT=0
TEXTEDIT_SELECTED_SUPPRESSION_PROOF=0
TEXTEDIT_FAST_TYPING_PROOF=0
STRICT_VISUAL_EVIDENCE="${AUTOCOMPLETE_LAB_SMOKE_REQUIRE_VISUAL_EVIDENCE:-${AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE:-0}}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}"
REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
PROOF_LABEL="${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-default}"
ACCEPT_ALL_SHORTCUT="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-backtick}"
CODEX_PROOF_MARKER="${AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER:-AUTOCOMPLETE_LAB_CODEX_PROOF}"
CLAUDE_CODE_PROOF_MARKER="${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER:-AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF}"
CLAUDE_CODE_HOST_VARIANT="${AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT:-auto}"

usage() {
  cat <<'EOF'
Usage: script/manual_smoke_session.sh <textedit|textedit-light|textedit-dark|textedit-long-wrap|textedit-wrapped|textedit-narrow|textedit-scrolled|textedit-selected-suppression|textedit-undo-one-word|textedit-undo-full|textedit-fast-typing|notes|notes-title|notes-title-short|notes-title-long|notes-body|notes-body-short|notes-body-long|notes-checklist|notes-checklist-checked|notes-checklist-long|notes-title-undo|notes-body-undo|notes-checklist-undo|obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on|chrome|codex|claude-code|claude> [--print|--check] [--visual]

Default mode prints the local manual steps, records the current diagnostics log
line, waits for Enter, validates the new diagnostics for that app, then appends
a pass row to docs/product/manual-smoke-runs.md.

Notes proof must be recorded as notes-title, notes-body, notes-checklist,
their notes-*-undo variants, or explicit Notes variant lanes.
Obsidian proof must keep default, theme, pane, long-note, font-zoom,
markdown-bold, markdown-list, multiline, and run-on variants separate before
the app can graduate past partial proof.
Use --visual when the trace slice must include strict screenshot evidence.

Set AUTOCOMPLETE_LAB_LOG_START_LINE when using --check against a known log slice.
Set AUTOCOMPLETE_LAB_TRACE_START_LINE to validate a matching trace slice.
Set AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL to claude-empty, claude-long,
claude-wrapped, claude-narrow, claude-context, claude-light, or claude-dark
when recording Claude desktop layout variants.
EOF
}

if [[ -z "$APP" || "$APP" == "-h" || "$APP" == "--help" ]]; then
  usage
  exit 0
fi

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
    ;;
  textedit-undo-full)
    APP="textedit"
    TEXTEDIT_VARIANT="undo-full"
    ;;
  textedit-fast-typing)
    APP="textedit"
    TEXTEDIT_VARIANT="fast-typing"
    ;;
  notes-title)
    APP="notes"
    NOTES_SURFACE="title"
    ;;
  notes-title-short)
    APP="notes"
    NOTES_SURFACE="title"
    NOTES_PROOF_LABEL="notes-title-short"
    ;;
  notes-title-long)
    APP="notes"
    NOTES_SURFACE="title"
    NOTES_PROOF_LABEL="notes-title-long"
    ;;
  notes-title-undo)
    APP="notes"
    NOTES_SURFACE="title"
    REQUIRES_UNDO_ACCEPT=1
    ;;
  notes-body)
    APP="notes"
    NOTES_SURFACE="body"
    ;;
  notes-body-short)
    APP="notes"
    NOTES_SURFACE="body"
    NOTES_PROOF_LABEL="notes-body-short"
    ;;
  notes-body-long)
    APP="notes"
    NOTES_SURFACE="body"
    NOTES_PROOF_LABEL="notes-body-long"
    ;;
  notes-body-undo)
    APP="notes"
    NOTES_SURFACE="body"
    REQUIRES_UNDO_ACCEPT=1
    ;;
  notes-checklist)
    APP="notes"
    NOTES_SURFACE="checklist"
    ;;
  notes-checklist-checked)
    APP="notes"
    NOTES_SURFACE="checklist"
    NOTES_PROOF_LABEL="notes-checklist-checked"
    ;;
  notes-checklist-long)
    APP="notes"
    NOTES_SURFACE="checklist"
    NOTES_PROOF_LABEL="notes-checklist-long"
    ;;
  notes-checklist-undo)
    APP="notes"
    NOTES_SURFACE="checklist"
    REQUIRES_UNDO_ACCEPT=1
    ;;
  obsidian-theme)
    APP="obsidian"
    OBSIDIAN_VARIANT="theme"
    ;;
  obsidian-pane)
    APP="obsidian"
    OBSIDIAN_VARIANT="pane"
    ;;
  obsidian-long-note)
    APP="obsidian"
    OBSIDIAN_VARIANT="long-note"
    ;;
  obsidian-font-zoom)
    APP="obsidian"
    OBSIDIAN_VARIANT="font-zoom"
    ;;
  obsidian-markdown-bold)
    APP="obsidian"
    OBSIDIAN_VARIANT="markdown-bold"
    ;;
  obsidian-markdown-list)
    APP="obsidian"
    OBSIDIAN_VARIANT="markdown-list"
    ;;
  obsidian-multiline)
    APP="obsidian"
    OBSIDIAN_VARIANT="multiline"
    ;;
  obsidian-run-on)
    APP="obsidian"
    OBSIDIAN_VARIANT="run-on"
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print | --check)
      MODE="$1"
      ;;
    --visual | --require-visual-evidence)
      STRICT_VISUAL_EVIDENCE=1
      ;;
    --no-visual)
      STRICT_VISUAL_EVIDENCE=0
      ;;
    --surface)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--surface needs title, body, or checklist" >&2
        exit 2
      fi
      NOTES_SURFACE="$1"
      ;;
    --surface=*)
      NOTES_SURFACE="${1#--surface=}"
      ;;
    --variant)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--variant needs default, theme, pane, long-note, font-zoom, markdown-bold, markdown-list, multiline, or run-on" >&2
        exit 2
      fi
      OBSIDIAN_VARIANT="$1"
      ;;
    --variant=*)
      OBSIDIAN_VARIANT="${1#--variant=}"
      ;;
    title | body | checklist)
      NOTES_SURFACE="$1"
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | ON)
      return 0
      ;;
    *)
      return 1
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
    *)
      echo "unknown Claude Code terminal host: $CLAUDE_CODE_HOST_VARIANT" >&2
      exit 2
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

if is_truthy "${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-0}"; then
  STRICT_VISUAL_EVIDENCE=1
fi

if is_truthy "$STRICT_VISUAL_EVIDENCE"; then
  STRICT_VISUAL_EVIDENCE=1
else
  STRICT_VISUAL_EVIDENCE=0
fi

case "$ACCEPT_ALL_SHORTCUT" in
  backtick|optionTab)
    ;;
  *)
    echo "unknown accept-all shortcut: $ACCEPT_ALL_SHORTCUT" >&2
    echo "expected backtick or optionTab" >&2
    exit 2
    ;;
esac

BUNDLE_ID=""
DISPLAY_NAME=""
SESSION_NAME=""
REPORT_APP_NAME=""
EXPECTED_RENDER=""
REQUIRES_FULL_ACCEPT=1
PROMPT_NO_SUBMIT_PROFILE=0
MIN_VERIFIED_ACCEPTS=2
STEPS=""

case "$APP" in
  textedit)
    BUNDLE_ID="com.apple.TextEdit"
    DISPLAY_NAME="TextEdit"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    case "$TEXTEDIT_VARIANT" in
      "")
        STEPS=$'- Open a disposable TextEdit document.\n- Type `Smoke proof feels inst`.\n- Wait for a suggestion.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      light)
        PROOF_LABEL="textedit-light"
        SESSION_NAME="TextEdit light"
        STEPS=$'- Open a disposable TextEdit document while the system appearance is light.\n- Type `Smoke proof feels inst`.\n- Wait for a suggestion.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      dark)
        PROOF_LABEL="textedit-dark"
        SESSION_NAME="TextEdit dark"
        STEPS=$'- Open a disposable TextEdit document while the system appearance is dark.\n- Type `Smoke proof feels inst`.\n- Wait for a suggestion.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      long-wrap)
        PROOF_LABEL="textedit-long-wrap"
        SESSION_NAME="TextEdit long wrapped line"
        STEPS=$'- Open a disposable narrow TextEdit document.\n- Type a long wrapped line ending in `inst`.\n- Wait for a suggestion on the wrapped line.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      narrow)
        PROOF_LABEL="textedit-narrow"
        SESSION_NAME="TextEdit narrow window"
        STEPS=$'- Open a disposable narrow TextEdit document.\n- Type `Smoke proof feels inst`.\n- Wait for a suggestion.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      scrolled)
        PROOF_LABEL="textedit-scrolled"
        SESSION_NAME="TextEdit scrolled document"
        STEPS=$'- Open a disposable narrow TextEdit document prefilled with enough lines to scroll.\n- Move the caret to the bottom and type `Smoke proof feels inst`.\n- Wait for a suggestion at the scrolled caret.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      selected-suppression)
        PROOF_LABEL="textedit-selected-suppression"
        SESSION_NAME="TextEdit selected-text suppression"
        EXPECTED_RENDER="selected-text-suppressed"
        REQUIRES_FULL_ACCEPT=0
        MIN_VERIFIED_ACCEPTS=0
        TEXTEDIT_SELECTED_SUPPRESSION_PROOF=1
        STEPS=$'- Open a disposable TextEdit document.\n- Type disposable text.\n- Select part of the text.\n- Confirm SteadyType suppresses suggestions and records no insertion while text is selected.'
        ;;
      undo-one-word)
        PROOF_LABEL="textedit-undo-one-word"
        SESSION_NAME="TextEdit one-word undo"
        REQUIRES_UNDO_ACCEPT=1
        STEPS=$'- Open a disposable TextEdit document.\n- Type `Smoke proof feels inst`.\n- Press Tab once and expect `instant`.\n- Press Command-Z and confirm native TextEdit undo removes only the accepted suffix as one edit.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      undo-full)
        PROOF_LABEL="textedit-undo-full"
        SESSION_NAME="TextEdit full-accept undo"
        REQUIRES_UNDO_ACCEPT=1
        STEPS=$'- Open a disposable TextEdit document.\n- Type `Smoke proof feels inst`.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.\n- Press Command-Z and confirm the full accepted insertion is undone as one native edit unit.'
        ;;
      fast-typing)
        PROOF_LABEL="textedit-fast-typing"
        SESSION_NAME="TextEdit fast typing pass-through"
        EXPECTED_RENDER="typing-pass-through"
        REQUIRES_FULL_ACCEPT=0
        MIN_VERIFIED_ACCEPTS=0
        TEXTEDIT_FAST_TYPING_PROOF=1
        STEPS=$'- Run the disposable TextEdit typing soak.\n- Confirm typed text matches exactly.\n- Confirm key capture stays idle/clean during normal fast typing.'
        ;;
      *)
        echo "unknown TextEdit variant: $TEXTEDIT_VARIANT" >&2
        exit 2
        ;;
    esac
    ;;
  notes)
    BUNDLE_ID="com.apple.Notes"
    DISPLAY_NAME="Notes"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    case "$PROOF_LABEL" in
      notes-title)
        NOTES_SURFACE="${NOTES_SURFACE:-title}"
        ;;
      notes-title-undo)
        NOTES_SURFACE="${NOTES_SURFACE:-title}"
        REQUIRES_UNDO_ACCEPT=1
        ;;
      notes-body)
        NOTES_SURFACE="${NOTES_SURFACE:-body}"
        ;;
      notes-body-undo)
        NOTES_SURFACE="${NOTES_SURFACE:-body}"
        REQUIRES_UNDO_ACCEPT=1
        ;;
      notes-checklist)
        NOTES_SURFACE="${NOTES_SURFACE:-checklist}"
        ;;
      notes-checklist-undo)
        NOTES_SURFACE="${NOTES_SURFACE:-checklist}"
        REQUIRES_UNDO_ACCEPT=1
        ;;
    esac

    case "$NOTES_SURFACE" in
      "")
        PROOF_LABEL="choose-notes-surface"
        SESSION_NAME="Notes surface selector"
        STEPS=$'- Open the disposable autocomplete smoke note.\n- Record three separate Notes passes:\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate`\n- Record optional undo proof with:\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title-undo --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body-undo --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist-undo --manual-gate`\n- Title, body, checklist, and undo rows are separate proof. A generic Notes row does not count.'
        ;;
      title)
        if (( REQUIRES_UNDO_ACCEPT == 1 )); then
          PROOF_LABEL="notes-title-undo"
          SESSION_NAME="Notes title undo"
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Put the caret in the note title.\n- Type `Smoke proof feels` in the title only.\n- Press Tab once and expect ` instant`.\n- Press Command-Z and confirm only the accepted ` instant` insertion is removed.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        else
          PROOF_LABEL="${NOTES_PROOF_LABEL:-notes-title}"
          case "$PROOF_LABEL" in
            notes-title-short)
              SESSION_NAME="Notes title short"
              ;;
            notes-title-long)
              SESSION_NAME="Notes title long"
              ;;
            *)
              SESSION_NAME="Notes title"
              ;;
          esac
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Put the caret in the note title.\n- Type `Smoke proof feels` in the title only.\n- Press Tab once and expect ` instant`.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        fi
        ;;
      body)
        if (( REQUIRES_UNDO_ACCEPT == 1 )); then
          PROOF_LABEL="notes-body-undo"
          SESSION_NAME="Notes body undo"
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Put `Autocomplete smoke` on the first body line.\n- Put the caret on the next body line and type `Smoke proof feels`.\n- Press Tab once and expect ` instant`.\n- Press Command-Z and confirm only the accepted ` instant` insertion is removed.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        else
          PROOF_LABEL="${NOTES_PROOF_LABEL:-notes-body}"
          case "$PROOF_LABEL" in
            notes-body-short)
              SESSION_NAME="Notes body short"
              ;;
            notes-body-long)
              SESSION_NAME="Notes body long"
              ;;
            *)
              SESSION_NAME="Notes body"
              ;;
          esac
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Put `Autocomplete smoke` on the first body line.\n- Put the caret on the next body line and type `Smoke proof feels`.\n- Press Tab once and expect ` instant`.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        fi
        ;;
      checklist)
        if (( REQUIRES_UNDO_ACCEPT == 1 )); then
          PROOF_LABEL="notes-checklist-undo"
          SESSION_NAME="Notes checklist undo"
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Toggle Checklist and create a disposable checklist row.\n- Type `Smoke proof feels` in that checklist row.\n- Press Tab once and expect ` instant`.\n- Press Command-Z and confirm only the accepted ` instant` insertion is removed.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        else
          PROOF_LABEL="${NOTES_PROOF_LABEL:-notes-checklist}"
          case "$PROOF_LABEL" in
            notes-checklist-checked)
              SESSION_NAME="Notes checklist checked"
              ;;
            notes-checklist-long)
              SESSION_NAME="Notes checklist long"
              ;;
            *)
              SESSION_NAME="Notes checklist"
              ;;
          esac
          STEPS=$'- Open the disposable autocomplete smoke note.\n- Toggle Checklist and create a disposable checklist row.\n- Type `Smoke proof feels` in that checklist row.\n- Press Tab once and expect ` instant`.\n- Type ` and stays`.\n- Press the configured full-accept shortcut and expect another ` instant` prediction.\n- Use --visual when screenshot-backed placement must be proven.'
        fi
        ;;
      *)
        echo "unknown Notes surface: $NOTES_SURFACE" >&2
        echo "expected title, body, or checklist" >&2
        exit 2
        ;;
    esac
    ;;
  obsidian)
    BUNDLE_ID="md.obsidian"
    DISPLAY_NAME="Obsidian"
    EXPECTED_RENDER="floatingMirror"
    case "$PROOF_LABEL" in
      obsidian-theme)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-theme}"
        ;;
      obsidian-pane)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-pane}"
        ;;
      obsidian-long-note)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-long-note}"
        ;;
      obsidian-font-zoom)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-font-zoom}"
        ;;
      obsidian-markdown-bold)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-markdown-bold}"
        ;;
      obsidian-markdown-list)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-markdown-list}"
        ;;
      obsidian-multiline)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-multiline}"
        ;;
      obsidian-run-on)
        OBSIDIAN_VARIANT="${OBSIDIAN_VARIANT:-run-on}"
        ;;
    esac

    case "$OBSIDIAN_VARIANT" in
      ""|default)
        PROOF_LABEL="default"
        SESSION_NAME="Obsidian"
        STEPS=$'- Open a disposable Obsidian note in the proof vault.\n- Type a partial word like `dicta`.\n- If CodeMirror does not expose caret bounds, confirm no detached floating bubble appears.\n- If a real caret-bound suggestion appears, use Tab once, then the configured full-accept shortcut.'
        ;;
      theme)
        PROOF_LABEL="obsidian-theme"
        SESSION_NAME="Obsidian theme variant"
        STEPS=$'- Use a disposable proof vault with a non-default Obsidian theme enabled.\n- Open a disposable note in edit mode.\n- Type `Smoke proof feels inst` at a normal writing line.\n- Confirm the ghost is anchored beside the visible caret, not to the whole editor.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and expect another `instant` completion.'
        ;;
      pane|split|side-pane)
        OBSIDIAN_VARIANT="pane"
        PROOF_LABEL="obsidian-pane"
        SESSION_NAME="Obsidian pane variant"
        STEPS=$'- Use a disposable proof vault with at least two visible panes or a side pane.\n- Put the caret in the target note pane, not the sidebar/search pane.\n- Type `Smoke proof feels inst` in the target pane.\n- Confirm the ghost follows that pane caret and does not jump to another pane.\n- Press Tab once and expect `instant` in the same pane only.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion stays in the same pane.'
        ;;
      long-note|scroll|scrolled)
        OBSIDIAN_VARIANT="long-note"
        PROOF_LABEL="obsidian-long-note"
        SESSION_NAME="Obsidian long-note variant"
        STEPS=$'- Use a disposable proof vault with a note that visibly scrolls.\n- Scroll so the target writing line is not near the top of the note.\n- Put the caret on a visible scrolled line and type `Smoke proof feels inst`.\n- Confirm the ghost anchors to the visible scrolled caret, not the unscrolled editor origin.\n- Press Tab once and expect `instant` on that visible line.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion lands on the visible scrolled line.'
        ;;
      font-zoom|zoom|font)
        OBSIDIAN_VARIANT="font-zoom"
        PROOF_LABEL="obsidian-font-zoom"
        SESSION_NAME="Obsidian font/zoom variant"
        STEPS=$'- Use the disposable proof vault.\n- Increase Obsidian editor zoom before typing.\n- Type `Smoke proof feels inst` at the zoomed caret.\n- Confirm the ghost tracks the larger visible text/caret.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion remains correct, then reset zoom.'
        ;;
      markdown-bold|bold)
        OBSIDIAN_VARIANT="markdown-bold"
        PROOF_LABEL="obsidian-markdown-bold"
        SESSION_NAME="Obsidian Markdown bold variant"
        STEPS=$'- Use the disposable proof vault.\n- Start after a Markdown bold prefix.\n- Type `Smoke proof feels inst` in that bold Markdown context.\n- Confirm the ghost tracks the visible caret.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion stays in the bold line.'
        ;;
      markdown-list|list|dash)
        OBSIDIAN_VARIANT="markdown-list"
        PROOF_LABEL="obsidian-markdown-list"
        SESSION_NAME="Obsidian Markdown list variant"
        STEPS=$'- Use the disposable proof vault.\n- Start from a dash-list Markdown context after a bold setup line.\n- Type `Smoke proof feels inst` in the list row.\n- Confirm the ghost tracks the list-row caret.\n- Press Tab once and expect `instant` without turning into indentation.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion stays in the same list row.'
        ;;
      multiline|blank-lines)
        OBSIDIAN_VARIANT="multiline"
        PROOF_LABEL="obsidian-multiline"
        SESSION_NAME="Obsidian multiline variant"
        STEPS=$'- Use the disposable proof vault.\n- Place the proof line several blank lines below the marker.\n- Type `Smoke proof feels inst` after the blank-line gap.\n- Confirm the ghost tracks the lower visible caret.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion stays on the intended line.'
        ;;
      run-on|runon|wrapped)
        OBSIDIAN_VARIANT="run-on"
        PROOF_LABEL="obsidian-run-on"
        SESSION_NAME="Obsidian run-on sentence variant"
        STEPS=$'- Use the disposable proof vault.\n- Start after a long wrapping sentence.\n- Type `Smoke proof feels inst` at the wrapped-line tail.\n- Confirm the ghost tracks the wrapped caret instead of the editor origin.\n- Press Tab once and expect `instant`.\n- Type ` and stays inst`.\n- Press the configured full-accept shortcut and confirm insertion remains correct.'
        ;;
      *)
        echo "unknown Obsidian variant: $OBSIDIAN_VARIANT" >&2
        echo "expected default, theme, pane, long-note, font-zoom, markdown-bold, markdown-list, multiline, or run-on" >&2
        exit 2
        ;;
    esac
    ;;
  chrome)
    BUNDLE_ID="com.google.Chrome"
    DISPLAY_NAME="Chrome"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    PROOF_LABEL="${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-${AUTOCOMPLETE_LAB_CHROME_FIXTURE:-$PROOF_LABEL}}"
    STEPS=$'- Open a local fixture page with a textarea, contenteditable field, editor-like field, Monaco-like editor, ProseMirror-like editor, real Monaco editor, real ProseMirror editor, public text-field demo, official public editor demo, or chat-style composer.\n- Type `Smoke proof feels inst` in the focused field. The `codemirror-official` lane uses `Smoke proof feels dicta` to avoid CodeMirror built-in JavaScript keyword completion.\n- Confirm focus stays in the field.\n- Use Tab once and expect a one-word/suffix accept.\n- Type ` and stays inst`. The `codemirror-official` lane uses ` and stays dicta`.\n- Press the configured full-accept shortcut and expect another completion.\n- Forced Chrome proof uses an isolated temp-profile Chrome with renderer accessibility enabled for local fixtures.\n- For default Chrome AX exposure proof, add `--chrome-accessibility default` and keep that proof label distinct.\n- For public text-field proof, use `textarea-public`, `contenteditable-public`, or `production-text-fields` and keep those proof labels distinct from local fixtures.\n- For public official editor demo proof, use `codemirror-official`, `monaco-official`, or `prosemirror-official` and keep those proof labels distinct from local fixtures.\n- For chat-like proof, prefer `script/real_app_smoke.sh chrome --fixture chat-like` so the no-submit guard is checked.'
    if [[ "$PROOF_LABEL" == "browser-chat-harness" ]]; then
      SESSION_NAME="Chrome browser-chat no-submit harness"
      REQUIRES_FULL_ACCEPT=0
      PROMPT_NO_SUBMIT_PROFILE=1
      MIN_VERIFIED_ACCEPTS=1
      STEPS=$'- Open the bounded HTTP browser-chat harness through `script/real_browser_chat_proof.sh`.\n- Type only disposable text.\n- Use Tab once and expect `instant`.\n- Confirm the harness counters stay at zero for submit, send-key collision, prompt mutation, and wrong-context insertion.\n- Do not press Enter. Full accept is intentionally not part of this proof.'
    fi
    ;;
  codex)
    BUNDLE_ID="com.openai.codex"
    DISPLAY_NAME="Codex"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    PROMPT_NO_SUBMIT_PROFILE=1
    MIN_VERIFIED_ACCEPTS=1
    STEPS="- Focus the Codex message box without submitting.
- Type only disposable prompt text that includes \`$CODEX_PROOF_MARKER\`, then a harmless local fragment like \`Can we make this\`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Use Tab once for one word/suffix.
- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.
- Do not press Enter as part of the smoke pass.
- Full visible accept stays disabled until separate full-accept no-submit proof exists."
    ;;
  claude-code)
    BUNDLE_ID="com.anthropic.claude-code"
    DISPLAY_NAME="Claude Code"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    PROMPT_NO_SUBMIT_PROFILE=1
    MIN_VERIFIED_ACCEPTS=1
    if [[ "$PROOF_LABEL" == "default" && "$CLAUDE_CODE_HOST_VARIANT" != "auto" ]]; then
      PROOF_LABEL="$(claude_code_host_proof_label)"
    fi
    STEPS="- In a supported terminal host, focus only a disposable Claude Code prompt without submitting.
- Host variant: \`$(claude_code_host_display_name)\` / \`$(claude_code_host_bundle_id)\`.
- Include \`$CLAUDE_CODE_PROOF_MARKER\` in the prompt or terminal title.
- Type a harmless local test fragment like \`Can we make this\`.
- Confirm a suggestion appears near the prompt or in a stable mirror position.
- Use Tab once for one word/suffix.
- Visually confirm the text stayed in the composer, no user message bubble appeared, no shell input executed, and no assistant response started.
- Do not press Enter as part of the smoke pass.
- Full visible accept stays disabled until separate full-accept no-submit proof exists."
    ;;
  claude)
    BUNDLE_ID="com.anthropic.claudefordesktop"
    DISPLAY_NAME="Claude"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    PROMPT_NO_SUBMIT_PROFILE=1
    MIN_VERIFIED_ACCEPTS=1
    case "$PROOF_LABEL" in
      default)
        SESSION_NAME="Claude default composer"
        STEPS=$'- Focus a normal Claude prompt without submitting.\n- Type a harmless local test fragment like `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-empty)
        SESSION_NAME="Claude empty composer"
        STEPS=$'- Start from a new or cleared Claude composer with no prompt text submitted.\n- Type only harmless local proof text, ending with `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-long)
        SESSION_NAME="Claude long prompt"
        STEPS=$'- Focus Claude with a long disposable prompt already in the composer, without submitting it.\n- Put the caret at the end of the long prompt and end with `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-wrapped)
        SESSION_NAME="Claude wrapped prompt"
        STEPS=$'- Focus Claude with disposable prompt text that wraps onto a second visual line, without submitting it.\n- Put the caret on the wrapped line and end with `Can we make this`.\n- Confirm a suggestion appears on the same visual baseline or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-narrow)
        SESSION_NAME="Claude narrow window"
        STEPS=$'- Resize the Claude window narrow enough to stress composer wrapping, using only disposable prompt text.\n- Focus the composer and end the text with `Can we make this`.\n- Confirm a suggestion appears on the same visual baseline or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-context)
        SESSION_NAME="Claude context layout"
        STEPS=$'- Open a safe Claude project, context, or side-panel layout if one is available; otherwise skip this proof label and keep it pending.\n- Focus the composer with only disposable prompt text ending in `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-light)
        SESSION_NAME="Claude light appearance"
        STEPS=$'- Put Claude in a light appearance only if that can be done without disrupting private work.\n- Focus the composer with only disposable prompt text ending in `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position with readable contrast.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-dark)
        SESSION_NAME="Claude dark appearance"
        STEPS=$'- Put Claude in a dark appearance only if that can be done without disrupting private work.\n- Focus the composer with only disposable prompt text ending in `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position with readable contrast.\n- Use Tab once for one word/suffix.\n- Visually confirm the text stayed in the composer, no user message bubble appeared, and no assistant response started.\n- Do not press Enter as part of the smoke pass.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
        ;;
      claude-full-accept)
        echo "Claude full-accept proof is blocked: the production profile disables full accept until a separate safe no-submit proof lane exists." >&2
        exit 2
        ;;
      *)
        echo "unknown Claude proof label: $PROOF_LABEL" >&2
        echo "expected default, claude-empty, claude-long, claude-wrapped, claude-narrow, claude-context, claude-light, or claude-dark" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

SESSION_NAME="${SESSION_NAME:-$DISPLAY_NAME}"
REPORT_APP_NAME="${REPORT_APP_NAME:-$DISPLAY_NAME}"

if [[ "$APP" == "notes" && -z "$NOTES_SURFACE" && "$MODE" != "--print" ]]; then
  echo "Notes proof cannot be recorded as a generic Notes pass." >&2
  echo "Choose one surface: notes-title, notes-body, notes-checklist, or a notes-*-undo variant." >&2
  echo "Example: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate" >&2
  exit 2
fi

if [[ "$APP" != "obsidian" && -n "$OBSIDIAN_VARIANT" ]]; then
  echo "--variant is only supported for Obsidian proof" >&2
  exit 2
fi

echo "Manual smoke: $SESSION_NAME"
echo "Bundle: $BUNDLE_ID"
echo "Proof: $PROOF_LABEL"
if [[ "$APP" == "notes" ]]; then
  if [[ -n "$NOTES_SURFACE" ]]; then
    echo "Notes surface: $NOTES_SURFACE"
  else
    echo "Notes surface: choose title, body, or checklist"
  fi
fi
if [[ "$APP" == "claude-code" ]]; then
  echo "Claude Code host: $(claude_code_host_display_name) ($(claude_code_host_bundle_id))"
fi
if [[ "$APP" == "textedit" && -n "$TEXTEDIT_VARIANT" ]]; then
  echo "TextEdit variant: $TEXTEDIT_VARIANT"
fi
if [[ "$APP" == "obsidian" ]]; then
  echo "Obsidian variant: ${OBSIDIAN_VARIANT:-default}"
fi
if (( STRICT_VISUAL_EVIDENCE == 1 )); then
  echo "Visual trace: strict screenshot evidence required"
else
  echo "Visual trace: insertion proof only; screenshot evidence not claimed"
fi
echo
echo "$STEPS"
echo
echo "Diagnostics log: $LOG_PATH"
echo "Trace log: $TRACE_PATH"
echo "Smoke report: $REPORT_PATH"

if [[ "$MODE" == "--print" ]]; then
  exit 0
fi

if [[ ! -f "$LOG_PATH" ]]; then
  echo "diagnostics log is missing: $LOG_PATH" >&2
  exit 1
fi

START_LINE="${AUTOCOMPLETE_LAB_LOG_START_LINE:-$(wc -l <"$LOG_PATH" | tr -d ' ')}"
TRACE_START_LINE=0
if [[ -f "$TRACE_PATH" ]]; then
  TRACE_START_LINE="${AUTOCOMPLETE_LAB_TRACE_START_LINE:-$(wc -l <"$TRACE_PATH" | tr -d ' ')}"
elif [[ -n "${AUTOCOMPLETE_LAB_TRACE_START_LINE:-}" ]]; then
  TRACE_START_LINE="$AUTOCOMPLETE_LAB_TRACE_START_LINE"
fi

if [[ "$MODE" == "run" ]]; then
  echo "Starting at diagnostics line $START_LINE."
  echo "Starting at trace line $TRACE_START_LINE."
  if [[ "$APP" == "codex" ]]; then
    read -r -p "Run the steps above with marker $CODEX_PROOF_MARKER, do not submit, then press Enter to validate this app pass. " _
    AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1
  elif [[ "$APP" == "claude-code" ]]; then
    read -r -p "Run the steps above with marker $CLAUDE_CODE_PROOF_MARKER, do not submit, then press Enter to validate this app pass. " _
    AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1
  else
    read -r -p "Run the steps above, then press Enter to validate this app pass. " _
  fi
elif [[ "$MODE" != "--check" ]]; then
  usage >&2
  exit 2
fi

SCAN_LINES="$(tail -n +"$((START_LINE + 1))" "$LOG_PATH" 2>/dev/null || true)"

count_pattern() {
  local pattern="$1"
  grep -E "$pattern" <<<"$SCAN_LINES" | wc -l | tr -d ' '
}

count_line_with_fields() {
  local prefix="$1"
  shift

  local lines
  lines="$(grep -F "$prefix" <<<"$SCAN_LINES" || true)"
  for field in "$@"; do
    lines="$(grep -F "$field" <<<"$lines" || true)"
  done
  if [[ -z "$lines" ]]; then
    echo 0
  else
    printf '%s\n' "$lines" | wc -l | tr -d ' '
  fi
}

print_failure_summary() {
  {
    echo
    echo "$SESSION_NAME smoke layer summary:"
    echo "- suggestion-presented: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID")"
    echo "- expected render: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)")"
    echo "- real caret placement: $(count_line_with_fields "suggestion-presented" "app=$BUNDLE_ID" "placementAnchorSource=caret" "placementConfidenceBand=high" "hasCaretRect=true")"
    echo "- synthetic caret placement: $(count_line_with_fields "suggestion-presented" "app=$BUNDLE_ID" "placementAnchorSource=synthetic-caret" "placementConfidenceBand=medium" "hasCaretRect=true")"
    echo "- Tab autocomplete action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=tab" "action=acceptNextWord" "handled=true")"
    echo "- full autocomplete action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=$ACCEPT_ALL_SHORTCUT" "action=acceptAllVisible" "handled=true")"
    echo "- accepted insertion undo action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "action=undoAcceptedInsertion" "handled=true")"
    echo "- accepted insertion undone: $(count_line_with_fields "accepted-insertion-undone" "app=$BUNDLE_ID")"
    echo "- native insertion undo: $(count_line_with_fields "accepted-insertion-native-undo-verified" "app=$BUNDLE_ID" "undoMechanism=nativeSingleEdit")"
    echo "- successful insert: $(count_pattern "insert .*app=$BUNDLE_ID .*success=true")"
    echo "- verified insertions: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified")"
    echo "- failed verification: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=(unchanged|partial|changedUnexpectedly|missing-context)")"
    echo "- field suppression: $(count_pattern "field-suppressed .*app=$BUNDLE_ID")"
    echo
    echo "If suggestions appeared but Tab action is 0, the key probably bypassed the app event tap."
  } >&2
}

require_line_with_fields() {
  local label="$1"
  shift

  local count
  count="$(count_line_with_fields "$@")"
  if [[ "$count" == "0" ]]; then
    echo "missing $SESSION_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

require_pattern() {
  local pattern="$1"
  local label="$2"

  if ! grep -E "$pattern" <<<"$SCAN_LINES" >/dev/null; then
    echo "missing $SESSION_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_pattern() {
  local pattern="$1"
  local label="$2"

  if grep -E "$pattern" <<<"$SCAN_LINES" >/dev/null; then
    echo "failed $SESSION_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

require_trusted_prompt_placement() {
  local real_caret_count synthetic_caret_count

  real_caret_count="$(count_line_with_fields \
    "suggestion-presented" \
    "app=$BUNDLE_ID" \
    "placementAnchorSource=caret" \
    "placementConfidenceBand=high" \
    "hasCaretRect=true")"
  synthetic_caret_count="$(count_line_with_fields \
    "suggestion-presented" \
    "app=$BUNDLE_ID" \
    "placementAnchorSource=synthetic-caret" \
    "placementConfidenceBand=medium" \
    "hasCaretRect=true")"

  if (( real_caret_count == 0 && synthetic_caret_count == 0 )); then
    echo "missing $SESSION_NAME diagnostics: trusted caret or synthetic-caret placement" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

append_report_row() {
  local verified_count="$1"
  local render_expectation="${2:-$EXPECTED_RENDER}"
  local visual_status="${3:-}"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local log_start_line="$((START_LINE + 1))"
  local log_end_line trace_start_line trace_end_line
  log_end_line="$(wc -l <"$LOG_PATH" | tr -d ' ')"
  if (( log_end_line < log_start_line )); then
    log_end_line="$log_start_line"
  fi
  trace_start_line="$((TRACE_START_LINE + 1))"
  if [[ -f "$TRACE_PATH" ]]; then
    trace_end_line="$(wc -l <"$TRACE_PATH" | tr -d ' ')"
  else
    trace_end_line="$trace_start_line"
  fi
  if (( trace_end_line < trace_start_line )); then
    trace_end_line="$trace_start_line"
  fi
  local trace_summary="lines $trace_start_line-$trace_end_line in \`$TRACE_PATH\`"
  if [[ "$visual_status" == "not-applicable" ]]; then
    trace_summary="$trace_summary; visual \`not-applicable\`"
  elif (( STRICT_VISUAL_EVIDENCE == 1 )); then
    trace_summary="$trace_summary; visual \`strict-complete\`"
  else
    trace_summary="$trace_summary; visual \`not-claimed\`"
  fi
  if (( PROMPT_NO_SUBMIT_PROFILE == 1 )); then
    trace_summary="$trace_summary; prompt no-submit confirmed"
  fi
  local build_proof
  build_proof="$(current_build_proof_summary)"
  if [[ -n "$build_proof" ]]; then
    trace_summary="$trace_summary; build \`$build_proof\`"
  fi

  if [[ ! -f "$REPORT_PATH" ]]; then
    mkdir -p "$(dirname "$REPORT_PATH")"
    cat >"$REPORT_PATH" <<'EOF'
# Manual Smoke Runs

This file is append-only proof for real app passes.

Only mark app-specific TODO items green after a run is recorded here.

Notes proof is surface-specific now: `notes-title`, `notes-body`, and
`notes-checklist` must each have their own row. The older generic Notes row is
historical evidence only.

When a trace slice says `visual strict-complete`, strict screenshot evidence was
required and passed. Rows without that marker are insertion proof only.

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
EOF
  fi

  printf '| %s | %s | `%s` | `%s` | %s | `%s` | lines %s-%s in `%s` | %s |\n' \
    "$timestamp" \
    "$REPORT_APP_NAME" \
    "$BUNDLE_ID" \
    "$PROOF_LABEL" \
    "$verified_count" \
    "$render_expectation" \
    "$log_start_line" \
    "$log_end_line" \
    "$LOG_PATH" \
    "$trace_summary" >>"$REPORT_PATH"
}

current_build_proof_summary() {
  local proofs=()
  if [[ -n "${AUTOCOMPLETE_LAB_SMOKE_BUILD_PROOF:-}" ]]; then
    proofs+=("$AUTOCOMPLETE_LAB_SMOKE_BUILD_PROOF")
  fi

  local commit
  commit="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -n "$commit" ]]; then
    proofs+=("commit:$commit")
  fi

  local app_binary="${AUTOCOMPLETE_LAB_APP_BINARY:-dist/SteadyType.app/Contents/MacOS/SteadyType}"
  if [[ -s "$app_binary" ]]; then
    local app_sha
    app_sha="$(shasum -a 256 "$app_binary" | awk '{print $1}')"
    if [[ -n "$app_sha" ]]; then
      proofs+=("app-sha256:$app_sha")
    fi
  fi

  local archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/smoke-proof/SteadyType.zip}"
  if [[ -s "$archive_path" ]]; then
    local archive_sha
    archive_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    if [[ -n "$archive_sha" ]]; then
      proofs+=("archive-sha256:$archive_sha")
    fi
  fi

  if (( ${#proofs[@]} == 0 )); then
    return 0
  fi

  local IFS=", "
  printf '%s' "${proofs[*]}"
}

if [[ "$APP" == "obsidian" ]] &&
  grep -E "suggestion-blocked .*app=$BUNDLE_ID .*reason=detached-suggestion-disabled" <<<"$SCAN_LINES" >/dev/null; then
  TRACE_SUPPRESSION_COUNT=0
  if [[ -f "$TRACE_PATH" ]]; then
    TRACE_SUPPRESSION_COUNT="$(
      tail -n +"$((TRACE_START_LINE + 1))" "$TRACE_PATH" |
        grep -F '"type":"suggestionSuppressed"' |
        grep -F "\"appBundleIdentifier\":\"$BUNDLE_ID\"" |
        grep -F '"reason":"detached-suggestion-disabled"' |
        wc -l |
        tr -d ' '
    )"
  fi

  if (( TRACE_SUPPRESSION_COUNT == 0 )); then
    echo "missing $DISPLAY_NAME trace coverage: detached suggestion suppression" >&2
    echo "trace: $TRACE_PATH" >&2
    print_failure_summary
    exit 1
  fi

  append_report_row 0 "detached-suppressed" "not-applicable"
  echo "$DISPLAY_NAME manual smoke verified detached suggestion suppression."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

if [[ "$APP" == "textedit" && "$TEXTEDIT_SELECTED_SUPPRESSION_PROOF" == "1" ]]; then
  require_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=selected-text" "selected-text suppression"
  reject_pattern "insert .*app=$BUNDLE_ID .*success=true" "insertion while text is selected"
  append_report_row 0 "selected-text-suppressed" "not-applicable"
  echo "$SESSION_NAME manual smoke verified selected-text suppression with no insertion."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

if [[ "$APP" == "textedit" && "$TEXTEDIT_FAST_TYPING_PROOF" == "1" ]]; then
  if ! is_truthy "${AUTOCOMPLETE_LAB_TEXTEDIT_FAST_TYPING_VERIFIED:-0}"; then
    echo "failed $SESSION_NAME proof: fast typing soak was not confirmed" >&2
    echo "run script/typing_performance_soak.sh successfully, then set AUTOCOMPLETE_LAB_TEXTEDIT_FAST_TYPING_VERIFIED=1 for this check" >&2
    exit 1
  fi

  append_report_row 0 "typing-pass-through" "not-applicable"
  echo "$SESSION_NAME manual smoke verified typing pass-through."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

require_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)" "suggestion presented with expected render mode"
if [[ "$APP" == "obsidian" || "$APP" == "codex" || "$APP" == "claude-code" || "$APP" == "claude" ]]; then
  require_trusted_prompt_placement
fi
require_line_with_fields "Tab handled by autocomplete" "keyboard-action" "app=$BUNDLE_ID" "key=tab" "action=acceptNextWord" "handled=true"
if [[ "$REQUIRES_FULL_ACCEPT" == "1" ]]; then
  require_line_with_fields "full accept key handled by autocomplete" "keyboard-action" "app=$BUNDLE_ID" "key=$ACCEPT_ALL_SHORTCUT" "action=acceptAllVisible" "handled=true"
else
  FULL_ACCEPT_COUNT="$(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=$ACCEPT_ALL_SHORTCUT" "action=acceptAllVisible" "handled=true")"
  if (( FULL_ACCEPT_COUNT > 0 )); then
    echo "failed $DISPLAY_NAME diagnostics: full accept handled before separate no-submit proof" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
fi
require_pattern "insert .*app=$BUNDLE_ID .*success=true" "successful insert"
require_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified" "verified insertion"
if (( REQUIRES_UNDO_ACCEPT == 1 )); then
  APP_ROLLBACK_UNDO_COUNT="$(count_line_with_fields "accepted-insertion-undone" "app=$BUNDLE_ID")"
  NATIVE_UNDO_COUNT="$(count_line_with_fields "accepted-insertion-native-undo-verified" "app=$BUNDLE_ID" "undoMechanism=nativeSingleEdit" "sameSliceUndoProof=true" "restoredOriginalTarget=true")"
  if (( APP_ROLLBACK_UNDO_COUNT == 0 && NATIVE_UNDO_COUNT == 0 )); then
    echo "missing $SESSION_NAME diagnostics: accepted insertion undo proof" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
  if (( APP_ROLLBACK_UNDO_COUNT > 0 )); then
    require_line_with_fields "accepted insertion undo handled" "keyboard-action" "app=$BUNDLE_ID" "action=undoAcceptedInsertion" "handled=true"
  fi
fi

VERIFIED_COUNT="$(grep -E "insert-verification .*app=$BUNDLE_ID .*result=verified" <<<"$SCAN_LINES" | wc -l | tr -d ' ')"
if (( VERIFIED_COUNT < MIN_VERIFIED_ACCEPTS )); then
  echo "expected at least $MIN_VERIFIED_ACCEPTS verified accept(s) for $SESSION_NAME, saw $VERIFIED_COUNT" >&2
  echo "log: $LOG_PATH" >&2
  print_failure_summary
  exit 1
fi
if [[ "$REQUIRES_FULL_ACCEPT" != "1" ]] && (( VERIFIED_COUNT != 1 )); then
  echo "expected exactly one verified one-word accept for $SESSION_NAME, saw $VERIFIED_COUNT" >&2
  echo "log: $LOG_PATH" >&2
  print_failure_summary
  exit 1
fi

reject_pattern "insert-verification-final-failure .*app=$BUNDLE_ID" "unrecovered insertion verification failure"
reject_pattern "field-suppressed .*app=$BUNDLE_ID" "field suppression"
reject_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=(insert-verification-failed|missing-anchor)" "blocking failure"

if (( PROMPT_NO_SUBMIT_PROFILE == 1 )); then
  if [[ "$APP" == "codex" ]] && ! is_truthy "${AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED:-0}"; then
    echo "failed $SESSION_NAME prompt no-submit proof: Codex proof marker was not confirmed" >&2
    echo "expected disposable prompt marker: $CODEX_PROOF_MARKER" >&2
    echo "set AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1 only after the prompt contains the marker and was not submitted" >&2
    print_failure_summary
    exit 1
  fi
  if [[ "$APP" == "claude-code" ]] && ! is_truthy "${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED:-0}"; then
    echo "failed $SESSION_NAME prompt no-submit proof: Claude Code proof marker was not confirmed" >&2
    echo "expected disposable terminal marker: $CLAUDE_CODE_PROOF_MARKER" >&2
    echo "set AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 only after the prompt contains the marker and was not submitted" >&2
    print_failure_summary
    exit 1
  fi

  if [[ ! -f "$TRACE_PATH" ]]; then
    echo "missing $SESSION_NAME trace coverage: prompt no-submit proof" >&2
    echo "trace: $TRACE_PATH" >&2
    print_failure_summary
    exit 1
  fi

  TRACE_SCAN_LINES="$(
    tail -n +"$((TRACE_START_LINE + 1))" "$TRACE_PATH" 2>/dev/null |
      grep -F "\"appBundleIdentifier\":\"$BUNDLE_ID\"" || true
  )"
  if [[ "$APP" == "claude-code" && "$CLAUDE_CODE_HOST_VARIANT" != "auto" ]]; then
    EXPECTED_CLAUDE_CODE_HOST_BUNDLE="$(claude_code_host_bundle_id)"
    if ! grep -F "\"fieldIdentity\":\"$EXPECTED_CLAUDE_CODE_HOST_BUNDLE|" <<<"$TRACE_SCAN_LINES" >/dev/null; then
      echo "failed $SESSION_NAME host proof: trace slice does not show host fieldIdentity $EXPECTED_CLAUDE_CODE_HOST_BUNDLE" >&2
      echo "trace: $TRACE_PATH" >&2
      print_failure_summary
      exit 1
    fi
  fi
  TRACE_ACCEPTED_COUNT="$(
    grep -F '"type":"suggestionAccepted"' <<<"$TRACE_SCAN_LINES" |
      wc -l |
      tr -d ' '
  )"

  if (( TRACE_ACCEPTED_COUNT != 1 )); then
    echo "failed $SESSION_NAME prompt no-submit proof: expected exactly one trace-level suggestionAccepted event, saw $TRACE_ACCEPTED_COUNT" >&2
    echo "trace: $TRACE_PATH" >&2
    print_failure_summary
    exit 1
  fi

  if grep -E '"acceptMode":"acceptAllVisible"|"checkpoint":"fieldSend"|"reason":"field-send-finalized"' <<<"$TRACE_SCAN_LINES" >/dev/null; then
    echo "failed $SESSION_NAME prompt no-submit proof: trace slice contains full-accept or field-send signal" >&2
    echo "trace: $TRACE_PATH" >&2
    print_failure_summary
    exit 1
  fi
fi

TRACE_EVAL_OUTPUT="$(mktemp)"
trap 'rm -f "$TRACE_EVAL_OUTPUT"' EXIT

TRACE_REQUIRE_CONFIDENT_PLACEMENT="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT:-0}"
TRACE_REQUIRE_VISUAL_EVIDENCE="${AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE:-0}"
if (( STRICT_VISUAL_EVIDENCE == 1 )); then
  TRACE_REQUIRE_CONFIDENT_PLACEMENT=1
  TRACE_REQUIRE_VISUAL_EVIDENCE=1
fi

if ! AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$TRACE_START_LINE" \
  AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="$BUNDLE_ID" \
  AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT="$TRACE_REQUIRE_CONFIDENT_PLACEMENT" \
  AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE="$TRACE_REQUIRE_VISUAL_EVIDENCE" \
  script/check_trace_eval.sh >"$TRACE_EVAL_OUTPUT" 2>&1; then
  echo "failed $SESSION_NAME trace eval coverage" >&2
  if (( STRICT_VISUAL_EVIDENCE == 1 )); then
    echo "Strict visual evidence requires every presented suggestion in this trace slice to include screenshot path, anchor rect, rendered panel rect, capture rect, and placement confidence." >&2
  fi
  echo "trace: $TRACE_PATH" >&2
  cat "$TRACE_EVAL_OUTPUT" >&2
  exit 1
fi

append_report_row "$VERIFIED_COUNT"

if (( STRICT_VISUAL_EVIDENCE == 1 )); then
  echo "$SESSION_NAME manual smoke verified with $VERIFIED_COUNT accepted insertions and strict visual trace evidence."
else
  echo "$SESSION_NAME manual smoke verified with $VERIFIED_COUNT accepted insertions."
fi
echo "Recorded pass in $REPORT_PATH."
