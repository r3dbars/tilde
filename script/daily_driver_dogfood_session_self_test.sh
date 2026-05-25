#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PATH="$TMP_DIR/traces.jsonl"
MARK_PATH="$TMP_DIR/session.env"
REPORT_PATH="$TMP_DIR/report.md"
LOW_REPORT_PATH="$TMP_DIR/low-report.md"
LOW_OVERRIDE_REPORT_PATH="$TMP_DIR/low-override-report.md"

cat >"$TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:00:00Z","sessionID":"old","suggestionID":"old","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":200}
{"timestamp":"2026-05-25T00:01:00Z","sessionID":"s","suggestionID":"s1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":210,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"4","supportState":"supported"}}
{"timestamp":"2026-05-25T00:01:01Z","sessionID":"s","suggestionID":"s1","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:02Z","sessionID":"s","suggestionID":"s1","type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:12Z","sessionID":"s","suggestionID":"s1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1","checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true"}}
{"timestamp":"2026-05-25T00:02:00Z","sessionID":"s","suggestionID":"s2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":220,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
{"timestamp":"2026-05-25T00:02:10Z","sessionID":"s","suggestionID":"s2","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","reason":"escape-dismissed"}
{"timestamp":"2026-05-25T00:03:00Z","sessionID":"s","suggestionID":"s3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":230,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"5","supportState":"supported"}}
{"timestamp":"2026-05-25T00:03:20Z","sessionID":"s","suggestionID":"s3","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","reason":"typed-against-visible-suggestion"}
{"timestamp":"2026-05-25T00:04:00Z","sessionID":"s","suggestionID":"s4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":240,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"4","supportState":"supported"}}
{"timestamp":"2026-05-25T00:04:15Z","sessionID":"s","suggestionID":"s4","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","outcome":"typed-through"}
{"timestamp":"2026-05-25T00:06:10Z","sessionID":"s","suggestionID":"s5","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":250,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
JSONL

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" start \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  --app com.apple.TextEdit \
  --label self-test \
  >"$TMP_DIR/start.out"

if ! grep -q "START_LINE=12" "$MARK_PATH"; then
  echo "dogfood self-test did not save current start line" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 12 \
  --app com.apple.TextEdit \
  --label self-test \
  --report "$REPORT_PATH"

for expected in \
  "Daily Driver Dogfood Session" \
  "Gate: \`pass\`" \
  "Session Sample Gate" \
  "Sample gate status: \`0\`" \
  "Shown suggestions: 5 (minimum 5)" \
  "Accepted-kept suggestions: 1 (minimum 1)" \
  "Non-Annoyance Gate" \
  "Trace Eval" \
  "Manual Trust Row" \
  "Fresh lines: \`2-12\`"
do
  if ! grep -q "$expected" "$REPORT_PATH"; then
    echo "dogfood self-test report missing: $expected" >&2
    exit 1
  fi
done

if grep -q "displayedText\\|acceptedText\\|rawOutput" "$REPORT_PATH"; then
  echo "dogfood self-test report leaked raw trace text keys" >&2
  exit 1
fi

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 5 \
  --app com.apple.TextEdit \
  --label self-test-low \
  --report "$LOW_REPORT_PATH" \
  >"$TMP_DIR/low.out" 2>&1
low_status=$?
set -e

if [[ "$low_status" -eq 0 ]]; then
  echo "dogfood self-test expected low-sample slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`1\`" \
  "shown suggestions below minimum (1/5)" \
  "active minutes below minimum"
do
  if ! grep -q "$expected" "$LOW_REPORT_PATH"; then
    echo "dogfood self-test low-sample report missing: $expected" >&2
    exit 1
  fi
done

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 5 \
  --app com.apple.TextEdit \
  --label self-test-low-override \
  --report "$LOW_OVERRIDE_REPORT_PATH" \
  --allow-low-sample

for expected in \
  "Gate: \`pass\`" \
  "Sample gate status: \`0\`" \
  "Low-sample override: \`1\`" \
  "Shown suggestions: 1 (minimum 0)"
do
  if ! grep -q "$expected" "$LOW_OVERRIDE_REPORT_PATH"; then
    echo "dogfood self-test low-sample override report missing: $expected" >&2
    exit 1
  fi
done

echo "daily_driver_dogfood_session_self_test passed"
