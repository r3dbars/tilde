#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=0
SKIP_BUILD=0
STRICT_AX=0
MINUTES="${AUTOCOMPLETE_LAB_ENDURANCE_SOAK_MINUTES:-10}"
CHUNK_SIZE="${AUTOCOMPLETE_LAB_ENDURANCE_SOAK_CHUNK_SIZE:-5}"
DELAY_MS="${AUTOCOMPLETE_LAB_ENDURANCE_SOAK_DELAY_MS:-250}"
MIN_EVENT_TAP_SAMPLES="${AUTOCOMPLETE_LAB_ENDURANCE_SOAK_MIN_EVENT_TAP_SAMPLES:-0}"
MIN_AX_SAMPLES="${AUTOCOMPLETE_LAB_ENDURANCE_SOAK_MIN_AX_SAMPLES:-0}"

usage() {
  cat <<'EOF'
Usage: script/typing_performance_endurance_soak.sh [--dry-run] [--skip-build] [--strict-ax] [--minutes N] [--chunk-size N] [--delay-ms N] [--require-event-tap-samples N] [--require-ax-samples N]

Runs the long disposable TextEdit typing endurance pass used for the
Apple-native "typing feels untouched" gate. The default is a 10-minute target.
EOF
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

while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --strict-ax)
      STRICT_AX=1
      ;;
    --minutes)
      shift
      if (($# == 0)); then
        usage >&2
        exit 2
      fi
      MINUTES="$1"
      ;;
    --minutes=*)
      MINUTES="${1#--minutes=}"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_positive_int "$MINUTES" "--minutes"
require_positive_int "$CHUNK_SIZE" "--chunk-size"
require_positive_int "$DELAY_MS" "--delay-ms"
require_non_negative_int "$MIN_EVENT_TAP_SAMPLES" "--require-event-tap-samples"
require_non_negative_int "$MIN_AX_SAMPLES" "--require-ax-samples"

if ((CHUNK_SIZE > 80)); then
  echo "--chunk-size must be 80 or lower so the soak stays typing-like." >&2
  exit 2
fi

if ((DELAY_MS < 10)); then
  echo "--delay-ms must be at least 10 for endurance runs." >&2
  exit 2
fi

TARGET_CHARS="$((MINUTES * 60 * 1000 / (DELAY_MS + 80) * CHUNK_SIZE))"
if ((TARGET_CHARS < 100)); then
  TARGET_CHARS=100
fi

echo "Typing endurance soak"
echo "Duration target: $MINUTES minute(s)"
echo "Computed text: $TARGET_CHARS generated chars"
echo "Underlying command: script/typing_performance_soak.sh --characters $TARGET_CHARS --chunk-size $CHUNK_SIZE --delay-ms $DELAY_MS --require-event-tap-samples $MIN_EVENT_TAP_SAMPLES --require-ax-samples $MIN_AX_SAMPLES"

args=(
  --characters "$TARGET_CHARS"
  --chunk-size "$CHUNK_SIZE"
  --delay-ms "$DELAY_MS"
  --require-event-tap-samples "$MIN_EVENT_TAP_SAMPLES"
  --require-ax-samples "$MIN_AX_SAMPLES"
)

if ((DRY_RUN == 1)); then
  args+=(--dry-run)
fi

if ((SKIP_BUILD == 1)); then
  args+=(--skip-build)
fi

if ((STRICT_AX == 1)); then
  args+=(--strict-ax)
fi

./script/typing_performance_soak.sh "${args[@]}"
