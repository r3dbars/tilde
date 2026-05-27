#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROOF_ROOT="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR:-$ROOT_DIR/dist/claude-code-ghostty-detached-proof}"
LATEST_FILE="$PROOF_ROOT/latest-run.txt"
MODE="${1:-status}"
DRY_RUN=0
FORCE_START=0
RUN_DIR=""
TAIL_LINES=80
WAIT_POLL_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_POLL_SECONDS:-2}"
WAIT_TIMEOUT_SECONDS="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_TIMEOUT_SECONDS:-900}"
LAUNCHER="${AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER:-terminal}"

usage() {
  cat <<'EOF'
Usage: script/claude_code_ghostty_detached_proof.sh <start|status|wait|tail|stop> [options]

Runs the Claude Code Ghostty one-word no-submit proof outside the Codex
foreground shell. This is for the current focus-steal gap: the proof launches a
normal Terminal.app runner by default, writes one log/status directory under
dist/, and returns right away so the disposable Ghostty window can keep focus
during Tab accept.

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
  --force          Allow start while the latest detached run is still active.

Set AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER=launchd or nohup to use the
older launch modes. The wrapper uses the same disposable defaults as
script/real_app_smoke.sh. It does not persist custom proof text into the
generated runner, LaunchAgent plist, or status file.
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

log_file_for_run() {
  printf '%s/proof.log\n' "$1"
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

run_is_active() {
  local run_dir="$1"
  local status_file state pid
  status_file="$(status_file_for_run "$run_dir")"
  [[ -f "$status_file" ]] || return 1
  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  [[ "$state" == "starting" || "$state" == "running" ]] && process_is_alive "$pid"
}

print_run_status() {
  local run_dir="$1"
  local status_file log_file pid state
  status_file="$(status_file_for_run "$run_dir")"
  log_file="$(log_file_for_run "$run_dir")"

  if [[ ! -f "$status_file" ]]; then
    echo "No detached Ghostty proof status file found: $status_file" >&2
    return 1
  fi

  cat "$status_file"
  pid="$(status_value "$status_file" pid)"
  state="$(status_value "$status_file" state)"
  if [[ -z "$pid" && "$state" == "starting" ]]; then
    echo "runner_process=pending"
  elif process_is_alive "$pid"; then
    echo "runner_process=alive"
  else
    echo "runner_process=not-running"
    if [[ "$state" == "starting" || "$state" == "running" ]]; then
      echo "warning=runner exited before writing a final status"
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
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -u\n\n'
    printf "trap '' HUP\n"
    printf 'export PATH=%q\n' "$runner_path"
    printf 'export HOME=%q\n' "$runner_home"
    printf 'ROOT_DIR=%q\n' "$ROOT_DIR"
    printf 'RUN_DIR=%q\n' "$run_dir"
    printf 'STATUS_FILE=%q\n' "$status_file"
    printf 'LOG_FILE=%q\n' "$log_file"
    printf 'LAUNCHER=%q\n' "$launcher"
    printf 'LAUNCH_LABEL=%q\n' "$launch_label"
    printf 'PLIST_FILE=%q\n' "$plist_file"
    cat <<'EOF'
STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

write_status() {
  local state="$1"
  local exit_status="${2:-}"
  local finished_at="${3:-}"
  {
    printf 'state=%s\n' "$state"
    printf 'pid=%s\n' "$$"
    printf 'started_at=%s\n' "$STARTED_AT"
    if [[ -n "$finished_at" ]]; then
      printf 'finished_at=%s\n' "$finished_at"
    fi
    if [[ -n "$exit_status" ]]; then
      printf 'exit_status=%s\n' "$exit_status"
    fi
    printf 'run_dir=%s\n' "$RUN_DIR"
    printf 'launcher=%s\n' "$LAUNCHER"
    if [[ -n "$LAUNCH_LABEL" ]]; then
      printf 'launch_label=%s\n' "$LAUNCH_LABEL"
    fi
    if [[ -n "$PLIST_FILE" ]]; then
      printf 'plist_file=%s\n' "$PLIST_FILE"
    fi
    printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
    printf 'note=%s\n' 'Detached wrapper stores status and child output only; custom proof text is not persisted here.'
  } >"$STATUS_FILE"
}

handle_signal() {
  local signal_name="$1"
  local exit_status="$2"
  local finished_at
  finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  write_status failed "$exit_status" "$finished_at"
  printf '\nDetached Ghostty proof interrupted by %s at %s\n' "$signal_name" "$finished_at" >>"$LOG_FILE"
  exit "$exit_status"
}

trap 'handle_signal TERM 143' TERM
trap 'handle_signal INT 130' INT

cd "$ROOT_DIR" || exit 1
write_status running

{
  printf 'Detached Ghostty proof started at %s\n' "$STARTED_AT"
  printf 'Run directory: %s\n' "$RUN_DIR"
  printf 'Root: %s\n' "$ROOT_DIR"
  printf 'Command: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate\n'
  printf '\n'
} >>"$LOG_FILE"

set +e
AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN="${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-1}" \
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE="${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-1}" \
AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS:-4}" \
AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_SECONDS:-20}" \
AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS="${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_ATTEMPTS:-2}" \
  ./script/real_app_smoke.sh claude-code-ghostty --manual-gate >>"$LOG_FILE" 2>&1
status=$?
set -e

finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
if ((status == 0)); then
  write_status passed "$status" "$finished_at"
else
  write_status failed "$status" "$finished_at"
fi
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
nohup "$WORKER_SCRIPT" >>"$LOG_FILE" 2>&1 &
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
  local status_file pid started_at launcher launch_label plist_file
  status_file="$(status_file_for_run "$run_dir")"
  pid="$(status_value "$status_file" pid)"
  started_at="$(status_value "$status_file" started_at)"
  launcher="$(status_value "$status_file" launcher)"
  launch_label="$(status_value "$status_file" launch_label)"
  plist_file="$(status_value "$status_file" plist_file)"
  [[ -n "$started_at" ]] || started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  {
    printf 'state=%s\n' "$state"
    printf 'pid=%s\n' "$pid"
    printf 'started_at=%s\n' "$started_at"
    printf 'finished_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'exit_status=%s\n' "$exit_status"
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
    printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
    printf 'note=%s\n' "$note"
  } >"$status_file"
}

start_run() {
  mkdir -p "$PROOF_ROOT"

  local latest
  latest="$(latest_run_dir 2>/dev/null || true)"
  if [[ -n "$latest" && "$FORCE_START" != "1" ]] && run_is_active "$latest"; then
    echo "Detached Ghostty proof is already running: $latest" >&2
    echo "Use status/wait/tail, or start --force if you intentionally want another run." >&2
    return 1
  fi

  local timestamp run_dir status_file log_file runner_script worker_script plist_file launch_label pid launch_domain
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  run_dir="$PROOF_ROOT/$timestamp-ghostty"
  status_file="$(status_file_for_run "$run_dir")"
  log_file="$(log_file_for_run "$run_dir")"
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
    echo "Launcher: $LAUNCHER"
    if [[ "$LAUNCHER" == "launchd" ]]; then
      echo "LaunchAgent: $plist_file"
      echo "Command: launchctl bootstrap $launch_domain $plist_file"
    elif [[ "$LAUNCHER" == "terminal" ]]; then
      echo "Command: open -g -na Terminal $runner_script"
      echo "Worker: $worker_script"
    else
      echo "Command: nohup $runner_script"
    fi
    echo "Child smoke: AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate"
    return 0
  fi

  mkdir -p "$run_dir"
  : >"$log_file"
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
    printf 'launcher=%s\n' "$LAUNCHER"
    if [[ "$LAUNCHER" == "launchd" ]]; then
      printf 'launch_label=%s\n' "$launch_label"
      printf 'plist_file=%s\n' "$plist_file"
    fi
    printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
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
        printf 'launcher=%s\n' "$LAUNCHER"
        printf 'launch_label=%s\n' "$launch_label"
        printf 'plist_file=%s\n' "$plist_file"
        printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
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
        printf 'launcher=%s\n' "$LAUNCHER"
        printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
        printf 'note=%s\n' 'Terminal.app launch failed before the child smoke could start.'
      } >"$status_file"
      return 1
    fi
    pid=""
  else
    nohup "$runner_script" >>"$log_file" 2>&1 &
    pid=$!
  fi

  {
    printf 'state=starting\n'
    printf 'pid=%s\n' "$pid"
    printf 'started_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'run_dir=%s\n' "$run_dir"
    printf 'launcher=%s\n' "$LAUNCHER"
    if [[ "$LAUNCHER" == "launchd" ]]; then
      printf 'launch_label=%s\n' "$launch_label"
      printf 'plist_file=%s\n' "$plist_file"
    fi
    printf 'command=%s\n' 'AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate'
    printf 'note=%s\n' 'Detached wrapper stores status and child output only; custom proof text is not persisted here.'
  } >"$status_file"

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
  while true; do
    if [[ ! -f "$status_file" ]]; then
      echo "No detached Ghostty proof status file found: $status_file" >&2
      return 1
    fi
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
          print_run_status "$run_dir"
          return 1
        fi
        if ((SECONDS >= deadline)); then
          echo "Detached Ghostty proof wait timed out after ${WAIT_TIMEOUT_SECONDS}s." >&2
          echo "Run script/claude_code_ghostty_detached_proof.sh stop to terminate the active proof." >&2
          print_run_status "$run_dir"
          return 1
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
  local status_file state pid pgid current_pgid deadline
  status_file="$(status_file_for_run "$run_dir")"
  if [[ ! -f "$status_file" ]]; then
    echo "No detached Ghostty proof status file found: $status_file" >&2
    return 1
  fi

  state="$(status_value "$status_file" state)"
  pid="$(status_value "$status_file" pid)"
  cleanup_launchd_job_if_terminal "$run_dir"

  if [[ -z "$pid" ]]; then
    echo "Detached Ghostty proof has no runner pid to stop." >&2
    print_run_status "$run_dir"
    return 1
  fi

  if ! process_is_alive "$pid"; then
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
