#!/usr/bin/env bash
# Build, sign, and optionally notarize the InlineGhostIME input method.
#
# Usage: ./script/build_ime.sh [--no-notarize] [--version VERSION] [--build-number NUMBER]
#
# Notarization is MANDATORY for the keyboard to appear in the System Settings
# picker (Gatekeeper silently hides unnotarized input methods). One-time setup:
#   xcrun notarytool store-credentials ghost-notary --apple-id <id> --team-id <team>
# --no-notarize builds and signs only (CI / compile checks).
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARIZE=1
VERSION="0.1.0"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
while (($#)); do
    case "$1" in
        --no-notarize) NOTARIZE=0 ;;
        --version|--build-number)
            [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
            if [[ "$1" == "--version" ]]; then VERSION="$2"; else BUILD_NUMBER="$2"; fi
            shift
            ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }

SIGN_IDENTITY="${IME_SIGN_IDENTITY:-9E29C607772DECCED7EC4E3BCBC01DD492548ECE}"
NOTARY_PROFILE="${IME_NOTARY_PROFILE:-ghost-notary}"
APP="dist/InlineGhostIME.app"
swift build -c release --product InlineGhostIME

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/InlineGhostIME "$APP/Contents/MacOS/InlineGhostIME"
cp Sources/InlineGhostIME/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"

if [ "$NOTARIZE" = 1 ]; then
    ditto -c -k --keepParent "$APP" dist/InlineGhostIME.zip
    xcrun notarytool submit dist/InlineGhostIME.zip \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP" >/dev/null
fi
