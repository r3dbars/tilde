#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/check_graduation_score.sh >"$TMP_DIR/good.txt"
if ! grep -F "Graduation score: 100/100" "$TMP_DIR/good.txt" >/dev/null; then
  echo "graduation score self-test did not report 100/100 for current fixtures" >&2
  exit 1
fi
script/check_graduation_score.sh --json --min-score 100 >"$TMP_DIR/good.json"
python3 - "$TMP_DIR/good.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("score") != 100 or payload.get("status") != "pass" or payload.get("threshold") != 100:
    raise SystemExit("unexpected graduation score JSON payload")
if payload.get("hardGateBlockers"):
    raise SystemExit("100/100 payload should not list hard gate blockers")
PY

BROKEN_MANIFEST="$TMP_DIR/broken-proof-manifest.json"
cp docs/product/proof-manifest.json "$BROKEN_MANIFEST"
python3 - "$BROKEN_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
for row in manifest["graduationDecisions"]:
    if row["surface"] == "Google Docs in Chrome":
        row["decision"] = "supported"
        row["requiredProof"] = []
        break
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

if script/check_graduation_score.sh --manifest "$BROKEN_MANIFEST" >"$TMP_DIR/broken.txt" 2>&1; then
  echo "graduation score self-test expected a broken manifest to fail" >&2
  exit 1
fi
if ! grep -F "Graduation score check failed: expected at least 100/100." "$TMP_DIR/broken.txt" >/dev/null; then
  echo "graduation score self-test did not print the expected failure" >&2
  exit 1
fi
if ! grep -F "Manifest decisions match the scorecard" "$TMP_DIR/broken.txt" >/dev/null; then
  echo "graduation score self-test did not flag the changed decision" >&2
  exit 1
fi

echo "Graduation score self-test passed."
