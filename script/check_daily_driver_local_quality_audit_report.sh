#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROMPTS_PATH="docs/evals/daily-driver-disposable-prompts-2026-05-25.jsonl"
REPORT_PATH="docs/evals/daily-driver-local-quality-audit-2026-05-25.md"

if [[ ! -f "$PROMPTS_PATH" ]]; then
  echo "daily-driver quality prompt set missing: $PROMPTS_PATH" >&2
  exit 1
fi

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "daily-driver quality audit report missing: $REPORT_PATH" >&2
  exit 1
fi

read -r ROW_COUNT SUPPRESSION_COUNT < <(python3 - "$PROMPTS_PATH" <<'PY'
import json
import sys
from pathlib import Path

rows = [
    json.loads(line)
    for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    if line.strip()
]
suppressed = sum(
    1
    for row in rows
    if row.get("expected_suppression")
    or row.get("expectedSuppression")
    or row.get("expect_no_suggestion")
    or row.get("expectNoSuggestion")
)
print(len(rows), suppressed)
PY
)

DISPLAY_COUNT=$((ROW_COUNT - SUPPRESSION_COUNT))

if (( ROW_COUNT < 45 )); then
  echo "daily-driver quality audit needs at least 45 disposable rows; found $ROW_COUNT" >&2
  exit 1
fi

if (( DISPLAY_COUNT < 36 )); then
  echo "daily-driver quality audit needs at least 36 display-eligible rows; found $DISPLAY_COUNT" >&2
  exit 1
fi

if (( SUPPRESSION_COUNT < 9 )); then
  echo "daily-driver quality audit needs at least 9 suppression rows; found $SUPPRESSION_COUNT" >&2
  exit 1
fi

for required in \
  "Rows scored: $ROW_COUNT" \
  "Display-eligible rows: $DISPLAY_COUNT" \
  "Suppressed/no-suggestion rows: $SUPPRESSION_COUNT" \
  "Expected suppressions passed: $SUPPRESSION_COUNT" \
  "Overall score: 100/100" \
  "Relevance score: 100/100" \
  "Raw output persisted: no" \
  "PASS \`obsidian-note-capture\`" \
  "PASS \`fast-typing-trust\`" \
  "PASS \`word-predictive\`" \
  "SUPPRESS \`suppress-api\`" \
  "SUPPRESS \`suppress-private-prompt\`"; do
  if ! grep -F "$required" "$REPORT_PATH" >/dev/null; then
    echo "daily-driver quality audit report missing required proof: $required" >&2
    exit 1
  fi
done

echo "daily-driver local quality audit report check passed"
