#!/usr/bin/env bash
# Self-test for normalize_public_core_allowlist.py: proves it sorts, collapses
# exact-duplicate rows (the merge=union artifact), fails on conflicting rows, is
# idempotent, and keeps --check honest.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NORMALIZE="script/normalize_public_core_allowlist.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "normalize allowlist self-test FAILED: $1" >&2
  exit 1
}

# --- 1. unsorted + exact-duplicate rows normalize to sorted + deduped ---------
UNSORTED="$TMP_DIR/unsorted.psv"
cat >"$UNSORTED" <<'PSV'
# Header comment kept verbatim.
# Second header line.
Zebra|research|Sources/Z.swift|Z reason.
Alpha|experimental|Sources/A.swift|A reason.
Zebra|research|Sources/Z.swift|Z reason.
PSV

if python3 "$NORMALIZE" --check --path "$UNSORTED" >/dev/null 2>&1; then
  fail "--check should reject an unsorted file"
fi

python3 "$NORMALIZE" --write --path "$UNSORTED" >/dev/null

EXPECTED="$TMP_DIR/expected.psv"
cat >"$EXPECTED" <<'PSV'
# Header comment kept verbatim.
# Second header line.
Alpha|experimental|Sources/A.swift|A reason.
Zebra|research|Sources/Z.swift|Z reason.
PSV

if ! diff -u "$EXPECTED" "$UNSORTED"; then
  fail "normalized output is not sorted + deduped as expected"
fi

# --- 2. --check now passes and --write is idempotent --------------------------
python3 "$NORMALIZE" --check --path "$UNSORTED" >/dev/null ||
  fail "--check should accept the canonical file"
python3 "$NORMALIZE" --write --path "$UNSORTED" | grep -qF "already canonical" ||
  fail "second --write should report already canonical"

# --- 3. conflicting rows for the same type fail loudly ------------------------
CONFLICT="$TMP_DIR/conflict.psv"
cat >"$CONFLICT" <<'PSV'
# Header.
Alpha|experimental|Sources/A.swift|First reason.
Alpha|research|Sources/A.swift|Different reason.
PSV

if python3 "$NORMALIZE" --check --path "$CONFLICT" >"$TMP_DIR/conflict.out" 2>&1; then
  fail "conflicting rows should not be accepted"
fi
grep -qF "conflicting allowlist rows for Alpha" "$TMP_DIR/conflict.out" ||
  fail "conflict error did not name the conflicting type"

# --- 4. the real, checked-in file is canonical --------------------------------
python3 "$NORMALIZE" --check >/dev/null ||
  fail "the committed allowlist is not canonical"

echo "normalize allowlist self-test passed."
