#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
TRACE_PATH="$TMP_DIR/traces.jsonl"
REPORT_PATH="$TMP_DIR/manual-smoke-runs.md"
FAILURE_OUTPUT="$TMP_DIR/failure-output.txt"

write_passing_log() {
  local bundle_id="$1"
  local render_mode="$2"

  cat >"$LOG_PATH" <<EOF
2026-04-26T08:00:00Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode
2026-04-26T08:00:01Z keyboard-action app=$bundle_id key=tab action=acceptNextWord handled=true reason=accepted
2026-04-26T08:00:01Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:02Z insert-verification app=$bundle_id result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
2026-04-26T08:00:03Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode
2026-04-26T08:00:04Z keyboard-action app=$bundle_id key=backtick action=acceptAllVisible handled=true reason=accepted
2026-04-26T08:00:04Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:05Z insert-verification app=$bundle_id result=verified acceptedChars=12 previousBeforeChars=11 currentBeforeChars=23
EOF
}

write_passing_trace() {
  local bundle_id="$1"

  cat >"$TRACE_PATH" <<EOF
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","latencyMilliseconds":0}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
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

  write_passing_log "$bundle_id" "$observed_render"
  write_passing_trace "$bundle_id"

  AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
    script/manual_smoke_session.sh "$app" --check >/dev/null

  if ! grep -F "| $display_name | \`$bundle_id\` | 2 | \`$expected_render\` | lines 1+ in \`" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $display_name pass" >&2
    exit 1
  fi

  if ! grep -F " | lines 1+ in \`$TRACE_PATH\` |" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $display_name trace slice" >&2
    exit 1
  fi
}

run_passing_case textedit TextEdit com.apple.TextEdit 'inlineAdjacent|floatingMirror' inlineAdjacent
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror
run_passing_case obsidian Obsidian md.obsidian floatingMirror floatingMirror
run_passing_case chrome Chrome com.google.Chrome floatingMirror floatingMirror

STATUS_OUTPUT="$TMP_DIR/status-output.txt"
AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

for app_name in TextEdit Notes Obsidian Chrome; do
  if ! grep -F -- "- $app_name: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test did not report $app_name as passed" >&2
    exit 1
  fi
done

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null

EMPTY_REPORT="$TMP_DIR/empty-manual-smoke-runs.md"
cat >"$EMPTY_REPORT" <<'EOF'
# Manual Smoke Runs

| Time UTC | App | Bundle | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | ---: | --- | --- | --- |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$EMPTY_REPORT" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- TextEdit: pending" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report missing app proof as pending" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$EMPTY_REPORT" \
  script/manual_smoke_status.sh --require-all >/dev/null 2>&1; then
  echo "manual smoke self-test expected --require-all to fail without app proof" >&2
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

echo "Manual smoke recorder self-test passed."
