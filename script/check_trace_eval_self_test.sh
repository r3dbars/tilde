#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0}
{"type":"suggestionAccepted","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"insertionVerified","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","acceptedText":"at"}
{"type":"suggestionPresented","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":120}
JSONL

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.apple.TextEdit" \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test.txt

if ! grep -F "com.apple.TextEdit: 100% (1/1)" /tmp/autocomplete-trace-eval-self-test.txt >/dev/null; then
  echo "trace eval self-test did not report the TextEdit accept rate" >&2
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
AUTOCOMPLETE_LAB_TRACE_START_LINE=3 \
  script/check_trace_eval.sh >/tmp/autocomplete-trace-eval-self-test-slice.txt

if ! grep -F "Start line: 3" /tmp/autocomplete-trace-eval-self-test-slice.txt >/dev/null; then
  echo "trace eval self-test did not honor AUTOCOMPLETE_LAB_TRACE_START_LINE" >&2
  cat /tmp/autocomplete-trace-eval-self-test-slice.txt >&2
  exit 1
fi

echo "Trace eval self-test passed."

