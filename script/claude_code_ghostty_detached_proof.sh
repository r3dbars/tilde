#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROOF_ROOT="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR:-$ROOT_DIR/dist/claude-code-ghostty-detached-proof}"
LATEST_FILE="$PROOF_ROOT/latest-run.txt"
MODE="${1:-status}"
DRY_RUN=0
FORCE_START=0
FORCE_STOP=0
RUN_DIR=""
TAIL_LINES=80
WAIT_POLL_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_POLL_SECONDS:-2}"
WAIT_TIMEOUT_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_TIMEOUT_SECONDS:-900}"
WAIT_PROGRESS_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_PROGRESS_SECONDS:-30}"
STARTUP_GRACE_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STARTUP_GRACE_SECONDS:-45}"
STOP_FORCE_GRACE_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STOP_FORCE_GRACE_SECONDS:-120}"
LAUNCHER="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER:-launchd}"
GHOSTTY_DETACHED_PASSTHROUGH_ENV_KEYS=(
  AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS
  AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION
  AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES
  AUTOCOMPLETE_LAB_CGEVENT_KEYPRESS_HELPER
  AUTOCOMPLETE_LAB_CGEVENT_KEYPRESS_HELPER_BUILD_TIMEOUT_SECONDS
  AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS
  AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE
  AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE
  AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES
  AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS
  AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE
  AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE
  AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_DRAIN_SECONDS
  AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE
  AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_VERIFY_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_SCHEDULE_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_TEXT
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_VERIFY_SECONDS
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED
  AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED
  AUTOCOMPLETE_LAB_SCREENSHOT_TRACE
)

: "${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS:=0.12}"
: "${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS:=45}"
: "${AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE:=0}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION:=hid}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:=0}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES:=2}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED:=0}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE:=0}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED:=1}"
: "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED:=1}"
: "${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:=1}"

usage() {
  cat <<'EOF'
Usage: script/claude_code_ghostty_detached_proof.sh <start|status|wait|tail|stop> [options]

Runs the Claude Code Ghostty one-word no-submit proof outside the Codex
foreground shell. This is for the current focus-steal gap: the proof launches a
short-lived LaunchAgent by default, writes one log/status directory under dist/,
and returns right away so the disposable Ghostty window can keep focus during
Tab accept.

Modes:
  start   Launch a detached Ghostty proof run.
  status  Print status for the latest run, or --run-dir <dir>.
  wait    Poll status until the detached run exits.
  tail    Print the last log lines for the latest run, or --run-dir <dir>.
  stop    Terminate the latest active detached proof run.

Options:
  --run-dir <dir>  Use a specific run directory for status/wait/tail.
  --lines <n>      Log lines for tail/status. Default: 80.
  --dry-run        Show what start would launch without starting a process.
  --force          Stop active same-launcher proof runs before starting.
  --force-stop     Stop an active proof even during the early evidence window.

Set AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER=terminal or nohup to use the
older launch modes. The wrapper uses the same disposable defaults as
script/real_app_smoke.sh. It does not persist custom proof text into the
generated runner, LaunchAgent plist, or status file.
Set AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_ALLOW_CROSS_LAUNCHER_FORCE=1 only when
you intentionally want one launcher family to stop another active proof run.
EOF
}

shift || true
while (($#)); do
  case "$1" in
    --run-dir)
      if (($# < 2)); then
        echo "--run-dir requires a directory" >&2
        exit 2
      fi
      RUN_DIR="$2"
      shift 2
      ;;
    --run-dir=*)
      RUN_DIR="${1#--run-dir=}"
      shift
      ;;
    --lines)
      if (($# < 2)); then
        echo "--lines requires a number" >&2
        exit 2
      fi
      TAIL_LINES="$2"
      shift 2
      ;;
    --lines=*)
      TAIL_LINES="${1#--lines=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE_START=1
      shift
      ;;
    --force-stop)
      FORCE_STOP=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown detached Ghostty proof option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  start|status|wait|tail|stop|-h|--help|help)
    ;;
  *)
    echo "unknown detached Ghostty proof mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "$MODE" == "-h" || "$MODE" == "--help" || "$MODE" == "help" ]]; then
  usage
  exit 0
fi

if ! [[ "$TAIL_LINES" =~ ^[0-9]+$ ]] || ((TAIL_LINES < 1)); then
  echo "--lines must be a positive integer" >&2
  exit 2
fi

if ! [[ "$WAIT_POLL_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_POLL_SECONDS must be a non-negative number." >&2
  exit 2
fi

if ! [[ "$WAIT_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || ((WAIT_TIMEOUT_SECONDS < 1)); then
  echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 2
fi

if ! [[ "$WAIT_PROGRESS_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_PROGRESS_SECONDS must be a non-negative integer." >&2
  exit 2
fi

if ! [[ "$STARTUP_GRACE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STARTUP_GRACE_SECONDS must be a non-negative integer." >&2
  exit 2
fi

if ! [[ "$STOP_FORCE_GRACE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STOP_FORCE_GRACE_SECONDS must be a non-negative integer." >&2
  exit 2
fi

case "$LAUNCHER" in
  terminal|launchd|nohup)
    ;;
  *)
    echo "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER must be terminal, launchd, or nohup." >&2
    exit 2
    ;;
esac

latest_run_dir() {
  if [[ -n "$RUN_DIR" ]]; then
    printf '%s\n' "$RUN_DIR"
    return 0
  fi
  if [[ -f "$LATEST_FILE" ]]; then
    head -n 1 "$LATEST_FILE"
    return 0
  fi
  return 1
}

status_file_for_run() {
  printf '%s/status.env\n' "$1"
}

all_run_dirs() {
  [[ -d "$PROOF_ROOT" ]] || return 0
  find "$PROOF_ROOT" -mindepth 2 -maxdepth 2 -name status.env -type f -print 2>/dev/null |
    sed 's#/status\.env$##' |
    sort
}

log_file_for_run() {
  printf '%s/proof.log\n' "$1"
}

smoke_pid_file_for_run() {
  printf '%s/smoke.pid\n' "$1"
}

detached_smoke_command_summary() {
  local key value
  for key in "${GHOSTTY_DETACHED_PASSTHROUGH_ENV_KEYS[@]}"; do
    if [[ -n "${!key+x}" ]]; then
      value="${!key}"
      printf '%s=%q ' "$key" "$value"
    fi
  done
  printf '%s' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
}

write_passthrough_env_exports() {
  local key value
  for key in "${GHOSTTY_DETACHED_PASSTHROUGH_ENV_KEYS[@]}"; do
    if [[ -n "${!key+x}" ]]; then
      value="${!key}"
      printf 'export %s=%q\n' "$key" "$value"
    fi
  done
}

status_value() {
  local file="$1"
  local key="$2"
  awk -F= -v wanted="$key" '$1 == wanted { value = substr($0, length($1) + 2) } END { if (value != "") print value }' "$file" 2>/dev/null || true
}

process_is_alive() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

process_group_for_pid() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  ps -p "$pid" -o pgid= 2>/dev/null | tr -d '[:space:]'
}

signal_process_or_group() {
  local pid="$1"
  local signal="${2:-TERM}"
  local pgid current_pgid

  [[ -n "$pid" ]] || return 1
  current_pgid="$(process_group_for_pid "$$" || true)"
  pgid="$(process_group_for_pid "$pid" || true)"
  if [[ -n "$pgid" && "$pgid" != "$current_pgid" ]]; then
    kill "-$signal" "-$pgid" >/dev/null 2>&1 || true
  else
    kill "-$signal" "$pid" >/dev/null 2>&1 || true
  fi
}

smoke_pid_for_run() {
  local run_dir="$1"
  local status_file smoke_pid smoke_pid_file
  status_file="$(status_file_for_run "$run_dir")"
  smoke_pid="$(status_value "$status_file" smoke_pid)"
  smoke_pid_file="$(smoke_pid_file_for_run "$run_dir")"
  if [[ -z "$smoke_pid" && -f "$smoke_pid_file" ]]; then
    smoke_pid="$(head -n 1 "$smoke_pid_file" | tr -dc '0-9')"
  fi
  printf '%s\n' "$smoke_pid"
}

proof_artifact_dir_for_run() {
  local run_dir="$1"
  local status_file proof_artifact_dir
  status_file="$(status_file_for_run "$run_dir")"
  proof_artifact_dir="$(status_value "$status_file" proof_artifact_dir)"
  [[ -n "$proof_artifact_dir" ]] || proof_artifact_dir="$run_dir/proof-artifacts"
  printf '%s\n' "$proof_artifact_dir"
}

detached_proof_context_pids_for_run() {
  local run_dir="$1"
  local log_file proof_artifact_dir
  log_file="$(log_file_for_run "$run_dir")"
  proof_artifact_dir="$(proof_artifact_dir_for_run "$run_dir")"

  if [[ -d "$proof_artifact_dir" ]]; then
    find "$proof_artifact_dir" -name claude.pid -type f -print 2>/dev/null |
      while IFS= read -r pid_file; do
        tr -dc '0-9\n' <"$pid_file" 2>/dev/null || true
      done
  fi

  if [[ -f "$log_file" ]]; then
    awk '
      /owns no-restore host pid\(s\):/ {
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[0-9]+$/) print $i
        }
      }
      /^root_pid=[0-9]+$/ {
        sub(/^root_pid=/, "")
        print
      }
    ' "$log_file" 2>/dev/null || true
  fi
}

terminate_detached_proof_context_processes() {
  local run_dir="$1"
  local log_file pid deadline stopped_any=0
  log_file="$(log_file_for_run "$run_dir")"

  while IFS= read -r pid; do
    [[ -n "$pid" && "$pid" != "$$" ]] || continue
    process_is_alive "$pid" || continue
    stopped_any=1
    signal_process_or_group "$pid" TERM
    deadline=$((SECONDS + 5))
    while process_is_alive "$pid" && ((SECONDS <= deadline)); do
      sleep 0.2
    done
    if process_is_alive "$pid"; then
      signal_process_or_group "$pid" KILL
      sleep 0.5
    fi
    printf 'Stopped detached Ghostty proof context pid=%s after wrapper stop.\n' "$pid" >>"$log_file"
  done < <(detached_proof_context_pids_for_run "$run_dir" | awk 'NF && !seen[$1]++')

  ((stopped_any == 1))
}

terminate_orphaned_detached_smoke_processes() {
  local run_dir="$1"
  local log_file smoke_pid pid args deadline
  log_file="$(log_file_for_run "$run_dir")"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  if [[ -n "$smoke_pid" ]]; then
    if process_is_alive "$smoke_pid"; then
      signal_process_or_group "$smoke_pid" TERM
      deadline=$((SECONDS + 5))
      while process_is_alive "$smoke_pid" && ((SECONDS <= deadline)); do
        sleep 0.2
      done
      if process_is_alive "$smoke_pid"; then
        signal_process_or_group "$smoke_pid" KILL
        sleep 0.5
      fi
      printf 'Stopped orphaned detached Ghostty smoke process pid=%s after runner exit.\n' "$smoke_pid" >>"$log_file"
    fi
    return 0
  fi
  while IFS= read -r pid; do
    [[ -z "$pid" || "$pid" == "$$" ]] && continue
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    [[ "$args" == *"script/real_app_smoke.sh claude-code-ghostty --manual-gate"* ]] || continue
    signal_process_or_group "$pid" TERM
    deadline=$((SECONDS + 5))
    while process_is_alive "$pid" && ((SECONDS <= deadline)); do
      sleep 0.2
    done
    if process_is_alive "$pid"; then
      signal_process_or_group "$pid" KILL
      sleep 0.5
    fi
    printf 'Stopped orphaned detached Ghostty smoke process pid=%s after runner exit.\n' "$pid" >>"$log_file"
  done < <(pgrep -f "script/real_app_smoke.sh claude-code-ghostty --manual-gate" 2>/dev/null || true)
}

file_mtime_seconds() {
  local path="$1"
  stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null
}

status_file_age_seconds() {
  local status_file="$1"
  local mtime now
  mtime="$(file_mtime_seconds "$status_file" || true)"
  [[ -n "$mtime" ]] || return 1
  now="$(date +%s)"
  printf '%s\n' "$((now - mtime))"
}

status_started_age_seconds() {
  local status_file="$1"
  local started_at started_epoch now
  started_at="$(status_value "$status_file" started_at)"
  [[ -n "$started_at" ]] || return 1
  started_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$started_at" '+%s' 2>/dev/null || true)"
  [[ -n "$started_epoch" ]] || return 1
  now="$(date +%s)"
  printf '%s\n' "$((now - started_epoch))"
}

starting_status_is_within_grace() {
  local status_file="$1"
  local age
  age="$(status_file_age_seconds "$status_file" || true)"
  [[ -n "$age" ]] && ((age < STARTUP_GRACE_SECONDS))
}

stop_requires_force_guard() {
  local status_file="$1"
  local state="$2"
  local pid="$3"
  local smoke_pid="$4"
  local age

  [[ "$FORCE_STOP" != "1" ]] || return 1
  ((STOP_FORCE_GRACE_SECONDS > 0)) || return 1
  [[ "$state" == "starting" || "$state" == "running" ]] || return 1
  { process_is_alive "$pid" || process_is_alive "$smoke_pid"; } || return 1
  age="$(status_started_age_seconds "$status_file" || true)"
  [[ -n "$age" ]] || age="$(status_file_age_seconds "$status_file" || true)"
  [[ -n "$age" ]] && ((age < STOP_FORCE_GRACE_SECONDS))
}

run_is_active() {
  local run_dir="$1"
  local status_file state pid smoke_pid
  status_file="$(status_file_for_run "$run_dir")"
  [[ -f "$status_file" ]] || return 1
  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  if [[ "$state" == "starting" ]] &&
     ! process_is_alive "$pid" &&
     ! process_is_alive "$smoke_pid" &&
     starting_status_is_within_grace "$status_file"; then
    return 0
  fi
  [[ "$state" == "starting" || "$state" == "running" ]] &&
    { process_is_alive "$pid" || process_is_alive "$smoke_pid"; }
}

active_run_dirs() {
  local run_dir
  while IFS= read -r run_dir; do
    [[ -n "$run_dir" ]] || continue
    if run_is_active "$run_dir"; then
      printf '%s\n' "$run_dir"
    fi
  done < <(all_run_dirs)
}

print_run_status() {
  local run_dir="$1"
  local status_file log_file pid smoke_pid state
  status_file="$(status_file_for_run "$run_dir")"
  log_file="$(log_file_for_run "$run_dir")"

  if [[ ! -f "$status_file" ]]; then
    echo "No detached Ghostty proof status file found: $status_file" >&2
    return 1
  fi

  repair_dead_runner_status_if_needed "$run_dir"
  cat "$status_file"
  pid="$(status_value "$status_file" pid)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  state="$(status_value "$status_file" state)"
  if [[ "$state" == "starting" ]] &&
     ! process_is_alive "$pid" &&
     ! process_is_alive "$smoke_pid" &&
     starting_status_is_within_grace "$status_file"; then
    echo "runner_process=pending"
  elif process_is_alive "$pid"; then
    echo "runner_process=alive"
  else
    echo "runner_process=not-running"
    if [[ "$state" == "starting" || "$state" == "running" ]]; then
      echo "warning=runner exited before writing a final status"
    fi
  fi
  if [[ -n "$smoke_pid" ]]; then
    if process_is_alive "$smoke_pid"; then
      echo "smoke_process=alive"
    else
      echo "smoke_process=not-running"
    fi
  fi
  echo "status_file=$status_file"
  echo "log_file=$log_file"
}

print_log_tail() {
  local run_dir="$1"
  local log_file
  log_file="$(log_file_for_run "$run_dir")"
  if [[ ! -f "$log_file" ]]; then
    echo "No detached Ghostty proof log found: $log_file" >&2
    return 1
  fi
  tail -n "$TAIL_LINES" "$log_file"
}

latest_progress_line_for_run() {
  local run_dir="$1"
  local log_file
  log_file="$(log_file_for_run "$run_dir")"
  [[ -f "$log_file" ]] || return 0
  awk '
    NF && /^(Claude Code|Real app smoke|Build|App bundle|Detached Ghostty|Temporary|Plan:|Safety:)/ {
      line = $0
    }
    END {
      if (line != "") print line
    }
  ' "$log_file" 2>/dev/null || true
}

print_wait_progress() {
  local run_dir="$1"
  local elapsed_seconds="$2"
  local status_file state pid smoke_pid phase
  status_file="$(status_file_for_run "$run_dir")"
  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  phase="$(latest_progress_line_for_run "$run_dir")"
  printf 'Detached Ghostty proof still %s after %ss' "${state:-unknown}" "$elapsed_seconds"
  if [[ -n "$pid" ]]; then
    printf ' pid=%s' "$pid"
  fi
  if [[ -n "$smoke_pid" ]]; then
    printf ' smoke_pid=%s' "$smoke_pid"
  fi
  if [[ -n "$phase" ]]; then
    printf ' phase=%s' "$phase"
  fi
  printf '\n'
}

create_runner_script() {
  local runner_script="$1"
  local run_dir="$2"
  local status_file="$3"
  local log_file="$4"
  local launcher="$5"
  local launch_label="$6"
  local plist_file="$7"
  local runner_path="${PATH:-/Users/redbars/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
  local runner_home="${HOME:-/Users/redbars}"
  local smoke_command_summary
  smoke_command_summary="$(detached_smoke_command_summary)"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -u\n\n'
    printf "trap '' HUP\n"
    printf 'export PATH=%q\n' "$runner_path"
    printf 'export HOME=%q\n' "$runner_home"
    write_passthrough_env_exports
    printf 'ROOT_DIR=%q\n' "$ROOT_DIR"
    printf 'RUN_DIR=%q\n' "$run_dir"
    printf 'STATUS_FILE=%q\n' "$status_file"
    printf 'LOG_FILE=%q\n' "$log_file"
    printf 'SMOKE_PID_FILE=%q\n' "$run_dir/smoke.pid"
    printf 'SMOKE_STARTUP_MARKER_FILE=%q\n' "$run_dir/smoke-startup.log"
    printf 'LAUNCHER=%q\n' "$launcher"
    printf 'LAUNCH_LABEL=%q\n' "$launch_label"
    printf 'PLIST_FILE=%q\n' "$plist_file"
    printf 'SMOKE_COMMAND_SUMMARY=%q\n' "$smoke_command_summary"
cat <<'EOF'
RUNNER_PID="$$"
STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
FINAL_STATUS_WRITTEN=0
SMOKE_PID=""
STATUS_PID="$RUNNER_PID"
PROOF_ARTIFACT_DIR="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR:-$RUN_DIR/proof-artifacts}"

write_status() {
  local state="$1"
  local exit_status="${2:-}"
  local finished_at="${3:-}"
  local status_pid="${STATUS_PID:-$RUNNER_PID}"
  {
    printf 'state=%s\n' "$state"
    printf 'pid=%s\n' "$status_pid"
    printf 'started_at=%s\n' "$STARTED_AT"
    if [[ -n "$finished_at" ]]; then
      printf 'finished_at=%s\n' "$finished_at"
    fi
    if [[ -n "$exit_status" ]]; then
      printf 'exit_status=%s\n' "$exit_status"
    fi
    if [[ -n "${SMOKE_PID:-}" ]]; then
      printf 'smoke_pid=%s\n' "$SMOKE_PID"
    elif [[ -f "$SMOKE_PID_FILE" ]]; then
      printf 'smoke_pid=%s\n' "$(head -n 1 "$SMOKE_PID_FILE" | tr -dc '0-9')"
    fi
    printf 'startup_log=%s\n' "$SMOKE_STARTUP_MARKER_FILE"
    printf 'proof_artifact_dir=%s\n' "$PROOF_ARTIFACT_DIR"
    printf 'run_dir=%s\n' "$RUN_DIR"
    printf 'launcher=%s\n' "$LAUNCHER"
    if [[ -n "$LAUNCH_LABEL" ]]; then
      printf 'launch_label=%s\n' "$LAUNCH_LABEL"
    fi
    if [[ -n "$PLIST_FILE" ]]; then
      printf 'plist_file=%s\n' "$PLIST_FILE"
    fi
    printf 'command=%s\n' "$SMOKE_COMMAND_SUMMARY"
    printf 'note=%s\n' 'Detached wrapper stores status and child output only; custom proof text is not persisted here.'
  } >"$STATUS_FILE"
}

handle_exit() {
  local exit_status="$?"
  local finished_at
  if [[ "${FINAL_STATUS_WRITTEN:-0}" == "1" ]]; then
    return "$exit_status"
  fi
  finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  write_status failed "$exit_status" "$finished_at"
  printf '\nDetached Ghostty proof exited before explicit final status at %s with exit status %s\n' "$finished_at" "$exit_status" >>"$LOG_FILE"
  return "$exit_status"
}

handle_signal() {
  local signal_name="$1"
  local exit_status="$2"
  local finished_at
  local smoke_pgid runner_pgid
  finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [[ -n "${SMOKE_PID:-}" ]]; then
    smoke_pgid="$(ps -o pgid= -p "$SMOKE_PID" 2>/dev/null | tr -d '[:space:]' || true)"
    runner_pgid="$(ps -o pgid= -p "$RUNNER_PID" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$smoke_pgid" && "$smoke_pgid" != "$runner_pgid" ]]; then
      kill -TERM "-$smoke_pgid" >/dev/null 2>&1 || true
    else
      kill -TERM "$SMOKE_PID" >/dev/null 2>&1 || true
    fi
  fi
  write_status failed "$exit_status" "$finished_at"
  FINAL_STATUS_WRITTEN=1
  printf '\nDetached Ghostty proof interrupted by %s at %s\n' "$signal_name" "$finished_at" >>"$LOG_FILE"
  exit "$exit_status"
}

trap handle_exit EXIT
trap 'handle_signal TERM 143' TERM
trap 'handle_signal INT 130' INT

cd "$ROOT_DIR" || exit 1
write_status running

{
  printf 'Detached Ghostty proof started at %s\n' "$STARTED_AT"
  printf 'Run directory: %s\n' "$RUN_DIR"
  printf 'Root: %s\n' "$ROOT_DIR"
  printf 'Command: %s\n' "$SMOKE_COMMAND_SUMMARY"
  printf '\n'
} >>"$LOG_FILE"

runner_pgid="$(ps -o pgid= -p "$RUNNER_PID" 2>/dev/null | tr -d '[:space:]' || true)"
protected_pgids="${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_PROTECTED_PGIDS:-}"
if [[ -n "$runner_pgid" ]]; then
  if [[ " $protected_pgids " == *" $runner_pgid "* ]]; then
    :
  elif [[ -n "$protected_pgids" ]]; then
    protected_pgids="$protected_pgids,$runner_pgid"
  else
    protected_pgids="$runner_pgid"
  fi
  printf 'Protected proof process groups: %s\n\n' "$protected_pgids" >>"$LOG_FILE"
fi

run_real_app_smoke() {
  local proof_pgids="${1:-}"
  exec env \
    "AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-1}" \
    "AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_PROTECTED_PGIDS=$proof_pgids" \
    "AUTOCOMPLETE_LAB_REAL_APP_SMOKE_STARTUP_MARKER_PATH=$SMOKE_STARTUP_MARKER_FILE" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR=$PROOF_ARTIFACT_DIR" \
    "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-1}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS:-4}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS=${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS:-20}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS=${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS:-2}" \
    "AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=${AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION:-hid}" \
    "AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=${AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS:-${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS:-0.12}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE:-1}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE:-0}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS=${AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS:-45}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE:-1}" \
    "AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE:-1}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED:-0}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE:-1}" \
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE:-1}" \
    ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
}

set +e
printf 'Detached Ghostty proof launching real_app_smoke as direct child process at %s\n' \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"$LOG_FILE"
run_real_app_smoke "${protected_pgids:-}" >>"$LOG_FILE" 2>&1 &
SMOKE_PID="$!"
STATUS_PID="$SMOKE_PID"
printf '%s\n' "$SMOKE_PID" >"$SMOKE_PID_FILE"
printf 'Detached Ghostty proof spawned smoke pid %s protected_pgids=%s\n' "$SMOKE_PID" "${protected_pgids:-}" >>"$LOG_FILE"
write_status running
wait "$SMOKE_PID"
status=$?
set -e

finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '\nDetached Ghostty proof smoke pid %s returned status %s at %s\n' "$SMOKE_PID" "$status" "$finished_at" >>"$LOG_FILE"
if ((status == 0)); then
  write_status passed "$status" "$finished_at"
else
  write_status failed "$status" "$finished_at"
fi
FINAL_STATUS_WRITTEN=1
printf '\nDetached Ghostty proof finished at %s with exit status %s\n' "$finished_at" "$status" >>"$LOG_FILE"
exit "$status"
EOF
  } >"$runner_script"
  chmod +x "$runner_script"
}

create_terminal_launcher_script() {
  local launcher_script="$1"
  local worker_script="$2"
  local log_file="$3"
  local runner_path="${PATH:-/Users/redbars/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
  local runner_home="${HOME:-/Users/redbars}"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -u\n\n'
    printf 'export PATH=%q\n' "$runner_path"
    printf 'export HOME=%q\n' "$runner_home"
    printf 'LOG_FILE=%q\n' "$log_file"
    printf 'WORKER_SCRIPT=%q\n' "$worker_script"
    cat <<'EOF'
{
  printf 'Terminal starter launched detached Ghostty worker at %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Worker: %s\n' "$WORKER_SCRIPT"
} >>"$LOG_FILE"
nohup /bin/bash "$WORKER_SCRIPT" >>"$LOG_FILE" 2>&1 &
worker_pid=$!
printf 'Terminal starter detached worker pid %s\n' "$worker_pid" >>"$LOG_FILE"
exit 0
EOF
  } >"$launcher_script"
  chmod +x "$launcher_script"
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s\n' "$value"
}

create_launch_agent_plist() {
  local plist_file="$1"
  local launch_label="$2"
  local runner_script="$3"
  local log_file="$4"
  local launch_path="${PATH:-/Users/redbars/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
  local launch_home="${HOME:-/Users/redbars}"
  cat >"$plist_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$(xml_escape "$launch_label")</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>$(xml_escape "$launch_home")</string>
    <key>PATH</key>
    <string>$(xml_escape "$launch_path")</string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$runner_script")</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$(xml_escape "$log_file")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "$log_file")</string>
</dict>
</plist>
EOF
}

start_nohup_runner() {
  local runner_script="$1"
  local log_file="$2"

  /usr/bin/python3 - "$runner_script" "$log_file" <<'PY'
import os
import subprocess
import sys

runner_script = sys.argv[1]
log_file = sys.argv[2]
with open(log_file, "ab", buffering=0) as log:
    process = subprocess.Popen(
        ["/bin/bash", runner_script],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        close_fds=True,
        env=os.environ.copy(),
        start_new_session=True,
    )
print(process.pid)
PY
}

cleanup_launchd_job_if_terminal() {
  local run_dir="$1"
  local status_file launcher launch_label
  status_file="$(status_file_for_run "$run_dir")"
  launcher="$(status_value "$status_file" launcher)"
  launch_label="$(status_value "$status_file" launch_label)"
  if [[ "$launcher" == "launchd" && -n "$launch_label" ]]; then
    launchctl bootout "gui/$(id -u)/$launch_label" >/dev/null 2>&1 || true
  fi
}

write_parent_final_status() {
  local run_dir="$1"
  local state="$2"
  local exit_status="$3"
  local note="$4"
  local status_file pid started_at launcher launch_label plist_file smoke_pid startup_log proof_artifact_dir
  local smoke_command_summary
  status_file="$(status_file_for_run "$run_dir")"
  pid="$(status_value "$status_file" pid)"
  started_at="$(status_value "$status_file" started_at)"
  launcher="$(status_value "$status_file" launcher)"
  launch_label="$(status_value "$status_file" launch_label)"
  plist_file="$(status_value "$status_file" plist_file)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  startup_log="$(status_value "$status_file" startup_log)"
  [[ -n "$startup_log" ]] || startup_log="$run_dir/smoke-startup.log"
  proof_artifact_dir="$(status_value "$status_file" proof_artifact_dir)"
  [[ -n "$proof_artifact_dir" ]] || proof_artifact_dir="$run_dir/proof-artifacts"
  smoke_command_summary="$(status_value "$status_file" command)"
  [[ -n "$smoke_command_summary" ]] || smoke_command_summary="$(detached_smoke_command_summary)"
  [[ -n "$started_at" ]] || started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  {
    printf 'state=%s\n' "$state"
    printf 'pid=%s\n' "$pid"
    printf 'started_at=%s\n' "$started_at"
    printf 'finished_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'exit_status=%s\n' "$exit_status"
    if [[ -n "$smoke_pid" ]]; then
      printf 'smoke_pid=%s\n' "$smoke_pid"
    fi
    printf 'startup_log=%s\n' "$startup_log"
    printf 'proof_artifact_dir=%s\n' "$proof_artifact_dir"
    printf 'run_dir=%s\n' "$run_dir"
    if [[ -n "$launcher" ]]; then
      printf 'launcher=%s\n' "$launcher"
    fi
    if [[ -n "$launch_label" ]]; then
      printf 'launch_label=%s\n' "$launch_label"
    fi
    if [[ -n "$plist_file" ]]; then
      printf 'plist_file=%s\n' "$plist_file"
    fi
    printf 'command=%s\n' "$smoke_command_summary"
    printf 'note=%s\n' "$note"
  } >"$status_file"
}

repair_dead_runner_status_if_needed() {
  local run_dir="$1"
  local status_file state pid smoke_pid age
  status_file="$(status_file_for_run "$run_dir")"
  [[ -f "$status_file" ]] || return 0
  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  if [[ "$state" == "starting" && -z "$pid" ]]; then
    age="$(status_file_age_seconds "$status_file" || true)"
    if [[ -n "$age" ]] && ((age >= STARTUP_GRACE_SECONDS)); then
      write_parent_final_status "$run_dir" failed 1 "Detached proof runner did not start before startup grace expired."
    fi
    return 0
  fi
  if [[ "$state" == "starting" ]] &&
     [[ -n "$pid" ]] &&
     ! process_is_alive "$pid" &&
     ! process_is_alive "$smoke_pid"; then
    if starting_status_is_within_grace "$status_file"; then
      return 0
    fi
    write_parent_final_status "$run_dir" failed 1 "Detached proof runner and smoke child exited before writing a final status."
    return 0
  fi
  if [[ "$state" == "starting" || "$state" == "running" ]] &&
     [[ -n "$pid" ]] &&
     ! process_is_alive "$pid"; then
    if process_is_alive "$smoke_pid"; then
      return 0
    fi
    write_parent_final_status "$run_dir" failed 1 "Detached proof runner and smoke child exited before writing a final status."
  fi
}

reset_stale_only_ghostty_host_before_start() {
  local log_file="$1"
  local marker ghostty_pids timeout_seconds ax_tmp ax_pid deadline ax_state ax_window_count unsafe_window_count proof_pid reset_reason

  if [[ ! "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED:-0}" =~ ^(1|true|yes|on)$ ]]; then
    return 0
  fi
  ghostty_pids="$(pgrep -x ghostty 2>/dev/null || true)"
  [[ -n "$ghostty_pids" ]] || return 0

  marker="${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER:-STEADYTYPECLAUDECODEPROOF}"
  timeout_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_CHECK_TIMEOUT_SECONDS:-3}"
  if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || ((timeout_seconds < 1)); then
    timeout_seconds=3
  fi
  ax_tmp="$(mktemp "${TMPDIR:-/tmp}/steadytype-ghostty-ax-reset.XXXXXX")"
  AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER="$marker" /usr/bin/osascript >"$ax_tmp" 2>/dev/null <<'APPLESCRIPT' &
set markerText to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER"
set proofDirectoryMarker to "steadytype-claude-code-proof"
set appleScriptProbePrefix to "SteadyType AppleScript Probe"
set submitProbePrefix to "SteadyType Submit Probe"
set windowCount to 0
set unsafeWindowCount to 0
tell application "System Events"
  if not (exists application process "Ghostty") then return "windows=0 unsafe=0"
  tell application process "Ghostty"
    set windowCount to count windows
    repeat with candidateWindow in windows
      set windowName to ""
      try
        set windowName to name of candidateWindow as text
      end try
      set isProofWindow to false
      if markerText is not "" and windowName contains markerText then set isProofWindow to true
      if windowName contains proofDirectoryMarker then set isProofWindow to true
      if windowName starts with appleScriptProbePrefix then set isProofWindow to true
      if windowName starts with submitProbePrefix then set isProofWindow to true
      if isProofWindow is false then set unsafeWindowCount to unsafeWindowCount + 1
    end repeat
  end tell
end tell
return "windows=" & (windowCount as text) & " unsafe=" & (unsafeWindowCount as text)
APPLESCRIPT
  ax_pid="$!"
  deadline=$((SECONDS + timeout_seconds))
  while kill -0 "$ax_pid" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      kill "$ax_pid" >/dev/null 2>&1 || true
      wait "$ax_pid" 2>/dev/null || true
      rm -f "$ax_tmp"
      printf 'Detached Ghostty proof stale-only reset check timed out before launch.\n' >>"$log_file"
      return 0
    fi
    sleep 0.1
  done
  wait "$ax_pid" 2>/dev/null || true
  ax_state="$(cat "$ax_tmp" 2>/dev/null || true)"
  rm -f "$ax_tmp"
  ax_window_count="$(printf '%s' "$ax_state" | sed -n 's/.*windows=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  unsafe_window_count="$(printf '%s' "$ax_state" | sed -n 's/.*unsafe=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  if [[ ! "$ax_window_count" =~ ^[1-9][0-9]*$ || "$unsafe_window_count" != "0" ]]; then
    if [[ "$ax_window_count" =~ ^[0-9]+$ && "$unsafe_window_count" =~ ^[0-9]+$ ]]; then
      printf 'Detached Ghostty proof not resetting stale-only host before launch: AX windows=%s unsafe=%s\n' "$ax_window_count" "$unsafe_window_count" >>"$log_file"
    else
      printf 'Detached Ghostty proof stale-only reset check was unavailable before launch.\n' >>"$log_file"
    fi
    return 0
  fi

  reset_reason="System Events reported only SteadyType proof/probe Ghostty AX windows (${ax_window_count})"
  printf 'Detached Ghostty proof resetting stale-only Ghostty host before launch: %s (%s)\n' "$(printf '%s' "$ghostty_pids" | tr '\n' ' ')" "$reset_reason" >>"$log_file"
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    kill "$proof_pid" >/dev/null 2>&1 || true
  done <<<"$ghostty_pids"
  sleep 0.4
  while IFS= read -r proof_pid; do
    [[ -z "$proof_pid" ]] && continue
    if kill -0 "$proof_pid" >/dev/null 2>&1; then
      kill -KILL "$proof_pid" >/dev/null 2>&1 || true
    fi
  done <<<"$ghostty_pids"
  sleep 0.4
}

start_run() {
  mkdir -p "$PROOF_ROOT"

  local active_runs latest run_dir_to_stop active_launcher
  active_runs="$(active_run_dirs || true)"
  if [[ -n "$active_runs" ]]; then
    if [[ "$FORCE_START" == "1" ]]; then
      while IFS= read -r run_dir_to_stop; do
        [[ -n "$run_dir_to_stop" ]] || continue
        active_launcher="$(status_value "$(status_file_for_run "$run_dir_to_stop")" launcher)"
        if [[ -n "$active_launcher" &&
              "$active_launcher" != "$LAUNCHER" &&
              ! "${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_ALLOW_CROSS_LAUNCHER_FORCE:-0}" =~ ^(1|true|yes|on)$ ]]; then
          echo "Refusing to force-stop active $active_launcher detached Ghostty proof from $LAUNCHER launcher: $run_dir_to_stop" >&2
          echo "Run stop --run-dir explicitly, or set AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_ALLOW_CROSS_LAUNCHER_FORCE=1." >&2
          return 1
        fi
        echo "Force start stopping active detached Ghostty proof: $run_dir_to_stop" >&2
        FORCE_STOP=1 stop_run "$run_dir_to_stop" >&2
      done <<<"$active_runs"
    else
      echo "Detached Ghostty proof is already running:" >&2
      printf '%s\n' "$active_runs" >&2
      echo "Use status/wait/tail, or start --force to stop active run(s) before starting." >&2
      return 1
    fi
  fi

  latest="$(latest_run_dir 2>/dev/null || true)"
  if [[ -n "$latest" && "$FORCE_START" != "1" ]] && run_is_active "$latest"; then
    echo "Detached Ghostty proof is already running: $latest" >&2
    echo "Use status/wait/tail, or start --force to stop it before starting." >&2
    return 1
  fi

  local timestamp run_dir status_file log_file startup_log runner_script worker_script plist_file launch_label pid launch_domain smoke_command_summary proof_artifact_dir
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  run_dir="$PROOF_ROOT/$timestamp-ghostty"
  status_file="$(status_file_for_run "$run_dir")"
  log_file="$(log_file_for_run "$run_dir")"
  startup_log="$run_dir/smoke-startup.log"
  proof_artifact_dir="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR:-$run_dir/proof-artifacts}"
  smoke_command_summary="$(detached_smoke_command_summary)"
  if [[ "$LAUNCHER" == "terminal" ]]; then
    runner_script="$run_dir/run-detached-proof.command"
    worker_script="$run_dir/run-detached-proof-worker.sh"
  else
    runner_script="$run_dir/run-detached-proof.sh"
    worker_script="$runner_script"
  fi
  plist_file="$run_dir/launch-agent.plist"
  launch_label="bar.r3d.steadytype.ghostty-detached-proof.$timestamp.$$"
  launch_domain="gui/$(id -u)"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "Dry run only; detached Ghostty proof would run:"
    echo "Run directory: $run_dir"
    echo "Log: $log_file"
    echo "Status: $status_file"
    echo "Smoke startup: $startup_log"
    echo "Proof artifacts: $proof_artifact_dir"
    echo "Launcher: $LAUNCHER"
    echo "Runner: $runner_script"
    if [[ "$LAUNCHER" == "launchd" ]]; then
      echo "LaunchAgent: $plist_file"
      echo "Command: launchctl bootstrap $launch_domain $plist_file"
    elif [[ "$LAUNCHER" == "terminal" ]]; then
      echo "Command: open -g -na Terminal $runner_script"
      echo "Worker: $worker_script"
    else
      echo "Command: /usr/bin/python3 start_new_session /bin/bash $runner_script"
    fi
    echo "Child smoke: $smoke_command_summary"
    return 0
  fi

  mkdir -p "$run_dir"
  : >"$log_file"
  reset_stale_only_ghostty_host_before_start "$log_file"
  create_runner_script "$worker_script" "$run_dir" "$status_file" "$log_file" "$LAUNCHER" "$launch_label" "$plist_file"
  if [[ "$LAUNCHER" == "terminal" ]]; then
    create_terminal_launcher_script "$runner_script" "$worker_script" "$log_file"
  fi
  if [[ "$LAUNCHER" == "launchd" ]]; then
    create_launch_agent_plist "$plist_file" "$launch_label" "$runner_script" "$log_file"
  fi
  {
    printf 'state=starting\n'
    printf 'pid=\n'
    printf 'started_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'run_dir=%s\n' "$run_dir"
    printf 'startup_log=%s\n' "$startup_log"
    printf 'proof_artifact_dir=%s\n' "$proof_artifact_dir"
    printf 'launcher=%s\n' "$LAUNCHER"
    if [[ "$LAUNCHER" == "launchd" ]]; then
      printf 'launch_label=%s\n' "$launch_label"
      printf 'plist_file=%s\n' "$plist_file"
    fi
    printf 'command=%s\n' "$smoke_command_summary"
    printf 'note=%s\n' 'Detached wrapper stores status and child output only; custom proof text is not persisted here.'
  } >"$status_file"
  printf '%s\n' "$run_dir" >"$LATEST_FILE"

  if [[ "$LAUNCHER" == "launchd" ]]; then
    if ! launchctl bootstrap "$launch_domain" "$plist_file" >>"$log_file" 2>&1; then
      {
        printf 'state=failed\n'
        printf 'pid=\n'
        printf 'started_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'finished_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'exit_status=1\n'
        printf 'run_dir=%s\n' "$run_dir"
        printf 'startup_log=%s\n' "$startup_log"
        printf 'proof_artifact_dir=%s\n' "$proof_artifact_dir"
        printf 'launcher=%s\n' "$LAUNCHER"
        printf 'launch_label=%s\n' "$launch_label"
        printf 'plist_file=%s\n' "$plist_file"
        printf 'command=%s\n' "$smoke_command_summary"
        printf 'note=%s\n' 'launchctl bootstrap failed before the child smoke could start.'
      } >"$status_file"
      return 1
    fi
    pid=""
  elif [[ "$LAUNCHER" == "terminal" ]]; then
    if ! open -g -na Terminal "$runner_script" >>"$log_file" 2>&1; then
      {
        printf 'state=failed\n'
        printf 'pid=\n'
        printf 'started_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'finished_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'exit_status=1\n'
        printf 'run_dir=%s\n' "$run_dir"
        printf 'startup_log=%s\n' "$startup_log"
        printf 'proof_artifact_dir=%s\n' "$proof_artifact_dir"
        printf 'launcher=%s\n' "$LAUNCHER"
        printf 'command=%s\n' "$smoke_command_summary"
        printf 'note=%s\n' 'Terminal.app launch failed before the child smoke could start.'
      } >"$status_file"
      return 1
    fi
    pid=""
  else
    pid="$(start_nohup_runner "$runner_script" "$log_file")"
  fi

  if [[ "$LAUNCHER" == "nohup" ]]; then
    printf 'Detached Ghostty proof nohup detached runner pid %s launched in a new session; runner will publish worker pid.\n' "$pid" >>"$log_file"
  else
    {
      printf 'state=starting\n'
      printf 'pid=%s\n' "$pid"
      printf 'started_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      printf 'run_dir=%s\n' "$run_dir"
      printf 'startup_log=%s\n' "$startup_log"
      printf 'proof_artifact_dir=%s\n' "$proof_artifact_dir"
      printf 'launcher=%s\n' "$LAUNCHER"
      if [[ "$LAUNCHER" == "launchd" ]]; then
        printf 'launch_label=%s\n' "$launch_label"
        printf 'plist_file=%s\n' "$plist_file"
      fi
      printf 'command=%s\n' "$smoke_command_summary"
      printf 'note=%s\n' 'Detached wrapper stores status and child output only; custom proof text is not persisted here.'
    } >"$status_file"
  fi

  echo "Started detached Ghostty proof."
  echo "Run directory: $run_dir"
  echo "Launcher: $LAUNCHER"
  if [[ "$LAUNCHER" == "launchd" ]]; then
    echo "Launch label: $launch_label"
  elif [[ "$LAUNCHER" == "terminal" ]]; then
    echo "Terminal runner: $runner_script"
  else
    echo "PID: $pid"
  fi
  echo "Status: script/claude_code_ghostty_detached_proof.sh status"
  echo "Wait: script/claude_code_ghostty_detached_proof.sh wait"
  echo "Log: $log_file"
}

resolve_run_dir_or_fail() {
  local run_dir
  run_dir="$(latest_run_dir 2>/dev/null || true)"
  if [[ -z "$run_dir" ]]; then
    echo "No detached Ghostty proof run found. Start one with:" >&2
    echo "script/claude_code_ghostty_detached_proof.sh start" >&2
    return 1
  fi
  printf '%s\n' "$run_dir"
}

wait_for_run() {
  local run_dir="$1"
  local status_file state pid exit_status
  status_file="$(status_file_for_run "$run_dir")"
  local deadline=$((SECONDS + WAIT_TIMEOUT_SECONDS))
  local wait_started_seconds="$SECONDS"
  local next_progress_seconds=$((SECONDS + WAIT_PROGRESS_SECONDS))
  while true; do
    if [[ ! -f "$status_file" ]]; then
      echo "No detached Ghostty proof status file found: $status_file" >&2
      return 1
    fi
    repair_dead_runner_status_if_needed "$run_dir"
    state="$(status_value "$status_file" state)"
    pid="$(status_value "$status_file" pid)"
    case "$state" in
      passed|failed)
        print_run_status "$run_dir"
        cleanup_launchd_job_if_terminal "$run_dir"
        exit_status="$(status_value "$status_file" exit_status)"
        [[ -n "$exit_status" ]] || exit_status=1
        return "$exit_status"
        ;;
      starting|running)
        if [[ -n "$pid" ]] && ! process_is_alive "$pid"; then
          repair_dead_runner_status_if_needed "$run_dir"
          state="$(status_value "$status_file" state)"
          if [[ "$state" == "failed" ]]; then
            print_run_status "$run_dir"
            return 1
          fi
        fi
        if ((SECONDS >= deadline)); then
          echo "Detached Ghostty proof wait timed out after ${WAIT_TIMEOUT_SECONDS}s." >&2
          echo "Run script/claude_code_ghostty_detached_proof.sh stop to terminate the active proof." >&2
          print_run_status "$run_dir"
          return 1
        fi
        if ((WAIT_PROGRESS_SECONDS > 0 && SECONDS >= next_progress_seconds)); then
          print_wait_progress "$run_dir" "$((SECONDS - wait_started_seconds))"
          next_progress_seconds=$((SECONDS + WAIT_PROGRESS_SECONDS))
        fi
        sleep "$WAIT_POLL_SECONDS"
        ;;
      *)
        print_run_status "$run_dir"
        return 1
        ;;
    esac
  done
}

stop_run() {
  local run_dir="$1"
  local status_file state pid smoke_pid pgid current_pgid deadline
  status_file="$(status_file_for_run "$run_dir")"
  if [[ ! -f "$status_file" ]]; then
    echo "No detached Ghostty proof status file found: $status_file" >&2
    return 1
  fi

  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  smoke_pid="$(smoke_pid_for_run "$run_dir")"
  if stop_requires_force_guard "$status_file" "$state" "$pid" "$smoke_pid"; then
    echo "Refusing to stop active detached Ghostty proof during the early evidence window: $run_dir" >&2
    echo "Use stop --force-stop if this is intentional, or wait ${STOP_FORCE_GRACE_SECONDS}s for normal stop cleanup." >&2
    print_run_status "$run_dir"
    return 2
  fi
  cleanup_launchd_job_if_terminal "$run_dir"

  if [[ -z "$pid" ]]; then
    if process_is_alive "$smoke_pid"; then
      terminate_orphaned_detached_smoke_processes "$run_dir"
      terminate_detached_proof_context_processes "$run_dir" || true
      write_parent_final_status "$run_dir" failed 143 "Detached proof smoke child was stopped by wrapper without a runner pid."
      print_run_status "$run_dir"
      return 0
    fi
    if terminate_detached_proof_context_processes "$run_dir"; then
      write_parent_final_status "$run_dir" failed 143 "Detached proof context was stopped by wrapper after runner exit."
      print_run_status "$run_dir"
      return 0
    fi
    echo "Detached Ghostty proof has no runner pid or smoke pid to stop." >&2
    print_run_status "$run_dir"
    return 1
  fi

  if ! process_is_alive "$pid"; then
    if process_is_alive "$smoke_pid"; then
      terminate_orphaned_detached_smoke_processes "$run_dir"
      terminate_detached_proof_context_processes "$run_dir" || true
      write_parent_final_status "$run_dir" failed 143 "Detached proof smoke child was stopped after runner exit."
    else
      if terminate_detached_proof_context_processes "$run_dir"; then
        write_parent_final_status "$run_dir" failed 143 "Detached proof context was stopped by wrapper after runner exit."
      fi
    fi
    echo "Detached Ghostty proof is not running."
    print_run_status "$run_dir"
    return 0
  fi

  echo "Stopping detached Ghostty proof: $run_dir"
  pgid="$(process_group_for_pid "$pid" || true)"
  current_pgid="$(process_group_for_pid "$$" || true)"
  if [[ -n "$pgid" && "$pgid" != "$current_pgid" ]]; then
    kill -TERM "-$pgid" >/dev/null 2>&1 || true
  else
    kill -TERM "$pid" >/dev/null 2>&1 || true
  fi

  deadline=$((SECONDS + 10))
  while process_is_alive "$pid" && ((SECONDS <= deadline)); do
    sleep 0.2
  done

  if process_is_alive "$pid"; then
    if [[ -n "$pgid" && "$pgid" != "$current_pgid" ]]; then
      kill -KILL "-$pgid" >/dev/null 2>&1 || true
    else
      kill -KILL "$pid" >/dev/null 2>&1 || true
    fi
    sleep 0.5
  fi

  if process_is_alive "$pid"; then
    echo "Detached Ghostty proof runner is still alive after stop: $pid" >&2
    print_run_status "$run_dir"
    return 1
  fi

  if process_is_alive "$smoke_pid"; then
    terminate_orphaned_detached_smoke_processes "$run_dir"
  fi
  terminate_detached_proof_context_processes "$run_dir" || true

  sleep 0.5
  state="$(status_value "$status_file" state)"
  if [[ "$state" == "starting" || "$state" == "running" ]]; then
    write_parent_final_status "$run_dir" failed 143 "Detached proof was stopped by wrapper before the child wrote final status."
  fi
  print_run_status "$run_dir"
}

case "$MODE" in
  start)
    start_run
    ;;
  status)
    print_run_status "$(resolve_run_dir_or_fail)"
    ;;
  wait)
    wait_for_run "$(resolve_run_dir_or_fail)"
    ;;
  tail)
    print_log_tail "$(resolve_run_dir_or_fail)"
    ;;
  stop)
    stop_run "$(resolve_run_dir_or_fail)"
    ;;
esac
