#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_FILE="$TMP_DIR/typing-feel.jsonl"
OUTPUT_FILE="$TMP_DIR/typing-feel.out"
JSON_OUTPUT_FILE="$TMP_DIR/typing-feel.json"

cat >"$TRACE_FILE" <<'JSONL'
{"timestamp":"2026-05-21T14:00:00Z","sessionID":"s","suggestionID":"p1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","displayedText":"secret launch text","textBeforeCursor":"private before cursor","metadata":{"displayedTextChars":"18"}}
{"timestamp":"2026-05-21T14:00:05Z","sessionID":"s","suggestionID":"p1","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","acceptedText":"private accepted word","metadata":{"acceptanceID":"a1","acceptedTextChars":"21"}}
{"timestamp":"2026-05-21T14:00:15Z","sessionID":"s","suggestionID":"p1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","acceptedText":"private accepted word","metadata":{"acceptanceID":"a1","checkpoint":"10s","survivalClass":"exactKept","strongAcceptedAndKept":"true","rawOutput":"raw model private"}}
{"timestamp":"2026-05-21T14:00:30Z","sessionID":"s","suggestionID":"p2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","rawOutput":"raw model private"}
{"timestamp":"2026-05-21T14:00:31Z","sessionID":"s","suggestionID":"p2","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","textAfterCursor":"private after cursor"}
{"timestamp":"2026-05-21T14:00:32Z","sessionID":"s","suggestionID":"p3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","displayedText":"resurfaced private text"}
{"timestamp":"2026-05-21T14:00:40Z","sessionID":"s","suggestionID":"p3","type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","acceptedText":"deleted private word","metadata":{"acceptanceID":"a3"}}
{"timestamp":"2026-05-21T14:00:41Z","sessionID":"s","suggestionID":"p3","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","outcome":"accepted-then-deleted","reason":"accepted-then-deleted","metadata":{"acceptanceID":"a3","checkpoint":"2s","survivalClass":"rejectedAfterAccept","firstEditDelayMs":"500"}}
{"timestamp":"2026-05-21T14:00:42Z","sessionID":"s","suggestionID":"p4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","latencyMilliseconds":900,"displayedText":"late private text","screenshotPath":"/Users/redbars/private-shot.png"}
{"timestamp":"2026-05-21T14:00:43Z","sessionID":"s","suggestionID":"p4","type":"insertionFailed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"verification-failed"}
{"timestamp":"2026-05-21T14:00:44Z","sessionID":"s","suggestionID":"p4","type":"caretGeometryFailed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"detached-suggestion-disabled"}
{"timestamp":"2026-05-21T14:00:45Z","sessionID":"s","suggestionID":"","type":"appPaused","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"timed-pause"}
{"timestamp":"2026-05-21T14:00:46Z","sessionID":"s","suggestionID":"","type":"fieldPaused","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"manual-field"}
{"timestamp":"2026-05-21T14:00:47Z","sessionID":"s","suggestionID":"","type":"appDisabled","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"manual-disable"}
{"timestamp":"2026-05-21T14:04:00Z","sessionID":"s","suggestionID":"p5","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","displayedText":"last private text"}
JSONL

"$ROOT_DIR/script/typing_feel_score_report.py" "$TRACE_FILE" >"$OUTPUT_FILE"

grep -F "Typing feel score report" "$OUTPUT_FILE" >/dev/null
grep -F "Privacy: redacted aggregate counts/rates only" "$OUTPUT_FILE" >/dev/null
grep -F "Shown/min: 1.25 (5 shown)" "$OUTPUT_FILE" >/dev/null
grep -F "Accepted-and-kept shown rate: 20% (1/5)" "$OUTPUT_FILE" >/dev/null
grep -F "Accepted-and-kept accepted rate: 50% (1/2)" "$OUTPUT_FILE" >/dev/null
grep -F "Typed-over rate: 20% (1/5)" "$OUTPUT_FILE" >/dev/null
grep -F "Accepted-then-deleted: 1" "$OUTPUT_FILE" >/dev/null
grep -F "Immediate resurfacing: 2" "$OUTPUT_FILE" >/dev/null
grep -F "Late shown suggestions: 1" "$OUTPUT_FILE" >/dev/null
grep -F "Insertion failures: 1" "$OUTPUT_FILE" >/dev/null
grep -F "Caret failures: 1" "$OUTPUT_FILE" >/dev/null
grep -F "Pause/disable events: 3 (2 pause, 1 disable)" "$OUTPUT_FILE" >/dev/null

if grep -E "secret launch text|private accepted word|raw model private|private-shot|resurfaced private text|last private text" "$OUTPUT_FILE" >/dev/null; then
  echo "typing feel report leaked raw trace text" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

"$ROOT_DIR/script/typing_feel_score_report.py" "$TRACE_FILE" --json >"$JSON_OUTPUT_FILE"
python3 - "$JSON_OUTPUT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    report = json.load(handle)

assert report["report"] == "typing_feel_score"
assert report["privacy"] == "redacted"
assert report["shown"] == 5
assert report["accepted"] == 2
assert report["accepted_and_kept"] == 1
assert round(report["shown_per_minute"], 2) == 1.25
assert report["accepted_and_kept_shown_numerator"] == 1
assert report["accepted_and_kept_accepted_numerator"] == 1
assert report["typed_over"] == 1
assert report["accepted_then_deleted"] == 1
assert report["immediate_resurfacing"] == 2
assert report["late_shown_suggestions"] == 1
assert report["insertion_failures"] == 1
assert report["caret_failures"] == 1
assert report["pause_disable_events"] == 3
PY

if "$ROOT_DIR/script/typing_feel_score_report.py" "$TRACE_FILE" --fail-under 95 >/dev/null 2>&1; then
  echo "typing feel report fail-under gate should fail the noisy fixture" >&2
  exit 1
fi

echo "typing_feel_score_report_self_test passed"
