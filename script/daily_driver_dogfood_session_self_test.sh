#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PATH="$TMP_DIR/traces.jsonl"
SHORT_PHRASE_TRACE_PATH="$TMP_DIR/short-phrase-traces.jsonl"
TRUST_KILLER_TRACE_PATH="$TMP_DIR/trust-killer-traces.jsonl"
MARK_PATH="$TMP_DIR/session.env"
REPORT_PATH="$TMP_DIR/report.md"
LOW_REPORT_PATH="$TMP_DIR/low-report.md"
LOW_OVERRIDE_REPORT_PATH="$TMP_DIR/low-override-report.md"
HIGH_SCORE_REPORT_PATH="$TMP_DIR/high-score-report.md"
REACH_REPORT_PATH="$TMP_DIR/reach-report.md"
SHORT_PHRASE_REPORT_PATH="$TMP_DIR/short-phrase-report.md"
TRUST_KILLER_REPORT_PATH="$TMP_DIR/trust-killer-report.md"
REVIEW_PASS_REPORT_PATH="$TMP_DIR/review-pass-report.md"
REVIEW_FAIL_REPORT_PATH="$TMP_DIR/review-fail-report.md"
REVIEW_UNSAFE_REPORT_PATH="$TMP_DIR/review-unsafe-report.md"
REVIEW_LOW_QUALITY_REPORT_PATH="$TMP_DIR/review-low-quality-report.md"
PREVIEW_MARK_PATH="$TMP_DIR/preview-session.env"

cat >"$TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:00:00Z","sessionID":"old","suggestionID":"old","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":200}
{"timestamp":"2026-05-25T00:01:00Z","sessionID":"s","suggestionID":"s1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":210,"metadata":{"candidateSelectionSource":"predictive-phrase-fallback","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"4","supportState":"supported"}}
{"timestamp":"2026-05-25T00:01:01Z","sessionID":"s","suggestionID":"s1","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:02Z","sessionID":"s","suggestionID":"s1","type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:12Z","sessionID":"s","suggestionID":"s1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1","checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true"}}
{"timestamp":"2026-05-25T00:02:00Z","sessionID":"s","suggestionID":"s2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":220,"metadata":{"candidateSelectionSource":"app-model-result","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
{"timestamp":"2026-05-25T00:02:10Z","sessionID":"s","suggestionID":"s2","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"escape-dismissed"}
{"timestamp":"2026-05-25T00:03:00Z","sessionID":"s","suggestionID":"s3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":230,"metadata":{"candidateSelectionSource":"predictive-phrase-fallback","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"5","supportState":"supported"}}
{"timestamp":"2026-05-25T00:03:20Z","sessionID":"s","suggestionID":"s3","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"typed-against-visible-suggestion"}
{"timestamp":"2026-05-25T00:04:00Z","sessionID":"s","suggestionID":"s4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","latencyMilliseconds":240,"metadata":{"candidateSelectionSource":"fast-word-completion","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"1","supportState":"supported"}}
{"timestamp":"2026-05-25T00:04:15Z","sessionID":"s","suggestionID":"s4","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"field-changed"}
{"timestamp":"2026-05-25T00:05:00Z","sessionID":"s","suggestionID":"q1","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","triggerReason":"model-result","reason":"empty-suggestion","metadata":{"candidateSelectionSource":"app-model-result","fieldKind":"plain"}}
{"timestamp":"2026-05-25T00:05:10Z","sessionID":"s","suggestionID":"q2","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","triggerReason":"predictive-phrase-fallback","reason":"no-suggestion","metadata":{"candidateSelectionSource":"predictive-phrase-fallback","fieldKind":"plain"}}
{"timestamp":"2026-05-25T00:06:10Z","sessionID":"s","suggestionID":"s5","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":250,"metadata":{"candidateSelectionSource":"app-model-result","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
JSONL

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" start \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  --app com.apple.TextEdit \
  --label self-test \
  >"$TMP_DIR/start.out"

if ! "$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$TMP_DIR/missing-session.env" \
  --app com.apple.TextEdit \
  >"$TMP_DIR/status-no-mark.out"; then
  echo "dogfood self-test expected status without mark to pass" >&2
  exit 1
fi

for expected in \
  "Trace exists: yes" \
  "Saved mark: none" \
  "Session state: start-needed" \
  "Sample gate preview: start-needed" \
  "Next command: ./script/daily_driver_dogfood_session.sh start --app com.apple.TextEdit" \
  "Review command after report: ./script/daily_driver_dogfood_session.sh review --report <report-path>"
do
  if ! grep -q "$expected" "$TMP_DIR/status-no-mark.out"; then
    echo "dogfood self-test status without mark missing: $expected" >&2
    exit 1
  fi
done

if ! grep -q "START_LINE=14" "$MARK_PATH"; then
  echo "dogfood self-test did not save current start line" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  >"$TMP_DIR/status-marked.out"

for expected in \
  "Trace exists: yes" \
  "Saved mark: 14" \
  "Label: self-test" \
  "App filter: com.apple.TextEdit" \
  "New trace rows: 0" \
  "Session state: marked-no-new-rows" \
  "Sample gate preview: waiting-for-new-rows" \
  "Next command: ./script/daily_driver_dogfood_session.sh finish --app com.apple.TextEdit"
do
  if ! grep -q "$expected" "$TMP_DIR/status-marked.out"; then
    echo "dogfood self-test marked status missing: $expected" >&2
    exit 1
  fi
done

{
  printf "START_LINE=%q\n" "1"
  printf "STARTED_AT=%q\n" "2026-05-25T00:00:00Z"
  printf "LABEL=%q\n" "preview"
  printf "APP_FILTER=%q\n" "com.apple.TextEdit"
  printf "TRACE_PATH_AT_START=%q\n" "$TRACE_PATH"
} >"$PREVIEW_MARK_PATH"

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$PREVIEW_MARK_PATH" \
  >"$TMP_DIR/status-preview.out"

for expected in \
  "Saved mark: 1" \
  "New trace rows: 13" \
  "Session state: ready-to-finish" \
  "Sample gate preview: pass" \
  "Daily-driver sample gate" \
  "Privacy: redacted metadata counts only" \
  "Rows scanned: 13" \
  "Shown suggestions: 5 (minimum 5)" \
  "Phrase suggestions: 4 (minimum 1)" \
  "Accepted-kept shown rate: 20% (minimum 15%, 1/5)" \
  "Source mix: shown / accepted / accepted-kept shown" \
  "No-show summary: suggestionSuppressed events by reason" \
  "Result: pass" \
  "Next command: ./script/daily_driver_dogfood_session.sh finish --app com.apple.TextEdit"
do
  if ! grep -q "$expected" "$TMP_DIR/status-preview.out"; then
    echo "dogfood self-test preview status missing: $expected" >&2
    exit 1
  fi
done

if grep -q "displayedText\\|acceptedText\\|rawOutput" "$TMP_DIR/status-preview.out"; then
  echo "dogfood self-test status preview leaked raw trace text keys" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --start-line 1 \
  --end-line 14 \
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
  "Trust-killer gate status: \`0\`" \
  "Trust-Killer Gate" \
  "Daily-driver trust-killer gate" \
  "Trust-killer counts:" \
  "Insertion Failures: 0" \
  "Wrong-Context Suppressions: 0" \
  "Caret Geometry Failures: 0" \
  "Sensitive Field Presentations: 0" \
  "Prompt Accidental Submits: 0" \
  "Reach minimum: accepted-kept / shown \`15%\`" \
  "Reach Test" \
  "Reach test: accepted-and-kept / shown" \
  "Typing feel status: \`0\`" \
  "Shown suggestions: 5 (minimum 5)" \
  "Phrase suggestions: 4 (minimum 1)" \
  "Phrase visible word minimum: 3" \
  "Phrase suggestions missing word count: 0" \
  "Phrase suggestions below word minimum: 0" \
  "Accepted-kept suggestions: 1 (minimum 1)" \
  "Accepted-kept shown rate: 20% (minimum 15%, 1/5)" \
  "Source mix: shown / accepted / accepted-kept shown" \
  "predictive-phrase-fallback: 2 / 1 / 1" \
  "app-model-result: 2 / 0 / 0" \
  "fast-word-completion: 1 / 0 / 0" \
  "Instant phrase fallback shown: 2" \
  "Model-backed shown: 2" \
  "Word fallback shown: 1" \
  "Unknown source shown: 0" \
  "No-show summary: suggestionSuppressed events by reason" \
  "empty-suggestion: 1" \
  "no-suggestion: 1" \
  "No-show triggers: suggestionSuppressed events by trigger" \
  "model-result: 1" \
  "predictive-phrase-fallback: 1" \
  "Typing Feel Score" \
  "Typing feel score report" \
  "Non-Annoyance Gate" \
  "Trace Eval" \
  "Manual Trust Row" \
  "Completed Report Review" \
  "daily_driver_dogfood_session.sh review --report" \
  "Fresh lines: \`2-14\`"
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

sed 's/"visibleWordCount":"4"/"visibleWordCount":"2"/' "$TRACE_PATH" >"$SHORT_PHRASE_TRACE_PATH"
set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$SHORT_PHRASE_TRACE_PATH" \
  --start-line 1 \
  --end-line 14 \
  --app com.apple.TextEdit \
  --label self-test-short-phrase \
  --report "$SHORT_PHRASE_REPORT_PATH" \
  >"$TMP_DIR/short-phrase.out" 2>&1
short_phrase_status=$?
set -e

if [[ "$short_phrase_status" -eq 0 ]]; then
  echo "dogfood self-test expected short phrase slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`1\`" \
  "Phrase suggestions: 4 (minimum 1)" \
  "Phrase visible word minimum: 3" \
  "Phrase suggestions below word minimum: 1" \
  "phrase suggestions below visible word minimum (1 below 3 words)"
do
  if ! grep -q "$expected" "$SHORT_PHRASE_REPORT_PATH"; then
    echo "dogfood self-test short-phrase report missing: $expected" >&2
    exit 1
  fi
done

cp "$TRACE_PATH" "$TRUST_KILLER_TRACE_PATH"
cat >>"$TRUST_KILLER_TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:06:20Z","sessionID":"s","suggestionID":"bad-insert","type":"insertionFailed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"verification-failed","metadata":{"fieldKind":"plain"}}
JSONL
set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRUST_KILLER_TRACE_PATH" \
  --start-line 1 \
  --end-line 15 \
  --app com.apple.TextEdit \
  --label self-test-trust-killer \
  --report "$TRUST_KILLER_REPORT_PATH" \
  >"$TMP_DIR/trust-killer.out" 2>&1
trust_killer_status=$?
set -e

if [[ "$trust_killer_status" -eq 0 ]]; then
  echo "dogfood self-test expected trust-killer slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`0\`" \
  "Trust-killer gate status: \`1\`" \
  "Trust-Killer Gate" \
  "Insertion Failures: 1" \
  "Result: fail" \
  "insertion failures (1)"
do
  if ! grep -q "$expected" "$TRUST_KILLER_REPORT_PATH"; then
    echo "dogfood self-test trust-killer report missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_PASS_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | 5 | predicted useful next words | none | aligned | yes |
MD

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_PASS_REPORT_PATH" \
  >"$TMP_DIR/review-pass.out"

for expected in \
  "Daily-driver manual review gate" \
  "Automated gate: pass" \
  "Safety snapshot: pass" \
  "Trust-killer gate: pass" \
  "Did reach for it: yes" \
  "Suggestion quality: 5" \
  "Keep it on tomorrow: yes" \
  "Result: pass"
do
  if ! grep -q "$expected" "$TMP_DIR/review-pass.out"; then
    echo "dogfood self-test review pass output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_LOW_QUALITY_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | 3 | predicted useful next words | none | aligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_LOW_QUALITY_REPORT_PATH" \
  >"$TMP_DIR/review-low-quality.out" 2>&1
review_low_quality_status=$?
set -e

if [[ "$review_low_quality_status" -eq 0 ]]; then
  echo "dogfood self-test expected low quality manual review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "Suggestion quality: 3" \
  "manual suggestion quality score must be 4 or 5"
do
  if ! grep -q "$expected" "$TMP_DIR/review-low-quality.out"; then
    echo "dogfood self-test low quality review output missing: $expected" >&2
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
  "manual suggestion quality score must be 4 or 5" \
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
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | 5 | predicted useful next words | none | aligned | yes |
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
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `1`.
- Sensitive field safety status: `0`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | 5 | predicted useful next words | none | aligned | yes |
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
  --end-line 14 \
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
  --end-line 14 \
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
  "Phrase suggestions: 1 (minimum 0)" \
  "Phrase suggestions below word minimum: 0" \
  "Accepted-kept shown rate: 100% (minimum 0%, 1/1)" \
  "predictive-phrase-fallback: 1 / 1 / 1" \
  "Instant phrase fallback shown: 1"
do
  if ! grep -q "$expected" "$LOW_OVERRIDE_REPORT_PATH"; then
    echo "dogfood self-test low-sample override report missing: $expected" >&2
    exit 1
  fi
done

echo "daily_driver_dogfood_session_self_test passed"
