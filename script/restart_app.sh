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

proof_candidate_pids_from_rows() {
  local rows="$1"
  local pid parent command
  while read -r pid parent command; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ "$command" == "$BINARY --release-proof" ]] && printf '%s\n' "$pid"
  done <<<"$rows"
  return 0
}

process_rows() {
  ps ax -o pid=,ppid=,command=
}

proof_candidate_pids() {
  local rows
  rows="$(process_rows)"
  proof_candidate_pids_from_rows "$rows"
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

release_proof_helper_pids_from_snapshots() {
  local listener_pids="$1"
  local rows="$2"
  local proof_pids pid parent command
  proof_pids="$(proof_candidate_pids_from_rows "$rows")"
  while read -r pid parent command; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    grep -Fqx "$pid" <<<"$listener_pids" || continue
    [[ "$command" == "$HELPER" || "$command" == "$HELPER "* ]] || continue
    if [[ "$parent" == "1" ]] || grep -Fqx "$parent" <<<"$proof_pids"; then
      printf '%s\n' "$pid"
    fi
  done <<<"$rows"
  return 0
}

release_proof_listener_pids() {
  local output rc=0
  [[ -x /usr/sbin/lsof ]] || {
    echo "release-proof cleanup requires /usr/sbin/lsof" >&2
    return 1
  }
  output="$(/usr/sbin/lsof -nP -t -a \
    -iTCP:"$RELEASE_PROOF_PORT" -sTCP:LISTEN 2>/dev/null)" || rc=$?
  if [[ "$rc" != "0" && "$rc" != "1" ]]; then
    echo "could not inspect release-proof port $RELEASE_PROOF_PORT" >&2
    return "$rc"
  fi
  printf '%s\n' "$output" | awk '/^[0-9]+$/ { print }' | sort -nu
}

release_proof_helper_pids() {
  local listener_pids rows
  listener_pids="$(release_proof_listener_pids)" || return 1
  [[ -n "$listener_pids" ]] || return 0
  rows="$(process_rows)"
  release_proof_helper_pids_from_snapshots "$listener_pids" "$rows"
}

exact_helper_pid_is_running() {
  local command
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  command="$(ps -p "$1" -o command= 2>/dev/null || true)"
  [[ "$command" == "$HELPER" || "$command" == "$HELPER "* ]]
}

stop_release_proof_helpers() {
  local captured="${1:-}"
  local candidates pid any_running

  # These PIDs were selected by exact path, port, and parent immediately before
  # the proof app was stopped. They remain the same proof helpers if closing the
  # listener or losing the parent happens during shutdown.
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    exact_helper_pid_is_running "$pid" && kill -TERM "$pid" 2>/dev/null || true
  done <<<"$captured"

  # Keep looking briefly after the app exits. A helper can be reparented to PID
  # 1 before its original parent/child relationship is observed.
  for _ in {1..20}; do
    candidates="$(release_proof_helper_pids)" || return 1
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      if ! grep -Fqx "$pid" <<<"$captured"; then
        captured+="${captured:+$'\n'}$pid"
      fi
      exact_helper_pid_is_running "$pid" && kill -TERM "$pid" 2>/dev/null || true
    done <<<"$candidates"
    sleep 0.1
  done

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    exact_helper_pid_is_running "$pid" && kill -KILL "$pid" 2>/dev/null || true
  done <<<"$captured"

  # Verify the KILL phase. A late listener makes cleanup fail closed.
  for _ in {1..20}; do
    candidates="$(release_proof_helper_pids)" || return 1
    any_running=0
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && exact_helper_pid_is_running "$pid" && any_running=1
    done <<<"$captured"
    [[ "$any_running" == "0" && -z "$candidates" ]] && return 0
    sleep 0.1
  done

  echo "release-proof helper did not stop; unrelated paths and ports were left untouched" >&2
  return 1
}

cleanup_release_proof() {
  local helper_pids
  helper_pids="$(release_proof_helper_pids)"
  stop_exact_processes "app" proof_candidate_pids
  stop_release_proof_helpers "$helper_pids"
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

run_selftest() {
  local saved_binary="$BINARY"
  local saved_helper="$HELPER"
  local rows listeners actual expected proof_pids
  BINARY="/tmp/Tilde Proof.app/Contents/MacOS/Tilde"
  HELPER="/tmp/Tilde Proof.app/Contents/Helpers/llama-server"
  rows="$(printf '%s\n' \
    "101 1 $BINARY --release-proof" \
    "102 1 $BINARY" \
    "103 1 $BINARY --release-proof --extra" \
    "201 101 $HELPER --port $RELEASE_PROOF_PORT" \
    "202 1 $HELPER --port $RELEASE_PROOF_PORT" \
    "203 102 $HELPER --port $RELEASE_PROOF_PORT" \
    "204 999 $HELPER --port $RELEASE_PROOF_PORT" \
    "205 101 /tmp/other/llama-server --port $RELEASE_PROOF_PORT" \
    "206 101 ${HELPER}-copy --port $RELEASE_PROOF_PORT" \
    "207 101 $HELPER --port $PRODUCTION_PORT" \
    "208 103 $HELPER --port $RELEASE_PROOF_PORT")"
  listeners=$'201\n202\n203\n204\n205\n206\n208'
  actual="$(release_proof_helper_pids_from_snapshots "$listeners" "$rows")"
  expected=$'201\n202'
  proof_pids="$(proof_candidate_pids_from_rows "$rows")"
  BINARY="$saved_binary"
  HELPER="$saved_helper"
  [[ "$actual" == "$expected" ]] || {
    echo "selftest failed: selected unsafe helper PIDs: ${actual:-<none>}" >&2
    return 1
  }
  [[ "$proof_pids" == "101" ]] || {
    echo "selftest failed: proof app selection was not exact" >&2
    return 1
  }
  echo "selftest OK: helper cleanup requires exact path, proof port, and proof parent or PID 1"
}

if [[ "$SELFTEST" == "1" ]]; then
  run_selftest
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
