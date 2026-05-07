#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
BAD_TRACE_FILE="$(mktemp)"
REPORT_FILE="$(mktemp)"
BAD_REPORT_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$BAD_TRACE_FILE" "$REPORT_FILE" "$BAD_REPORT_FILE"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"caret","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"caret","anchorQuality":"trusted","anchorReason":"caretBoundsTrusted","anchorCanPresent":"true","anchorRect":"10,20,0,18","hasCaretRect":"true","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionPresented","suggestionID":"line","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","latencyMilliseconds":100,"metadata":{"anchorSource":"line","anchorQuality":"usableFallback","anchorReason":"lineBoundsFallback","anchorCanPresent":"true","anchorRect":"20,30,140,18","hasCaretRect":"false","hasTextLineRect":"true","hasElementRect":"true","hasWindowRect":"true"}}
{"type":"suggestionSuppressed","suggestionID":"blocked","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","reason":"detached-suggestion-disabled","metadata":{"anchorSource":"none","anchorQuality":"invalid","anchorReason":"detachedAnchorDisallowed","anchorCanPresent":"false","anchorRect":"none","hasCaretRect":"false","hasTextLineRect":"false","hasElementRect":"true","hasWindowRect":"true"}}
JSONL

script/geometry_trace_report.py --trace "$TRACE_FILE" --require-proof >"$REPORT_FILE"

for expected in \
  "Geometry proof failures: 0" \
  "com.apple.TextEdit" \
  "Anchor sources" \
  "md.obsidian" \
  "caret=1" \
  "line=1" \
  "detachedAnchorDisallowed=1"; do
  if ! grep -F "$expected" "$REPORT_FILE" >/dev/null; then
    echo "geometry report self-test missing: $expected" >&2
    cat "$REPORT_FILE" >&2
    exit 1
  fi
done

cat >"$BAD_TRACE_FILE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"bad","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":0,"metadata":{"anchorSource":"window","anchorQuality":"diagnosticsOnly","anchorReason":"windowBoundsDiagnostics","anchorCanPresent":"true","anchorRect":"1,2,400,300","hasWindowRect":"true"}}
JSONL

if script/geometry_trace_report.py --trace "$BAD_TRACE_FILE" --require-proof >"$BAD_REPORT_FILE" 2>&1; then
  echo "geometry report self-test expected unsafe presented window anchor to fail" >&2
  cat "$BAD_REPORT_FILE" >&2
  exit 1
fi

if ! grep -F "presented with window anchor" "$BAD_REPORT_FILE" >/dev/null; then
  echo "geometry report self-test did not explain unsafe window anchor" >&2
  cat "$BAD_REPORT_FILE" >&2
  exit 1
fi

echo "Geometry trace report self-test passed."
