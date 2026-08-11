#!/usr/bin/env bash
# The one restart path: ask the current Tilde app to quit, open dist/Tilde.app,
# and require the exact app plus its exact helper child to become healthy.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT_DIR/dist/Tilde.app"
BINARY="$APP/Contents/MacOS/Tilde"
PORT=17872
SOCKET="$HOME/Library/Application Support/Tilde/ghost.sock"

[[ -x "$BINARY" ]] || { echo "missing built app: $APP" >&2; exit 1; }

tilde_pids() {
  ps ax -o pid=,command= | awk '
    $0 ~ /\/Tilde\.app\/Contents\/MacOS\/Tilde([[:space:]]|$)/ { print $1 }
  '
}

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
      && curl -sf "http://127.0.0.1:$PORT/health" >/dev/null \
      && [[ -S "$SOCKET" ]]; then
      echo "Tilde restarted from $APP (pid $app_pid, llama-server child $child_pid)."
      exit 0
    fi
  fi
  sleep 1
done

echo "Tilde restart failed: exact app, direct llama-server child, health, and socket did not all become ready." >&2
exit 1
