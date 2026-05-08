#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_MODE=0
APP_BUNDLE="$ROOT_DIR/dist/AutocompleteLab.app"

fail() {
  echo "bundle check failed: $*" >&2
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --release)
      RELEASE_MODE=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: script/check_app_bundle.sh [--release] [path/to/AutocompleteLab.app]

Checks the local app bundle shape, signature, and hardened runtime.
Use --release to also require a Developer ID Application signature.
EOF
      exit 0
      ;;
    -*)
      fail "unknown option: $arg"
      ;;
    *)
      APP_BUNDLE="$arg"
      ;;
  esac
done

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/AutocompleteLab"
APP_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
MLX_METALLIB="$APP_BUNDLE/Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

[[ -d "$APP_BUNDLE" ]] || fail "missing app bundle: $APP_BUNDLE"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE" ]] || fail "missing executable: $EXECUTABLE"
[[ -s "$APP_ICON" ]] || fail "missing app icon: $APP_ICON"
[[ -s "$MLX_METALLIB" ]] || fail "missing packaged MLX Metal library"

[[ "$(plist_value CFBundlePackageType)" == "APPL" ]] || fail "CFBundlePackageType is not APPL"
[[ "$(plist_value CFBundleExecutable)" == "AutocompleteLab" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIconFile)" == "AppIcon" ]] || fail "CFBundleIconFile mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "bar.r3d.autocomplete-lab" ]] || fail "CFBundleIdentifier mismatch"
[[ -n "$(plist_value CFBundleShortVersionString)" ]] || fail "missing CFBundleShortVersionString"
[[ -n "$(plist_value CFBundleVersion)" ]] || fail "missing CFBundleVersion"
[[ "$(plist_value LSUIElement)" == "true" ]] || fail "LSUIElement must be true for menu bar agent"

ACCESSIBILITY_REASON="$(plist_value NSAccessibilityUsageDescription)"
[[ "$ACCESSIBILITY_REASON" == *"Accessibility permission"* ]] || fail "missing Accessibility usage description"

codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1 || fail "codesign verification failed"

SIGNATURE_DETAILS="$(codesign --display --verbose=4 "$APP_BUNDLE" 2>&1 || true)"
grep -F "runtime" <<<"$SIGNATURE_DETAILS" >/dev/null || fail "hardened runtime flag is missing"

if [[ "$RELEASE_MODE" == "1" ]]; then
  grep -F "Authority=Developer ID Application" <<<"$SIGNATURE_DETAILS" >/dev/null \
    || fail "release bundle is not signed with Developer ID Application"
fi

echo "App bundle verified: $APP_BUNDLE"
