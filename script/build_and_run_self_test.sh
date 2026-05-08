#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_TEXT="$(sed -n '1,340p' script/build_and_run.sh)"

require_contains() {
  local expected="$1"
  if ! grep -Fq "$expected" <<<"$SCRIPT_TEXT"; then
    echo "missing expected build/run script text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local rejected="$1"
  if grep -Fq "$rejected" <<<"$SCRIPT_TEXT"; then
    echo "stale build/run script reference remains: $rejected" >&2
    exit 1
  fi
}

require_contains "kill_running_app_instances()"
require_contains "open_app()"
require_contains "is_target_app_running()"
require_contains "kill_running_app_instances"
reject_contains "stop_running_apps"
reject_contains "quarantine_stale_app_bundles"

echo "Build and run self-test passed."
