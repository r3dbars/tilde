#!/usr/bin/env bash
set -euo pipefail

TRACE_FILE="$(mktemp)"
trap 'rm -f "$TRACE_FILE"' EXIT

cat >"$TRACE_FILE" <<'JSONL'
{"type":"modelResult","experimentArm":"length_1_word","suggestionID":"one","latencyMilliseconds":40,"metadata":{"cleanedWordCount":"1","firstTokenLatencyMilliseconds":"20"}}
{"type":"suggestionPresented","experimentArm":"length_1_word","suggestionID":"one","latencyMilliseconds":40}
{"type":"suggestionAccepted","experimentArm":"length_1_word","suggestionID":"one"}
{"type":"insertionVerified","experimentArm":"length_1_word","suggestionID":"one"}
{"type":"acceptedTextEdited","experimentArm":"length_1_word","suggestionID":"one","metadata":{"checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true"}}
{"type":"modelResult","experimentArm":"length_3_word","suggestionID":"two","latencyMilliseconds":1300,"metadata":{"cleanedWordCount":"0","firstTokenLatencyMilliseconds":"900"}}
{"type":"suggestionPresented","experimentArm":"length_3_word","suggestionID":"two","latencyMilliseconds":1300}
{"type":"insertionFailed","experimentArm":"length_3_word","suggestionID":"two","reason":"duplicate insertion","metadata":{"duplicateDetected":"true"}}
{"type":"appDisabled","experimentArm":"length_3_word","suggestionID":"app","reason":"manual"}
{"type":"suggestionSuppressed","experimentArm":"length_3_word","suggestionID":"three","reason":"empty-model-result"}
JSONL

script/experiment_report.py \
  --trace "$TRACE_FILE" \
  --tester tester-a \
  --min-shown 2 >/tmp/autocomplete-experiment-report-self-test.txt

if ! grep -F "Experiment report" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test did not print a report header" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "Counterbalanced order for tester-a:" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test did not print counterbalanced order" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "length_1_word: directional" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test did not mark tiny samples as directional" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "length_3_word: directional" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test expected tiny guardrail arm to stay directional" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "p95 latency above 1000ms" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test did not print latency guardrail" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

if ! grep -F "empty-results=1 pre-render-blocked=1" /tmp/autocomplete-experiment-report-self-test.txt >/dev/null; then
  echo "experiment report self-test did not print model quality counters" >&2
  cat /tmp/autocomplete-experiment-report-self-test.txt >&2
  exit 1
fi

echo "Experiment report self-test passed."
