#!/usr/bin/env bash
# Self-test for script/proof.sh: proves the gate harness fails when a check is
# broken and passes when every check is green, without running the slower real
# checks (it drives proof.sh through its PROOF_SELFTEST_MODE seam).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROOF="./script/proof.sh"

fail() {
  echo "proof self-test FAILED: $*" >&2
  exit 1
}

# Run a command, capturing combined output and exit code without aborting.
capture() { # outfile cmd...
  local out="$1"
  shift
  local rc=0
  "$@" >"$out" 2>&1 || rc=$?
  echo "$rc"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 1. --help is exit 0 and documents the tiers + fast mode.
rc="$(capture "$TMP_DIR/help.out" "$PROOF" --help)"
[ "$rc" -eq 0 ] || fail "--help exited $rc (expected 0)"
grep -q "fast" "$TMP_DIR/help.out" || fail "--help does not mention 'fast' mode"
grep -q "BLOCKING" "$TMP_DIR/help.out" || fail "--help does not document the BLOCKING tier"
grep -q "REPORT" "$TMP_DIR/help.out" || fail "--help does not document the REPORT tier"

# 2. A green check set -> exit 0 and a PASS summary.
rc="$(PROOF_SELFTEST_MODE=pass capture "$TMP_DIR/pass.out" "$PROOF" fast)"
[ "$rc" -eq 0 ] || fail "green run exited $rc (expected 0); see $TMP_DIR/pass.out"
grep -q "PASS: all blocking checks" "$TMP_DIR/pass.out" || fail "green run missing PASS summary"

# 3. A broken check -> non-zero exit and a FAIL summary.
rc="$(PROOF_SELFTEST_MODE=fail capture "$TMP_DIR/fail.out" "$PROOF" fast)"
[ "$rc" -ne 0 ] || fail "broken run exited 0 (expected non-zero); the gate would not block a red main"
grep -q "blocking check(s) failed" "$TMP_DIR/fail.out" || fail "broken run missing FAIL summary"

# 4. An unknown mode is a usage error (exit 2), not a silent pass.
rc="$(capture "$TMP_DIR/bad.out" "$PROOF" bogus-mode)"
[ "$rc" -eq 2 ] || fail "unknown mode exited $rc (expected 2)"

echo "proof self-test: PASS"
