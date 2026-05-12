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

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
2026-05-12T20:00:01Z runtime-warm-start candidate=mlx
2026-05-12T20:00:02Z mlx-model-load-succeeded loadMilliseconds=1800 usesVisionLanguageFactory=false
2026-05-12T20:00:02Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2100
2026-05-12T20:00:02Z runtime readinessAction=none readinessStage=ready state=ready (MLX)
2026-05-12T20:00:03Z diagnostic textBeforeCursor=SECRET-SHOULD-NOT-APPEAR
2026-05-12T20:00:04Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Gemma4E4B/MLX/gemma-4-e4b-4bit nativeRuntimeAvailable=true preferredCandidate=mlx
LOG

for index in 1 2 3 4 5; do
  first=$((70 + index))
  total=$((160 + index * 5))
  shown=$((180 + index * 20))
  tap=$((80 + index))
  {
    echo "2026-05-12T20:00:1${index}Z mlx-completion-timing firstChunkMilliseconds=$first generationMilliseconds=$total maxTokens=9 mode=phraseContinuation totalMilliseconds=$total"
    echo "2026-05-12T20:00:2${index}Z suggestion-presented latencyMilliseconds=$shown requestMode=phraseContinuation traceID=scorecard-$index"
    echo "2026-05-12T20:00:3${index}Z keyboard-event-tap-latency decision=passthrough durationMicros=$tap key=other"
  } >>"$LOG_PATH"
done

cat >>"$LOG_PATH" <<'LOG'
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
  --require-no-egress \
  --min-score 90 \
  >"$TMP_DIR/pass.txt"

for expected in \
  "Overall score:" \
  "Runtime readiness + no egress: 100/100" \
  "Privacy: metadata-only parse; ignored sensitive field values=1" \
  "Latency sample depth: 100/100" \
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
