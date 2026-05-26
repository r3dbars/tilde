#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PATH="$TMP_DIR/traces.jsonl"
SHORT_PHRASE_TRACE_PATH="$TMP_DIR/short-phrase-traces.jsonl"
MODEL_ONLY_PHRASE_TRACE_PATH="$TMP_DIR/model-only-phrase-traces.jsonl"
SLOW_INSTANT_TRACE_PATH="$TMP_DIR/slow-instant-traces.jsonl"
TRUST_KILLER_TRACE_PATH="$TMP_DIR/trust-killer-traces.jsonl"
MARK_PATH="$TMP_DIR/session.env"
REPORT_PATH="$TMP_DIR/report.md"
LOW_REPORT_PATH="$TMP_DIR/low-report.md"
LOW_OVERRIDE_REPORT_PATH="$TMP_DIR/low-override-report.md"
HIGH_SCORE_REPORT_PATH="$TMP_DIR/high-score-report.md"
REACH_REPORT_PATH="$TMP_DIR/reach-report.md"
SHORT_PHRASE_REPORT_PATH="$TMP_DIR/short-phrase-report.md"
MODEL_ONLY_PHRASE_REPORT_PATH="$TMP_DIR/model-only-phrase-report.md"
SLOW_INSTANT_REPORT_PATH="$TMP_DIR/slow-instant-report.md"
TRUST_KILLER_REPORT_PATH="$TMP_DIR/trust-killer-report.md"
NOT_READY_MARK_PATH="$TMP_DIR/not-ready-session.env"
NOT_READY_REPORT_PATH="$TMP_DIR/not-ready-report.md"
REVIEW_PASS_REPORT_PATH="$TMP_DIR/review-pass-report.md"
REVIEW_FAIL_REPORT_PATH="$TMP_DIR/review-fail-report.md"
REVIEW_UNSAFE_REPORT_PATH="$TMP_DIR/review-unsafe-report.md"
REVIEW_LOW_QUALITY_REPORT_PATH="$TMP_DIR/review-low-quality-report.md"
REVIEW_APP_MISMATCH_REPORT_PATH="$TMP_DIR/review-app-mismatch-report.md"
REVIEW_LOW_MINUTES_REPORT_PATH="$TMP_DIR/review-low-minutes-report.md"
REVIEW_BAD_PLACEMENT_REPORT_PATH="$TMP_DIR/review-bad-placement-report.md"
PREVIEW_MARK_PATH="$TMP_DIR/preview-session.env"
TRUST_PREVIEW_TRACE_PATH="$TMP_DIR/trust-preview-traces.jsonl"
TRUST_PREVIEW_MARK_PATH="$TMP_DIR/trust-preview-session.env"

export AUTOCOMPLETE_LAB_STEADYTYPE_STATUS_OVERRIDE=running

cat >"$TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:00:00Z","sessionID":"old","suggestionID":"old","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":200}
{"timestamp":"2026-05-25T00:01:00Z","sessionID":"s","suggestionID":"s1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":0,"metadata":{"candidateSelectionSource":"predictive-phrase-fallback","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"4","supportState":"supported"}}
{"timestamp":"2026-05-25T00:01:01Z","sessionID":"s","suggestionID":"s1","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:02Z","sessionID":"s","suggestionID":"s1","type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1"}}
{"timestamp":"2026-05-25T00:01:12Z","sessionID":"s","suggestionID":"s1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","metadata":{"acceptanceID":"a1","checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true"}}
{"timestamp":"2026-05-25T00:02:00Z","sessionID":"s","suggestionID":"s2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":220,"metadata":{"candidateSelectionSource":"app-model-result","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
{"timestamp":"2026-05-25T00:02:10Z","sessionID":"s","suggestionID":"s2","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"escape-dismissed"}
{"timestamp":"2026-05-25T00:03:00Z","sessionID":"s","suggestionID":"s3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":0,"metadata":{"candidateSelectionSource":"predictive-phrase-fallback","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"5","supportState":"supported"}}
{"timestamp":"2026-05-25T00:03:20Z","sessionID":"s","suggestionID":"s3","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"typed-against-visible-suggestion"}
{"timestamp":"2026-05-25T00:04:00Z","sessionID":"s","suggestionID":"s4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","latencyMilliseconds":240,"metadata":{"candidateSelectionSource":"fast-word-completion","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"1","supportState":"supported"}}
{"timestamp":"2026-05-25T00:04:15Z","sessionID":"s","suggestionID":"s4","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"field-changed"}
{"timestamp":"2026-05-25T00:05:00Z","sessionID":"s","suggestionID":"q1","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","triggerReason":"model-result","reason":"empty-suggestion","metadata":{"candidateSelectionSource":"app-model-result","fieldKind":"plain"}}
{"timestamp":"2026-05-25T00:05:10Z","sessionID":"s","suggestionID":"q2","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","triggerReason":"predictive-phrase-fallback","reason":"no-suggestion","metadata":{"candidateSelectionSource":"predictive-phrase-fallback","fieldKind":"plain"}}
{"timestamp":"2026-05-25T00:05:20Z","sessionID":"s","suggestionID":"q3","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","triggerReason":"predictive-phrase-fallback","reason":"fast-phrase-learning-restraint","metadata":{"candidateSelectionSource":"predictive-phrase-fallback","fieldKind":"plain","fastPhraseFallbackLearningSuppressed":"true","acceptedAndKeptSamples":"6","acceptedAndKeptRejected":"6"}}
{"timestamp":"2026-05-25T00:06:10Z","sessionID":"s","suggestionID":"s5","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","latencyMilliseconds":250,"metadata":{"candidateSelectionSource":"app-model-result","effectiveRenderMode":"inlineAdjacent","fieldKind":"plain","visibleWordCount":"3","supportState":"supported"}}
JSONL

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" start \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  --app com.apple.TextEdit \
  --label self-test \
  >"$TMP_DIR/start.out"

for expected in \
  "Trace exists: yes" \
  "SteadyType app: running" \
  "Dogfood readiness: pass"
do
  if ! grep -q "$expected" "$TMP_DIR/start.out"; then
    echo "dogfood self-test start output missing: $expected" >&2
    exit 1
  fi
done

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
  "SteadyType app: running" \
  "Dogfood readiness: pass" \
  "Saved mark: none" \
  "Session state: start-needed" \
  "Sample gate preview: start-needed" \
  "Trust-killer preview: start-needed" \
  "Typing feel preview: start-needed" \
  "Next command: ./script/daily_driver_dogfood_session.sh start --app com.apple.TextEdit" \
  "Review command after report: ./script/daily_driver_dogfood_session.sh review --report <report-path>"
do
  if ! grep -q "$expected" "$TMP_DIR/status-no-mark.out"; then
    echo "dogfood self-test status without mark missing: $expected" >&2
    exit 1
  fi
done

if ! AUTOCOMPLETE_LAB_STEADYTYPE_STATUS_OVERRIDE=not-running "$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$TMP_DIR/missing-session.env" \
  --app com.apple.TextEdit \
  >"$TMP_DIR/status-not-running.out"; then
  echo "dogfood self-test expected not-running status preflight to pass" >&2
  exit 1
fi

for expected in \
  "SteadyType app: not-running" \
  "Dogfood readiness: attention" \
  "Dogfood readiness next: ./script/build_and_run.sh --verify" \
  "Next command: ./script/daily_driver_dogfood_session.sh start --app com.apple.TextEdit"
do
  if ! grep -q "$expected" "$TMP_DIR/status-not-running.out"; then
    echo "dogfood self-test not-running status missing: $expected" >&2
    exit 1
  fi
done

if ! grep -q "START_LINE=15" "$MARK_PATH"; then
  echo "dogfood self-test did not save current start line" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$MARK_PATH" \
  >"$TMP_DIR/status-marked.out"

for expected in \
  "Trace exists: yes" \
  "SteadyType app: running" \
  "Dogfood readiness: pass" \
  "Saved mark: 15" \
  "Label: self-test" \
  "App filter: com.apple.TextEdit" \
  "App status at start: running" \
  "Trace existed at start: yes" \
  "Start readiness: pass" \
  "New trace rows: 0" \
  "Session state: marked-no-new-rows" \
  "Sample gate preview: waiting-for-new-rows" \
  "Trust-killer preview: waiting-for-new-rows" \
  "Typing feel preview: waiting-for-new-rows" \
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
  printf "APP_STATUS_AT_START=%q\n" "running"
  printf "TRACE_EXISTS_AT_START=%q\n" "yes"
  printf "DOGFOOD_READINESS_AT_START=%q\n" "pass"
} >"$PREVIEW_MARK_PATH"

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRACE_PATH" \
  --mark-file "$PREVIEW_MARK_PATH" \
  >"$TMP_DIR/status-preview.out"

for expected in \
  "SteadyType app: running" \
  "Dogfood readiness: pass" \
  "Saved mark: 1" \
  "App status at start: running" \
  "Trace existed at start: yes" \
  "Start readiness: pass" \
  "New trace rows: 14" \
  "Session state: ready-to-finish" \
  "Sample gate preview: pass" \
  "Daily-driver sample gate" \
  "Privacy: redacted metadata counts only" \
  "Rows scanned: 14" \
  "Shown suggestions: 5 (minimum 5)" \
  "Phrase suggestions: 4 (minimum 1)" \
  "Instant phrase fallback shown: 2 (minimum 1)" \
  "Instant phrase max latency: 0ms (maximum 1ms)" \
  "Instant phrase latency samples missing: 0" \
  "Accepted-kept shown rate: 20% (minimum 15%, 1/5)" \
  "Source mix: shown / accepted / accepted-kept shown" \
  "Instant phrase learned restraint: 1" \
  "No-show summary: suggestionSuppressed events by reason" \
  "Trust-killer preview: pass" \
  "Daily-driver trust-killer gate" \
  "Trust-killer counts:" \
  "Insertion Failures: 0" \
  "Typing feel preview: pass" \
  "Typing feel score report" \
  "Typing feel score:" \
  "Main drags:" \
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

cp "$TRACE_PATH" "$TRUST_PREVIEW_TRACE_PATH"
cat >>"$TRUST_PREVIEW_TRACE_PATH" <<'JSONL'
{"timestamp":"2026-05-25T00:06:20Z","sessionID":"s","suggestionID":"bad-insert","type":"insertionFailed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"phraseContinuation","reason":"verification-failed","metadata":{"fieldKind":"plain"}}
JSONL
{
  printf "START_LINE=%q\n" "1"
  printf "STARTED_AT=%q\n" "2026-05-25T00:00:00Z"
  printf "LABEL=%q\n" "trust-preview"
  printf "APP_FILTER=%q\n" "com.apple.TextEdit"
  printf "TRACE_PATH_AT_START=%q\n" "$TRUST_PREVIEW_TRACE_PATH"
  printf "APP_STATUS_AT_START=%q\n" "running"
  printf "TRACE_EXISTS_AT_START=%q\n" "yes"
  printf "DOGFOOD_READINESS_AT_START=%q\n" "pass"
} >"$TRUST_PREVIEW_MARK_PATH"

if ! "$ROOT_DIR/script/daily_driver_dogfood_session.sh" status \
  --trace "$TRUST_PREVIEW_TRACE_PATH" \
  --mark-file "$TRUST_PREVIEW_MARK_PATH" \
  --app com.apple.TextEdit \
  >"$TMP_DIR/status-trust-preview.out"; then
  echo "dogfood self-test expected trust-killer status preview to pass as a preflight" >&2
  exit 1
fi

for expected in \
  "Sample gate preview: pass" \
  "Trust-killer preview: fail" \
  "Daily-driver trust-killer gate" \
  "Trust-killer counts:" \
  "Insertion Failures: 1" \
  "Typing feel preview: fail" \
  "Typing feel score report" \
  "Insertion failures: 1" \
  "Main drags: 1 insertion failure(s)" \
  "Result: fail" \
  "insertion failures (1)" \
  "Next command: ./script/daily_driver_dogfood_session.sh finish --app com.apple.TextEdit"
do
  if ! grep -q "$expected" "$TMP_DIR/status-trust-preview.out"; then
    echo "dogfood self-test trust-killer status preview missing: $expected" >&2
    exit 1
  fi
done

if grep -q "displayedText\\|acceptedText\\|rawOutput" "$TMP_DIR/status-trust-preview.out"; then
  echo "dogfood self-test trust-killer status preview leaked raw trace text keys" >&2
  exit 1
fi

"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --mark-file "$PREVIEW_MARK_PATH" \
  --end-line 15 \
  --app com.apple.TextEdit \
  --label self-test \
  --report "$REPORT_PATH"

for expected in \
  "Daily Driver Dogfood Session" \
  "Gate: \`pass\`" \
  "Start readiness status: \`0\`" \
  "SteadyType app at start: \`running\`" \
  "Trace existed at start: \`yes\`" \
  "Start readiness: \`pass\`" \
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
  "Instant phrase minimum: shown \`1\`, latency <= \`1\` ms." \
  "Phrase suggestions missing word count: 0" \
  "Phrase suggestions below word minimum: 0" \
  "Accepted-kept suggestions: 1 (minimum 1)" \
  "Accepted-kept shown rate: 20% (minimum 15%, 1/5)" \
  "Source mix: shown / accepted / accepted-kept shown" \
  "predictive-phrase-fallback: 2 / 1 / 1" \
  "app-model-result: 2 / 0 / 0" \
  "fast-word-completion: 1 / 0 / 0" \
  "Instant phrase fallback shown: 2 (minimum 1)" \
  "Instant phrase max latency: 0ms (maximum 1ms)" \
  "Instant phrase latency samples missing: 0" \
  "Instant phrase learned restraint: 1" \
  "Model-backed shown: 2" \
  "Word fallback shown: 1" \
  "Unknown source shown: 0" \
  "No-show summary: suggestionSuppressed events by reason" \
  "empty-suggestion: 1" \
  "no-suggestion: 1" \
  "fast-phrase-learning-restraint: 1" \
  "No-show triggers: suggestionSuppressed events by trigger" \
  "model-result: 1" \
  "predictive-phrase-fallback: 2" \
  "Typing Feel Score" \
  "Typing feel score report" \
  "Non-Annoyance Gate" \
  "Trace Eval" \
  "Manual Trust Row" \
  "Completed Report Review" \
  "daily_driver_dogfood_session.sh review --report" \
  "Fresh lines: \`2-15\`"
do
  if ! grep -q "$expected" "$REPORT_PATH"; then
    echo "dogfood self-test report missing: $expected" >&2
    exit 1
  fi
done

{
  printf "START_LINE=%q\n" "1"
  printf "STARTED_AT=%q\n" "2026-05-25T00:00:00Z"
  printf "LABEL=%q\n" "not-ready"
  printf "APP_FILTER=%q\n" "com.apple.TextEdit"
  printf "TRACE_PATH_AT_START=%q\n" "$TRACE_PATH"
  printf "APP_STATUS_AT_START=%q\n" "not-running"
  printf "TRACE_EXISTS_AT_START=%q\n" "yes"
  printf "DOGFOOD_READINESS_AT_START=%q\n" "attention"
} >"$NOT_READY_MARK_PATH"

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$TRACE_PATH" \
  --mark-file "$NOT_READY_MARK_PATH" \
  --end-line 15 \
  --app com.apple.TextEdit \
  --label self-test-not-ready \
  --report "$NOT_READY_REPORT_PATH" \
  >"$TMP_DIR/not-ready.out" 2>&1
not_ready_status=$?
set -e

if [[ "$not_ready_status" -eq 0 ]]; then
  echo "dogfood self-test expected not-ready start slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Start readiness status: \`1\`" \
  "SteadyType app at start: \`not-running\`" \
  "Start readiness: \`attention\`" \
  "Start Readiness Gate" \
  "SteadyType was not confirmed running when the dogfood session started"
do
  if ! grep -q "$expected" "$NOT_READY_REPORT_PATH"; then
    echo "dogfood self-test not-ready report missing: $expected" >&2
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
  --end-line 15 \
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

sed 's/predictive-phrase-fallback/app-model-result/g' "$TRACE_PATH" >"$MODEL_ONLY_PHRASE_TRACE_PATH"
set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$MODEL_ONLY_PHRASE_TRACE_PATH" \
  --start-line 1 \
  --end-line 15 \
  --app com.apple.TextEdit \
  --label self-test-model-only-phrase \
  --report "$MODEL_ONLY_PHRASE_REPORT_PATH" \
  >"$TMP_DIR/model-only-phrase.out" 2>&1
model_only_phrase_status=$?
set -e

if [[ "$model_only_phrase_status" -eq 0 ]]; then
  echo "dogfood self-test expected model-only phrase slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`1\`" \
  "Phrase suggestions: 4 (minimum 1)" \
  "Instant phrase fallback shown: 0 (minimum 1)" \
  "Instant phrase max latency: n/a (maximum 1ms)" \
  "instant phrase fallback below minimum (0/1)"
do
  if ! grep -q "$expected" "$MODEL_ONLY_PHRASE_REPORT_PATH"; then
    echo "dogfood self-test model-only phrase report missing: $expected" >&2
    exit 1
  fi
done

sed 's/"latencyMilliseconds":0/"latencyMilliseconds":5/g' "$TRACE_PATH" >"$SLOW_INSTANT_TRACE_PATH"
set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" finish \
  --trace "$SLOW_INSTANT_TRACE_PATH" \
  --start-line 1 \
  --end-line 15 \
  --app com.apple.TextEdit \
  --label self-test-slow-instant \
  --report "$SLOW_INSTANT_REPORT_PATH" \
  >"$TMP_DIR/slow-instant.out" 2>&1
slow_instant_status=$?
set -e

if [[ "$slow_instant_status" -eq 0 ]]; then
  echo "dogfood self-test expected slow instant phrase slice to fail" >&2
  exit 1
fi

for expected in \
  "Gate: \`fail\`" \
  "Sample gate status: \`1\`" \
  "Instant phrase fallback shown: 2 (minimum 1)" \
  "Instant phrase max latency: 5ms (maximum 1ms)" \
  "instant phrase latency above maximum (5/1 ms)"
do
  if ! grep -q "$expected" "$SLOW_INSTANT_REPORT_PATH"; then
    echo "dogfood self-test slow instant report missing: $expected" >&2
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
  --end-line 16 \
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
- App filter: `com.apple.TextEdit`.
- Sample minimums: shown `5`, phrase shown `1`, accepted `1`, accepted-kept `1`, active minutes `5`.

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
  "App filter: com.apple.TextEdit" \
  "Did reach for it: yes" \
  "Active minute minimum: 5" \
  "Suggestion quality: 5" \
  "Keep it on tomorrow: yes" \
  "Result: pass"
do
  if ! grep -q "$expected" "$TMP_DIR/review-pass.out"; then
    echo "dogfood self-test review pass output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_APP_MISMATCH_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.
- App filter: `com.apple.TextEdit`.
- Sample minimums: shown `5`, phrase shown `1`, accepted `1`, accepted-kept `1`, active minutes `5`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| md.obsidian | 12 | yes | 5 | predicted useful next words | none | aligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_APP_MISMATCH_REPORT_PATH" \
  >"$TMP_DIR/review-app-mismatch.out" 2>&1
review_app_mismatch_status=$?
set -e

if [[ "$review_app_mismatch_status" -eq 0 ]]; then
  echo "dogfood self-test expected app mismatch manual review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "App filter: com.apple.TextEdit" \
  "App: md.obsidian" \
  "manual app must match the report app filter"
do
  if ! grep -q "$expected" "$TMP_DIR/review-app-mismatch.out"; then
    echo "dogfood self-test app mismatch review output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_LOW_MINUTES_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.
- App filter: `com.apple.TextEdit`.
- Sample minimums: shown `5`, phrase shown `1`, accepted `1`, accepted-kept `1`, active minutes `5`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 3 | yes | 5 | predicted useful next words | none | aligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_LOW_MINUTES_REPORT_PATH" \
  >"$TMP_DIR/review-low-minutes.out" 2>&1
review_low_minutes_status=$?
set -e

if [[ "$review_low_minutes_status" -eq 0 ]]; then
  echo "dogfood self-test expected low minutes manual review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "Minutes: 3" \
  "Active minute minimum: 5" \
  "manual minutes must meet active session minimum (5)"
do
  if ! grep -q "$expected" "$TMP_DIR/review-low-minutes.out"; then
    echo "dogfood self-test low minutes review output missing: $expected" >&2
    exit 1
  fi
done

cat >"$REVIEW_BAD_PLACEMENT_REPORT_PATH" <<'MD'
# Daily Driver Dogfood Session

This report is redacted. It should contain trace metadata and manual labels only.

## Summary

- Gate: `pass`.
- Safety snapshot status: `0`.
- Trust-killer gate status: `0`.
- Prompt no-submit safety status: `0`.
- Sensitive field safety status: `0`.
- App filter: `com.apple.TextEdit`.
- Sample minimums: shown `5`, phrase shown `1`, accepted `1`, accepted-kept `1`, active minutes `5`.

## Manual Trust Row

| App | Minutes | Did I reach for it? | Suggestion quality (1-5) | Magic moment | Annoying moment | Placement trust | Keep it on tomorrow? |
| --- | ---: | --- | ---: | --- | --- | --- | --- |
| com.apple.TextEdit | 12 | yes | 5 | predicted useful next words | none | weird and misaligned | yes |
MD

set +e
"$ROOT_DIR/script/daily_driver_dogfood_session.sh" review \
  --report "$REVIEW_BAD_PLACEMENT_REPORT_PATH" \
  >"$TMP_DIR/review-bad-placement.out" 2>&1
review_bad_placement_status=$?
set -e

if [[ "$review_bad_placement_status" -eq 0 ]]; then
  echo "dogfood self-test expected bad placement manual review to fail" >&2
  exit 1
fi

for expected in \
  "Result: fail" \
  "Placement trust: filled" \
  "manual placement trust must not describe wrong or unstable placement"
do
  if ! grep -q "$expected" "$TMP_DIR/review-bad-placement.out"; then
    echo "dogfood self-test bad placement review output missing: $expected" >&2
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
  --end-line 15 \
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
  --end-line 15 \
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
  "Instant phrase fallback shown: 1 (minimum 0)" \
  "Instant phrase max latency: 0ms (maximum 1ms)" \
  "Instant phrase latency samples missing: 0"
do
  if ! grep -q "$expected" "$LOW_OVERRIDE_REPORT_PATH"; then
    echo "dogfood self-test low-sample override report missing: $expected" >&2
    exit 1
  fi
done

echo "daily_driver_dogfood_session_self_test passed"
