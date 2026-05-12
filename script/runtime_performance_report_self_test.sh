#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
MODEL_ROOT="$TMP_DIR/Models"
MODEL_PATH="$MODEL_ROOT/Qwen35FourB/MLX/Qwen3.5-4B-4bit"
mkdir -p "$MODEL_PATH"
printf 'model' >"$MODEL_PATH/config.json"

cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z launch accessibility=true
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
2026-05-12T20:00:00Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:00:02Z mlx-model-load-succeeded assetDirectory=/tmp/model loadMilliseconds=1980 usesVisionLanguageFactory=false
2026-05-12T20:00:02Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2100
2026-05-12T20:00:03Z mlx-completion-timing firstChunkMilliseconds=140 mode=phraseContinuation totalMilliseconds=260
2026-05-12T20:00:03Z mlx-completion-timing firstChunkMilliseconds=150 mode=phraseContinuation totalMilliseconds=280
2026-05-12T20:00:03Z suggestion-presented app=com.apple.TextEdit latencyMilliseconds=310 requestMode=phraseContinuation
2026-05-12T20:00:03Z keyboard-event-tap-latency decision=passthrough-other durationMicros=80 key=other
2026-05-12T20:00:04Z focused-text-poll-latency-summary count=60 maxMilliseconds=7 p50Milliseconds=1 p90Milliseconds=2 p95Milliseconds=3 p99Milliseconds=4
2026-05-12T20:00:04Z suggestion-request-cancelled reason=new-request
LOG

OUTPUT="$TMP_DIR/report.txt"
./script/runtime_performance_report.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --no-live-process \
  >"$OUTPUT"

grep -F "Runtime launch: asset=Qwen3.5-4B-4bit candidate=mlx native=true override=none" "$OUTPUT" >/dev/null
grep -F "Warm time: runtime-warm-succeeded 2100ms" "$OUTPUT" >/dev/null
grep -F "Model load time: mlx-model-load-succeeded 1980ms" "$OUTPUT" >/dev/null
grep -F "First token: n=2" "$OUTPUT" >/dev/null
grep -F "In-flight cancellations: 1" "$OUTPUT" >/dev/null
grep -F "Live process: not running" "$OUTPUT" >/dev/null
grep -F "Battery/energy risk: low" "$OUTPUT" >/dev/null
grep -F "qwen35-4b: installed" "$OUTPUT" >/dev/null

echo "Runtime performance report self-test passed."
