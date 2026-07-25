#!/bin/bash
# The one blessed way to restart SteadyType. No environment variables — the
# app's real configuration lives in persisted defaults (see RuntimeSetting),
# so a restart here behaves identically to a login-item launch after reboot.
# Kills only our own processes: the app and the llama-server on OUR port.
set -euo pipefail

DIST="$(cd "$(dirname "$0")/.." && pwd)/dist/SteadyType.app"
PORT=17872

pkill -x SteadyType 2>/dev/null || true
sleep 1
for pid in $(pgrep -f llama-server 2>/dev/null || true); do
  if ps -o args= -p "$pid" | grep -q -- "--port $PORT"; then
    kill "$pid" 2>/dev/null || true
  fi
done
sleep 1

open "$DIST"

for _ in $(seq 1 30); do
  sleep 2
  if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 \
     && [ -S "$HOME/Library/Application Support/SteadyType/ghost.sock" ]; then
    echo "SteadyType restarted: brain socket up, engine healthy."
    exit 0
  fi
done
echo "SteadyType relaunched but the engine is not healthy yet — check the menu-bar status line." >&2
exit 1
