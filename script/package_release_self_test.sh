#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HELP_OUTPUT="$(./script/package_release.sh --help)"
PROOF_TEMPLATE="$(./script/package_release.sh --print-proof-template)"
SCRIPT_TEXT="$(cat script/package_release.sh)"

require_contains() {
  local text="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" <<<"$text"; then
    echo "missing expected package release text: $expected" >&2
    exit 1
  fi
}

require_contains "$HELP_OUTPUT" "primary dist/SteadyType.dmg plus secondary dist/SteadyType.zip"
require_contains "$HELP_OUTPUT" "--print-proof-template"
require_contains "$HELP_OUTPUT" "--require-developer-id"
require_contains "$HELP_OUTPUT" "Submit the DMG to Apple notarytool"
require_contains "$HELP_OUTPUT" "AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES"

require_contains "$PROOF_TEMPLATE" "Preferred artifact: dist/SteadyType.dmg"
require_contains "$PROOF_TEMPLATE" "Secondary artifact: dist/SteadyType.zip"
require_contains "$PROOF_TEMPLATE" "Developer ID app signature: required before private-beta packet"
require_contains "$PROOF_TEMPLATE" "Notarization status:"
require_contains "$PROOF_TEMPLATE" "Stapler status:"
require_contains "$PROOF_TEMPLATE" "Gatekeeper status:"
require_contains "$PROOF_TEMPLATE" "Fresh quarantined download"
require_contains "$SCRIPT_TEXT" "2>&1 | tee dist/release-proof/spctl-installed-app.txt"
require_contains "$SCRIPT_TEXT" 'record_command "$PROOF_DIR/stapler-staple.txt"'
require_contains "$SCRIPT_TEXT" "gatekeeper_failed=0"
require_contains "$SCRIPT_TEXT" 'Gatekeeper assessment failed; saved spctl output in $PROOF_DIR'
require_contains "$PROOF_TEMPLATE" "Deny Accessibility"
require_contains "$PROOF_TEMPLATE" "uninstall/delete-data instructions"

MISSING_MODEL_HOME="$(mktemp -d)"
trap 'rm -rf "$MISSING_MODEL_HOME"' EXIT
if HOME="$MISSING_MODEL_HOME" ./script/package_release.sh --check >/tmp/autocomplete-package-missing-model-check.txt 2>&1; then
  echo "package release check should fail when the required app-owned model asset is missing" >&2
  cat /tmp/autocomplete-package-missing-model-check.txt >&2
  exit 1
fi

require_contains "$(cat /tmp/autocomplete-package-missing-model-check.txt)" "Preferred MLX model: blocked - required app-owned model is missing, invalid, corrupt, or not checksum-verified"
require_contains "$(cat /tmp/autocomplete-package-missing-model-check.txt)" "Run ./script/check_model_asset.py for the exact fix."

if env -u NOTARYTOOL_PROFILE \
  AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES=not-a-real-profile \
  ./script/package_release.sh --check --require-notary-profile >/tmp/autocomplete-package-check.txt 2>&1; then
  echo "package release check should fail when no usable notary profile is available" >&2
  cat /tmp/autocomplete-package-check.txt >&2
  exit 1
fi

require_contains "$(cat /tmp/autocomplete-package-check.txt)" "Apple notary credentials: blocked - no usable NOTARYTOOL_PROFILE or stored profile alias was found"

if SIGN_IDENTITY=not-a-real-developer-id \
  NOTARYTOOL_PROFILE=not-a-real-profile \
  ./script/package_release.sh --check --require-developer-id --require-notary-profile >/tmp/autocomplete-package-fake-check.txt 2>&1; then
  echo "package release check should fail with fake signing and notary env values" >&2
  cat /tmp/autocomplete-package-fake-check.txt >&2
  exit 1
fi

require_contains "$(cat /tmp/autocomplete-package-fake-check.txt)" "Developer ID signing identity: blocked - missing Developer ID Application identity"
require_contains "$(cat /tmp/autocomplete-package-fake-check.txt)" "Apple notary credentials: blocked - NOTARYTOOL_PROFILE is not usable"

echo "Package release self-test passed."
