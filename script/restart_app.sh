#!/usr/bin/env bash
# The one restart path: stop only Tilde-owned processes, open dist/Tilde.app,
# and require the exact app plus its direct llama-server child to become healthy.
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

server_pids_on_port() {
  ps ax -o pid=,command= | awk -v port="$PORT" '
    $0 ~ /\/llama-server([[:space:]]|$)/ &&
    ($0 ~ ("--port " port "([[:space:]]|$)") || $0 ~ ("--port=" port "([[:space:]]|$)")) { print $1 }
  '
}

while IFS= read -r pid; do
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
done < <(tilde_pids)

for _ in {1..30}; do
  [[ -z "$(tilde_pids)" ]] && break
  sleep 0.1
done

# A crashed app can leave its server behind. The port match keeps this scoped
# to Tilde's local runtime rather than other llama-server work.
while IFS= read -r pid; do
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
done < <(server_pids_on_port)

/usr/bin/open -n -F "$APP"

for _ in {1..60}; do
  app_pid="$(pgrep -f "^${BINARY}([[:space:]]|$)" | head -n 1 || true)"
  if [[ -n "$app_pid" ]]; then
    child_pid="$(pgrep -P "$app_pid" -f '/llama-server([[:space:]]|$)' | head -n 1 || true)"
    if [[ -n "$child_pid" ]] \
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
