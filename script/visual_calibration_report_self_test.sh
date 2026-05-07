#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" /tmp/autocomplete-visual-calibration-report-self-test.txt /tmp/autocomplete-visual-calibration-report-missing.txt' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","displayedText":"violet-model-output","acceptedText":"violet-accepted","screenshotPath":"/tmp/violet-private.png","metadata":{"effectiveRenderMode":"inlineAdjacent","hasCaretRect":"false","learningApplied":"true","learningXOffset":"4.0","learningYOffset":"-2.0","screenshotCaptured":"true"}}
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","displayedText":"later-streamed-raw-text","metadata":{"effectiveRenderMode":"inlineAdjacent","hasCaretRect":"true"}}
{"type":"caretGeometryFailed","suggestionID":"two","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","reason":"missing-anchor","metadata":{"effectiveRenderMode":"inlineAdjacent"}}
{"type":"suggestionHidden","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","metadata":{"effectiveRenderMode":"inlineAdjacent","lifetimeMs":"90"}}
JSONL

script/visual_calibration_report.py \
  --log "$TRACE_FILE" \
  --require-app com.apple.TextEdit \
  >/tmp/autocomplete-visual-calibration-report-self-test.txt

if ! grep -F "Visual calibration report (no screenshots required)" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not print the report header" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "Screenshots: not read, linked, or required" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not prove screenshot-free reporting" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit / inlineAdjacent: shown=1 caretFailures=1 failureRate=50% missingCaret=1 flicker=1 learningApplied=1 latestOffset=(4.0, -2.0)" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not summarize app/render calibration" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "missing-anchor: 1" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not summarize caret failure reasons" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if grep -F "violet-model-output" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null \
   || grep -F "violet-accepted" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null \
   || grep -F "/tmp/violet-private.png" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test leaked raw text or screenshot paths" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if script/visual_calibration_report.py \
   --log "$TRACE_FILE" \
   --require-app md.obsidian \
   >/tmp/autocomplete-visual-calibration-report-missing.txt 2>&1; then
  echo "visual calibration report self-test expected missing app gate to fail" >&2
  cat /tmp/autocomplete-visual-calibration-report-missing.txt >&2
  exit 1
fi

if ! grep -F "missing required app in visual calibration slice: md.obsidian" /tmp/autocomplete-visual-calibration-report-missing.txt >/dev/null; then
  echo "visual calibration report self-test did not explain the missing app" >&2
  cat /tmp/autocomplete-visual-calibration-report-missing.txt >&2
  exit 1
fi

echo "Visual calibration report self-test passed."
