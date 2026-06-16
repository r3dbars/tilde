#!/usr/bin/env bash
# Self-test for normalize_proof_manifest.py: proves it sorts the growth lists by
# key, leaves graduationDecisions order untouched, collapses identical duplicate
# entries, fails on conflicting ones, is idempotent, and keeps --check honest.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NORMALIZE="script/normalize_proof_manifest.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "normalize proof manifest self-test FAILED: $1" >&2
  exit 1
}

# --- 1. unsorted growth lists + duplicate entry normalize correctly -----------
UNSORTED="$TMP_DIR/unsorted.json"
cat >"$UNSORTED" <<'JSON'
{
  "schemaVersion": 1,
  "surfaces": [
    {"surface": "Zeta"},
    {"surface": "Alpha"}
  ],
  "profileCoverage": [
    {"bundle": "com.z.app"},
    {"bundle": "com.a.app"},
    {"bundle": "com.z.app"}
  ],
  "hostPolicy": {
    "entries": [
      {"bundle": "com.z.host"},
      {"bundle": "com.a.host"}
    ]
  },
  "graduationDecisions": [
    {"surface": "Second"},
    {"surface": "First"}
  ]
}
JSON

if python3 "$NORMALIZE" --check --path "$UNSORTED" >/dev/null 2>&1; then
  fail "--check should reject an unsorted manifest"
fi

python3 "$NORMALIZE" --write --path "$UNSORTED" >/dev/null

python3 - "$UNSORTED" <<'PY' || exit 1
import json, sys
m = json.load(open(sys.argv[1]))
assert [s["surface"] for s in m["surfaces"]] == ["Alpha", "Zeta"], "surfaces not sorted"
assert [r["bundle"] for r in m["profileCoverage"]] == ["com.a.app", "com.z.app"], "profileCoverage not sorted+deduped"
assert [e["bundle"] for e in m["hostPolicy"]["entries"]] == ["com.a.host", "com.z.host"], "hostPolicy not sorted"
# graduationDecisions order is a contract — it must NOT be reordered.
assert [g["surface"] for g in m["graduationDecisions"]] == ["Second", "First"], "graduationDecisions order changed"
print("structural assertions passed")
PY

# --- 2. --check passes and --write is idempotent ------------------------------
python3 "$NORMALIZE" --check --path "$UNSORTED" >/dev/null ||
  fail "--check should accept the canonical manifest"
python3 "$NORMALIZE" --write --path "$UNSORTED" | grep -qF "already canonical" ||
  fail "second --write should report already canonical"

# --- 3. conflicting entries for the same key fail loudly ----------------------
CONFLICT="$TMP_DIR/conflict.json"
cat >"$CONFLICT" <<'JSON'
{
  "schemaVersion": 1,
  "profileCoverage": [
    {"bundle": "com.a.app", "status": "complete"},
    {"bundle": "com.a.app", "status": "pending"}
  ]
}
JSON

if python3 "$NORMALIZE" --check --path "$CONFLICT" >"$TMP_DIR/conflict.out" 2>&1; then
  fail "conflicting entries should not be accepted"
fi
grep -qF "conflicting entries for bundle='com.a.app'" "$TMP_DIR/conflict.out" ||
  fail "conflict error did not name the conflicting key"

# --- 4. the real, checked-in manifest is canonical ----------------------------
python3 "$NORMALIZE" --check >/dev/null ||
  fail "the committed proof manifest is not canonical"

echo "normalize proof manifest self-test passed."
