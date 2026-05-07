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
  cat >"$path" <<'MARKDOWN'
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:00:00Z | TextEdit | `com.apple.TextEdit` | `default` | 2 | `inlineAdjacent|floatingMirror` | lines 10+ | lines 20+; visual `strict-complete` |
| 2026-05-07T12:05:00Z | Codex | `com.openai.codex` | `default` | 1 | `inlineAdjacent` | lines 30+ | lines 40+; visual `strict-complete` |
MARKDOWN
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

write_manifest() {
  local path="$1"
  local status="$2"
  local screenshot="$3"
  local trace_proof_version="${4:-$TRACE_PROOF_VERSION}"
  local manual_app="${5:-TextEdit}"
  local bundle="${6:-com.apple.TextEdit}"
  local proof="${7:-default}"
  local min_accepts="${8:-2}"

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
      "surface": "$manual_app",
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

MANUAL_SMOKE="$TMP_DIR/manual-smoke-runs.md"
SCORECARD="$TMP_DIR/scorecard.md"
PASS_MANIFEST="$TMP_DIR/pass.json"
PENDING_MANIFEST="$TMP_DIR/pending.json"
STALE_MANIFEST="$TMP_DIR/stale.json"
MISSING_SMOKE_MANIFEST="$TMP_DIR/missing-smoke.json"
MISSING_SCREENSHOT_MANIFEST="$TMP_DIR/missing-screenshot.json"

write_manual_smoke "$MANUAL_SMOKE"
write_scorecard "$SCORECARD"
write_manifest "$PASS_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$PENDING_MANIFEST" pending "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$STALE_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png" "old-proof"
write_manifest "$MISSING_SMOKE_MANIFEST" complete "docs/product/visual-placement-screenshots/codex-inline.png" "$TRACE_PROOF_VERSION" "Codex" "com.openai.codex" "default" 2
write_manifest "$MISSING_SCREENSHOT_MANIFEST" complete "docs/product/visual-placement-screenshots/missing-proof.png"

script/check_proof_manifest.sh \
  --manifest "$PASS_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --strict >"$TMP_DIR/pass.out"

if ! grep -F "Proof manifest verified." "$TMP_DIR/pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify complete proof" >&2
  cat "$TMP_DIR/pass.out" >&2
  exit 1
fi

script/check_proof_manifest.sh \
  --manifest "$PENDING_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" >"$TMP_DIR/pending.out"

if ! grep -F "Pending proof:" "$TMP_DIR/pending.out" >/dev/null; then
  echo "proof manifest self-test did not report pending proof" >&2
  cat "$TMP_DIR/pending.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$PENDING_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
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
  --scorecard "$SCORECARD" >"$TMP_DIR/stale.out" 2>&1; then
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
  --scorecard "$SCORECARD" >"$TMP_DIR/missing-smoke.out" 2>&1; then
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
  --scorecard "$SCORECARD" >"$TMP_DIR/missing-screenshot.out" 2>&1; then
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
