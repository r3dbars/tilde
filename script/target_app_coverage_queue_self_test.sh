#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUTPUT="$TMP_DIR/output.txt"
script/target_app_coverage_queue.py --limit 5 >"$OUTPUT"

for expected in \
  "1. Apple Pages documents | value=High | risk=Low-Medium" \
  "2. LibreOffice Writer documents | value=High | risk=Medium" \
  "3. Safari local textarea/contenteditable fixtures | value=Medium-High | risk=Low-Medium" \
  "4. Focused local writing apps | value=Medium-High | risk=Medium" \
  "5. Google Docs in Chrome | value=High | risk=High"; do
  if ! grep -F "$expected" "$OUTPUT" >/dev/null; then
    echo "target app coverage queue missed: $expected" >&2
    cat "$OUTPUT" >&2
    exit 1
  fi
done

if ! grep -F "Local fixtures only; no public pages or hosted browser apps." "$OUTPUT" >/dev/null; then
  echo "Safari lane must stay limited to local fixtures" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "Exact disposable real-service proof only; local fixtures do not count." "$OUTPUT" >/dev/null; then
  echo "Google Docs lane must not broaden local fixture proof" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! grep -F "manifest: decision=blocked, proofState=blocked" "$OUTPUT" >/dev/null; then
  echo "queue should include live manifest blocked state for blocked rows" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

if ! script/target_app_coverage_queue.py --limit 10 | grep -F "Keep off by default until no-submit/no-send proof exists" >/dev/null; then
  echo "risky send/prompt surfaces must stay guarded in the long queue" >&2
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
