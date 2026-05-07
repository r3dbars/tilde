#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="textedit"
DRY_RUN=0
SKIP_BUILD="${AUTOCOMPLETE_LAB_SOAK_SKIP_BUILD:-0}"
STRICT_AX="${AUTOCOMPLETE_LAB_SOAK_STRICT_AX:-0}"
TARGET_CHARS="${AUTOCOMPLETE_LAB_SOAK_CHARS:-1800}"
CHUNK_SIZE="${AUTOCOMPLETE_LAB_SOAK_CHUNK_SIZE:-10}"
DELAY_MS="${AUTOCOMPLETE_LAB_SOAK_DELAY_MS:-15}"
MIN_EVENT_TAP_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_EVENT_TAP_SAMPLES:-100}"
MIN_AX_SAMPLES="${AUTOCOMPLETE_LAB_SOAK_MIN_AX_SAMPLES:-0}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/AutocompleteLab/diagnostics.log}"
DEFAULTS_DOMAIN="${AUTOCOMPLETE_LAB_DEFAULTS_DOMAIN:-bar.r3d.autocomplete-lab}"
TEXTEDIT_BUNDLE_ID="com.apple.TextEdit"
declare -a SOAK_TMP_DIRS=()
declare -a ORIGINAL_DISABLED_APPS=()
TEXTEDIT_DISABLED_FOR_SOAK=0

usage() {
  cat <<'EOF'
Usage: script/typing_performance_soak.sh [--dry-run] [--skip-build] [--strict-ax] [--characters N] [--chunk-size N] [--delay-ms N] [--require-event-tap-samples N] [--require-ax-samples N]

Runs a safe TextEdit typing soak with built-in neutral fixture text, then checks
diagnostics for keyboard event-tap latency. Focused-text AX polling is reported
separately and stays non-fatal unless --strict-ax is set.
EOF
}

cleanup_soak() {
  if ((TEXTEDIT_DISABLED_FOR_SOAK == 1)); then
    restore_disabled_apps
  fi

  if ((${#SOAK_TMP_DIRS[@]})); then
    rm -rf "${SOAK_TMP_DIRS[@]}"
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

delay_seconds() {
  local millis="$1"
  printf '%d.%03d\n' "$((millis / 1000))" "$((millis % 1000))"
}

computed_applescript_timeout_seconds() {
  local chunk_count
  chunk_count="$(((TARGET_CHARS + CHUNK_SIZE - 1) / CHUNK_SIZE))"
  echo "$((chunk_count * (DELAY_MS + 80) / 1000 + 180))"
}

generate_soak_text() {
  local target="$1"
  local text=""
  local index=0
  local sentences=(
    "this is a local typing soak for autocomplete lab."
    "the words are synthetic and safe to throw away."
    "the goal is to keep normal typing smooth for a long stretch."
    "event tap timing should stay fast while suggestions think in the background."
    "focused text warnings are useful but should not hide keyboard latency."
    "this disposable text never comes from a private document."
  )

  while ((${#text} < target)); do
    text+="${sentences[$((index % ${#sentences[@]}))]} "
    index=$((index + 1))
  done

  printf '%s' "${text:0:target}"
}

current_disabled_apps() {
  { defaults read "$DEFAULTS_DOMAIN" DisabledBundleIdentifiers 2>/dev/null || true; } |
    sed -n -E 's/^[[:space:]]*"?([A-Za-z0-9._-]+)"?,?$/\1/p'
}

write_disabled_apps() {
  if (($# == 0)); then
    defaults delete "$DEFAULTS_DOMAIN" DisabledBundleIdentifiers >/dev/null 2>&1 || true
    return 0
  fi

  defaults write "$DEFAULTS_DOMAIN" DisabledBundleIdentifiers -array "$@"
}

capture_original_disabled_apps() {
  ORIGINAL_DISABLED_APPS=()
  local bundle_identifier
  while IFS= read -r bundle_identifier; do
    [[ -n "$bundle_identifier" ]] || continue
    ORIGINAL_DISABLED_APPS+=("$bundle_identifier")
  done < <(current_disabled_apps)
}

textedit_is_disabled() {
  if ((${#ORIGINAL_DISABLED_APPS[@]} == 0)); then
    return 1
  fi

  local bundle_identifier
  for bundle_identifier in "${ORIGINAL_DISABLED_APPS[@]}"; do
    if [[ "$bundle_identifier" == "$TEXTEDIT_BUNDLE_ID" ]]; then
      return 0
    fi
  done

  return 1
}

restore_disabled_apps() {
  if ((${#ORIGINAL_DISABLED_APPS[@]} == 0)); then
    write_disabled_apps
  else
    write_disabled_apps "${ORIGINAL_DISABLED_APPS[@]}"
  fi
}

prepare_textedit_enablement() {
  capture_original_disabled_apps

  if ! textedit_is_disabled; then
    echo "TextEdit enablement: already allowed"
    return 0
  fi

  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "TextEdit is disabled in $DEFAULTS_DOMAIN, and --skip-build cannot refresh the running app state." >&2
    echo "Run without --skip-build so the soak can temporarily allow TextEdit before launching Autocomplete Lab." >&2
    exit 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "TextEdit enablement: would temporarily allow TextEdit before relaunch"
    return 0
  fi

  local filtered=()
  local bundle_identifier
  if ((${#ORIGINAL_DISABLED_APPS[@]} > 0)); then
    for bundle_identifier in "${ORIGINAL_DISABLED_APPS[@]}"; do
      if [[ "$bundle_identifier" != "$TEXTEDIT_BUNDLE_ID" ]]; then
        filtered+=("$bundle_identifier")
      fi
    done
  fi

  if ((${#filtered[@]} == 0)); then
    write_disabled_apps
  else
    write_disabled_apps "${filtered[@]}"
  fi
  TEXTEDIT_DISABLED_FOR_SOAK=1
  echo "TextEdit enablement: temporarily allowed TextEdit for this soak"
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

describe_plan() {
  echo "Safe typing performance soak"
  echo "Target app: TextEdit disposable temp file"
  echo "Diagnostics log: $LOG_PATH"
  echo "Defaults domain: $DEFAULTS_DOMAIN"
  if [[ "$SKIP_BUILD" == "1" ]]; then
    echo "Build: skipped; using an already-running app"
  else
    echo "Build: ./script/build_and_run.sh --verify"
  fi
  echo "Synthetic text: $TARGET_CHARS generated chars from a built-in neutral fixture"
  echo "Typing: $CHUNK_SIZE-char chunks with ${DELAY_MS}ms delay"
  echo "AppleScript timeout: $(computed_applescript_timeout_seconds)s"
  echo "Event tap proof: require at least $MIN_EVENT_TAP_SAMPLES samples"
  if is_truthy "$STRICT_AX"; then
    echo "AX warnings: strict; slow or skipped focused-text polling fails the soak"
  else
    echo "AX warnings: separate non-fatal lane"
  fi
  echo "AX sample proof: require at least $MIN_AX_SAMPLES focused-text poll samples"
}

type_textedit_fixture() {
  local tmp_dir text_file target_file delay timeout_seconds
  tmp_dir="$(make_tmp_dir)"
  text_file="$tmp_dir/autocomplete-lab-typing-soak-input.txt"
  target_file="$tmp_dir/autocomplete-lab-typing-soak.txt"
  delay="$(delay_seconds "$DELAY_MS")"
  timeout_seconds="$(computed_applescript_timeout_seconds)"

  generate_soak_text "$TARGET_CHARS" >"$text_file"
  : >"$target_file"

  open -a TextEdit "$target_file"
  sleep 1

  osascript <<APPLESCRIPT
set soakText to read POSIX file "$text_file" as «class utf8»
set soakChunkSize to $CHUNK_SIZE
set soakDelay to $delay

with timeout of 20 seconds
  tell application "TextEdit" to activate
  delay 0.4
  tell application "System Events"
    tell process "TextEdit"
      set frontmost to true
    end tell
    keystroke "a" using command down
    key code 51
  end tell
end timeout

with timeout of $timeout_seconds seconds
  tell application "System Events"
    repeat with chunkStart from 1 to (length of soakText) by soakChunkSize
      set chunkEnd to chunkStart + soakChunkSize - 1
      if chunkEnd > (length of soakText) then set chunkEnd to (length of soakText)
      keystroke (text chunkStart thru chunkEnd of soakText)
      if soakDelay > 0 then delay soakDelay
    end repeat
  end tell
end timeout
APPLESCRIPT
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

if ((TARGET_CHARS < 100)); then
  echo "--characters must be at least 100 so the soak can produce meaningful event-tap evidence." >&2
  exit 2
fi

if ((CHUNK_SIZE > 80)); then
  echo "--chunk-size must be 80 or lower so the soak stays typing-like." >&2
  exit 2
fi

describe_plan
prepare_textedit_enablement

if [[ "$DRY_RUN" == "1" ]]; then
  exit 0
fi

runtime_start_line="$(line_count "$LOG_PATH")"
build_if_needed
wait_for_runtime_ready "$runtime_start_line" "$SKIP_BUILD"

start_line="$(line_count "$LOG_PATH")"
type_textedit_fixture
sleep 1
run_checker "$start_line"

echo
echo "Typing soak complete."
