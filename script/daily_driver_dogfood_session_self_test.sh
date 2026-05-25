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
HIGH_SCORE_REPORT_PATH="$TMP_DIR/high-score-report.md"
REACH_REPORT_PATH="$TMP_DIR/reach-report.md"
REVIEW_PASS_REPORT_PATH="$TMP_DIR/review-pass-report.md"
REVIEW_FAIL_REPORT_PATH="$TMP_DIR/review-fail-report.md"
REVIEW_UNSAFE_REPORT_PATH="$TMP_DIR/review-unsafe-report.md"

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
{"timestamp":"2026-05-25T00:04:15Z","sessionID":"s","suggestionID":"s4","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phrase","reason":"field-changed"}
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
  "Safety snapshot status: \`0\`" \
  "Prompt no-submit safety status: \`0\`" \
  "Sensitive field safety status: \`0\`" \
  "Daily Driver Safety Snapshot" \
  "Prompt app proof self-test passed." \
  "Sensitive field proof self-test passed." \
  "Session Sample Gate" \
  "Sample gate status: \`0\`" \
  "Reach minimum: accepted-kept / shown \`15%\`" \
  "Reach Test" \
  "Reach test: accepted-and-kept / shown" \
  "Typing feel status: \`0\`" \
  "Shown suggestions: 5 (minimum 5)" \
  "Accepted-kept suggestions: 1 (minimum 1)" \
  "Accepted-kept shown rate: 20% (minimum 15%, 1/5)" \
  "Typing Feel Score" \
  "Typing feel score report" \
  "Non-Annoyance Gate" \
  "Trace Eval" \
  "Manual Trust Row" \
  "Completed Report Review" \
  "daily_driver_dogfood_session.sh review --report" \
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

cat >"$REVIEW_PASS_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | predicted useful next words | none | aligned | yes |
MD

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_PASS_REPORT_PATH" \
  >"$TMP_DIR/review-pass.out"

for expected in \
  "Daily-driver manual review gate" \
  "Automated gate: pass" \
  "Safety snapshot: pass" \
  "Did reach for it: yes" \
  "Keep it on tomorrow: yes" \
  "Result: pass"
do
  if ! grep -q "$expected" "$TMP_DIR/review-pass.out"; then
    echo "dogfood self-test review pass output missing: $expected" >&2
    exit 1
  fi
done

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REPORT_PATH" \
  >"$TMP_DIR/review-blank.out" 2>&1
review_blank_status=$?
set -e

if [[ "$review_blank_status" -eq 0 ]]; then
  echo "dogfood self-test expected blank manual review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "manual minutes must be greater than 0" \
  "manual reach verdict must be yes/useful" \
  "manual keep-it-on-tomorrow verdict must be yes"
do
  if ! grep -q "$expected" "$TMP_DIR/review-blank.out"; then
    echo "dogfood self-test blank review output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_FAIL_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `fail`.
- Safety snapshot status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | predicted useful next words | none | aligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_FAIL_REPORT_PATH" \
  >"$TMP_DIR/review-fail.out" 2>&1
review_fail_status=$?
set -e

if [[ "$review_fail_status" -eq 0 ]]; then
  echo "dogfood self-test expected failed automated gate review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "automated dogfood gate failed" \
  "automated dogfood gate pass marker missing"
do
  if ! grep -q "$expected" "$TMP_DIR/review-fail.out"; then
    echo "dogfood self-test failed-gate review output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_UNSAFE_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `1`.
- Prompt no-submit safety status: `1`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | predicted useful next words | none | aligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_UNSAFE_REPORT_PATH" \
  >"$TMP_DIR/review-unsafe.out" 2>&1
review_unsafe_status=$?
set -e

if [[ "$review_unsafe_status" -eq 0 ]]; then
  echo "dogfood self-test expected unsafe safety snapshot review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "daily-driver safety snapshot failed" \
  "prompt no-submit safety pass marker missing"
do
  if ! grep -q "$expected" "$TMP_DIR/review-unsafe.out"; then
    echo "dogfood self-test unsafe review output missing: $expected" >&2
    exit 1
  fi
done

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 12 \
  --app com.apple.TextEdit \
  --label self-test-high-score \
  --report "$HIGH_SCORE_REPORT_PATH" \
  --min-typing-feel-score 95 \
  >"$TMP_DIR/high-score.out" 2>&1
high_score_status=$?
set -e

if [[ "$high_score_status" -eq 0 ]]; then
  echo "dogfood self-test expected high typing-feel threshold to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`0\`" \
  "Typing feel status: \`1\`" \
  "Typing feel minimum score: \`95\`"
do
  if ! grep -q "$expected" "$HIGH_SCORE_REPORT_PATH"; then
    echo "dogfood self-test high-score report missing: $expected" >&2
    exit 1
  fi
done

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 12 \
  --app com.apple.TextEdit \
  --label self-test-reach \
  --report "$REACH_REPORT_PATH" \
  --min-kept-per-shown-percent 25 \
  >"$TMP_DIR/reach.out" 2>&1
reach_status=$?
set -e

if [[ "$reach_status" -eq 0 ]]; then
  echo "dogfood self-test expected high reach threshold to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`1\`" \
  "Typing feel status: \`0\`" \
  "Reach minimum: accepted-kept / shown \`25%\`" \
  "accepted-kept shown rate below minimum (20%/25%)"
do
  if ! grep -q "$expected" "$REACH_REPORT_PATH"; then
    echo "dogfood self-test reach report missing: $expected" >&2
    exit 1
  fi
done

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
  "Typing feel status: \`0\`" \
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
  "Typing feel status: \`0\`" \
  "Low-sample override: \`1\`" \
  "Shown suggestions: 1 (minimum 0)" \
  "Accepted-kept shown rate: 100% (minimum 0%, 1/1)"
do
  if ! grep -q "$expected" "$LOW_OVERRIDE_REPORT_PATH"; then
    echo "dogfood self-test low-sample override report missing: $expected" >&2
    exit 1
  fi
done

echo "daily_driver_dogfood_session_self_test passed"
