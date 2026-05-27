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
| Manual lane | 55/100 | Stale rows. | Needs live proof. | Run a documented manual gate in Settings. |
| Automation lane | 60/100 | Prompt-row proof exists. | Needs insertion repair. | Repair Ghostty insertion transport and rerun `./script/claude_code_ghostty_detached_proof.sh wait`. |
| Middle lane | 70/100 | Partial. | Needs screenshots. | Refresh screenshot evidence. |
EOF

OUTPUT="$(script/scorecard_next_proof_lanes.py --scorecard "$FIXTURE" --limit 2)"

EXPECTED="$(
  cat <<'EOF'
Next proof lanes:
- Manual lane (55/100): Run a documented manual gate in Settings.
- Automation lane (60/100): Repair Ghostty insertion transport and rerun ./script/claude_code_ghostty_detached_proof.sh wait.
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

AUTOMATION_OUTPUT="$(script/scorecard_next_proof_lanes.py --scorecard "$FIXTURE" --limit 2 --automation-ready)"

AUTOMATION_EXPECTED="$(
  cat <<'EOF'
Automation-ready proof lanes:
- Automation lane (60/100): Repair Ghostty insertion transport and rerun ./script/claude_code_ghostty_detached_proof.sh wait.
- Middle lane (70/100): Refresh screenshot evidence.
EOF
)"

if [[ "$AUTOMATION_OUTPUT" != "$AUTOMATION_EXPECTED" ]]; then
  echo "unexpected automation-ready proof lane summary" >&2
  echo "Expected:" >&2
  echo "$AUTOMATION_EXPECTED" >&2
  echo "Actual:" >&2
  echo "$AUTOMATION_OUTPUT" >&2
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
