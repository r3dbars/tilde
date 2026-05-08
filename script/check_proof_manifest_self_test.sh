#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TRACE_PROOF_VERSION="$(awk -F '"' '/traceProofVersion/ { print $2; exit }' Sources/AutocompleteLabCore/Tracing/AutocompleteTraceProofMetadata.swift)"
PLACEMENT_PROOF_VERSION="$(awk -F '"' '/placementProofVersion/ { print $2; exit }' Sources/AutocompleteLabCore/Tracing/AutocompleteTraceProofMetadata.swift)"
KEY_CAPTURE_PROOF_VERSION="$(awk -F '"' '/keyCaptureProofVersion/ { print $2; exit }' Sources/AutocompleteLabCore/Tracing/AutocompleteTraceProofMetadata.swift)"
RUNTIME_PROOF_VERSION="$(awk -F '"' '/runtimeProofVersion/ { print $2; exit }' Sources/AutocompleteLabCore/Tracing/AutocompleteTraceProofMetadata.swift)"

write_manual_smoke() {
  local path="$1"
  local trace_path="$2"
  cat >"$path" <<MARKDOWN
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 10+ | lines 20-25 in \`$trace_path\`; visual \`strict-complete\` |
| 2026-05-07T12:05:00Z | Codex | \`com.openai.codex\` | \`default\` | 1 | \`inlineAdjacent\` | lines 30+ | lines 40-44 in \`$trace_path\`; visual \`strict-complete\` |
MARKDOWN
}

write_unbounded_manual_smoke() {
  local path="$1"
  local trace_path="$2"
  cat >"$path" <<MARKDOWN
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 10+ | lines 20+ in \`$trace_path\`; visual \`strict-complete\` |
MARKDOWN
}

write_trace() {
  local path="$1"
  : >"$path"
  for _ in $(seq 1 19); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done

  cat >>"$path" <<JSONL
{"type":"suggestionRequested","appBundleIdentifier":"com.apple.TextEdit","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","screenshotPath":"docs/product/visual-placement-screenshots/textedit-inline.png","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","outcome":"verified","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","outcome":"verified","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
JSONL
}

write_stale_trace() {
  local path="$1"
  : >"$path"
  for _ in $(seq 1 19); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done

  cat >>"$path" <<'JSONL'
{"type":"suggestionRequested","appBundleIdentifier":"com.apple.TextEdit","metadata":{}}
{"type":"suggestionPresented","appBundleIdentifier":"com.apple.TextEdit","screenshotPath":"docs/product/visual-placement-screenshots/textedit-inline.png","metadata":{}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","metadata":{}}
{"type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","outcome":"verified","metadata":{}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","metadata":{}}
{"type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","outcome":"verified","metadata":{}}
JSONL
}

write_scorecard() {
  local path="$1"
  cat >"$path" <<'MARKDOWN'
# Scorecard

## Visual Placement And Text Box Audit

| App or surface | Grade | Evidence | What is good | What still needs work |
| --- | ---: | --- | --- | --- |
| TextEdit | 10/10 | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Good. | Done. |
| Codex | 10/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Good. | Done. |
| Missing | 10/10 | [missing-proof.png](visual-placement-screenshots/missing-proof.png) | Missing. | Done. |
MARKDOWN
}

write_app_proof_matrix() {
  local path="$1"
  cat >"$path" <<'MARKDOWN'
# App Proof Matrix

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Complete. | Reference proof. | More variants. |
| Obsidian | A- | [obsidian.png](visual-placement-screenshots/obsidian.png) | Partial. | Strong but variant-incomplete. | More variants. |
| Codex | B- | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Partial. | Prompt proof missing. | No-submit proof. |
MARKDOWN
}

write_manifest() {
  local path="$1"
  local status="$2"
  local screenshot="$3"
  local trace_proof_version="${4:-$TRACE_PROOF_VERSION}"
  local manual_app="${5:-TextEdit}"
  local bundle="${6:-com.apple.TextEdit}"
  local proof="${7:-default}"
  local min_accepts="${8:-2}"
  local surface="${9:-$manual_app}"

  local gaps_json="[]"
  if [[ "$status" != "complete" ]]; then
    gaps_json='["still needs proof"]'
  fi

  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "proofFingerprint": {
    "traceProofVersion": "$trace_proof_version",
    "placementProofVersion": "$PLACEMENT_PROOF_VERSION",
    "keyCaptureProofVersion": "$KEY_CAPTURE_PROOF_VERSION",
    "runtimeProofVersion": "$RUNTIME_PROOF_VERSION"
  },
  "surfaces": [
    {
      "surface": "$surface",
      "status": "$status",
      "manualSmoke": {
        "app": "$manual_app",
        "bundle": "$bundle",
        "proof": "$proof",
        "minVerifiedAccepts": $min_accepts,
        "requiresVisualStrictComplete": true
      },
      "screenshots": [
        "$screenshot"
      ],
      "gaps": $gaps_json
    }
  ]
}
JSON
}

write_profile_source() {
  local path="$1"
  cat >"$path" <<'SWIFT'
public struct CompatibilityProfileStore {
    public static let mvp = [
        CompatibilityProfile(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            supportLevel: .green,
            notes: "fixture"
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            supportLevel: .yellow,
            notes: "fixture"
        )
    ]
}
SWIFT
}

write_profile_manifest() {
  local path="$1"
  local include_codex="${2:-yes}"
  local codex_row=""
  if [[ "$include_codex" == "yes" ]]; then
    codex_row=', {
      "bundle": "com.openai.codex",
      "displayName": "Codex",
      "supportLevel": "yellow",
      "surface": "Codex",
      "status": "partial",
      "owner": "prompt-app proof lane",
      "safetyNote": "Codex needs one-word no-submit proof."
    }'
  fi

  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "proofFingerprint": {
    "traceProofVersion": "$TRACE_PROOF_VERSION",
    "placementProofVersion": "$PLACEMENT_PROOF_VERSION",
    "keyCaptureProofVersion": "$KEY_CAPTURE_PROOF_VERSION",
    "runtimeProofVersion": "$RUNTIME_PROOF_VERSION"
  },
  "surfaces": [
    {
      "surface": "TextEdit",
      "status": "complete",
      "manualSmoke": {
        "app": "TextEdit",
        "bundle": "com.apple.TextEdit",
        "proof": "default",
        "minVerifiedAccepts": 2,
        "requiresVisualStrictComplete": true
      },
      "screenshots": [
        "docs/product/visual-placement-screenshots/textedit-inline.png"
      ],
      "gaps": []
    }
  ],
  "profileCoverage": [
    {
      "bundle": "com.apple.TextEdit",
      "displayName": "TextEdit",
      "supportLevel": "green",
      "surface": "TextEdit",
      "status": "complete",
      "owner": "core proof lane",
      "safetyNote": "TextEdit is the green reference proof target."
    }$codex_row
  ]
}
JSON
}
MANUAL_SMOKE="$TMP_DIR/manual-smoke-runs.md"
UNBOUNDED_MANUAL_SMOKE="$TMP_DIR/manual-smoke-runs-unbounded.md"
TRACE_FILE="$TMP_DIR/traces.jsonl"
STALE_TRACE_FILE="$TMP_DIR/stale-traces.jsonl"
SCORECARD="$TMP_DIR/scorecard.md"
APP_PROOF_MATRIX="$TMP_DIR/app-proof-matrix.md"
PASS_MANIFEST="$TMP_DIR/pass.json"
PARTIAL_MANIFEST="$TMP_DIR/partial.json"
PENDING_MANIFEST="$TMP_DIR/pending.json"
A_MINUS_COMPLETE_MANIFEST="$TMP_DIR/a-minus-complete.json"
STALE_MANIFEST="$TMP_DIR/stale.json"
MISSING_SMOKE_MANIFEST="$TMP_DIR/missing-smoke.json"
MISSING_SCREENSHOT_MANIFEST="$TMP_DIR/missing-screenshot.json"
PROFILE_SOURCE="$TMP_DIR/CompatibilityProfile.swift"
PROFILE_MANIFEST="$TMP_DIR/profile-pass.json"
MISSING_PROFILE_MANIFEST="$TMP_DIR/profile-missing.json"

write_trace "$TRACE_FILE"
write_stale_trace "$STALE_TRACE_FILE"
write_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"
write_unbounded_manual_smoke "$UNBOUNDED_MANUAL_SMOKE" "$TRACE_FILE"
write_scorecard "$SCORECARD"
write_app_proof_matrix "$APP_PROOF_MATRIX"
write_manifest "$PASS_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$PARTIAL_MANIFEST" partial "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$PENDING_MANIFEST" pending "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$A_MINUS_COMPLETE_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png" "$TRACE_PROOF_VERSION" "TextEdit" "com.apple.TextEdit" "default" 2 "Obsidian"
write_manifest "$STALE_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png" "old-proof"
write_manifest "$MISSING_SMOKE_MANIFEST" complete "docs/product/visual-placement-screenshots/codex-inline.png" "$TRACE_PROOF_VERSION" "Codex" "com.openai.codex" "default" 2
write_manifest "$MISSING_SCREENSHOT_MANIFEST" complete "docs/product/visual-placement-screenshots/missing-proof.png"
write_profile_source "$PROFILE_SOURCE"
write_profile_manifest "$PROFILE_MANIFEST" yes
write_profile_manifest "$MISSING_PROFILE_MANIFEST" no

script/check_proof_manifest.sh \
  --manifest "$PASS_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/pass.out"

if ! grep -F "Proof manifest verified." "$TMP_DIR/pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify complete proof" >&2
  cat "$TMP_DIR/pass.out" >&2
  exit 1
fi

script/check_proof_manifest.sh \
  --manifest "$PASS_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --verify-trace-slices >"$TMP_DIR/pass-trace.out"

if ! grep -F "Verified trace slices: 1" "$TMP_DIR/pass-trace.out" >/dev/null; then
  echo "proof manifest self-test did not verify the trace slice" >&2
  cat "$TMP_DIR/pass-trace.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$A_MINUS_COMPLETE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/a-minus-complete.out" 2>&1; then
  echo "proof manifest self-test expected strict A- complete proof to fail" >&2
  cat "$TMP_DIR/a-minus-complete.out" >&2
  exit 1
fi

if ! grep -F "app proof matrix grade is A-" "$TMP_DIR/a-minus-complete.out" >/dev/null; then
  echo "proof manifest self-test did not explain A- complete proof mismatch" >&2
  cat "$TMP_DIR/a-minus-complete.out" >&2
  exit 1
fi

script/check_proof_manifest.sh \
  --manifest "$PARTIAL_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --verify-trace-slices >"$TMP_DIR/partial-trace.out"

if ! grep -F "Partial proof:" "$TMP_DIR/partial-trace.out" >/dev/null; then
  echo "proof manifest self-test did not report partial live proof" >&2
  cat "$TMP_DIR/partial-trace.out" >&2
  exit 1
fi

if ! grep -F "Verified trace slices: 1" "$TMP_DIR/partial-trace.out" >/dev/null; then
  echo "proof manifest self-test did not verify partial live proof trace slices" >&2
  cat "$TMP_DIR/partial-trace.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$PARTIAL_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/partial-strict.out" 2>&1; then
  echo "proof manifest self-test expected strict partial proof to fail" >&2
  cat "$TMP_DIR/partial-strict.out" >&2
  exit 1
fi

if ! grep -F "proof is partial, not complete" "$TMP_DIR/partial-strict.out" >/dev/null; then
  echo "proof manifest self-test did not explain strict partial live proof" >&2
  cat "$TMP_DIR/partial-strict.out" >&2
  exit 1
fi

script/check_proof_manifest.sh \
  --manifest "$PROFILE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --compatibility-profiles "$PROFILE_SOURCE" >"$TMP_DIR/profile-pass.out"

if ! grep -F "Profile coverage rows: 2" "$TMP_DIR/profile-pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify profile coverage" >&2
  cat "$TMP_DIR/profile-pass.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$MISSING_PROFILE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --compatibility-profiles "$PROFILE_SOURCE" >"$TMP_DIR/profile-missing.out" 2>&1; then
  echo "proof manifest self-test expected missing profile coverage to fail" >&2
  cat "$TMP_DIR/profile-missing.out" >&2
  exit 1
fi

if ! grep -F "profileCoverage missing bundle(s): com.openai.codex" "$TMP_DIR/profile-missing.out" >/dev/null; then
  echo "proof manifest self-test did not explain missing profile coverage" >&2
  cat "$TMP_DIR/profile-missing.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$PASS_MANIFEST" \
  --manual-smoke "$UNBOUNDED_MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/unbounded-strict.out" 2>&1; then
  echo "proof manifest self-test expected strict unbounded trace proof to fail" >&2
  cat "$TMP_DIR/unbounded-strict.out" >&2
  exit 1
fi

if ! grep -F "trace proof must use bounded line evidence" "$TMP_DIR/unbounded-strict.out" >/dev/null; then
  echo "proof manifest self-test did not explain unbounded trace proof" >&2
  cat "$TMP_DIR/unbounded-strict.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$STALE_TRACE_FILE"

if script/check_proof_manifest.sh \
  --manifest "$PASS_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/stale-trace.out" 2>&1; then
  echo "proof manifest self-test expected stale trace proof to fail" >&2
  cat "$TMP_DIR/stale-trace.out" >&2
  exit 1
fi

if ! grep -F "proof events are missing current proof fingerprints" "$TMP_DIR/stale-trace.out" >/dev/null; then
  echo "proof manifest self-test did not explain stale trace proof" >&2
  cat "$TMP_DIR/stale-trace.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"

script/check_proof_manifest.sh \
  --manifest "$PENDING_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage >"$TMP_DIR/pending.out"

if ! grep -F "Pending proof:" "$TMP_DIR/pending.out" >/dev/null; then
  echo "proof manifest self-test did not report pending proof" >&2
  cat "$TMP_DIR/pending.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$PENDING_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/pending-strict.out" 2>&1; then
  echo "proof manifest self-test expected strict pending proof to fail" >&2
  cat "$TMP_DIR/pending-strict.out" >&2
  exit 1
fi

if ! grep -F "proof is pending, not complete" "$TMP_DIR/pending-strict.out" >/dev/null; then
  echo "proof manifest self-test did not explain strict pending proof" >&2
  cat "$TMP_DIR/pending-strict.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$STALE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage >"$TMP_DIR/stale.out" 2>&1; then
  echo "proof manifest self-test expected stale fingerprint to fail" >&2
  cat "$TMP_DIR/stale.out" >&2
  exit 1
fi

if ! grep -F "proofFingerprint.traceProofVersion" "$TMP_DIR/stale.out" >/dev/null; then
  echo "proof manifest self-test did not explain stale fingerprint" >&2
  cat "$TMP_DIR/stale.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$MISSING_SMOKE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage >"$TMP_DIR/missing-smoke.out" 2>&1; then
  echo "proof manifest self-test expected missing smoke proof to fail" >&2
  cat "$TMP_DIR/missing-smoke.out" >&2
  exit 1
fi

if ! grep -F "no manual smoke row" "$TMP_DIR/missing-smoke.out" >/dev/null; then
  echo "proof manifest self-test did not explain missing smoke proof" >&2
  cat "$TMP_DIR/missing-smoke.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$MISSING_SCREENSHOT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage >"$TMP_DIR/missing-screenshot.out" 2>&1; then
  echo "proof manifest self-test expected missing screenshot to fail" >&2
  cat "$TMP_DIR/missing-screenshot.out" >&2
  exit 1
fi

if ! grep -F "screenshot missing" "$TMP_DIR/missing-screenshot.out" >/dev/null; then
  echo "proof manifest self-test did not explain missing screenshot" >&2
  cat "$TMP_DIR/missing-screenshot.out" >&2
  exit 1
fi

echo "Proof manifest self-test passed."
