#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DIAGNOSTICS="$TMP_DIR/diagnostics.log"
TRACE="$TMP_DIR/traces.jsonl"
RAW_TRACE="$TMP_DIR/raw-traces.jsonl"
SCREENSHOTS="$TMP_DIR/screenshots"

mkdir -p "$SCREENSHOTS"

cat >"$DIAGNOSTICS" <<'LOG'
2026-05-25T12:00:00Z launch executableSHA256=abc
2026-05-25T12:01:00Z textedit-practice-started app=com.apple.TextEdit model=ready globalPaused=false textEditEnabled=true
2026-05-25T12:02:00Z keyboard-action action=acceptNextWord app=com.apple.TextEdit handled=true insertsSuggestionText=String(4 chars) key=tab reason=accepted
2026-05-25T12:03:00Z keyboard-action action=dismiss app=com.apple.TextEdit handled=true insertsSuggestionText=String(5 chars) key=escape reason=dismissed
2026-05-25T12:04:00Z suggestions-control paused=true
LOG

cat >"$TRACE" <<'JSONL'
{"type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","displayedText":"String(8 chars)"}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","outcome":"acceptNextWord","acceptedText":"String(4 chars)"}
JSONL

touch "$RAW_TRACE"
touch "$SCREENSHOTS/textedit.png"

script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$DIAGNOSTICS" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/before.txt"

for expected in \
  "Onboarding walkthrough evidence helper: before-delete" \
  "This is not a pass row." \
  "TextEdit Tab accepted one word" \
  "TextEdit acceptNextWord events: 1" \
  "trace lines 1-2" \
  "Suggested Evidence cell before delete:"; do
  if ! grep -F "$expected" "$TMP_DIR/before.txt" >/dev/null; then
    echo "onboarding evidence helper self-test missing before-delete output: $expected" >&2
    cat "$TMP_DIR/before.txt" >&2
    exit 1
  fi
done

MISSING_ESC="$TMP_DIR/missing-esc.log"
grep -v "action=dismiss" "$DIAGNOSTICS" >"$MISSING_ESC"
if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$MISSING_ESC" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/missing-esc.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected missing Esc proof to fail" >&2
  exit 1
fi

if ! grep -F "TextEdit Esc dismissed suggestion" "$TMP_DIR/missing-esc.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing Esc failure detail" >&2
  cat "$TMP_DIR/missing-esc.txt" >&2
  exit 1
fi

rm -f "$TRACE" "$RAW_TRACE"
rm -rf "$SCREENSHOTS"
cat >"$DIAGNOSTICS" <<'LOG'
2026-05-25T12:05:00Z local-privacy-logs-deleted surface=settings
LOG

script/onboarding_walkthrough_evidence_helper.py \
  --mode after-delete \
  --require-ready \
  --diagnostics-log "$DIAGNOSTICS" \
  --trace-log "$TRACE" \
  --raw-trace-log "$RAW_TRACE" \
  --screenshot-dir "$SCREENSHOTS" \
  >"$TMP_DIR/after.txt"

for expected in \
  "Onboarding walkthrough evidence helper: after-delete" \
  "Delete Local Logs recorded" \
  "Trace JSONL removed: yes" \
  "Suggested Evidence cell after delete:"; do
  if ! grep -F "$expected" "$TMP_DIR/after.txt" >/dev/null; then
    echo "onboarding evidence helper self-test missing after-delete output: $expected" >&2
    cat "$TMP_DIR/after.txt" >&2
    exit 1
  fi
done

cat >"$DIAGNOSTICS" <<'LOG'
2026-05-25T12:05:00Z status accessibility=trusted
LOG

if script/onboarding_walkthrough_evidence_helper.py \
  --mode after-delete \
  --require-ready \
  --diagnostics-log "$DIAGNOSTICS" \
  --trace-log "$TRACE" \
  --raw-trace-log "$RAW_TRACE" \
  --screenshot-dir "$SCREENSHOTS" \
  >"$TMP_DIR/missing-delete.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected missing delete event to fail" >&2
  exit 1
fi

if ! grep -F "local-privacy-logs-deleted diagnostics event" "$TMP_DIR/missing-delete.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing delete failure detail" >&2
  cat "$TMP_DIR/missing-delete.txt" >&2
  exit 1
fi

script/onboarding_walkthrough_evidence_helper.py --print-commands >"$TMP_DIR/commands.txt"

if ! grep -F "./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready" "$TMP_DIR/commands.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing before-delete command" >&2
  cat "$TMP_DIR/commands.txt" >&2
  exit 1
fi

echo "Onboarding walkthrough evidence helper self-test passed."
