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
FRESH_LATENCY_LOCK_DIR="${AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-fresh-latency.lock}"
FRESH_LATENCY_LOCK_WAIT_SECONDS="${AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS:-300}"
FRESH_LATENCY_LOCK_HELD=0

usage() {
  cat <<'EOF'
Usage: script/fresh_latency_proof.sh [--runs N] [--target textedit|textedit-model-latency]

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

if ! [[ "$FRESH_LATENCY_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_WAIT_SECONDS must be a non-negative integer." >&2
  exit 2
fi

cleanup_fresh_latency_lock() {
  if [[ "$FRESH_LATENCY_LOCK_HELD" == "1" ]]; then
    rm -rf "$FRESH_LATENCY_LOCK_DIR" >/dev/null 2>&1 || true
    FRESH_LATENCY_LOCK_HELD=0
  fi
}

trap cleanup_fresh_latency_lock EXIT

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

acquire_fresh_latency_lock() {
  local deadline=$((SECONDS + FRESH_LATENCY_LOCK_WAIT_SECONDS))
  local announced=0

  while true; do
    if mkdir "$FRESH_LATENCY_LOCK_DIR" >/dev/null 2>&1; then
      FRESH_LATENCY_LOCK_HELD=1
      printf '%s\n' "$$" >"$FRESH_LATENCY_LOCK_DIR/pid"
      return 0
    fi

    local existing_pid=""
    if [[ -f "$FRESH_LATENCY_LOCK_DIR/pid" ]]; then
      existing_pid="$(cat "$FRESH_LATENCY_LOCK_DIR/pid" 2>/dev/null || true)"
    fi

    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
      if ((SECONDS >= deadline)); then
        echo "Another fresh latency proof is already active (pid $existing_pid)." >&2
        echo "Timed out waiting for the fresh latency lock: $FRESH_LATENCY_LOCK_DIR" >&2
        exit 1
      fi
      if [[ "$announced" == "0" ]]; then
        echo "Waiting for active fresh latency proof to finish (pid $existing_pid)." >&2
        announced=1
      fi
      sleep 2
      continue
    fi

    rm -rf "$FRESH_LATENCY_LOCK_DIR" >/dev/null 2>&1 || true
  done
}

other_proof_process_lines() {
  local process_list current_pgid
  current_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ' || true)"
  if [[ "${AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST+x}" == "x" ]]; then
    process_list="$AUTOCOMPLETE_LAB_FRESH_LATENCY_PROCESS_LIST"
  else
    process_list="$(ps -axo pid=,ppid=,pgid=,command= 2>/dev/null || true)"
  fi

  awk -v self="$$" -v selfPGID="$current_pgid" '
    {
      pid = $1
      pgid = $3
      command = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", command)
    }
    pid != self &&
      (selfPGID == "" || pgid != selfPGID) &&
      command ~ /^((\/[^[:space:]]+\/)?(env[[:space:]]+)?bash|\/usr\/bin\/env[[:space:]]+bash)[[:space:]]+(\.\/)?script\/(real_app_smoke|fresh_latency_proof)\.sh([[:space:]]|$)/ {
        print
      }
  ' <<<"$process_list"
}

wait_for_quiet_proof_processes() {
  local deadline=$((SECONDS + FRESH_LATENCY_LOCK_WAIT_SECONDS))
  local announced=0
  local processes

  while true; do
    processes="$(other_proof_process_lines || true)"
    if [[ -z "$processes" ]]; then
      return 0
    fi

    if ((SECONDS >= deadline)); then
      echo "Another proof process is already active." >&2
      echo "Timed out before selecting the fresh latency log window." >&2
      echo "$processes" >&2
      exit 1
    fi

    if [[ "$announced" == "0" ]]; then
      echo "Waiting for active proof process to finish before selecting the latency window." >&2
      echo "$processes" >&2
      announced=1
    fi
    sleep 2
  done
}

acquire_fresh_latency_lock
wait_for_quiet_proof_processes

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
