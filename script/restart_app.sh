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
SELFTEST=0

usage() {
  cat <<'EOF'
Usage: script/restart_app.sh
       script/restart_app.sh --release-proof [--cleanup]
       script/restart_app.sh --selftest

The release-proof path never quits another Tilde or touches the input method.
--cleanup stops only this dist app launched with --release-proof and its exact
packaged helper on the dedicated release-proof port. --selftest validates that
selection logic without launching or signaling a process.
EOF
}

while (($#)); do
  case "$1" in
    --release-proof) RELEASE_PROOF=1 ;;
    --cleanup) CLEANUP=1 ;;
    --selftest) SELFTEST=1 ;;
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
[[ "$SELFTEST" == "0" || ( "$RELEASE_PROOF" == "0" && "$CLEANUP" == "0" ) ]] || {
  echo "restart_app.sh: --selftest cannot be combined with process actions" >&2
  exit 2
}

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

process_executable() {
  /usr/sbin/lsof -nP -a -p "$1" -d txt -Fn 2>/dev/null \
    | awk '/^n/ { sub(/^n/, ""); print; exit }' || true
}
proof_helper_command() {
  local command="$1" args
  [[ "$command" == "$HELPER "* ]] || return 1
  args="${command#"$HELPER"}"
  [[ "$args" =~ (^|[[:space:]])--port[[:space:]]+${RELEASE_PROOF_PORT}([[:space:]]|$) ]]
}
release_proof_helper_identities() {
  local listeners rc=0 pid row parent command birth
  listeners="$(/usr/sbin/lsof -nP -t -a -iTCP:"$RELEASE_PROOF_PORT" \
    -sTCP:LISTEN 2>/dev/null)" || rc=$?
  [[ "$rc" == "0" || "$rc" == "1" ]] || return "$rc"
  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    row="$(ps -p "$pid" -o ppid=,command= 2>/dev/null || true)"
    read -r parent command <<<"$row"
    [[ "$parent" == "1" && "$(process_executable "$pid")" == "$HELPER" ]] || continue
    proof_helper_command "$command" || continue
    birth="$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
    [[ -n "${birth//[[:space:]]/}" ]] && printf '%s\t%s\n' "$pid" "$birth"
  done <<<"$listeners"
  return 0
}
captured_helper_is_current() {
  local identity="$1" pid
  pid="${identity%%$'\t'*}"
  helper_identity_matches "$identity" "$(process_executable "$pid")" \
    "$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
}
helper_identity_matches() {
  [[ "$2" == "$HELPER" && "$3" == "${1#*$'\t'}" ]]
}
stop_captured_helpers() {
  local captured="$1" signal identity pid any_running
  for signal in TERM KILL; do
    while IFS= read -r identity; do
      pid="${identity%%$'\t'*}"
      [[ -n "$pid" ]] && captured_helper_is_current "$identity" \
        && kill "-$signal" "$pid" 2>/dev/null || true
    done <<<"$captured"
    for _ in {1..20}; do
      any_running=0
      while IFS= read -r identity; do
        [[ -n "$identity" ]] && captured_helper_is_current "$identity" && any_running=1
      done <<<"$captured"
      [[ "$any_running" == "0" ]] && return 0
      sleep 0.1
    done
  done
  echo "release-proof helper did not stop; unrelated processes were left untouched" >&2
  return 1
}
cleanup_release_proof() {
  local helpers
  stop_exact_processes "app" proof_candidate_pids
  helpers="$(release_proof_helper_identities)" || return 1
  stop_captured_helpers "$helpers"
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
if [[ "$SELFTEST" == "1" ]]; then
  HELPER="/tmp/Tilde Proof.app/Contents/Helpers/llama-server"
  proof_helper_command "$HELPER --port $RELEASE_PROOF_PORT"
  ! proof_helper_command "$HELPER --port $PRODUCTION_PORT"
  helper_identity_matches $'201\tbirth-a' "$HELPER" birth-a
  ! helper_identity_matches $'201\tbirth-a' /tmp/other birth-a
  ! helper_identity_matches $'201\tbirth-a' "$HELPER" birth-b
  echo "selftest OK: cleanup matcher rejects port, path, and birth mismatches"
  exit 0
fi

[[ -x "$BINARY" ]] || { echo "missing built app: $APP" >&2; exit 1; }

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
