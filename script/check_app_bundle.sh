#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-$ROOT_DIR/dist/AutocompleteLab.app}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/AutocompleteLab"
MLX_METALLIB="$APP_BUNDLE/Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib"

fail() {
  echo "bundle check failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

[[ -d "$APP_BUNDLE" ]] || fail "missing app bundle: $APP_BUNDLE"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE" ]] || fail "missing executable: $EXECUTABLE"
[[ -s "$MLX_METALLIB" ]] || fail "missing packaged MLX Metal library"

[[ "$(plist_value CFBundlePackageType)" == "APPL" ]] || fail "CFBundlePackageType is not APPL"
[[ "$(plist_value CFBundleExecutable)" == "AutocompleteLab" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "bar.r3d.autocomplete-lab" ]] || fail "CFBundleIdentifier mismatch"
[[ "$(plist_value LSUIElement)" == "true" ]] || fail "LSUIElement must be true for menu bar agent"

ACCESSIBILITY_REASON="$(plist_value NSAccessibilityUsageDescription)"
[[ "$ACCESSIBILITY_REASON" == *"Accessibility permission"* ]] || fail "missing Accessibility usage description"

codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1 || fail "codesign verification failed"

echo "App bundle verified: $APP_BUNDLE"
