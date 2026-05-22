#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
CLAUDE_CODE_TRACE_FILE="$(mktemp)"
VISUAL_TRACE_FILE="$(mktemp)"
VISUAL_SCREENSHOT_FILE="$(mktemp)"
UNRECOVERED_TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$CLAUDE_CODE_TRACE_FILE" "$VISUAL_TRACE_FILE" "$VISUAL_SCREENSHOT_FILE" "$UNRECOVERED_TRACE_FILE"' EXIT
printf "png" >"$VISUAL_SCREENSHOT_FILE"

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionRequested","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion"}
{"type":"modelResult","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":42,"metadata":{"cleanedWordCount":"1","firstTokenLatencyMilliseconds":"17","totalGenerationLatencyMilliseconds":"42"}}
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"fieldKind":"multilineCompose","anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"insertionVerified","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at","metadata":{"insertionMode":"axSelectedText"}}
{"type":"acceptedInsertionUndone","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","outcome":"acceptNextWord","reason":"accepted-insertion-undone","metadata":{"acceptMode":"acceptNextWord","undoMechanism":"nativeSingleEdit","sameSliceUndoProof":"true","restoredOriginalTarget":"true"}}
{"type":"acceptedTextEdited","experimentArm":"length_1_word","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","metadata":{"fieldKind":"multilineCompose","checkpoint":"10s","survivalClass":"exactKept","tokenRecall":"1.000","normalizedEditDistance":"0.000","strongAcceptedAndKept":"true"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":120,"metadata":{"anchorSource":"field","hasElementRect":"true","placementConfidenceBand":"medium"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":220,"metadata":{"anchorSource":"field","hasElementRect":"true","placementConfidenceBand":"medium"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"three","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":" I   think so. ","latencyMilliseconds":80,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"four","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"i think so.","latencyMilliseconds":90,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"five","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"I think so.","latencyMilliseconds":100,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","experimentArm":"length_3_word","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","experimentArm":"length_3_word","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","experimentArm":"length_3_word","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"nine","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"ten","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"eleven","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionHidden","experimentArm":"length_1_word","suggestionID":"nine","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionHidden","experimentArm":"length_1_word","suggestionID":"ten","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionHidden","experimentArm":"length_1_word","suggestionID":"eleven","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionSuppressed","experimentArm":"length_1_word","suggestionID":"twelve","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"is","reason":"repeated-miss","metadata":{"fieldKind":"form"}}
{"type":"suggestionSuppressed","experimentArm":"length_1_word","suggestionID":"thirteen","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"e","reason":"repeated-miss","metadata":{"fieldKind":"search"}}
{"type":"suggestionSuppressed","experimentArm":"length_1_word","suggestionID":"fourteen","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","reason":"no-fast-word-candidate"}
{"type":"caretGeometryFailed","experimentArm":"length_3_word","suggestionID":"fifteen","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","reason":"detached-suggestion-disabled","metadata":{"effectiveRenderMode":"floatingMirror"}}
JSONL

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.apple.TextEdit" \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test.txt

if ! grep -F "com.apple.TextEdit: 100% (1/1)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report the TextEdit accept rate" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Presented: 11" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not deduplicate streamed presentations" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Typed through: 3" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report typed-through suggestions" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Suppressed: 3" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppressed suggestions" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Actionable suppressed: 2" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not separate actionable suppressions" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "repeated-miss: 2" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppression reasons" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.openai.codex: 3" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppression counts by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "wordCompletion: 3" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppression counts by mode" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.openai.codex: 2" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report actionable suppression counts by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "wordCompletion: 2" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report actionable suppression counts by mode" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Accept rate: 36%" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report overall accept rate" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Useful rate: 64%" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Accepted and kept: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report accepted-and-kept count" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Accepted-and-kept shown rate: 9%" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report accepted-and-kept shown rate" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Insertion verification success: 100%" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report insertion verification success" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "total-generation p95 latency: 42ms" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report total-generation latency" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Empty model results: 0 (0%)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report empty model results" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Pre-render blocked: 3" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report pre-render blocked count" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "first token:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null ||
   ! grep -F "0-50ms: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report first-token latency buckets" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Acceptance funnel:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print the acceptance funnel" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "model returned: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not count model-result funnel events" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Recommended next fix:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print recommended next fixes" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Caret placement failures: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report caret placement failures" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "md.obsidian: 50% (1/2)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report caret failures by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "floatingMirror: 100% (1/1)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report caret failures by render mode" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Support state by app:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print support states" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Insertion reliability by app and mode:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print insertion reliability by app and mode" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit axSelectedText: 100% (1 ok / 0 failed)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print insertion reliability for TextEdit" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Undo recoverability by app:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print undo recoverability by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit: nativeSingleEdit" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print native undo recoverability for TextEdit" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit: experimental" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not mark low-sample TextEdit traces as experimental" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.openai.codex: 67% (6/9)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

cat >"$VISUAL_TRACE_FILE" <<JSONL
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"shadow-no-shot","appBundleIdentifier":"md.obsidian","fieldIdentity":"md.obsidian|pid:1|element:2","requestMode":"wordCompletion","displayedText":"String(8 chars)","textBeforeCursor":"String(49 chars)","textAfterCursor":"","timestamp":"2026-05-13T10:25:53Z","latencyMilliseconds":0,"metadata":{"anchorRect":"x=799,y=313,w=0,h=21","suggestionPanelRect":"x=735,y=317,w=87,h=32","clippingRect":"x=704,y=224,w=126,h=536","screenshotCaptureRect":"none","placementConfidenceBand":"medium"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"shadow-covered","appBundleIdentifier":"md.obsidian","fieldIdentity":"md.obsidian|pid:1|element:2","requestMode":"wordCompletion","displayedText":"String(8 chars)","textBeforeCursor":"String(49 chars)","textAfterCursor":"","timestamp":"2026-05-13T10:25:53Z","latencyMilliseconds":0,"screenshotPath":"$VISUAL_SCREENSHOT_FILE","metadata":{"anchorRect":"x=799,y=313,w=0,h=21","suggestionPanelRect":"x=735,y=317,w=87,h=32","clippingRect":"x=704,y=224,w=126,h=536","screenshotCaptureRect":"x=680,y=200,w=174,h=584","placementConfidenceBand":"medium"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"cross-second-covered","appBundleIdentifier":"md.obsidian","fieldIdentity":"md.obsidian|pid:1|element:2","requestMode":"wordCompletion","displayedText":"String(11 chars)","textBeforeCursor":"String(67 chars)","textAfterCursor":"","timestamp":"2026-05-13T10:25:53Z","latencyMilliseconds":0,"screenshotPath":"$VISUAL_SCREENSHOT_FILE","metadata":{"anchorRect":"x=812,y=341,w=0,h=21","suggestionPanelRect":"x=748,y=345,w=105,h=32","clippingRect":"x=704,y=224,w=160,h=536","screenshotCaptureRect":"x=680,y=200,w=208,h=584","placementConfidenceBand":"medium"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"cross-second-no-shot","appBundleIdentifier":"md.obsidian","fieldIdentity":"md.obsidian|pid:1|element:2","requestMode":"wordCompletion","displayedText":"String(11 chars)","textBeforeCursor":"String(67 chars)","textAfterCursor":"","timestamp":"2026-05-13T10:25:54Z","latencyMilliseconds":0,"metadata":{"anchorRect":"x=812,y=341,w=0,h=21","suggestionPanelRect":"x=748,y=345,w=105,h=32","clippingRect":"x=704,y=224,w=160,h=536","screenshotCaptureRect":"none","placementConfidenceBand":"medium"}}
JSONL

AUTOCOMPLETE_LAB_TRACE_PATH="$VISUAL_TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_VISUAL_EVIDENCE=1 \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-visual.txt

if grep -F "visual evidence guardrail failed" /tmp/autocomplete-trace-eval-self-test-visual.txt >/dev/null; then
  echo "trace eval self-test did not deduplicate repeated visual shadow presentations" >&2
  cat /tmp/autocomplete-trace-eval-self-test-visual.txt >&2
  exit 1
fi

cat >"$CLAUDE_CODE_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"claude-code-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","displayedText":"safe","latencyMilliseconds":20,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
JSONL

AUTOCOMPLETE_LAB_TRACE_PATH="$CLAUDE_CODE_TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.anthropic.claude-code" \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-claude-code.txt 2>&1 || true

if grep -F "no MVP compatibility profile" /tmp/autocomplete-trace-eval-self-test-claude-code.txt >/dev/null; then
  echo "trace eval self-test treated Claude Code as an unknown profile" >&2
  cat /tmp/autocomplete-trace-eval-self-test-claude-code.txt >&2
  exit 1
fi

if ! grep -F "com.anthropic.claude-code: blocked" /tmp/autocomplete-trace-eval-self-test-claude-code.txt >/dev/null; then
  echo "trace eval self-test did not keep Claude Code diagnostics-only" >&2
  cat /tmp/autocomplete-trace-eval-self-test-claude-code.txt >&2
  exit 1
fi

if ! grep -F "length_1_word: 25% (1/4)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report accept rate by experiment arm" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "length_1_word: 100% (4/4)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate by experiment arm" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Accepted and kept by experiment arm:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print accepted-and-kept experiment-arm slices" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "wordCompletion: 100% (4/4)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate by mode" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "multilineCompose: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report field-kind slices" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "form: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppressed form fields" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "search: 1" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report suppressed search fields" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Suppressed by experiment arm:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not print suppressed experiment-arm slices" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "p90 latency: 100ms" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not use first visible streamed latency" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if grep -F "220ms" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test leaked a later streamed latency sample" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "3x phraseContinuation: i think so. | app com.openai.codex 3/3 (example three)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report repeated unaccepted suggestions" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if grep -F "that works" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test incorrectly reported accepted repeated suggestions" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if grep -F "wordCompletion: ng" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test incorrectly reported typed-through suggestions as repeated misses" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="md.obsidian" \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-fail.txt 2>&1; then
  echo "trace eval self-test expected Obsidian app gate to fail" >&2
  cat /tmp/autocomplete-trace-eval-self-test-fail.txt >&2
  exit 1
fi

if ! grep -F "md.obsidian: accepted suggestion" /tmp/autocomplete-trace-eval-self-test-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain the missing accepted suggestion" >&2
  cat /tmp/autocomplete-trace-eval-self-test-fail.txt >&2
  exit 1
fi

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_EXPERIMENT_ARM="length_1_word" \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-arm.txt

if ! grep -F "length_1_word: 4" /tmp/autocomplete-trace-eval-self-test-arm.txt >/dev/null; then
  echo "trace eval self-test did not pass the experiment-arm gate" >&2
  cat /tmp/autocomplete-trace-eval-self-test-arm.txt >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_REQUIRE_EXPERIMENT_ARM="missing_arm" \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-arm-fail.txt 2>&1; then
  echo "trace eval self-test expected the experiment-arm gate to fail" >&2
  cat /tmp/autocomplete-trace-eval-self-test-arm-fail.txt >&2
  exit 1
fi

if ! grep -F "missing_arm: suggestionPresented" /tmp/autocomplete-trace-eval-self-test-arm-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain the missing experiment arm" >&2
  cat /tmp/autocomplete-trace-eval-self-test-arm-fail.txt >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.apple.TextEdit" \
   AUTOCOMPLETE_LAB_TRACE_REQUIRE_SUPPORT_STATE="caveated" \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-support-fail.txt 2>&1; then
  echo "trace eval self-test expected the support-state gate to fail" >&2
  cat /tmp/autocomplete-trace-eval-self-test-support-fail.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit: support state experimental below caveated" /tmp/autocomplete-trace-eval-self-test-support-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain the low support state" >&2
  cat /tmp/autocomplete-trace-eval-self-test-support-fail.txt >&2
  exit 1
fi

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_START_LINE=3 \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-slice.txt

if ! grep -F "Start line: 3" /tmp/autocomplete-trace-eval-self-test-slice.txt >/dev/null; then
  echo "trace eval self-test did not honor AUTOCOMPLETE_LAB_TRACE_START_LINE" >&2
  cat /tmp/autocomplete-trace-eval-self-test-slice.txt >&2
  exit 1
fi

cat >"$UNRECOVERED_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"failed","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","hasCaretRect":"true","placementConfidenceBand":"high"}}
{"type":"suggestionAccepted","suggestionID":"failed","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"insertionFailed","suggestionID":"failed","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","reason":"verification-failed"}
JSONL

if AUTOCOMPLETE_LAB_TRACE_PATH="$UNRECOVERED_TRACE_FILE" \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-insertion-fail.txt 2>&1; then
  echo "trace eval self-test expected explicit trace path insertion failure to fail" >&2
  cat /tmp/autocomplete-trace-eval-self-test-insertion-fail.txt >&2
  exit 1
fi

if ! grep -F "unrecovered insertion failure" /tmp/autocomplete-trace-eval-self-test-insertion-fail.txt >/dev/null; then
  echo "trace eval self-test did not report unrecovered insertion failure" >&2
  cat /tmp/autocomplete-trace-eval-self-test-insertion-fail.txt >&2
  exit 1
fi

if [[ "$(AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" script/trace_mark.sh --quiet)" != "28" ]]; then
  echo "trace mark self-test did not report the current trace line" >&2
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" script/trace_mark.sh >&2
  exit 1
fi

MARK_FILE="$(mktemp)"
AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --save >/tmp/autocomplete-trace-mark-save.txt

if ! grep -F "Saved trace mark: 28" /tmp/autocomplete-trace-mark-save.txt >/dev/null; then
  echo "trace mark self-test did not save the current trace line" >&2
  cat /tmp/autocomplete-trace-mark-save.txt >&2
  exit 1
fi

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --eval >/tmp/autocomplete-trace-mark-empty.txt

if ! grep -F "No new trace events since the saved mark." /tmp/autocomplete-trace-mark-empty.txt >/dev/null; then
  echo "trace mark self-test did not explain an empty dogfood slice" >&2
  cat /tmp/autocomplete-trace-mark-empty.txt >&2
  exit 1
fi

printf "0\n" >"$MARK_FILE"
AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --eval com.apple.TextEdit >/tmp/autocomplete-trace-mark-eval.txt

if ! grep -F "Start line: 0" /tmp/autocomplete-trace-mark-eval.txt >/dev/null; then
  echo "trace mark self-test did not evaluate from the saved mark" >&2
  cat /tmp/autocomplete-trace-mark-eval.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit: 100% (1/1)" /tmp/autocomplete-trace-mark-eval.txt >/dev/null; then
  echo "trace mark self-test did not pass the app gate through" >&2
  cat /tmp/autocomplete-trace-mark-eval.txt >&2
  exit 1
fi

echo "Trace eval self-test passed."
