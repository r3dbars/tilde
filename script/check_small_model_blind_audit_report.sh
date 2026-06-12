#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROMPTS_PATH="docs/evals/small-model-blind-prompts-2026-06-12.jsonl"
REPORT_PATH="docs/evals/small-model-blind-quality-audit-2026-06-12.md"

if [[ ! -f "$PROMPTS_PATH" ]]; then
  echo "small-model blind prompt set missing: $PROMPTS_PATH" >&2
  exit 1
fi

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "small-model blind audit report missing: $REPORT_PATH" >&2
  exit 1
fi

COUNTS="$(python3 - "$PROMPTS_PATH" <<'PY'
import json
import sys
from pathlib import Path

forbidden = [
    "justin",
    "wrong field",
    "placement",
    "too timid",
    "annoying",
    "complaint",
    "magic",
    "reach test",
]

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
source_kinds = {
    str(row.get("source_kind", "")).strip()
    for row in rows
}
allowed_source_kinds = {"synthetic-public", "public-domain"}
bad_source_kinds = source_kinds.difference(allowed_source_kinds)
if bad_source_kinds:
    raise SystemExit(f"unexpected source_kind values: {sorted(bad_source_kinds)}")
for row in rows:
    text = " ".join(str(row.get(key, "")) for key in ("id", "user", "system")).lower()
    for phrase in forbidden:
        if phrase in text:
            raise SystemExit(f"blind prompt row {row.get('id')} contains overfit phrase: {phrase}")
print(len(rows), suppressed, len(source_kinds))
PY
)"
read -r ROW_COUNT SUPPRESSION_COUNT SOURCE_KIND_COUNT <<<"$COUNTS"

DISPLAY_COUNT=$((ROW_COUNT - SUPPRESSION_COUNT))

if (( ROW_COUNT < 36 )); then
  echo "small-model blind audit needs at least 36 rows; found $ROW_COUNT" >&2
  exit 1
fi

if (( DISPLAY_COUNT < 30 )); then
  echo "small-model blind audit needs at least 30 display rows; found $DISPLAY_COUNT" >&2
  exit 1
fi

if (( SUPPRESSION_COUNT < 6 )); then
  echo "small-model blind audit needs at least 6 suppression rows; found $SUPPRESSION_COUNT" >&2
  exit 1
fi

for required in \
  "Small Model Blind Quality Audit - 2026-06-12" \
  "1B-class lane: \`small-draft-1b\` / \`qwen3-1.7b\`" \
  "Default model remains: \`qwen35-4b\`" \
  "Rows scored: $ROW_COUNT" \
  "Display rows: $DISPLAY_COUNT" \
  "Expected suppression rows: $SUPPRESSION_COUNT" \
  "Source mix: synthetic-public" \
  "No private text: yes" \
  "Default switch: no" \
  "Blindness check: no current complaint-language fixtures"; do
  if ! grep -F "$required" "$REPORT_PATH" >/dev/null; then
    echo "small-model blind audit report missing required proof: $required" >&2
    exit 1
  fi
done

if ! grep -E "Result status: (measured-failed-quality-bar|measured-passed-quality-bar|runnable-not-measured)" "$REPORT_PATH" >/dev/null; then
  echo "small-model blind audit report must declare a measured or runnable result status" >&2
  exit 1
fi

if (( SOURCE_KIND_COUNT < 1 )); then
  echo "small-model blind prompt set missing source_kind metadata" >&2
  exit 1
fi

echo "small-model blind quality audit report check passed"
