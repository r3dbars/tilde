#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
ALIVE_SMOKE_PID=""
ALIVE_CONTEXT_PID=""
ALIVE_CONTEXT_HOST_PID=""
cleanup() {
  if [[ -n "${ALIVE_SMOKE_PID:-}" ]]; then
    kill "$ALIVE_SMOKE_PID" >/dev/null 2>&1 || true
    wait "$ALIVE_SMOKE_PID" 2>/dev/null || true
  fi
  if [[ -n "${ALIVE_CONTEXT_PID:-}" ]]; then
    kill "$ALIVE_CONTEXT_PID" >/dev/null 2>&1 || true
    wait "$ALIVE_CONTEXT_PID" 2>/dev/null || true
  fi
  if [[ -n "${ALIVE_CONTEXT_HOST_PID:-}" ]]; then
    kill "$ALIVE_CONTEXT_HOST_PID" >/dev/null 2>&1 || true
    wait "$ALIVE_CONTEXT_HOST_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "missing expected detached Ghostty proof text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local file="$1"
  local rejected="$2"
  if grep -Fq -- "$rejected" "$file"; then
    echo "unsafe detached Ghostty proof text is present: $rejected" >&2
    exit 1
  fi
}

start_fake_smoke_process() {
  bash -c 'trap "exit 0" TERM; while :; do sleep 1 & wait $!; done' >/dev/null 2>&1 &
  printf '%s\n' "$!"
}

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh --help >"$TMP_DIR/help.txt"
require_contains "$TMP_DIR/help.txt" "start|status|wait|tail|stop"
require_contains "$TMP_DIR/help.txt" "outside the Codex"
require_contains "$TMP_DIR/help.txt" "custom proof text"
require_contains "$TMP_DIR/help.txt" "LaunchAgent"
require_contains "$TMP_DIR/help.txt" "terminal or nohup"
require_contains "$TMP_DIR/help.txt" "LaunchAgent by default"
require_contains "$TMP_DIR/help.txt" "--force-stop"
require_contains script/claude_code_ghostty_detached_proof.sh "reset_stale_only_ghostty_host_before_start"
require_contains script/claude_code_ghostty_detached_proof.sh "SteadyType AppleScript Probe"
require_contains script/claude_code_ghostty_detached_proof.sh "SteadyType Submit Probe"
require_contains script/claude_code_ghostty_detached_proof.sh "unsafeWindowCount"
require_contains script/claude_code_ghostty_detached_proof.sh "Detached Ghostty proof resetting stale-only Ghostty host before launch"
require_contains script/claude_code_ghostty_detached_proof.sh 'reset_stale_only_ghostty_host_before_start "$log_file"'
require_contains script/claude_code_ghostty_detached_proof.sh "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR"
require_contains script/real_app_smoke.sh "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/dry-run.txt"
require_contains "$TMP_DIR/dry-run.txt" "Dry run only; detached Ghostty proof would run:"
require_contains "$TMP_DIR/dry-run.txt" "Launcher: launchd"
require_contains "$TMP_DIR/dry-run.txt" "LaunchAgent:"
require_contains "$TMP_DIR/dry-run.txt" "Command: launchctl bootstrap"
require_contains "$TMP_DIR/dry-run.txt" "run-detached-proof.sh"
require_contains "$TMP_DIR/dry-run.txt" "script/real_app_smoke.sh claude-code-ghostty --manual-gate"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=0.12"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS=45"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=0"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=hid"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER=0"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES=2"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=0"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_NATIVE_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE=0"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED=1"
require_contains "$TMP_DIR/dry-run.txt" "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1"
require_contains "$TMP_DIR/dry-run.txt" "proof.log"
require_contains "$TMP_DIR/dry-run.txt" "status.env"
require_contains "$TMP_DIR/dry-run.txt" "Smoke startup:"
require_contains "$TMP_DIR/dry-run.txt" "Proof artifacts:"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=1 \
AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=0.18 \
AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE=1 \
AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS=2 \
AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=0 \
AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=4 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS=0.25 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS=4 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS=5 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS=5 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS=6 \
AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=session \
AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=1 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER=1 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_SECONDS=9 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS=0.75 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS=7 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS=0.5 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS=8 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS=3 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS=9 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES=3 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE=1 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE=0 \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED=0 \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/passthrough-dry-run.txt"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=0.18"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS=2"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=4"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_SECONDS=0.25"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_PROBE_TIMEOUT_SECONDS=4"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS=5"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_PROBE=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_SYSTEM_EVENTS_TIMEOUT_SECONDS=5"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_STEAL_WAIT_SECONDS=6"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=session"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER_SECONDS=9"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS=0.75"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS=7"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_PROBE_SECONDS=0.5"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_HID_TAB_TIMEOUT_SECONDS=8"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_PROBE_SECONDS=3"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_FALLBACK_TAB_TIMEOUT_SECONDS=9"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MAX_KEY_CAPTURE_MISSES=3"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_MUTATION_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PRE_ACCEPT_EXTERNAL_SYSTEM_EVENTS_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE=1"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_STALE_ONLY_RESET_ENABLED=0"
require_contains "$TMP_DIR/passthrough-dry-run.txt" "script/real_app_smoke.sh claude-code-ghostty --manual-gate"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER=terminal \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/terminal-dry-run.txt"
require_contains "$TMP_DIR/terminal-dry-run.txt" "Launcher: terminal"
require_contains "$TMP_DIR/terminal-dry-run.txt" "open -g -na Terminal"
require_contains "$TMP_DIR/terminal-dry-run.txt" "run-detached-proof.command"
require_contains "$TMP_DIR/terminal-dry-run.txt" "run-detached-proof-worker.sh"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=1 \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/command-open-dry-run.txt"
require_contains "$TMP_DIR/command-open-dry-run.txt" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=1"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER=launchd \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/launchd-dry-run.txt"
require_contains "$TMP_DIR/launchd-dry-run.txt" "Launcher: launchd"
require_contains "$TMP_DIR/launchd-dry-run.txt" "LaunchAgent:"
require_contains "$TMP_DIR/launchd-dry-run.txt" "launchctl bootstrap"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_LAUNCHER=nohup \
  script/claude_code_ghostty_detached_proof.sh start --dry-run >"$TMP_DIR/nohup-dry-run.txt"
require_contains "$TMP_DIR/nohup-dry-run.txt" "Launcher: nohup"
require_contains "$TMP_DIR/nohup-dry-run.txt" "Command: /usr/bin/python3 start_new_session /bin/bash"
require_contains "$TMP_DIR/nohup-dry-run.txt" "run-detached-proof.sh"

FAKE_RUN="$TMP_DIR/proofs/fake-run"
mkdir -p "$FAKE_RUN"
cat >"$FAKE_RUN/status.env" <<EOF
state=passed
pid=999999
started_at=2026-05-27T00:00:00Z
finished_at=2026-05-27T00:00:01Z
exit_status=0
run_dir=$FAKE_RUN
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'fake detached log\n' >"$FAKE_RUN/proof.log"
printf '%s\n' "$FAKE_RUN" >"$TMP_DIR/proofs/latest-run.txt"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status >"$TMP_DIR/status.txt"
require_contains "$TMP_DIR/status.txt" "state=passed"
require_contains "$TMP_DIR/status.txt" "runner_process=not-running"
require_contains "$TMP_DIR/status.txt" "script/real_app_smoke.sh claude-code-ghostty --manual-gate"

RUNNING_SMOKE_RUN="$TMP_DIR/proofs/running-smoke-run"
mkdir -p "$RUNNING_SMOKE_RUN"
ALIVE_SMOKE_PID="$(start_fake_smoke_process)"
cat >"$RUNNING_SMOKE_RUN/status.env" <<EOF
state=running
pid=$$
smoke_pid=$ALIVE_SMOKE_PID
started_at=2026-05-27T00:00:01Z
run_dir=$RUNNING_SMOKE_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'Detached Ghostty running smoke detached log\n' >"$RUNNING_SMOKE_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$RUNNING_SMOKE_RUN" >"$TMP_DIR/running-smoke-status.txt"
require_contains "$TMP_DIR/running-smoke-status.txt" "smoke_pid=$ALIVE_SMOKE_PID"
require_contains "$TMP_DIR/running-smoke-status.txt" "runner_process=alive"
require_contains "$TMP_DIR/running-smoke-status.txt" "smoke_process=alive"
(
  sleep 2
  cat >"$RUNNING_SMOKE_RUN/status.env" <<EOF
state=passed
pid=$$
smoke_pid=$ALIVE_SMOKE_PID
started_at=2026-05-27T00:00:01Z
finished_at=2026-05-27T00:00:03Z
exit_status=0
run_dir=$RUNNING_SMOKE_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
  kill "$ALIVE_SMOKE_PID" >/dev/null 2>&1 || true
) &
WAIT_PROGRESS_UPDATER_PID="$!"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_PROGRESS_SECONDS=1 \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_POLL_SECONDS=1 \
  script/claude_code_ghostty_detached_proof.sh wait --run-dir "$RUNNING_SMOKE_RUN" >"$TMP_DIR/running-smoke-wait.txt"
wait "$WAIT_PROGRESS_UPDATER_PID" 2>/dev/null || true
require_contains "$TMP_DIR/running-smoke-wait.txt" "Detached Ghostty proof still running after"
require_contains "$TMP_DIR/running-smoke-wait.txt" "phase=Detached Ghostty"
require_contains "$TMP_DIR/running-smoke-wait.txt" "state=passed"
kill "$ALIVE_SMOKE_PID" >/dev/null 2>&1 || true
wait "$ALIVE_SMOKE_PID" 2>/dev/null || true
ALIVE_SMOKE_PID=""

ORPHANED_SMOKE_RUN="$TMP_DIR/proofs/orphaned-smoke-run"
mkdir -p "$ORPHANED_SMOKE_RUN"
ALIVE_SMOKE_PID="$(start_fake_smoke_process)"
cat >"$ORPHANED_SMOKE_RUN/status.env" <<EOF
state=running
pid=999999
smoke_pid=$ALIVE_SMOKE_PID
started_at=2026-05-27T00:00:01Z
run_dir=$ORPHANED_SMOKE_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'orphaned smoke detached log\n' >"$ORPHANED_SMOKE_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$ORPHANED_SMOKE_RUN" >"$TMP_DIR/orphaned-smoke-status.txt"
require_contains "$TMP_DIR/orphaned-smoke-status.txt" "state=running"
require_contains "$TMP_DIR/orphaned-smoke-status.txt" "smoke_pid=$ALIVE_SMOKE_PID"
require_contains "$TMP_DIR/orphaned-smoke-status.txt" "runner_process=not-running"
require_contains "$TMP_DIR/orphaned-smoke-status.txt" "warning=runner exited before writing a final status"
require_contains "$TMP_DIR/orphaned-smoke-status.txt" "smoke_process=alive"
reject_contains "$TMP_DIR/orphaned-smoke-status.txt" "state=failed"
kill "$ALIVE_SMOKE_PID" >/dev/null 2>&1 || true
wait "$ALIVE_SMOKE_PID" 2>/dev/null || true
ALIVE_SMOKE_PID=""

GUARDED_STOP_RUN="$TMP_DIR/proofs/guarded-stop-run"
mkdir -p "$GUARDED_STOP_RUN"
ALIVE_SMOKE_PID="$(start_fake_smoke_process)"
cat >"$GUARDED_STOP_RUN/status.env" <<EOF
state=running
pid=999999
smoke_pid=$ALIVE_SMOKE_PID
started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
run_dir=$GUARDED_STOP_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'guarded stop detached log\n' >"$GUARDED_STOP_RUN/proof.log"
if AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh stop --run-dir "$GUARDED_STOP_RUN" >"$TMP_DIR/guarded-stop-refused.txt" 2>&1; then
  echo "detached Ghostty proof early stop should require --force-stop" >&2
  exit 1
fi
require_contains "$TMP_DIR/guarded-stop-refused.txt" "Refusing to stop active detached Ghostty proof during the early evidence window"
require_contains "$TMP_DIR/guarded-stop-refused.txt" "Use stop --force-stop if this is intentional"
if ! kill -0 "$ALIVE_SMOKE_PID" >/dev/null 2>&1; then
  echo "detached Ghostty proof guarded stop should leave the active smoke pid alive" >&2
  exit 1
fi
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh stop --force-stop --run-dir "$GUARDED_STOP_RUN" >"$TMP_DIR/guarded-stop-forced.txt"
require_contains "$TMP_DIR/guarded-stop-forced.txt" "state=failed"
require_contains "$TMP_DIR/guarded-stop-forced.txt" "exit_status=143"
if kill -0 "$ALIVE_SMOKE_PID" >/dev/null 2>&1; then
  echo "detached Ghostty proof --force-stop should terminate guarded smoke pid $ALIVE_SMOKE_PID" >&2
  exit 1
fi
wait "$ALIVE_SMOKE_PID" 2>/dev/null || true
ALIVE_SMOKE_PID=""

STOP_ORPHANED_SMOKE_RUN="$TMP_DIR/proofs/stop-orphaned-smoke-run"
mkdir -p "$STOP_ORPHANED_SMOKE_RUN"
bash -c 'trap "exit 0" TERM; while :; do sleep 1 & wait $!; done' &
ALIVE_SMOKE_PID="$!"
cat >"$STOP_ORPHANED_SMOKE_RUN/status.env" <<EOF
state=running
pid=999999
smoke_pid=$ALIVE_SMOKE_PID
started_at=2026-05-27T00:00:01Z
run_dir=$STOP_ORPHANED_SMOKE_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'stop orphaned smoke detached log\n' >"$STOP_ORPHANED_SMOKE_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh stop --run-dir "$STOP_ORPHANED_SMOKE_RUN" >"$TMP_DIR/stop-orphaned-smoke-status.txt"
require_contains "$TMP_DIR/stop-orphaned-smoke-status.txt" "state=failed"
require_contains "$TMP_DIR/stop-orphaned-smoke-status.txt" "exit_status=143"
require_contains "$TMP_DIR/stop-orphaned-smoke-status.txt" "Detached proof smoke child was stopped after runner exit."
require_contains "$STOP_ORPHANED_SMOKE_RUN/proof.log" "Stopped orphaned detached Ghostty smoke process pid=$ALIVE_SMOKE_PID after runner exit."
if kill -0 "$ALIVE_SMOKE_PID" >/dev/null 2>&1; then
  echo "detached Ghostty proof stop should terminate orphaned smoke pid $ALIVE_SMOKE_PID" >&2
  exit 1
fi
wait "$ALIVE_SMOKE_PID" 2>/dev/null || true
ALIVE_SMOKE_PID=""

bash -c 'trap "kill ${child:-} >/dev/null 2>&1 || true; exit 0" TERM; sleep 600 & child=$!; wait "$child"' &
ALIVE_CONTEXT_PID="$!"
bash -c 'trap "kill ${child:-} >/dev/null 2>&1 || true; exit 0" TERM; sleep 600 & child=$!; wait "$child"' &
ALIVE_CONTEXT_HOST_PID="$!"
STOP_CONTEXT_RUN="$TMP_DIR/proofs/stop-context-run"
mkdir -p "$STOP_CONTEXT_RUN/proof-artifacts/context"
cat >"$STOP_CONTEXT_RUN/status.env" <<EOF
state=running
pid=999999
started_at=2026-05-27T00:00:08Z
run_dir=$STOP_CONTEXT_RUN
proof_artifact_dir=$STOP_CONTEXT_RUN/proof-artifacts
launcher=launchd
launch_label=bar.r3d.steadytype.ghostty-detached-proof.test
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf '%s\n' "$ALIVE_CONTEXT_PID" >"$STOP_CONTEXT_RUN/proof-artifacts/context/claude.pid"
{
  printf 'context cleanup detached log\n'
  printf 'Claude Code Ghostty proof owns no-restore host pid(s): %s\n' "$ALIVE_CONTEXT_HOST_PID"
  printf 'root_pid=%s\n' "$ALIVE_CONTEXT_HOST_PID"
} >"$STOP_CONTEXT_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh stop --run-dir "$STOP_CONTEXT_RUN" >"$TMP_DIR/stop-context-status.txt"
require_contains "$TMP_DIR/stop-context-status.txt" "state=failed"
require_contains "$TMP_DIR/stop-context-status.txt" "exit_status=143"
require_contains "$TMP_DIR/stop-context-status.txt" "Detached proof context was stopped by wrapper after runner exit."
require_contains "$STOP_CONTEXT_RUN/proof.log" "Stopped detached Ghostty proof context pid=$ALIVE_CONTEXT_PID after wrapper stop."
require_contains "$STOP_CONTEXT_RUN/proof.log" "Stopped detached Ghostty proof context pid=$ALIVE_CONTEXT_HOST_PID after wrapper stop."
if kill -0 "$ALIVE_CONTEXT_PID" >/dev/null 2>&1; then
  echo "detached Ghostty proof stop should terminate proof context pid $ALIVE_CONTEXT_PID" >&2
  exit 1
fi
if kill -0 "$ALIVE_CONTEXT_HOST_PID" >/dev/null 2>&1; then
  echo "detached Ghostty proof stop should terminate proof context host pid $ALIVE_CONTEXT_HOST_PID" >&2
  exit 1
fi
wait "$ALIVE_CONTEXT_PID" 2>/dev/null || true
wait "$ALIVE_CONTEXT_HOST_PID" 2>/dev/null || true
ALIVE_CONTEXT_PID=""
ALIVE_CONTEXT_HOST_PID=""

PENDING_RUN="$TMP_DIR/proofs/pending-run"
mkdir -p "$PENDING_RUN"
cat >"$PENDING_RUN/status.env" <<EOF
state=starting
pid=
started_at=2026-05-27T00:00:02Z
run_dir=$PENDING_RUN
launcher=terminal
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'pending detached log\n' >"$PENDING_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$PENDING_RUN" >"$TMP_DIR/pending-status.txt"
require_contains "$TMP_DIR/pending-status.txt" "runner_process=pending"

PENDING_DEAD_STARTER_RUN="$TMP_DIR/proofs/pending-dead-starter-run"
mkdir -p "$PENDING_DEAD_STARTER_RUN"
cat >"$PENDING_DEAD_STARTER_RUN/status.env" <<EOF
state=starting
pid=999999
started_at=2026-05-27T00:00:02Z
run_dir=$PENDING_DEAD_STARTER_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'pending dead starter detached log\n' >"$PENDING_DEAD_STARTER_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$PENDING_DEAD_STARTER_RUN" >"$TMP_DIR/pending-dead-starter-status.txt"
require_contains "$TMP_DIR/pending-dead-starter-status.txt" "state=starting"
require_contains "$TMP_DIR/pending-dead-starter-status.txt" "pid=999999"
require_contains "$TMP_DIR/pending-dead-starter-status.txt" "runner_process=pending"
reject_contains "$TMP_DIR/pending-dead-starter-status.txt" "state=failed"

STALE_START_RUN="$TMP_DIR/proofs/stale-start-run"
mkdir -p "$STALE_START_RUN"
cat >"$STALE_START_RUN/status.env" <<EOF
state=starting
pid=
started_at=2026-05-27T00:00:04Z
run_dir=$STALE_START_RUN
launcher=terminal
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'stale start detached log\n' >"$STALE_START_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STARTUP_GRACE_SECONDS=0 \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$STALE_START_RUN" >"$TMP_DIR/stale-start-status.txt"
require_contains "$TMP_DIR/stale-start-status.txt" "state=failed"
require_contains "$TMP_DIR/stale-start-status.txt" "exit_status=1"
require_contains "$TMP_DIR/stale-start-status.txt" "Detached proof runner did not start before startup grace expired."
require_contains "$TMP_DIR/stale-start-status.txt" "runner_process=not-running"

STALE_DEAD_STARTER_RUN="$TMP_DIR/proofs/stale-dead-starter-run"
mkdir -p "$STALE_DEAD_STARTER_RUN"
cat >"$STALE_DEAD_STARTER_RUN/status.env" <<EOF
state=starting
pid=999999
started_at=2026-05-27T00:00:05Z
run_dir=$STALE_DEAD_STARTER_RUN
launcher=nohup
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'stale dead starter detached log\n' >"$STALE_DEAD_STARTER_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STARTUP_GRACE_SECONDS=0 \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$STALE_DEAD_STARTER_RUN" >"$TMP_DIR/stale-dead-starter-status.txt"
require_contains "$TMP_DIR/stale-dead-starter-status.txt" "state=failed"
require_contains "$TMP_DIR/stale-dead-starter-status.txt" "exit_status=1"
require_contains "$TMP_DIR/stale-dead-starter-status.txt" "Detached proof runner and smoke child exited before writing a final status."
require_contains "$TMP_DIR/stale-dead-starter-status.txt" "runner_process=not-running"

DEAD_RUN="$TMP_DIR/proofs/dead-run"
mkdir -p "$DEAD_RUN"
cat >"$DEAD_RUN/status.env" <<EOF
state=running
pid=999999
started_at=2026-05-27T00:00:03Z
run_dir=$DEAD_RUN
launcher=terminal
command=AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh claude-code-ghostty --manual-gate
note=Detached wrapper stores status and child output only; custom proof text is not persisted here.
EOF
printf 'dead detached log\n' >"$DEAD_RUN/proof.log"
AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh status --run-dir "$DEAD_RUN" >"$TMP_DIR/dead-status.txt"
require_contains "$TMP_DIR/dead-status.txt" "state=failed"
require_contains "$TMP_DIR/dead-status.txt" "exit_status=1"
require_contains "$TMP_DIR/dead-status.txt" "Detached proof runner and smoke child exited before writing a final status."
require_contains "$TMP_DIR/dead-status.txt" "runner_process=not-running"

AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh tail >"$TMP_DIR/tail.txt"
require_contains "$TMP_DIR/tail.txt" "fake detached log"

SCRIPT_TEXT="$TMP_DIR/script.txt"
cp script/claude_code_ghostty_detached_proof.sh "$SCRIPT_TEXT"
require_contains "$SCRIPT_TEXT" "open -g -na Terminal"
require_contains "$SCRIPT_TEXT" "create_terminal_launcher_script"
require_contains "$SCRIPT_TEXT" 'nohup /bin/bash "$WORKER_SCRIPT"'
require_contains "$SCRIPT_TEXT" "start_nohup_runner"
require_contains "$SCRIPT_TEXT" "start_new_session=True"
require_contains "$SCRIPT_TEXT" "nohup detached runner pid"
require_contains "$SCRIPT_TEXT" "launchctl bootstrap"
require_contains "$SCRIPT_TEXT" "<key>EnvironmentVariables</key>"
require_contains "$SCRIPT_TEXT" "cleanup_launchd_job_if_terminal"
require_contains "$SCRIPT_TEXT" "run-detached-proof.command"
require_contains "$SCRIPT_TEXT" "run-detached-proof-worker.sh"
require_contains "$SCRIPT_TEXT" "trap '' HUP"
require_contains "$SCRIPT_TEXT" "trap handle_exit EXIT"
require_contains "$SCRIPT_TEXT" "handle_signal TERM 143"
require_contains "$SCRIPT_TEXT" "handle_signal INT 130"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof exited before explicit final status"
require_contains "$SCRIPT_TEXT" "stop_run()"
require_contains "$SCRIPT_TEXT" "all_run_dirs()"
require_contains "$SCRIPT_TEXT" "active_run_dirs()"
require_contains "$SCRIPT_TEXT" "Force start stopping active detached Ghostty proof"
require_contains "$SCRIPT_TEXT" "start --force to stop active run(s) before starting"
require_contains "$SCRIPT_TEXT" "Stop active same-launcher proof runs before starting."
require_contains "$SCRIPT_TEXT" "process_group_for_pid"
require_contains "$SCRIPT_TEXT" "signal_process_or_group"
require_contains "$SCRIPT_TEXT" "proof_artifact_dir_for_run"
require_contains "$SCRIPT_TEXT" "detached_proof_context_pids_for_run"
require_contains "$SCRIPT_TEXT" "terminate_detached_proof_context_processes"
require_contains "$SCRIPT_TEXT" "Stopped detached Ghostty proof context pid="
require_contains "$SCRIPT_TEXT" 'kill "-$signal" "-$pgid"'
require_contains "$SCRIPT_TEXT" 'signal_process_or_group "$smoke_pid" KILL'
require_contains "$SCRIPT_TEXT" 'kill -TERM "-$smoke_pgid"'
require_contains "$SCRIPT_TEXT" 'write_parent_final_status "$run_dir" failed 143'
require_contains "$SCRIPT_TEXT" "Run script/claude_code_ghostty_detached_proof.sh stop to terminate the active proof."
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_ALLOW_CROSS_LAUNCHER_FORCE"
require_contains "$SCRIPT_TEXT" "Refusing to force-stop active"
require_contains "$SCRIPT_TEXT" "Run stop --run-dir explicitly"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STOP_FORCE_GRACE_SECONDS"
require_contains "$SCRIPT_TEXT" "status_started_age_seconds"
require_contains "$SCRIPT_TEXT" "stop_requires_force_guard"
require_contains "$SCRIPT_TEXT" "Refusing to stop active detached Ghostty proof during the early evidence window"
require_contains "$SCRIPT_TEXT" "Use stop --force-stop if this is intentional"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_WAIT_PROGRESS_SECONDS"
require_contains "$SCRIPT_TEXT" "print_wait_progress"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof still"
require_contains "$SCRIPT_TEXT" "export PATH="
require_contains "$SCRIPT_TEXT" "GHOSTTY_DETACHED_PASSTHROUGH_ENV_KEYS=("
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_KEY_CAPTURE_FOCUS_SECONDS"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED"
require_contains "$SCRIPT_TEXT" "write_passthrough_env_exports"
require_contains "$SCRIPT_TEXT" "repair_dead_runner_status_if_needed"
require_contains "$SCRIPT_TEXT" "Detached proof runner and smoke child exited before writing a final status."
require_contains "$SCRIPT_TEXT" "terminate_orphaned_detached_smoke_processes"
require_contains "$SCRIPT_TEXT" "smoke_pid_file_for_run"
require_contains "$SCRIPT_TEXT" "smoke_pid_for_run"
require_contains "$SCRIPT_TEXT" "SMOKE_PID_FILE"
require_contains "$SCRIPT_TEXT" "SMOKE_STARTUP_MARKER_FILE"
require_contains "$SCRIPT_TEXT" "PROOF_ARTIFACT_DIR"
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_ARTIFACT_DIR"
require_contains "$SCRIPT_TEXT" 'proof_artifact_dir=%s'
require_contains "$SCRIPT_TEXT" 'Proof artifacts: $proof_artifact_dir'
require_contains "$SCRIPT_TEXT" "startup_log=%s"
require_contains "$SCRIPT_TEXT" 'SMOKE_PID=""'
require_contains "$SCRIPT_TEXT" 'smoke_pid=%s'
require_contains "$SCRIPT_TEXT" 'printf '\''%s\n'\'' "$SMOKE_PID" >"$SMOKE_PID_FILE"'
require_contains "$SCRIPT_TEXT" 'wait "$SMOKE_PID"'
require_contains "$SCRIPT_TEXT" 'process_is_alive "$smoke_pid"'
require_contains "$SCRIPT_TEXT" "smoke_process=alive"
require_contains "$SCRIPT_TEXT" "smoke_process=not-running"
require_contains "$SCRIPT_TEXT" 'RUNNER_PID="$$"'
require_contains "$SCRIPT_TEXT" 'STATUS_PID="$SMOKE_PID"'
require_contains "$SCRIPT_TEXT" 'runner_pgid="$(ps -o pgid= -p "$RUNNER_PID"'
require_contains "$SCRIPT_TEXT" "Protected proof process groups:"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof launching real_app_smoke as direct child process"
require_contains "$SCRIPT_TEXT" 'run_real_app_smoke "${protected_pgids:-}"'
require_contains "$SCRIPT_TEXT" "exec env"
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_REAL_APP_SMOKE_STARTUP_MARKER_PATH=$SMOKE_STARTUP_MARKER_FILE"'
require_contains "$SCRIPT_TEXT" "write_status passed"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof spawned smoke pid"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof smoke pid"
require_contains "$SCRIPT_TEXT" "Stopped orphaned detached Ghostty smoke process"
require_contains "$SCRIPT_TEXT" "Detached proof smoke child was stopped after runner exit."
require_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_STARTUP_GRACE_SECONDS"
require_contains "$SCRIPT_TEXT" "status_file_age_seconds"
require_contains "$SCRIPT_TEXT" "starting_status_is_within_grace"
require_contains "$SCRIPT_TEXT" "Detached proof runner did not start before startup grace expired."
require_contains "$SCRIPT_TEXT" 'printf '\''export %s=%q\n'\'' "$key" "$value"'
require_contains "$SCRIPT_TEXT" 'printf '\''command=%s\n'\'' "$SMOKE_COMMAND_SUMMARY"'
require_contains "$SCRIPT_TEXT" "nohup detached runner pid"
require_contains "$SCRIPT_TEXT" "run_real_app_smoke"
require_contains "$SCRIPT_TEXT" "Detached Ghostty proof spawned smoke pid"
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=${AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS=${AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS:-4}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION=${AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION:-hid}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS=${AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_COMMANDS:-${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:-0}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS=${AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS:-0.12}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS=${AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS:-45}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE=${AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED:-0}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE:-1}"'
require_contains "$SCRIPT_TEXT" '"AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE=${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE:-1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_COMMAND_OPEN_ENABLED:=0}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_MUTATION_PROBE:=0}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_NATIVE_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_TAB_PRE_INSERT_EXTERNAL_SYSTEM_EVENTS_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_INSERTION_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_POST_FAIL_EXTERNAL_SYSTEM_EVENTS_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE:=1}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_KEYBOARD_EVENT_TAP_LOCATION:=hid}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_PROOF_ONLY_ACCEPT_DRIVER:=0}"'
require_contains "$SCRIPT_TEXT" ': "${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_RESET_ENABLED:=1}"'
require_contains "$SCRIPT_TEXT" "./script/real_app_smoke.sh claude-code-ghostty --manual-gate"
require_contains "$SCRIPT_TEXT" "custom proof text is not persisted here"
reject_contains "$SCRIPT_TEXT" "child_signal_status"
reject_contains "$SCRIPT_TEXT" "Detached Ghostty smoke child shell"
reject_contains "$SCRIPT_TEXT" "set -m"
reject_contains "$SCRIPT_TEXT" "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_TEXTS="
reject_contains "$SCRIPT_TEXT" "Make this setting the feature"

if AUTOCOMPLETE_LAB_GHOSTTY_DETACHED_PROOF_DIR="$TMP_DIR/proofs" \
  script/claude_code_ghostty_detached_proof.sh unknown >/dev/null 2>&1; then
  echo "detached Ghostty proof should reject unknown modes" >&2
  exit 1
fi

echo "Detached Ghostty proof self-test passed."
