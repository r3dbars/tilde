#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="$(mktemp)"
EMPTY_LOG_FILE="$(mktemp)"
PROOF_LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE" "$EMPTY_LOG_FILE" "$PROOF_LOG_FILE"' EXIT

cat >"$LOG_FILE" <<'LOG'
2026-04-26T18:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-9B-MLX-4bit
2026-04-26T18:00:01Z mlx-completion-timing app=com.openai.codex cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=120 generationMilliseconds=180 maxTokens=8 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=181
2026-04-26T18:00:01Z suggestion-presented app=com.openai.codex latencyMilliseconds=220 requestMode=phraseContinuation traceID=first
2026-04-26T18:05:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:05:01Z suggestion-presented app=com.openai.codex latencyMilliseconds=0 requestMode=wordCompletion traceID=word
2026-04-26T18:05:01Z mlx-warmup-generation app=app.transcripted.autocomplete-lab.runtime-warmup cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=90 generationMilliseconds=140 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 rssMegabytes=512 sessionMilliseconds=0 thermalState=nominal totalMilliseconds=141
2026-04-26T18:05:02Z mlx-completion-timing app=com.openai.codex cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=70 generationMilliseconds=100 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 rssMegabytes=520 sessionMilliseconds=0 thermalState=nominal totalMilliseconds=101
2026-04-26T18:05:02Z suggestion-presented app=com.openai.codex latencyMilliseconds=130 requestMode=phraseContinuation traceID=stream
2026-04-26T18:05:02Z suggestion-presented app=com.openai.codex latencyMilliseconds=190 requestMode=phraseContinuation traceID=stream
LOG

REPORT="$(script/model_latency_report.py --log "$LOG_FILE" --latest)"

if ! grep -F "asset=Qwen3.5-4B-4bit" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not select latest launch" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "first token: n=1 min=70ms avg=70ms p50=70ms p90=70ms p95=70ms max=70ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize first-token timing" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "max tokens: 9" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not show token budget" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "warmup" <<<"$REPORT" >/dev/null || ! grep -F "model total: n=1 min=141ms avg=141ms p50=141ms p90=141ms p95=141ms max=141ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize warmup timing" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "resident memory: n=1 min=512MB avg=512MB p50=512MB p90=512MB p95=512MB max=512MB" <<<"$REPORT" >/dev/null || ! grep -F "thermal states: nominal" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize runtime resources" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "shown latency: n=1 min=0ms avg=0ms p50=0ms p90=0ms p95=0ms max=0ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize word-completion latency" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "shown latency: n=1 min=130ms avg=130ms p50=130ms p90=130ms p95=130ms max=130ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not deduplicate streamed shown latency" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$EMPTY_LOG_FILE" <<'LOG'
2026-04-26T18:10:00Z runtime-bootstrap activeCandidate=mlx asset=gemma-4-e4b-4bit
LOG

EMPTY_REPORT="$(script/model_latency_report.py --log "$EMPTY_LOG_FILE" --latest)"

if ! grep -F "try: type one short sentence in TextEdit or Codex" <<<"$EMPTY_REPORT" >/dev/null; then
  echo "latency report self-test did not explain how to collect first samples" >&2
  echo "$EMPTY_REPORT" >&2
  exit 1
fi

if ! grep -F "instant word-completion may bypass the model" <<<"$EMPTY_REPORT" >/dev/null; then
  echo "latency report self-test did not explain fast-path timing" >&2
  echo "$EMPTY_REPORT" >&2
  exit 1
fi

script/model_latency_report.py \
  --log "$LOG_FILE" \
  --latest \
  --require-timing-samples 1 \
  --require-shown-samples 2 >/dev/null

cp "$LOG_FILE" "$PROOF_LOG_FILE"
cat >>"$PROOF_LOG_FILE" <<'LOG'
2026-04-26T18:06:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:07:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit probe=runtime-latency
2026-04-26T18:07:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=9 cleanupMilliseconds=0 firstChunkMilliseconds=80 generationMilliseconds=120 maxTokens=9 mode=phraseContinuation probe=runtime-latency promptMilliseconds=0 rawChars=8 rssMegabytes=530 sessionMilliseconds=0 thermalState=nominal totalMilliseconds=121
2026-04-26T18:07:01Z suggestion-presented app=com.apple.TextEdit latencyMilliseconds=125 probe=runtime-latency requestMode=phraseContinuation traceID=probe
2026-04-26T18:07:02Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=4 cleanupMilliseconds=0 firstChunkMilliseconds=90 generationMilliseconds=140 maxTokens=4 mode=phraseContinuation promptMilliseconds=0 rawChars=4 sessionMilliseconds=0 totalMilliseconds=141
LOG

DEFAULT_PROOF_REPORT="$(script/model_latency_report.py \
  --log "$PROOF_LOG_FILE" \
  --default-model-proof \
  --require-timing-samples 1 \
  --require-shown-samples 1 \
  --require-phrase-timing-samples 1 \
  --require-phrase-shown-samples 1)"

if ! grep -F "Default model proof passed" <<<"$DEFAULT_PROOF_REPORT" >/dev/null; then
  echo "latency report self-test did not pass default model proof" >&2
  echo "$DEFAULT_PROOF_REPORT" >&2
  exit 1
fi

if ! grep -F "launch=2026-04-26T18:07:00Z" <<<"$DEFAULT_PROOF_REPORT" >/dev/null; then
  echo "latency report self-test did not skip the newer empty proof launch" >&2
  echo "$DEFAULT_PROOF_REPORT" >&2
  exit 1
fi

if grep -F "max tokens: 4" <<<"$DEFAULT_PROOF_REPORT" >/dev/null; then
  echo "latency report self-test did not ignore non-probe timing inside a probe launch" >&2
  echo "$DEFAULT_PROOF_REPORT" >&2
  exit 1
fi

if script/model_latency_report.py --log "$EMPTY_LOG_FILE" --latest --require-timing-samples 1 >/dev/null 2>&1; then
  echo "latency report self-test did not fail missing timing samples" >&2
  exit 1
fi

if script/model_latency_report.py \
  --log "$LOG_FILE" \
  --default-model-proof \
  --require-timing-samples 1 \
  --require-shown-samples 1 \
  --require-phrase-timing-samples 1 \
  --require-phrase-shown-samples 1 \
  --require-p95-shown-ms 50 >/dev/null 2>&1; then
  echo "latency report self-test did not fail slow default model proof" >&2
  exit 1
fi

echo "Model latency report self-test passed."
