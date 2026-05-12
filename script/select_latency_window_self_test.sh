#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DIAGNOSTICS_LOG="$TMP_DIR/diagnostics.log"
TRACE_LOG="$TMP_DIR/traces.jsonl"

cat >"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-12T10:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
2026-05-12T10:00:01Z focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
2026-05-12T10:05:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-0.6b-4bit modelOverride=qwen3-0.6b nativeRuntimeAvailable=true
2026-05-12T10:10:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
LOG

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-12T10:00:02Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"2026-05-12T10:00:03Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:00:04Z","sessionID":"session","suggestionID":"two","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":140,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"140"}}
{"timestamp":"2026-05-12T10:00:05Z","sessionID":"session","suggestionID":"two","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":150,"metadata":{"behaviorProfile":"docs_prose"}}
LOG

WINDOW="$(
  script/select_latency_window.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --min-first-visible-samples 2 \
    --min-model-samples 2
)"

if ! grep -F "AUTOCOMPLETE_LAB_LOG_START_LINE=0" <<<"$WINDOW" >/dev/null; then
  echo "latency window self-test did not choose the sampled default launch" >&2
  echo "$WINDOW" >&2
  exit 1
fi

if ! grep -F "AUTOCOMPLETE_LAB_TRACE_START_LINE=0" <<<"$WINDOW" >/dev/null; then
  echo "latency window self-test did not choose the matching trace window" >&2
  echo "$WINDOW" >&2
  exit 1
fi

env $WINDOW \
  script/latency_benchmark_report.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --beta-gate \
    --require-first-visible-samples 2 \
    --require-model-samples 2 \
    --require-event-tap-samples 0 \
    --require-ax-samples 1 \
    --max-first-visible-p95-ms 250 \
    --max-first-visible-p99-ms 250 \
    --max-first-token-p95-ms 650 \
    --max-total-generation-p95-ms 850 >/dev/null

WINDOW="$(
  script/select_latency_window.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --min-first-visible-samples 3 \
    --min-model-samples 3
)"

if ! grep -F "AUTOCOMPLETE_LAB_LOG_START_LINE=3" <<<"$WINDOW" >/dev/null; then
  echo "latency window self-test did not fail closed on the latest default launch" >&2
  echo "$WINDOW" >&2
  exit 1
fi

echo "Latency window self-test passed."
