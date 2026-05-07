#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
LEARNING_FILE="$(mktemp)"
REPORT_FILE="$(mktemp)"
JSON_REPORT_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$LEARNING_FILE" "$REPORT_FILE" "$JSON_REPORT_FILE"' EXIT

cat >"$LEARNING_FILE" <<'JSON'
{
  "com.apple.Notes": {
    "bundleIdentifier": "com.apple.Notes",
    "xOffset": 4,
    "yOffset": -2,
    "renderModeOverride": "inlineAdjacent",
    "screenshotTracingEnabled": false,
    "observations": 6,
    "confidence": 0.45,
    "lastReason": "manual-visual-nudge",
    "updatedAt": "2026-05-07T02:00:00Z"
  },
  "com.apple.TextEdit": {
    "bundleIdentifier": "com.apple.TextEdit",
    "xOffset": 2,
    "yOffset": 0,
    "screenshotTracingEnabled": false,
    "observations": 1,
    "confidence": 0.35,
    "lastReason": "manual-visual-nudge",
    "updatedAt": "2026-05-07T02:00:00Z"
  }
}
JSON

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionSuppressed","suggestionID":"one","appBundleIdentifier":"md.obsidian","requestMode":"wordCompletion","reason":"detached-suggestion-disabled","metadata":{"anchorSource":"none","anchorReason":"detachedAnchorDisallowed"}}
{"type":"suggestionSuppressed","suggestionID":"two","appBundleIdentifier":"md.obsidian","requestMode":"phraseContinuation","reason":"detached-suggestion-disabled","metadata":{"anchorSource":"none","anchorReason":"detachedAnchorDisallowed"}}
{"type":"suggestionSuppressed","suggestionID":"three","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","reason":"detached-suggestion-disabled","metadata":{"anchorSource":"none","anchorReason":"detachedAnchorDisallowed"}}
{"type":"suggestionSuppressed","suggestionID":"four","appBundleIdentifier":"md.obsidian","requestMode":"wordCompletion","reason":"no-fast-word-candidate"}
JSONL

script/compatibility_self_healing_report.py \
  --learning "$LEARNING_FILE" \
  --trace "$TRACE_FILE" \
  >"$REPORT_FILE"

if ! grep -F "com.apple.Notes: offset=(4.0,-2.0), approxNudges=3" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report did not list repeated visual nudges" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if grep -F "com.apple.TextEdit:" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report listed a single visual nudge as repeated" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if ! grep -F "md.obsidian: detachedSuppressions=2" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report did not list repeated detached suppression" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if grep -F "com.openai.codex: detachedSuppressions=1" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report listed a single detached suppression as repeated" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if ! grep -F "recommendation: turn the learned offset into an app/profile calibration fixture" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report did not include visual adapter recommendation" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if ! grep -F "recommendation: keep detached display blocked" "$REPORT_FILE" >/dev/null; then
  echo "compatibility report did not include detached adapter recommendation" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

if ! grep -F "No screenshots, calibration, or new trace capture were started." "$REPORT_FILE" >/dev/null; then
  echo "compatibility report did not state that it is read-only" >&2
  cat "$REPORT_FILE" >&2
  exit 1
fi

script/compatibility_self_healing_report.py \
  --learning "$LEARNING_FILE" \
  --trace "$TRACE_FILE" \
  --start-line 2 \
  --json \
  >"$JSON_REPORT_FILE"

python3 - "$JSON_REPORT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    report = json.load(handle)

if report["startLine"] != 2:
    raise SystemExit("JSON report did not keep the requested trace start line")
if report["detachedSuppressionCandidates"]:
    raise SystemExit("JSON report did not apply the trace start line")
if report["visualNudgeCandidates"][0]["bundleIdentifier"] != "com.apple.Notes":
    raise SystemExit("JSON report did not include the visual nudge candidate")
PY

echo "Compatibility self-healing report self-test passed."
