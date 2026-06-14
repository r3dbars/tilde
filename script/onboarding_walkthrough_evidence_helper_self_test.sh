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
2026-05-25T12:03:00Z keyboard-action action=acceptAllVisible app=com.apple.TextEdit handled=true insertsSuggestionText=String(14 chars) key=shiftTab reason=accepted
2026-05-25T12:04:00Z keyboard-action action=dismiss app=com.apple.TextEdit handled=true insertsSuggestionText=String(5 chars) key=escape reason=dismissed
2026-05-25T12:05:00Z suggestions-control paused=true
LOG

cat >"$TRACE" <<'JSONL'
{"type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","displayedText":"String(8 chars)"}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","requestMode":"wordCompletion","outcome":"acceptNextWord","acceptedText":"String(4 chars)"}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","requestMode":"phraseContinuation","outcome":"acceptAllVisible","acceptedText":"String(14 chars)"}
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
  "Local model ready at practice start" \
  "TextEdit enabled at practice start" \
  "Suggestions unpaused at practice start" \
  "Latest TextEdit practice start line: 2" \
  "TextEdit Tab accepted one word" \
  "TextEdit Shift-Tab accepted whole suggestion" \
  "TextEdit acceptNextWord events: 1" \
  "TextEdit acceptAllVisible events: 1" \
  "trace lines 1-3" \
  "Suggested Evidence cell before delete:"; do
  if ! grep -F "$expected" "$TMP_DIR/before.txt" >/dev/null; then
    echo "onboarding evidence helper self-test missing before-delete output: $expected" >&2
    cat "$TMP_DIR/before.txt" >&2
    exit 1
  fi
done

MISSING_SHIFT_TAB="$TMP_DIR/missing-shift-tab.log"
grep -v "action=acceptAllVisible" "$DIAGNOSTICS" >"$MISSING_SHIFT_TAB"
if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$MISSING_SHIFT_TAB" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/missing-shift-tab.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected missing Shift-Tab proof to fail" >&2
  exit 1
fi

if ! grep -F "TextEdit Shift-Tab accepted whole suggestion" "$TMP_DIR/missing-shift-tab.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing Shift-Tab failure detail" >&2
  cat "$TMP_DIR/missing-shift-tab.txt" >&2
  exit 1
fi

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

STALE_AFTER_START="$TMP_DIR/stale-after-start.log"
cat >"$STALE_AFTER_START" <<'LOG'
2026-05-25T12:00:00Z launch executableSHA256=abc
2026-05-25T12:01:00Z textedit-practice-started app=com.apple.TextEdit model=ready globalPaused=false textEditEnabled=true
2026-05-25T12:02:00Z keyboard-action action=acceptNextWord app=com.apple.TextEdit handled=true insertsSuggestionText=String(4 chars) key=tab reason=accepted
2026-05-25T12:03:00Z keyboard-action action=acceptAllVisible app=com.apple.TextEdit handled=true insertsSuggestionText=String(14 chars) key=shiftTab reason=accepted
2026-05-25T12:04:00Z keyboard-action action=dismiss app=com.apple.TextEdit handled=true insertsSuggestionText=String(5 chars) key=escape reason=dismissed
2026-05-25T12:05:00Z suggestions-control paused=true
2026-05-25T12:06:00Z textedit-practice-started app=com.apple.TextEdit model=ready globalPaused=false textEditEnabled=true
LOG

if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$STALE_AFTER_START" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/stale-after-start.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected stale pre-practice actions to fail" >&2
  exit 1
fi

for expected in \
  "Latest TextEdit practice start line: 7" \
  "TextEdit Tab accepted one word after TextEdit practice started" \
  "TextEdit Shift-Tab accepted whole suggestion after TextEdit practice started" \
  "TextEdit Esc dismissed suggestion after TextEdit practice started" \
  "Pause Suggestions turned on after TextEdit practice started"; do
  if ! grep -F "$expected" "$TMP_DIR/stale-after-start.txt" >/dev/null; then
    echo "onboarding evidence helper self-test missing stale-after-start detail: $expected" >&2
    cat "$TMP_DIR/stale-after-start.txt" >&2
    exit 1
  fi
done

MODEL_NOT_READY="$TMP_DIR/model-not-ready.log"
sed 's/model=ready/model=installing/' "$DIAGNOSTICS" >"$MODEL_NOT_READY"
if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$MODEL_NOT_READY" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/model-not-ready.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected model-not-ready proof to fail" >&2
  exit 1
fi

if ! grep -F "Local model ready at practice start" "$TMP_DIR/model-not-ready.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing model-ready failure detail" >&2
  cat "$TMP_DIR/model-not-ready.txt" >&2
  exit 1
fi

TEXTEDIT_DISABLED="$TMP_DIR/textedit-disabled.log"
sed 's/textEditEnabled=true/textEditEnabled=false/' "$DIAGNOSTICS" >"$TEXTEDIT_DISABLED"
if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$TEXTEDIT_DISABLED" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/textedit-disabled.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected TextEdit-disabled proof to fail" >&2
  exit 1
fi

if ! grep -F "TextEdit enabled at practice start" "$TMP_DIR/textedit-disabled.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing TextEdit-enabled failure detail" >&2
  cat "$TMP_DIR/textedit-disabled.txt" >&2
  exit 1
fi

GLOBAL_PAUSED="$TMP_DIR/global-paused.log"
sed 's/globalPaused=false/globalPaused=true/' "$DIAGNOSTICS" >"$GLOBAL_PAUSED"
if script/onboarding_walkthrough_evidence_helper.py \
  --mode before-delete \
  --require-ready \
  --diagnostics-log "$GLOBAL_PAUSED" \
  --trace-log "$TRACE" \
  >"$TMP_DIR/global-paused.txt" 2>&1; then
  echo "onboarding evidence helper self-test expected globally-paused proof to fail" >&2
  exit 1
fi

if ! grep -F "Suggestions unpaused at practice start" "$TMP_DIR/global-paused.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing unpaused failure detail" >&2
  cat "$TMP_DIR/global-paused.txt" >&2
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

if ! grep -F "through Tab, Shift-Tab, Esc, and Pause Suggestions" "$TMP_DIR/commands.txt" >/dev/null; then
  echo "onboarding evidence helper self-test missing Shift-Tab command guidance" >&2
  cat "$TMP_DIR/commands.txt" >&2
  exit 1
fi

echo "Onboarding walkthrough evidence helper self-test passed."
