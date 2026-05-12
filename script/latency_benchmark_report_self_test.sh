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

cat >"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-09T09:59:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T09:59:01Z focused-text-poll-latency-summary count=60 maxMilliseconds=250 p50Milliseconds=250 p90Milliseconds=250 p95Milliseconds=250 p99Milliseconds=250
2026-05-09T10:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T10:00:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=100 generationMilliseconds=180 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=190
2026-05-09T10:00:02Z focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-09T09:59:00Z","sessionID":"old","suggestionID":"late","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":900,"metadata":{"behaviorProfile":"notes"}}
{"timestamp":"2026-05-09T10:00:01Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":190,"metadata":{"behaviorProfile":"notes","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"190"}}
{"timestamp":"2026-05-09T10:00:02Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":210,"metadata":{"behaviorProfile":"notes"}}
LOG

REPORT="$(
  AUTOCOMPLETE_LAB_LOG_START_LINE=2 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=1 \
    script/latency_benchmark_report.py \
      --diagnostics-log "$DIAGNOSTICS_LOG" \
      --trace-log "$TRACE_LOG" \
      --beta-gate \
      --require-first-visible-samples 1 \
      --require-model-samples 1 \
      --require-event-tap-samples 0 \
      --require-ax-samples 1 \
      --max-first-visible-p95-ms 250 \
      --max-first-visible-p99-ms 250 \
      --max-first-token-p95-ms 650 \
      --max-total-generation-p95-ms 850
)"

if ! grep -F "Diagnostics start line: 2" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not honor AUTOCOMPLETE_LAB_LOG_START_LINE" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Trace start line: 1" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not honor AUTOCOMPLETE_LAB_TRACE_START_LINE" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not ignore old latency when start-line env vars are set" >&2
  echo "$REPORT" >&2
  exit 1
fi

REPORT="$(
  AUTOCOMPLETE_LAB_LOG_START_LINE=2 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=1 \
    AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE=1 \
    AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_DIAGNOSTICS_LINE=5 \
    AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_FIRST_VISIBLE_SAMPLES=1 \
    AUTOCOMPLETE_LAB_LATENCY_WINDOW_STALE_MODEL_SAMPLES=0 \
    script/latency_benchmark_report.py \
      --diagnostics-log "$DIAGNOSTICS_LOG" \
      --trace-log "$TRACE_LOG" \
      --beta-gate \
      --require-first-visible-samples 1 \
      --require-model-samples 1 \
      --require-event-tap-samples 0 \
      --require-ax-samples 1 \
      --max-first-visible-p95-ms 250 \
      --max-first-visible-p99-ms 250 \
      --max-first-token-p95-ms 650 \
      --max-total-generation-p95-ms 850
)"

if ! grep -F "Latency window caveat: current default runtime launch is under-sampled; diagnosticsLine=5; firstVisibleSamples=1; modelSamples=0; reporting latest older sampled default window" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not print the stale current-launch caveat" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-09T10:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T10:00:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=100 generationMilliseconds=180 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=190
2026-05-09T10:00:02Z focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
2026-05-09T10:01:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T10:01:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=12 cleanupMilliseconds=0 firstChunkMilliseconds=900 generationMilliseconds=1800 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=12 sessionMilliseconds=0 totalMilliseconds=2000
2026-05-09T10:01:02Z focused-text-poll-latency-summary count=4 maxMilliseconds=200 p50Milliseconds=200 p90Milliseconds=200 p95Milliseconds=200 p99Milliseconds=200
LOG

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-09T10:00:01Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":190,"metadata":{"behaviorProfile":"notes","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"190"}}
{"timestamp":"2026-05-09T10:00:02Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":210,"metadata":{"behaviorProfile":"notes"}}
{"timestamp":"2026-05-09T10:01:01Z","sessionID":"session","suggestionID":"future","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":2000,"metadata":{"behaviorProfile":"notes","firstTokenLatencyMilliseconds":"900","totalGenerationLatencyMilliseconds":"2000"}}
{"timestamp":"2026-05-09T10:01:02Z","sessionID":"session","suggestionID":"future","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":2000,"metadata":{"behaviorProfile":"notes"}}
LOG

REPORT="$(
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
    AUTOCOMPLETE_LAB_LOG_END_LINE=3 \
    AUTOCOMPLETE_LAB_TRACE_START_LINE=0 \
    AUTOCOMPLETE_LAB_TRACE_END_LINE=2 \
    script/latency_benchmark_report.py \
      --diagnostics-log "$DIAGNOSTICS_LOG" \
      --trace-log "$TRACE_LOG" \
      --beta-gate \
      --require-first-visible-samples 1 \
      --require-model-samples 1 \
      --require-event-tap-samples 0 \
      --require-ax-samples 1 \
      --max-first-visible-p95-ms 250 \
      --max-first-visible-p99-ms 250 \
      --max-first-token-p95-ms 650 \
      --max-total-generation-p95-ms 850
)"

if ! grep -F "Diagnostics end line: 3" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not honor AUTOCOMPLETE_LAB_LOG_END_LINE" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Trace end line: 2" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not honor AUTOCOMPLETE_LAB_TRACE_END_LINE" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not ignore future latency when end-line env vars are set" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-09T10:00:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit
2026-05-09T10:00:01Z mlx-completion-timing app=com.apple.TextEdit cleanedChars=0 cleanupMilliseconds=0 firstChunkMilliseconds=120 generationMilliseconds=160 maxTokens=9 mode=phraseContinuation promptMilliseconds=0 rawChars=4 sessionMilliseconds=0 totalMilliseconds=160
2026-05-09T10:00:02Z focused-text-poll-latency-summary count=60 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG

cat >"$TRACE_LOG" <<'LOG'
LOG

REPORT="$(
  script/latency_benchmark_report.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --beta-gate \
    --require-first-visible-samples 0 \
    --require-model-samples 1 \
    --require-event-tap-samples 0 \
    --require-ax-samples 1
)"

if ! grep -F "Latency beta gate passed." <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not honor explicit zero sample overrides" >&2
  echo "$REPORT" >&2
  exit 1
fi

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-09T10:00:01Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":190,"metadata":{"behaviorProfile":"notes","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"190"}}
{"timestamp":"2026-05-09T10:00:02Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","latencyMilliseconds":210,"metadata":{"behaviorProfile":"notes"}}
LOG

{
  echo "2026-05-09T10:10:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit"
  for index in $(seq 1 100); do
    echo "2026-05-09T10:10:${index}Z focused-text-poll-latency-summary count=60 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9"
  done
  echo "2026-05-09T10:12:00Z focused-text-poll-latency-summary count=60 maxMilliseconds=121 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=121"
} >"$DIAGNOSTICS_LOG"

REPORT="$(
  script/latency_benchmark_report.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --beta-gate \
    --require-first-visible-samples 1 \
    --require-model-samples 1 \
    --require-ax-samples 1
)"

if ! grep -F "AX read latency summaries: windows=101" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not keep AX summary-window evidence" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "p99Max=121ms" <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test did not expose the AX outlier max" >&2
  echo "$REPORT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$REPORT" >/dev/null; then
  echo "latency benchmark self-test treated a single AX p99-window outlier as sustained p99 failure" >&2
  echo "$REPORT" >&2
  exit 1
fi

{
  echo "2026-05-09T10:20:00Z runtime-bootstrap activeCandidate=mlx asset=Qwen3.5-4B-4bit"
  for index in $(seq 1 99); do
    echo "2026-05-09T10:20:${index}Z focused-text-poll-latency-summary count=60 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9"
  done
  echo "2026-05-09T10:22:00Z focused-text-poll-latency-summary count=60 maxMilliseconds=121 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=121"
  echo "2026-05-09T10:22:01Z focused-text-poll-latency-summary count=60 maxMilliseconds=122 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=122"
} >"$DIAGNOSTICS_LOG"

if script/latency_benchmark_report.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --beta-gate \
  --require-first-visible-samples 1 \
  --require-model-samples 1 \
  --require-ax-samples 1 >"$TMP_DIR/ax-p99.txt" 2>&1; then
  echo "latency benchmark self-test expected sustained AX p99-window failures to fail" >&2
  cat "$TMP_DIR/ax-p99.txt" >&2
  exit 1
fi

if ! grep -F "AX summary p99-window budget 2 windows exceed 120ms; allowed 1" "$TMP_DIR/ax-p99.txt" >/dev/null; then
  echo "latency benchmark self-test did not explain sustained AX p99-window failure" >&2
  cat "$TMP_DIR/ax-p99.txt" >&2
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
