#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
MODE="${2:-run}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}"
REPORT_PATH="${AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT:-docs/product/manual-smoke-runs.md}"

usage() {
  cat <<'EOF'
Usage: script/manual_smoke_session.sh <app> [--print|--check]

Supported apps:
  textedit notes obsidian chrome codex
  mail safari slack vscode cursor
  atlas terminal onepassword

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
PROOF_KIND="accept"
STEPS=""

case "$APP" in
  textedit)
    BUNDLE_ID="com.apple.TextEdit"
    DISPLAY_NAME="TextEdit"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    STEPS=$'- Open a disposable TextEdit document.\n- Type `Can we`.\n- Wait for a suggestion.\n- Press Tab once.\n- Press the key above Tab for full visible accept.\n- Trigger one more suggestion, press Esc, then keep typing briefly in the same field.\n- Confirm the field stays calm until focus changes.'
    ;;
  notes)
    BUNDLE_ID="com.apple.Notes"
    DISPLAY_NAME="Notes"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    STEPS=$'- Open the disposable autocomplete smoke note.\n- Test a title field with `Can we`.\n- Test a body line with `Can we`.\n- Test a checklist row with `Can we`.\n- Use Tab once, then the key above Tab for full visible accept.\n- Trigger one more suggestion, press Esc, then keep typing briefly in the same field.\n- Confirm the field stays calm until focus changes.'
    ;;
  obsidian)
    BUNDLE_ID="md.obsidian"
    DISPLAY_NAME="Obsidian"
    EXPECTED_RENDER="floatingMirror"
    STEPS=$'- Open a disposable Obsidian note.\n- Type a partial word like `dicta`.\n- If CodeMirror does not expose caret bounds, confirm no detached floating bubble appears.\n- If a real caret-bound suggestion appears, use Tab once, then the key above Tab for full visible accept.\n- Trigger one more real caret-bound suggestion, press Esc, then keep typing briefly in the same field.\n- Confirm the field stays calm until focus changes.'
    ;;
  chrome)
    BUNDLE_ID="com.google.Chrome"
    DISPLAY_NAME="Chrome"
    EXPECTED_RENDER="floatingMirror"
    STEPS=$'- Open a local data: page with a textarea.\n- Type `Can we` in the textarea.\n- Confirm focus stays in the textarea.\n- Use Tab once, then the key above Tab for full visible accept.\n- Trigger one more suggestion, press Esc, then keep typing briefly in the same textarea.\n- Confirm the field stays calm until focus changes.'
    ;;
  codex)
    BUNDLE_ID="com.openai.codex"
    DISPLAY_NAME="Codex"
    EXPECTED_RENDER="inlineAdjacent|floatingMirror"
    STEPS=$'- Focus the Codex message box without submitting.\n- Type a harmless local test fragment like `Can we make this`.\n- Confirm a suggestion appears near the prompt or in a stable mirror position.\n- Use Tab once, then the key above Tab for full visible accept.\n- Trigger one more suggestion, press Esc, then keep typing briefly in the same prompt.\n- Confirm the field stays calm until focus changes.\n- Do not press Enter as part of the smoke pass.'
    ;;
  mail)
    BUNDLE_ID="com.apple.mail"
    DISPLAY_NAME="Mail"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="diagnostics-only"
    STEPS=$'- Open a disposable Mail compose draft with no recipient.\n- Type `Can we` in the body.\n- Confirm no suggestion appears.\n- Confirm Tab and the key above Tab are not captured by autocomplete.\n- Delete the draft after the pass only if you are sure it is disposable.'
    ;;
  safari)
    BUNDLE_ID="com.apple.Safari"
    DISPLAY_NAME="Safari"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="diagnostics-only"
    STEPS=$'- Open a local textarea or disposable local test page in Safari.\n- Type `Can we`.\n- Confirm no suggestion appears.\n- Confirm Tab and the key above Tab are not captured by autocomplete.'
    ;;
  slack)
    BUNDLE_ID="com.tinyspeck.slackmacgap"
    DISPLAY_NAME="Slack"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="diagnostics-only"
    STEPS=$'- Focus only a disposable Slack draft or your own test space.\n- Type `Can we` without sending.\n- Confirm no suggestion appears.\n- Confirm Tab and the key above Tab are not captured by autocomplete.\n- Do not send the message as part of the smoke pass.'
    ;;
  vscode)
    BUNDLE_ID="com.microsoft.VSCode"
    DISPLAY_NAME="VS Code"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="diagnostics-only"
    STEPS=$'- Open a disposable local text file in VS Code.\n- Type `Can we`.\n- Confirm no suggestion appears.\n- Confirm Tab and the key above Tab are not captured by autocomplete.'
    ;;
  cursor)
    BUNDLE_ID="com.todesktop.230313mzl4w4u92"
    DISPLAY_NAME="Cursor"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="diagnostics-only"
    STEPS=$'- Open a disposable local text file in Cursor.\n- Type `Can we`.\n- Confirm no suggestion appears.\n- Confirm Tab and the key above Tab are not captured by autocomplete.'
    ;;
  atlas)
    BUNDLE_ID="com.openai.atlas"
    DISPLAY_NAME="Atlas"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="unsupported"
    STEPS=$'- Focus Atlas in a harmless disposable prompt or local field.\n- Type `Can we`.\n- Confirm the menu status shows `unsupported`.\n- Confirm no suggestion appears and autocomplete does not capture Tab.'
    ;;
  terminal)
    BUNDLE_ID="com.apple.Terminal"
    DISPLAY_NAME="Terminal"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="unsupported"
    STEPS=$'- Focus a local Terminal prompt.\n- Type a harmless fragment, then delete it without pressing Enter.\n- Confirm the menu status shows `unsupported`.\n- Confirm no suggestion appears and autocomplete does not capture Tab.'
    ;;
  onepassword)
    BUNDLE_ID="com.1password.1password"
    DISPLAY_NAME="1Password"
    EXPECTED_RENDER="disabled"
    PROOF_KIND="unsupported"
    STEPS=$'- Focus a safe non-secret area in 1Password, not a real secret field.\n- Confirm the menu status shows `unsupported`.\n- Confirm no suggestion appears and autocomplete does not capture Tab.\n- Do not type or reveal any real password, token, key, or payment data.'
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
TRACE_SCAN_LINES=""
if [[ -f "$TRACE_PATH" ]]; then
  TRACE_SCAN_LINES="$(tail -n +"$((TRACE_START_LINE + 1))" "$TRACE_PATH" 2>/dev/null || true)"
fi

count_pattern() {
  local pattern="$1"
  local lines
  lines="$(grep -E "$pattern" <<<"$SCAN_LINES" || true)"
  if [[ -z "$lines" ]]; then
    echo 0
  else
    printf '%s\n' "$lines" | wc -l | tr -d ' '
  fi
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

count_event_for_other_app() {
  local event="$1"
  local lines
  lines="$(grep -E "^[^ ]+ $event " <<<"$SCAN_LINES" | grep -Fv "app=$BUNDLE_ID" || true)"
  if [[ -z "$lines" ]]; then
    echo 0
  else
    printf '%s\n' "$lines" | wc -l | tr -d ' '
  fi
}

print_failure_summary() {
  {
    echo
    echo "$DISPLAY_NAME smoke layer summary:"
    echo "- suggestion-presented: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID")"
    echo "- expected render: $(count_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)")"
    echo "- Tab autocomplete action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=tab" "action=acceptNextWord" "handled=true")"
    echo "- full autocomplete action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=backtick" "action=acceptAllVisible" "handled=true")"
    echo "- successful insert: $(count_pattern "insert .*app=$BUNDLE_ID .*success=true")"
    echo "- verified insertions: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified")"
    echo "- failed verification: $(count_pattern "insert-verification .*app=$BUNDLE_ID .*result=(unchanged|partial|changedUnexpectedly|missing-context)")"
    echo "- Esc dismiss action: $(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=escape" "action=dismiss" "handled=true")"
    echo "- Esc field suppression: $(count_line_with_fields "field-suppressed" "app=$BUNDLE_ID" "reason=escape")"
    echo "- suppressed field block: $(count_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=suppressedField")"
    echo "- wrong-app insertions: $(count_event_for_other_app "insert")"
    echo "- secure-field presented rows: $(count_line_with_fields "suggestion-presented" "app=$BUNDLE_ID" "role=AXSecureTextField")"
    echo "- sensitive-reason presented rows: $(count_line_with_fields "suggestion-presented" "app=$BUNDLE_ID" "reason=sensitiveContent")"
    echo "- detached presented rows: $(count_line_with_fields "suggestion-presented" "app=$BUNDLE_ID" "anchorCanPresent=false")"
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
    echo "missing $DISPLAY_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
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

reject_line_with_fields() {
  local label="$1"
  shift

  local count
  count="$(count_line_with_fields "$@")"
  if [[ "$count" != "0" ]]; then
    echo "failed $DISPLAY_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_event_for_other_app() {
  local event="$1"
  local label="$2"

  local offenders
  offenders="$(grep -E "^[^ ]+ $event " <<<"$SCAN_LINES" | grep -Fv "app=$BUNDLE_ID" || true)"
  if [[ -n "$offenders" ]]; then
    echo "failed $DISPLAY_NAME diagnostics: $label" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_trace_type_for_other_app() {
  local type="$1"
  local label="$2"

  local offenders
  offenders="$(grep -F "\"type\":\"$type\"" <<<"$TRACE_SCAN_LINES" | grep -Fv "\"appBundleIdentifier\":\"$BUNDLE_ID\"" || true)"
  if [[ -n "$offenders" ]]; then
    echo "failed $DISPLAY_NAME trace coverage: $label" >&2
    echo "trace: $TRACE_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_tab_without_visible_suggestion() {
  local handled_tabs
  handled_tabs="$(count_line_with_fields "keyboard-action" "app=$BUNDLE_ID" "key=tab" "handled=true")"
  local shown_suggestions
  shown_suggestions="$(count_pattern "suggestion-presented .*app=$BUNDLE_ID")"

  if (( handled_tabs > 0 && shown_suggestions == 0 )); then
    echo "failed $DISPLAY_NAME diagnostics: Tab stolen with no visible suggestion" >&2
    echo "log: $LOG_PATH" >&2
    print_failure_summary
    exit 1
  fi
}

reject_hard_fail_markers() {
  reject_event_for_other_app "insert" "wrong-app insertion"
  reject_event_for_other_app "insert-verification" "wrong-app insertion verification"
  reject_trace_type_for_other_app "suggestionAccepted" "wrong-app accepted suggestion"
  reject_trace_type_for_other_app "insertionVerified" "wrong-app verified insertion"
  reject_tab_without_visible_suggestion
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "role=AXSecureTextField"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "reason=secureField"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "reason=sensitiveContent"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "isSecure=true"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "sensitive=true"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "fieldKind=password"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "fieldKind=payment"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "fieldKind=token"
  reject_line_with_fields "suggestion shown over sensitive field" "suggestion-presented" "app=$BUNDLE_ID" "fieldKind=apiKey"
  reject_line_with_fields "detached bubble over whole editor" "suggestion-presented" "app=$BUNDLE_ID" "anchorCanPresent=false"
  reject_line_with_fields "detached bubble over whole editor" "suggestion-presented" "app=$BUNDLE_ID" "anchorReason=detachedAnchorDisallowed"
}

append_report_row() {
  local verified_count="$1"
  local render_expectation="${2:-$EXPECTED_RENDER}"
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
    "$verified_count" \
    "$render_expectation" \
    "$((START_LINE + 1))" \
    "$LOG_PATH" \
    "$((TRACE_START_LINE + 1))" \
    "$TRACE_PATH" >>"$REPORT_PATH"
}

reject_hard_fail_markers

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

  append_report_row 0 "detached-suppressed"
  echo "$DISPLAY_NAME manual smoke verified detached suggestion suppression."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

if [[ "$PROOF_KIND" == "diagnostics-only" ]]; then
  require_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=profile-diagnostics-only" "diagnostics-only profile blocked suggestion"
  reject_pattern "suggestion-presented .*app=$BUNDLE_ID" "suggestion shown for diagnostics-only app"
  reject_line_with_fields "Tab captured for diagnostics-only app" "keyboard-action" "app=$BUNDLE_ID" "key=tab" "handled=true"
  reject_line_with_fields "full accept captured for diagnostics-only app" "keyboard-action" "app=$BUNDLE_ID" "key=backtick" "handled=true"
  reject_pattern "insert .*app=$BUNDLE_ID .*success=true" "insert attempted for diagnostics-only app"
  reject_pattern "insert-verification .*app=$BUNDLE_ID .*result=verified" "insertion verified for diagnostics-only app"

  append_report_row 0 "diagnostics-only-blocked"
  echo "$DISPLAY_NAME manual smoke verified diagnostics-only suppression."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

if [[ "$PROOF_KIND" == "unsupported" ]]; then
  require_line_with_fields "unsupported app status" "status" "profile=unsupported" "enabled=off"
  reject_pattern "suggestion-presented" "suggestion shown while unsupported app was frontmost"
  reject_line_with_fields "Tab captured while unsupported app was frontmost" "keyboard-action" "key=tab" "handled=true"
  reject_line_with_fields "full accept captured while unsupported app was frontmost" "keyboard-action" "key=backtick" "handled=true"
  reject_pattern "insert .*success=true" "insert attempted while unsupported app was frontmost"
  reject_pattern "insert-verification .*result=verified" "insertion verified while unsupported app was frontmost"

  append_report_row 0 "unsupported-blocked"
  echo "$DISPLAY_NAME manual smoke verified unsupported-app suppression."
  echo "Recorded pass in $REPORT_PATH."
  exit 0
fi

require_pattern "suggestion-presented .*app=$BUNDLE_ID .*effectiveRenderMode=($EXPECTED_RENDER)" "suggestion presented with expected render mode"
require_line_with_fields "Tab handled by autocomplete" "keyboard-action" "app=$BUNDLE_ID" "key=tab" "action=acceptNextWord" "handled=true"
require_line_with_fields "full accept key handled by autocomplete" "keyboard-action" "app=$BUNDLE_ID" "key=backtick" "action=acceptAllVisible" "handled=true"
require_line_with_fields "Esc handled by autocomplete" "keyboard-action" "app=$BUNDLE_ID" "key=escape" "action=dismiss" "handled=true"
require_line_with_fields "Esc suppressed current field" "field-suppressed" "app=$BUNDLE_ID" "reason=escape"
require_pattern "suggestion-blocked .*app=$BUNDLE_ID .*reason=suppressedField" "suppressed field after Esc"
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
reject_pattern "field-suppressed .*app=$BUNDLE_ID .*reason=insert-verification-failed" "unexpected field suppression"
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

append_report_row "$VERIFIED_COUNT"

echo "$DISPLAY_NAME manual smoke verified with $VERIFIED_COUNT accepted insertions."
echo "Recorded pass in $REPORT_PATH."
