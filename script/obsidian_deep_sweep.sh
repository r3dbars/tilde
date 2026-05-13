#!/usr/bin/env bash
set -euo pipefail

ITERATIONS="${AUTOCOMPLETE_LAB_OBSIDIAN_DEEP_SWEEP_ITERATIONS:-1}"
REPORT_PATH="${AUTOCOMPLETE_LAB_OBSIDIAN_DEEP_SWEEP_REPORT:-docs/product/obsidian-deep-sweep-latest.md}"
SKIP_BUILD_AFTER_FIRST="${AUTOCOMPLETE_LAB_OBSIDIAN_DEEP_SWEEP_SKIP_BUILD_AFTER_FIRST:-0}"

LANES=(
  obsidian
  obsidian-theme
  obsidian-long-note
  obsidian-font-zoom
  obsidian-markdown-bold
  obsidian-markdown-list
  obsidian-multiline
  obsidian-run-on
  obsidian-pane
)

usage() {
  cat <<'EOF'
Usage: script/obsidian_deep_sweep.sh [--iterations N] [--lanes lane1,lane2] [--skip-build-after-first|--no-skip-build-after-first]

Runs screenshot-backed Obsidian smoke lanes repeatedly and writes a compact
pass/fail report. Each lane still uses script/real_app_smoke.sh --manual-gate
because it focuses the real Obsidian app and a disposable proof vault note.
By default each lane rebuilds/relaunches the app so Obsidian editor state stays
isolated. Use --skip-build-after-first only for faster exploratory runs.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --iterations)
      shift
      ITERATIONS="${1:?--iterations needs a value}"
      ;;
    --iterations=*)
      ITERATIONS="${1#--iterations=}"
      ;;
    --lanes)
      shift
      IFS=',' read -r -a LANES <<<"${1:?--lanes needs a comma-separated value}"
      ;;
    --lanes=*)
      IFS=',' read -r -a LANES <<<"${1#--lanes=}"
      ;;
    --no-skip-build-after-first)
      SKIP_BUILD_AFTER_FIRST=0
      ;;
    --skip-build-after-first)
      SKIP_BUILD_AFTER_FIRST=1
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$ITERATIONS" in
  ''|*[!0-9]*)
    echo "--iterations must be a positive integer" >&2
    exit 2
    ;;
esac
if (( ITERATIONS < 1 )); then
  echo "--iterations must be at least 1" >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT_PATH")"
started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
{
  echo "# Obsidian Deep Sweep Latest"
  echo
  echo "- Started UTC: $started_at"
  echo "- Iterations: $ITERATIONS"
  echo "- Lanes: ${LANES[*]}"
  echo
  echo "| Iteration | Lane | Result | Command |"
  echo "| ---: | --- | --- | --- |"
} >"$REPORT_PATH"

attempts=0
passes=0
failures=0
first_run=1

for iteration in $(seq 1 "$ITERATIONS"); do
  for lane in "${LANES[@]}"; do
    attempts=$((attempts + 1))
    cmd=(script/real_app_smoke.sh "$lane" --manual-gate)
    if (( first_run == 0 && SKIP_BUILD_AFTER_FIRST == 1 )); then
      cmd+=(--skip-build)
    fi

    echo "[$iteration/$ITERATIONS] Running $lane"
    if AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS=md.obsidian \
      AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS=md.obsidian \
      AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN=1 \
      AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 \
      AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-optionTab}" \
      AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_SETTLE_SECONDS="${AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_SETTLE_SECONDS:-0.4}" \
      AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS=1 \
      "${cmd[@]}"; then
      passes=$((passes + 1))
      result="pass"
    else
      failures=$((failures + 1))
      result="fail"
    fi
    first_run=0

    printf '| %s | `%s` | `%s` | `%s` |\n' \
      "$iteration" \
      "$lane" \
      "$result" \
      "${cmd[*]}" >>"$REPORT_PATH"
  done
done

finished_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
{
  echo
  echo "## Summary"
  echo
  echo "- Finished UTC: $finished_at"
  echo "- Attempts: $attempts"
  echo "- Passes: $passes"
  echo "- Failures: $failures"
} >>"$REPORT_PATH"

if (( failures > 0 )); then
  echo "Obsidian deep sweep finished with $failures failure(s). Report: $REPORT_PATH" >&2
  exit 1
fi

echo "Obsidian deep sweep passed $passes/$attempts attempt(s). Report: $REPORT_PATH"
