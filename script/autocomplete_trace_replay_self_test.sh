#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
WHOLE_OUTPUT="$(mktemp)"
SLICE_OUTPUT="$(mktemp)"
SMOKE_OUTPUT="$(mktemp)"
FROZEN_OUTPUT="$(mktemp)"
HELP_OUTPUT="$(mktemp)"
DIFF_OUTPUT="$(mktemp)"
MARK_FILE="$(mktemp)"
TRACE_MARK_OUTPUT="$(mktemp)"
TRACE_MARK_SMOKE_OUTPUT="$(mktemp)"
trap 'rm -f "$TRACE_FILE" "$WHOLE_OUTPUT" "$SLICE_OUTPUT" "$SMOKE_OUTPUT" "$FROZEN_OUTPUT" "$HELP_OUTPUT" "$DIFF_OUTPUT" "$MARK_FILE" "$TRACE_MARK_OUTPUT" "$TRACE_MARK_SMOKE_OUTPUT"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"timestamp":"2026-05-07T12:00:00Z","type":"suggestionRequested","suggestionID":"stale","requestMode":"phraseContinuation"}
{"timestamp":"2026-05-07T12:00:01Z","sessionID":"session-one","suggestionID":"one","type":"suggestionRequested","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","metadata":{"delayMilliseconds":"180","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:02Z","sessionID":"session-one","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","metadata":{"cleanedCandidateCount":"2","candidateTopScore":"0.950","candidateScoreMargin":"0.090","candidateSuppressionReason":"none","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:03Z","sessionID":"session-one","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","latencyMilliseconds":220,"metadata":{"displayScoreDecision":"display","displayScoreUtility":"0.70","displayScoreStyleFit":"0.40","displayScoreContextFit":"0.50","displayScoreUserAffinity":"0.20","displayScoreRisk":"0.05","displayScoreRepetition":"0.05","displayScoreInstability":"0.05","displayScoreFinal":"1.65","displayScoreAcceptedAndKeptProbability":"0.340","displayScoreAcceptedAndKeptSamples":"0","placementAnchorSource":"caret","placementConfidenceBand":"high","hasCaretRect":"true","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:04Z","sessionID":"session-one","suggestionID":"stale-one","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","reason":"stale-request","metadata":{"traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:05Z","sessionID":"session-one","suggestionID":"one","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","outcome":"acceptNextWord","metadata":{"acceptanceID":"accept-one","acceptMode":"tab","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:06Z","sessionID":"session-one","suggestionID":"one","type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","outcome":"verified","metadata":{"acceptanceID":"accept-one","acceptMode":"tab","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:07Z","sessionID":"session-one","suggestionID":"one","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","metadata":{"acceptanceID":"accept-one","checkpoint":"thirtySeconds","survivalClass":"exactKept","finishReason":"thirty-second-finalized","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
{"timestamp":"2026-05-07T12:00:08Z","sessionID":"session-one","suggestionID":"one","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"com.apple.TextEdit|pid:42|element:7","requestMode":"phraseContinuation","outcome":"ignored","reason":"escape","metadata":{"lifetimeMs":"90","traceProofVersion":"2026-05-07.1","placementProofVersion":"placement-v4","keyCaptureProofVersion":"key-capture-v3","runtimeProofVersion":"runtime-v2"}}
JSONL

if swift run AutocompleteTraceReplay "$TRACE_FILE" >"$WHOLE_OUTPUT" 2>&1; then
  echo "replay self-test expected the whole stale fixture to fail" >&2
  cat "$WHOLE_OUTPUT" >&2
  exit 1
fi

if ! grep -F "[ ] trigger policy replay" "$WHOLE_OUTPUT" >/dev/null; then
  echo "replay self-test did not fail the unsliced stale row" >&2
  cat "$WHOLE_OUTPUT" >&2
  exit 1
fi

swift run AutocompleteTraceReplay --start-line 1 "$TRACE_FILE" >"$SLICE_OUTPUT"

if ! grep -F "[x] trace events loaded: 8 events" "$SLICE_OUTPUT" >/dev/null; then
  echo "replay self-test did not skip the stale row" >&2
  cat "$SLICE_OUTPUT" >&2
  exit 1
fi

if ! grep -F "[x] proof fingerprint freshness: 8/8" "$SLICE_OUTPUT" >/dev/null; then
  echo "replay self-test sliced run did not pass proof fingerprint freshness" >&2
  cat "$SLICE_OUTPUT" >&2
  exit 1
fi

swift run AutocompleteTraceReplay --profile smoke-slice --start-line 1 "$TRACE_FILE" >"$SMOKE_OUTPUT"

if ! grep -F -- "- profile: smoke-slice" "$SMOKE_OUTPUT" >/dev/null; then
  echo "replay self-test smoke-slice run did not select the smoke profile" >&2
  cat "$SMOKE_OUTPUT" >&2
  exit 1
fi

swift run AutocompleteTraceReplay --start-line 1 --end-line 9 "$TRACE_FILE" >"$FROZEN_OUTPUT"

if ! cmp -s "$SLICE_OUTPUT" "$FROZEN_OUTPUT"; then
  echo "replay self-test frozen bounds differed from open-ended slice" >&2
  diff -u "$SLICE_OUTPUT" "$FROZEN_OUTPUT" >&2 || true
  exit 1
fi

swift run AutocompleteTraceReplay --help >"$HELP_OUTPUT"

if ! grep -F "Usage: AutocompleteTraceReplay [--decision-diff] [--one-brain-preview]" "$HELP_OUTPUT" >/dev/null; then
  echo "replay self-test did not print help" >&2
  cat "$HELP_OUTPUT" >&2
  exit 1
fi

CORPUS_FILE="docs/evals/trace-replay-one-brain-suppression-corpus-2026-06-13.jsonl"
if grep -E '"(textBeforeCursor|textAfterCursor|systemPrompt|userPrompt|rawOutput|cleanedVisibleText|displayedText|acceptedText|remainingVisibleText|screenshotPath)"[[:space:]]*:[[:space:]]*"[^"]+"' "$CORPUS_FILE" >/dev/null; then
  echo "replay diff corpus contains raw text, prompt, output, accepted text, or screenshot fields" >&2
  exit 1
fi

script/autocomplete_trace_replay_diff.sh "$CORPUS_FILE" >"$DIFF_OUTPUT"

if ! grep -F -- "- preview brain: one-brain-preview" "$DIFF_OUTPUT" >/dev/null; then
  echo "replay diff self-test did not select one-brain preview" >&2
  cat "$DIFF_OUTPUT" >&2
  exit 1
fi

if ! grep -F -- "- current-vs-preview diffs: 3" "$DIFF_OUTPUT" >/dev/null; then
  echo "replay diff self-test did not report the expected reviewed diff count" >&2
  cat "$DIFF_OUTPUT" >&2
  exit 1
fi

if ! grep -F "suggestion=repetition-hard-veto" "$DIFF_OUTPUT" >/dev/null ||
   ! grep -F "suggestion=learned-restraint-binding" "$DIFF_OUTPUT" >/dev/null ||
   ! grep -F "suggestion=low-kept-hard-gate" "$DIFF_OUTPUT" >/dev/null; then
  echo "replay diff self-test did not include the expected binding-reason rows" >&2
  cat "$DIFF_OUTPUT" >&2
  exit 1
fi

printf "1\n" >"$MARK_FILE"
AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --replay >"$TRACE_MARK_OUTPUT"

if ! grep -F "[x] trace events loaded: 8 events" "$TRACE_MARK_OUTPUT" >/dev/null; then
  echo "replay self-test trace_mark --replay did not use the saved mark" >&2
  cat "$TRACE_MARK_OUTPUT" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_FILE" \
AUTOCOMPLETE_LAB_TRACE_MARK_PATH="$MARK_FILE" \
  script/trace_mark.sh --replay smoke-slice >"$TRACE_MARK_SMOKE_OUTPUT"

if ! grep -F -- "- profile: smoke-slice" "$TRACE_MARK_SMOKE_OUTPUT" >/dev/null; then
  echo "replay self-test trace_mark --replay smoke-slice did not select the smoke profile" >&2
  cat "$TRACE_MARK_SMOKE_OUTPUT" >&2
  exit 1
fi

echo "Autocomplete trace replay self-test passed."
