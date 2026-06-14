#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOG_PATH="$TMP_DIR/diagnostics.log"
TRACE_PATH="$TMP_DIR/traces.jsonl"
OUT_DIR="$TMP_DIR/proof-export"

cat >"$LOG_PATH" <<'EOF'
2026-06-13T00:00:00Z launch accessibility=true
2026-06-13T00:00:01Z runtime app=com.openai.codex readinessStage=ready
2026-06-13T00:00:02Z suggestion-presented app=com.openai.codex effectiveRenderMode=inlineAdjacent placementAnchorSource=synthetic-caret placementConfidenceBand=medium rawText=AUTOCOMPLETE_LAB_CODEX_PROOF private prompt
2026-06-13T00:00:03Z keyboard-event-tap-latency key=tab sourcePid=123 targetPid=456 rawText=AUTOCOMPLETE_LAB_CODEX_PROOF private prompt
2026-06-13T00:00:04Z keyboard-action app=com.openai.codex key=tab action=acceptNextWord handled=true rawText=AUTOCOMPLETE_LAB_CODEX_PROOF private prompt
2026-06-13T00:00:05Z insert app=com.openai.codex success=true mode=keyEvents rawText=AUTOCOMPLETE_LAB_CODEX_PROOF private prompt
2026-06-13T00:00:06Z insert-verification app=com.openai.codex result=verified acceptedText=private raw text
EOF

cat >"$TRACE_PATH" <<'EOF'
{"type":"suggestionPresented","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"private raw text","metadata":{"anchorSource":"synthetic-caret","placementConfidenceBand":"medium","rawText":"AUTOCOMPLETE_LAB_CODEX_PROOF private prompt"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"private raw text","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"noSubmit"}}
{"type":"insertionVerified","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"private raw text","metadata":{"acceptMode":"acceptNextWord"}}
EOF

script/real_app_smoke_proof_export.sh \
  --app com.openai.codex \
  --label default \
  --out "$OUT_DIR" \
  --log "$LOG_PATH" \
  --trace "$TRACE_PATH" \
  --log-start 0 \
  --trace-start 0 \
  --outcome passed \
  --reason "self-test" \
  --next-step "none" \
  --command "script/real_app_smoke.sh codex --manual-gate" >"$TMP_DIR/export.txt"

for required in README.md status.json diagnostic-counts.txt redacted-diagnostics.tsv redacted-trace-events.jsonl; do
  if [[ ! -f "$OUT_DIR/$required" ]]; then
    echo "proof export self-test missing $required" >&2
    exit 1
  fi
done

grep -F "suggestion_presented=1" "$OUT_DIR/diagnostic-counts.txt" >/dev/null
grep -F "tab_accept_handled=1" "$OUT_DIR/diagnostic-counts.txt" >/dev/null
grep -F "insertion_verified=1" "$OUT_DIR/diagnostic-counts.txt" >/dev/null
grep -F '"privacy": "redacted metadata and counts only"' "$OUT_DIR/status.json" >/dev/null
grep -F '"type": "suggestionAccepted"' "$OUT_DIR/redacted-trace-events.jsonl" >/dev/null
grep -F '"acceptMode": "acceptNextWord"' "$OUT_DIR/redacted-trace-events.jsonl" >/dev/null

if grep -R -F "AUTOCOMPLETE_LAB_CODEX_PROOF private prompt" "$OUT_DIR" >/dev/null; then
  echo "proof export leaked raw prompt text" >&2
  exit 1
fi
if grep -R -F "private raw text" "$OUT_DIR" >/dev/null; then
  echo "proof export leaked raw accepted text" >&2
  exit 1
fi
if grep -R -F "rawText" "$OUT_DIR" >/dev/null; then
  echo "proof export leaked raw trace metadata keys" >&2
  exit 1
fi

echo "Real app smoke proof export self-test passed."
