#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_TEXT="$(cat script/beta_readiness.sh)"

require_contains() {
  local expected="$1"
  if ! grep -Fq -- "$expected" <<<"$SCRIPT_TEXT"; then
    echo "missing expected beta readiness text: $expected" >&2
    exit 1
  fi
}

reject_contains() {
  local rejected="$1"
  if grep -Fq -- "$rejected" <<<"$SCRIPT_TEXT"; then
    echo "unsafe beta readiness text remains: $rejected" >&2
    exit 1
  fi
}

reject_line() {
  local rejected="$1"
  if grep -Fxq -- "$rejected" <<<"$SCRIPT_TEXT"; then
    echo "unsafe beta readiness line remains: $rejected" >&2
    exit 1
  fi
}

require_contains './script/package_release.sh --check --require-developer-id --require-notary-profile'
require_contains 'PRIMARY_ARTIFACT="$ROOT_DIR/dist/SteadyType.dmg"'
require_contains 'check_release_dmg_signature'
require_contains 'check_notarized_install_proof'
require_contains 'check_current_artifact_checksum'
require_contains 'write_current_artifact_checksums'
require_contains 'record_release_proof_command "$proof_dir/spctl-dmg.txt"'
require_contains 'record_release_proof_command "$proof_dir/spctl-installed-app.txt"'
require_contains 'attach_dmg_for_inspection'
require_contains 'hdiutil attach "$dmg_path" -readonly -mountpoint "$mount_path" -nobrowse -quiet'
require_contains 'DMG inspection blocked: could not mount $PRIMARY_ARTIFACT'
require_contains 'AUTOCOMPLETE_LAB_TRACE_LOG:-${AUTOCOMPLETE_LAB_TRACE_PATH'
require_contains '--required-proof-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_PROOF_APP:-com.apple.TextEdit}"'
require_contains '--required-trace-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_TRACE_APP:-com.apple.TextEdit}"'
require_contains '--require-model-backed-visible'
require_contains 'xcrun stapler validate "$PRIMARY_ARTIFACT"'
require_contains 'spctl -a -t open --context context:primary-signature -v "$PRIMARY_ARTIFACT"'
require_contains 'spctl --assess --type execute --verbose=4 "$app_path"'
require_contains 'AUTOCOMPLETE_LAB_BETA_READINESS_NOTARIZE'
require_contains './script/package_release.sh --notarize'
reject_contains 'Developer ID DMG signature blocked: could not mount'
reject_line './script/package_release.sh --check'
reject_contains 'Notarization is still pending'

echo "Beta readiness self-test passed."
