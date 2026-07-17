#!/usr/bin/env bash
# Fast proof gate — the single pre-merge entry point that keeps main green.
#
# Usage:
#   script/proof.sh [fast]     Run the fast proof tier (default; target < ~5 min).
#   script/proof.sh --help
#
# Every lane is BLOCKING and real:
#   1. git diff --check            whitespace / conflict markers
#   2. byte-compile script/*.py    all remaining python tooling parses
#   3. harness self-tests          the latency/quality measurement tools work
#   4. swift test (core)           the pure policy suite passes
#
# Environment:
#   PROOF_SKIP_SWIFT=1      Skip the Swift test step. Swift is auto-skipped when
#                           `swift` is absent (e.g. the Linux PR runner).
#   PROOF_REQUIRE_SWIFT=1   Fail instead of skipping when `swift` is unavailable
#                           (use on a macOS runner that must exercise Swift).
#   PROOF_SWIFT_FILTER=...  Value for `swift test --filter`. Default
#                           AutocompleteLabCoreTests (pure, fast, no MLX). Set it
#                           empty (PROOF_SWIFT_FILTER=) to run the full suite.
#   PROOF_DIFF_BASE=<ref>   If set, run `git diff --check <ref>...HEAD` (catches
#                           whitespace/conflict markers introduced by a PR);
#                           otherwise the working tree is checked.
#
# The release gate (app bundle, model asset, runtime network egress) lives in
# script/release_check.sh — run it on macOS before cutting a release.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

print_help() {
  awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | on) return 0 ;;
    *) return 1 ;;
  esac
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

skip() { # label reason
  echo
  echo "== [skip] $1 =="
  echo "[SKIP] $1 — $2"
  mark SKIP "$1" "$2"
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
  if is_truthy "${PROOF_SKIP_SWIFT:-}"; then
    skip "swift test" "PROOF_SKIP_SWIFT is set"
    return
  fi
  if ! command -v swift >/dev/null 2>&1; then
    if is_truthy "${PROOF_REQUIRE_SWIFT:-}"; then
      echo
      echo "== [blocking] swift test =="
      echo "[FAIL] swift test — swift not found but PROOF_REQUIRE_SWIFT is set"
      mark FAIL "swift test" "0s"
      BLOCKING_FAILURES=$((BLOCKING_FAILURES + 1))
      return
    fi
    skip "swift test" "no swift toolchain on PATH (expected on the Linux PR runner)"
    return
  fi
  # Default to the pure core suite: fast, deterministic, no MLX/model needed.
  # PROOF_SWIFT_FILTER= (empty) runs the full suite.
  local filter="${PROOF_SWIFT_FILTER-AutocompleteLabCoreTests}"
  if [ -n "$filter" ]; then
    run_blocking "swift test --jobs 1 --filter $filter" swift test --jobs 1 --filter "$filter"
  else
    run_blocking "swift test --jobs 1 (full suite)" swift test --jobs 1
  fi
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

echo "SteadyType fast proof gate (mode: ${MODE})"
echo "Repo: ${ROOT_DIR}"

run_blocking "git diff --check (whitespace / conflict markers)" check_diff
run_blocking "byte-compile script/*.py" python3 -m py_compile script/*.py
run_blocking "local completion runtime self-test" bash script/local_completion_runtime_self_test.sh
run_blocking "local completion batch self-test" bash script/local_completion_batch_self_test.sh
run_blocking "first-token latency self-test" bash script/first_token_latency_self_test.sh
run_blocking "local quality audit self-test" bash script/check_local_quality_audit_self_test.sh
run_blocking "replay eval report self-test" bash script/replay_eval_report_self_test.sh
run_swift

summarize_and_exit
