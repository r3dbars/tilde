#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
EGRESS_JSON="$TMP_DIR/no-egress.json"
BAD_EGRESS_JSON="$TMP_DIR/bad-egress.json"
RUNTIME_REPORT="$TMP_DIR/runtime-performance.txt"
JSON_OUT="$TMP_DIR/scorecard.json"

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-12T20:00:01Z runtime-warm-start candidate=mlx
2026-05-12T20:00:02Z mlx-model-load-succeeded loadMilliseconds=1800 usesVisionLanguageFactory=false
2026-05-12T20:00:02Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2100
2026-05-12T20:00:02Z runtime readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-12T20:00:03Z diagnostic textBeforeCursor=SECRET-SHOULD-NOT-APPEAR
2026-05-12T20:00:03Z focused-text-poll-latency-slow durationMilliseconds=600
2026-05-12T20:00:03Z keyboard-event-tap-latency-slow durationMicros=20000
2026-05-12T20:00:04Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Gemma4E4B/MLX/gemma-4-e4b-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
LOG

for index in 1 2 3 4 5; do
  first=$((70 + index))
  total=$((160 + index * 5))
  shown=$((100 + index * 10))
  tap=$((80 + index))
  {
    echo "2026-05-12T20:00:1${index}Z mlx-completion-timing firstChunkMilliseconds=$first generationMilliseconds=$total maxTokens=9 mode=phraseContinuation totalMilliseconds=$total"
    echo "2026-05-12T20:00:2${index}Z suggestion-presented latencyMilliseconds=$shown requestMode=phraseContinuation traceID=scorecard-$index"
    echo "2026-05-12T20:00:3${index}Z keyboard-event-tap-latency decision=passthrough durationMicros=$tap key=other"
  } >>"$LOG_PATH"
done

cat >>"$LOG_PATH" <<'LOG'
2026-05-12T20:00:55Z suggestion-blocked latencyMilliseconds=180 reason=replacement-gate requestMode=phraseContinuation traceID=blocked-one triggerReason=model-result
2026-05-12T20:00:56Z suggestion-blocked latencyMilliseconds=220 keptVisibleStreamingSuggestion=true reason=empty-suggestion requestMode=phraseContinuation traceID=blocked-two triggerReason=model-result
2026-05-12T20:00:57Z suggestion-request-cancelled reason=invalidate
2026-05-12T20:01:00Z keyboard-event-tap-latency-summary count=60 maxMicros=120 p50Micros=85 p90Micros=110 p95Micros=115 p99Micros=120 reason=idle
2026-05-12T20:01:01Z focused-text-poll-latency-summary count=60 maxMilliseconds=8 p50Milliseconds=1 p90Milliseconds=3 p95Milliseconds=4 p99Milliseconds=8
LOG

cat >"$EGRESS_JSON" <<'JSON'
{
  "phase": "autocomplete",
  "result": "pass",
  "remote_endpoint_count": 0,
  "unexpected_remote_endpoint_count": 0
}
JSON

cat >"$BAD_EGRESS_JSON" <<'JSON'
{
  "phase": "autocomplete",
  "result": "fail",
  "remote_endpoint_count": 1,
  "unexpected_remote_endpoint_count": 1
}
JSON

cat >"$RUNTIME_REPORT" <<'REPORT'
Runtime performance report
Runtime launch: asset=Qwen3.5-4B-4bit candidate=mlx native=true override=none line=2
Live process: pid=42 cpu=2.5% rss=420MB elapsed=00:01
Battery/energy risk: low (no current risk markers)

Supported local model assets
  qwen35-4b: installed, 1.2 GiB
  qwen35-9b: installed, 2.4 GiB
  qwen3-0.6b: missing, missing
REPORT

./script/performance_scorecard.py \
  --diagnostics-log "$LOG_PATH" \
  --egress-json "$EGRESS_JSON" \
  --runtime-report "$RUNTIME_REPORT" \
  --json-out "$JSON_OUT" \
  --require-no-egress \
  --min-score 90 \
  >"$TMP_DIR/pass.txt"

for expected in \
  "Overall score:" \
  "Runtime readiness + no egress: 100/100" \
  "Privacy: metadata-only parse; ignored sensitive field values=1" \
  "Latency sample depth: 100/100" \
  "Typing responsiveness: 100/100" \
  "Request outcomes: visible=5 blocked=2 cancelled=1 visibleRate=63% lateVisible=0 slowHidden=0 staleHidden=0 keptStreamingVisible=1; visibleLatency n=5 avg=130ms p95=150ms max=150ms; blockedLatency n=2 avg=200ms p95=220ms max=220ms; topBlocked=replacement-gate:1, empty-suggestion:1; topCancelled=invalidate:1" \
  "Request outcome visibility: 100/100" \
  "Event-tap latency: 100/100" \
  "Multi-model evidence: 100/100"; do
  if ! grep -F "$expected" "$TMP_DIR/pass.txt" >/dev/null; then
    echo "performance scorecard self-test missing expected output: $expected" >&2
    cat "$TMP_DIR/pass.txt" >&2
    exit 1
  fi
done

if grep -F "SECRET-SHOULD-NOT-APPEAR" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "performance scorecard leaked a raw diagnostic value" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

python3 - "$JSON_OUT" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1], encoding="utf-8").read())
outcomes = payload["request_outcomes"]
assert outcomes["visible"] == 5
assert outcomes["blocked"] == 2
assert outcomes["cancelled"] == 1
assert outcomes["visible_rate_percent"] == 63
assert outcomes["visible_latency"]["p95"] == 150
assert outcomes["blocked_latency"]["avg"] == 200
assert outcomes["kept_streaming_visible"] == 1
assert outcomes["top_blocked_reasons"][0] == {"reason": "replacement-gate", "count": 1}
PY

if ./script/performance_scorecard.py \
  --diagnostics-log "$LOG_PATH" \
  --runtime-report "$RUNTIME_REPORT" \
  --require-no-egress \
  >"$TMP_DIR/missing-egress.txt" 2>"$TMP_DIR/missing-egress.err"; then
  echo "performance scorecard self-test expected missing no-egress proof to fail" >&2
  exit 1
fi

if ! grep -F "required no-egress proof is missing" "$TMP_DIR/missing-egress.err" >/dev/null; then
  echo "performance scorecard self-test did not explain missing no-egress proof" >&2
  cat "$TMP_DIR/missing-egress.err" >&2
  exit 1
fi

if ./script/performance_scorecard.py \
  --diagnostics-log "$LOG_PATH" \
  --egress-json "$BAD_EGRESS_JSON" \
  --runtime-report "$RUNTIME_REPORT" \
  --require-no-egress \
  >"$TMP_DIR/bad-egress.txt" 2>"$TMP_DIR/bad-egress.err"; then
  echo "performance scorecard self-test expected bad no-egress proof to fail" >&2
  exit 1
fi

if ! grep -F "required no-egress proof is fail" "$TMP_DIR/bad-egress.err" >/dev/null; then
  echo "performance scorecard self-test did not explain bad no-egress proof" >&2
  cat "$TMP_DIR/bad-egress.err" >&2
  exit 1
fi

echo "Performance scorecard self-test passed."
