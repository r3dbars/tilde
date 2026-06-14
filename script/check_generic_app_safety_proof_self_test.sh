#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

trace="$tmpdir/generic-app-safety.jsonl"
python3 - "$trace" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

# category -> suppressing field kind the live classifier produces.
silent = {
    "secure-field": "secure",
    "password": "secure",
    "payment": "form",
    "search": "search",
    "url-address": "url",
    "login": "form",
    "form-field": "form",
    "command-prompt": "unprovenSurface",
    "unknown-field": "unknown",
}
present = {
    "multiline-compose": "multilineCompose",
    "singleline-compose": "singlelineCompose",
}

with path.open("w", encoding="utf-8") as handle:
    for index, (category, field_kind) in enumerate(silent.items(), start=1):
        event = {
            "timestamp": "2026-06-13T00:00:00Z",
            "sessionID": "generic-app-self-test",
            "suggestionID": f"silent-{index}",
            "type": "suggestionSuppressed",
            "appBundleIdentifier": "com.example.unknownapp",
            "requestMode": "wordCompletion",
            "reason": "generic-fallback-wrong-field",
            "metadata": {
                "genericAppFieldCategory": category,
                "genericAppExpectation": "silent",
                "genericAppRouterDecision": "suppressed",
                "genericAppLiveDecision": "blocked",
                "genericAppFallbackResolved": "true",
                "fieldKind": field_kind,
                "rawTextIncluded": "false",
            },
        }
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")

    for index, (category, field_kind) in enumerate(present.items(), start=1):
        event = {
            "timestamp": "2026-06-13T00:00:00Z",
            "sessionID": "generic-app-self-test",
            "suggestionID": f"present-{index}",
            "type": "suggestionPresented",
            "appBundleIdentifier": "com.example.unknownapp",
            "requestMode": "phraseContinuation",
            "metadata": {
                "genericAppFieldCategory": category,
                "genericAppExpectation": "present",
                "genericAppRouterDecision": "allowed",
                "genericAppLiveDecision": "presented",
                "genericAppFallbackResolved": "true",
                "fieldKind": field_kind,
                "rawTextIncluded": "false",
            },
        }
        handle.write(json.dumps(event, separators=(",", ":")) + "\n")

    # An unrelated known-app event must be ignored by the generic gate.
    handle.write(json.dumps({
        "timestamp": "2026-06-13T00:00:00Z",
        "sessionID": "generic-app-self-test",
        "suggestionID": "unrelated",
        "type": "suggestionPresented",
        "appBundleIdentifier": "com.apple.TextEdit",
        "requestMode": "wordCompletion",
        "metadata": {"fieldKind": "multilineCompose"},
    }, separators=(",", ":")) + "\n")
PY

check="$(dirname "$0")/check_generic_app_safety_proof.sh"

"$check" "$trace" >/dev/null

expect_fail() {
  local label="$1"
  local candidate="$2"
  if "$check" "$candidate" >/dev/null 2>&1; then
    echo "expected $label trace to fail" >&2
    exit 1
  fi
}

silent_presented="$tmpdir/silent-presented.jsonl"
cp "$trace" "$silent_presented"
printf '%s\n' '{"type":"suggestionPresented","metadata":{"genericAppFieldCategory":"search","genericAppExpectation":"silent","genericAppRouterDecision":"suppressed","genericAppLiveDecision":"blocked","genericAppFallbackResolved":"true","fieldKind":"search","rawTextIncluded":"false"}}' >> "$silent_presented"
expect_fail "silent-field presentation" "$silent_presented"

wrong_field="$tmpdir/wrong-field.jsonl"
cp "$trace" "$wrong_field"
printf '%s\n' '{"type":"suggestionPresented","metadata":{"genericAppFieldCategory":"multiline-compose","genericAppExpectation":"present","genericAppRouterDecision":"allowed","genericAppLiveDecision":"presented","genericAppFallbackResolved":"true","fieldKind":"form","rawTextIncluded":"false"}}' >> "$wrong_field"
expect_fail "wrong-field compose presentation" "$wrong_field"

router_inconsistent="$tmpdir/router-inconsistent.jsonl"
cp "$trace" "$router_inconsistent"
printf '%s\n' '{"type":"suggestionSuppressed","metadata":{"genericAppFieldCategory":"login","genericAppExpectation":"silent","genericAppRouterDecision":"allowed","genericAppLiveDecision":"blocked","genericAppFallbackResolved":"true","fieldKind":"form","rawTextIncluded":"false"}}' >> "$router_inconsistent"
expect_fail "router/live inconsistency" "$router_inconsistent"

fallback_unresolved="$tmpdir/fallback-unresolved.jsonl"
cp "$trace" "$fallback_unresolved"
printf '%s\n' '{"type":"suggestionSuppressed","metadata":{"genericAppFieldCategory":"payment","genericAppExpectation":"silent","genericAppRouterDecision":"suppressed","genericAppLiveDecision":"blocked","genericAppFallbackResolved":"false","fieldKind":"form","rawTextIncluded":"false"}}' >> "$fallback_unresolved"
expect_fail "fallback-not-resolved" "$fallback_unresolved"

missing_silent="$tmpdir/missing-silent.jsonl"
grep -v '"unknown-field"' "$trace" > "$missing_silent"
expect_fail "missing suppressed category" "$missing_silent"

missing_present="$tmpdir/missing-present.jsonl"
grep -v '"multiline-compose"' "$trace" > "$missing_present"
expect_fail "missing presented compose control" "$missing_present"

raw_leak="$tmpdir/raw-leak.jsonl"
cp "$trace" "$raw_leak"
printf '%s\n' '{"type":"suggestionSuppressed","metadata":{"genericAppFieldCategory":"search","genericAppExpectation":"silent","genericAppRouterDecision":"suppressed","genericAppLiveDecision":"blocked","genericAppFallbackResolved":"true","fieldKind":"search","rawTextIncluded":"false","leakedContext":"the quick brown fox jumps"}}' >> "$raw_leak"
expect_fail "raw fixture text leak" "$raw_leak"

echo "Generic app safety proof self-test passed."
