#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=0
export AUTOCOMPLETE_LAB_SMOKE_REQUIRE_VISUAL_EVIDENCE=0
export AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE=0

mkdir -p "$TMP_DIR/visual-placement-screenshots"
cp docs/product/visual-placement-screenshots/textedit-inline.png "$TMP_DIR/visual-placement-screenshots/textedit-inline.png"
cp docs/product/visual-placement-screenshots/codex-inline.png "$TMP_DIR/visual-placement-screenshots/codex-inline.png"
cp docs/product/visual-placement-screenshots/claude-code-terminal.png "$TMP_DIR/visual-placement-screenshots/claude-code-terminal.png"

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

write_undo_passing_log() {
  local bundle_id="$1"
  local render_mode="$2"

  cat >"$LOG_PATH" <<EOF
2026-04-26T08:00:00Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:01Z keyboard-action action=acceptNextWord app=$bundle_id handled=true key=tab reason=accepted
2026-04-26T08:00:01Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:02Z insert-verification app=$bundle_id result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
2026-04-26T08:00:03Z keyboard-action action=undoAcceptedInsertion app=$bundle_id handled=true key=cmdZ reason=accepted-insertion-undone
2026-04-26T08:00:03Z accepted-insertion-undone app=$bundle_id acceptedTextLength=3 restoredTextLength=23
2026-04-26T08:00:04Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:05Z keyboard-action action=acceptAllVisible app=$bundle_id handled=true key=backtick reason=accepted
2026-04-26T08:00:05Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:06Z insert-verification app=$bundle_id result=verified acceptedChars=12 previousBeforeChars=11 currentBeforeChars=23
EOF
}

write_option_tab_passing_log() {
  local bundle_id="$1"
  local render_mode="$2"

  cat >"$LOG_PATH" <<EOF
2026-04-26T08:00:00Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:01Z keyboard-action action=acceptNextWord app=$bundle_id handled=true key=tab reason=accepted
2026-04-26T08:00:01Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:02Z insert-verification app=$bundle_id result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
2026-04-26T08:00:03Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
2026-04-26T08:00:04Z keyboard-action action=acceptAllVisible app=$bundle_id handled=true key=optionTab reason=accepted
2026-04-26T08:00:04Z insert app=$bundle_id success=true mode=axSelectedText
2026-04-26T08:00:05Z insert-verification app=$bundle_id result=verified acceptedChars=12 previousBeforeChars=11 currentBeforeChars=23
EOF
}

write_one_word_log() {
  local bundle_id="$1"
  local render_mode="$2"

  cat >"$LOG_PATH" <<EOF
2026-04-26T08:00:00Z suggestion-presented app=$bundle_id effectiveRenderMode=$render_mode placementAnchorSource=synthetic-caret placementConfidenceBand=medium hasCaretRect=true
2026-04-26T08:00:01Z keyboard-action action=acceptNextWord app=$bundle_id handled=true key=tab reason=accepted
2026-04-26T08:00:01Z insert app=$bundle_id success=true mode=keyEvents
2026-04-26T08:00:02Z insert-verification app=$bundle_id result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
EOF
}

write_passing_trace() {
  local bundle_id="$1"

  cat >"$TRACE_PATH" <<EOF
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"insertionFailed","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","reason":"unchanged"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","latencyMilliseconds":110,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,40,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
{"type":"insertionVerified","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
EOF
}

write_one_word_log_with_runtime_warmup() {
  local bundle_id="$1"
  local render_mode="$2"

  write_one_word_log "$bundle_id" "$render_mode"
  local warmed_log="$LOG_PATH.warmup"
  {
    echo "2026-04-26T07:59:59Z suggestion-blocked app=$bundle_id reason=runtime-not-ready readinessStage=warming"
    cat "$LOG_PATH"
  } >"$warmed_log"
  mv "$warmed_log" "$LOG_PATH"
}

write_one_word_trace() {
  local bundle_id="$1"
  local host_field_identity="${2:-$bundle_id|pid:1|element:1}"

  cat >"$TRACE_PATH" <<EOF
{"type":"suggestionPresented","suggestionID":"one-word","appBundleIdentifier":"$bundle_id","fieldIdentity":"$host_field_identity","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","suggestionID":"one-word","appBundleIdentifier":"$bundle_id","fieldIdentity":"$host_field_identity","requestMode":"wordCompletion","acceptedText":"make","metadata":{"acceptMode":"acceptNextWord"}}
{"type":"insertionVerified","suggestionID":"one-word","appBundleIdentifier":"$bundle_id","fieldIdentity":"$host_field_identity","requestMode":"wordCompletion","acceptedText":"make"}
EOF
}

write_passing_visual_trace() {
  local bundle_id="$1"
  local screenshot_one="$TMP_DIR/autocomplete-lab-one.png"
  local screenshot_two="$TMP_DIR/autocomplete-lab-two.png"

  cp docs/product/visual-placement-screenshots/textedit-inline.png "$screenshot_one"
  cp docs/product/visual-placement-screenshots/textedit-inline.png "$screenshot_two"

  cat >"$TRACE_PATH" <<EOF
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","latencyMilliseconds":0,"screenshotPath":"$screenshot_one","metadata":{"anchorRect":"{{10,10},{4,18}}","suggestionPanelRect":"{{14,10},{90,18}}","screenshotCaptureRect":"{{0,0},{200,120}}","placementConfidenceBand":"medium"}}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"$bundle_id","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","latencyMilliseconds":110,"screenshotPath":"$screenshot_two","metadata":{"anchorRect":"{{10,32},{4,18}}","suggestionPanelRect":"{{14,32},{120,18}}","screenshotCaptureRect":"{{0,0},{200,120}}","placementConfidenceBand":"medium"}}
{"type":"suggestionAccepted","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
{"type":"insertionVerified","suggestionID":"two","appBundleIdentifier":"$bundle_id","requestMode":"phraseContinuation","acceptedText":" this work"}
EOF
}

write_passing_log "com.apple.TextEdit" "inlineAdjacent"
write_passing_trace "com.apple.TextEdit"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$TMP_DIR/headless-manual-smoke-runs.md" \
  script/manual_smoke_session.sh textedit --visual >"$TMP_DIR/headless-run.txt" 2>&1 </dev/null; then
  echo "manual smoke self-test expected headless run mode to fail before validation" >&2
  exit 1
fi

if ! grep -F 'Manual smoke run mode needs an interactive terminal' "$TMP_DIR/headless-run.txt" >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_LOG_START_LINE=' "$TMP_DIR/headless-run.txt" >/dev/null ||
   ! grep -F 'script/manual_smoke_session.sh textedit --check' "$TMP_DIR/headless-run.txt" >/dev/null; then
  echo "manual smoke self-test expected headless run mode to explain --check recovery" >&2
  exit 1
fi

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

  if ! grep -F "| $display_name | \`$bundle_id\` | \`$proof_label\` | 2 | \`$expected_render\` | lines 1-" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $display_name pass" >&2
    exit 1
  fi

  if ! grep -F " | lines 1-" "$REPORT_PATH" | grep -F "in \`$TRACE_PATH\` |" >/dev/null; then
    if ! grep -F " | lines 1-" "$REPORT_PATH" | grep -F "in \`$TRACE_PATH\`; visual \`not-claimed\`" >/dev/null; then
      echo "manual smoke self-test did not record the successful $display_name trace slice" >&2
      exit 1
    fi
  fi
}

run_one_word_case() {
  local app="$1"
  local status_name="$2"
  local report_name="$3"
  local bundle_id="$4"
  local expected_render="$5"
  local observed_render="$6"
  local proof_label="${7:-default}"

  write_one_word_log "$bundle_id" "$observed_render"
  write_one_word_trace "$bundle_id"

  AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL="$proof_label" \
    AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1 \
    AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
    script/manual_smoke_session.sh "$app" --check >/dev/null

  if ! grep -F "| $report_name | \`$bundle_id\` | \`$proof_label\` | 1 | \`$expected_render\` | lines 1-" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record one-word no-submit proof for $status_name" >&2
    exit 1
  fi
}

run_strict_visual_case() {
  local app="$1"
  local proof_label="$2"

  write_passing_log "com.apple.Notes" "floatingMirror"
  write_passing_visual_trace "com.apple.Notes"

  AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
    script/manual_smoke_session.sh "$app" --check --visual >/dev/null

  if ! grep -F "| Notes | \`com.apple.Notes\` | \`$proof_label\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the strict visual $proof_label pass" >&2
    exit 1
  fi

  if ! grep -F " | lines 1-" "$REPORT_PATH" | grep -F "in \`$TRACE_PATH\`; visual \`strict-complete\`" >/dev/null; then
    echo "manual smoke self-test did not record the successful $proof_label strict visual trace slice" >&2
    exit 1
  fi
}

run_notes_undo_case() {
  local app="$1"
  local proof_label="$2"

  write_undo_passing_log "com.apple.Notes" "floatingMirror"
  write_passing_trace "com.apple.Notes"

  AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
    AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
    script/manual_smoke_session.sh "$app" --check >/dev/null

  if ! grep -F "| Notes | \`com.apple.Notes\` | \`$proof_label\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-" "$REPORT_PATH" >/dev/null; then
    echo "manual smoke self-test did not record the successful $proof_label undo pass" >&2
    exit 1
  fi
}

run_passing_case textedit TextEdit com.apple.TextEdit 'inlineAdjacent|floatingMirror' inlineAdjacent
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-title
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-body
run_passing_case notes Notes com.apple.Notes 'inlineAdjacent|floatingMirror' floatingMirror notes-checklist
run_notes_undo_case notes-title-undo notes-title-undo
run_notes_undo_case notes-body-undo notes-body-undo
run_notes_undo_case notes-checklist-undo notes-checklist-undo
run_passing_case obsidian Obsidian md.obsidian floatingMirror floatingMirror
run_passing_case obsidian-theme Obsidian md.obsidian floatingMirror floatingMirror obsidian-theme
run_passing_case obsidian-pane Obsidian md.obsidian floatingMirror floatingMirror obsidian-pane
run_passing_case obsidian-long-note Obsidian md.obsidian floatingMirror floatingMirror obsidian-long-note
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent textarea
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent contenteditable
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent textarea-public
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent contenteditable-public
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent editor-like
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent monaco-like
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent prosemirror-like
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent monaco-real
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent prosemirror-real
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent monaco-real-default
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent prosemirror-real-default
run_passing_case chrome Chrome com.google.Chrome 'inlineAdjacent|floatingMirror' inlineAdjacent chat-like

write_option_tab_passing_log "com.apple.TextEdit" "inlineAdjacent"
write_passing_trace "com.apple.TextEdit"
AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL=option-tab \
  AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT=optionTab \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >/dev/null

if ! grep -F "| TextEdit | \`com.apple.TextEdit\` | \`option-tab\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-" "$REPORT_PATH" >/dev/null; then
  echo "manual smoke self-test did not record the Option-Tab full accept pass" >&2
  exit 1
fi

run_one_word_case codex Codex Codex com.openai.codex 'inlineAdjacent|floatingMirror' inlineAdjacent
run_one_word_case claude "Claude desktop" Claude com.anthropic.claudefordesktop 'inlineAdjacent|floatingMirror' inlineAdjacent
for claude_proof_label in claude-empty claude-long claude-wrapped claude-narrow claude-context claude-light claude-dark; do
  run_one_word_case claude "Claude desktop $claude_proof_label" Claude com.anthropic.claudefordesktop 'inlineAdjacent|floatingMirror' inlineAdjacent "$claude_proof_label"
done
run_one_word_case claude-code "Claude Code" "Claude Code" com.anthropic.claude-code 'inlineAdjacent|floatingMirror' inlineAdjacent
run_strict_visual_case notes-title notes-title

write_one_word_log_with_runtime_warmup "com.anthropic.claude-code" "inlineAdjacent"
write_one_word_trace "com.anthropic.claude-code"

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh claude-code --check >/dev/null

if ! grep -F "| Claude Code | \`com.anthropic.claude-code\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 1-" "$REPORT_PATH" >/dev/null; then
  echo "manual smoke self-test did not allow Claude Code runtime warmup before verified proof" >&2
  exit 1
fi

write_one_word_log "com.anthropic.claude-code" "inlineAdjacent"
write_one_word_trace "com.anthropic.claude-code" "com.apple.Terminal|pid:1|element:1"

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT=terminal \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh claude-code --check >/dev/null

if ! grep -F "| Claude Code | \`com.anthropic.claude-code\` | \`claude-code-terminal\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 1-" "$REPORT_PATH" >/dev/null; then
  echo "manual smoke self-test did not record the Claude Code Terminal host proof label" >&2
  exit 1
fi

write_one_word_log "com.anthropic.claude-code" "inlineAdjacent"
write_one_word_trace "com.anthropic.claude-code" "com.mitchellh.ghostty|pid:1|element:1"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_VARIANT=iterm2 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh claude-code --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected Claude Code host proof to reject the wrong terminal fieldIdentity" >&2
  exit 1
fi

if ! grep -F "trace slice does not show host fieldIdentity com.googlecode.iterm2" "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain the Claude Code wrong-host trace proof failure" >&2
  exit 1
fi

write_one_word_log "com.openai.codex" "inlineAdjacent"
write_one_word_trace "com.openai.codex"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh codex --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected Codex proof without marker confirmation to fail" >&2
  exit 1
fi

if ! grep -F 'Codex proof marker was not confirmed' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not reject unmarked Codex proof" >&2
  exit 1
fi

write_one_word_log "com.openai.codex" "inlineAdjacent"
cat >"$TRACE_PATH" <<'EOF'
{"type":"suggestionPresented","suggestionID":"codex-field-send","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","suggestionID":"codex-field-send","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"make","metadata":{"acceptMode":"acceptNextWord"}}
{"type":"insertionVerified","suggestionID":"codex-field-send","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"make"}
{"type":"acceptedTextEdited","suggestionID":"codex-field-send","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"make","reason":"field-send-finalized","metadata":{"checkpoint":"fieldSend"}}
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_CODEX_PROOF_MARKER_CONFIRMED=1 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh codex --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected Codex field-send proof to fail" >&2
  exit 1
fi

if ! grep -F 'trace slice contains full-accept or field-send signal' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not reject Codex field-send proof" >&2
  exit 1
fi

script/manual_smoke_session.sh notes --print >"$TMP_DIR/notes-picker.txt"
if ! grep -F "Manual smoke: Notes surface selector" "$TMP_DIR/notes-picker.txt" >/dev/null; then
  echo "manual smoke self-test did not print the Notes surface selector" >&2
  exit 1
fi

if ! grep -F "Proof: choose-notes-surface" "$TMP_DIR/notes-picker.txt" >/dev/null; then
  echo "manual smoke self-test did not label generic Notes as a surface picker" >&2
  exit 1
fi

if ! grep -F "script/real_app_smoke.sh notes-title --manual-gate" "$TMP_DIR/notes-picker.txt" >/dev/null; then
  echo "manual smoke self-test did not print the explicit Notes title real-app command" >&2
  exit 1
fi

script/manual_smoke_session.sh notes-title --print >"$TMP_DIR/notes-title-print.txt"
if ! grep -F "Notes surface: title" "$TMP_DIR/notes-title-print.txt" >/dev/null; then
  echo "manual smoke self-test did not print the Notes title surface label" >&2
  exit 1
fi

script/manual_smoke_session.sh notes-title-undo --print >"$TMP_DIR/notes-title-undo-print.txt"
if ! grep -F "Manual smoke: Notes title undo" "$TMP_DIR/notes-title-undo-print.txt" >/dev/null; then
  echo "manual smoke self-test did not print the Notes title undo session label" >&2
  exit 1
fi

if ! grep -F "Proof: notes-title-undo" "$TMP_DIR/notes-title-undo-print.txt" >/dev/null; then
  echo "manual smoke self-test did not label Notes title undo proof" >&2
  exit 1
fi

if ! grep -F "Press Command-Z" "$TMP_DIR/notes-title-undo-print.txt" >/dev/null; then
  echo "manual smoke self-test did not print the Notes undo instruction" >&2
  exit 1
fi

write_passing_log "com.apple.Notes" "floatingMirror"
write_passing_trace "com.apple.Notes"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh notes --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected generic Notes proof to fail" >&2
  exit 1
fi

if ! grep -F 'Notes proof cannot be recorded as a generic Notes pass' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain missing Notes surface proof" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-04-26T08:00:00Z suggestion-presented app=com.apple.Notes effectiveRenderMode=floatingMirror placementAnchorSource=caret placementConfidenceBand=high hasCaretRect=true
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh notes-body --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected Notes body diagnostics to fail without Tab proof" >&2
  exit 1
fi

if ! grep -F 'missing Notes body diagnostics: Tab handled by autocomplete' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not label the Notes body diagnostics failure" >&2
  exit 1
fi

write_passing_log "com.apple.Notes" "floatingMirror"
write_passing_trace "com.apple.Notes"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh notes-body-undo --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected Notes undo proof to fail without undo diagnostics" >&2
  exit 1
fi

if ! grep -F 'missing Notes body undo diagnostics: accepted insertion undo proof' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not label missing Notes undo diagnostics" >&2
  exit 1
fi

write_passing_log "com.apple.Notes" "floatingMirror"
write_passing_trace "com.apple.Notes"

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh notes-body --check --visual >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected strict Notes visual proof to fail without screenshots" >&2
  exit 1
fi

if ! grep -F 'Strict visual evidence requires every presented suggestion' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain strict Notes visual proof requirements" >&2
  exit 1
fi

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

if ! grep -F "| Obsidian | \`md.obsidian\` | 0 | \`detached-suppressed\` | lines 1-" "$REPORT_PATH" >/dev/null; then
  if ! grep -F "| Obsidian | \`md.obsidian\` | \`default\` | 0 | \`detached-suppressed\` | lines 1-" "$REPORT_PATH" >/dev/null; then
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

for app_name in TextEdit "Notes title" "Notes body" "Notes checklist" Obsidian "Obsidian theme" "Obsidian panes" "Obsidian long note" "Chrome textarea" "Chrome contenteditable"; do
  if ! grep -F -- "- $app_name: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test did not report $app_name as passed" >&2
    exit 1
  fi
done

for app_name in "Chrome production textarea" "Chrome chat-like no-submit" Codex "Claude Code" "Claude desktop"; do
  if grep -F -- "- $app_name: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should not report $app_name as beta-safe passed" >&2
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

if ! grep -F -- "Focused graduation decisions:" "$STATUS_OUTPUT" >/dev/null ||
   ! grep -F -- "- Google Docs browser: blocked" "$STATUS_OUTPUT" >/dev/null ||
   ! grep -F -- "- Mail compose: diagnostics-only" "$STATUS_OUTPUT" >/dev/null ||
   ! grep -F -- "- Chrome production text fields: blocked" "$STATUS_OUTPUT" >/dev/null ||
   ! grep -F -- "- Claude desktop layouts: proof-only" "$STATUS_OUTPUT" >/dev/null ||
   ! grep -F -- "- Codex layouts: proof-only" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not print focused graduation decisions" >&2
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

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null 2>&1; then
  echo "manual smoke self-test expected --require-all to fail while screenshot proof is pending" >&2
  exit 1
fi

COMPLETE_SCORECARD_PATH="$TMP_DIR/deep-dive-scorecard-complete.md"
cat >"$COMPLETE_SCORECARD_PATH" <<'EOF'
# Deep Dive Scorecard

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Diagnostics | 10/10 | Clear enough. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 10/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Inline proof exists. | Done. |
| Codex | 10/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Prompt screenshot exists. | Done. |
| Claude Code | 10/10 | [claude-code-terminal.png](visual-placement-screenshots/claude-code-terminal.png) | Terminal-host prompt screenshot exists. | Done. |
EOF

if ! AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  AUTOCOMPLETE_LAB_SCORECARD="$COMPLETE_SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected --require-all to pass when Claude Code proof is present" >&2
  cat "$FAILURE_OUTPUT" >&2
  exit 1
fi

BELOW_TARGET_SCORECARD_PATH="$TMP_DIR/deep-dive-scorecard-below-target.md"
cat >"$BELOW_TARGET_SCORECARD_PATH" <<'EOF'
# Deep Dive Scorecard

## Area Ratings

| Area | Rating | Why |
| --- | ---: | --- |
| Diagnostics | 10/10 | Clear enough. |

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 9.5/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Inline proof exists. | More variants. |
| Codex | 10/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Prompt screenshot exists. | Done. |
EOF

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  AUTOCOMPLETE_LAB_SCORECARD="$BELOW_TARGET_SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected strict status to fail on unlabelled below-target visual score" >&2
  exit 1
fi

if ! grep -F 'Below-target visual score rows without pending labels' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain unlabelled below-target visual scoring" >&2
  exit 1
fi

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

if ! grep -F -- "Notes title: pending (run AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate)" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not print the explicit Notes title real-app status command" >&2
  exit 1
fi

DEFAULT_OBSIDIAN_REPORT="$TMP_DIR/default-obsidian-manual-smoke-runs.md"
CURRENT_COMMIT_PROOF="$(git rev-parse --short=12 HEAD)"
cat >"$DEFAULT_OBSIDIAN_REPORT" <<EOF
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | Obsidian | \`md.obsidian\` | \`default\` | 2 | \`floatingMirror\` | lines 1+ in \`/tmp/diagnostics.log\` | lines 1+ in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CURRENT_COMMIT_PROOF\` |
EOF

AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$DEFAULT_OBSIDIAN_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- Obsidian: passed" "$STATUS_OUTPUT" >/dev/null &&
  ! grep -F -- "- Obsidian: stale pass" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not recognize the default Obsidian proof row" >&2
  exit 1
fi

for app_name in "Obsidian theme" "Obsidian panes" "Obsidian long note"; do
  if ! grep -F -- "- $app_name: pending" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should not accept default Obsidian proof for $app_name" >&2
    exit 1
  fi
done

if ! grep -F -- "Obsidian theme: pending (run AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate)" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not print the explicit Obsidian theme proof command" >&2
  exit 1
fi

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

if ! grep -F -- "- Obsidian: limited pass (needs full accept proof; run" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not report limited Obsidian proof as incomplete" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$LIMITED_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh --require-all >/dev/null 2>&1; then
  echo "manual smoke self-test expected --require-all to fail with only limited Obsidian proof" >&2
  exit 1
fi

MASKED_STALE_REPORT="$TMP_DIR/masked-stale-manual-smoke-runs.md"
FAKE_APP_BINARY="$TMP_DIR/current-app-binary"
printf 'current app binary\n' >"$FAKE_APP_BINARY"
FAKE_APP_SHA="$(shasum -a 256 "$FAKE_APP_BINARY" | awk '{print $1}')"
cat >"$MASKED_STALE_REPORT" <<EOF
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:deadbeef0000,app-sha256:$FAKE_APP_SHA\` |
EOF

AUTOCOMPLETE_LAB_APP_BINARY="$FAKE_APP_BINARY" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$MASKED_STALE_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- TextEdit: passed" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test should accept current app binary proof after docs-only commits" >&2
  exit 1
fi

FAKE_ARCHIVE="$TMP_DIR/current-archive.zip"
printf 'current archive\n' >"$FAKE_ARCHIVE"
FAKE_ARCHIVE_SHA="$(shasum -a 256 "$FAKE_ARCHIVE" | awk '{print $1}')"
cat >"$MASKED_STALE_REPORT" <<EOF
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:deadbeef0000,archive-sha256:$FAKE_ARCHIVE_SHA\` |
EOF

AUTOCOMPLETE_LAB_ARCHIVE_PATH="$FAKE_ARCHIVE" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$MASKED_STALE_REPORT" \
  AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
  script/manual_smoke_status.sh >"$STATUS_OUTPUT"

if ! grep -F -- "- TextEdit: passed" "$STATUS_OUTPUT" >/dev/null; then
  echo "manual smoke self-test should accept current archive proof after docs commit" >&2
  exit 1
fi

SOURCE_COMPAT_COMMIT="$(git rev-parse --short=12 HEAD~1 2>/dev/null || true)"
if [[ -n "$SOURCE_COMPAT_COMMIT" ]]; then
  cat >"$MASKED_STALE_REPORT" <<EOF
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$SOURCE_COMPAT_COMMIT,app-sha256:stale-app-binary\` |
EOF

  AUTOCOMPLETE_LAB_PROOF_SOURCE_PATHS="script/nonexistent-proof-source-path" \
    AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$MASKED_STALE_REPORT" \
    AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
    script/manual_smoke_status.sh >"$STATUS_OUTPUT"

  if ! grep -F -- "- TextEdit: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should accept older commit proof when watched app source paths are unchanged" >&2
    exit 1
  fi
fi

CLAUDE_POLICY_ONLY_COMMIT=""
CURRENT_HEAD="$(git rev-parse --verify HEAD)"
while IFS= read -r candidate; do
  [[ "$candidate" != "$CURRENT_HEAD" ]] || continue
  changed_paths="$(git diff --name-only "$candidate".."$CURRENT_HEAD" -- Package.swift Package.resolved Sources | tr '\n' ' ')"
  if [[ "$changed_paths" == "Sources/AutocompleteLabCore/Configuration/ClaudeCodeTerminalHostProofPolicy.swift " ]]; then
    CLAUDE_POLICY_ONLY_COMMIT="$(git rev-parse --short=12 "$candidate")"
    break
  fi
done < <(git rev-list --max-count=120 HEAD)

if [[ -n "$CLAUDE_POLICY_ONLY_COMMIT" ]]; then
  cat >"$MASKED_STALE_REPORT" <<EOF
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-04-26T08:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 1-2 in \`/tmp/diagnostics.log\` | lines 1-2 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; build \`commit:$CLAUDE_POLICY_ONLY_COMMIT,app-sha256:stale-app-binary\` |
| 2026-04-26T08:01:00Z | Claude Code | \`com.anthropic.claude-code\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 3-4 in \`/tmp/diagnostics.log\` | lines 3-4 in \`/tmp/traces.jsonl\`; visual \`strict-complete\`; prompt no-submit confirmed; build \`commit:$CLAUDE_POLICY_ONLY_COMMIT,app-sha256:stale-app-binary\` |
EOF

  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$MASKED_STALE_REPORT" \
    AUTOCOMPLETE_LAB_SCORECARD="$SCORECARD_PATH" \
    script/manual_smoke_status.sh >"$STATUS_OUTPUT"

  if ! grep -F -- "- TextEdit: passed" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should not stale TextEdit on Claude Code-only source changes" >&2
    exit 1
  fi

  if ! grep -F -- "- Claude Code: stale pass" "$STATUS_OUTPUT" >/dev/null; then
    echo "manual smoke self-test should stale Claude Code on Claude Code policy changes" >&2
    exit 1
  fi
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
