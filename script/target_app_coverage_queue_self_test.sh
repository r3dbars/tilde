#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUTPUT="$TMP_DIR/output.txt"
script/target_app_coverage_queue.py --limit 5 >"$OUTPUT"

for expected in \
  "1. Obsidian broader vault layouts | value=High | risk=Low-Medium" \
  "2. TextEdit and Notes polish variants | value=Medium-High | risk=Low" \
  "3. Chrome production text fields | value=High | risk=Medium" \
  "4. Real Monaco and CodeMirror editors | value=High | risk=Medium-High" \
  "5. Codex layouts | value=High | risk=High"; do
  if ! grep -F "$expected" "$OUTPUT" >/dev/null; then
    echo "target app coverage queue missed: $expected" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

if ! grep -F "local textarea/contenteditable fixtures do not count" "$OUTPUT" >/dev/null; then
  echo "Chrome production lane must not broaden local fixture proof" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "manifest: decision=blocked, proofState=blocked" "$OUTPUT" >/dev/null; then
  echo "queue should include live manifest blocked state for blocked rows" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

LIMIT_OUTPUT="$TMP_DIR/limit.out"
if script/target_app_coverage_queue.py --limit 0 >"$LIMIT_OUTPUT" 2>&1; then
  echo "expected --limit 0 to fail" >&2
  exit 1
fi

if ! grep -F -- "--limit must be a positive integer" "$LIMIT_OUTPUT" >/dev/null; then
  echo "missing limit validation message" >&2
  cat "$LIMIT_OUTPUT" >&2
  exit 1
fi

echo "Target app coverage queue self-test passed."
