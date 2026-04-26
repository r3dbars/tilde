#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
REPORT_PATH="$TMP_DIR/manual-smoke-runs.md"
FAILURE_OUTPUT="$TMP_DIR/failure-output.txt"

cat >"$LOG_PATH" <<'EOF'
2026-04-26T08:00:00Z suggestion-presented app=com.apple.TextEdit effectiveRenderMode=inlineAdjacent
2026-04-26T08:00:01Z keyboard-action app=com.apple.TextEdit key=tab action=acceptNextWord handled=true reason=accepted
2026-04-26T08:00:01Z insert app=com.apple.TextEdit success=true mode=axSelectedText
2026-04-26T08:00:02Z insert-verification app=com.apple.TextEdit result=verified acceptedChars=5 previousBeforeChars=6 currentBeforeChars=11
2026-04-26T08:00:03Z suggestion-presented app=com.apple.TextEdit effectiveRenderMode=inlineAdjacent
2026-04-26T08:00:04Z keyboard-action app=com.apple.TextEdit key=backtick action=acceptAllVisible handled=true reason=accepted
2026-04-26T08:00:04Z insert app=com.apple.TextEdit success=true mode=axSelectedText
2026-04-26T08:00:05Z insert-verification app=com.apple.TextEdit result=verified acceptedChars=12 previousBeforeChars=11 currentBeforeChars=23
EOF

AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >/dev/null

if ! grep -F '| TextEdit | `com.apple.TextEdit` | 2 | `inlineAdjacent|floatingMirror` | lines 1+ in `' "$REPORT_PATH" >/dev/null; then
  echo "manual smoke self-test did not record the successful TextEdit pass" >&2
  exit 1
fi

cat >"$LOG_PATH" <<'EOF'
2026-04-26T08:00:00Z suggestion-presented app=com.apple.TextEdit effectiveRenderMode=inlineAdjacent
EOF

if AUTOCOMPLETE_LAB_LOG="$LOG_PATH" \
  AUTOCOMPLETE_LAB_LOG_START_LINE=0 \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_REPORT="$REPORT_PATH" \
  script/manual_smoke_session.sh textedit --check >"$FAILURE_OUTPUT" 2>&1; then
  echo "manual smoke self-test expected a failed pass without key handling" >&2
  exit 1
fi

if ! grep -F 'Tab autocomplete action: 0' "$FAILURE_OUTPUT" >/dev/null; then
  echo "manual smoke self-test did not explain the missing key action" >&2
  exit 1
fi

echo "Manual smoke recorder self-test passed."
