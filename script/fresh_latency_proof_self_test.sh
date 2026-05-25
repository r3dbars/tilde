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
smoke_env_prefix=""
if [[ "${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-}" == "1" ]]; then
  smoke_env_prefix="AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 "
fi
printf '%s%s\n' "$smoke_env_prefix" "$*" >>"$AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG"
base_timestamp="2026-05-12T12:00:0${run_number}Z"
if [[ "${1:-}" == "textedit-default-model-latency" ]]; then
  cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp app-proof-mode-started app=com.apple.TextEdit scenario=textedit-default-model-latency
LOG
fi
cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp runtime-bootstrap activeCandidate=mlx allowsUserManagedServer=false asset=Qwen3.5-4B-4bit modelOverride= nativeRuntimeAvailable=true
$base_timestamp focused-text-poll-latency-summary count=4 maxMilliseconds=9 p50Milliseconds=4 p90Milliseconds=6 p95Milliseconds=8 p99Milliseconds=9
LOG
if [[ "${1:-}" == "textedit-model-latency" ]]; then
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh-model","suggestionID":"fresh-model-${sample}","type":"modelResult","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh-model","suggestionID":"fresh-model-${sample}","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose","candidateSelectionSource":"app-model-result"}}
LOG
  done
  exit 0
fi
if [[ "${1:-}" == "chrome-textarea-model-latency" || "${1:-}" == "chrome-contenteditable-model-latency" ]]; then
  scenario="${1:-}"
  cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp app-proof-mode-started app=com.google.Chrome scenario=$scenario
LOG
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh-chrome","suggestionID":"fresh-chrome-${run_number}-${sample}","type":"modelResult","appBundleIdentifier":"com.google.Chrome","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"docs_prose","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh-chrome","suggestionID":"fresh-chrome-${run_number}-${sample}","type":"suggestionPresented","appBundleIdentifier":"com.google.Chrome","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"docs_prose","candidateSelectionSource":"app-model-result"}}
LOG
  done
  exit 0
fi
if [[ "${1:-}" == "codex-model-latency" ]]; then
  cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp app-proof-mode-started app=com.openai.codex scenario=codex-model-latency
LOG
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh-codex","suggestionID":"fresh-codex-${run_number}-${sample}","type":"modelResult","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"ai_chat","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh-codex","suggestionID":"fresh-codex-${run_number}-${sample}","type":"suggestionPresented","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"ai_chat","candidateSelectionSource":"app-model-result","promptSafetyMode":"wordOnly"}}
LOG
  done
  exit 0
fi
if [[ "${1:-}" == "claude-model-latency" ]]; then
  cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp app-proof-mode-started app=com.anthropic.claudefordesktop scenario=claude-model-latency
LOG
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh-claude","suggestionID":"fresh-claude-${run_number}-${sample}","type":"modelResult","appBundleIdentifier":"com.anthropic.claudefordesktop","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"ai_chat","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh-claude","suggestionID":"fresh-claude-${run_number}-${sample}","type":"suggestionPresented","appBundleIdentifier":"com.anthropic.claudefordesktop","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"ai_chat","candidateSelectionSource":"app-model-result","promptSafetyMode":"wordOnly"}}
LOG
  done
  exit 0
fi
if [[ "${1:-}" == "claude-code-model-latency" ]]; then
  cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp app-proof-mode-started app=com.anthropic.claude-code scenario=claude-code-model-latency
LOG
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_TRACE_PATH" <<LOG
{"timestamp":"$base_timestamp","sessionID":"fresh-claude-code","suggestionID":"fresh-claude-code-${run_number}-${sample}","type":"modelResult","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","latencyMilliseconds":120,"metadata":{"behaviorProfile":"ai_chat","firstTokenLatencyMilliseconds":"90","totalGenerationLatencyMilliseconds":"120"}}
{"timestamp":"$base_timestamp","sessionID":"fresh-claude-code","suggestionID":"fresh-claude-code-${run_number}-${sample}","type":"suggestionPresented","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","latencyMilliseconds":130,"metadata":{"behaviorProfile":"ai_chat","candidateSelectionSource":"app-model-result","promptSafetyMode":"wordOnly"}}
LOG
  done
  exit 0
fi
if [[ "${1:-}" == "textedit-default-model-latency" ]]; then
  for sample in 1 2 3 4 5; do
    cat >>"$AUTOCOMPLETE_LAB_LOG" <<LOG
$base_timestamp mlx-completion-timing app=com.apple.TextEdit cleanedChars=18 cleanupMilliseconds=0 firstChunkMilliseconds=90 generationMilliseconds=120 maxTokens=14 mode=phraseContinuation promptMilliseconds=0 rawChars=18 sessionMilliseconds=0 totalMilliseconds=121
$base_timestamp suggestion-presented app=com.apple.TextEdit candidateSelectionSource=app-model-result latencyMilliseconds=130 requestMode=phraseContinuation traceID=fresh-default-${sample}
LOG
  done
  exit 0
fi
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

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-model.lock" \
    ./script/fresh_latency_proof.sh --target textedit-model-latency --runs 3
)"

if ! grep -F "textedit-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected textedit-model-latency to force one run" >&2
  echo "$MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected model-latency target to pass with one bounded launch" >&2
  echo "$MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "textedit-model-latency" ]]; then
  echo "fresh latency proof self-test expected model-latency smoke without --skip-build" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
CHROME_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-chrome-model.lock" \
    ./script/fresh_latency_proof.sh --target chrome-textarea-model-latency --runs 3
)"

if ! grep -F "chrome-textarea-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$CHROME_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected chrome-textarea-model-latency to force one run" >&2
  echo "$CHROME_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$CHROME_MODEL_OUTPUT" >/dev/null ||
   ! grep -F "First visible / keystroke-to-visible: n=5" <<<"$CHROME_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected chrome model-latency target to pass with one bounded launch" >&2
  echo "$CHROME_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one chrome model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "chrome-textarea-model-latency" ]]; then
  echo "fresh latency proof self-test expected chrome model-latency smoke without --skip-build" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for chrome model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
CHROME_CONTENTEDITABLE_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-chrome-contenteditable-model.lock" \
    ./script/fresh_latency_proof.sh --target chrome-contenteditable-model-latency --runs 3
)"

if ! grep -F "chrome-contenteditable-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$CHROME_CONTENTEDITABLE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected chrome-contenteditable-model-latency to force one run" >&2
  echo "$CHROME_CONTENTEDITABLE_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$CHROME_CONTENTEDITABLE_MODEL_OUTPUT" >/dev/null ||
   ! grep -F "First visible / keystroke-to-visible: n=5" <<<"$CHROME_CONTENTEDITABLE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected chrome contenteditable model-latency target to pass with one bounded launch" >&2
  echo "$CHROME_CONTENTEDITABLE_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one chrome contenteditable model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "chrome-contenteditable-model-latency" ]]; then
  echo "fresh latency proof self-test expected chrome contenteditable model-latency smoke without --skip-build" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for chrome contenteditable model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
CODEX_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-codex-model.lock" \
    ./script/fresh_latency_proof.sh --target codex-model-latency --runs 3
)"

if ! grep -F "codex-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$CODEX_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected codex-model-latency to force one run" >&2
  echo "$CODEX_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$CODEX_MODEL_OUTPUT" >/dev/null ||
   ! grep -F "First visible / keystroke-to-visible: n=5" <<<"$CODEX_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected codex model-latency target to pass with one bounded launch" >&2
  echo "$CODEX_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one codex model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 codex-model-latency --manual-gate" ]]; then
  echo "fresh latency proof self-test expected codex model-latency smoke with manual gate and screenshot trace" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for codex model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
CLAUDE_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-claude-model.lock" \
    ./script/fresh_latency_proof.sh --target claude-model-latency --runs 3
)"

if ! grep -F "claude-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$CLAUDE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected claude-model-latency to force one run" >&2
  echo "$CLAUDE_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$CLAUDE_MODEL_OUTPUT" >/dev/null ||
   ! grep -F "First visible / keystroke-to-visible: n=5" <<<"$CLAUDE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected claude model-latency target to pass with one bounded launch" >&2
  echo "$CLAUDE_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one claude model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 claude-model-latency --manual-gate" ]]; then
  echo "fresh latency proof self-test expected claude model-latency smoke with manual gate and screenshot trace" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for claude model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
CLAUDE_CODE_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-claude-code-model.lock" \
    ./script/fresh_latency_proof.sh --target claude-code-model-latency --runs 3
)"

if ! grep -F "claude-code-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$CLAUDE_CODE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected claude-code-model-latency to force one run" >&2
  echo "$CLAUDE_CODE_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Latency beta gate passed." <<<"$CLAUDE_CODE_MODEL_OUTPUT" >/dev/null ||
   ! grep -F "First visible / keystroke-to-visible: n=5" <<<"$CLAUDE_CODE_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected claude-code model-latency target to pass with one bounded launch" >&2
  echo "$CLAUDE_CODE_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(wc -l <"$SMOKE_LOG" | tr -d ' ')" != "1" ]]; then
  echo "fresh latency proof self-test expected one claude-code model-latency smoke run" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 claude-code-model-latency --manual-gate" ]]; then
  echo "fresh latency proof self-test expected claude-code model-latency smoke with manual gate and screenshot trace" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

if grep -F -- "--skip-build" "$SMOKE_LOG" >/dev/null; then
  echo "fresh latency proof self-test expected no skip-build rerun for claude-code model-latency target" >&2
  cat "$SMOKE_LOG" >&2
  exit 1
fi

: >"$SMOKE_LOG"
: >"$DIAGNOSTICS_LOG"
: >"$TRACE_LOG"
DEFAULT_MODEL_OUTPUT="$(
  AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-default-model.lock" \
    ./script/fresh_latency_proof.sh --target textedit-default-model-latency --runs 3
)"

if ! grep -F "textedit-default-model-latency collects the proof sample set in one launch; forcing --runs 1." <<<"$DEFAULT_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected textedit-default-model-latency to force one run" >&2
  echo "$DEFAULT_MODEL_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Default model proof passed" <<<"$DEFAULT_MODEL_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected default-model-latency target to pass the default model report" >&2
  echo "$DEFAULT_MODEL_OUTPUT" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$SMOKE_LOG")" != "textedit-default-model-latency" ]]; then
  echo "fresh latency proof self-test expected default-model-latency smoke without --skip-build" >&2
  cat "$SMOKE_LOG" >&2
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

FULL_SMOKE_BLOCKED_OUTPUT="$TMP_DIR/full-smoke-blocked-output.txt"
if AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-full-smoke-blocked.lock" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS=0 \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST=$'123 1 123 bash ./script/smoke_test.sh\n124 1 124 bash ./script/build_and_run.sh --verify' \
    ./script/fresh_latency_proof.sh --runs 1 >"$FULL_SMOKE_BLOCKED_OUTPUT" 2>&1; then
  echo "fresh latency proof self-test expected full smoke/build processes to block before selecting a window" >&2
  cat "$FULL_SMOKE_BLOCKED_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Another proof process is already active." "$FULL_SMOKE_BLOCKED_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected full smoke/build process warning" >&2
  cat "$FULL_SMOKE_BLOCKED_OUTPUT" >&2
  exit 1
fi

if ! grep -F 'current_process_ancestor_pids' script/fresh_latency_proof.sh >/dev/null ||
   ! grep -F 'relatedToSelf(pid)' script/fresh_latency_proof.sh >/dev/null ||
   ! grep -F 'script/check_current_build_privacy_export.sh' script/fresh_latency_proof.sh >/dev/null; then
  echo "fresh latency proof self-test expected ancestor-only process exclusion" >&2
  exit 1
fi

SELF_TEST_PGID="$(ps -o pgid= -p "$$" 2>/dev/null || true)"
SELF_TEST_PGID="${SELF_TEST_PGID//[[:space:]]/}"
if [[ -n "$SELF_TEST_PGID" ]]; then
  SAME_PGID_BLOCKED_OUTPUT="$TMP_DIR/same-pgid-build-blocked-output.txt"
  if AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
    AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
    AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
    AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
    AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-same-pgid-blocked.lock" \
    AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS=0 \
    AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST="123 1 $SELF_TEST_PGID bash ./script/check_controls_diagnostics_readiness.sh"$'\n' \
      ./script/fresh_latency_proof.sh --runs 1 >"$SAME_PGID_BLOCKED_OUTPUT" 2>&1; then
    echo "fresh latency proof self-test expected same-PGID proof process to block before selecting a window" >&2
    cat "$SAME_PGID_BLOCKED_OUTPUT" >&2
    exit 1
  fi

  if ! grep -F "Another proof process is already active." "$SAME_PGID_BLOCKED_OUTPUT" >/dev/null; then
    echo "fresh latency proof self-test expected same-PGID proof process warning" >&2
    cat "$SAME_PGID_BLOCKED_OUTPUT" >&2
    exit 1
  fi
fi

BETA_GATE_BLOCKED_OUTPUT="$TMP_DIR/beta-gate-blocked-output.txt"
if AUTOCOMPLETE_LAB_LOG="$DIAGNOSTICS_LOG" \
  AUTOCOMPLETE_LAB_TRACE_PATH="$TRACE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT="$SMOKE_STUB" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_SMOKE_LOG="$SMOKE_LOG" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR="$TMP_DIR/fresh-latency-beta-gate-blocked.lock" \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS=0 \
  AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST=$'123 1 123 bash ./script/check_score_targets.sh\n124 123 123 bash ./script/beta_readiness.sh --check-only\n125 124 123 bash ./script/check_controls_diagnostics_readiness.sh' \
    ./script/fresh_latency_proof.sh --target textedit-default-model-latency --runs 1 >"$BETA_GATE_BLOCKED_OUTPUT" 2>&1; then
  echo "fresh latency proof self-test expected beta readiness gates to block before selecting a window" >&2
  cat "$BETA_GATE_BLOCKED_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Another proof process is already active." "$BETA_GATE_BLOCKED_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected beta readiness process warning" >&2
  cat "$BETA_GATE_BLOCKED_OUTPUT" >&2
  exit 1
fi

if grep -F "Fresh latency proof start:" "$BETA_GATE_BLOCKED_OUTPUT" >/dev/null; then
  echo "fresh latency proof self-test expected no default latency window during beta readiness" >&2
  cat "$BETA_GATE_BLOCKED_OUTPUT" >&2
  exit 1
fi

echo "Fresh latency proof self-test passed."
