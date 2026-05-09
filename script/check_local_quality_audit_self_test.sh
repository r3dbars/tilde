#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT="$(script/local_quality_audit.py --self-test)"

grep -q "Local quality audit: PASS" <<<"$OUTPUT"
grep -q "Source: self-test fixtures" <<<"$OUTPUT"
grep -q "Overall score: 100/100" <<<"$OUTPUT"
grep -q "Relevance score: 100/100" <<<"$OUTPUT"
grep -q "Raw output persisted: no" <<<"$OUTPUT"
grep -q "PASS fixture-good-markdown" <<<"$OUTPUT"
grep -q "FAIL fixture-assistant-voice" <<<"$OUTPUT"
grep -q "FAIL fixture-sensitive-structure" <<<"$OUTPUT"

for label in \
  "relevance" \
  "literal continuation" \
  "assistant voice" \
  "wrong topic" \
  "too long" \
  "structural breakage" \
  "unsafe or sensitive content" \
  "repetition"; do
  grep -q -- "- $label:" <<<"$OUTPUT"
done

echo "$OUTPUT"
