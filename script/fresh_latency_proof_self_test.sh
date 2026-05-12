#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DIAGNOSTICS_LOG="$TMP_DIR/diagnostics.log"
TRACE_LOG="$TMP_DIR/traces.jsonl"
SMOKE_LOG="$TMP_DIR/smoke.log"
touch "$DIAGNOSTICS_LOG" "$TRACE_LOG" "$SMOKE_LOG"

SMOKE_STUB="$TMP_DIR/real_app_smoke_stub.sh"
cat >"$SMOKE_STUB" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
run_number="$(( $(wc -l <"$AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG" | tr -d ' ') + 1 ))"
printf '%s\n' "$*" >>"$AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG"
base_timestamp="2026-05-12T12:00:0${run_number}Z"
cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
$base_timestamp focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG
cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh","suggestionID":"fresh-${run_number}-one","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh","suggestionID":"fresh-${run_number}-one","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose"}}
{"timestamp":"$base_timestamp","sessionID":"fresh","suggestionID":"fresh-${run_number}-two","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":140,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"100","totalGenerationLatencyMilliseconds":"140"}}
{"timestamp":"$base_timestamp","sessionID":"fresh","suggestionID":"fresh-${run_number}-two","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":150,"metadata":{"behaviorProfile":"docs_prose"}}
LOG
STUB
chmod +x "$SMOKE_STUB"

OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency.lock" \
    ./script/fresh_latency_proof.sh --runs 3
)"

if ! grep -F "Latency beta gate passed." <<<"$OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test did not pass beta latency gate" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "AUTOCOMPLETE_LAB_LOG_START_LINE=0" <<<"$OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test did not print bounded diagnostics start" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "First visible / keystroke-to-visible: n=6" <<<"$OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test did not collect six first-visible samples" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "textedit" ]]; then
  echo "fresh latency proof self-test expected first smoke without --skip-build" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(grep -c -- '--skip-build' "$SMOKE_LOG")" != "2" ]]; then
  echo "fresh latency proof self-test expected two skip-build smoke reruns" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ -d "$TMP_DIR/fresh-latency.lock" ]]; then
  echo "fresh latency proof self-test expected lock cleanup after success" >&2
  exit 1
fi

BLOCKED_OUTPUT="$TMP_DIR/blocked-output.txt"
if AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-blocked.lock" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS=0 \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST=$'123 1 123 bash ./script/real_app_smoke.sh chrome\n124 1 124 bash ./script/fresh_latency_proof.sh --runs 3' \
    ./script/fresh_latency_proof.sh --runs 1 >"$BLOCKED_OUTPUT" 2>&1; then
  echo "fresh latency proof self-test expected active proof processes to fail before selecting a window" >&2
  cat "$BLOCKED_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Another proof process is already active." "$BLOCKED_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected active proof process warning" >&2
  cat "$BLOCKED_OUTPUT" >&2
  exit 1
fi

if grep -F "Fresh latency proof start:" "$BLOCKED_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected no latency window after active proof refusal" >&2
  cat "$BLOCKED_OUTPUT" >&2
  exit 1
fi

echo "Fresh latency proof self-test passed."
