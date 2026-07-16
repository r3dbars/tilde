#!/usr/bin/env bash
# Fast proof gate — the single pre-merge entry point that keeps main green.
#
# Usage:
#   script/proof.sh [fast]     Run the fast proof tier (default; target < ~10 min).
#   script/proof.sh --help
#
# Tiers:
#   BLOCKING  Cheap checks that must stay green on a healthy main. A failure here
#             exits non-zero and fails the PR gate / pre-push hook. These are the
#             ones that catch the kind of red that has been landing on main
#             (stale coverage manifest, whitespace, broken scripts, core tests).
#   REPORT    Proof-status checks that surface pending MANUAL proofs (e.g. the
#             Obsidian screenshot smokes). They run for visibility but never fail
#             the gate. Keep proof gates honest: pending proof stays pending.
#             Promote a report lane to blocking once its manual proof lands.
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
# The heavy pre-beta gate (signed artifacts, notarization, model asset, latency,
# manual smokes) lives in script/beta_readiness.sh — this is the cheap tier only.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

print_help() {
  # Print the header comment block (everything from line 2 up to the first
  # non-comment line), stripping the leading "# ".
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

run_report() { # label cmd...
  local label="$1"
  shift
  echo
  echo "== [report] $label =="
  local start end rc
  start="$(date +%s)"
  "$@"
  rc=$?
  end="$(date +%s)"
  if [ "$rc" -eq 0 ]; then
    echo "[REPORT ok] $label ($((end - start))s)"
    mark "REPORT-ok" "$label" "$((end - start))s"
  else
    echo "[REPORT pending] $label (exit $rc, $((end - start))s) — non-blocking"
    mark "REPORT-pending" "$label" "$((end - start))s"
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
  echo "PASS: all blocking checks are green. (report-only lanes are advisory.)"
  exit 0
}

# --- Self-test seam ---------------------------------------------------------
# proof_self_test.sh sets PROOF_SELFTEST_MODE to validate the harness contract
# (fails when a check is broken, passes when green) without running the real,
# slower checks.
if [ -n "${PROOF_SELFTEST_MODE:-}" ]; then
  echo "proof.sh self-test mode: ${PROOF_SELFTEST_MODE}"
  case "${PROOF_SELFTEST_MODE}" in
    pass) run_blocking "selftest synthetic check" true ;;
    fail) run_blocking "selftest synthetic check" false ;;
    *)
      echo "proof.sh: unknown PROOF_SELFTEST_MODE '${PROOF_SELFTEST_MODE}'" >&2
      exit 2
      ;;
  esac
  summarize_and_exit
fi

echo "SteadyType fast proof gate (mode: ${MODE})"
echo "Repo: ${ROOT_DIR}"

# --- BLOCKING lane (cheap first, Swift last) --------------------------------
run_blocking "git diff --check (whitespace / conflict markers)" check_diff
run_blocking "byte-compile script/*.py" python3 -m py_compile script/*.py
run_blocking "shipping boundary checker self-test" python3 script/check_shipping_boundary_self_test.py
run_blocking "shipping product boundary" python3 script/check_shipping_boundary.py
run_blocking "local completion runtime self-test" bash script/local_completion_runtime_self_test.sh
run_blocking "local completion batch self-test" bash script/local_completion_batch_self_test.sh
run_blocking "first-token latency self-test" bash script/first_token_latency_self_test.sh
run_blocking "local quality audit self-test" bash script/check_local_quality_audit_self_test.sh
run_blocking "small model blind audit report" bash script/check_small_model_blind_audit_report.sh
run_blocking "test coverage manifest" ./script/check_test_coverage_manifest.sh
run_blocking "public-core allowlist canonical" python3 script/normalize_public_core_allowlist.py --check
run_blocking "public-core allowlist normalizer self-test" bash script/normalize_public_core_allowlist_self_test.sh
run_blocking "proof-manifest canonical" python3 script/normalize_proof_manifest.py --check
run_blocking "proof-manifest normalizer self-test" bash script/normalize_proof_manifest_self_test.sh
run_swift

# --- REPORT lane (advisory; pending manual proof stays pending) -------------
run_report "proof manifest (--require-all)" ./script/check_proof_manifest.sh --require-all

summarize_and_exit
