#!/usr/bin/env bash
# Screen Memory duty-cycle / power probe (Phase 1b, docs/plans/screen-memory.md).
#
# Runs a scripted capture-ON vs capture-OFF comparison against a DEV build of
# Tilde (dist/Tilde.app, built by script/build_and_run.sh) and reports the
# plan's two budget assertions:
#   - battery: < 2% additional battery/day from Screen Memory capture
#   - OCR:     p95 capture+OCR duration < 250ms per capture on M1
#
# It never touches /Applications or an already-running production Tilde:
#   - The dev app is launched in the existing --release-proof isolation lane
#     (dedicated llama-server port 17873; production mode's duplicate-instance
#     guard would otherwise make a second production launch either collide
#     with, or self-terminate next to, a real running Tilde).
#   - Screen Memory's own toggle (ScreenMemoryEnabled) is read from the SAME
#     UserDefaults domain a production Tilde would use, so this script saves
#     whatever value was already there and restores it on exit — capture
#     itself still requires TILDE_SCREEN_MEMORY_DEV=1 in the specific
#     process's own environment (never inherited by another Tilde launched
#     without it), so a stray "on" value cannot make a real daily-driver
#     instance start capturing. Even so, flipping the shared toggle at all
#     while a real Tilde is running would change what its Settings UI shows
#     mid-session, so this script refuses to start if any non-release-proof
#     Tilde process is found running (see production_tilde_pids() below).
#     That guard cannot help against an untrapped `kill -9` on this script
#     itself (no shell trap can) — that residual risk is unchanged from
#     before this script existed and applies to any tool that mutates a
#     persisted default and restores it on exit.
#
# Two things this script cannot get around, only detect and report:
#   - powermetrics requires root. Run this from an interactive terminal so
#     `sudo` can prompt for a password (or add a NOPASSWD sudoers rule for the
#     exact invocation below); it will not work unattended.
#   - The dev build needs its own Screen Recording (TCC) grant, separate from
#     any grant already held by an installed Tilde. This script triggers the
#     system consent dialog on first run; if it is not answered in time it
#     reports BLOCKED with exactly what to click.
#
# Usage: script/capture_power_probe.sh [--duration SECONDS] [--interval-ms MS]
#        script/capture_power_probe.sh --selftest
#
# Nothing this script prints or writes is raw screen text — only counts,
# durations, and power/battery numbers, matching the covenant's "no raw
# screen text in logs, diagnostics, or any report."
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP="$ROOT_DIR/dist/Tilde.app"
BINARY="$APP/Contents/MacOS/Tilde"
RELEASE_PROOF_PORT=17873
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/Tilde/diagnostics.log}"
# NOT the app's own bundle id: TildeSettings reads/writes ScreenMemoryEnabled
# through the app-group suite shared with the keyboard extension
# (PersonalHistorySettingsContract.keyboardSuiteName in TildeCore),
# so that has to be the domain this script mutates too.
DEFAULTS_DOMAIN="bar.r3d.inputmethod.InlineGhost"
DEFAULTS_KEY="ScreenMemoryEnabled"

DURATION_SECONDS=600
SAMPLE_INTERVAL_MS=5000
PERMISSION_WAIT_SECONDS=45
SELFTEST=0

# Budgets from docs/plans/screen-memory.md Phase 1b.
BUDGET_BATTERY_PCT_PER_DAY="2.0"
BUDGET_OCR_P95_MS="250"

WORK_DIR=""
APP_PID=""
PM_PID=""
DRIVER_PID=""
DEFAULTS_HELD=0
ORIGINAL_DEFAULT_SET=0
ORIGINAL_DEFAULT_VALUE=""

usage() {
  awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

fail() {
  echo "capture_power_probe: $1" >&2
  exit 1
}

blocked() {
  echo ""
  echo "BLOCKED: $1"
  echo ""
  echo "$2"
  cleanup
  trap - EXIT INT TERM
  exit 3
}

# Ownership-safe stop of this script's own dev instance AND its exact
# llama-server helper on the release-proof port — script/restart_app.sh
# already implements the port+birth+file-identity matching this needs
# (release_proof_helper_identities / stop_captured_helpers) so a bare `kill
# $APP_PID` here can't orphan the helper child the way it used to.
stop_dev_instance() {
  bash "$ROOT_DIR/script/restart_app.sh" --release-proof --cleanup >/dev/null 2>&1 || true
}

cleanup() {
  if [[ -n "$DRIVER_PID" ]] && kill -0 "$DRIVER_PID" >/dev/null 2>&1; then
    kill "$DRIVER_PID" >/dev/null 2>&1 || true
    wait "$DRIVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$PM_PID" ]] && kill -0 "$PM_PID" >/dev/null 2>&1; then
    sudo -n kill "$PM_PID" >/dev/null 2>&1 || kill "$PM_PID" >/dev/null 2>&1 || true
    wait "$PM_PID" >/dev/null 2>&1 || true
  fi
  # Gated on DEFAULTS_HELD (set right before the arms begin) so a trivial
  # exit — --help, --selftest, an early preflight `fail` — doesn't spawn
  # restart_app.sh's lsof/ps cleanup query for a dev instance that was
  # never launched.
  if [[ "$DEFAULTS_HELD" == "1" ]]; then
    stop_dev_instance
  fi
  APP_PID=""
  if [[ "$DEFAULTS_HELD" == "1" ]]; then
    if [[ "$ORIGINAL_DEFAULT_SET" == "1" ]]; then
      defaults write "$DEFAULTS_DOMAIN" "$DEFAULTS_KEY" -bool "$ORIGINAL_DEFAULT_VALUE" >/dev/null 2>&1 || true
    else
      defaults delete "$DEFAULTS_DOMAIN" "$DEFAULTS_KEY" >/dev/null 2>&1 || true
    fi
    DEFAULTS_HELD=0
  fi
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Pure-ish helpers (covered by --selftest without touching hardware or sudo).
# ---------------------------------------------------------------------------

# mWh from the two ioreg fields every Apple Silicon MacBook battery reports.
# Pure text-in/text-out so --selftest can exercise it against a fixture
# instead of requiring a real AppleSmartBattery reading (this Mac's own
# battery, or a battery at all — battery-less CI runners and desktop Macs
# have neither, and proof.sh fast calls --selftest unconditionally).
parse_battery_capacity_mwh() {
  local ioreg_output="$1" max_capacity_mah voltage_mv
  max_capacity_mah="$(printf '%s\n' "$ioreg_output" | awk -F'= ' '/"AppleRawMaxCapacity" =/ { print $2; exit }')"
  voltage_mv="$(printf '%s\n' "$ioreg_output" | awk -F'= ' '/"Voltage" =/ { print $2; exit }')"
  [[ "$max_capacity_mah" =~ ^[0-9]+$ && "$voltage_mv" =~ ^[0-9]+$ ]] || return 1
  awk -v mah="$max_capacity_mah" -v mv="$voltage_mv" 'BEGIN { printf "%.2f", (mah * mv) / 1000.0 }'
}

battery_capacity_mwh() {
  local ioreg_output
  ioreg_output="$(ioreg -rc AppleSmartBattery 2>/dev/null)" || return 1
  parse_battery_capacity_mwh "$ioreg_output"
}

# Mean of "Combined Power (CPU + GPU + ANE): NNNN mW"-shaped lines (wording
# has drifted across macOS versions, hence the loose match); falls back to
# summing CPU/GPU/ANE power lines separately if no combined line exists.
mean_combined_power_mw() {
  local pm_log="$1" combined_mean
  combined_mean="$(awk '
    /Combined Power.*mW/ {
      for (i = 1; i <= NF; i++) if ($i == "mW") { sum += $(i - 1); n++ }
    }
    END { if (n > 0) printf "%.2f", sum / n }
  ' "$pm_log" 2>/dev/null)"
  if [[ -n "$combined_mean" ]]; then
    printf '%s' "$combined_mean"
    return 0
  fi

  awk '
    /^CPU Power:/ { for (i=1;i<=NF;i++) if ($i=="mW") cpu[++cn]=$(i-1) }
    /^GPU Power:/ { for (i=1;i<=NF;i++) if ($i=="mW") gpu[++gn]=$(i-1) }
    /^ANE Power:/ { for (i=1;i<=NF;i++) if ($i=="mW") ane[++an]=$(i-1) }
    END {
      n = cn; if (gn < n) n = gn; if (an < n) n = an
      if (n == 0) exit 1
      for (i=1;i<=n;i++) sum += cpu[i] + gpu[i] + ane[i]
      printf "%.2f", sum / n
    }
  ' "$pm_log"
}

# p95 of a newline-separated list of non-negative integers, nearest-rank.
p95_of() {
  local values="$1" count index
  count="$(printf '%s\n' "$values" | grep -c '^[0-9][0-9]*$')" || count=0
  [[ "$count" -gt 0 ]] || { echo ""; return 0; }
  index=$(( (count * 95 + 99) / 100 ))
  [[ "$index" -ge 1 ]] || index=1
  [[ "$index" -le "$count" ]] || index="$count"
  printf '%s\n' "$values" | grep '^[0-9][0-9]*$' | sort -n | sed -n "${index}p"
}

# Events between two 1-based line numbers of the diagnostics log, filtered to
# a given event name; extracts duration_ms= when present. Never touches
# anything but counts/durations already written by DiagnosticsLog (which
# itself never carries raw screen text).
extract_duration_ms_values() {
  local log="$1" start_line="$2" event_name="$3"
  [[ -f "$log" ]] || return 0
  tail -n "+$((start_line + 1))" "$log" \
    | grep -E " ${event_name}( |$)" \
    | sed -nE 's/.*duration_ms=([0-9]+).*/\1/p'
}

count_events() {
  local log="$1" start_line="$2" event_name="$3"
  [[ -f "$log" ]] || { echo 0; return 0; }
  tail -n "+$((start_line + 1))" "$log" | grep -cE " ${event_name}( |$)" || true
}

line_count() {
  [[ -f "$1" ]] && wc -l <"$1" | tr -d ' ' || echo 0
}

# Pure matcher over `ps ax -o pid=,command=`-shaped text: any Tilde.app
# process that is NOT this script's own --release-proof launch. Kept
# separate from the real `ps` call so --selftest can exercise the matching
# logic against a fixture without depending on what happens to be running.
production_tilde_pids_from_ps_output() {
  local ps_text="$1"
  printf '%s\n' "$ps_text" | awk '
    $0 ~ /\/Tilde\.app\/Contents\/MacOS\/Tilde([[:space:]]|$)/ && $0 !~ /--release-proof/ { print $1 }
  '
}

production_tilde_pids() {
  production_tilde_pids_from_ps_output "$(ps ax -o pid=,command= 2>/dev/null)"
}

# Both successful and failed capture attempts spend duty-cycle time and both
# carry duration_ms (ScreenCaptureService.swift's screen-capture-failed
# comment: "count toward the duty cycle the power probe measures") — the
# probe's stats must include failed attempts too, not just completed ones.
DUTY_CYCLE_EVENT_PATTERN="screen-capture-(completed|failed)"

if [[ "${1:-}" == "--selftest" ]]; then
  SELFTEST=1
fi

if [[ "$SELFTEST" == "1" ]]; then
  echo "capture_power_probe --selftest"

  # Fixture text shaped like `ioreg -rc AppleSmartBattery` output — no real
  # battery required, so this holds on battery-less CI runners and desktops.
  ioreg_fixture='    | "AppleRawMaxCapacity" = 4000
    | "Voltage" = 11750'
  cap="$(parse_battery_capacity_mwh "$ioreg_fixture")" || fail "selftest: parse_battery_capacity_mwh failed on fixture"
  [[ "$cap" == "47000.00" ]] || fail "selftest: parse_battery_capacity_mwh expected 47000.00 got '$cap'"
  echo "  parse_battery_capacity_mwh() -> ${cap} mWh OK (fixture: 4000mAh @ 11750mV)"

  if parse_battery_capacity_mwh "no matching fields here" >/dev/null 2>&1; then
    fail "selftest: parse_battery_capacity_mwh should fail on input with no battery fields"
  fi
  echo "  parse_battery_capacity_mwh() on malformed input -> failure OK"

  tmp_pm="$(mktemp -t capture_power_probe_selftest_pm)"
  cat >"$tmp_pm" <<'EOF'
**** Processor usage ****
Combined Power (CPU + GPU + ANE): 1200 mW
**** Processor usage ****
Combined Power (CPU + GPU + ANE): 1400 mW
EOF
  power="$(mean_combined_power_mw "$tmp_pm")"
  [[ "$power" == "1300.00" ]] || fail "selftest: mean_combined_power_mw expected 1300.00 got '$power'"
  rm -f "$tmp_pm"
  echo "  mean_combined_power_mw() -> $power mW OK (fixture: 1200, 1400)"

  tmp_pm2="$(mktemp -t capture_power_probe_selftest_pm2)"
  cat >"$tmp_pm2" <<'EOF'
CPU Power: 500 mW
GPU Power: 100 mW
ANE Power: 0 mW
CPU Power: 700 mW
GPU Power: 100 mW
ANE Power: 0 mW
EOF
  power2="$(mean_combined_power_mw "$tmp_pm2")"
  [[ "$power2" == "700.00" ]] || fail "selftest: fallback mean expected 700.00 got '$power2'"
  rm -f "$tmp_pm2"
  echo "  mean_combined_power_mw() fallback -> $power2 mW OK (fixture: (500+100+0),(700+100+0))"

  p95_result="$(p95_of "$(printf '10\n20\n30\n40\n50\n60\n70\n80\n90\n100\n')")"
  [[ "$p95_result" == "100" ]] || fail "selftest: p95 of 10..100 expected 100 got '$p95_result'"
  echo "  p95_of() -> $p95_result OK (fixture: 10..100 step 10)"

  empty_p95="$(p95_of "")"
  [[ -z "$empty_p95" ]] || fail "selftest: p95 of empty input should be empty, got '$empty_p95'"
  echo "  p95_of() on empty input -> '' OK"

  tmp_log="$(mktemp -t capture_power_probe_selftest_log)"
  {
    echo "2026-01-01T00:00:00Z screen-capture-completed blocks=3 duration_ms=120"
    echo "2026-01-01T00:00:05Z screen-capture-completed blocks=1 duration_ms=340"
    echo "2026-01-01T00:00:10Z screen-capture-skipped reason=cadence"
  } >"$tmp_log"
  durations="$(extract_duration_ms_values "$tmp_log" 0 "screen-capture-completed")"
  [[ "$durations" == $'120\n340' ]] || fail "selftest: duration extraction mismatch: '$durations'"
  completed="$(count_events "$tmp_log" 0 "screen-capture-completed")"
  [[ "$completed" == "2" ]] || fail "selftest: completed count expected 2 got '$completed'"
  rm -f "$tmp_log"
  echo "  extract_duration_ms_values()/count_events() OK against a synthetic log"

  # Failed attempts carry duration_ms too and must count toward duty cycle
  # (ScreenCaptureService.swift's screen-capture-failed comment says so
  # explicitly); the probe's own event pattern must not exclude them.
  tmp_log2="$(mktemp -t capture_power_probe_selftest_log2)"
  {
    echo "2026-01-01T00:00:00Z screen-capture-completed blocks=3 duration_ms=120"
    echo "2026-01-01T00:00:05Z screen-capture-failed duration_ms=980"
    echo "2026-01-01T00:00:10Z screen-capture-skipped reason=cadence"
  } >"$tmp_log2"
  duty_durations="$(extract_duration_ms_values "$tmp_log2" 0 "$DUTY_CYCLE_EVENT_PATTERN")"
  [[ "$duty_durations" == $'120\n980' ]] || fail "selftest: duty-cycle duration extraction mismatch: '$duty_durations'"
  duty_count="$(count_events "$tmp_log2" 0 "$DUTY_CYCLE_EVENT_PATTERN")"
  [[ "$duty_count" == "2" ]] || fail "selftest: duty-cycle count expected 2 got '$duty_count'"
  rm -f "$tmp_log2"
  echo "  DUTY_CYCLE_EVENT_PATTERN OK: completed + failed both counted"

  # production_tilde_pids_from_ps_output: matches a real (non-release-proof)
  # Tilde process, ignores a --release-proof one and unrelated processes.
  ps_fixture="  111 /Applications/Tilde.app/Contents/MacOS/Tilde
  222 /Users/dev/repo/dist/Tilde.app/Contents/MacOS/Tilde --release-proof
  333 /usr/bin/some-other-process"
  prod_pids="$(production_tilde_pids_from_ps_output "$ps_fixture")"
  [[ "$prod_pids" == "111" ]] || fail "selftest: production_tilde_pids_from_ps_output expected '111' got '$prod_pids'"
  echo "  production_tilde_pids_from_ps_output() OK: matches production, skips --release-proof and unrelated"

  echo ""
  echo "selftest OK: measurement math holds; no sudo/TCC/app launch performed."
  exit 0
fi

while (($#)); do
  case "$1" in
    --duration)
      [[ $# -ge 2 ]] || { echo "missing value for --duration" >&2; exit 2; }
      DURATION_SECONDS="$2"
      shift
      ;;
    --interval-ms)
      [[ $# -ge 2 ]] || { echo "missing value for --interval-ms" >&2; exit 2; }
      SAMPLE_INTERVAL_MS="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "capture_power_probe: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done
[[ "$DURATION_SECONDS" =~ ^[0-9]+$ && "$DURATION_SECONDS" -ge 5 ]] || fail "--duration must be an integer >= 5"
[[ "$SAMPLE_INTERVAL_MS" =~ ^[0-9]+$ && "$SAMPLE_INTERVAL_MS" -ge 100 ]] || fail "--interval-ms must be an integer >= 100"

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

[[ -x "$BINARY" ]] || fail "dev app not built; run script/build_and_run.sh first (never point this at /Applications/Tilde.app)"

if pgrep -f "^${BINARY}( |$)" >/dev/null 2>&1; then
  fail "a dev Tilde from this exact dist build is already running; stop it before running this probe (pgrep -f '${BINARY}')"
fi

command -v powermetrics >/dev/null 2>&1 || fail "powermetrics not found (unexpected on macOS)"

# `-v` (not `-n true`) so sudo can actually prompt when this is run
# interactively, matching the remediation text below; `-n true` can never
# prompt, so it would report BLOCKED even in a perfectly interactive
# terminal with no credential cached yet.
if ! sudo -v 2>/dev/null; then
  blocked \
    "powermetrics requires root and sudo could not obtain or refresh credentials in this shell." \
    "Run this script from an interactive terminal so sudo can prompt for your password, or add a NOPASSWD sudoers rule scoped to:
  $(command -v powermetrics) --samplers cpu_power -i <n> -n <n>
Nothing else in this script needs elevated privileges."
fi

# This script mutates the shared ScreenMemoryEnabled default a real running
# Tilde also reads (see file header); refuse to run alongside one rather
# than risk a real instance observing a transient toggle flip mid-session.
running_production_pids="$(production_tilde_pids)"
if [[ -n "$running_production_pids" ]]; then
  fail "a real (non-release-proof) Tilde is running (pid $running_production_pids); quit it before running this probe — this script writes to the shared ScreenMemoryEnabled default that instance also reads"
fi

battery_mwh="$(battery_capacity_mwh)" || fail "could not read battery capacity via ioreg -rc AppleSmartBattery (desktop Mac with no battery?)"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tilde-capture-power-probe.XXXXXX")"

# Save/restore the shared ScreenMemoryEnabled default so this script never
# leaves a real Tilde's persisted toggle state different from how it found
# it (see the file header: the dev-flag pairing keeps this safe regardless,
# but restoring is the considerate thing to do).
if defaults_value="$(defaults read "$DEFAULTS_DOMAIN" "$DEFAULTS_KEY" 2>/dev/null)"; then
  ORIGINAL_DEFAULT_SET=1
  ORIGINAL_DEFAULT_VALUE="$defaults_value"
fi
DEFAULTS_HELD=1

# ---------------------------------------------------------------------------
# One arm: launch the isolated dev instance, sample power, drive triggers
# (capture-on only), collect diagnostics-derived duty-cycle numbers.
# ---------------------------------------------------------------------------

# Alternates two disposable, always-present apps to fire the window-changed
# trigger roughly every 6s (just over the 5s cadence cap, so most nudges land
# a fresh capture rather than being cadence-skipped). This never types
# anything and never touches document content — it only changes which app is
# frontmost.
drive_window_changes() {
  local deadline=$((SECONDS + DURATION_SECONDS))
  while ((SECONDS < deadline)); do
    osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
    sleep 3
    osascript -e 'tell application "Calculator" to activate' >/dev/null 2>&1 || true
    sleep 3
  done
}

# run_arm is called directly (never through `$(...)`) precisely so that a
# `fail`/`blocked` call inside it terminates THIS process, not a throwaway
# subshell whose exit code nothing downstream checked — that swallowed
# arm failures and could print zero/negative metrics as a false PASS.
# Results go to out_file instead of stdout for the same reason: no command
# substitution boundary for a failure to hide behind.
run_arm() {
  local label="$1" capture_on="$2" out_file="$3"
  local app_log="$WORK_DIR/${label}.app.log" pm_log="$WORK_DIR/${label}.powermetrics.log"
  local start_line health_deadline sample_count

  defaults write "$DEFAULTS_DOMAIN" "$DEFAULTS_KEY" -bool "$capture_on" >/dev/null 2>&1

  start_line="$(line_count "$LOG_PATH")"

  TILDE_SCREEN_MEMORY_DEV=1 "$BINARY" --release-proof >"$app_log" 2>&1 &
  APP_PID="$!"

  health_deadline=$((SECONDS + 30))
  until curl -sf "http://127.0.0.1:${RELEASE_PROOF_PORT}/health" >/dev/null 2>&1; do
    kill -0 "$APP_PID" >/dev/null 2>&1 || fail "$label: dev app exited before becoming healthy; see $app_log"
    ((SECONDS < health_deadline)) || fail "$label: dev app never became healthy on port $RELEASE_PROOF_PORT; see $app_log"
    sleep 0.5
  done

  if [[ "$capture_on" == "true" ]]; then
    # Confirm the TCC gate is actually open before spending a full sampling
    # window on a run that can never capture anything.
    local permission_deadline=$((SECONDS + PERMISSION_WAIT_SECONDS))
    local saw_permission_skip=0 saw_completed=0
    while ((SECONDS < permission_deadline)); do
      if grep -qE " screen-capture-completed( |$)" <(tail -n "+$((start_line + 1))" "$LOG_PATH" 2>/dev/null); then
        saw_completed=1
        break
      fi
      if grep -qE "screen-capture-skipped reason=permission" <(tail -n "+$((start_line + 1))" "$LOG_PATH" 2>/dev/null); then
        saw_permission_skip=1
      fi
      osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
      sleep 1
    done
    if [[ "$saw_completed" == "0" && "$saw_permission_skip" == "1" ]]; then
      blocked \
        "dist/Tilde.app (this dev build, launched with TILDE_SCREEN_MEMORY_DEV=1) does not have Screen Recording permission." \
        "This binary's code signature is distinct from any already-installed Tilde, so it needs its own grant even if another Tilde already has one. Launching it just triggered (or should have triggered) the system 'Tilde Would Like to Access the Screen Recording' consent dialog.
Exact click needed:
  1. If the system dialog is on screen right now: click Allow.
  2. Otherwise open System Settings > Privacy & Security > Screen Recording, find the entry for this build ($BINARY), and turn its toggle on. If it is not listed yet, the dialog may have been suppressed — quit this probe, run it again from an interactive session with the screen unlocked, and answer the dialog when it appears.
  3. macOS requires a full quit of the app after a permission change before the grant takes effect for a running process — this script already restarts a fresh instance per run, so simply re-run script/capture_power_probe.sh after granting.
(saw_permission_skip=$saw_permission_skip in the diagnostics log during the wait, confirming the app tried and was told no.)"
    elif [[ "$saw_completed" == "0" ]]; then
      # Zero completions but the log never even logged a permission skip —
      # a real TCC denial is only one of several possible causes (the
      # window-change triggers may not have fired, the app may have hit a
      # different failure), so don't misreport this as the TCC case above.
      fail "$label: no screen-capture-completed events observed within ${PERMISSION_WAIT_SECONDS}s, and no screen-capture-skipped reason=permission was logged either (saw_permission_skip=0) — this isn't the TCC-denial case; check $app_log and $LOG_PATH for what actually happened"
    fi
  fi

  sample_count=$(( (DURATION_SECONDS * 1000 + SAMPLE_INTERVAL_MS - 1) / SAMPLE_INTERVAL_MS ))
  sudo powermetrics --samplers cpu_power -i "$SAMPLE_INTERVAL_MS" -n "$sample_count" >"$pm_log" 2>&1 &
  PM_PID="$!"

  # Both arms get the identical Finder/Calculator window-change workload —
  # capture-on-ness is the ONLY difference between the two arms now, so the
  # measured power delta is attributable to Screen Memory capture itself
  # rather than including osascript/app-launch/WindowServer work the OFF
  # arm never did.
  drive_window_changes &
  DRIVER_PID="$!"

  wait "$PM_PID" 2>/dev/null || true
  PM_PID=""

  if [[ -n "$DRIVER_PID" ]]; then
    kill "$DRIVER_PID" >/dev/null 2>&1 || true
    wait "$DRIVER_PID" >/dev/null 2>&1 || true
    DRIVER_PID=""
  fi

  stop_dev_instance
  APP_PID=""

  local mean_power completed_count duration_values p95_ms
  mean_power="$(mean_combined_power_mw "$pm_log")" || fail "$label: could not parse powermetrics output; see $pm_log"
  completed_count="$(count_events "$LOG_PATH" "$start_line" "$DUTY_CYCLE_EVENT_PATTERN")"
  duration_values="$(extract_duration_ms_values "$LOG_PATH" "$start_line" "$DUTY_CYCLE_EVENT_PATTERN")"
  p95_ms="$(p95_of "$duration_values")"

  printf '%s:%s:%s:%s\n' "$label" "$mean_power" "$completed_count" "$p95_ms" >"$out_file"
}

echo "Screen Memory power probe — duration=${DURATION_SECONDS}s per arm, sample interval=${SAMPLE_INTERVAL_MS}ms"
echo "Battery capacity (this Mac): ${battery_mwh} mWh"
echo ""

echo "Arm 1/2: capture OFF (baseline)"
off_out="$WORK_DIR/off.result"
run_arm "off" "false" "$off_out"
off_result="$(<"$off_out")"
off_power="$(cut -d: -f2 <<<"$off_result")"

echo "Arm 2/2: capture ON"
on_out="$WORK_DIR/on.result"
run_arm "on" "true" "$on_out"
on_result="$(<"$on_out")"
on_power="$(cut -d: -f2 <<<"$on_result")"
on_events="$(cut -d: -f3 <<<"$on_result")"
on_p95="$(cut -d: -f4 <<<"$on_result")"

events_per_hour="$(awk -v n="$on_events" -v d="$DURATION_SECONDS" 'BEGIN { printf "%.1f", n * 3600.0 / d }')"
delta_mw="$(awk -v on="$on_power" -v off="$off_power" 'BEGIN { printf "%.2f", on - off }')"
battery_pct_per_day="$(awk -v delta="$delta_mw" -v cap="$battery_mwh" 'BEGIN { printf "%.3f", (delta * 24.0 / cap) * 100.0 }')"

echo ""
echo "==== Results ===="
echo "Capture OFF mean power: ${off_power} mW"
echo "Capture ON  mean power: ${on_power} mW"
echo "Delta:                  ${delta_mw} mW"
echo "Estimated extra battery/day from Screen Memory: ${battery_pct_per_day}%"
echo "Capture attempts observed (ON arm, completed+failed): ${on_events} (${events_per_hour}/hour)"
if [[ -n "$on_p95" ]]; then
  echo "Capture+OCR duration p95 (ON arm, completed+failed): ${on_p95}ms"
else
  echo "Capture+OCR duration p95 (ON arm): no capture attempts to measure"
fi
echo ""

battery_pass=1
awk -v v="$battery_pct_per_day" -v budget="$BUDGET_BATTERY_PCT_PER_DAY" 'BEGIN { exit !(v+0 < budget+0) }' || battery_pass=0
if [[ "$battery_pass" == "1" ]]; then
  echo "PASS: battery ${battery_pct_per_day}% < ${BUDGET_BATTERY_PCT_PER_DAY}%/day budget"
else
  echo "FAIL: battery ${battery_pct_per_day}% >= ${BUDGET_BATTERY_PCT_PER_DAY}%/day budget"
fi

if [[ -n "$on_p95" ]]; then
  ocr_pass=1
  awk -v v="$on_p95" -v budget="$BUDGET_OCR_P95_MS" 'BEGIN { exit !(v+0 < budget+0) }' || ocr_pass=0
  if [[ "$ocr_pass" == "1" ]]; then
    echo "PASS: OCR p95 ${on_p95}ms < ${BUDGET_OCR_P95_MS}ms budget"
  else
    echo "FAIL: OCR p95 ${on_p95}ms >= ${BUDGET_OCR_P95_MS}ms budget"
  fi
else
  echo "SKIP: OCR p95 budget — no capture attempts in the ON arm"
fi
