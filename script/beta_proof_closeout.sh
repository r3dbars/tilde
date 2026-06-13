#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGET="textedit-model-latency"
APP_BUNDLE="${AUTOCOMPLETE_LAB_PACKAGED_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
DRY_RUN=0
PRINT_PLAN=0
RUN_PACKAGED_LATENCY=0
BLOCKERS=0
DOC_PATH="docs/product/beta-proof-closeout.md"

usage() {
  cat <<'EOF'
Usage: script/beta_proof_closeout.sh [--dry-run] [--print-plan] [--run-packaged-latency] [--target textedit-model-latency|claude-model-latency] [--app-bundle <path>]

Front-door beta proof close-out command.

By default it checks the manual onboarding gates, prints the packaged-latency
command for the notarized app lane, and points at the dogfood/tester ledger.
It does not cut, notarize, publish, deploy, grant Accessibility, or mark human
dogfood proof green.

Use --run-packaged-latency only after a notarized app exists and Accessibility
has been granted for that exact packaged app.
EOF
}

print_plan() {
  cat <<EOF
# Beta Proof Close-Out Plan

1. Re-proof onboarding:
   ./script/check_onboarding_walkthrough_proof.py
   ./script/check_onboarding_permission_qa.sh --check

2. Re-proof packaged latency after the notarized app exists:
   ./script/beta_proof_closeout.sh --run-packaged-latency --target $TARGET --app-bundle "$APP_BUNDLE"

3. Keep dogfood unknown until observed:
   Fill the ledger in $DOC_PATH for 5 consecutive green dogfood days.

4. Invite only 3-5 testers after those 5 green dogfood days:
   Use the tester wave checklist in $DOC_PATH.

This command is proof prep. It never replaces human onboarding or dogfood evidence.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --print-plan)
      PRINT_PLAN=1
      shift
      ;;
    --run-packaged-latency)
      RUN_PACKAGED_LATENCY=1
      shift
      ;;
    --target)
      if (($# < 2)); then
        echo "--target requires a value" >&2
        exit 2
      fi
      TARGET="$2"
      shift 2
      ;;
    --app-bundle)
      if (($# < 2)); then
        echo "--app-bundle requires a path" >&2
        exit 2
      fi
      APP_BUNDLE="$2"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown beta proof close-out option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$TARGET" in
  textedit-model-latency|claude-model-latency)
    ;;
  *)
    echo "unsupported packaged latency target: $TARGET" >&2
    exit 2
    ;;
esac

if [[ "$PRINT_PLAN" == "1" ]]; then
  print_plan
  exit 0
fi

print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

run_gate() {
  local label="$1"
  shift

  echo
  echo "== $label =="
  if [[ "$DRY_RUN" == "1" ]]; then
    print_command "$@"
    echo "$label: dry-run"
    return 0
  fi

  if "$@"; then
    echo "$label: OK"
    return 0
  fi

  echo "$label: blocked"
  BLOCKERS=$((BLOCKERS + 1))
  return 0
}

echo "Beta proof close-out front door"
echo "Target: $TARGET"
echo "Packaged app: $APP_BUNDLE"
echo "Dogfood ledger: $DOC_PATH"
echo "Guardrail: this command does not cut, notarize, publish, deploy, or fake human proof."

run_gate "Onboarding walkthrough proof" ./script/check_onboarding_walkthrough_proof.py
run_gate "Onboarding permission QA" ./script/check_onboarding_permission_qa.sh --check
run_gate "Dogfood and tester-wave ledger doc" test -s "$DOC_PATH"

if [[ "$RUN_PACKAGED_LATENCY" == "1" ]]; then
  run_gate "Packaged latency proof" ./script/packaged_latency_proof.sh "$TARGET" --app-bundle "$APP_BUNDLE"
else
  run_gate "Packaged latency proof dry-run" ./script/packaged_latency_proof.sh "$TARGET" --app-bundle "$APP_BUNDLE" --dry-run
  echo
  echo "Packaged latency proof not observed in this pass."
  echo "Run with --run-packaged-latency only after the notarized app exists and Accessibility is granted."
  if [[ "$DRY_RUN" != "1" ]]; then
    BLOCKERS=$((BLOCKERS + 1))
  fi
fi

echo
echo "Next human gate:"
echo "- record 5 consecutive green dogfood rows in $DOC_PATH"
echo "- invite 3-5 testers only after those 5 rows stay green"

if ((BLOCKERS > 0)); then
  echo
  echo "Beta proof close-out found $BLOCKERS blocker(s)."
  exit 1
fi

echo
echo "Beta proof close-out checks passed."
