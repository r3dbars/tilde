#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="textedit"
DRY_RUN=0
SKIP_BUILD="${AUTOCOMPLETE_LAB_SOAK_SKIP_BUILD:-0}"
STRICT_AX="${AUTOCOMPLETE_LAB_SOAK_STRICT_AX:-0}"
TARGET_CHARS="${AUTOCOMPLETE_LAB_SOAK_CHARS:-1200}"
CHUNK_SIZE="${AUTOCOMPLETE_LAB_SOAK_CHUNK_SIZE:-5}"
DELAY_MS="${AUTOCOMPLETE_LAB_SOAK_DELAY_MS:-120}"
MIN_EVENT_TAP_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_EVENT_TAP_SAMPLES:-100}"
MIN_AX_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_AX_SAMPLES:-0}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
SEGMENT_CHARS="${AUTOCOMPLETE_LAB_SOAK_SEGMENT_CHARS:-1200}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.autocomplete-lab}"
PAUSE_DEFAULTS_KEY="SuggestionsPaused"
PAUSE_DEFAULTS_WAS_PREPARED=0
PAUSE_DEFAULTS_PREVIOUS_EXISTS=0
PAUSE_DEFAULTS_PREVIOUS=""
SOAK_EXPECTED_TEXT_FILE=""
SOAK_ACTUAL_TEXT_FILE=""
SOAK_TYPING_START_LINE=""
TEMP_ENABLE_ENV_KEY="AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=0
TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""
declare -a SOAK_TMP_DIRS=()

usage() {
  cat <<'EOF'
Usage: script/typing_performance_soak.sh [--dry-run] [--skip-build] [--strict-ax] [--characters N] [--chunk-size N] [--delay-ms N] [--require-event-tap-samples N] [--require-ax-samples N]

Runs a safe TextEdit typing soak with built-in neutral fixture text, then checks
diagnostics for keyboard event-tap latency. Focused-text AX polling is reported
separately and stays non-fatal unless --strict-ax is set.
EOF
}

cleanup_soak() {
  if ((${#SOAK_TMP_DIRS[@]})); then
    rm -rf "${SOAK_TMP_DIRS[@]}"
  fi

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" == "1" ]]; then
    if [[ -n "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" ]]; then
      launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$TEMP_ENABLE_LAUNCHCTL_PREVIOUS" >/dev/null 2>&1 || true
    else
      launchctl unsetenv "$TEMP_ENABLE_ENV_KEY" >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$PAUSE_DEFAULTS_WAS_PREPARED" == "1" ]]; then
    if [[ "$PAUSE_DEFAULTS_PREVIOUS_EXISTS" == "1" ]]; then
      defaults write "$DEFAULTS_DOMAIN" "$PAUSE_DEFAULTS_KEY" -bool "$PAUSE_DEFAULTS_PREVIOUS" >/dev/null 2>&1 || true
    else
      defaults delete "$DEFAULTS_DOMAIN" "$PAUSE_DEFAULTS_KEY" >/dev/null 2>&1 || true
    fi
  fi
}

trap cleanup_soak EXIT

make_tmp_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  SOAK_TMP_DIRS+=("$tmp_dir")
  printf '%s\n' "$tmp_dir"
}

is_truthy() {
  [[ "$1" =~ ^(1|true|yes|on)$ ]]
}

require_non_negative_int() {
  local value="$1"
  local label="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "$label must be a non-negative integer, got: $value" >&2
    exit 2
  fi
}

require_positive_int() {
  local value="$1"
  local label="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || ((value <= 0)); then
    echo "$label must be a positive integer, got: $value" >&2
    exit 2
  fi
}

line_count() {
  local path="$1"
  if [[ -f "$path" ]]; then
    wc -l <"$path" | tr -d ' '
  else
    echo 0
  fi
}

wait_for_focused_text_poll_summary_after_line() {
  local start_line="$1"
  local timeout_seconds="${2:-15}"
  local deadline=$((SECONDS + timeout_seconds))
  local first_new_line=$((start_line + 1))

  while ((SECONDS < deadline)); do
    if [[ -f "$LOG_PATH" ]] &&
      sed -n "${first_new_line},\$p" "$LOG_PATH" | grep -q "focused-text-poll-latency-summary"; then
      return 0
    fi
    sleep 0.25
  done

  echo "Note: no focused-text poll summary arrived during the pre-typing warmup window." >&2
}

computed_typing_budget_seconds() {
  local chunk_count
  chunk_count="$(((TARGET_CHARS + CHUNK_SIZE - 1) / CHUNK_SIZE))"
  echo "$((chunk_count * (DELAY_MS + 80) / 1000 + 180))"
}

computed_segment_typing_budget_seconds() {
  local segment_length="$1"
  local chunk_count
  chunk_count="$(((segment_length + CHUNK_SIZE - 1) / CHUNK_SIZE))"
  echo "$((chunk_count * (DELAY_MS + 80) / 1000 + 60))"
}

delay_seconds() {
  local millis="$1"
  printf '%d.%03d\n' "$((millis / 1000))" "$((millis % 1000))"
}

verify_typed_text() {
  local expected_file="$1"
  local actual_file="$2"

  python3 - "$expected_file" "$actual_file" <<'PY'
import sys

expected_path, actual_path = sys.argv[1:3]
with open(expected_path, "r", encoding="utf-8") as handle:
    expected = handle.read()
with open(actual_path, "r", encoding="utf-8") as handle:
    actual = handle.read().rstrip("\n")

if actual != expected:
    mismatch = next(
        (index for index, pair in enumerate(zip(expected, actual)) if pair[0] != pair[1]),
        min(len(expected), len(actual)),
    )
    raise SystemExit(
        "typed text verification failed: "
        f"expected {len(expected)} chars, got {len(actual)} chars, "
        f"first mismatch at char {mismatch}"
    )

print(f"Typed text verified: {len(expected)} chars matched TextEdit exactly.")
PY
}

prepare_textedit_document() {
  local attempt

  for attempt in 1 2; do
    if osascript >/dev/null <<'APPLESCRIPT'
with timeout of 20 seconds
  tell application "TextEdit"
    activate
    make new document
    set text of front document to ""
  end tell
end timeout
APPLESCRIPT
    then
      return 0
    fi

    echo "TextEdit document setup attempt $attempt failed; retrying." >&2
    open -a TextEdit
    sleep 1
  done

  echo "TextEdit document setup failed after 2 attempts." >&2
  return 1
}

capture_typed_text() {
  local actual_file="$1"
  local clipboard_file="$2"

  if capture_typed_text_with_textedit_timeout "$actual_file" 45; then
    return 0
  fi

  echo "TextEdit document read timed out; falling back to UI copy verification." >&2
  pbpaste >"$clipboard_file" 2>/dev/null || : >"$clipboard_file"
  osascript >/dev/null <<'APPLESCRIPT'
with timeout of 20 seconds
  tell application "System Events"
    tell process "TextEdit"
      set frontmost to true
      if exists text area 1 of scroll area 1 of front window then
        click text area 1 of scroll area 1 of front window
      end if
      keystroke "a" using {command down}
      delay 0.2
      keystroke "c" using {command down}
      delay 0.4
    end tell
  end tell
end timeout
APPLESCRIPT
  pbpaste >"$actual_file"
  pbcopy <"$clipboard_file" || true
}

capture_typed_text_with_textedit_timeout() {
  local actual_file="$1"
  local timeout_seconds="$2"
  local pid deadline

  osascript >/dev/null <<APPLESCRIPT &
set outputFile to POSIX file "$actual_file"
tell application "TextEdit"
  set docText to text of front document
end tell
set fileRef to open for access outputFile with write permission
set eof of fileRef to 0
write docText to fileRef as «class utf8»
close access fileRef
APPLESCRIPT
  pid=$!
  deadline=$((SECONDS + timeout_seconds))

  while kill -0 "$pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 1
    fi
    sleep 0.2
  done

  wait "$pid"
}

focus_textedit_document() {
  osascript >/dev/null <<'APPLESCRIPT'
with timeout of 20 seconds
  tell application "System Events"
    repeat 20 times
      if exists process "TextEdit" then exit repeat
      delay 0.1
    end repeat
    tell process "TextEdit"
      set frontmost to true
      if exists text area 1 of scroll area 1 of front window then
        click text area 1 of scroll area 1 of front window
      end if
    end tell
  end tell
end timeout
APPLESCRIPT
}

type_text_with_system_events() {
  local text_file="$1"
  local delay text total_length offset segment segment_file segment_length segment_dir

  delay="$(delay_seconds "$DELAY_MS")"
  text="$(<"$text_file")"
  total_length="${#text}"
  offset=0
  segment_dir="$(make_tmp_dir)"

  while ((offset < total_length)); do
    segment="${text:offset:SEGMENT_CHARS}"
    segment_file="$segment_dir/segment-$offset.txt"
    printf '%s' "$segment" >"$segment_file"
    segment_length="${#segment}"
    type_text_segment_with_system_events "$segment_file" "$segment_length" "$delay"
    offset=$((offset + segment_length))
    sleep 0.3
  done
}

type_text_segment_with_system_events() {
  local text_file="$1"
  local segment_length="$2"
  local delay="$3"
  local timeout_seconds

  timeout_seconds="$(computed_segment_typing_budget_seconds "$segment_length")"

  osascript - "$text_file" "$CHUNK_SIZE" "$delay" "$timeout_seconds" <<'APPLESCRIPT'
on run argv
  set textFile to item 1 of argv
  set soakText to read POSIX file textFile as «class utf8»
  set soakChunkSize to item 2 of argv as integer
  set soakDelay to item 3 of argv as real
  set timeoutSeconds to item 4 of argv as integer

  with timeout of timeoutSeconds seconds
    tell application "System Events"
      repeat with chunkStart from 1 to (length of soakText) by soakChunkSize
        set chunkEnd to chunkStart + soakChunkSize - 1
        if chunkEnd > (length of soakText) then set chunkEnd to (length of soakText)
        tell process "TextEdit" to set frontmost to true
        keystroke (text chunkStart thru chunkEnd of soakText)
        if soakDelay > 0 then delay soakDelay
      end repeat
    end tell
  end timeout
end run
APPLESCRIPT
}

generate_soak_text() {
  local target="$1"
  local text=""
  local index=0
  local sentences=(
    "this is a local typing soak for autocomplete lab"
    "the words are synthetic and safe to throw away"
    "the goal is to keep normal typing smooth for a long stretch"
    "event tap timing should stay fast while suggestions think in the background"
    "focused text warnings are useful but should not hide keyboard latency"
    "this disposable text never comes from a private document"
  )

  while ((${#text} < target)); do
    text+="${sentences[$((index % ${#sentences[@]}))]} "
    index=$((index + 1))
  done

  text="${text:0:target}"
  printf '%s%s' "$(printf '%s' "${text:0:1}" | tr '[:lower:]' '[:upper:]')" "${text:1}"
}

latest_runtime_is_ready() {
  local latest_runtime_line
  latest_runtime_line="$(grep -E " runtime .*readinessStage=" "$LOG_PATH" 2>/dev/null | tail -n 1 || true)"
  [[ "$latest_runtime_line" == *"readinessStage=ready"* ]]
}

wait_for_runtime_ready() {
  local start_line="$1"
  local allow_existing_ready="$2"
  local timeout_seconds="${AUTOCOMPLETE_LAB_SOAK_READY_TIMEOUT_SECONDS:-60}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS <= deadline)); do
    if tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | grep -E " runtime .*readinessStage=ready" >/dev/null; then
      return 0
    fi

    if [[ "$allow_existing_ready" == "1" ]] && latest_runtime_is_ready; then
      return 0
    fi

    sleep 0.2
  done

  echo "Timed out waiting for AutocompleteLab runtime readiness." >&2
  echo "Log: $LOG_PATH" >&2
  tail -n +"$((start_line + 1))" "$LOG_PATH" 2>/dev/null | tail -n 80 >&2
  exit 1
}

build_if_needed() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    return 0
  fi

  ./script/build_and_run.sh --verify
}

prepare_temporary_textedit_enablement() {
  local bundle_ids="com.apple.TextEdit"

  if [[ "$TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED" != "1" ]]; then
    TEMP_ENABLE_LAUNCHCTL_PREVIOUS="$(launchctl getenv "$TEMP_ENABLE_ENV_KEY" 2>/dev/null || true)"
    TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=1
  fi

  export AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS="$bundle_ids"
  launchctl setenv "$TEMP_ENABLE_ENV_KEY" "$bundle_ids" >/dev/null 2>&1 || true
  echo "Temporary app enablement for soak: $bundle_ids"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so temporary enablement only applies if the app was launched with this environment." >&2
  fi
}

prepare_temporary_suggestions_resume() {
  if [[ "$PAUSE_DEFAULTS_WAS_PREPARED" != "1" ]]; then
    if PAUSE_DEFAULTS_PREVIOUS="$(defaults read "$DEFAULTS_DOMAIN" "$PAUSE_DEFAULTS_KEY" 2>/dev/null)"; then
      PAUSE_DEFAULTS_PREVIOUS_EXISTS=1
      case "$PAUSE_DEFAULTS_PREVIOUS" in
        1|true|TRUE|yes|YES)
          PAUSE_DEFAULTS_PREVIOUS=true
          ;;
        *)
          PAUSE_DEFAULTS_PREVIOUS=false
          ;;
      esac
    else
      PAUSE_DEFAULTS_PREVIOUS_EXISTS=0
      PAUSE_DEFAULTS_PREVIOUS=false
    fi
    PAUSE_DEFAULTS_WAS_PREPARED=1
  fi

  defaults write "$DEFAULTS_DOMAIN" "$PAUSE_DEFAULTS_KEY" -bool false >/dev/null
  echo "Temporary suggestions state for soak: resumed"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Note: --skip-build uses the already-running app, so temporary pause-state changes only apply if the app reloads them." >&2
  fi
}

describe_plan() {
  echo "Safe typing performance soak"
  echo "Target app: disposable TextEdit document"
  echo "Diagnostics log: $LOG_PATH"
  echo "Safety: temporarily enables TextEdit only for this proof pass"
  echo "Safety: temporarily resumes suggestions and restores the previous pause state"
  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Build: skipped; using an already-running app"
  else
    echo "Build: ./script/build_and_run.sh --verify"
  fi
  echo "Synthetic text: $TARGET_CHARS generated chars from a built-in neutral fixture"
  echo "Typed text proof: exact TextEdit document match required"
  echo "Clipboard fallback: used only if direct TextEdit read fails"
  echo "Typing driver: System Events key chunks"
  echo "Typing batches: up to $SEGMENT_CHARS chars per AppleScript process"
  echo "AX warmup: waits for a focused-text poll summary before typing"
  echo "Typing: $CHUNK_SIZE-char chunks with ${DELAY_MS}ms delay"
  echo "Typing duration budget: $(computed_typing_budget_seconds)s"
  echo "Event tap proof: require at least $MIN_EVENT_TAP_SAMPLES samples"
  if is_truthy "$STRICT_AX"; then
    echo "AX warnings: strict; slow or skipped focused-text polling fails the soak"
  else
    echo "AX warnings: separate non-fatal lane"
  fi
  echo "AX sample proof: require at least $MIN_AX_SAMPLES focused-text poll samples"
}

type_textedit_fixture() {
  local tmp_dir text_file actual_file clipboard_file
  tmp_dir="$(make_tmp_dir)"
  text_file="$tmp_dir/autocomplete-lab-typing-soak-input.txt"
  actual_file="$tmp_dir/autocomplete-lab-typing-soak-actual.txt"
  clipboard_file="$tmp_dir/autocomplete-lab-typing-soak-clipboard.txt"
  SOAK_EXPECTED_TEXT_FILE="$text_file"
  SOAK_ACTUAL_TEXT_FILE="$actual_file"
  generate_soak_text "$TARGET_CHARS" >"$text_file"
  prepare_textedit_document
  focus_textedit_document
  sleep 1
  wait_for_focused_text_poll_summary_after_line "$(line_count "$LOG_PATH")" 15
  SOAK_TYPING_START_LINE="$(line_count "$LOG_PATH")"
  type_text_with_system_events "$text_file"
  sleep 2
  capture_typed_text "$SOAK_ACTUAL_TEXT_FILE" "$clipboard_file"
  verify_typed_text "$SOAK_EXPECTED_TEXT_FILE" "$SOAK_ACTUAL_TEXT_FILE"
}

run_checker() {
  local start_line="$1"

  echo
  echo "== Event tap guard =="
  echo "Keyboard event-tap latency is fatal here; focused-text AX warnings print separately."
  AUTOCOMPLETE_LAB_LOG_START_LINE="$start_line" \
  AUTOCOMPLETE_LAB_TYPING_PERF_REQUIRE_SAMPLES="$MIN_EVENT_TAP_SAMPLES" \
  AUTOCOMPLETE_LAB_FOCUSED_TEXT_POLL_REQUIRE_SAMPLES="$MIN_AX_SAMPLES" \
  AUTOCOMPLETE_LAB_TYPING_PERF_FAIL_ON_FOCUSED_POLL="$STRICT_AX" \
    ./script/check_typing_performance_log.sh
}

while (($#)); do
  case "$1" in
    --app)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      APP="$1"
      ;;
    --app=*)
      APP="${1#--app=}"
      ;;
    --characters)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      TARGET_CHARS="$1"
      ;;
    --characters=*)
      TARGET_CHARS="${1#--characters=}"
      ;;
    --chunk-size)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      CHUNK_SIZE="$1"
      ;;
    --chunk-size=*)
      CHUNK_SIZE="${1#--chunk-size=}"
      ;;
    --delay-ms)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      DELAY_MS="$1"
      ;;
    --delay-ms=*)
      DELAY_MS="${1#--delay-ms=}"
      ;;
    --require-event-tap-samples)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      MIN_EVENT_TAP_SAMPLES="$1"
      ;;
    --require-event-tap-samples=*)
      MIN_EVENT_TAP_SAMPLES="${1#--require-event-tap-samples=}"
      ;;
    --require-ax-samples)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      MIN_AX_SAMPLES="$1"
      ;;
    --require-ax-samples=*)
      MIN_AX_SAMPLES="${1#--require-ax-samples=}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --strict-ax)
      STRICT_AX=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$APP" in
  textedit)
    ;;
  *)
    echo "Unsupported soak app: $APP" >&2
    echo "Only TextEdit is automated because it is disposable and does not touch private text." >&2
    exit 2
    ;;
esac

require_positive_int "$TARGET_CHARS" "--characters"
require_positive_int "$CHUNK_SIZE" "--chunk-size"
require_non_negative_int "$DELAY_MS" "--delay-ms"
require_non_negative_int "$MIN_EVENT_TAP_SAMPLES" "--require-event-tap-samples"
require_non_negative_int "$MIN_AX_SAMPLES" "--require-ax-samples"
require_positive_int "$SEGMENT_CHARS" "AUTOCOMPLETE_LAB_SOAK_SEGMENT_CHARS"

if ((TARGET_CHARS < 100)); then
  echo "--characters must be at least 100 so the soak can produce meaningful event-tap evidence." >&2
  exit 2
fi

if ((CHUNK_SIZE > 80)); then
  echo "--chunk-size must be 80 or lower so the soak stays typing-like." >&2
  exit 2
fi

describe_plan

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

runtime_start_line="$(line_count "$LOG_PATH")"
prepare_temporary_textedit_enablement
prepare_temporary_suggestions_resume
build_if_needed
wait_for_runtime_ready "$runtime_start_line" "$SKIP_BUILD"

type_textedit_fixture
sleep 1
run_checker "${SOAK_TYPING_START_LINE:-$(line_count "$LOG_PATH")}"

echo
echo "Typing soak complete."
