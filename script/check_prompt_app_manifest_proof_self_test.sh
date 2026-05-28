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
{"type":"suggestionPresented","suggestionID":"claude-safe-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","displayedText":"safe","screenshotPath":"/tmp/claude.png","metadata":{"promptSafetyMode":"wordOnly"}}
{"type":"suggestionAccepted","suggestionID":"claude-safe-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","acceptedText":"safe","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"insertionVerified","suggestionID":"claude-safe-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","acceptedText":"safe","outcome":"verified","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"acceptedTextEdited","suggestionID":"claude-safe-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","acceptedText":"safe","outcome":"exactKept","metadata":{"checkpoint":"10s","promptSafetyMode":"wordOnly"}}
{"type":"suggestionHidden","suggestionID":"claude-safe-one","appBundleIdentifier":"com.anthropic.claude-code","requestMode":"wordCompletion","outcome":"accepted"}
{"type":"suggestionPresented","suggestionID":"codex-full-safe","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","displayedText":"finish this thought","screenshotPath":"/tmp/codex-full.png","metadata":{"promptSafetyMode":"fullAcceptProof"}}
{"type":"suggestionAccepted","suggestionID":"codex-full-safe","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"finish this thought","metadata":{"acceptMode":"acceptAllVisible","acceptedVisibleScope":"fullVisible","promptSafetyMode":"fullAcceptProof"}}
{"type":"insertionVerified","suggestionID":"codex-full-safe","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"finish this thought","outcome":"verified","metadata":{"acceptMode":"acceptAllVisible","acceptedVisibleScope":"fullVisible","promptSafetyMode":"fullAcceptProof"}}
{"type":"acceptedTextEdited","suggestionID":"codex-full-safe","appBundleIdentifier":"com.openai.codex","requestMode":"phraseContinuation","acceptedText":"finish this thought","outcome":"exactKept","metadata":{"acceptMode":"acceptAllVisible","acceptedVisibleScope":"fullVisible","checkpoint":"10s","promptSafetyMode":"fullAcceptProof"}}
JSONL

cat >"$SMOKE_PATH" <<EOF
| Date | App | Bundle | Proof | Accepts | Render modes | Diagnostics | Trace |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-09T03:06:50Z | Codex | \`com.openai.codex\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 1-5 in \`/tmp/diagnostics.log\` | lines 1-5 in \`$TRACE_PATH\`; visual \`strict-complete\`; prompt no-submit confirmed |
| 2026-05-09T03:07:50Z | Claude Code | \`com.anthropic.claude-code\` | \`default\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 6-10 in \`/tmp/diagnostics.log\` | lines 7-11 in \`$TRACE_PATH\`; visual \`strict-complete\`; prompt no-submit confirmed |
| 2026-05-09T03:08:50Z | Codex | \`com.openai.codex\` | \`full-accept\` | 1 | \`inlineAdjacent|floatingMirror\` | lines 11-14 in \`/tmp/diagnostics.log\` | lines 12-15 in \`$TRACE_PATH\`; visual \`strict-complete\`; prompt full-accept no-submit confirmed |
EOF

cat >"$MANIFEST_PATH" <<'JSON'
{
  "schemaVersion": 1,
  "surfaces": [
    {
      "surface": "Codex",
      "status": "partial",
      "manualSmoke": {
        "app": "Codex",
        "bundle": "com.openai.codex",
        "proof": "default",
        "minVerifiedAccepts": 1,
        "maxVerifiedAccepts": 1,
        "requiresVisualStrictComplete": true
      },
      "screenshots": ["docs/product/visual-placement-screenshots/codex-inline.png"],
      "gaps": [
        "Default one-word no-submit proof exists, but full accept remains blocked."
      ],
      "requirements": [
        {
          "id": "codex-one-word-no-submit",
          "status": "complete",
          "summary": "Bounded one-word no-submit prompt proof is recorded.",
          "manualSmoke": {
            "app": "Codex",
            "bundle": "com.openai.codex",
            "proof": "default",
            "minVerifiedAccepts": 1,
            "maxVerifiedAccepts": 1,
            "requiresVisualStrictComplete": true
          }
        },
        {
          "id": "codex-full-accept-no-submit",
          "status": "complete",
          "summary": "Full accept no-submit proof is recorded separately.",
          "manualSmoke": {
            "app": "Codex",
            "bundle": "com.openai.codex",
            "proof": "full-accept",
            "minVerifiedAccepts": 1,
            "maxVerifiedAccepts": 1,
            "requiresVisualStrictComplete": true,
            "requiresPromptFullAcceptNoSubmit": true
          }
        }
      ]
    },
    {
      "surface": "Claude Code",
      "status": "partial",
      "requirements": [
        {
          "id": "claude-code-one-word-no-submit",
          "status": "complete",
          "summary": "Bounded one-word no-submit prompt proof is recorded.",
          "manualSmoke": {
            "app": "Claude Code",
            "bundle": "com.anthropic.claude-code",
            "proof": "default",
            "minVerifiedAccepts": 1,
            "maxVerifiedAccepts": 1,
            "requiresVisualStrictComplete": true
          }
        }
      ]
    }
  ]
}
JSON

AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$SMOKE_PATH" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/pass.txt"

for expected in \
  "Prompt app manifest proof status" \
  "Codex / codex-one-word-no-submit: com.openai.codex proof=default lines 1-5" \
  "Codex / codex-full-accept-no-submit: com.openai.codex proof=full-accept lines 12-15" \
  "Claude Code / claude-code-one-word-no-submit: com.anthropic.claude-code proof=default lines 7-11" \
  "wrongContextInsertionCount: 0" \
  "Prompt app manifest proof gate passed with 3 bounded prompt slice(s)."; do
  if ! grep -F "$expected" "$TMP_DIR/pass.txt" >/dev/null; then
    echo "prompt app manifest proof self-test missing output: $expected" >&2
    cat "$TMP_DIR/pass.txt" >&2
    exit 1
  fi
done

awk 'BEGIN { done = 0 } !done && /prompt no-submit confirmed/ { sub(/; prompt no-submit confirmed/, ""); done = 1 } { print }' \
  "$SMOKE_PATH" >"$TMP_DIR/no-submit-missing.md"
if AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$TMP_DIR/no-submit-missing.md" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/fail.txt" 2>&1; then
  echo "prompt app manifest proof self-test expected missing no-submit label to fail" >&2
  cat "$TMP_DIR/fail.txt" >&2
  exit 1
fi

if ! grep -F "missing prompt no-submit confirmed" "$TMP_DIR/fail.txt" >/dev/null; then
  echo "prompt app manifest proof self-test did not explain missing no-submit proof" >&2
  cat "$TMP_DIR/fail.txt" >&2
  exit 1
fi

awk '/Claude Code/ { sub(/; prompt no-submit confirmed/, "") } { print }' \
  "$SMOKE_PATH" >"$TMP_DIR/claude-no-submit-missing.md"
if AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$TMP_DIR/claude-no-submit-missing.md" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/claude-fail.txt" 2>&1; then
  echo "prompt app manifest proof self-test expected non-Codex missing no-submit label to fail" >&2
  cat "$TMP_DIR/claude-fail.txt" >&2
  exit 1
fi

if ! grep -F "Claude Code / claude-code-one-word-no-submit: missing prompt no-submit confirmed" "$TMP_DIR/claude-fail.txt" >/dev/null; then
  echo "prompt app manifest proof self-test did not require non-Codex no-submit proof" >&2
  cat "$TMP_DIR/claude-fail.txt" >&2
  exit 1
fi

sed 's/; prompt full-accept no-submit confirmed//' \
  "$SMOKE_PATH" >"$TMP_DIR/full-accept-no-submit-missing.md"
if AUTOCOMPLETE_LAB_PROOF_MANIFEST="$MANIFEST_PATH" \
  AUTOCOMPLETE_LAB_MANUAL_SMOKE_RUNS="$TMP_DIR/full-accept-no-submit-missing.md" \
  ./script/check_prompt_app_manifest_proof.sh >"$TMP_DIR/full-accept-fail.txt" 2>&1; then
  echo "prompt app manifest proof self-test expected missing full-accept no-submit label to fail" >&2
  cat "$TMP_DIR/full-accept-fail.txt" >&2
  exit 1
fi

if ! grep -F "Codex / codex-full-accept-no-submit: missing prompt full-accept no-submit confirmed" "$TMP_DIR/full-accept-fail.txt" >/dev/null; then
  echo "prompt app manifest proof self-test did not require full-accept no-submit proof" >&2
  cat "$TMP_DIR/full-accept-fail.txt" >&2
  exit 1
fi

echo "Prompt app manifest proof self-test passed."
