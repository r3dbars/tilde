#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_BUNDLE="${AUTOCOMPLETE_LAB_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
OUTPUT_DIR="${AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT:-$ROOT_DIR/docs/diagnostics/runs/current-build-privacy-export-proof}"

if [[ ! -x "$APP_BINARY" || "${AUTOCOMPLETE_LAB_REBUILD_PRIVACY_PROOF:-0}" =~ ^(1|true|yes|on)$ ]]; then
  ./script/build_and_run.sh --bundle-only >/tmp/autocomplete-current-build-privacy-build.log
fi

if [[ ! -x "$APP_BINARY" ]]; then
  echo "missing app binary for privacy export proof: $APP_BINARY" >&2
  echo "build output:" >&2
  cat /tmp/autocomplete-current-build-privacy-build.log >&2 2>/dev/null || true
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if ! "$APP_BINARY" --privacy-export-proof --output "$OUTPUT_DIR" >"$OUTPUT_DIR/proof-command.log" 2>&1; then
  cat "$OUTPUT_DIR/proof-command.log" >&2
  exit 1
fi

if find "$OUTPUT_DIR" \( -name 'traces.jsonl' -o -name 'raw-traces.jsonl' \) -print | grep -q .; then
  echo "privacy proof output retained raw trace input" >&2
  find "$OUTPUT_DIR" \( -name 'traces.jsonl' -o -name 'raw-traces.jsonl' \) -print >&2
  exit 1
fi

if grep -R -I -E 'proof-private-|private\.example|private-screenshot|private-recipient|private document|private subject' "$OUTPUT_DIR" >/tmp/autocomplete-current-build-privacy-leaks.txt 2>/dev/null; then
  echo "privacy proof output leaked private sentinel text" >&2
  cat /tmp/autocomplete-current-build-privacy-leaks.txt >&2
  exit 1
fi

for required in \
  "$OUTPUT_DIR/proof-manifest.json" \
  "$OUTPUT_DIR/privacy-export/PRIVACY-CHECKLIST.md" \
  "$OUTPUT_DIR/privacy-export/manifest.json" \
  "$OUTPUT_DIR/privacy-export/redacted-traces.jsonl" \
  "$OUTPUT_DIR/privacy-export/survival-report.json" \
  "$OUTPUT_DIR/privacy-export/visual-calibration-report.txt" \
  "$OUTPUT_DIR/privacy-export/trace-report.html"; do
  if [[ ! -f "$required" ]]; then
    echo "privacy proof missing required file: $required" >&2
    exit 1
  fi
done

EXPECTED_FILES="$(mktemp)"
ACTUAL_FILES="$(mktemp)"
trap 'rm -f "$EXPECTED_FILES" "$ACTUAL_FILES"' EXIT

cat >"$EXPECTED_FILES" <<'EOF'
privacy-export/PRIVACY-CHECKLIST.md
privacy-export/manifest.json
privacy-export/redacted-traces.jsonl
privacy-export/survival-report.json
privacy-export/trace-report.html
privacy-export/visual-calibration-report.txt
proof-command.log
proof-manifest.json
EOF

find "$OUTPUT_DIR" -type f -print |
  sed "s#^$OUTPUT_DIR/##" |
  sort >"$ACTUAL_FILES"

if ! diff -u "$EXPECTED_FILES" "$ACTUAL_FILES" >/tmp/autocomplete-current-build-privacy-files.diff; then
  echo "privacy proof output contains unexpected shareable files" >&2
  cat /tmp/autocomplete-current-build-privacy-files.diff >&2
  exit 1
fi

python3 - "$OUTPUT_DIR/privacy-export/redacted-traces.jsonl" "$OUTPUT_DIR/privacy-export/survival-report.json" <<'PY'
import json
import re
import sys
from pathlib import Path

raw_text_fields = {
    "acceptedText",
    "cleanedVisibleText",
    "displayedText",
    "rawOutput",
    "remainingVisibleText",
    "screenshotPath",
    "systemPrompt",
    "textAfterCursor",
    "textBeforeCursor",
    "userPrompt",
}
shape_metadata = {
    "documentTitle",
    "visibleURL",
    "recipientEmail",
    "subjectLine",
}
shape_re = re.compile(r"^String\(\d+ chars\)$")

def check_event(event, source):
    for field in raw_text_fields:
        value = event.get(field)
        if value not in (None, ""):
            raise SystemExit(f"{source}: raw field {field} was not redacted")
    metadata = event.get("metadata") or {}
    for key in shape_metadata:
        value = metadata.get(key)
        if value is not None and not shape_re.match(str(value)):
            raise SystemExit(f"{source}: metadata {key} kept raw value {value!r}")

trace_path = Path(sys.argv[1])
for line_number, line in enumerate(trace_path.read_text().splitlines(), start=1):
    if line.strip():
        check_event(json.loads(line), f"{trace_path}:{line_number}")

survival_path = Path(sys.argv[2])
for index, event in enumerate(json.loads(survival_path.read_text()), start=1):
    check_event(event, f"{survival_path}:event-{index}")
PY

echo "Current build privacy export proof passed: $OUTPUT_DIR"
