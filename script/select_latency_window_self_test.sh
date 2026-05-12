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
2026-05-12T10:10:01Z focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG

cat >"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-12T10:00:02Z","sessionID":"session","suggestionID":"one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"2026-05-12T10:00:03Z","sessionID":"session","suggestionID":"one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:00:04Z","sessionID":"session","suggestionID":"two","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":140,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"140"}}
{"timestamp":"2026-05-12T10:00:05Z","sessionID":"session","suggestionID":"two","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":150,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:10:02Z","sessionID":"session","suggestionID":"three","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"2026-05-12T10:10:03Z","sessionID":"session","suggestionID":"three","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:10:04Z","sessionID":"session","suggestionID":"four","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":140,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"140"}}
{"timestamp":"2026-05-12T10:10:05Z","sessionID":"session","suggestionID":"four","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":150,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:10:06Z","sessionID":"session","suggestionID":"four","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":151,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T10:10:07Z","sessionID":"session","suggestionID":"token-only","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"110"}}
LOG

WINDOW="$(
  script/select_latency_window.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --min-first-visible-samples 2 \
    --min-model-samples 2
)"

if ! grep -F "AUTOCOMPLETE_LAB_LOG_START_LINE=3" <<<"$WINDOW" >/dev/null; then
  echo "latency window self-test did not choose the latest sampled default launch" >&2
  echo "$WINDOW" >&2
  exit 1
fi

if ! grep -F "AUTOCOMPLETE_LAB_TRACE_START_LINE=4" <<<"$WINDOW" >/dev/null; then
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

if script/select_latency_window.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --min-first-visible-samples 3 \
  --min-model-samples 2 2>"$TMP_DIR/duplicate-presented.err" >/dev/null; then
  echo "latency window self-test expected duplicate presented rows not to inflate first-visible samples" >&2
  exit 1
fi

if ! grep -F "firstVisibleSamples=2; modelSamples=2" "$TMP_DIR/duplicate-presented.err" >/dev/null; then
  echo "latency window self-test did not report benchmark-equivalent first-visible samples" >&2
  cat "$TMP_DIR/duplicate-presented.err" >&2
  exit 1
fi

if script/select_latency_window.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --min-first-visible-samples 2 \
  --min-model-samples 3 2>"$TMP_DIR/token-only-model.err" >/dev/null; then
  echo "latency window self-test expected first-token-only model rows not to inflate model samples" >&2
  exit 1
fi

if ! grep -F "latest default runtime launch has too few samples" "$TMP_DIR/token-only-model.err" >/dev/null; then
  echo "latency window self-test did not keep partial latest launch proof red" >&2
  cat "$TMP_DIR/token-only-model.err" >&2
  exit 1
fi

if ! grep -F "firstVisibleSamples=2; modelSamples=2" "$TMP_DIR/token-only-model.err" >/dev/null; then
  echo "latency window self-test did not report benchmark-equivalent model samples" >&2
  cat "$TMP_DIR/token-only-model.err" >&2
  exit 1
fi

cat >>"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-12T10:12:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
LOG

WINDOW_WITH_EMPTY_LATEST="$(
  script/select_latency_window.py \
    --diagnostics-log "$DIAGNOSTICS_LOG" \
    --trace-log "$TRACE_LOG" \
    --min-first-visible-samples 2 \
    --min-model-samples 2 2>"$TMP_DIR/empty-latest.err"
)"

if ! grep -F "AUTOCOMPLETE_LAB_LOG_START_LINE=3" <<<"$WINDOW_WITH_EMPTY_LATEST" >/dev/null; then
  echo "latency window self-test did not skip an unsampled latest default launch" >&2
  cat "$TMP_DIR/empty-latest.err" >&2
  echo "$WINDOW_WITH_EMPTY_LATEST" >&2
  exit 1
fi

if ! grep -F "AUTOCOMPLETE_LAB_LOG_END_LINE=5" <<<"$WINDOW_WITH_EMPTY_LATEST" >/dev/null; then
  echo "latency window self-test did not emit a diagnostics end line for the selected older launch" >&2
  cat "$TMP_DIR/empty-latest.err" >&2
  echo "$WINDOW_WITH_EMPTY_LATEST" >&2
  exit 1
fi

if ! grep -F "AUTOCOMPLETE_LAB_TRACE_END_LINE=10" <<<"$WINDOW_WITH_EMPTY_LATEST" >/dev/null; then
  echo "latency window self-test did not emit a trace end line for the selected older launch" >&2
  cat "$TMP_DIR/empty-latest.err" >&2
  echo "$WINDOW_WITH_EMPTY_LATEST" >&2
  exit 1
fi

if ! grep -F "skippedUnsampledDefaultLaunches=1" "$TMP_DIR/empty-latest.err" >/dev/null; then
  echo "latency window self-test did not explain the skipped unsampled launch" >&2
  cat "$TMP_DIR/empty-latest.err" >&2
  exit 1
fi

cat >>"$TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-12T10:12:01Z","sessionID":"session","suggestionID":"future-slow","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":2000,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"1800","totalGenerationLatencyMilliseconds":"2000"}}
{"timestamp":"2026-05-12T10:12:02Z","sessionID":"session","suggestionID":"future-slow","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":2000,"metadata":{"behaviorProfile":"docs_prose"}}
LOG

if script/select_latency_window.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --min-first-visible-samples 2 \
  --min-model-samples 2 2>"$TMP_DIR/partial-latest.err" >/dev/null; then
  echo "latency window self-test expected partial latest launch samples to fail" >&2
  exit 1
fi

if ! grep -F "latest default runtime launch has too few samples" "$TMP_DIR/partial-latest.err" >/dev/null; then
  echo "latency window self-test did not explain the partial latest launch" >&2
  cat "$TMP_DIR/partial-latest.err" >&2
  exit 1
fi

CROSS_DIAGNOSTICS_LOG="$TMP_DIR/cross-override-diagnostics.log"
CROSS_TRACE_LOG="$TMP_DIR/cross-override-traces.jsonl"

cat >"$CROSS_DIAGNOSTICS_LOG" <<'LOG'
2026-05-12T11:00:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
2026-05-12T11:05:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-0.6b-4bit modelOverride=qwen3-0.6b nativeRuntimeAvailable=true
2026-05-12T11:10:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
LOG

cat >"$CROSS_TRACE_LOG" <<'LOG'
{"timestamp":"2026-05-12T11:00:02Z","sessionID":"session","suggestionID":"old-one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"2026-05-12T11:00:03Z","sessionID":"session","suggestionID":"old-one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"2026-05-12T11:00:04Z","sessionID":"session","suggestionID":"old-two","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":140,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"140"}}
{"timestamp":"2026-05-12T11:00:05Z","sessionID":"session","suggestionID":"old-two","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":150,"metadata":{"behaviorProfile":"docs_prose"}}
LOG

if script/select_latency_window.py \
  --diagnostics-log "$CROSS_DIAGNOSTICS_LOG" \
  --trace-log "$CROSS_TRACE_LOG" \
  --min-first-visible-samples 2 \
  --min-model-samples 2 2>"$TMP_DIR/cross-override.err" >/dev/null; then
  echo "latency window self-test crossed an override launch to reuse old default samples" >&2
  exit 1
fi

if ! grep -F "no sampled default runtime launch meets sample requirements" "$TMP_DIR/cross-override.err" >/dev/null; then
  echo "latency window self-test did not explain the post-override undersampled launch" >&2
  cat "$TMP_DIR/cross-override.err" >&2
  exit 1
fi

cat >>"$DIAGNOSTICS_LOG" <<'LOG'
2026-05-12T10:15:00Z runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=qwen3-0.6b-4bit modelOverride=qwen3-0.6b nativeRuntimeAvailable=true
LOG

if script/select_latency_window.py \
  --diagnostics-log "$DIAGNOSTICS_LOG" \
  --trace-log "$TRACE_LOG" \
  --min-first-visible-samples 2 \
  --min-model-samples 2 2>"$TMP_DIR/override.err" >/dev/null; then
  echo "latency window self-test expected latest model override launch to fail" >&2
  exit 1
fi

if ! grep -F "latest runtime launch is not the expected default runtime" "$TMP_DIR/override.err" >/dev/null; then
  echo "latency window self-test did not explain the latest override launch" >&2
  cat "$TMP_DIR/override.err" >&2
  exit 1
fi

echo "Latency window self-test passed."
