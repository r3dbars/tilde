#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

trace="$tmpdir/sensitive-proof.jsonl"
python3 - "$trace" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
categories = [
    "password",
    "otp",
    "payment",
    "login",
    "search",
    "url-address",
    "address",
    "government-id",
    "date-of-birth",
    "tax",
    "insurance",
    "medical",
    "crypto-wallet",
    "command-line",
    "api-key-like-text",
    "password-manager",
    "private-prompt",
    "private-search",
]
browser_surfaces = [
    "google-docs",
    "notion",
    "chatgpt",
    "slack",
    "discord",
    "browser-login",
    "browser-payment",
    "browser-password-manager",
    "browser-private-search",
    "browser-search-or-address-bar",
    "browser-developer-tool",
    "unproven-browser-surface",
]
with path.open("w", encoding="utf-8") as handle:
    for index, category in enumerate(categories, start=1):
        event = {
            "timestamp": "2026-05-08T00:00:00Z",
            "sessionID": "sensitive-self-test",
            "suggestionID": f"sensitive-{index}",
            "type": "suggestionSuppressed",
            "appBundleIdentifier": "local.fixture",
            "requestMode": "wordCompletion",
            "reason": "sensitive-field",
            "metadata": {
                "sensitiveSuppressionCategory": category,
                "sensitiveSuppressionProof": "localFixture",
                "sensitiveSuppressionDecision": "blocked",
                "rawTextIncluded": "false",
            },
        }
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")
    for index, surface in enumerate(browser_surfaces, start=1):
        event = {
            "timestamp": "2026-05-08T00:00:00Z",
            "sessionID": "sensitive-self-test",
            "suggestionID": f"browser-block-{index}",
            "type": "suggestionSuppressed",
            "appBundleIdentifier": "com.google.Chrome",
            "requestMode": "wordCompletion",
            "reason": "unsupported-browser-surface",
            "metadata": {
                "browserSurface": surface,
                "browserSurfaceDecision": "blocked",
                "browserSurfaceReason": "unsupported-surface-needs-proof",
                "blockedSurfaceTextRedacted": "true",
                "rawTextIncluded": "false",
            },
        }
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")
    handle.write(json.dumps({
        "timestamp": "2026-05-08T00:00:00Z",
        "sessionID": "sensitive-self-test",
        "suggestionID": "ordinary",
        "type": "suggestionPresented",
        "appBundleIdentifier": "com.apple.TextEdit",
        "requestMode": "wordCompletion",
        "metadata": {"fieldKind": "multilineCompose"},
    }, separators=(",", ":")) + "\n")
PY

"$(dirname "$0")/check_sensitive_field_proof.sh" "$trace" >/dev/null

leak="$tmpdir/leak.jsonl"
cp "$trace" "$leak"
printf '{"timestamp":"2026-05-08T00:00:00Z","sessionID":"sensitive-self-test","suggestionID":"leak","type":"suggestionPresented","metadata":{"sensitiveSuppressionCategory":"password","sensitiveSuppressionProof":"localFixture","sensitiveSuppressionDecision":"presented"}}\n' >> "$leak"
if "$(dirname "$0")/check_sensitive_field_proof.sh" "$leak" >/dev/null 2>&1; then
  echo "expected sensitive presentation trace to fail" >&2
  exit 1
fi

unsafe_kind="$tmpdir/unsafe-kind.jsonl"
cp "$trace" "$unsafe_kind"
printf '{"timestamp":"2026-05-08T00:00:00Z","sessionID":"sensitive-self-test","suggestionID":"unsafe-kind","type":"suggestionPresented","metadata":{"fieldKind":"search"}}\n' >> "$unsafe_kind"
if "$(dirname "$0")/check_sensitive_field_proof.sh" "$unsafe_kind" >/dev/null 2>&1; then
  echo "expected unsafe field kind presentation trace to fail" >&2
  exit 1
fi

missing="$tmpdir/missing.jsonl"
grep -v '"private-search"' "$trace" > "$missing"
if "$(dirname "$0")/check_sensitive_field_proof.sh" "$missing" >/dev/null 2>&1; then
  echo "expected missing category trace to fail" >&2
  exit 1
fi

missing_browser="$tmpdir/missing-browser.jsonl"
grep -v '"browserSurface":"chatgpt"' "$trace" > "$missing_browser"
if "$(dirname "$0")/check_sensitive_field_proof.sh" "$missing_browser" >/dev/null 2>&1; then
  echo "expected missing browser-hosted block trace to fail" >&2
  exit 1
fi

browser_presented="$tmpdir/browser-presented.jsonl"
cp "$trace" "$browser_presented"
printf '{"timestamp":"2026-05-08T00:00:00Z","sessionID":"sensitive-self-test","suggestionID":"browser-presented","type":"suggestionPresented","metadata":{"browserSurface":"google-docs","browserSurfaceDecision":"blocked"}}\n' >> "$browser_presented"
if "$(dirname "$0")/check_sensitive_field_proof.sh" "$browser_presented" >/dev/null 2>&1; then
  echo "expected browser-hosted presentation trace to fail" >&2
  exit 1
fi

echo "Sensitive field proof self-test passed."
