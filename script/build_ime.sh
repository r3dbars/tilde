#!/usr/bin/env bash
# Build, sign, notarize, install, and register the InlineGhostIME input method.
#
# Usage: ./script/build_ime.sh [--no-install] [--no-notarize]
#
# Notarization is MANDATORY for the keyboard to appear in the System Settings
# picker (Gatekeeper silently hides unnotarized input methods). One-time setup:
#   xcrun notarytool store-credentials ghost-notary --apple-id <id> --team-id <team>
# --no-notarize builds and signs only (CI / compile checks).
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=1
NOTARIZE=1
for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL=0 ;;
        --no-notarize) NOTARIZE=0 ;;
        *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

SIGN_IDENTITY="${IME_SIGN_IDENTITY:-9E29C607772DECCED7EC4E3BCBC01DD492548ECE}"
NOTARY_PROFILE="${IME_NOTARY_PROFILE:-ghost-notary}"
APP="dist/InlineGhostIME.app"
DEST="$HOME/Library/Input Methods/InlineGhostIME.app"

swift build -c release --product InlineGhostIME

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/InlineGhostIME "$APP/Contents/MacOS/InlineGhostIME"
cp Sources/InlineGhostIME/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"

if [ "$NOTARIZE" = 1 ]; then
    ditto -c -k --keepParent "$APP" dist/InlineGhostIME.zip
    xcrun notarytool submit dist/InlineGhostIME.zip \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP" >/dev/null
fi

if [ "$INSTALL" = 1 ]; then
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    # Official registration API — lsregister alone is insufficient, and the very
    # first registration on a machine additionally needs a login/restart before
    # the keyboard shows in the System Settings picker.
    swift script/register_input_source.swift
    # A live IME relaunches on the next keystroke after a kill.
    killall InlineGhostIME 2>/dev/null || true
    echo "installed: $DEST"
fi
