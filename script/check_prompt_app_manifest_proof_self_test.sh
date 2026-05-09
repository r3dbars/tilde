#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PATH="$TMP_DIR/traces.jsonl"
SMOKE_PATH="$TMP_DIR/manual-smoke-runs.md"
MANIFEST_PATH="$TMP_DIR/proof-manifest.json"

cat >"$TRACE_PATH" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"safe","screenshotPath":"/tmp/codex.png","metadata":{"promptSafetyMode":"wordOnly"}}
{"type":"suggestionAccepted","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"insertionVerified","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","outcome":"verified","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"acceptedTextEdited","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","outcome":"exactKept","metadata":{"checkpoint":"10s","promptSafetyMode":"wordOnly"}}
{"type":"suggestionHidden","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","outcome":"accepted"}
{"type":"suggestionSuppressed","suggestionID":"old-failure","appBundleIdentifier":"com.openai.codex","reason":"wrong-app-or-field-before-accept","metadata":{"acceptanceGuardReason":"app-changed-before-accept"}}
JSONL

cat >"$SMOKE_PATH" <<EOF
| Date | App | Bundle | Proof | Accepts | Render modes | Diagnostics | Trace |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-09T03:06:50Z | Codex | \`com.openai.codex\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 1-5 in \`/tmp/diagnostics.log\` | lines 1-5 in \`$TRACE_PATH\`; visual \`strict-complete\`; prompt no-submit confirmed |
EOF

cat >"$MANIFEST_PATH" <<'JSON'
{
  "schemaVersion": 1,
  "surfaces": [
    {
      "surface": "Codex",
      "status": "complete",
      "manualSmoke": {
        "app": "Codex",
        "bundle": "com.openai.codex",
        "proof": "default",
        "minVerifiedAccepts": 1,
        "maxVerifiedAccepts": 1,
        "requiresVisualStrictComplete": true
      },
      "screenshots": ["docs/product/visual-placement-screenshots/codex-inline.png"],
      "gaps": []
    }
  ]
}
JSON

AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$SMOKE_PATH" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/pass.txt"

for expected in \
  "Prompt app manifest proof status" \
  "Codex: com.openai.codex proof=default lines 1-5" \
  "wrongContextInsertionCount: 0" \
  "Prompt app manifest proof gate passed with 1 bounded prompt slice(s)."; do
  if ! grep -F "$expected" "$TMP_DIR/pass.txt" >/dev/null; then
    echo "prompt app manifest proof self-test missing output: $expected" >&2
    cat "$TMP_DIR/pass.txt" >&2
    exit 1
  fi
done

sed 's/; prompt no-submit confirmed//' "$SMOKE_PATH" >"$TMP_DIR/no-submit-missing.md"
if AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$TMP_DIR/no-submit-missing.md" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/fail.txt" 2>&1; then
  echo "prompt app manifest proof self-test expected missing no-submit label to fail" >&2
  cat "$TMP_DIR/fail.txt" >&2
  exit 1
fi

if ! grep -F "no bounded strict prompt smoke row" "$TMP_DIR/fail.txt" >/dev/null; then
  echo "prompt app manifest proof self-test did not explain missing no-submit proof" >&2
  cat "$TMP_DIR/fail.txt" >&2
  exit 1
fi

echo "Prompt app manifest proof self-test passed."
