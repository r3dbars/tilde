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
    "command-line",
    "api-key-like-text",
    "password-manager",
    "private-prompt",
    "private-search",
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

echo "Sensitive field proof self-test passed."
