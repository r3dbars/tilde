#!/usr/bin/env bash
# The one restart path: ask the current Tilde app to quit, open dist/Tilde.app,
# and require the exact app plus its exact helper child to become healthy.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/dist/Tilde.app"
BINARY="$APP/Contents/MacOS/Tilde"
PRODUCTION_PORT=17872
RELEASE_PROOF_PORT=17873
SOCKET="$HOME/Library/Application Support/Tilde/ghost.sock"
HELPER="$APP/Contents/Helpers/llama-server"
RELEASE_PROOF=0
CLEANUP=0

usage() {
  cat <<'EOF'
Usage: script/restart_app.sh
       script/restart_app.sh --release-proof [--cleanup]

The release-proof path never quits another Tilde or touches the input method.
--cleanup stops only this dist app launched with --release-proof and its exact
packaged helper.
EOF
}

while (($#)); do
  case "$1" in
    --release-proof) RELEASE_PROOF=1 ;;
    --cleanup) CLEANUP=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "restart_app.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[[ "$CLEANUP" == "0" || "$RELEASE_PROOF" == "1" ]] || {
  echo "restart_app.sh: --cleanup requires --release-proof" >&2
  exit 2
}

[[ -x "$BINARY" ]] || { echo "missing built app: $APP" >&2; exit 1; }

tilde_pids() {
  ps ax -o pid=,command= | awk '
    $0 ~ /\/Tilde\.app\/Contents\/MacOS\/Tilde([[:space:]]|$)/ { print $1 }
  '
}

proof_candidate_pids() {
  ps ax -o pid=,command= | while read -r pid command; do
    [[ "$command" == "$BINARY --release-proof" ]] && printf '%s\n' "$pid"
  done
}

other_candidate_pids() {
  ps ax -o pid=,command= | while read -r pid command; do
    if [[ "$command" == "$BINARY" || "$command" == "$BINARY "* ]] \
      && [[ "$command" != "$BINARY --release-proof" ]]; then
      printf '%s\n' "$pid"
    fi
  done
}

stop_exact_processes() {
  local label="$1"
  local finder="$2"
  local pids pid
  pids="$($finder)"
  [[ -n "$pids" ]] || return 0
  while read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done <<<"$pids"
  for _ in {1..50}; do
    [[ -z "$($finder)" ]] && return 0
    sleep 0.1
  done
  pids="$($finder)"
  while read -r pid; do
    [[ -n "$pid" ]] && kill -KILL "$pid" 2>/dev/null || true
  done <<<"$pids"
  for _ in {1..20}; do
    [[ -z "$($finder)" ]] && return 0
    sleep 0.1
  done
  echo "release-proof $label did not stop; leaving unrelated processes untouched" >&2
  return 1
}

exact_helper_pid_is_running() {
  local command
  command="$(ps -p "$1" -o command= 2>/dev/null || true)"
  [[ "$command" == "$HELPER" || "$command" == "$HELPER "* ]]
}

stop_captured_helpers() {
  local pids="$1"
  local pid any_running
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    exact_helper_pid_is_running "$pid" && kill -TERM "$pid" 2>/dev/null || true
  done <<<"$pids"
  for _ in {1..20}; do
    any_running=0
    while read -r pid; do
      [[ -n "$pid" ]] && exact_helper_pid_is_running "$pid" && any_running=1
    done <<<"$pids"
    [[ "$any_running" == "0" ]] && return 0
    sleep 0.1
  done
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    exact_helper_pid_is_running "$pid" && kill -KILL "$pid" 2>/dev/null || true
  done <<<"$pids"
  return 0
}

cleanup_release_proof() {
  local app_pids child_pids="" app_pid child_pid
  app_pids="$(proof_candidate_pids)"
  while read -r app_pid; do
    [[ -n "$app_pid" ]] || continue
    while read -r child_pid; do
      [[ -n "$child_pid" ]] && child_pids+="${child_pids:+$'\n'}$child_pid"
    done < <(proof_child_pid "$app_pid")
  done <<<"$app_pids"
  stop_exact_processes "app" proof_candidate_pids
  stop_captured_helpers "$child_pids"
}

proof_child_pid() {
  local wanted_parent="$1"
  ps ax -o pid=,ppid=,command= | while read -r pid parent command; do
    if [[ "$parent" == "$wanted_parent" ]] \
      && [[ "$command" == "$HELPER" || "$command" == "$HELPER "* ]]; then
      printf '%s\n' "$pid"
    fi
  done
}

if [[ "$RELEASE_PROOF" == "1" ]]; then
  cleanup_release_proof
  if [[ "$CLEANUP" == "1" ]]; then
    echo "Exact release-proof candidate is stopped."
    exit 0
  fi
  [[ -z "$(other_candidate_pids)" ]] || {
    echo "A non-proof instance of this candidate is running; leaving it untouched." >&2
    exit 1
  }

  /usr/bin/open -n -F "$APP" --args --release-proof
  for _ in {1..60}; do
    app_pid="$(proof_candidate_pids | head -n 1)"
    if [[ -n "$app_pid" ]]; then
      child_pid="$(proof_child_pid "$app_pid" | head -n 1)"
      if [[ -n "$child_pid" ]] \
        && curl -sf "http://127.0.0.1:$RELEASE_PROOF_PORT/health" >/dev/null; then
        echo "Tilde release proof started from $APP (pid $app_pid, llama-server child $child_pid)."
        exit 0
      fi
    fi
    sleep 1
  done
  cleanup_release_proof
  echo "Release-proof launch failed; only the exact candidate and packaged helper were stopped." >&2
  exit 1
fi

if [[ -n "$(tilde_pids)" ]]; then
  /usr/bin/osascript -e 'tell application id "bar.r3d.tilde" to quit' >/dev/null 2>&1 || true
fi

for _ in {1..50}; do
  [[ -z "$(tilde_pids)" ]] && break
  sleep 0.1
done
[[ -z "$(tilde_pids)" ]] || {
  echo "Tilde did not quit cleanly; leaving it and its helper untouched." >&2
  exit 1
}

/usr/bin/open -n -F "$APP"

for _ in {1..60}; do
  app_pid="$(pgrep -f "^${BINARY}([[:space:]]|$)" | head -n 1 || true)"
  if [[ -n "$app_pid" ]]; then
    child_pid="$(pgrep -P "$app_pid" -f '/llama-server([[:space:]]|$)' | head -n 1 || true)"
    child_command="$(ps -p "$child_pid" -o command= 2>/dev/null || true)"
    expected_helper="$APP/Contents/Helpers/llama-server"
    if [[ -n "$child_pid" ]] \
      && [[ "$child_command" == "$expected_helper" || "$child_command" == "$expected_helper "* ]] \
      && curl -sf "http://127.0.0.1:$PRODUCTION_PORT/health" >/dev/null \
      && [[ -S "$SOCKET" ]]; then
      echo "Tilde restarted from $APP (pid $app_pid, llama-server child $child_pid)."
      exit 0
    fi
  fi
  sleep 1
done

echo "Tilde restart failed: exact app, direct llama-server child, health, and socket did not all become ready." >&2
exit 1
