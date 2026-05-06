#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
BAD_TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$BAD_TRACE_FILE"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":120}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":220}
{"type":"suggestionPresented","suggestionID":"three","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":" I   think so. ","latencyMilliseconds":80}
{"type":"suggestionPresented","suggestionID":"four","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"i think so.","latencyMilliseconds":90}
{"type":"suggestionPresented","suggestionID":"five","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"I think so.","latencyMilliseconds":100}
{"type":"suggestionPresented","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100}
{"type":"suggestionPresented","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100}
{"type":"suggestionPresented","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"that works","latencyMilliseconds":100}
{"type":"suggestionAccepted","suggestionID":"six","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","suggestionID":"seven","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionAccepted","suggestionID":"eight","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"that"}
{"type":"suggestionPresented","suggestionID":"nine","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0}
{"type":"suggestionPresented","suggestionID":"ten","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0}
{"type":"suggestionPresented","suggestionID":"eleven","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"ng","latencyMilliseconds":0}
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

if grep -F "3x wordCompletion: ng" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test incorrectly reported typed-through suggestions as repeated misses" >&2
  cat /tmp/autocomplete-trace-eval-self-test.txt >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_MIN_USEFUL_RATE=70 \
   AUTOCOMPLETE_LAB_TRACE_MAX_REPEATED_UNACCEPTED=2 \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-annoyance-fail.txt 2>&1; then
  echo "trace eval self-test expected suggestion annoyance guardrails to fail" >&2
  cat /tmp/autocomplete-trace-eval-annoyance-fail.txt >&2
  exit 1
fi

if ! grep -F "suggestion annoyance guardrail failed" /tmp/autocomplete-trace-eval-annoyance-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain annoyance guardrail failures" >&2
  cat /tmp/autocomplete-trace-eval-annoyance-fail.txt >&2
  exit 1
fi

if ! grep -F "useful rate 64% is below required 70%" /tmp/autocomplete-trace-eval-annoyance-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch low useful rate" >&2
  cat /tmp/autocomplete-trace-eval-annoyance-fail.txt >&2
  exit 1
fi

if ! grep -F "3x repeated unaccepted phraseContinuation suggestion exceeds limit 2" /tmp/autocomplete-trace-eval-annoyance-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch repeated unaccepted suggestions" >&2
  cat /tmp/autocomplete-trace-eval-annoyance-fail.txt >&2
  exit 1
fi

cat >"$BAD_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"repaint","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":80,"metadata":{"visibleWords":"2"}}
{"type":"suggestionPresented","suggestionID":"repaint","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":95,"metadata":{"visibleWords":"3"}}
{"type":"suggestionPresented","suggestionID":"repaint","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":110,"metadata":{"visibleWords":"4"}}
{"type":"suggestionPresented","suggestionID":"repaint","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":125,"metadata":{"visibleWords":"5"}}
{"type":"suggestionPresented","suggestionID":"too-long","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":90,"metadata":{"visibleWords":"6"}}
{"type":"suggestionPresented","suggestionID":"word-too-long","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"visibleWords":"2"}}
JSONL

if AUTOCOMPLETE_LAB_TRACE_PATH="$BAD_TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_ENFORCE_PERFORMANCE=1 \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-performance-fail.txt 2>&1; then
  echo "trace eval self-test expected typing performance guardrails to fail" >&2
  cat /tmp/autocomplete-trace-eval-performance-fail.txt >&2
  exit 1
fi

if ! grep -F "typing performance guardrail failed" /tmp/autocomplete-trace-eval-performance-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain typing performance guardrail failures" >&2
  cat /tmp/autocomplete-trace-eval-performance-fail.txt >&2
  exit 1
fi

if ! grep -F "repaint: phraseContinuation presented 4 times" /tmp/autocomplete-trace-eval-performance-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch excessive streaming repaints" >&2
  cat /tmp/autocomplete-trace-eval-performance-fail.txt >&2
  exit 1
fi

if ! grep -F "too-long: phraseContinuation showed 6 words" /tmp/autocomplete-trace-eval-performance-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch too-long phrase suggestions" >&2
  cat /tmp/autocomplete-trace-eval-performance-fail.txt >&2
  exit 1
fi

if ! grep -F "word-too-long: wordCompletion showed 2 words" /tmp/autocomplete-trace-eval-performance-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch too-long word completions" >&2
  cat /tmp/autocomplete-trace-eval-performance-fail.txt >&2
  exit 1
fi

cat >"$BAD_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"low-place","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":80,"metadata":{"placementConfidenceBand":"low","placementConfidenceScore":"0.40","placementSelfHealingAction":"fallback-floating-mirror"}}
{"type":"suggestionPresented","suggestionID":"missing-place","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{}}
JSONL

if AUTOCOMPLETE_LAB_TRACE_PATH="$BAD_TRACE_FILE" \
   AUTOCOMPLETE_LAB_TRACE_REQUIRE_CONFIDENT_PLACEMENT=1 \
   script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-placement-fail.txt 2>&1; then
  echo "trace eval self-test expected placement confidence guardrails to fail" >&2
  cat /tmp/autocomplete-trace-eval-placement-fail.txt >&2
  exit 1
fi

if ! grep -F "placement confidence guardrail failed" /tmp/autocomplete-trace-eval-placement-fail.txt >/dev/null; then
  echo "trace eval self-test did not explain placement confidence failures" >&2
  cat /tmp/autocomplete-trace-eval-placement-fail.txt >&2
  exit 1
fi

if ! grep -F "low-place: placement confidence low (0.40)" /tmp/autocomplete-trace-eval-placement-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch low-confidence placement" >&2
  cat /tmp/autocomplete-trace-eval-placement-fail.txt >&2
  exit 1
fi

if ! grep -F "missing-place: missing placementConfidenceBand" /tmp/autocomplete-trace-eval-placement-fail.txt >/dev/null; then
  echo "trace eval self-test did not catch missing placement confidence metadata" >&2
  cat /tmp/autocomplete-trace-eval-placement-fail.txt >&2
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
