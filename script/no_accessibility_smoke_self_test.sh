#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_LOG="$TMP_DIR/pass.log"
TRUSTED_LOG="$TMP_DIR/trusted.log"
PRESENTED_LOG="$TMP_DIR/presented.log"

cat >"$PASS_LOG" <<'LOG'
2026-05-07T08:00:00Z launch accessibility=false
2026-05-07T08:00:00Z runtime-bootstrap readinessStage=ready
2026-05-07T08:00:01Z status accessibility=AX missing control=running app=No app profile=none enabled=off paused=false decision=Blocked: Accessibility permission missing
LOG

AUTOCOMPLETE_LAB_LOG="$PASS_LOG" script/no_accessibility_smoke.sh --check >/dev/null

cat >"$TRUSTED_LOG" <<'LOG'
2026-05-07T08:00:00Z launch accessibility=true
2026-05-07T08:00:01Z status accessibility=AX ok control=running app=TextEdit profile=supported enabled=on paused=false decision=Ready
LOG

if AUTOCOMPLETE_LAB_LOG="$TRUSTED_LOG" script/no_accessibility_smoke.sh --check >/dev/null 2>&1; then
  echo "no-Accessibility self-test expected trusted log to fail" >&2
  exit 1
fi

cat >"$PRESENTED_LOG" <<'LOG'
2026-05-07T08:00:00Z launch accessibility=false
2026-05-07T08:00:01Z status accessibility=AX missing control=running app=No app profile=none enabled=off paused=false decision=Blocked: Accessibility permission missing
2026-05-07T08:00:02Z suggestion-presented app=com.apple.TextEdit
LOG

if AUTOCOMPLETE_LAB_LOG="$PRESENTED_LOG" script/no_accessibility_smoke.sh --check >/dev/null 2>&1; then
  echo "no-Accessibility self-test expected presented suggestion to fail" >&2
  exit 1
fi

script/no_accessibility_smoke.sh --print >"$TMP_DIR/print.txt"
if ! grep -F "does not" "$TMP_DIR/print.txt" >/dev/null; then
  echo "no-Accessibility self-test expected print mode to state the helper is non-destructive" >&2
  exit 1
fi

echo "No-Accessibility smoke self-test passed."
