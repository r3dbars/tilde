#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MODEL_ROOT="$TMP_DIR/Models"
MODEL_PATH="$MODEL_ROOT/Qwen35FourB/MLX/Qwen3.5-4B-4bit"
mkdir -p "$MODEL_PATH"
printf '{}' >"$MODEL_PATH/config.json"
printf '{}' >"$MODEL_PATH/tokenizer.json"
printf '{}' >"$MODEL_PATH/tokenizer_config.json"
truncate -s 2147483648 "$MODEL_PATH/model.safetensors"

LOG_PATH="$TMP_DIR/diagnostics.log"
cat >"$LOG_PATH" <<'LOG'
2026-05-12T20:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
2026-05-12T20:00:00Z mlx-model-load-succeeded loadMilliseconds=2000 assetDirectory=/tmp/private-model
2026-05-12T20:00:00Z runtime-warm-succeeded candidate=mlx warmMilliseconds=2200 modelDirectory=/tmp/private-model
2026-05-12T20:00:01Z suggestion-presented latencyMilliseconds=100 requestMode=phraseContinuation traceID=first prompt=SECRET typedText=SECRET
2026-05-12T20:00:02Z suggestion-presented latencyMilliseconds=140 requestMode=phraseContinuation traceID=second output=SECRET
2026-05-12T20:00:03Z mlx-completion-timing firstChunkMilliseconds=80 totalMilliseconds=160 prompt=SECRET
2026-05-12T20:00:04Z mlx-completion-timing firstChunkMilliseconds=100 generationMilliseconds=180 output=SECRET
LOG

RUNTIME_REPORT="$TMP_DIR/runtime-report.txt"
cat >"$RUNTIME_REPORT" <<'REPORT'
Runtime performance report
Runtime launch: asset=Qwen3.5-4B-4bit candidate=mlx native=true override=none line=10
Live process: pid=123 cpu=0.7% rss=2534MB elapsed=00:05
Battery/energy risk: low (no current risk markers)

Supported local model assets
  qwen35-4b: installed, 2.0 GiB
REPORT

EGRESS_JSON="$TMP_DIR/no-egress.json"
cat >"$EGRESS_JSON" <<'JSON'
{
  "generated_at": "2026-05-12T20:05:00+00:00",
  "phase": "autocomplete",
  "result": "pass",
  "unexpected_remote_endpoint_count": 0
}
JSON

OUTPUT="$TMP_DIR/model-config-matrix.txt"
./script/model_config_matrix_report.py \
  --diagnostics-log "$LOG_PATH" \
  --model-root "$MODEL_ROOT" \
  --runtime-report "$RUNTIME_REPORT" \
  --egress-json "$EGRESS_JSON" \
  --no-default-artifacts \
  --models qwen35-4b qwen3-0.6b \
  >"$OUTPUT"

grep -F "Supported local model config matrix" "$OUTPUT" >/dev/null
grep -F "No-egress evidence: pass" "$OUTPUT" >/dev/null
grep -F "qwen35-4b / Qwen3.5 4B / Qwen3.5-4B-4bit" "$OUTPUT" >/dev/null
grep -F "| qwen35-4b / Qwen3.5 4B / Qwen3.5-4B-4bit | yes | available | 2.0 GiB | n=1 p50=2000ms p95=2000ms (log) | n=1 p50=2200ms p95=2200ms (log) | n=2 p50=100ms p95=140ms (log) | n=2 p50=80ms p95=100ms (log) | n=2 p50=160ms p95=180ms (log) | cpu=0.7% rss=2534MB energy=low | pass (active) |" "$OUTPUT" >/dev/null
grep -F "| qwen3-0.6b / Qwen3 0.6B / qwen3-0.6b-4bit | missing | missing | missing | missing | missing | missing | missing | missing | missing | missing |" "$OUTPUT" >/dev/null
grep -F "qwen3-0.6b: install state missing" "$OUTPUT" >/dev/null

if grep -F "SECRET" "$OUTPUT" >/dev/null || grep -F "/tmp/private-model" "$OUTPUT" >/dev/null; then
  echo "model config matrix report leaked raw diagnostic text" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

EMPTY_OUTPUT="$TMP_DIR/missing-matrix.txt"
./script/model_config_matrix_report.py \
  --diagnostics-log "$TMP_DIR/missing.log" \
  --model-root "$TMP_DIR/missing-models" \
  --no-default-artifacts \
  --models qwen35-4b \
  >"$EMPTY_OUTPUT"

grep -F "Diagnostics log: missing" "$EMPTY_OUTPUT" >/dev/null
grep -F "No-egress evidence: missing" "$EMPTY_OUTPUT" >/dev/null
grep -F "| qwen35-4b / Qwen3.5 4B / Qwen3.5-4B-4bit | missing | missing | missing | missing | missing | missing | missing | missing | missing | missing |" "$EMPTY_OUTPUT" >/dev/null

echo "Model config matrix report self-test passed."
