#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
EXPECTED_CURRENT_SCORE=98

script/check_graduation_score.sh --min-score "$EXPECTED_CURRENT_SCORE" >"$TMP_DIR/current.txt"
if ! grep -F "Graduation score: $EXPECTED_CURRENT_SCORE/100" "$TMP_DIR/current.txt" >/dev/null; then
  echo "graduation score self-test did not report the expected current score" >&2
  exit 1
fi
if ! grep -F "[FAIL]  2 - Proof manifest validator passes with current source-compatible evidence" "$TMP_DIR/current.txt" >/dev/null; then
  echo "graduation score self-test did not keep the pending current-source proof gate visible" >&2
  exit 1
fi

script/check_graduation_score.sh --json --min-score "$EXPECTED_CURRENT_SCORE" >"$TMP_DIR/current.json"
python3 - "$TMP_DIR/current.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("score") != 98 or payload.get("status") != "pass" or payload.get("threshold") != 98:
    raise SystemExit("unexpected graduation score JSON payload")
if "Proof manifest validator passes with current source-compatible evidence" not in payload.get("hardGateBlockers", []):
    raise SystemExit("current payload should keep pending proof blockers visible")
PY

if script/check_graduation_score.sh --min-score 100 >"$TMP_DIR/missing-proof.txt" 2>&1; then
  echo "graduation score self-test expected current fixtures to fail the 100/100 beta gate" >&2
  exit 1
fi
if ! grep -F "Graduation score check failed: expected at least 100/100." "$TMP_DIR/missing-proof.txt" >/dev/null; then
  echo "graduation score self-test did not print the expected 100/100 failure" >&2
  exit 1
fi

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
