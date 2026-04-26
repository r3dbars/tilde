#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
MODE="${2:-run}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"

usage() {
  cat <<'EOF'
Usage: script/manual_smoke_session.sh <textedit|notes|obsidian|chrome> [--print|--check]

Default mode prints the local manual steps, records the current diagnostics log
line, waits for Enter, validates the new diagnostics for that app, then appends
a pass row to docs/product/manual-smoke-runs.md.

Set AUTOCOMPLETE_LAB_LOG_START_LINE when using --check against a known log slice.
Set AUTOCOMPLETE_LAB_TRACE_START_LINE to validate a matching trace slice.
EOF
}

if [[ -z "$APP" || "$APP" == "-h" || "$APP" == "--help" ]]; then
  usage
  exit 0
fi

BUNDLE_ID=""
DISPLAY_NAME=""
EXPECTED_RENDER=""
STEPS=""

case "$APP" in
  textedit)
    BUNDLE_ID="com.apple.TextEdit"
    DISPLAY_NAME="TextEdit"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    STEPS=$'- Open a disposable TextEdit document.\n- Type `Can we`.\n- Wait for a suggestion.\n- Press Tab once.\n- Press the key above Tab for full visible accept.'
    ;;
  notes)
    BUNDLE_ID="com.apple.Notes"
    DISPLAY_NAME="Notes"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    STEPS=$'- Open the disposable autocomplete smoke note.\n- Test a title field with `Can we`.\n- Test a body line with `Can we`.\n- Test a checklist row with `Can we`.\n- Use Tab once, then the key above Tab for full visible accept.'
    ;;
  obsidian)
    BUNDLE_ID="md.obsidian"
    DISPLAY_NAME="Obsidian"
    EXPECTED_RENDER="floatingMirror"
    STEPS=$'- Open a disposable Obsidian note.\n- Type `Can we`.\n- Confirm mirror rendering does not jump during CodeMirror focus churn.\n- Use Tab once, then the key above Tab for full visible accept.'
    ;;
  chrome)
    BUNDLE_ID="com.google.Chrome"
    DISPLAY_NAME="Chrome"
    EXPECTED_RENDER="floatingMirror"
    STEPS=$'- Open a local data: page with a textarea.\n- Type `Can we` in the textarea.\n- Confirm focus stays in the textarea.\n- Use Tab once, then the key above Tab for full visible accept.'
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

echo "Manual smoke: $DISPLAY_NAME"
echo "Bundle: $BUNDLE_ID"
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
elif [[ "$MODE" != "--check" ]]; then
  usage >&2
  exit 2
fi

SCAN_LINES="$(tail -n +"$((START_LINE + 1))" "$LOG_PATH" 2>/dev/null || true)"

count_pattern() {
  local pattern="$1"
  grep -E "$pattern" <<<"$SCAN_LINES" | wc -l | tr -d ' '
}

print_failure_summary() {
  {
    echo
    echo "$DISPLAY_NAME smoke layer summary:"
    echo "- suggestion-presented: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID")"
    echo "- expected render: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)")"
    echo "- Tab autocomplete action: $(count_pattern "keyboard-action .*app=$BUNDLE_ID .*key=tab .*action=acceptNextWord .*handled=true")"
    echo "- full autocomplete action: $(count_pattern "keyboard-action .*app=$BUNDLE_ID .*key=backtick .*action=acceptAllVisible .*handled=true")"
    echo "- successful insert: $(count_pattern "insert .*app=$BUNDLE_ID .*success=true")"
    echo "- verified insertions: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified")"
    echo "- failed verification: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=(unchanged|partial|changedUnexpectedly|missing-context)")"
    echo "- field suppression: $(count_pattern "field-suppressed .*app=$BUNDLE_ID")"
    echo
    echo "If suggestions appeared but Tab action is 0, the key probably bypassed the app event tap."
  } >&2
}

require_pattern() {
  local pattern="$1"
  local label="$2"

  if ! grep -E "$pattern" <<<"$SCAN_LINES" >/dev/null; then
    echo "missing $DISPLAY_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_pattern() {
  local pattern="$1"
  local label="$2"

  if grep -E "$pattern" <<<"$SCAN_LINES" >/dev/null; then
    echo "failed $DISPLAY_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

require_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)" "suggestion presented with expected render mode"
require_pattern "keyboard-action .*app=$BUNDLE_ID .*key=tab .*action=acceptNextWord .*handled=true" "Tab handled by autocomplete"
require_pattern "keyboard-action .*app=$BUNDLE_ID .*key=backtick .*action=acceptAllVisible .*handled=true" "full accept key handled by autocomplete"
require_pattern "insert .*app=$BUNDLE_ID .*success=true" "successful insert"
require_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified" "verified insertion"

VERIFIED_COUNT="$(grep -E "insert-verification .*app=$BUNDLE_ID .*result=verified" <<<"$SCAN_LINES" | wc -l | tr -d ' ')"
if (( VERIFIED_COUNT < 2 )); then
  echo "expected at least two verified accepts for $DISPLAY_NAME, saw $VERIFIED_COUNT" >&2
  echo "log: $LOG_PATH" >&2
  print_failure_summary
  exit 1
fi

reject_pattern "insert-verification .*app=$BUNDLE_ID .*result=(unchanged|partial|changedUnexpectedly|missing-context)" "failed insertion verification"
reject_pattern "field-suppressed .*app=$BUNDLE_ID" "field suppression"
reject_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=(insert-verification-failed|missing-anchor|runtime-not-ready)" "blocking failure"

TRACE_EVAL_OUTPUT="$(mktemp)"
trap 'rm -f "$TRACE_EVAL_OUTPUT"' EXIT

if ! AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$TRACE_START_LINE" \
  AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="$BUNDLE_ID" \
  script/check_trace_eval.sh >"$TRACE_EVAL_OUTPUT" 2>&1; then
  echo "failed $DISPLAY_NAME trace eval coverage" >&2
  echo "trace: $TRACE_PATH" >&2
  cat "$TRACE_EVAL_OUTPUT" >&2
  exit 1
fi

append_report_row() {
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  if [[ ! -f "$REPORT_PATH" ]]; then
    mkdir -p "$(dirname "$REPORT_PATH")"
    cat >"$REPORT_PATH" <<'EOF'
# Manual Smoke Runs

This file is append-only proof for real app passes.

Only mark app-specific TODO items green after a run is recorded here.

| Time UTC | App | Bundle | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | ---: | --- | --- | --- |
EOF
  fi

  printf '| %s | %s | `%s` | %s | `%s` | lines %s+ in `%s` | lines %s+ in `%s` |\n' \
    "$timestamp" \
    "$DISPLAY_NAME" \
    "$BUNDLE_ID" \
    "$VERIFIED_COUNT" \
    "$EXPECTED_RENDER" \
    "$((START_LINE + 1))" \
    "$LOG_PATH" \
    "$((TRACE_START_LINE + 1))" \
    "$TRACE_PATH" >>"$REPORT_PATH"
}

append_report_row

echo "$DISPLAY_NAME manual smoke verified with $VERIFIED_COUNT accepted insertions."
echo "Recorded pass in $REPORT_PATH."
