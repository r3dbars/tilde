#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
DIAGNOSTICS_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$DIAGNOSTICS_FILE" /tmp/autocomplete-visual-calibration-report-self-test.txt /tmp/autocomplete-visual-calibration-report-missing.txt' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","displayedText":"violet-model-output","acceptedText":"violet-accepted","screenshotPath":"/tmp/violet-private.png","metadata":{"effectiveRenderMode":"inlineAdjacent","hasCaretRect":"false","learningApplied":"true","learningXOffset":"4.0","learningYOffset":"-2.0","learningVisualOffsetStatus":"applied","learningVisualOffsetReason":"scope-matched","screenshotCaptured":"true","displayLayoutVariant":"vertical-multi-display"}}
{"type":"suggestionPresented","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","displayedText":"later-streamed-raw-text","metadata":{"effectiveRenderMode":"inlineAdjacent","hasCaretRect":"true"}}
{"type":"suggestionPresented","suggestionID":"refused","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","metadata":{"effectiveRenderMode":"inlineAdjacent","hasCaretRect":"true","learningApplied":"false","learningVisualOffsetStatus":"refused","learningVisualOffsetReason":"screen-changed"}}
{"type":"caretGeometryFailed","suggestionID":"two","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","reason":"missing-anchor","metadata":{"effectiveRenderMode":"inlineAdjacent"}}
{"type":"suggestionHidden","suggestionID":"one","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","reason":"stale-geometry-window-changed","metadata":{"effectiveRenderMode":"inlineAdjacent","lifetimeMs":"90","displayLayoutVariant":"vertical-multi-display"}}
JSONL

cat >"$DIAGNOSTICS_FILE" <<'LOG'
2026-05-09T00:00:00Z screenshot-captured app=com.apple.TextEdit path=redacted rect=x=0,y=0,w=100,h=40 screenshotOffsetCorrection=accepted screenshotOffsetCorrectionReason=trusted screenshotOffsetProof=improved screenshotOffsetBeforeDistance=5.0 screenshotOffsetAfterDistance=0.0 screenshotOffsetImprovement=5.0 screenshotOffsetProofPrivacy=geometry-only
2026-05-09T00:00:01Z screenshot-captured app=com.apple.TextEdit path=redacted rect=x=0,y=0,w=100,h=40 screenshotOffsetCorrection=not-detected screenshotOffsetBadDetection=low-contrast screenshotOffsetProof=refused screenshotOffsetProofPrivacy=geometry-only
LOG

script/visual_calibration_report.py \
  --log "$TRACE_FILE" \
  --diagnostics-log "$DIAGNOSTICS_FILE" \
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

if ! grep -F "com.apple.TextEdit / inlineAdjacent: shown=2 caretFailures=1 failureRate=33% missingCaret=1 flicker=1 learningApplied=1 staleGeometryHidden=1 layoutVariants=vertical-multi-display:2 latestOffset=(4.0, -2.0) trustedCorrection=applied:1 refused:1 refusedReasons=screen-changed:1" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not summarize app/render calibration" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "missing-anchor: 1" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not summarize caret failure reasons" >&2
  cat /tmp/autocomplete-visual-calibration-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit: applied=1 refused=1 improved=1 bestImprovement=5.0 refusedReasons=low-contrast:1 badDetections=low-contrast:1 privacy=geometry-only:2" /tmp/autocomplete-visual-calibration-report-self-test.txt >/dev/null; then
  echo "visual calibration report self-test did not summarize screenshot correction proof" >&2
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
