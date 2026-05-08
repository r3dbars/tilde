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
KEY_DELAY_US="${AUTOCOMPLETE_LAB_SOAK_KEY_DELAY_US:-3000}"
MIN_EVENT_TAP_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_EVENT_TAP_SAMPLES:-0}"
MIN_AX_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_AX_SAMPLES:-0}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
SEGMENT_CHARS="${AUTOCOMPLETE_LAB_SOAK_SEGMENT_CHARS:-250}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.autocomplete-lab}"
PAUSE_DEFAULTS_KEY="SuggestionsPaused"
PAUSE_DEFAULTS_WAS_PREPARED=0
PAUSE_DEFAULTS_PREVIOUS_EXISTS=0
PAUSE_DEFAULTS_PREVIOUS=""
SOAK_EXPECTED_TEXT_FILE=""
SOAK_ACTUAL_TEXT_FILE=""
SOAK_TARGET_TEXT_FILE=""
SOAK_TARGET_DOCUMENT_NAME=""
SOAK_TYPING_START_LINE=""
TEMP_ENABLE_ENV_KEY="AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
TEMP_ENABLE_LAUNCHCTL_WAS_PREPARED=0
TEMP_ENABLE_LAUNCHCTL_PREVIOUS=""
declare -a SOAK_TMP_DIRS=()

usage() {
  cat <<'EOF'
Usage: script/typing_performance_soak.sh [--dry-run] [--skip-build] [--strict-ax] [--characters N] [--chunk-size N] [--delay-ms N] [--key-delay-us N] [--require-event-tap-samples N] [--require-ax-samples N]

Runs a safe TextEdit typing soak with built-in neutral fixture text, then checks
diagnostics for keyboard event-tap latency. Focused-text AX polling is reported
separately and stays non-fatal unless --strict-ax is set.
EOF
}

cleanup_soak() {
  if [[ -n "$SOAK_TARGET_DOCUMENT_NAME" ]]; then
    close_textedit_document "$SOAK_TARGET_DOCUMENT_NAME" >/dev/null 2>&1 || true
  fi

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
  local target_file="${1:-}"
  local target_name attempt actual_name

  if [[ -z "$target_file" ]]; then
    echo "prepare_textedit_document needs a target file path" >&2
    return 1
  fi

  target_name="$(basename "$target_file")"
  : >"$target_file"

  for attempt in 1 2; do
    open -F -a TextEdit "$target_file" >/dev/null 2>&1 || true
    osascript - "$target_file" "$target_name" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set targetPath to item 1 of argv
  set targetName to item 2 of argv
  tell application "TextEdit"
    activate
    open (POSIX file targetPath)
  end tell
end run
APPLESCRIPT
    sleep 0.5
    if actual_name="$(
      osascript - "$target_name" <<'APPLESCRIPT'
on run argv
  set expectedName to item 1 of argv
  with timeout of 20 seconds
    tell application "System Events"
      repeat 50 times
        if exists process "TextEdit" then exit repeat
        delay 0.1
      end repeat
      if not (exists process "TextEdit") then error "TextEdit process did not launch"

      tell process "TextEdit"
        set frontmost to true
        delay 0.2
      end tell

      set targetName to ""
      repeat 40 times
        tell process "TextEdit"
          set frontmost to true
          if exists window expectedName then
            set targetName to name of window expectedName
            exit repeat
          end if
        end tell
        delay 0.1
      end repeat

      tell process "TextEdit"
        if targetName is "" then error "missing TextEdit soak front window"
        perform action "AXRaise" of window targetName
        delay 0.1
        if exists text area 1 of scroll area 1 of window targetName then
          click text area 1 of scroll area 1 of window targetName
        end if
        keystroke "a" using {command down}
        key code 51
        key code 53
      end tell
    end tell

    return targetName
  end timeout
end run
APPLESCRIPT
    )"; then
      printf '%s\n' "$actual_name"
      return 0
    fi

    echo "TextEdit document setup attempt $attempt failed; retrying." >&2
    open -F -a TextEdit "$target_file" >/dev/null 2>&1 || true
    osascript - "$target_file" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  tell application "TextEdit"
    activate
    open (POSIX file (item 1 of argv))
  end tell
end run
APPLESCRIPT
    sleep 1
  done

  echo "TextEdit document setup failed after 2 attempts." >&2
  return 1
}

capture_typed_text() {
  local actual_file="$1"
  local target_name="$2"
  local clipboard_file
  clipboard_file="$(make_tmp_dir)/previous-clipboard.txt"

  pbpaste >"$clipboard_file" 2>/dev/null || true

  if capture_typed_text_with_textedit_timeout "$actual_file" "$target_name" 45; then
    pbcopy <"$clipboard_file" 2>/dev/null || true
    return 0
  fi

  pbcopy <"$clipboard_file" 2>/dev/null || true
  echo "TextEdit document read timed out." >&2
  return 1
}

capture_typed_text_with_textedit_timeout() {
  local actual_file="$1"
  local target_name="$2"
  local timeout_seconds="$3"
  local pid deadline status

  osascript - "$target_name" >/dev/null <<'APPLESCRIPT' &
on run argv
  set targetName to item 1 of argv

  tell application "System Events"
    tell process "TextEdit"
      set frontmost to true
      if not (exists window targetName) then error "missing TextEdit soak window " & targetName
      perform action "AXRaise" of window targetName
      delay 0.1
      if exists text area 1 of scroll area 1 of window targetName then
        click text area 1 of scroll area 1 of window targetName
      end if
      keystroke "a" using {command down}
      delay 0.1
      keystroke "c" using {command down}
    end tell
  end tell
end run
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
  status=$?
  if ((status != 0)); then
    return "$status"
  fi

  pbpaste >"$actual_file"
}

close_textedit_document() {
  local target_name="$1"
  local pid deadline

  osascript - "$target_name" >/dev/null <<'APPLESCRIPT' &
on run argv
  set targetName to item 1 of argv
  tell application "TextEdit"
    if exists document targetName then
      close document targetName saving no
    end if
  end tell
end run
APPLESCRIPT
  pid=$!
  deadline=$((SECONDS + 5))

  while kill -0 "$pid" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "Warning: timed out closing TextEdit soak document: $target_name" >&2
      return 1
    fi
    sleep 0.2
  done

  wait "$pid"
}

focus_textedit_document() {
  local target_name="$1"

  open -a TextEdit >/dev/null 2>&1 || true
  osascript - "$target_name" >/dev/null <<'APPLESCRIPT'
on run argv
  set targetName to item 1 of argv

with timeout of 20 seconds
  tell application "System Events"
    repeat 50 times
      if exists process "TextEdit" then
        tell process "TextEdit"
          set frontmost to true
          if exists window targetName then
            perform action "AXRaise" of window targetName
            if exists text area 1 of scroll area 1 of window targetName then
              click text area 1 of scroll area 1 of window targetName
            end if
          end if
        end tell
      end if

      delay 0.05
      if (name of first application process whose frontmost is true) is "TextEdit" then
        tell process "TextEdit"
          if exists window targetName then return
        end tell
      end if
      delay 0.1
    end repeat
    error "TextEdit soak target did not become frontmost: " & targetName
  end tell
end timeout
end run
APPLESCRIPT
}

type_text_with_cgevents() {
  local text_file="$1"
  local text total_length offset segment segment_file segment_length segment_dir

  text="$(<"$text_file")"
  total_length="${#text}"
  offset=0
  segment_dir="$(make_tmp_dir)"

  while ((offset < total_length)); do
    segment="${text:offset:SEGMENT_CHARS}"
    segment_file="$segment_dir/segment-$offset.txt"
    printf '%s' "$segment" >"$segment_file"
    segment_length="${#segment}"
    focus_textedit_document "$SOAK_TARGET_DOCUMENT_NAME"
    type_text_segment_with_cgevents "$segment_file"
    offset=$((offset + segment_length))
    sleep 0.3
  done
}

type_text_segment_with_cgevents() {
  local text_file="$1"

  swift - "$text_file" "$CHUNK_SIZE" "$DELAY_MS" "$KEY_DELAY_US" <<'SWIFT'
import ApplicationServices
import Foundation

guard CommandLine.arguments.count == 5,
      let chunkSize = Int(CommandLine.arguments[2]),
      let delayMilliseconds = Int(CommandLine.arguments[3]),
      let keyDelayMicroseconds = useconds_t(CommandLine.arguments[4]),
      chunkSize > 0,
      delayMilliseconds >= 0 else {
    FileHandle.standardError.write(Data("invalid CGEvent typing arguments\n".utf8))
    exit(2)
}

let textPath = CommandLine.arguments[1]
let text = try String(contentsOfFile: textPath, encoding: .utf8)
let source = CGEventSource(stateID: .hidSystemState)
source?.localEventsSuppressionInterval = 0
let delayMicros = useconds_t(delayMilliseconds * 1_000)

var typedScalars = 0
for scalar in text.unicodeScalars {
    var units = Array(String(scalar).utf16)
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        FileHandle.standardError.write(Data("failed to create CGEvent\n".utf8))
        exit(1)
    }

    keyDown.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)

    typedScalars += 1
    if keyDelayMicroseconds > 0 {
        usleep(keyDelayMicroseconds)
    }
    if typedScalars % chunkSize == 0 && delayMicros > 0 {
        usleep(delayMicros)
    }
}
SWIFT
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
  echo "Target app: disposable TextEdit window"
  echo "Diagnostics log: $LOG_PATH"
  echo "Safety: temporarily enables TextEdit only for this proof pass"
  echo "Safety: temporarily resumes suggestions and restores the previous pause state"
  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Build: skipped; using an already-running app"
  else
    echo "Build: ./script/build_and_run.sh --verify"
  fi
  echo "Synthetic text: $TARGET_CHARS generated chars from a built-in neutral fixture"
  echo "Typed text proof: exact TextEdit clipboard capture match required"
  echo "Typing driver: CGEvent Unicode key events after target-window focus"
  echo "Typing batches: up to $SEGMENT_CHARS chars per Swift process"
  echo "AX warmup: waits for a focused-text poll summary before typing"
  echo "Typing: $CHUNK_SIZE-char chunks with ${DELAY_MS}ms delay and ${KEY_DELAY_US}us key spacing"
  echo "Typing duration budget: $(computed_typing_budget_seconds)s"
  if ((MIN_EVENT_TAP_SAMPLES > 0)); then
    echo "Event tap proof: require at least $MIN_EVENT_TAP_SAMPLES samples"
  else
    echo "Event tap proof: not required for this normal-typing pass"
  fi
  if is_truthy "$STRICT_AX"; then
    echo "AX warnings: strict; threshold-exceeding or skipped focused-text polling fails the soak"
  else
    echo "AX warnings: separate non-fatal lane"
  fi
  echo "AX sample proof: require at least $MIN_AX_SAMPLES focused-text poll samples"
}

type_textedit_fixture() {
  local tmp_dir text_file actual_file target_file
  tmp_dir="$(make_tmp_dir)"
  text_file="$tmp_dir/autocomplete-lab-typing-soak-input.txt"
  actual_file="$tmp_dir/autocomplete-lab-typing-soak-actual.txt"
  target_file="$tmp_dir/autocomplete-lab-typing-soak-$(date +%Y%m%d%H%M%S)-$$-$RANDOM.txt"
  SOAK_EXPECTED_TEXT_FILE="$text_file"
  SOAK_ACTUAL_TEXT_FILE="$actual_file"
  SOAK_TARGET_TEXT_FILE="$target_file"
  SOAK_TARGET_DOCUMENT_NAME=""
  generate_soak_text "$TARGET_CHARS" >"$text_file"
  SOAK_TARGET_DOCUMENT_NAME="$(prepare_textedit_document "$SOAK_TARGET_TEXT_FILE")"
  focus_textedit_document "$SOAK_TARGET_DOCUMENT_NAME"
  sleep 1
  wait_for_focused_text_poll_summary_after_line "$(line_count "$LOG_PATH")" 15
  SOAK_TYPING_START_LINE="$(line_count "$LOG_PATH")"
  type_text_with_cgevents "$text_file"
  sleep 2
  capture_typed_text "$SOAK_ACTUAL_TEXT_FILE" "$SOAK_TARGET_DOCUMENT_NAME"
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
    --key-delay-us)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      KEY_DELAY_US="$1"
      ;;
    --key-delay-us=*)
      KEY_DELAY_US="${1#--key-delay-us=}"
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
require_non_negative_int "$KEY_DELAY_US" "--key-delay-us"
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
