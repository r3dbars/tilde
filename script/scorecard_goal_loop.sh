#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ITERATIONS=10

usage() {
  cat <<'EOF'
Usage: script/scorecard_goal_loop.sh [--iterations N]

Runs the SteadyType product scorecard checker, scorecard target gate, strict
manual smoke status, strict visual evidence gate, strict proof manifest gate,
prompt-app manifest proof gate, and private-beta readiness gate repeatedly. This is
intentionally a proof loop, not a score inflator: it exits 1 until every score
and required app proof is actually complete.
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

STEADYTYPE_SCORECARD_GATE_SCRIPT="${AUTOCOMPLETE_LAB_STEADYTYPE_SCORECARD_GATE_SCRIPT:-./script/check_steadytype_scorecard.py}"
SCORE_TARGET_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_GATE_SCRIPT:-./script/check_score_targets.sh}"
MANUAL_SMOKE_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_MANUAL_SMOKE_GATE_SCRIPT:-./script/manual_smoke_status.sh}"
VISUAL_EVIDENCE_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_VISUAL_EVIDENCE_GATE_SCRIPT:-./script/check_visual_placement_evidence.sh}"
PROOF_MANIFEST_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_PROOF_MANIFEST_GATE_SCRIPT:-./script/check_proof_manifest.sh}"
PROMPT_APP_PROOF_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_PROMPT_APP_PROOF_GATE_SCRIPT:-./script/check_prompt_app_manifest_proof.sh}"
BETA_READINESS_GATE_SCRIPT="${AUTOCOMPLETE_LAB_BETA_READINESS_GATE_SCRIPT:-./script/beta_readiness.sh}"

run_iteration() {
  local iteration="$1"
  local prefix="$TMP_DIR/iteration-$iteration"
  local failed=0

  if ! "$STEADYTYPE_SCORECARD_GATE_SCRIPT" >"$prefix-steadytype-scorecard.txt" 2>&1; then
    failed=1
  fi

  if ! AUTOCOMPLETE_LAB_SCORE_TARGET_STRICT_PROOF_GATES=never \
    "$SCORE_TARGET_GATE_SCRIPT" >"$prefix-score-targets.txt" 2>&1; then
    failed=1
  fi

  if ! "$MANUAL_SMOKE_GATE_SCRIPT" --strict >"$prefix-manual-smoke.txt" 2>&1; then
    failed=1
  fi

  if ! "$VISUAL_EVIDENCE_GATE_SCRIPT" --require-all >"$prefix-visual-evidence.txt" 2>&1; then
    failed=1
  fi

  if ! "$PROOF_MANIFEST_GATE_SCRIPT" --require-all >"$prefix-proof-manifest.txt" 2>&1; then
    failed=1
  fi

  if ! "$PROMPT_APP_PROOF_GATE_SCRIPT" >"$prefix-prompt-app-proof.txt" 2>&1; then
    failed=1
  fi

  if ! "$BETA_READINESS_GATE_SCRIPT" --check-only >"$prefix-beta-readiness.txt" 2>&1; then
    failed=1
  fi

  return "$failed"
}

print_final_output() {
  local iteration="$1"
  local prefix="$TMP_DIR/iteration-$iteration"

  echo
  echo "Final SteadyType scorecard output:"
  sed -n '1,220p' "$prefix-steadytype-scorecard.txt"

  echo
  echo "Final score target output:"
  sed -n '1,220p' "$prefix-score-targets.txt"

  echo
  echo "Final strict manual smoke output:"
  sed -n '1,220p' "$prefix-manual-smoke.txt"

  echo
  echo "Final strict visual evidence output:"
  sed -n '1,220p' "$prefix-visual-evidence.txt"

  echo
  echo "Final proof manifest output:"
  sed -n '1,220p' "$prefix-proof-manifest.txt"

  echo
  echo "Final prompt app manifest proof output:"
  sed -n '1,220p' "$prefix-prompt-app-proof.txt"

  echo
  echo "Final beta readiness output:"
  sed -n '1,260p' "$prefix-beta-readiness.txt"
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
