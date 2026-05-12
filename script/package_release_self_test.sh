#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HELP_OUTPUT="$(./script/package_release.sh --help)"
PROOF_TEMPLATE="$(./script/package_release.sh --print-proof-template)"
PATCH_SCRIPT="$(cat script/patch_mlx_swift_lm.sh)"
MLX_PATCH="$(cat patches/mlx-swift-lm/gemma4-optiq-scaled-linear.patch)"

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
require_contains "$HELP_OUTPUT" "Submit the DMG to Apple notarytool"

require_contains "$PROOF_TEMPLATE" "Preferred artifact: dist/SteadyType.dmg"
require_contains "$PROOF_TEMPLATE" "Secondary artifact: dist/SteadyType.zip"
require_contains "$PROOF_TEMPLATE" "Notarization status:"
require_contains "$PROOF_TEMPLATE" "Stapler status:"
require_contains "$PROOF_TEMPLATE" "Gatekeeper status:"
require_contains "$PROOF_TEMPLATE" "Fresh quarantined download"
require_contains "$PROOF_TEMPLATE" "Deny Accessibility"
require_contains "$PROOF_TEMPLATE" "uninstall/delete-data instructions"

require_contains "$PATCH_SCRIPT" 'SWIFT_SCRATCH_PATH="${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build}"'
require_contains "$PATCH_SCRIPT" 'patch -d "$SWIFT_SCRATCH_PATH" -p0'
require_contains "$MLX_PATCH" '--- checkouts/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift'

if env -u NOTARYTOOL_PROFILE ./script/package_release.sh --check --require-notary-profile >/tmp/autocomplete-package-check.txt 2>&1; then
  echo "package release check should fail when --require-notary-profile is used without NOTARYTOOL_PROFILE" >&2
  cat /tmp/autocomplete-package-check.txt >&2
  exit 1
fi

require_contains "$(cat /tmp/autocomplete-package-check.txt)" "Notary profile: missing"

echo "Package release self-test passed."
