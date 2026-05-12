#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUNS="${AUTOCOMPLETE_LAB_FRESH_LATENCY_RUNS:-3}"
TARGET_APP="${AUTOCOMPLETE_LAB_FRESH_LATENCY_TARGET:-textedit}"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}"
REAL_APP_SMOKE_SCRIPT="${AUTOCOMPLETE_LAB_FRESH_LATENCY_REAL_APP_SMOKE_SCRIPT:-./script/real_app_smoke.sh}"
LATENCY_REPORT_SCRIPT="${AUTOCOMPLETE_LAB_FRESH_LATENCY_REPORT_SCRIPT:-./script/latency_benchmark_report.py}"

usage() {
  cat <<'EOF'
Usage: script/fresh_latency_proof.sh [--runs N] [--target textedit]

Runs a fresh bounded latency proof: one current-app smoke launch, repeated
TextEdit smoke passes with rebuilds skipped, then latency_benchmark_report.py
against only the new diagnostics and trace lines.

This helper is for making beta latency proof repeatable. It does not fall back
to older sampled launches.
EOF
}

while (($#)); do
  case "$1" in
    --runs)
      if (($# < 2)); then
        echo "--runs needs a value" >&2
        exit 2
      fi
      RUNS="$2"
      shift 2
      ;;
    --runs=*)
      RUNS="${1#--runs=}"
      shift
      ;;
    --target)
      if (($# < 2)); then
        echo "--target needs a value" >&2
        exit 2
      fi
      TARGET_APP="$2"
      shift 2
      ;;
    --target=*)
      TARGET_APP="${1#--target=}"
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || ((RUNS < 1)); then
  echo "--runs must be a positive integer" >&2
  exit 2
fi

line_count() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo 0
    return
  fi
  wc -l <"$path" | tr -d ' '
}

run_smoke() {
  local index="$1"
  local args=("$TARGET_APP")

  if ((index > 1)); then
    args+=(--skip-build)
    AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 "$REAL_APP_SMOKE_SCRIPT" "${args[@]}"
    return
  fi

  "$REAL_APP_SMOKE_SCRIPT" "${args[@]}"
}

diagnostics_start_line="$(line_count "$LOG_PATH")"
trace_start_line="$(line_count "$TRACE_PATH")"

echo "Fresh latency proof start:"
echo "- diagnostics: $LOG_PATH line $diagnostics_start_line"
echo "- trace: $TRACE_PATH line $trace_start_line"
echo "- target: $TARGET_APP"
echo "- runs: $RUNS"

for ((index = 1; index <= RUNS; index++)); do
  echo
  echo "== Fresh latency smoke $index/$RUNS =="
  run_smoke "$index"
done

diagnostics_end_line="$(line_count "$LOG_PATH")"
trace_end_line="$(line_count "$TRACE_PATH")"

echo
echo "Fresh latency proof window:"
echo "AUTOCOMPLETE_LAB_LOG_START_LINE=$diagnostics_start_line"
echo "AUTOCOMPLETE_LAB_LOG_END_LINE=$diagnostics_end_line"
echo "AUTOCOMPLETE_LAB_TRACE_START_LINE=$trace_start_line"
echo "AUTOCOMPLETE_LAB_TRACE_END_LINE=$trace_end_line"

env \
  AUTOCOMPLETE_LAB_LOG_START_LINE="$diagnostics_start_line" \
  AUTOCOMPLETE_LAB_LOG_END_LINE="$diagnostics_end_line" \
  AUTOCOMPLETE_LAB_TRACE_START_LINE="$trace_start_line" \
  AUTOCOMPLETE_LAB_TRACE_END_LINE="$trace_end_line" \
  "$LATENCY_REPORT_SCRIPT" \
    --diagnostics-log "$LOG_PATH" \
    --trace-log "$TRACE_PATH" \
    --beta-gate
