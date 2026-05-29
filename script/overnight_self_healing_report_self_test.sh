#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
LEARNING_FILE="$(mktemp)"
REPORT_FILE="$(mktemp)"
JSON_REPORT_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$LEARNING_FILE" "$REPORT_FILE" "$JSON_REPORT_FILE"' EXIT

cat >"$LEARNING_FILE" <<'JSON'
{
  "com.google.Chrome": {
    "bundleIdentifier": "com.google.Chrome",
    "xOffset": 8,
    "yOffset": -4,
    "renderModeOverride": "inlineAdjacent",
    "screenshotTracingEnabled": false,
    "observations": 9,
    "confidence": 0.86,
    "lastReason": "screenshot-visual-correction",
    "updatedAt": "2026-05-21T02:00:00Z"
  }
}
JSON

cat >"$TRACE_FILE" <<'JSONL'
{"type":"suggestionSuppressed","suggestionID":"slack-one","appBundleIdentifier":"com.tinyspeck.slackmacgap","fieldIdentity":"com.tinyspeck.slackmacgap|pid:10|element:99","requestMode":"wordCompletion","reason":"unsupported-browser-surface","metadata":{"browserSurface":"slack","browserSurfaceDecision":"blocked","fieldKind":"unprovenSurface","blockedSurfaceTextRedacted":"true"}}
{"type":"suggestionSuppressed","suggestionID":"slack-two","appBundleIdentifier":"com.tinyspeck.slackmacgap","fieldIdentity":"com.tinyspeck.slackmacgap|pid:10|element:99","requestMode":"phraseContinuation","reason":"unsupported-browser-surface","metadata":{"browserSurface":"slack","browserSurfaceDecision":"blocked","fieldKind":"unprovenSurface","blockedSurfaceTextRedacted":"true"}}
{"type":"suggestionTypedOver","suggestionID":"notes-one","appBundleIdentifier":"com.apple.Notes","fieldIdentity":"com.apple.Notes|pid:123|element:456","requestMode":"wordCompletion","textBeforeCursor":"private customer sentence","displayedText":"private suggestion","metadata":{"fieldKind":"multilineCompose"}}
{"type":"suggestionHidden","suggestionID":"notes-two","appBundleIdentifier":"com.apple.Notes","fieldIdentity":"com.apple.Notes|pid:123|element:456","requestMode":"wordCompletion","reason":"escape-dismissed","metadata":{"fieldKind":"multilineCompose"}}
{"type":"caretGeometryFailed","suggestionID":"chrome-place-one","appBundleIdentifier":"com.google.Chrome","fieldIdentity":"com.google.Chrome|pid:20|element:7","requestMode":"wordCompletion","reason":"placement-missing-caret","metadata":{"effectiveRenderMode":"floatingMirror","anchorSource":"none","fieldKind":"multilineCompose"}}
{"type":"caretGeometryFailed","suggestionID":"chrome-place-two","appBundleIdentifier":"com.google.Chrome","fieldIdentity":"com.google.Chrome|pid:20|element:7","requestMode":"wordCompletion","reason":"placement-missing-caret","metadata":{"effectiveRenderMode":"floatingMirror","anchorSource":"none","fieldKind":"multilineCompose"}}
{"type":"insertionFailed","suggestionID":"chrome-insert-one","appBundleIdentifier":"com.google.Chrome","fieldIdentity":"com.google.Chrome|pid:20|element:7","requestMode":"wordCompletion","reason":"value-set-failed","metadata":{"insertionMode":"axValueReplacement","failureRecoverability":"recoverable","fieldKind":"multilineCompose"}}
{"type":"insertionFailed","suggestionID":"chrome-insert-two","appBundleIdentifier":"com.google.Chrome","fieldIdentity":"com.google.Chrome|pid:20|element:7","requestMode":"wordCompletion","reason":"value-set-failed","metadata":{"insertionMode":"axValueReplacement","failureRecoverability":"recoverable","fieldKind":"multilineCompose"}}
JSONL

script/compatibility_self_healing_report.py \
  --learning "$LEARNING_FILE" \
  --trace "$TRACE_FILE" \
  >"$REPORT_FILE"

for expected in \
  "Adapter promotion candidates (>= 5 observations, >= 0.75 confidence, trusted visual reason):" \
  "com.google.Chrome: offset=(8.0,-4.0), approxNudges=6, observations=9, confidence=0.86" \
  "Apps that should stay blocked (>= 2 risk events or critical signal):" \
  "com.tinyspeck.slackmacgap: riskEvents=2" \
  "Fields needing quiet mode (>= 2 annoyance signals):" \
  "com.apple.Notes: field=multilineCompose/sha256:" \
  "signals=escape-dismissed=1, typed-over=1" \
  "Repeated placement failures (>= 2 events per cluster):" \
  "com.google.Chrome: render=floatingMirror, reason=placement-missing-caret, count=2" \
  "Insertion failure clusters (>= 2 events per cluster):" \
  "com.google.Chrome: insert=axValueReplacement, reason=value-set-failed, count=2" \
  "Next recommended smoke commands:" \
  "./script/manual_smoke_session.sh chrome --print --visual" \
  "AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP=com.google.Chrome ./script/check_trace_eval.sh" \
  "python3 script/non_annoyance_report.py" \
  "Field identifiers are redacted as sha256 10-character fingerprints when present."; do
  if ! grep -F "$expected" "$REPORT_FILE" >/dev/null; then
    echo "overnight self-healing report missing output: $expected" >&2
    cat "$REPORT_FILE" >&2
    exit 1
  fi
done

for forbidden in \
  "private customer sentence" \
  "private suggestion" \
  "pid:123" \
  "element:456"; do
  if grep -F "$forbidden" "$REPORT_FILE" >/dev/null; then
    echo "overnight self-healing report leaked raw fixture content: $forbidden" >&2
    cat "$REPORT_FILE" >&2
    exit 1
  fi
done

script/compatibility_self_healing_report.py \
  --learning "$LEARNING_FILE" \
  --trace "$TRACE_FILE" \
  --json \
  >"$JSON_REPORT_FILE"

python3 - "$JSON_REPORT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    report = json.load(handle)

if report["reportKind"] != "overnight-self-healing-proof":
    raise SystemExit("JSON report did not identify the overnight proof kind")
if not report["appsThatShouldStayBlocked"]:
    raise SystemExit("JSON report did not include blocked app candidates")
if not report["fieldsNeedingQuietMode"]:
    raise SystemExit("JSON report did not include quiet field candidates")
if not report["repeatedPlacementFailures"]:
    raise SystemExit("JSON report did not include placement failure clusters")
if not report["insertionFailureClusters"]:
    raise SystemExit("JSON report did not include insertion failure clusters")
field = report["fieldsNeedingQuietMode"][0]["field"]
if "/sha256:" not in field:
    raise SystemExit(f"field fingerprint was not redacted: {field}")
payload = json.dumps(report)
for forbidden in ("private customer sentence", "private suggestion", "pid:123", "element:456"):
    if forbidden in payload:
        raise SystemExit(f"JSON report leaked raw fixture content: {forbidden}")
PY

echo "Overnight self-healing report self-test passed."
