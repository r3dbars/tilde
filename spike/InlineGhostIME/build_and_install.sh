#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
APP="build/InlineGhostIME.app"
DEST="$HOME/Library/Input Methods/InlineGhostIME.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O \
  -framework Cocoa -framework InputMethodKit \
  Sources/main.swift Sources/GhostInputController.swift \
  -o "$APP/Contents/MacOS/InlineGhostIME"

cp Info.plist "$APP/Contents/Info.plist"
# Developer ID (by fingerprint — two keychains make the name ambiguous). Gatekeeper
# rejects ad-hoc signatures for input methods on macOS 26.
codesign --force --options runtime \
  --sign 9E29C607772DECCED7EC4E3BCBC01DD492548ECE "$APP" >/dev/null

# Notarization is MANDATORY: Gatekeeper silently hides unnotarized input methods
# from the System Settings picker. One-time setup:
#   xcrun notarytool store-credentials ghost-notary --apple-id <id> --team-id XG6WL66WUQ
ditto -c -k --keepParent "$APP" build/InlineGhostIME.zip
xcrun notarytool submit build/InlineGhostIME.zip --keychain-profile ghost-notary --wait
xcrun stapler staple "$APP" >/dev/null

# Install, then register via the official Text Input Services API (no logout needed
# after the FIRST successful registration; the very first appearance in the picker
# required a restart). Registration is wiped if TextInputMenuAgent restarts — re-run.
[ -d "$DEST" ] && rm -rf "$DEST"
cp -R "$APP" "$DEST"
swift register.swift
# Live IME relaunches on the next keystroke after a kill.
killall InlineGhostIME 2>/dev/null || true

echo "installed: $DEST"
