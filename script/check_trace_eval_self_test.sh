#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":120,"metadata":{"anchorSource":"line","anchorQuality":"usableFallback","anchorReason":"lineBoundsFallback","anchorCanPresent":"true","anchorRect":"20,30,140,18","hasCaretRect":"false","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":220,"metadata":{"anchorSource":"line","anchorQuality":"usableFallback","anchorReason":"lineBoundsFallback","anchorCanPresent":"true","anchorRect":"20,30,140,18","hasCaretRect":"false","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"three","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":" I   think so. ","latencyMilliseconds":80,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"four","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"i think so.","latencyMilliseconds":90,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"five","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"I think so.","latencyMilliseconds":100,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100,"metadata":{"anchorSource":"field","anchorQuality":"usableFallback","anchorReason":"fieldBoundsFallback","anchorCanPresent":"true","anchorRect":"1,2,300,44","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionAccepted","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionPresented","suggestionID":"nine","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"ten","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"eleven","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionHidden","suggestionID":"nine","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionHidden","suggestionID":"ten","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionHidden","suggestionID":"eleven","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","outcome":"typed-through"}
{"type":"suggestionSuppressed","suggestionID":"twelve","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"is","reason":"repeated-miss"}
{"type":"suggestionSuppressed","suggestionID":"thirteen","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"e","reason":"repeated-miss"}
{"type":"suggestionSuppressed","suggestionID":"fourteen","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","reason":"no-fast-word-candidate"}
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

if ! grep -F "com.openai.codex: 67% (6/9)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "wordCompletion: 100% (4/4)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report useful rate by mode" >&2
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

if grep -F "ng" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test incorrectly reported typed-through suggestions as repeated misses" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "Geometry proof:" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report geometry proof" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "presented anchors checked: 11" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not check presented anchor proof" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "failures: 0" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test reported unexpected geometry proof failures" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.openai.codex: caret=3, field=6" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not summarize anchor sources by app" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if ! grep -F "md.obsidian: line=2" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not summarize streamed line anchors" >&2
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

BAD_TRACE_FILE="$(mktemp)"
cat >"$BAD_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"bad","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0}
JSONL

if AUTOCOMPLETE_LAB_TRACE_PATH="$BAD_TRACE_FILE" \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-geometry-fail.txt 2>&1; then
  echo "trace eval self-test expected missing geometry proof to fail" >&2
  cat /tmp/autocomplete-trace-eval-self-test-geometry-fail.txt >&2
  rm -f "$BAD_TRACE_FILE"
  exit 1
fi

if ! grep -F "geometry proof" /tmp/autocomplete-trace-eval-self-test-geometry-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain missing geometry proof" >&2
  cat /tmp/autocomplete-trace-eval-self-test-geometry-fail.txt >&2
  rm -f "$BAD_TRACE_FILE"
  exit 1
fi

rm -f "$BAD_TRACE_FILE"

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_START_LINE=3 \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-slice.txt

if ! grep -F "Start line: 3" /tmp/autocomplete-trace-eval-self-test-slice.txt >/dev/null; then
  echo "trace eval self-test did not honor AUTOCOMPLETE_LAB_TRACE_START_LINE" >&2
  cat /tmp/autocomplete-trace-eval-self-test-slice.txt >&2
  exit 1
fi

if [[ "$(AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" script/trace_mark.sh --quiet)" != "23" ]]; then
  echo "trace mark self-test did not report the current trace line" >&2
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" script/trace_mark.sh >&2
  exit 1
fi

MARK_FILE="$(mktemp)"
AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --save >/tmp/autocomplete-trace-mark-save.txt

if ! grep -F "Saved trace mark: 23" /tmp/autocomplete-trace-mark-save.txt >/dev/null; then
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
