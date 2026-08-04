#!/usr/bin/env bash
# Build a self-contained, notarized Tilde.app for installation on any
# Apple Silicon Mac running macOS 26. The app carries everything it needs:
#   - Tilde.app (menu-bar brain) with
#       Contents/Helpers/llama-server         (static binary, no dylib deps)
#       Contents/Library/InlineGhostIME.app   (the keyboard; auto-installed at launch)
#       Contents/Resources/bundled-model.gguf (the Gemma model; nothing downloads at runtime)
#
# Usage: LLAMA_SERVER_BIN=/path/to/static/llama-server \
#        BUNDLED_MODEL=/path/to/gemma-2-2b.Q4_K_M.gguf ./script/package_app.sh
#
# LLAMA_SERVER_BIN must be a STATIC build (no non-system dylibs):
#   cmake -B build -DBUILD_SHARED_LIBS=OFF -DLLAMA_CURL=OFF \
#     -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=TRUE -DGGML_METAL=ON \
#     -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON
#   cmake --build build --target llama-server -j
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_IDENTITY="${IME_SIGN_IDENTITY:-9E29C607772DECCED7EC4E3BCBC01DD492548ECE}"
NOTARY_PROFILE="${IME_NOTARY_PROFILE:-ghost-notary}"
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:?set LLAMA_SERVER_BIN to a static llama-server binary}"

# Refuse dynamic binaries — they will break on machines without brew.
if otool -L "$LLAMA_SERVER_BIN" | grep -qv "/System\|/usr/lib\|:"; then
    echo "error: LLAMA_SERVER_BIN links non-system dylibs; build it static" >&2
    exit 1
fi

echo "==> building app + keyboard"
./script/build_and_run.sh --verify > /dev/null
./script/build_ime.sh --no-install > /dev/null

APP="dist/Tilde.app"
echo "==> embedding helpers"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Library"
cp "$LLAMA_SERVER_BIN" "$APP/Contents/Helpers/llama-server"
rm -rf "$APP/Contents/Library/InlineGhostIME.app"
cp -R dist/InlineGhostIME.app "$APP/Contents/Library/InlineGhostIME.app"

# The model ships inside the app — required, not optional. There is no
# runtime download path anymore (LlamaServerProcessHost.resolveModelPath).
BUNDLED_MODEL="${BUNDLED_MODEL:?set BUNDLED_MODEL to the GGUF to ship inside the app}"
echo "==> embedding bundled model ($(du -h "$BUNDLED_MODEL" | cut -f1))"
mkdir -p "$APP/Contents/Resources"
cp "$BUNDLED_MODEL" "$APP/Contents/Resources/bundled-model.gguf"

echo "==> signing (inside out)"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP/Contents/Helpers/llama-server"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP/Contents/Library/InlineGhostIME.app"
codesign --force --options runtime \
    --entitlements script/Tilde.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"

echo "==> notarizing"
ditto -c -k --keepParent "$APP" dist/Tilde-notarize.zip
xcrun notarytool submit dist/Tilde-notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP" > /dev/null

STAMP=$(date +%Y%m%d)
OUT="dist/Tilde-$STAMP.zip"
ditto -c -k --keepParent "$APP" "$OUT"
echo "==> packaged: $OUT"
spctl -a -t exec -vv "$APP" 2>&1 | head -2
