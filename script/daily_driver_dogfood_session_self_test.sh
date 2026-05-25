#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PATH="$TMP_DIR/traces.jsonl"
MARK_PATH="$TMP_DIR/session.env"
REPORT_PATH="$TMP_DIR/report.md"

cat >"$TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:00:00Z","sessionID":"old","suggestionID":"old","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":200}
{"timestamp":"2026-05-25T00:01:00Z","sessionID":"s","suggestionID":"s1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","latencyMilliseconds":210,"metadata":{"effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"4","supportState":"supported"}}
{"timestamp":"2026-05-25T00:01:01Z","sessionID":"s","suggestionID":"s1","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:02Z","sessionID":"s","suggestionID":"s1","type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:12Z","sessionID":"s","suggestionID":"s1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","metadata":{"acceptanceID":"a1","checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true"}}
JSONL

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" start \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  --app com.apple.TextEdit \
  --label self-test \
  >"$TMP_DIR/start.out"

if ! grep -q "START_LINE=5" "$MARK_PATH"; then
  echo "dogfood self-test did not save current start line" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 5 \
  --app com.apple.TextEdit \
  --label self-test \
  --report "$REPORT_PATH"

for expected in \
  "Daily Driver Dogfood Session" \
  "Gate: \`pass\`" \
  "Non-Annoyance Gate" \
  "Trace Eval" \
  "Manual Trust Row" \
  "Fresh lines: \`2-5\`"
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

echo "daily_driver_dogfood_session_self_test passed"
