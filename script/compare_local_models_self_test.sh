#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MODEL_ROOT="$TMP_DIR/Models"
mkdir -p "$MODEL_ROOT/Qwen3Small/MLX/qwen3-0.6b-4bit"
mkdir -p "$MODEL_ROOT/Qwen3Medium/MLX/qwen3-1.7b-4bit"
mkdir -p "$MODEL_ROOT/Qwen35FourB/MLX/Qwen3.5-4B-4bit"
printf 'model' >"$MODEL_ROOT/Qwen3Small/MLX/qwen3-0.6b-4bit/model.safetensors"
printf 'model' >"$MODEL_ROOT/Qwen3Medium/MLX/qwen3-1.7b-4bit/model.safetensors"
printf 'model' >"$MODEL_ROOT/Qwen35FourB/MLX/Qwen3.5-4B-4bit/model.safetensors"

LOG_PATH="$TMP_DIR/diagnostics.log"
cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-0.6b-4bit modelOverride=qwen3-0.6b nativeRuntimeAvailable=true
2026-05-12T20:00:00Z mlx-model-load-succeeded loadMilliseconds=300
2026-05-12T20:00:00Z runtime-warm-succeeded candidate=mlx warmMilliseconds=420
2026-05-12T20:00:01Z mlx-completion-timing firstChunkMilliseconds=40 totalMilliseconds=70 prompt=SECRET
2026-05-12T20:00:02Z mlx-completion-timing firstChunkMilliseconds=50 totalMilliseconds=80 output=SECRET
2026-05-12T20:00:30Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-1.7b-4bit modelOverride=qwen3-1.7b nativeRuntimeAvailable=true
2026-05-12T20:00:30Z mlx-model-load-succeeded loadMilliseconds=700
2026-05-12T20:00:30Z runtime-warm-succeeded candidate=mlx warmMilliseconds=850
2026-05-12T20:00:31Z mlx-completion-timing firstChunkMilliseconds=60 totalMilliseconds=100 prompt=SECRET
2026-05-12T20:01:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride=qwen35-4b nativeRuntimeAvailable=true
2026-05-12T20:01:00Z mlx-model-load-succeeded loadMilliseconds=1800
2026-05-12T20:01:00Z runtime-warm-succeeded candidate=mlx warmMilliseconds=2100
2026-05-12T20:01:01Z mlx-completion-timing firstChunkMilliseconds=90 totalMilliseconds=150 typedText=SECRET
2026-05-12T20:01:02Z mlx-completion-timing firstChunkMilliseconds=100 totalMilliseconds=160
LOG

OUTPUT="$TMP_DIR/model-comparison.txt"
./script/compare_local_models.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --models qwen3-0.6b qwen3-1.7b qwen35-4b qwen35-9b \
  >"$OUTPUT"

grep -F "Local model comparison" "$OUTPUT" >/dev/null
grep -F "Privacy: metadata-only" "$OUTPUT" >/dev/null
grep -F "qwen3-0.6b: installed" "$OUTPUT" >/dev/null
grep -F "qwen3-1.7b: installed" "$OUTPUT" >/dev/null
grep -F "qwen35-4b: installed" "$OUTPUT" >/dev/null
grep -F "qwen35-9b: missing" "$OUTPUT" >/dev/null
grep -F "Runtime launch: asset=qwen3-0.6b-4bit candidate=mlx native=true override=qwen3-0.6b" "$OUTPUT" >/dev/null
grep -F "Runtime launch: asset=Qwen3.5-4B-4bit candidate=mlx native=true override=qwen35-4b" "$OUTPUT" >/dev/null
grep -F "qwen3-0.6b: modelLoad n=1 avg=300ms" "$OUTPUT" >/dev/null
grep -F "runtimeWarm n=1 avg=420ms" "$OUTPUT" >/dev/null
grep -F "firstToken n=2 avg=45ms" "$OUTPUT" >/dev/null
grep -F "qwen35-4b: modelLoad n=1 avg=1800ms" "$OUTPUT" >/dev/null
grep -F "firstToken n=2 avg=95ms" "$OUTPUT" >/dev/null

LANE_OUTPUT="$TMP_DIR/small-draft-lane.txt"
./script/compare_local_models.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --small-draft-lane \
  >"$LANE_OUTPUT"

grep -F "Lane: small-draft-1b (qwen3-1.7b) versus qwen35-4b quality default" "$LANE_OUTPUT" >/dev/null
grep -F "Decision guard: keep qwen35-4b as default" "$LANE_OUTPUT" >/dev/null
grep -F "qwen3-1.7b: installed" "$LANE_OUTPUT" >/dev/null
grep -F "qwen35-4b: installed" "$LANE_OUTPUT" >/dev/null
grep -F "qwen3-1.7b: modelLoad n=1 avg=700ms" "$LANE_OUTPUT" >/dev/null

if grep -F "SECRET" "$OUTPUT" >/dev/null || grep -F "SECRET" "$LANE_OUTPUT" >/dev/null; then
  echo "model comparison self-test leaked raw diagnostic text" >&2
  cat "$OUTPUT" >&2
  cat "$LANE_OUTPUT" >&2
  exit 1
fi

echo "Local model comparison self-test passed."
