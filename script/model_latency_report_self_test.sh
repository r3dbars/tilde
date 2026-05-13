#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="$(mktemp)"
DEFAULT_PROOF_LOG_FILE="$(mktemp)"
EMPTY_LOG_FILE="$(mktemp)"
RESOURCE_LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE" "$DEFAULT_PROOF_LOG_FILE" "$EMPTY_LOG_FILE" "$RESOURCE_LOG_FILE"' EXIT

cat >"$LOG_FILE" <<'LOG'
2026-04-26T18:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-9B-MLX-4bit
2026-04-26T18:00:01Z mlx-completion-timing app=com.openai.codex cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=120 generationMilliseconds=180 maxTokens=8 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=181
2026-04-26T18:00:01Z suggestion-presented app=com.openai.codex latencyMilliseconds=220 requestMode=phraseContinuation traceID=first
2026-04-26T18:05:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:05:01Z suggestion-presented app=com.openai.codex latencyMilliseconds=0 requestMode=wordCompletion traceID=word
2026-04-26T18:05:02Z mlx-completion-timing app=com.openai.codex cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=70 generationMilliseconds=100 maxTokens=11 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=101
2026-04-26T18:05:02Z suggestion-presented app=com.openai.codex latencyMilliseconds=130 requestMode=phraseContinuation traceID=stream
2026-04-26T18:05:02Z suggestion-presented app=com.openai.codex latencyMilliseconds=190 requestMode=phraseContinuation traceID=stream
LOG

cat >"$DEFAULT_PROOF_LOG_FILE" <<'LOG'
2026-04-26T18:04:58Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-9B-MLX-4bit
2026-04-26T18:04:59Z app-proof-mode-started app=com.apple.TextEdit scenario=textedit-default-model-latency
2026-04-26T18:05:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:05:03Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=80 generationMilliseconds=110 maxTokens=11 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=111
2026-04-26T18:05:03Z suggestion-presented app=com.apple.TextEdit latencyMilliseconds=135 requestMode=phraseContinuation traceID=textedit-stream
2026-04-26T18:06:00Z app-proof-mode-started app=md.obsidian
2026-04-26T18:06:01Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:06:02Z mlx-completion-timing app=md.obsidian cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=90 generationMilliseconds=120 maxTokens=11 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=121
LOG

REPORT="$(script/model_latency_report.py --log "$LOG_FILE" --latest)"

if ! grep -F "asset=Qwen3.5-4B-4bit" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not select latest launch" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "first token: n=1 min=70ms avg=70ms p50=70ms p90=70ms p95=70ms p99=70ms max=70ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize first-token timing" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "max tokens: 11" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not show token budget" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "shown latency: n=1 min=0ms avg=0ms p50=0ms p90=0ms p95=0ms p99=0ms max=0ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not summarize word-completion latency" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "shown latency: n=1 min=130ms avg=130ms p50=130ms p90=130ms p95=130ms p99=130ms max=130ms" <<<"$REPORT" >/dev/null; then
  echo "latency report self-test did not deduplicate streamed shown latency" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$EMPTY_LOG_FILE" <<'LOG'
2026-04-26T18:10:00Z runtime-bootstrap activeCandidate=mlx asset=gemma-4-e4b-4bit
LOG

cat >"$RESOURCE_LOG_FILE" <<'LOG'
2026-04-26T18:20:00Z launch accessibility=true executableSHA256=abc
2026-04-26T18:20:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-04-26T18:20:00Z runtime-resource-sample cpuPercent=0.0 rssMB=3000 thermalState=nominal
2026-04-26T18:20:02Z runtime-warm-succeeded candidate=mlx state=ready warmMilliseconds=2000
2026-04-26T18:20:03Z runtime-resource-sample cpuPercent=4.0 rssMB=5500 thermalState=nominal
2026-04-26T18:20:08Z runtime-resource-sample cpuPercent=1.0 rssMB=5510 thermalState=nominal
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

RESOURCE_REPORT="$(script/model_latency_report.py \
  --log "$RESOURCE_LOG_FILE" \
  --latest \
  --require-resource-samples 2 \
  --max-rss-growth-mb 512)"

if ! grep -F "rssModelLoadDelta=2510MB rssPostReadyGrowth=10MB" <<<"$RESOURCE_REPORT" >/dev/null; then
  echo "latency report self-test did not split model-load RSS from post-ready growth" >&2
  echo "$RESOURCE_REPORT" >&2
  exit 1
fi

script/model_latency_report.py \
  --log "$LOG_FILE" \
  --latest \
  --require-timing-samples 1 \
  --require-shown-samples 2 >/dev/null

DEFAULT_PROOF_REPORT="$(script/model_latency_report.py \
  --log "$DEFAULT_PROOF_LOG_FILE" \
  --default-model-proof \
  --start-line 1 \
  --end-line 5 \
  --require-sample-app com.apple.TextEdit \
  --require-proof-scenario textedit-default-model-latency \
  --require-timing-samples 1 \
  --require-shown-samples 1 \
  --require-phrase-timing-samples 1 \
  --require-phrase-shown-samples 1)"

if ! grep -F "Default model proof passed" <<<"$DEFAULT_PROOF_REPORT" >/dev/null; then
  echo "latency report self-test did not pass default model proof" >&2
  echo "$DEFAULT_PROOF_REPORT" >&2
  exit 1
fi

if script/model_latency_report.py --log "$EMPTY_LOG_FILE" --latest --require-timing-samples 1 >/dev/null 2>&1; then
  echo "latency report self-test did not fail missing timing samples" >&2
  exit 1
fi

if script/model_latency_report.py \
  --log "$DEFAULT_PROOF_LOG_FILE" \
  --default-model-proof \
  --start-line 1 \
  --end-line 5 \
  --require-sample-app com.apple.TextEdit \
  --require-proof-scenario textedit-default-model-latency \
  --require-timing-samples 1 \
  --require-shown-samples 1 \
  --require-phrase-timing-samples 1 \
  --require-phrase-shown-samples 1 \
  --require-p95-shown-ms 50 >/dev/null 2>&1; then
  echo "latency report self-test did not fail slow default model proof" >&2
  exit 1
fi

echo "Model latency report self-test passed."
