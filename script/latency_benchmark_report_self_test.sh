#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DIAGNOSTICS_LOG="$TMP_DIR/diagnostics.log"
TRACE_LOG="$TMP_DIR/traces.jsonl"

cat >"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-09T10:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T10:00:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=100 generationMilliseconds=180 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=190
2026-05-09T10:00:02Z suggestion-presented app=com.apple.TextEdit behaviorProfile=notes latencyMilliseconds=210 requestMode=phraseContinuation traceID=one
2026-05-09T10:00:03Z keyboard-event-tap-latency decision=consume durationMicros=300 key=tab
2026-05-09T10:00:04Z keyboard-event-tap-latency decision=passthrough durationMicros=500 key=escape
2026-05-09T10:00:05Z keyboard-event-tap-latency-summary count=3 maxMicros=700 p50Micros=400 p90Micros=500 p95Micros=600 p99Micros=700 reason=stop
2026-05-09T10:00:06Z focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-09T10:00:01Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":190,"metadata":{"behaviorProfile":"notes","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"190"}}
{"timestamp":"2026-05-09T10:00:02Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":210,"metadata":{"behaviorProfile":"notes"}}
{"timestamp":"2026-05-09T10:00:03Z","sessionID":"session","suggestionID":"two","type":"modelResult","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":820,"metadata":{"behaviorProfile":"ai_chat","firstTokenLatencyMilliseconds":"610","totalGenerationLatencyMilliseconds":"820"}}
{"timestamp":"2026-05-09T10:00:04Z","sessionID":"session","suggestionID":"two","type":"suggestionSuppressed","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","latencyMilliseconds":820,"reason":"too-slow-to-display","metadata":{"behaviorProfile":"ai_chat"}}
{"timestamp":"2026-05-09T10:00:05Z","sessionID":"session","suggestionID":"three","type":"suggestionSuppressed","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":120,"reason":"stale-text","metadata":{"behaviorProfile":"ai_chat"}}
LOG

REPORT="$(
  script/latency_benchmark_report.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --beta-gate \
    --require-first-visible-samples 1 \
    --require-model-samples 2 \
    --require-event-tap-samples 2 \
    --require-ax-samples 1 \
    --max-first-visible-p95-ms 250 \
    --max-first-visible-p99-ms 250 \
    --max-first-token-p95-ms 650 \
    --max-total-generation-p95-ms 850
)"

if ! grep -F "Latency benchmark report" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print the report title" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "First visible / keystroke-to-visible: n=1 min=210ms avg=210ms p50=210ms p90=210ms p95=210ms p99=210ms max=210ms" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print first-visible percentiles" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Event-tap overhead summaries: windows=1 samples=3 p50Max=400us p90Max=500us p95Max=600us p99Max=700us max=700us" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print event-tap summary percentiles" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "AX read latency summaries: windows=1 samples=4 p50Max=4ms p90Max=6ms p95Max=8ms p99Max=9ms max=9ms" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print AX summary percentiles" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "latestDefaultAsset=Qwen3.5-4B-4bit defaultCandidate=mlx defaultNativeRuntimeAvailable=unknown latestDefaultLine=1 defaultAssetLaunches=1" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print current default runtime proof" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Stale/late suppression: n=2 lateShown=0" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not count stale/late suppression" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "com.apple.TextEdit / notes" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not slice by app/profile" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not pass the good beta gate" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-09T10:00:02Z","sessionID":"session","suggestionID":"late","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":900,"metadata":{"behaviorProfile":"notes"}}
LOG

if script/latency_benchmark_report.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --beta-gate \
  --require-first-visible-samples 1 \
  --require-model-samples 0 \
  --require-event-tap-samples 0 \
  --require-ax-samples 0 >"$TMP_DIR/late.txt" 2>&1; then
  echo "latency benchmark self-test expected late visible suggestions to fail" >&2
  cat "$TMP_DIR/late.txt" >&2
  exit 1
fi

if ! grep -F "late visible suggestion" "$TMP_DIR/late.txt" >/dev/null; then
  echo "latency benchmark self-test did not explain late visible failure" >&2
  cat "$TMP_DIR/late.txt" >&2
  exit 1
fi

echo "Latency benchmark report self-test passed."
