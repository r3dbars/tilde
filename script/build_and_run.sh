#!/usr/bin/env bash
# Historical name, exact behavior: build and verify dist/Tilde.app.
# This script never launches, stops, or registers a running app. Use
# script/restart_app.sh when a deliberate restart is required.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/signing_identity.sh"

CONFIGURATION="debug"
SCRATCH_PATH="$ROOT_DIR/.build"
VERSION="0.1.0"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
JOBS=""
SIGN_IDENTITY=""

usage() {
  cat <<'EOF'
Usage: script/build_and_run.sh [options]

Build and verify dist/Tilde.app without touching any running Tilde process.

Options:
  --release                 Build with Swift's release configuration.
  --scratch-path PATH       Use a specific SwiftPM scratch directory.
  --jobs COUNT              Limit Swift build jobs.
  --version VERSION         Set CFBundleShortVersionString.
  --build-number NUMBER     Set CFBundleVersion.
  --sign-identity SHA1      Sign with this exact SHA-1; use - for explicit ad hoc signing.

Without --sign-identity, the sole eligible Apple Development identity is used.
Zero or multiple eligible identities fail loudly. Ad hoc bundles cannot exercise
the authenticated app-to-IME runtime.
EOF
}

while (($#)); do
  case "$1" in
    --release)
      CONFIGURATION="release"
      ;;
    --scratch-path|--jobs|--version|--build-number|--sign-identity)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --scratch-path) SCRATCH_PATH="$2" ;;
        --jobs) JOBS="$2" ;;
        --version) VERSION="$2" ;;
        --build-number) BUILD_NUMBER="$2" ;;
        --sign-identity) SIGN_IDENTITY="$2" ;;
      esac
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }
if [[ -n "$JOBS" ]]; then
  [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "jobs must be a positive integer" >&2; exit 2; }
fi
SIGN_IDENTITY="$(tilde_resolve_signing_identity "$SIGN_IDENTITY")"

APP="$ROOT_DIR/dist/Tilde.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
GENERATED_ICON="$ROOT_DIR/dist/Tilde.generated-icon.$$.icns"
trap 'rm -f "$GENERATED_ICON"' EXIT

mkdir -p "$ROOT_DIR/dist" "$SCRATCH_PATH"
swift script/generate_app_icon.swift "dist/$(basename "$GENERATED_ICON")"

BUILD_ARGS=(--scratch-path "$SCRATCH_PATH" -c "$CONFIGURATION" --product Tilde)
if [[ -n "$JOBS" ]]; then
  BUILD_ARGS=(--jobs "$JOBS" "${BUILD_ARGS[@]}")
fi
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build --scratch-path "$SCRATCH_PATH" -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_PATH/Tilde" "$MACOS/Tilde"
cp "$GENERATED_ICON" "$RESOURCES/AppIcon.icns"
if [[ "$CONFIGURATION" == "release" ]]; then
  strip -S -x "$MACOS/Tilde"
fi
chmod +x "$MACOS/Tilde"

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Tilde</string>
  <key>CFBundleIdentifier</key>
  <string>bar.r3d.tilde</string>
  <key>CFBundleName</key>
  <string>Tilde</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP" >/dev/null

"$ROOT_DIR/script/check_app_bundle.sh" "$APP"
echo "Built app bundle without restarting Tilde: $APP"
