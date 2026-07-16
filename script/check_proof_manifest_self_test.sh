#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
DIRTY_PROOF_PATH=""
DIRTY_TRACKED_PROOF_SCRIPT=""
DIRTY_TRACKED_PROOF_SCRIPT_BACKUP=""

restore_dirty_tracked_proof_script() {
  if [[ -n "${DIRTY_TRACKED_PROOF_SCRIPT:-}" && -n "${DIRTY_TRACKED_PROOF_SCRIPT_BACKUP:-}" && -f "$DIRTY_TRACKED_PROOF_SCRIPT_BACKUP" ]]; then
    cp -p "$DIRTY_TRACKED_PROOF_SCRIPT_BACKUP" "$DIRTY_TRACKED_PROOF_SCRIPT"
  fi
  DIRTY_TRACKED_PROOF_SCRIPT=""
  DIRTY_TRACKED_PROOF_SCRIPT_BACKUP=""
}

cleanup() {
  restore_dirty_tracked_proof_script
  if [[ -n "${DIRTY_PROOF_PATH:-}" ]]; then
    rm -f "$DIRTY_PROOF_PATH"
  fi
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

TRACE_PROOF_VERSION="$(awk -F '"' '/traceProofVersion/ { print $2; exit }' Sources/AutocompleteLabResearch/AutocompleteTraceProofMetadata.swift)"
PLACEMENT_PROOF_VERSION="$(awk -F '"' '/placementProofVersion/ { print $2; exit }' Sources/AutocompleteLabResearch/AutocompleteTraceProofMetadata.swift)"
KEY_CAPTURE_PROOF_VERSION="$(awk -F '"' '/keyCaptureProofVersion/ { print $2; exit }' Sources/AutocompleteLabResearch/AutocompleteTraceProofMetadata.swift)"
RUNTIME_PROOF_VERSION="$(awk -F '"' '/runtimeProofVersion/ { print $2; exit }' Sources/AutocompleteLabResearch/AutocompleteTraceProofMetadata.swift)"
HOST_POLICY_VERSION="$(awk -F '"' '/currentPolicyVersion/ { print $2; exit }' Sources/AutocompleteLabResearch/HostCompatibilityPolicy.swift)"
HOST_POLICY_JSON="$(python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path("docs/product/proof-manifest.json").read_text())
print(json.dumps(manifest["hostPolicy"], indent=2))
PY
)"

write_manual_smoke() {
  local path="$1"
  local trace_path="$2"
  cat >"$path" <<MARKDOWN
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:00:00Z | TextEdit | \`com.apple.TextEdit\` | \`default\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 10+ | lines 20-25 in \`$trace_path\`; visual \`strict-complete\` |
| 2026-05-07T12:05:00Z | Codex | \`com.openai.codex\` | \`default\` | 1 | \`inlineAdjacent\` | lines 30+ | lines 40-44 in \`$trace_path\`; visual \`strict-complete\` |
| 2026-05-07T12:10:00Z | Chrome | \`com.google.Chrome\` | \`chat-like\` | 1 | \`inlineAdjacent\` | lines 50+ | lines 60-64 in \`$trace_path\`; visual \`strict-complete\` |
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

write_undo_manual_smoke() {
  local path="$1"
  local trace_path="$2"
  cat >"$path" <<MARKDOWN
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:15:00Z | TextEdit | \`com.apple.TextEdit\` | \`undo\` | 2 | \`inlineAdjacent|floatingMirror\` | lines 70-76 | lines 20-26 in \`$trace_path\`; visual \`strict-complete\` |
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

write_undo_trace() {
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
{"type":"acceptanceRetentionCleared","appBundleIdentifier":"com.apple.TextEdit","outcome":"undone","reason":"accepted-insertion-undone","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.apple.TextEdit","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"com.apple.TextEdit","outcome":"verified","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
JSONL
}

write_codex_prompt_trace() {
  local path="$1"
  local accept_mode="${2:-acceptNextWord}"
  local outcome="${3:-acceptNextWord}"
  local checkpoint="${4:-10s}"
  local reason="${5:-10s}"
  : >"$path"
  for _ in $(seq 1 39); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done

  cat >>"$path" <<JSONL
{"type":"suggestionRequested","appBundleIdentifier":"com.openai.codex","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionPresented","appBundleIdentifier":"com.openai.codex","screenshotPath":"docs/product/visual-placement-screenshots/codex-inline.png","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.openai.codex","outcome":"$outcome","metadata":{"acceptMode":"$accept_mode","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"com.openai.codex","outcome":"verified","metadata":{"acceptMode":"$accept_mode","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"acceptedTextEdited","appBundleIdentifier":"com.openai.codex","outcome":"exactKept","reason":"$reason","metadata":{"acceptMode":"$accept_mode","checkpoint":"$checkpoint","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
JSONL
}

write_chrome_chat_trace() {
  local path="$1"
  local checkpoint="${2:-10s}"
  local reason="${3:-10s}"
  : >"$path"
  for _ in $(seq 1 59); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done

  cat >>"$path" <<JSONL
{"type":"suggestionRequested","appBundleIdentifier":"com.google.Chrome","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionPresented","appBundleIdentifier":"com.google.Chrome","screenshotPath":"docs/product/visual-placement-screenshots/chrome-chat-like.png","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"com.google.Chrome","outcome":"acceptAllVisible","metadata":{"acceptMode":"acceptAllVisible","acceptedVisibleScope":"fullVisible","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"com.google.Chrome","outcome":"verified","metadata":{"acceptMode":"acceptAllVisible","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"acceptedTextEdited","appBundleIdentifier":"com.google.Chrome","outcome":"exactKept","reason":"$reason","metadata":{"acceptMode":"acceptAllVisible","checkpoint":"$checkpoint","traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
JSONL
}

append_obsidian_trace_segment() {
  local path="$1"
  cat >>"$path" <<JSONL
{"type":"suggestionRequested","appBundleIdentifier":"md.obsidian","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionPresented","appBundleIdentifier":"md.obsidian","screenshotPath":"docs/product/visual-placement-screenshots/obsidian.png","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"md.obsidian","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"md.obsidian","outcome":"verified","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"suggestionAccepted","appBundleIdentifier":"md.obsidian","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
{"type":"insertionVerified","appBundleIdentifier":"md.obsidian","outcome":"verified","metadata":{"traceProofVersion":"$TRACE_PROOF_VERSION","placementProofVersion":"$PLACEMENT_PROOF_VERSION","keyCaptureProofVersion":"$KEY_CAPTURE_PROOF_VERSION","runtimeProofVersion":"$RUNTIME_PROOF_VERSION"}}
JSONL
}

write_obsidian_trace() {
  local path="$1"
  : >"$path"
  for _ in $(seq 1 19); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done
  append_obsidian_trace_segment "$path"
  for _ in $(seq 1 4); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done
  append_obsidian_trace_segment "$path"
  for _ in $(seq 1 4); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done
  append_obsidian_trace_segment "$path"
  for _ in $(seq 1 4); do
    printf '{"type":"renderModeChanged","appBundleIdentifier":"com.example.other","metadata":{}}\n' >>"$path"
  done
  append_obsidian_trace_segment "$path"
}

write_obsidian_required_manual_smoke() {
  local path="$1"
  local trace_path="$2"
  local include_variants="${3:-yes}"
  cat >"$path" <<MARKDOWN
# Manual Smoke Runs

| Time UTC | App | Bundle | Proof | Verified accepts | Render expectation | Diagnostics slice | Trace slice |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| 2026-05-07T12:20:00Z | Obsidian | \`md.obsidian\` | \`default\` | 2 | \`floatingMirror\` | lines 10+ | lines 20-25 in \`$trace_path\`; visual \`strict-complete\` |
MARKDOWN
  if [[ "$include_variants" == "yes" ]]; then
    cat >>"$path" <<MARKDOWN
| 2026-05-07T12:21:00Z | Obsidian | \`md.obsidian\` | \`obsidian-theme\` | 2 | \`floatingMirror\` | lines 20+ | lines 30-35 in \`$trace_path\`; visual \`strict-complete\` |
| 2026-05-07T12:22:00Z | Obsidian | \`md.obsidian\` | \`obsidian-pane\` | 2 | \`floatingMirror\` | lines 30+ | lines 40-45 in \`$trace_path\`; visual \`strict-complete\` |
| 2026-05-07T12:23:00Z | Obsidian | \`md.obsidian\` | \`obsidian-long-note\` | 2 | \`floatingMirror\` | lines 40+ | lines 50-55 in \`$trace_path\`; visual \`strict-complete\` |
MARKDOWN
  fi
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
| Obsidian | 10/10 | [obsidian.png](visual-placement-screenshots/obsidian.png) | Good. | Done. |
| Codex | 10/10 | [codex-inline.png](visual-placement-screenshots/codex-inline.png) | Good. | Done. |
| Chrome chat-like composer | 10/10 | [chrome-chat-like.png](visual-placement-screenshots/chrome-chat-like.png) | Good. | Done. |
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

write_complete_obsidian_app_proof_matrix() {
  local path="$1"
  cat >"$path" <<'MARKDOWN'
# App Proof Matrix

| Surface | Grade | Screenshot proof | Accept proof | Current read | Evidence gap |
| --- | --- | --- | --- | --- | --- |
| TextEdit | A | [textedit-inline.png](visual-placement-screenshots/textedit-inline.png) | Complete. | Reference proof. | More variants. |
| Obsidian | A | [obsidian.png](visual-placement-screenshots/obsidian.png) | Complete. | Variant-complete proof. | None. |
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
  local requirements_json="[]"
  if [[ "$status" != "complete" ]]; then
    gaps_json='["still needs proof"]'
    requirements_json='[
        {
          "id": "variant-proof",
          "status": "pending",
          "summary": "Add exact variant proof before this surface can be complete.",
          "smokeCommand": "script/real_app_smoke.sh textedit --manual-gate"
        }
      ]'
  fi

  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "hostPolicy": $HOST_POLICY_JSON,
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
      "gaps": $gaps_json,
      "requirements": $requirements_json
    }
  ]
}
JSON
}

write_obsidian_required_manifest() {
  local path="$1"
  local status="${2:-complete}"
  local gaps_json="[]"
  local requirements_json="[]"
  if [[ "$status" != "complete" ]]; then
    gaps_json='["theme, pane, and long-note variants are still pending"]'
    requirements_json='[
        {
          "id": "obsidian-theme-variants",
          "status": "pending",
          "summary": "Run one non-default Obsidian theme proof.",
          "smokeCommand": "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate"
        },
        {
          "id": "obsidian-pane-variants",
          "status": "pending",
          "summary": "Run split or side-pane Obsidian proof.",
          "smokeCommand": "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate"
        },
        {
          "id": "obsidian-long-note-variants",
          "status": "pending",
          "summary": "Run long scrolled Obsidian note proof.",
          "smokeCommand": "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate"
        }
      ]'
  fi

  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "hostPolicy": $HOST_POLICY_JSON,
  "proofFingerprint": {
    "traceProofVersion": "$TRACE_PROOF_VERSION",
    "placementProofVersion": "$PLACEMENT_PROOF_VERSION",
    "keyCaptureProofVersion": "$KEY_CAPTURE_PROOF_VERSION",
    "runtimeProofVersion": "$RUNTIME_PROOF_VERSION"
  },
  "surfaces": [
    {
      "surface": "Obsidian",
      "status": "$status",
      "manualSmoke": {
        "app": "Obsidian",
        "bundle": "md.obsidian",
        "proof": "default",
        "minVerifiedAccepts": 2,
        "requiresVisualStrictComplete": true
      },
      "requiredManualSmokes": [
        {
          "id": "obsidian-theme",
          "app": "Obsidian",
          "bundle": "md.obsidian",
          "proof": "obsidian-theme",
          "minVerifiedAccepts": 2,
          "requiresVisualStrictComplete": true
        },
        {
          "id": "obsidian-pane",
          "app": "Obsidian",
          "bundle": "md.obsidian",
          "proof": "obsidian-pane",
          "minVerifiedAccepts": 2,
          "requiresVisualStrictComplete": true
        },
        {
          "id": "obsidian-long-note",
          "app": "Obsidian",
          "bundle": "md.obsidian",
          "proof": "obsidian-long-note",
          "minVerifiedAccepts": 2,
          "requiresVisualStrictComplete": true
        }
      ],
      "screenshots": [
        "docs/product/visual-placement-screenshots/obsidian.png"
      ],
      "gaps": $gaps_json,
      "requirements": $requirements_json
    }
  ]
}
JSON
}

write_variant_manifest() {
  local path="$1"
  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "hostPolicy": $HOST_POLICY_JSON,
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
      "manualSmokeVariants": [
        {
          "app": "TextEdit",
          "bundle": "com.apple.TextEdit",
          "proof": "default",
          "minVerifiedAccepts": 2,
          "requiresVisualStrictComplete": true
        },
        {
          "app": "TextEdit",
          "bundle": "com.apple.TextEdit",
          "proof": "default",
          "minVerifiedAccepts": 2,
          "requiresVisualStrictComplete": true
        }
      ],
      "screenshots": [
        "docs/product/visual-placement-screenshots/textedit-inline.png"
      ],
      "gaps": []
    }
  ]
}
JSON
}

write_requirement_manifest() {
  local path="$1"
  cat >"$path" <<JSON
{
  "schemaVersion": 1,
  "hostPolicy": $HOST_POLICY_JSON,
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
        "proof": "undo",
        "minVerifiedAccepts": 2,
        "requiresVisualStrictComplete": true
      },
      "screenshots": [
        "docs/product/visual-placement-screenshots/textedit-inline.png"
      ],
      "gaps": [],
      "requirements": [
        {
          "id": "same-slice-undo-proof",
          "status": "complete",
          "summary": "Prove same-slice accepted insertion undo.",
          "manualSmoke": {
            "app": "TextEdit",
            "bundle": "com.apple.TextEdit",
            "proof": "undo",
            "minVerifiedAccepts": 2,
            "requiresVisualStrictComplete": true,
            "requiresUndo": true
          }
        }
      ]
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
  "hostPolicy": {
    "policyVersion": "$HOST_POLICY_VERSION",
    "source": "Sources/AutocompleteLabResearch/HostCompatibilityPolicy.swift",
    "entries": [
      {
        "bundle": "com.apple.TextEdit",
        "displayName": "TextEdit",
        "versionState": "pending",
        "versionReason": "Fixture profile.",
        "safetyMode": "notPrompt",
        "runtimeState": "userToggleAllowed",
        "proofState": "complete",
        "killSwitch": "perHostDisable",
        "proofArtifacts": [
          {
            "kind": "screenshot",
            "reference": "docs/product/visual-placement-screenshots/textedit-inline.png"
          }
        ],
        "notes": "Fixture host policy row."
      },
      {
        "bundle": "com.openai.codex",
        "displayName": "Codex",
        "versionState": "pending",
        "versionReason": "Fixture profile.",
        "safetyMode": "notPrompt",
        "runtimeState": "diagnosticsOnly",
        "proofState": "partial",
        "killSwitch": "diagnosticsOnly",
        "proofArtifacts": [],
        "notes": "Fixture host policy row."
      }
    ]
  },
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
OBSIDIAN_TRACE_FILE="$TMP_DIR/obsidian-traces.jsonl"
UNDO_TRACE_FILE="$TMP_DIR/undo-traces.jsonl"
CODEX_PROMPT_TRACE_FILE="$TMP_DIR/codex-prompt-traces.jsonl"
CODEX_FULL_ACCEPT_TRACE_FILE="$TMP_DIR/codex-full-accept-traces.jsonl"
CHROME_CHAT_SUBMIT_TRACE_FILE="$TMP_DIR/chrome-chat-submit-traces.jsonl"
STALE_TRACE_FILE="$TMP_DIR/stale-traces.jsonl"
SCORECARD="$TMP_DIR/scorecard.md"
APP_PROOF_MATRIX="$TMP_DIR/app-proof-matrix.md"
OBSIDIAN_APP_PROOF_MATRIX="$TMP_DIR/obsidian-app-proof-matrix.md"
PASS_MANIFEST="$TMP_DIR/pass.json"
VARIANT_MANIFEST="$TMP_DIR/variant-pass.json"
OBSIDIAN_REQUIRED_MANIFEST="$TMP_DIR/obsidian-required.json"
OBSIDIAN_PARTIAL_MANIFEST="$TMP_DIR/obsidian-partial.json"
PROMPT_PASS_MANIFEST="$TMP_DIR/prompt-pass.json"
PROMPT_FULL_ACCEPT_MANIFEST="$TMP_DIR/prompt-full-accept.json"
PROMPT_FULL_ACCEPT_ALLOWED_MANIFEST="$TMP_DIR/prompt-full-accept-allowed.json"
CHROME_CHAT_SUBMIT_MANIFEST="$TMP_DIR/chrome-chat-submit.json"
PARTIAL_MANIFEST="$TMP_DIR/partial.json"
PENDING_MANIFEST="$TMP_DIR/pending.json"
UNAVAILABLE_BLOCKER_MANIFEST="$TMP_DIR/unavailable-blocker.json"
UNAVAILABLE_COMPLETE_MANIFEST="$TMP_DIR/unavailable-complete.json"
A_MINUS_COMPLETE_MANIFEST="$TMP_DIR/a-minus-complete.json"
STALE_MANIFEST="$TMP_DIR/stale.json"
MISSING_SMOKE_MANIFEST="$TMP_DIR/missing-smoke.json"
MISSING_SCREENSHOT_MANIFEST="$TMP_DIR/missing-screenshot.json"
REQUIREMENT_MANIFEST="$TMP_DIR/requirement.json"
PROFILE_SOURCE="$TMP_DIR/CompatibilityProfile.swift"
PROFILE_MANIFEST="$TMP_DIR/profile-pass.json"
MISSING_PROFILE_MANIFEST="$TMP_DIR/profile-missing.json"

write_trace "$TRACE_FILE"
write_obsidian_trace "$OBSIDIAN_TRACE_FILE"
write_undo_trace "$UNDO_TRACE_FILE"
write_codex_prompt_trace "$CODEX_PROMPT_TRACE_FILE" acceptNextWord acceptNextWord 10s 10s
write_codex_prompt_trace "$CODEX_FULL_ACCEPT_TRACE_FILE" acceptAllVisible acceptAllVisible 10s 10s
write_chrome_chat_trace "$CHROME_CHAT_SUBMIT_TRACE_FILE" fieldSend field-send-finalized
write_stale_trace "$STALE_TRACE_FILE"
write_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"
write_unbounded_manual_smoke "$UNBOUNDED_MANUAL_SMOKE" "$TRACE_FILE"
write_scorecard "$SCORECARD"
write_app_proof_matrix "$APP_PROOF_MATRIX"
write_complete_obsidian_app_proof_matrix "$OBSIDIAN_APP_PROOF_MATRIX"
write_manifest "$PASS_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png"
write_variant_manifest "$VARIANT_MANIFEST"
write_obsidian_required_manifest "$OBSIDIAN_REQUIRED_MANIFEST" complete
write_obsidian_required_manifest "$OBSIDIAN_PARTIAL_MANIFEST" partial
write_manifest "$PROMPT_PASS_MANIFEST" complete "docs/product/visual-placement-screenshots/codex-inline.png" "$TRACE_PROOF_VERSION" "Codex" "com.openai.codex" "default" 1
write_manifest "$PROMPT_FULL_ACCEPT_MANIFEST" complete "docs/product/visual-placement-screenshots/codex-inline.png" "$TRACE_PROOF_VERSION" "Codex" "com.openai.codex" "default" 1
cp "$PROMPT_FULL_ACCEPT_MANIFEST" "$PROMPT_FULL_ACCEPT_ALLOWED_MANIFEST"
python3 - "$PROMPT_FULL_ACCEPT_ALLOWED_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
manual_smoke = manifest["surfaces"][0]["manualSmoke"]
manual_smoke["requiresPromptFullAcceptNoSubmit"] = True
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
write_manifest "$CHROME_CHAT_SUBMIT_MANIFEST" complete "docs/product/visual-placement-screenshots/chrome-chat-like.png" "$TRACE_PROOF_VERSION" "Chrome" "com.google.Chrome" "chat-like" 1 "Chrome chat-like composer"
write_manifest "$PARTIAL_MANIFEST" partial "docs/product/visual-placement-screenshots/textedit-inline.png"
write_manifest "$PENDING_MANIFEST" pending "docs/product/visual-placement-screenshots/textedit-inline.png"
cp "$PARTIAL_MANIFEST" "$UNAVAILABLE_BLOCKER_MANIFEST"
python3 - "$UNAVAILABLE_BLOCKER_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
requirement = manifest["surfaces"][0]["requirements"][0]
requirement["status"] = "blocked"
requirement["blockerType"] = "unavailable-host"
requirement["summary"] = "This host is not installed here."
requirement.pop("smokeCommand", None)
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
cp "$PASS_MANIFEST" "$UNAVAILABLE_COMPLETE_MANIFEST"
python3 - "$UNAVAILABLE_COMPLETE_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
manifest["surfaces"][0]["requirements"] = [
    {
        "id": "unavailable-host-proof",
        "status": "blocked",
        "blockerType": "unavailable-host",
        "summary": "This host is not installed here."
    }
]
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
write_manifest "$A_MINUS_COMPLETE_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png" "$TRACE_PROOF_VERSION" "TextEdit" "com.apple.TextEdit" "default" 2 "Obsidian"
write_manifest "$STALE_MANIFEST" complete "docs/product/visual-placement-screenshots/textedit-inline.png" "old-proof"
write_manifest "$MISSING_SMOKE_MANIFEST" complete "docs/product/visual-placement-screenshots/codex-inline.png" "$TRACE_PROOF_VERSION" "Codex" "com.openai.codex" "default" 2
write_manifest "$MISSING_SCREENSHOT_MANIFEST" complete "docs/product/visual-placement-screenshots/missing-proof.png"
write_requirement_manifest "$REQUIREMENT_MANIFEST"
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

BROKEN_GRADUATION_MANIFEST="$TMP_DIR/proof-manifest.json"
cp docs/product/proof-manifest.json "$BROKEN_GRADUATION_MANIFEST"
python3 - "$BROKEN_GRADUATION_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
for row in manifest["graduationDecisions"]:
    if row["surface"] == "Google Docs in Chrome":
        row["decision"] = "supported"
        break
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

if script/check_proof_manifest.sh \
  --manifest "$BROKEN_GRADUATION_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage >"$TMP_DIR/broken-graduation.out" 2>&1; then
  echo "proof manifest self-test expected changed graduation decision to fail" >&2
  cat "$TMP_DIR/broken-graduation.out" >&2
  exit 1
fi

if ! grep -F "graduationDecisions Google Docs in Chrome: decision is 'supported'; expected 'blocked'" "$TMP_DIR/broken-graduation.out" >/dev/null; then
  echo "proof manifest self-test did not explain changed graduation decision" >&2
  cat "$TMP_DIR/broken-graduation.out" >&2
  exit 1
fi

DIRTY_PROOF_PATH="Sources/.proof-manifest-self-test-dirty"
rm -f "$DIRTY_PROOF_PATH"
printf 'dirty proof source\n' >"$DIRTY_PROOF_PATH"

if script/check_proof_manifest.sh \
  --manifest docs/product/proof-manifest.json \
  --skip-profile-coverage \
  --require-current-commit >"$TMP_DIR/dirty-proof-source.out" 2>&1; then
  echo "proof manifest self-test expected dirty proof-sensitive source paths to fail current-commit validation" >&2
  cat "$TMP_DIR/dirty-proof-source.out" >&2
  rm -f "$DIRTY_PROOF_PATH"
  exit 1
fi

if ! grep -F "proof-sensitive source paths have uncommitted changes" "$TMP_DIR/dirty-proof-source.out" >/dev/null; then
  echo "proof manifest self-test did not explain dirty proof-sensitive source path failure" >&2
  cat "$TMP_DIR/dirty-proof-source.out" >&2
  rm -f "$DIRTY_PROOF_PATH"
  exit 1
fi
rm -f "$DIRTY_PROOF_PATH"
DIRTY_PROOF_PATH=""

DIRTY_TRACKED_PROOF_SCRIPT="script/fresh_latency_proof.sh"
DIRTY_TRACKED_PROOF_SCRIPT_BACKUP="$TMP_DIR/fresh_latency_proof.sh.backup"
cp -p "$DIRTY_TRACKED_PROOF_SCRIPT" "$DIRTY_TRACKED_PROOF_SCRIPT_BACKUP"
printf '\n# proof manifest self-test dirty proof script\n' >>"$DIRTY_TRACKED_PROOF_SCRIPT"

if script/check_proof_manifest.sh \
  --manifest docs/product/proof-manifest.json \
  --skip-profile-coverage \
  --require-current-commit >"$TMP_DIR/dirty-proof-script.out" 2>&1; then
  echo "proof manifest self-test expected dirty proof loop scripts to fail current-commit validation" >&2
  cat "$TMP_DIR/dirty-proof-script.out" >&2
  exit 1
fi

if ! grep -F "script/fresh_latency_proof.sh" "$TMP_DIR/dirty-proof-script.out" >/dev/null; then
  echo "proof manifest self-test did not explain dirty proof loop script failure" >&2
  cat "$TMP_DIR/dirty-proof-script.out" >&2
  exit 1
fi
restore_dirty_tracked_proof_script

python3 - "$TMP_DIR" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

tmp_dir = Path(sys.argv[1])
module_path = Path("script/check_proof_manifest.py").resolve()
spec = importlib.util.spec_from_file_location("check_proof_manifest", module_path)
checker = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(checker)

proof_scripts = [
    "script/fresh_latency_proof.sh",
    "script/fresh_latency_proof_self_test.sh",
    "script/beta_readiness.sh",
    "script/check_score_targets.sh",
    "script/scorecard_goal_loop.sh",
]


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()


def commit_all(repo: Path, message: str) -> str:
    subprocess.check_call(["git", "add", "."], cwd=repo)
    subprocess.check_call(
        [
            "git",
            "-c",
            "user.name=Proof Manifest Self Test",
            "-c",
            "user.email=proof-manifest@example.invalid",
            "commit",
            "-m",
            message,
        ],
        cwd=repo,
        stdout=subprocess.DEVNULL,
    )
    return git(repo, "rev-parse", "HEAD")


def write_base_repo(repo: Path) -> str:
    subprocess.check_call(["git", "init", "-q"], cwd=repo)
    for path in proof_scripts:
        file_path = repo / path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    (repo / "docs").mkdir()
    (repo / "docs/not-proof-sensitive.md").write_text("base\n", encoding="utf-8")
    return commit_all(repo, "base")


docs_repo = tmp_dir / "commit-proof-docs-only"
docs_repo.mkdir()
base = write_base_repo(docs_repo)
(docs_repo / "docs/not-proof-sensitive.md").write_text("updated\n", encoding="utf-8")
docs_head = commit_all(docs_repo, "docs only")
checker.ROOT_DIR = docs_repo
if not checker.source_commit_is_current_compatible(base, docs_head):
    raise SystemExit("docs-only changes should remain current-proof compatible")

for proof_script in proof_scripts:
    repo = tmp_dir / ("commit-proof-" + proof_script.replace("/", "-"))
    repo.mkdir()
    base = write_base_repo(repo)
    script_path = repo / proof_script
    script_path.write_text(script_path.read_text(encoding="utf-8") + "echo changed\n", encoding="utf-8")
    head = commit_all(repo, f"change {proof_script}")
    checker.ROOT_DIR = repo
    if checker.source_commit_is_current_compatible(base, head):
        raise SystemExit(f"{proof_script} changes should not be current-proof compatible")
PY

script/check_proof_manifest.sh \
  --manifest "$VARIANT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/variant-pass.out"

if ! grep -F "Verified trace slices: 2" "$TMP_DIR/variant-pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify multiple manual smoke variants" >&2
  cat "$TMP_DIR/variant-pass.out" >&2
  exit 1
fi

write_obsidian_required_manual_smoke "$MANUAL_SMOKE" "$OBSIDIAN_TRACE_FILE" no

script/check_proof_manifest.sh \
  --manifest "$OBSIDIAN_PARTIAL_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --verify-trace-slices >"$TMP_DIR/obsidian-partial.out"

if ! grep -F "Partial proof:" "$TMP_DIR/obsidian-partial.out" >/dev/null; then
  echo "proof manifest self-test did not keep variant-incomplete Obsidian partial" >&2
  cat "$TMP_DIR/obsidian-partial.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$OBSIDIAN_REQUIRED_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$OBSIDIAN_APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --verify-trace-slices >"$TMP_DIR/obsidian-missing-required.out" 2>&1; then
  echo "proof manifest self-test expected complete Obsidian proof to require all variant lanes" >&2
  cat "$TMP_DIR/obsidian-missing-required.out" >&2
  exit 1
fi

if ! grep -F "missing required manual smoke obsidian-theme" "$TMP_DIR/obsidian-missing-required.out" >/dev/null; then
  echo "proof manifest self-test did not explain missing Obsidian theme proof" >&2
  cat "$TMP_DIR/obsidian-missing-required.out" >&2
  exit 1
fi

write_obsidian_required_manual_smoke "$MANUAL_SMOKE" "$OBSIDIAN_TRACE_FILE" yes

script/check_proof_manifest.sh \
  --manifest "$OBSIDIAN_REQUIRED_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$OBSIDIAN_APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/obsidian-required-pass.out"

if ! grep -F "Verified trace slices: 4" "$TMP_DIR/obsidian-required-pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify all required Obsidian variant trace slices" >&2
  cat "$TMP_DIR/obsidian-required-pass.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"

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

write_undo_manual_smoke "$MANUAL_SMOKE" "$UNDO_TRACE_FILE"

script/check_proof_manifest.sh \
  --manifest "$REQUIREMENT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/requirement-pass.out"

if ! grep -F "Verified trace slices: 2" "$TMP_DIR/requirement-pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify requirement-level undo proof" >&2
  cat "$TMP_DIR/requirement-pass.out" >&2
  exit 1
fi

write_undo_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"

if script/check_proof_manifest.sh \
  --manifest "$REQUIREMENT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/requirement-missing-undo.out" 2>&1; then
  echo "proof manifest self-test expected missing requirement undo proof to fail" >&2
  cat "$TMP_DIR/requirement-missing-undo.out" >&2
  exit 1
fi

if ! grep -F "undo proof requires acceptanceRetentionCleared" "$TMP_DIR/requirement-missing-undo.out" >/dev/null; then
  echo "proof manifest self-test did not explain missing requirement undo proof" >&2
  cat "$TMP_DIR/requirement-missing-undo.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$CODEX_PROMPT_TRACE_FILE"

script/check_proof_manifest.sh \
  --manifest "$PROMPT_PASS_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/prompt-pass.out"

if ! grep -F "Proof manifest verified." "$TMP_DIR/prompt-pass.out" >/dev/null; then
  echo "proof manifest self-test did not verify one-word prompt no-submit proof" >&2
  cat "$TMP_DIR/prompt-pass.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$CODEX_FULL_ACCEPT_TRACE_FILE"

if script/check_proof_manifest.sh \
  --manifest "$PROMPT_FULL_ACCEPT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/prompt-full-accept.out" 2>&1; then
  echo "proof manifest self-test expected prompt full accept proof to fail" >&2
  cat "$TMP_DIR/prompt-full-accept.out" >&2
  exit 1
fi

if ! grep -F "no-submit-only prompt proof contains full accept" "$TMP_DIR/prompt-full-accept.out" >/dev/null; then
  echo "proof manifest self-test did not explain prompt full accept proof" >&2
  cat "$TMP_DIR/prompt-full-accept.out" >&2
  exit 1
fi

sed 's/visual `strict-complete`/visual `strict-complete`; prompt full-accept no-submit confirmed/' \
  "$MANUAL_SMOKE" >"$TMP_DIR/full-accept-manual-smoke.md"

script/check_proof_manifest.sh \
  --manifest "$PROMPT_FULL_ACCEPT_ALLOWED_MANIFEST" \
  --manual-smoke "$TMP_DIR/full-accept-manual-smoke.md" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/prompt-full-accept-allowed.out"

if ! grep -F "Proof manifest verified." "$TMP_DIR/prompt-full-accept-allowed.out" >/dev/null; then
  echo "proof manifest self-test did not verify separate full-accept no-submit proof" >&2
  cat "$TMP_DIR/prompt-full-accept-allowed.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$CHROME_CHAT_SUBMIT_TRACE_FILE"

if script/check_proof_manifest.sh \
  --manifest "$CHROME_CHAT_SUBMIT_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/chrome-chat-submit.out" 2>&1; then
  echo "proof manifest self-test expected Chrome chat submit proof to fail" >&2
  cat "$TMP_DIR/chrome-chat-submit.out" >&2
  exit 1
fi

if ! grep -F "prompt no-submit trace contains submit-like signal" "$TMP_DIR/chrome-chat-submit.out" >/dev/null; then
  echo "proof manifest self-test did not explain Chrome chat submit proof" >&2
  cat "$TMP_DIR/chrome-chat-submit.out" >&2
  exit 1
fi

write_manual_smoke "$MANUAL_SMOKE" "$TRACE_FILE"

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

if ! grep -F "proof is partial, not complete; pending requirement(s): variant-proof - Add exact variant proof before this surface can be complete. (run script/real_app_smoke.sh textedit --manual-gate)" "$TMP_DIR/partial-strict.out" >/dev/null; then
  echo "proof manifest self-test did not explain strict partial live proof" >&2
  cat "$TMP_DIR/partial-strict.out" >&2
  exit 1
fi

if ! grep -F "Pending requirements:" "$TMP_DIR/partial-strict.out" >/dev/null; then
  echo "proof manifest self-test did not print pending requirements" >&2
  cat "$TMP_DIR/partial-strict.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$UNAVAILABLE_BLOCKER_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/unavailable-partial-strict.out" 2>&1; then
  echo "proof manifest self-test expected strict unavailable-host partial proof to fail" >&2
  cat "$TMP_DIR/unavailable-partial-strict.out" >&2
  exit 1
fi

if grep -F "pending requirement(s): variant-proof - This host is not installed here." "$TMP_DIR/unavailable-partial-strict.out" >/dev/null; then
  echo "proof manifest self-test should not count unavailable hosts as actionable pending proof" >&2
  cat "$TMP_DIR/unavailable-partial-strict.out" >&2
  exit 1
fi

if ! grep -F "Unavailable host requirements:" "$TMP_DIR/unavailable-partial-strict.out" >/dev/null; then
  echo "proof manifest self-test did not keep unavailable host requirements visible" >&2
  cat "$TMP_DIR/unavailable-partial-strict.out" >&2
  exit 1
fi

if script/check_proof_manifest.sh \
  --manifest "$UNAVAILABLE_COMPLETE_MANIFEST" \
  --manual-smoke "$MANUAL_SMOKE" \
  --scorecard "$SCORECARD" \
  --app-proof-matrix "$APP_PROOF_MATRIX" \
  --skip-profile-coverage \
  --strict >"$TMP_DIR/unavailable-complete.out" 2>&1; then
  echo "proof manifest self-test expected complete proof with unavailable host requirement to fail" >&2
  cat "$TMP_DIR/unavailable-complete.out" >&2
  exit 1
fi

if ! grep -F "complete proof still has pending requirement(s): unavailable-host-proof - This host is not installed here." "$TMP_DIR/unavailable-complete.out" >/dev/null; then
  echo "proof manifest self-test did not block complete proof with unavailable host requirement" >&2
  cat "$TMP_DIR/unavailable-complete.out" >&2
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

if ! grep -F "proof is pending, not complete; pending requirement(s): variant-proof - Add exact variant proof before this surface can be complete. (run script/real_app_smoke.sh textedit --manual-gate)" "$TMP_DIR/pending-strict.out" >/dev/null; then
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
