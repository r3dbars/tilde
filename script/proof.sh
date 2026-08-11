#!/usr/bin/env bash
# Fast proof gate — the single pre-merge entry point that keeps main green.
#
# Usage:
#   script/proof.sh [fast]     Run the fast proof tier (default; target < ~5 min).
#   script/proof.sh --help
#
# Every lane is BLOCKING and real:
#   1. git diff --check            whitespace / conflict markers
#   2. complexity budget           structural high-water marks stay bounded
#   3. bash -n script/*.sh         all remaining shell tooling parses
#   4. byte-compile script/*.py    all remaining python tooling parses
#   5. harness self-tests          proof helpers police their own contracts
#   6. swift test                  the complete Swift suite passes
#
# Environment:
#   PROOF_DIFF_BASE=<ref>   If set, run `git diff --check <ref>...HEAD` (catches
#                           whitespace/conflict markers introduced by a PR);
#                           otherwise the working tree is checked.
#   PROOF_STRUCTURAL_CHANGE=1
#                           Require the production Swift diff to be net-negative.
#   PROOF_STRUCTURAL_LOC_EXCEPTION=1
#                           Allow a non-negative structural diff only when the
#                           PR description explains the justified exception.
#
# The signed/notarized release path lives in script/package_app.sh.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

print_help() {
  awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

MODE="fast"
case "${1:-fast}" in
  fast | "") MODE="fast" ;;
  -h | --help | help)
    print_help
    exit 0
    ;;
  *)
    echo "proof.sh: unknown mode '$1'" >&2
    print_help >&2
    exit 2
    ;;
esac

BLOCKING_FAILURES=0
SUMMARY=()

mark() { # status label detail
  SUMMARY+=("$1|$2|$3")
}

run_blocking() { # label cmd...
  local label="$1"
  shift
  echo
  echo "== [blocking] $label =="
  local start end rc
  start="$(date +%s)"
  "$@"
  rc=$?
  end="$(date +%s)"
  if [ "$rc" -eq 0 ]; then
    echo "[PASS] $label ($((end - start))s)"
    mark PASS "$label" "$((end - start))s"
  else
    echo "[FAIL] $label (exit $rc, $((end - start))s)"
    mark FAIL "$label" "$((end - start))s"
    BLOCKING_FAILURES=$((BLOCKING_FAILURES + 1))
  fi
}

check_diff() {
  if [ -n "${PROOF_DIFF_BASE:-}" ]; then
    echo "diff base: ${PROOF_DIFF_BASE}...HEAD"
    git diff --check "${PROOF_DIFF_BASE}...HEAD"
  else
    git diff --check
  fi
}

run_swift() {
  if ! command -v swift >/dev/null 2>&1; then
    echo
    echo "== [blocking] swift test =="
    echo "[FAIL] swift test — swift not found"
    mark FAIL "swift test" "0s"
    BLOCKING_FAILURES=$((BLOCKING_FAILURES + 1))
    return
  fi
  run_blocking "swift test --jobs 1 (full suite)" swift test --jobs 1
}

summarize_and_exit() {
  echo
  echo "==== proof.sh $MODE summary ===="
  local row st lb dt
  for row in "${SUMMARY[@]}"; do
    IFS='|' read -r st lb dt <<<"$row"
    printf '  %-16s %s (%s)\n' "$st" "$lb" "$dt"
  done
  if [ "$BLOCKING_FAILURES" -gt 0 ]; then
    echo
    echo "FAIL: ${BLOCKING_FAILURES} blocking check(s) failed. Fix them before merging to main."
    exit 1
  fi
  echo
  echo "PASS: all blocking checks are green."
  exit 0
}

echo "Tilde fast proof gate (mode: ${MODE})"
echo "Repo: ${ROOT_DIR}"

run_blocking "git diff --check (whitespace / conflict markers)" check_diff
run_blocking "complexity budget" bash script/check_complexity_budget.sh
run_blocking "complexity budget self-test" bash script/check_complexity_budget_self_test.sh
run_blocking "bash -n script/*.sh" bash -n script/*.sh
run_blocking "byte-compile script/*.py" python3 -m py_compile script/*.py
run_swift

summarize_and_exit
