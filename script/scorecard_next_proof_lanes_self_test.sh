#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FIXTURE="$TMP_DIR/scorecard.md"
cat >"$FIXTURE" <<'EOF'
# Fixture Scorecard

| Area | Score | Evidence | Why It Is Not Higher | Next Proof |
| --- | ---: | --- | --- | --- |
| Strong lane | 95/100 | Green. | Narrow. | Keep the green gate current. |
| Lowest lane | 55/100 | Stale rows. | Needs live proof. | Run `./script/manual_smoke_status.sh --strict`. |
| Middle lane | 70/100 | Partial. | Needs screenshots. | Refresh screenshot evidence. |
EOF

OUTPUT="$(script/scorecard_next_proof_lanes.py --scorecard "$FIXTURE" --limit 2)"

EXPECTED="$(
  cat <<'EOF'
Next proof lanes:
- Lowest lane (55/100): Run ./script/manual_smoke_status.sh --strict.
- Middle lane (70/100): Refresh screenshot evidence.
EOF
)"

if [[ "$OUTPUT" != "$EXPECTED" ]]; then
  echo "unexpected proof lane summary" >&2
  echo "Expected:" >&2
  echo "$EXPECTED" >&2
  echo "Actual:" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

LIMIT_OUTPUT="$TMP_DIR/limit.out"
if script/scorecard_next_proof_lanes.py --scorecard "$FIXTURE" --limit 0 >"$LIMIT_OUTPUT" 2>&1; then
  echo "expected --limit 0 to fail" >&2
  exit 1
fi

if ! grep -F -- "--limit must be a positive integer" "$LIMIT_OUTPUT" >/dev/null; then
  echo "missing limit validation message" >&2
  cat "$LIMIT_OUTPUT" >&2
  exit 1
fi

echo "Scorecard next proof lanes self-test passed."
