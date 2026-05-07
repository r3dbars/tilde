#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ITERATIONS=10

usage() {
  cat <<'EOF'
Usage: script/scorecard_goal_loop.sh [--iterations N]

Runs the scorecard target gate, strict manual smoke status, and strict visual
evidence gate repeatedly. This is intentionally a proof loop, not a score
inflator: it exits 1 until every score and required app proof is actually
complete.
EOF
}

while (($# > 0)); do
  case "$1" in
    --iterations)
      if (($# < 2)); then
        echo "--iterations requires a value" >&2
        exit 2
      fi
      ITERATIONS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]] || ((ITERATIONS < 1)); then
  echo "--iterations must be a positive integer" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_iteration() {
  local iteration="$1"
  local prefix="$TMP_DIR/iteration-$iteration"
  local failed=0

  if ! ./script/check_score_targets.sh >"$prefix-score-targets.txt" 2>&1; then
    failed=1
  fi

  if ! ./script/manual_smoke_status.sh --strict >"$prefix-manual-smoke.txt" 2>&1; then
    failed=1
  fi

  if ! ./script/check_visual_placement_evidence.sh --require-all >"$prefix-visual-evidence.txt" 2>&1; then
    failed=1
  fi

  return "$failed"
}

print_final_output() {
  local iteration="$1"
  local prefix="$TMP_DIR/iteration-$iteration"

  echo
  echo "Final score target output:"
  sed -n '1,220p' "$prefix-score-targets.txt"

  echo
  echo "Final strict manual smoke output:"
  sed -n '1,220p' "$prefix-manual-smoke.txt"

  echo
  echo "Final strict visual evidence output:"
  sed -n '1,220p' "$prefix-visual-evidence.txt"
}

for ((iteration = 1; iteration <= ITERATIONS; iteration++)); do
  echo "Scorecard goal loop iteration $iteration/$ITERATIONS"
  if run_iteration "$iteration"; then
    echo
    echo "All scorecard goals complete on iteration $iteration."
    exit 0
  fi
done

echo
echo "Scorecard goal loop still has gaps after $ITERATIONS iteration(s)."
print_final_output "$ITERATIONS"
exit 1
