#!/usr/bin/env bash
# Fast proof gate — the single pre-merge entry point that keeps main green.
#
# Usage:
#   script/proof.sh [fast]     Run the fast proof tier (default; target < ~5 min).
#   script/proof.sh --help
#
# Every lane is BLOCKING and real:
#   1. git diff --check            whitespace / conflict markers
#   2. structural Swift delta      shipped-target refactors remove more code than they add
#   3. repository boundary         Tilde never depends on Tilde Lab
#   4. bash -n script/*.sh         all remaining shell tooling parses
#   5. byte-compile script/*.py    all remaining python tooling parses
#   6. harness self-tests          request shape, privacy, and metric math hold,
#                                   including the p99 latency budget tripwire
#                                   against synthetic pass/fail fixture logs
#   7. swift test                  the complete Swift suite passes
#
# After the blocking lanes, one REPORT-ONLY lane runs: if this machine has a
# live diagnostics log (~/Library/Logs/Tilde/diagnostics.log), it is checked
# against script/latency_budgets.json and the verdict is printed. This never
# fails the build — live-machine observations stay report-only, per this
# script's own rule: pending proof stays pending.
#
# Environment:
#   PROOF_DIFF_BASE=<ref>   If set, run `git diff --check <ref>...HEAD` (catches
#                           whitespace/conflict markers introduced by a PR);
#                           otherwise the working tree is checked.
#   PROOF_STRUCTURAL_CHANGE=1
#                           Require changed shipped-target Swift to be net-negative.
#                           Development-only Tilde Lab changes may leave it at zero.
#
# The signed/notarized release path lives in script/package_app.sh. Release
# proof pre-seeds one pinned Gemma 4 E2B model outside the app; it never permits
# a GGUF to be embedded in the signed bundle. The post-download runtime lane
# remains loopback-only and does not exercise the separate HTTPS asset phase.
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

run_report() { # label cmd...
  # Same shape as run_blocking, but the result never moves BLOCKING_FAILURES.
  # Live-machine observations are report-only: pending proof stays pending.
  local label="$1"
  shift
  echo
  echo "== [report-only] $label =="
  local start end rc
  start="$(date +%s)"
  "$@"
  rc=$?
  end="$(date +%s)"
  if [ "$rc" -eq 0 ]; then
    echo "[REPORT] $label ($((end - start))s)"
    mark REPORT "$label" "$((end - start))s"
  else
    echo "[REPORT] $label — verdict: over budget or unavailable (exit $rc, $((end - start))s)"
    mark REPORT "$label" "$((end - start))s"
  fi
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
    git diff --numstat "${base}...HEAD" -- \
      ':(glob)Sources/TildeCore/**/*.swift' \
      ':(glob)Sources/TildeApp/**/*.swift' \
      ':(glob)Sources/InlineGhostIME/**/*.swift' |
      awk '{ added += $1; deleted += $2 } END { printf "%d %d\n", added, deleted }'
  )
  net=$((added - deleted))
  printf 'production Swift delta (%s...HEAD): +%d -%d net %+d\n' "$base" "$added" "$deleted" "$net"
  if [ "$added" -eq 0 ] && [ "$deleted" -eq 0 ]; then
    echo "no shipped-target Swift changed; Tilde Lab remains covered by the repository-boundary gate"
    return 0
  fi
  if [ "$net" -ge 0 ]; then
    echo "structural changes must reduce production Swift LOC" >&2
    return 1
  fi
}

check_live_latency_budget() {
  local diagnostics_log="${HOME}/Library/Logs/Tilde/diagnostics.log"
  if [ ! -f "$diagnostics_log" ]; then
    echo "no live diagnostics log at $diagnostics_log — nothing to report yet"
    return 0
  fi
  python3 script/latency_report.py --budget --log "$diagnostics_log"
}

check_release_contract() {
  local help
  help="$(bash script/package_app.sh --help)"
  grep -F -- '--proof-model PATH' <<<"$help" >/dev/null \
    || { echo "release driver does not expose explicit --proof-model input" >&2; return 1; }
  grep -F -- 'never copied into Tilde.app' <<<"$help" >/dev/null \
    || { echo "release driver does not state that the proof model is external" >&2; return 1; }
  grep -F -- 'gemma-4-E2B.Q4_K_M.gguf' <<<"$help" >/dev/null \
    || { echo "release driver does not identify the pinned Gemma 4 E2B file" >&2; return 1; }
  grep -F -- 'capture/redaction' <<<"$help" >/dev/null \
    || { echo "release driver does not describe the Screen Memory capture/redaction stimulus" >&2; return 1; }
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
  # SwiftPM on a Command Line Tools-only Mac (no Xcode) omits the framework
  # search path and runtime rpaths for Swift Testing, so every `import Testing`
  # fails with "no such module" and the bundle cannot dlopen
  # lib_TestingInterop. Supply them when that is the active toolchain.
  local -a clt_testing_flags=()
  local dev_dir
  dev_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$dev_dir" == */CommandLineTools && -d "$dev_dir/Library/Developer/Frameworks/Testing.framework" ]]; then
    local fw="$dev_dir/Library/Developer/Frameworks"
    local lib="$dev_dir/Library/Developer/usr/lib"
    clt_testing_flags=(
      -Xswiftc -F -Xswiftc "$fw"
      -Xlinker -F -Xlinker "$fw"
      -Xlinker -rpath -Xlinker "$fw"
      -Xlinker -rpath -Xlinker "$lib"
    )
  fi
  run_blocking "swift test --jobs 1 (full suite)" swift test --jobs 1 ${clt_testing_flags[@]+"${clt_testing_flags[@]}"}
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
run_blocking "Tilde / Tilde Lab repository boundary" python3 script/check_repository_boundary.py
run_blocking "bash -n script/*.sh" bash -n script/*.sh
run_blocking "byte-compile script/*.py" python3 -m py_compile script/*.py
run_blocking "personal brain lab LOC budget" bash -c \
  'test $(( $(wc -l < script/personal_brain_lab.py) + $(wc -l < script/personal_brain_messages.swift) )) -le 1250'
run_blocking "runtime egress harness self-test" python3 script/check_runtime_network_egress.py --selftest
run_blocking "external-model release contract self-test" check_release_contract
run_blocking "golden evaluator self-test" python3 script/golden_eval.py --selftest
run_blocking "personal brain historical discovery self-test" python3 script/personal_brain_lab.py --selftest
run_blocking "personal brain Messages decoder self-test" xcrun swift script/personal_brain_messages.swift --selftest
run_blocking "bundle signing parser self-test" bash script/check_app_bundle.sh --selftest
run_blocking "development signing selector self-test" bash script/signing_identity.sh --selftest
run_blocking "packaged source provenance self-test" bash script/source_provenance.sh --selftest
run_blocking "F03 preview run receipt self-test" bash script/f03_preview_run.sh --selftest
run_blocking "dev packaging lane self-test" bash script/package_dev.sh --selftest
run_blocking "release-proof cleanup parser self-test" bash script/restart_app.sh --selftest
run_blocking "capture power probe measurement self-test" bash script/capture_power_probe.sh --selftest
run_blocking "latency budget tripwire self-test" python3 script/latency_report.py --selftest
run_swift

run_report "live diagnostics p99 latency budget" check_live_latency_budget

summarize_and_exit
