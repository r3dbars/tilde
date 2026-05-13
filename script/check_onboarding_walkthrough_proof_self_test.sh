#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CURRENT_COMMIT="$(git rev-parse --short=12 HEAD)"

write_proof() {
  local path="$1"
  local runtime="${2:-ready; app-owned MLX; no external server}"
  local delete_traces="${3:-Delete traces removed local trace/log files}"
  local build_proof="${4:-commit:$CURRENT_COMMIT}"

  cat >"$path" <<MARKDOWN
# Onboarding Walkthrough Proof

| Time UTC | Build proof | macOS user | Accessibility | Runtime | TextEdit practice | Tab | Esc | Pause | Delete traces | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-13T12:00:00Z | \`$build_proof\` | steadytype-clean | Accessibility granted after app-owned Settings user-triggered Allow Accessibility | $runtime | TextEdit opened disposable local practice file | one-word Tab inserted verified next word | Esc dismissed with no text change | Pause stopped suggestions | $delete_traces | pass | manual gate; diagnostics lines 10-80; trace lines 40-55 |
MARKDOWN
}

PASS_PROOF="$TMP_DIR/pass.md"
write_proof "$PASS_PROOF"
script/check_onboarding_walkthrough_proof.py --proof "$PASS_PROOF" >"$TMP_DIR/pass.txt"
script/check_onboarding_walkthrough_proof.py --print-template >"$TMP_DIR/template.txt"

if ! grep -F "Onboarding walkthrough proof passed" "$TMP_DIR/pass.txt" >/dev/null; then
  echo "onboarding proof self-test expected passing output" >&2
  cat "$TMP_DIR/pass.txt" >&2
  exit 1
fi

if ! grep -F "Only add a pass row after a real clean-user walkthrough." "$TMP_DIR/template.txt" >/dev/null; then
  echo "onboarding proof self-test missing real-run warning in template output" >&2
  cat "$TMP_DIR/template.txt" >&2
  exit 1
fi

if ! grep -F "docs/product/onboarding-walkthrough-proof.md" "$TMP_DIR/template.txt" >/dev/null; then
  echo "onboarding proof self-test missing runbook link in template output" >&2
  cat "$TMP_DIR/template.txt" >&2
  exit 1
fi

if ! grep -F "Do not turn a placeholder into \`pass\`" docs/product/onboarding-walkthrough-proof.md >/dev/null; then
  echo "onboarding proof self-test missing honest-pass warning in runbook" >&2
  exit 1
fi

if ! grep -F "./script/check_onboarding_walkthrough_proof.py --print-template" docs/product/onboarding-permission-qa-checklist.md >/dev/null; then
  echo "onboarding proof self-test missing template command in checklist" >&2
  exit 1
fi

PENDING_PROOF="$TMP_DIR/pending.md"
cat >"$PENDING_PROOF" <<'MARKDOWN'
# Onboarding Walkthrough Proof

| Time UTC | Build proof | macOS user | Accessibility | Runtime | TextEdit practice | Tab | Esc | Pause | Delete traces | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Needs fresh run. |
MARKDOWN

if script/check_onboarding_walkthrough_proof.py --proof "$PENDING_PROOF" >"$TMP_DIR/pending.txt" 2>&1; then
  echo "onboarding proof self-test expected pending proof to fail" >&2
  exit 1
fi

if ! grep -F "no completed passing walkthrough proof row found" "$TMP_DIR/pending.txt" >/dev/null; then
  echo "onboarding proof self-test missing no-pass failure" >&2
  cat "$TMP_DIR/pending.txt" >&2
  exit 1
fi

if ! grep -F "template: ./script/check_onboarding_walkthrough_proof.py --print-template" "$TMP_DIR/pending.txt" >/dev/null; then
  echo "onboarding proof self-test missing template hint" >&2
  cat "$TMP_DIR/pending.txt" >&2
  exit 1
fi

PENDING_THEN_PASS="$TMP_DIR/pending-then-pass.md"
cat >"$PENDING_THEN_PASS" <<MARKDOWN
# Onboarding Walkthrough Proof

| Time UTC | Build proof | macOS user | Accessibility | Runtime | TextEdit practice | Tab | Esc | Pause | Delete traces | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Needs fresh guided TextEdit walkthrough proof. |
| 2026-05-13T12:00:00Z | \`commit:$CURRENT_COMMIT\` | steadytype-clean | Accessibility granted after app-owned Settings user-triggered Allow Accessibility | ready; app-owned MLX; no external server | TextEdit opened disposable local practice file | one-word Tab inserted verified next word | Esc dismissed with no text change | Pause stopped suggestions | Delete traces removed local trace/log files | pass | manual gate; diagnostics lines 10-80; trace lines 40-55 |
MARKDOWN

script/check_onboarding_walkthrough_proof.py --proof "$PENDING_THEN_PASS" >"$TMP_DIR/pending-then-pass.txt"

if ! grep -F "Onboarding walkthrough proof passed" "$TMP_DIR/pending-then-pass.txt" >/dev/null; then
  echo "onboarding proof self-test expected placeholder followed by pass to succeed" >&2
  cat "$TMP_DIR/pending-then-pass.txt" >&2
  exit 1
fi

EXTERNAL_RUNTIME="$TMP_DIR/external-runtime.md"
write_proof "$EXTERNAL_RUNTIME" "ready; Ollama separate server"

if script/check_onboarding_walkthrough_proof.py --proof "$EXTERNAL_RUNTIME" >"$TMP_DIR/external-runtime.txt" 2>&1; then
  echo "onboarding proof self-test expected external runtime proof to fail" >&2
  exit 1
fi

if ! grep -F "runtime proof must not rely on Ollama" "$TMP_DIR/external-runtime.txt" >/dev/null; then
  echo "onboarding proof self-test missing external runtime failure" >&2
  cat "$TMP_DIR/external-runtime.txt" >&2
  exit 1
fi

MISSING_DELETE="$TMP_DIR/missing-delete.md"
write_proof "$MISSING_DELETE" "ready; app-owned MLX; no external server" "Delete traces button clicked"

if script/check_onboarding_walkthrough_proof.py --proof "$MISSING_DELETE" >"$TMP_DIR/missing-delete.txt" 2>&1; then
  echo "onboarding proof self-test expected weak delete proof to fail" >&2
  exit 1
fi

if ! grep -F "delete-traces proof must show files were removed" "$TMP_DIR/missing-delete.txt" >/dev/null; then
  echo "onboarding proof self-test missing delete-traces failure" >&2
  cat "$TMP_DIR/missing-delete.txt" >&2
  exit 1
fi

STALE_BUILD="$TMP_DIR/stale-build.md"
write_proof "$STALE_BUILD" "ready; app-owned MLX; no external server" "Delete traces removed local trace/log files" "commit:0000000"

if script/check_onboarding_walkthrough_proof.py --proof "$STALE_BUILD" >"$TMP_DIR/stale-build.txt" 2>&1; then
  echo "onboarding proof self-test expected stale build proof to fail" >&2
  exit 1
fi

if ! grep -F "build proof is not current" "$TMP_DIR/stale-build.txt" >/dev/null; then
  echo "onboarding proof self-test missing stale build failure" >&2
  cat "$TMP_DIR/stale-build.txt" >&2
  exit 1
fi

echo "Onboarding walkthrough proof self-test passed."
