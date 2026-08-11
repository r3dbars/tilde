#!/usr/bin/env bash
# Fast proof gate — the single pre-merge entry point that keeps main green.
#
# Usage:
#   script/proof.sh [fast]     Run the fast proof tier (default; target < ~5 min).
#   script/proof.sh --help
#
# Every lane is BLOCKING and real:
#   1. git diff --check            whitespace / conflict markers
#   2. structural Swift delta      refactors remove more production code than they add
#   3. bash -n script/*.sh         all remaining shell tooling parses
#   4. byte-compile script/*.py    all remaining python tooling parses
#   5. harness self-tests          request shape, privacy, and metric math hold
#   6. swift test                  the complete Swift suite passes
#
# Environment:
#   PROOF_DIFF_BASE=<ref>   If set, run `git diff --check <ref>...HEAD` (catches
#                           whitespace/conflict markers introduced by a PR);
#                           otherwise the working tree is checked.
#   PROOF_STRUCTURAL_CHANGE=1
#                           Require the production Swift diff to be net-negative.
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

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

check_structural_delta() {
  if ! is_truthy "${PROOF_STRUCTURAL_CHANGE:-}"; then
    echo "structural delta check not requested"
    return 0
  fi

  local base="${PROOF_DIFF_BASE:-origin/main}"
  git rev-parse --verify --quiet "${base}^{commit}" >/dev/null \
    || { echo "structural diff base is not a commit: $base" >&2; return 2; }

  local added deleted net
  read -r added deleted < <(
    git diff --numstat "${base}...HEAD" -- ':(glob)Sources/**/*.swift' |
      awk '{ added += $1; deleted += $2 } END { printf "%d %d\n", added, deleted }'
  )
  net=$((added - deleted))
  printf 'production Swift delta (%s...HEAD): +%d -%d net %+d\n' "$base" "$added" "$deleted" "$net"
  if [ "$net" -ge 0 ]; then
    echo "structural changes must reduce production Swift LOC" >&2
    return 1
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
run_blocking "structural Swift delta" check_structural_delta
run_blocking "bash -n script/*.sh" bash -n script/*.sh
run_blocking "byte-compile script/*.py" python3 -m py_compile script/*.py
run_blocking "runtime egress harness self-test" python3 script/check_runtime_network_egress.py --selftest
run_blocking "golden evaluator self-test" python3 script/golden_eval.py --selftest
run_blocking "bundle signing parser self-test" bash script/check_app_bundle.sh --selftest
run_blocking "release identity parser self-test" bash script/package_app.sh --selftest
run_blocking "release-proof cleanup parser self-test" bash script/restart_app.sh --selftest
run_swift

summarize_and_exit
