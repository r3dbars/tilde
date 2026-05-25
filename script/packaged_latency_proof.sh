#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="claude-model-latency"
APP_BUNDLE="${AUTOCOMPLETE_LAB_PACKAGED_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
DRY_RUN=0
RUN_SMOKE=1
OPEN_ACCESSIBILITY_SETTINGS=0
RELAUNCH="${AUTOCOMPLETE_LAB_PACKAGED_LATENCY_RELAUNCH:-1}"

usage() {
  cat <<'EOF'
Usage: script/packaged_latency_proof.sh [claude-model-latency] [--dry-run] [--skip-smoke] [--app-bundle <path>] [--open-accessibility-settings]

Launch the notarized packaged SteadyType app with the proof-mode environment
needed for a strict model-latency run, then run the guarded skip-build smoke
and latency selector against that exact app binary.

This script cannot grant macOS Accessibility. If the packaged app reports
accessibility-permission-lost, open System Settings > Privacy & Security >
Accessibility, enable SteadyType for bundle ID bar.r3d.steadytype, and rerun.
EOF
}

while (($#)); do
  case "$1" in
    claude-model-latency)
      TARGET="$1"
      shift
      ;;
    --app-bundle)
      if (($# < 2)); then
        echo "--app-bundle requires a path" >&2
        exit 2
      fi
      APP_BUNDLE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-smoke)
      RUN_SMOKE=0
      shift
      ;;
    --open-accessibility-settings)
      OPEN_ACCESSIBILITY_SETTINGS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown packaged latency proof option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$TARGET" != "claude-model-latency" ]]; then
  echo "unsupported packaged latency target: $TARGET" >&2
  exit 2
fi

canonical_bundle_path() {
  local path="$1"
  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ ! -d "$dir" ]]; then
    if [[ "$path" == /* ]]; then
      printf '%s\n' "$path"
    else
      printf '%s/%s\n' "$ROOT_DIR" "$path"
    fi
    return 0
  fi
  dir="$(cd "$dir" && pwd)"
  printf '%s/%s\n' "$dir" "$base"
}

APP_BUNDLE="$(canonical_bundle_path "$APP_BUNDLE")"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
LOG_PATH="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
TRACE_PATH="${AUTOCOMPLETE_LAB_TRACE_LOG:-${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}}"
PROOF_BUNDLE="com.anthropic.claudefordesktop"
SETTINGS_URL="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

if [[ "$DRY_RUN" != "1" && ! -x "$APP_BINARY" ]]; then
  echo "missing packaged SteadyType binary: $APP_BINARY" >&2
  echo "Run ./script/package_release.sh archive first." >&2
  exit 1
fi

APP_SHA="<missing>"
if [[ -x "$APP_BINARY" ]]; then
  APP_SHA="$(shasum -a 256 "$APP_BINARY" | awk '{print $1}')"
fi

run_or_print() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

packaged_pids() {
  pgrep -f "$APP_BINARY" 2>/dev/null || true
}

relaunch_packaged_app() {
  if [[ "$RELAUNCH" =~ ^(1|true|yes|on)$ ]]; then
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      run_or_print kill "$pid"
    done < <(packaged_pids)
    if [[ "$DRY_RUN" != "1" ]]; then
      sleep 1
    fi
  fi

  run_or_print launchctl setenv AUTOCOMPLETE_LAB_SCREENSHOT_TRACE 1
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION 1
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION 1
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_PROOF_SCENARIO "$TARGET"
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING 1
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS "$PROOF_BUNDLE"
  run_or_print launchctl setenv AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS "$PROOF_BUNDLE"
  run_or_print /usr/bin/open -n -F "$APP_BUNDLE"
}

wait_for_packaged_app() {
  local attempts=30
  local pids=""
  for _ in $(seq 1 "$attempts"); do
    pids="$(packaged_pids | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    if [[ -n "$pids" ]]; then
      echo "Packaged SteadyType running: pid(s) $pids"
      return 0
    fi
    sleep 0.5
  done

  echo "packaged SteadyType did not launch from: $APP_BINARY" >&2
  exit 1
}

print_accessibility_recovery() {
  cat >&2 <<EOF

Packaged latency proof blocked by macOS Accessibility.
Bundle ID: bar.r3d.steadytype
App: $APP_BUNDLE

Open System Settings > Privacy & Security > Accessibility and enable SteadyType.
Then rerun:

AUTOCOMPLETE_LAB_PACKAGED_LATENCY_RELAUNCH=1 ./script/packaged_latency_proof.sh $TARGET

This script cannot grant Accessibility or edit TCC directly.
EOF
  if [[ "$OPEN_ACCESSIBILITY_SETTINGS" == "1" ]]; then
    run_or_print /usr/bin/open "$SETTINGS_URL"
  else
    echo "Optional: rerun with --open-accessibility-settings to open $SETTINGS_URL" >&2
  fi
}

run_smoke() {
  local output
  set +e
  output="$(
    AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 \
    AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 \
    AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 \
      ./script/real_app_smoke.sh "$TARGET" --manual-gate --skip-build 2>&1
  )"
  local status=$?
  set -e
  printf '%s\n' "$output"

  if ((status != 0)); then
    if grep -Fq "accessibility-permission-lost" <<<"$output"; then
      print_accessibility_recovery
    fi
    return "$status"
  fi
}

run_selector() {
  run_or_print ./script/select_latency_window.py \
    --diagnostics-log "$LOG_PATH" \
    --trace-log "$TRACE_PATH" \
    --expected-asset Qwen3.5-4B-4bit \
    --min-first-visible-samples 5 \
    --min-model-samples 5 \
    --required-proof-app "$PROOF_BUNDLE" \
    --required-proof-scenario "$TARGET" \
    --required-trace-app "$PROOF_BUNDLE" \
    --required-request-mode wordCompletion \
    --app-binary "$APP_BINARY" \
    --expected-executable-sha256 "$APP_SHA" \
    --require-model-backed-visible \
    --forbid-fast-word-visible
}

echo "Packaged latency target: $TARGET"
echo "Packaged app: $APP_BUNDLE"
echo "Packaged executable SHA-256: $APP_SHA"
echo "Proof app: $PROOF_BUNDLE"
echo "Diagnostics log: $LOG_PATH"
echo "Trace log: $TRACE_PATH"

relaunch_packaged_app
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run only. Smoke command would set AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 and use --skip-build."
  echo "Accessibility recovery opens: $SETTINGS_URL"
  run_selector
  exit 0
fi

wait_for_packaged_app

if [[ "$RUN_SMOKE" == "1" ]]; then
  run_smoke
else
  echo "Skipping smoke. Next command:"
  echo "AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 AUTOCOMPLETE_LAB_REAL_APP_SKIP_BUILD=1 AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 ./script/real_app_smoke.sh $TARGET --manual-gate --skip-build"
fi

run_selector
