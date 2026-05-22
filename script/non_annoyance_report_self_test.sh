#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_TRACE="$TMP_DIR/pass.jsonl"
FAIL_TRACE="$TMP_DIR/fail.jsonl"
SUPPRESSED_TRACE="$TMP_DIR/suppressed.jsonl"
PAUSE_TRACE="$TMP_DIR/pause.jsonl"
COOLDOWN_TRACE="$TMP_DIR/cooldown.jsonl"
STALE_WINDOW_TRACE="$TMP_DIR/stale-window.jsonl"

cat >"$PASS_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"s","suggestionID":"p1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","displayedText":"private shown"}
{"timestamp":"2026-05-08T20:00:20Z","sessionID":"s","suggestionID":"p1","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"escape-dismissed"}
{"timestamp":"2026-05-08T20:01:10Z","sessionID":"s","suggestionID":"p2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:02:00Z","sessionID":"s","suggestionID":"p3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:02:30Z","sessionID":"s","suggestionID":"late1","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"late-suggestion-hidden","latencyMilliseconds":950}
{"timestamp":"2026-05-08T20:03:00Z","sessionID":"s","suggestionID":"p4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
JSONL

cat >"$FAIL_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"s","suggestionID":"n1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:01Z","sessionID":"s","suggestionID":"n1","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"escape-dismissed"}
{"timestamp":"2026-05-08T20:00:02Z","sessionID":"s","suggestionID":"n2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:02Z","sessionID":"s","suggestionID":"n2","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:03Z","sessionID":"s","suggestionID":"n3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:04Z","sessionID":"s","suggestionID":"n3","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","outcome":"rejectedAfterAccept","reason":"accepted-then-deleted","metadata":{"acceptanceID":"a3"}}
{"timestamp":"2026-05-08T20:00:05Z","sessionID":"s","suggestionID":"n4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","latencyMilliseconds":900}
{"timestamp":"2026-05-08T20:00:06Z","sessionID":"s","suggestionID":"","type":"appDisabled","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
JSONL

cat >"$SUPPRESSED_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"s","suggestionID":"s1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:01Z","sessionID":"s","suggestionID":"s1","type":"acceptedTextEdited","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","outcome":"rejectedAfterAccept","reason":"accepted-then-deleted","metadata":{"acceptanceID":"a1","prefixCooldownReason":"acceptedThenDeleted"}}
JSONL

cat >"$PAUSE_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"s","suggestionID":"p1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:10Z","sessionID":"s","suggestionID":"p1","type":"appPaused","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"timed-pause","metadata":{"durationSeconds":"900"}}
{"timestamp":"2026-05-08T20:01:10Z","sessionID":"s","suggestionID":"","type":"fieldPaused","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"manual-field","metadata":{"scope":"field"}}
JSONL

cat >"$COOLDOWN_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"s","suggestionID":"c1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:01Z","sessionID":"s","suggestionID":"c1","type":"suggestionTypedOver","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"typed-against-visible-suggestion","metadata":{"prefixCooldownReason":"typedOver"}}
{"timestamp":"2026-05-08T20:00:01Z","sessionID":"s","suggestionID":"c2","type":"suggestionSuppressed","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"typedOver","triggerReason":"prefix-family-cooldown","metadata":{"prefixCooldownReason":"typedOver"}}
{"timestamp":"2026-05-08T20:00:02Z","sessionID":"s","suggestionID":"c3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","triggerReason":"fast-word-completion","metadata":{"candidateSelectionSource":"fast-word-completion"}}
{"timestamp":"2026-05-08T20:01:10Z","sessionID":"s","suggestionID":"c4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:02:00Z","sessionID":"s","suggestionID":"c5","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:03:00Z","sessionID":"s","suggestionID":"c6","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
JSONL

cat >"$STALE_WINDOW_TRACE" <<'JSONL'
{"timestamp":"2026-05-08T20:00:00Z","sessionID":"old","suggestionID":"old1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-08T20:00:01Z","sessionID":"old","suggestionID":"old1","type":"suggestionHidden","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion","reason":"escape-dismissed"}
{"timestamp":"2026-05-08T20:00:02Z","sessionID":"old","suggestionID":"old2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-10T20:00:00Z","sessionID":"new","suggestionID":"new1","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-10T20:01:10Z","sessionID":"new","suggestionID":"new2","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-10T20:02:00Z","sessionID":"new","suggestionID":"new3","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
{"timestamp":"2026-05-10T20:03:00Z","sessionID":"new","suggestionID":"new4","type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","fieldIdentity":"field","requestMode":"wordCompletion"}
JSONL

PASS_OUTPUT="$TMP_DIR/pass.out"
FAIL_OUTPUT="$TMP_DIR/fail.out"
SUPPRESSED_OUTPUT="$TMP_DIR/suppressed.out"
PAUSE_OUTPUT="$TMP_DIR/pause.out"
COOLDOWN_OUTPUT="$TMP_DIR/cooldown.out"
STALE_WINDOW_OUTPUT="$TMP_DIR/stale-window.out"
STALE_ALL_OUTPUT="$TMP_DIR/stale-all.out"

"$ROOT_DIR/script/non_annoyance_report.py" "$PASS_TRACE" >"$PASS_OUTPUT"
grep -q "Gate: pass" "$PASS_OUTPUT"
grep -q "Shown/min: 1.33 (4 shown)" "$PASS_OUTPUT"
grep -q "Dismissals/shown: 25% (1/4)" "$PASS_OUTPUT"
grep -q "Late suggestions hidden: 1/1 (100%)" "$PASS_OUTPUT"
if grep -q "private shown" "$PASS_OUTPUT"; then
  echo "raw displayed text leaked into non-annoyance report" >&2
  exit 1
fi

if "$ROOT_DIR/script/non_annoyance_report.py" "$FAIL_TRACE" >"$FAIL_OUTPUT" 2>&1; then
  echo "expected noisy trace to fail non-annoyance gate" >&2
  exit 1
fi
grep -q "Gate: fail" "$FAIL_OUTPUT"
grep -q "Immediate resurfacing: 3" "$FAIL_OUTPUT"
grep -q "Late suggestions shown: 1" "$FAIL_OUTPUT"
grep -q "Severe suppression coverage: 0/1 (0%)" "$FAIL_OUTPUT"

"$ROOT_DIR/script/non_annoyance_report.py" \
  "$SUPPRESSED_TRACE" \
  --max-accepted-then-deleted 1.0 \
  >"$SUPPRESSED_OUTPUT"
grep -q "Severe suppression coverage: 1/1 (100%)" "$SUPPRESSED_OUTPUT"
grep -q "Gate: pass" "$SUPPRESSED_OUTPUT"

"$ROOT_DIR/script/non_annoyance_report.py" \
  "$PAUSE_TRACE" \
  --max-pause-disable-per-shown 2.0 \
  >"$PAUSE_OUTPUT"
grep -q "Pause/disable events: 2" "$PAUSE_OUTPUT"
grep -q "Gate: pass" "$PAUSE_OUTPUT"

"$ROOT_DIR/script/non_annoyance_report.py" "$COOLDOWN_TRACE" >"$COOLDOWN_OUTPUT"
grep -q "Immediate resurfacing: 0" "$COOLDOWN_OUTPUT"
grep -q "Gate: pass" "$COOLDOWN_OUTPUT"

"$ROOT_DIR/script/non_annoyance_report.py" "$STALE_WINDOW_TRACE" >"$STALE_WINDOW_OUTPUT"
grep -q "Window: latest-24h" "$STALE_WINDOW_OUTPUT"
grep -q "Gate: pass" "$STALE_WINDOW_OUTPUT"
if "$ROOT_DIR/script/non_annoyance_report.py" "$STALE_WINDOW_TRACE" --window all >"$STALE_ALL_OUTPUT" 2>&1; then
  echo "expected all-history stale trace to fail non-annoyance gate" >&2
  exit 1
fi
grep -q "Gate: fail" "$STALE_ALL_OUTPUT"

echo "non_annoyance_report_self_test passed"
