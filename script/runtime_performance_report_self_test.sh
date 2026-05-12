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
2026-05-12T20:00:10Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:00:12Z mlx-model-load-succeeded assetDirectory=/tmp/model loadMilliseconds=2050 usesVisionLanguageFactory=false
2026-05-12T20:00:12Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2200
2026-05-12T20:00:20Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:00:22Z mlx-model-load-succeeded assetDirectory=/tmp/model loadMilliseconds=2200 usesVisionLanguageFactory=false
2026-05-12T20:00:22Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2300
2026-05-12T20:00:30Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:00:32Z mlx-model-load-succeeded assetDirectory=/tmp/model loadMilliseconds=2350 usesVisionLanguageFactory=false
2026-05-12T20:00:32Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2400
2026-05-12T20:00:40Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:00:42Z mlx-model-load-succeeded assetDirectory=/tmp/model loadMilliseconds=2500 usesVisionLanguageFactory=false
2026-05-12T20:00:42Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2500
2026-05-12T20:01:00Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:01:00Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=3 usesVisionLanguageFactory=false
2026-05-12T20:01:00Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=8
2026-05-12T20:01:10Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:01:10Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=4 usesVisionLanguageFactory=false
2026-05-12T20:01:10Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=9
2026-05-12T20:01:20Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:01:20Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=5 usesVisionLanguageFactory=false
2026-05-12T20:01:20Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=10
2026-05-12T20:01:30Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:01:30Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=6 usesVisionLanguageFactory=false
2026-05-12T20:01:30Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=11
2026-05-12T20:01:40Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T20:01:40Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=7 usesVisionLanguageFactory=false
2026-05-12T20:01:40Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=12
2026-05-12T20:00:03Z mlx-completion-timing firstChunkMilliseconds=140 mode=phraseContinuation totalMilliseconds=260
2026-05-12T20:00:03Z mlx-completion-timing firstChunkMilliseconds=150 mode=phraseContinuation totalMilliseconds=280
2026-05-12T20:00:03Z suggestion-presented app=com.apple.TextEdit latencyMilliseconds=310 requestMode=phraseContinuation
2026-05-12T20:00:03Z suggestion-presented app=com.apple.TextEdit latencyMilliseconds=330 requestMode=phraseContinuation
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
grep -F "Latest warm event: runtime-warm-succeeded 12ms" "$OUTPUT" >/dev/null
grep -F "Latest model load event: mlx-model-load-reused 7ms" "$OUTPUT" >/dev/null
grep -F "Cold model load succeeded: n=5 min=1980ms avg=2216ms p50=2200ms p95=2500ms p99=2500ms max=2500ms" "$OUTPUT" >/dev/null
grep -F "Warm model reuse: n=5 min=3ms avg=5ms p50=5ms p95=7ms p99=7ms max=7ms" "$OUTPUT" >/dev/null
grep -F "First token: n=2" "$OUTPUT" >/dev/null
grep -F "In-flight cancellations: 1" "$OUTPUT" >/dev/null
grep -F "Live process: not running" "$OUTPUT" >/dev/null
grep -F "Battery/energy risk: low" "$OUTPUT" >/dev/null
grep -F "No missing core timing samples in this log slice" "$OUTPUT" >/dev/null
grep -F "Privacy: redacted timings/counts only" "$OUTPUT" >/dev/null
grep -F "qwen35-4b: installed" "$OUTPUT" >/dev/null

if grep -F "assetDirectory=" "$OUTPUT" >/dev/null || grep -F "modelDirectory=" "$OUTPUT" >/dev/null; then
  echo "runtime performance report leaked event paths" >&2
  exit 1
fi

MISSING_LOG_PATH="$TMP_DIR/missing-diagnostics.log"
cat >"$MISSING_LOG_PATH" <<'LOG'
2026-05-12T21:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
2026-05-12T21:00:00Z runtime-warm-start candidate=mlx modelDirectory=/tmp/model
2026-05-12T21:00:00Z mlx-model-load-reused assetDirectory=/tmp/model loadMilliseconds=4 usesVisionLanguageFactory=false
2026-05-12T21:00:00Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=9
LOG

MISSING_OUTPUT="$TMP_DIR/missing-report.txt"
./script/runtime_performance_report.py \
  --diagnostics-log "$MISSING_LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --no-live-process \
  >"$MISSING_OUTPUT"

grep -F "Missing cold model load samples; do not score cold-start load time from this report." "$MISSING_OUTPUT" >/dev/null
grep -F "Missing first-visible samples; do not score keystroke-to-visible latency from this report." "$MISSING_OUTPUT" >/dev/null
grep -F "Missing first-token samples; do not score model response latency from this report." "$MISSING_OUTPUT" >/dev/null

ENERGY_OUTPUT="$TMP_DIR/energy-report.txt"
./script/runtime_performance_report.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --pid "$$" \
  --energy-gate \
  --sample-duration-seconds 0 \
  --max-average-cpu 100 \
  --max-p95-cpu 100 \
  --max-rss-mb 999999 \
  --max-rss-growth-mb 999999 \
  >"$ENERGY_OUTPUT"

grep -F "Energy sample gate: pass" "$ENERGY_OUTPUT" >/dev/null

if ./script/runtime_performance_report.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --pid "$$" \
  --energy-gate \
  --sample-duration-seconds 0 \
  --max-average-cpu -1 \
  >"$TMP_DIR/energy-fail.txt" 2>/dev/null; then
  echo "runtime performance report self-test expected energy gate to fail" >&2
  exit 1
fi

grep -F "Energy sample gate: fail" "$TMP_DIR/energy-fail.txt" >/dev/null

echo "Runtime performance report self-test passed."
