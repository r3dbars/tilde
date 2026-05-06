#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
TRACE_PATH="$TMP_DIR/traces.jsonl"
REPORT_PATH="$TMP_DIR/manual-smoke-runs.md"
SCORECARD_PATH="$TMP_DIR/deep-dive-scorecard.md"
FAILURE_OUTPUT="$TMP_DIR/failure-output.txt"

write_passing_log() {
  local bundle_id="$1"
  local render_mode="$2"

  cat >"$LOG_PATH" <<EOF
2026-04-26T08:00:00Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:01Z keyboard-action action=acceptNextWord app=$bundle_id handled=true key=tab reason=accepted
2026-04-26T08:00:01Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:02Z insert-verification app=$bundle_id result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
2026-04-26T08:00:03Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:04Z keyboard-action action=acceptAllVisible app=$bundle_id handled=true key=backtick reason=accepted
2026-04-26T08:00:04Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:05Z insert-verification app=$bundle_id result=verified acceptedChars=12 previousBeforeChars=11 currentBeforeChars=23
EOF
}

write_passing_trace() {
  local bundle_id="$1"

  cat >"$TRACE_PATH" <<EOF
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","latencyMilliseconds":0}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"insertionFailed","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","reason":"unchanged"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","latencyMilliseconds":110}
{"type":"suggestionAccepted","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
{"type":"insertionVerified","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
EOF
}

run_passing_case() {
  local app="$1"
  local display_name="$2"
  local bundle_id="$3"
  local expected_render="$4"
  local observed_render="$5"
  local proof_label="${6:-default}"

  write_passing_log "$bundle_id" "$observed_render"
  write_passing_trace "$bundle_id"

  AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$proof_label" \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
    script/manual_smoke_session.sh "$app" --check >/dev/null

  if ! grep -F "| $display_name | \`$bundle_id\` | \`$proof_label\` | 2 | \`$expected_render\` | lines 1+ in \`" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $display_name pass" >&2
    exit 1
  fi

  if ! grep -F " | lines 1+ in \`$TRACE_PATH\` |" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $display_name trace slice" >&2
    exit 1
  fi
}

run_passing_case textedit TextEdit com.apple.TextEdit 'inlineAdjacent|floatingMirror' inlineAdjacent
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-title
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-body
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-checklist
run_passing_case obsidian Obsidian md.obsidian floatingMirror floatingMirror
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent textarea
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent contenteditable
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent editor-like
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent monaco-like
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent prosemirror-like
run_passing_case codex Codex com.openai.codex 'inlineAdjacent|floatingMirror' inlineAdjacent
run_passing_case claude-code "Claude Code" com.anthropic.claude-code 'inlineAdjacent|floatingMirror' inlineAdjacent
run_passing_case claude Claude com.anthropic.claudefordesktop 'inlineAdjacent|floatingMirror' inlineAdjacent

cat >"$LOG_PATH" <<'EOF'
2026-04-26T08:00:00Z suggestion-blocked app=md.obsidian reason=detached-suggestion-disabled hasCaretRect=false
EOF
cat >"$TRACE_PATH" <<'EOF'
{"type":"suggestionSuppressed","suggestionID":"suppressed-one","appBundleIdentifier":"md.obsidian","requestMode":"wordCompletion","reason":"detached-suggestion-disabled","metadata":{"hasCaretRect":"false"}}
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh obsidian --check >/dev/null

if ! grep -F "| Obsidian | \`md.obsidian\` | 0 | \`detached-suppressed\` | lines 1+ in \`" "$REPORT_PATH" >/dev/null; then
  if ! grep -F "| Obsidian | \`md.obsidian\` | \`default\` | 0 | \`detached-suppressed\` | lines 1+ in \`" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful Obsidian detached-suppression proof" >&2
    exit 1
  fi
fi

cat >"$SCORECARD_PATH" <<'EOF'
# Deep Dive Scorecard

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Codex support | 6/10 | Needs prompt proof. |
| Normal typing passthrough | 9.5/10 | Poll guard proof is almost there. |
| Diagnostics | 10/10 | Clear enough. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 9.5/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Inline proof exists. | More variants. |
| Codex | 7.5/10 | Pending safe screenshot | Insertion proof exists. | Needs a safe prompt screenshot audit. |
EOF

STATUS_OUTPUT="$TMP_DIR/status-output.txt"
AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F "Insertion proof status: $REPORT_PATH" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not label insertion proof separately" >&2
  exit 1
fi

for app_name in TextEdit "Notes title" "Notes body" "Notes checklist" "Chrome textarea" "Chrome contenteditable" "Chrome editor-like" "Chrome Monaco-like" "Chrome ProseMirror-like" Codex "Claude Code"; do
  if ! grep -F -- "- $app_name: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test did not report $app_name as passed" >&2
    exit 1
  fi
done

if ! grep -F -- "- Obsidian: passed" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report full Obsidian proof as passed" >&2
  exit 1
fi

if ! grep -F -- "- TextEdit: screenshot-backed (visual-placement-screenshots/textedit-inline.png)" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report TextEdit screenshot proof separately" >&2
  exit 1
fi

if ! grep -F -- "- Codex: pending screenshot proof - Pending safe screenshot" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report pending Codex screenshot proof separately" >&2
  exit 1
fi

if ! grep -F -- "next: Needs a safe prompt screenshot audit." "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not print the next visual audit action" >&2
  exit 1
fi

if ! grep -F -- "- Codex support: 6/10 - Needs prompt proof." "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report remaining non-10 scorecard gaps" >&2
  exit 1
fi

if ! grep -F -- "- Normal typing passthrough: 9.5/10 - Poll guard proof is almost there." "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report decimal scorecard gaps" >&2
  exit 1
fi

if grep -F -- "- Diagnostics: 10/10" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test should not report 10/10 scorecard rows as gaps" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null

GENERIC_NOTES_REPORT="$TMP_DIR/generic-notes-manual-smoke-runs.md"
cat >"$GENERIC_NOTES_REPORT" <<'EOF'
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | Notes | `com.apple.Notes` | `default` | 2 | `inlineAdjacent|floatingMirror` | lines 1+ in `/tmp/diagnostics.log` | lines 1+ in `/tmp/traces.jsonl` |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$GENERIC_NOTES_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

for app_name in "Notes title" "Notes body" "Notes checklist"; do
  if ! grep -F -- "- $app_name: pending" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should not accept generic Notes proof for $app_name" >&2
    exit 1
  fi
done

LIMITED_REPORT="$TMP_DIR/limited-manual-smoke-runs.md"
cat >"$LIMITED_REPORT" <<'EOF'
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof label | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | Obsidian | `md.obsidian` | `default` | 0 | `detached-suppressed` | lines 1+ in `/tmp/diagnostics.log` | lines 1+ in `/tmp/traces.jsonl` |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$LIMITED_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- Obsidian: limited pass (needs full accept proof)" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report limited Obsidian proof as incomplete" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$LIMITED_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null 2>&1; then
  echo "manual smoke self-test expected --require-all to fail with only limited Obsidian proof" >&2
  exit 1
fi

EMPTY_REPORT="$TMP_DIR/empty-manual-smoke-runs.md"
cat >"$EMPTY_REPORT" <<'EOF'
# Manual Smoke Runs

| Time UTC | App | Bundle | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | ---: | --- | --- | --- |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$EMPTY_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- TextEdit: pending" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report missing app proof as pending" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$EMPTY_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null 2>&1; then
  echo "manual smoke self-test expected --require-all to fail without app proof" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$EMPTY_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --strict >/dev/null 2>&1; then
  echo "manual smoke self-test expected --strict to fail without app proof" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-04-26T08:00:00Z suggestion-presented app=com.apple.TextEdit effectiveRenderMode=inlineAdjacent
EOF
write_passing_trace "com.apple.TextEdit"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected a failed pass without key handling" >&2
  exit 1
fi

if ! grep -F 'Tab autocomplete action: 0' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain the missing key action" >&2
  exit 1
fi

write_passing_log "com.apple.TextEdit" "inlineAdjacent"
cat >"$TRACE_PATH" <<'EOF'
{"type":"suggestionPresented","suggestionID":"trace-miss","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0}
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected a failed pass without trace accept coverage" >&2
  exit 1
fi

if ! grep -F 'failed TextEdit trace eval coverage' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain missing trace eval coverage" >&2
  exit 1
fi

write_passing_log "com.apple.TextEdit" "inlineAdjacent"
cat >>"$LOG_PATH" <<'EOF'
2026-04-26T08:00:06Z insert-verification-final-failure app=com.apple.TextEdit mode=keyEvents result=unchanged
EOF
write_passing_trace "com.apple.TextEdit"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected a failed pass with unrecovered insertion failure" >&2
  exit 1
fi

if ! grep -F 'unrecovered insertion verification failure' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain unrecovered insertion failures" >&2
  exit 1
fi

echo "Manual smoke recorder self-test passed."
