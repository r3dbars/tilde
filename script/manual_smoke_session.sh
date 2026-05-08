#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

MODE="run"
NOTES_SURFACE=""
STRICT_VISUAL_EVIDENCE="${AUTOCOMPLETE_LAB_SMOKE_REQUIRE_VISUAL_EVIDENCE:-${AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE:-0}}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"
PROOF_LABEL="${AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL:-default}"
ACCEPT_ALL_SHORTCUT="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-backtick}"
PROMPT_NO_SUBMIT_CONFIRMED="${AUTOCOMPLETE_LAB_PROMPT_NO_SUBMIT_CONFIRMED:-0}"
BUILD_PROOF="${AUTOCOMPLETE_LAB_SMOKE_BUILD_PROOF:-}"

usage() {
  cat <<'EOF'
Usage: script/manual_smoke_session.sh <textedit|textedit-multiline|textedit-wrapped|notes|notes-title|notes-body|notes-checklist|obsidian|chrome|codex|claude-code|claude> [--print|--check] [--visual]

Default mode prints the local manual steps, records the current diagnostics log
line, waits for Enter, validates the new diagnostics for that app, then appends
a pass row to docs/product/manual-smoke-runs.md.

Notes proof must be recorded as notes-title, notes-body, or notes-checklist.
Use --visual when the trace slice must include strict screenshot evidence.

Set AUTOCOMPLETE_LAB_LOG_START_LINE when using --check against a known log slice.
Set AUTOCOMPLETE_LAB_TRACE_START_LINE to validate a matching trace slice.
EOF
}

if [[ -z "$APP" || "$APP" == "-h" || "$APP" == "--help" ]]; then
  usage
  exit 0
fi

case "$APP" in
  textedit-multiline)
    APP="textedit"
    PROOF_LABEL="multiline"
    ;;
  textedit-wrapped)
    APP="textedit"
    PROOF_LABEL="wrapped-line"
    ;;
  notes-title)
    APP="notes"
    NOTES_SURFACE="title"
    ;;
  notes-body)
    APP="notes"
    NOTES_SURFACE="body"
    ;;
  notes-checklist)
    APP="notes"
    NOTES_SURFACE="checklist"
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
MIN_VERIFIED_ACCEPTS=2
STEPS=""

case "$APP" in
  textedit)
    BUNDLE_ID="com.apple.TextEdit"
    DISPLAY_NAME="TextEdit"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    case "$PROOF_LABEL" in
      default|option-tab)
        STEPS=$'- Open a disposable TextEdit document.\n- Type `Can we`.\n- Wait for a suggestion.\n- Press Tab once.\n- Press the key above Tab for full visible accept.'
        ;;
      multiline)
        SESSION_NAME="TextEdit multiline"
        STEPS=$'- Open a disposable TextEdit document.\n- Type one setup line, press Return, then type `Can we` on the next line.\n- Wait for a suggestion on the second line.\n- Press Tab once.\n- Press the key above Tab for full visible accept.'
        ;;
      wrapped-line)
        SESSION_NAME="TextEdit wrapped line"
        STEPS=$'- Open a disposable TextEdit document in a narrow window.\n- Type a long disposable sentence so the caret is on a visually wrapped line.\n- End with `Can we`.\n- Wait for a suggestion on the wrapped visual line.\n- Press Tab once.\n- Press the key above Tab for full visible accept.'
        ;;
      *)
        echo "unknown TextEdit proof label: $PROOF_LABEL" >&2
        echo "expected default, multiline, or wrapped-line" >&2
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
      notes-body)
        NOTES_SURFACE="${NOTES_SURFACE:-body}"
        ;;
      notes-checklist)
        NOTES_SURFACE="${NOTES_SURFACE:-checklist}"
        ;;
    esac

    case "$NOTES_SURFACE" in
      "")
        PROOF_LABEL="choose-notes-surface"
        SESSION_NAME="Notes surface selector"
        STEPS=$'- Open the disposable autocomplete smoke note.\n- Record three separate Notes passes:\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate`\n  - `AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate`\n- Title, body, and checklist rows are separate proof. A generic Notes row does not count.'
        ;;
      title)
        PROOF_LABEL="notes-title"
        SESSION_NAME="Notes title"
        STEPS=$'- Open the disposable autocomplete smoke note.\n- Put the caret in the note title.\n- Type `Can we` in the title only.\n- Use Tab once, then the key above Tab for full visible accept.\n- Use --visual when screenshot-backed placement must be proven.'
        ;;
      body)
        PROOF_LABEL="notes-body"
        SESSION_NAME="Notes body"
        STEPS=$'- Open the disposable autocomplete smoke note.\n- Put `Autocomplete smoke` on the first body line.\n- Put the caret on the next body line and type `Can we`.\n- Use Tab once, then the key above Tab for full visible accept.\n- Use --visual when screenshot-backed placement must be proven.'
        ;;
      checklist)
        PROOF_LABEL="notes-checklist"
        SESSION_NAME="Notes checklist"
        STEPS=$'- Open the disposable autocomplete smoke note.\n- Toggle Checklist and create a disposable checklist row.\n- Type `Can we` in that checklist row.\n- Use Tab once, then the key above Tab for full visible accept.\n- Use --visual when screenshot-backed placement must be proven.'
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
    STEPS=$'- Open a disposable Obsidian note.\n- Type a partial word like `dicta`.\n- If CodeMirror does not expose caret bounds, confirm no detached floating bubble appears.\n- If a real caret-bound suggestion appears, use Tab once, then the key above Tab for full visible accept.'
    ;;
  chrome)
    BUNDLE_ID="com.google.Chrome"
    DISPLAY_NAME="Chrome"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    PROOF_LABEL="${AUTOCOMPLETE_LAB_CHROME_FIXTURE:-$PROOF_LABEL}"
    STEPS=$'- Open a local fixture page with a textarea, contenteditable field, editor-like field, Monaco-like editor, ProseMirror-like editor, or chat-style composer.\n- Type `Can we` in the focused field.\n- Confirm focus stays in the field.\n- Use Tab once, then the key above Tab for full visible accept.\n- For chat-like proof, prefer `script/real_app_smoke.sh chrome --fixture chat-like` so the no-submit guard is checked.'
    ;;
  codex)
    BUNDLE_ID="com.openai.codex"
    DISPLAY_NAME="Codex"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    MIN_VERIFIED_ACCEPTS=1
    STEPS=$'- Focus the Codex message box without submitting.\n- Type a harmless local test fragment like `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Do not press Enter as part of the smoke pass.\n- When the recorder asks, type NO-SUBMIT only after confirming the prompt was not sent.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
    ;;
  claude-code)
    BUNDLE_ID="com.anthropic.claude-code"
    DISPLAY_NAME="Claude Code"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    MIN_VERIFIED_ACCEPTS=1
    STEPS=$'- Focus the Claude Code prompt without submitting.\n- Type a harmless local test fragment like `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Do not press Enter as part of the smoke pass.\n- When the recorder asks, type NO-SUBMIT only after confirming the prompt was not sent.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
    ;;
  claude)
    BUNDLE_ID="com.anthropic.claudefordesktop"
    DISPLAY_NAME="Claude"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    REQUIRES_FULL_ACCEPT=0
    MIN_VERIFIED_ACCEPTS=1
    STEPS=$'- Focus the Claude prompt without submitting.\n- Type a harmless local test fragment like `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once for one word/suffix.\n- Do not press Enter as part of the smoke pass.\n- When the recorder asks, type NO-SUBMIT only after confirming the prompt was not sent.\n- Full visible accept stays disabled until separate full-accept no-submit proof exists.'
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
  echo "Choose one surface: notes-title, notes-body, or notes-checklist." >&2
  echo "Example: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate" >&2
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
  read -r -p "Run the steps above, then press Enter to validate this app pass. " _
  if [[ "$REQUIRES_FULL_ACCEPT" != "1" ]]; then
    read -r -p "Type NO-SUBMIT to confirm the prompt was not sent. " prompt_confirmation
    if [[ "$prompt_confirmation" != "NO-SUBMIT" ]]; then
      echo "$SESSION_NAME prompt proof was not recorded because no-submit was not confirmed." >&2
      exit 1
    fi
    PROMPT_NO_SUBMIT_CONFIRMED=1
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
  local trace_summary="lines $((TRACE_START_LINE + 1))+ in \`$TRACE_PATH\`"
  if [[ "$visual_status" == "not-applicable" ]]; then
    trace_summary="$trace_summary; visual \`not-applicable\`"
  elif (( STRICT_VISUAL_EVIDENCE == 1 )); then
    trace_summary="$trace_summary; visual \`strict-complete\`"
  else
    trace_summary="$trace_summary; visual \`not-claimed\`"
  fi
  if [[ "$REQUIRES_FULL_ACCEPT" != "1" ]]; then
    trace_summary="$trace_summary; prompt no-submit confirmed"
  fi

  local build_proof
  build_proof="$(manual_smoke_build_proof)"
  trace_summary="$trace_summary; build \`$build_proof\`"

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

Rows also include a build proof token in the trace slice. Current proof must
match either the current Git commit or the current release archive checksum.

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
EOF
  fi

  printf '| %s | %s | `%s` | `%s` | %s | `%s` | lines %s+ in `%s` | %s |\n' \
    "$timestamp" \
    "$REPORT_APP_NAME" \
    "$BUNDLE_ID" \
    "$PROOF_LABEL" \
    "$verified_count" \
    "$render_expectation" \
    "$((START_LINE + 1))" \
    "$LOG_PATH" \
    "$trace_summary" >>"$REPORT_PATH"
}

manual_smoke_build_proof() {
  if [[ -n "$BUILD_PROOF" ]]; then
    printf '%s' "$BUILD_PROOF"
    return
  fi

  local proof_parts=()
  local commit
  commit="$(git rev-parse --short=12 HEAD 2>/dev/null || true)"
  if [[ -n "$commit" ]]; then
    proof_parts+=("commit:$commit")
  fi

  local archive_path="${AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/AutocompleteLab.zip}"
  if [[ -s "$archive_path" ]]; then
    local archive_sha
    archive_sha="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    if [[ -n "$archive_sha" ]]; then
      proof_parts+=("archive-sha256:$archive_sha")
    fi
  fi

  if (( ${#proof_parts[@]} == 0 )); then
    printf 'commit:unknown'
    return
  fi

  local IFS=','
  printf '%s' "${proof_parts[*]}"
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
if [[ "$REQUIRES_FULL_ACCEPT" != "1" ]] && ! is_truthy "$PROMPT_NO_SUBMIT_CONFIRMED"; then
  echo "missing $SESSION_NAME no-submit confirmation; set AUTOCOMPLETE_LAB_PROMPT_NO_SUBMIT_CONFIRMED=1 only after confirming the prompt was not sent" >&2
  exit 1
fi

reject_pattern "insert-verification-final-failure .*app=$BUNDLE_ID" "unrecovered insertion verification failure"
reject_pattern "field-suppressed .*app=$BUNDLE_ID" "field suppression"
reject_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=(insert-verification-failed|missing-anchor)" "blocking failure"

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
