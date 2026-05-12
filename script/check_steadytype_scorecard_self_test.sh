#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SCORECARD="docs/product/steadytype-product-scorecard.md"

python3 script/check_steadytype_scorecard.py --scorecard "$SCORECARD" >"$TMP_DIR/pass.txt"

if ! grep -F "SteadyType scorecard verified" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "scorecard self-test expected the real scorecard to verify" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

BAD_SCORE="$TMP_DIR/bad-score.md"
sed -E 's#(\| Latency \| )[0-9]+/100#\1101/100#' "$SCORECARD" >"$BAD_SCORE"

if python3 script/check_steadytype_scorecard.py --scorecard "$BAD_SCORE" >"$TMP_DIR/bad-score.txt" 2>&1; then
  echo "scorecard self-test expected invalid score to fail" >&2
  exit 1
fi

if ! grep -F "Latency: score must be between 0 and 100" "$TMP_DIR/bad-score.txt" >/dev/null; then
  echo "scorecard self-test missing invalid score failure" >&2
  cat "$TMP_DIR/bad-score.txt" >&2
  exit 1
fi

STALE_ROUND_UP="$TMP_DIR/stale-round-up.md"
sed 's#| Placement | 70/100 |#| Placement | 90/100 |#' "$SCORECARD" >"$STALE_ROUND_UP"

if python3 script/check_steadytype_scorecard.py --scorecard "$STALE_ROUND_UP" >"$TMP_DIR/stale.txt" 2>&1; then
  echo "scorecard self-test expected stale rounded-up proof to fail" >&2
  exit 1
fi

if ! grep -F "Placement: contains 'stale', so score must stay <= 75/100" "$TMP_DIR/stale.txt" >/dev/null; then
  echo "scorecard self-test missing stale proof failure" >&2
  cat "$TMP_DIR/stale.txt" >&2
  exit 1
fi

MISSING_AREA="$TMP_DIR/missing-area.md"
grep -v '^| Model readiness |' "$SCORECARD" >"$MISSING_AREA"

if python3 script/check_steadytype_scorecard.py --scorecard "$MISSING_AREA" >"$TMP_DIR/missing.txt" 2>&1; then
  echo "scorecard self-test expected missing area to fail" >&2
  exit 1
fi

if ! grep -F "missing required score area: model readiness" "$TMP_DIR/missing.txt" >/dev/null; then
  echo "scorecard self-test missing required-area failure" >&2
  cat "$TMP_DIR/missing.txt" >&2
  exit 1
fi

echo "SteadyType scorecard self-test passed."
