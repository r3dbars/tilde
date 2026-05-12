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
  "$OUTPUT_DIR/privacy-export/trace-report.html"; do
  if [[ ! -f "$required" ]]; then
    echo "privacy proof missing required file: $required" >&2
    exit 1
  fi
done

echo "Current build privacy export proof passed: $OUTPUT_DIR"
