#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HELP_OUTPUT="$(./script/package_release.sh --help)"
PROOF_TEMPLATE="$(./script/package_release.sh --print-proof-template)"

require_contains() {
  local text="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" <<<"$text"; then
    echo "missing expected package release text: $expected" >&2
    exit 1
  fi
}

require_contains "$HELP_OUTPUT" "dist/SteadyType.zip plus preferred dist/SteadyType.dmg"
require_contains "$HELP_OUTPUT" "--print-proof-template"
require_contains "$HELP_OUTPUT" "--require-developer-id"
require_contains "$HELP_OUTPUT" "Submit the DMG to Apple notarytool"

require_contains "$PROOF_TEMPLATE" "Preferred artifact: dist/SteadyType.dmg"
require_contains "$PROOF_TEMPLATE" "Secondary artifact: dist/SteadyType.zip"
require_contains "$PROOF_TEMPLATE" "Developer ID archive signature: required before private-beta packet"
require_contains "$PROOF_TEMPLATE" "Notarization status:"
require_contains "$PROOF_TEMPLATE" "Stapler status:"
require_contains "$PROOF_TEMPLATE" "Gatekeeper status:"
require_contains "$PROOF_TEMPLATE" "Fresh quarantined download"
require_contains "$PROOF_TEMPLATE" "Deny Accessibility"
require_contains "$PROOF_TEMPLATE" "uninstall/delete-data instructions"

if env -u NOTARYTOOL_PROFILE ./script/package_release.sh --check --require-notary-profile >/tmp/autocomplete-package-check.txt 2>&1; then
  echo "package release check should fail when --require-notary-profile is used without NOTARYTOOL_PROFILE" >&2
  cat /tmp/autocomplete-package-check.txt >&2
  exit 1
fi

require_contains "$(cat /tmp/autocomplete-package-check.txt)" "Apple notary credentials: blocked - NOTARYTOOL_PROFILE is missing"

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
