#!/usr/bin/env bash
# Build the separately identified 26B preview without mutating production Tilde.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/signing_identity.sh"

MODEL_SOURCE="${TILDE_PREVIEW_MODEL_SOURCE:-$HOME/Library/Application Support/Tilde Lab/Models/gemma-4-26b-a4b-base-q4_k_m.gguf}"
EXPECTED_MODEL_BYTES=16795999232
EXPECTED_MODEL_SHA256="5049347370bb87ebfe4cb65a7588ff6cdd945c456f951256ced8ea203b5572a7"
APP_NAME="Tilde 26B Preview"
APP_ID="bar.r3d.tilde.preview26b"
IME_ID="bar.r3d.inputmethod.InlineGhostPreview26B"
IME_CONNECTION="InlineGhostIME_26B_Preview_Connection"
PROFILE="preview-26b"
VERSION="0.1.0-preview26b"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
SIGN_IDENTITY=""
INSTALL_AND_LAUNCH=0

usage() {
  cat <<'EOF'
Usage: script/build_preview_26b.sh [--install-and-launch] [options]

Builds dist/Tilde 26B Preview.app with an isolated app identity, input source,
socket, settings, history, model directory, and llama-server port.

Options:
  --install-and-launch      Install to /Applications and open the preview.
  --model PATH             Seed the exact verified Q4_K_M model from PATH.
  --sign-identity SHA1     Sign with this exact Apple Development identity.
  --version VERSION        Set CFBundleShortVersionString.
  --build-number NUMBER    Set CFBundleVersion.
EOF
}

while (($#)); do
  case "$1" in
    --install-and-launch) INSTALL_AND_LAUNCH=1 ;;
    --model|--sign-identity|--version|--build-number)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --model) MODEL_SOURCE="$2" ;;
        --sign-identity) SIGN_IDENTITY="$2" ;;
        --version) VERSION="$2" ;;
        --build-number) BUILD_NUMBER="$2" ;;
      esac
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }
[[ -f "$MODEL_SOURCE" ]] || { echo "missing preview model: $MODEL_SOURCE" >&2; exit 1; }
[[ "$(stat -f '%z' "$MODEL_SOURCE")" == "$EXPECTED_MODEL_BYTES" ]] \
  || { echo "preview model size mismatch" >&2; exit 1; }
[[ "$(shasum -a 256 "$MODEL_SOURCE" | awk '{print $1}')" == "$EXPECTED_MODEL_SHA256" ]] \
  || { echo "preview model checksum mismatch" >&2; exit 1; }
[[ "$(LC_ALL=C head -c 4 "$MODEL_SOURCE")" == "GGUF" ]] \
  || { echo "preview model is not a GGUF" >&2; exit 1; }

SIGN_IDENTITY="$(tilde_resolve_signing_identity "$SIGN_IDENTITY")"
APP="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP/Contents"
IME="$CONTENTS/Library/InlineGhostIME.app"
HELPER_SOURCE="/Applications/Tilde.app/Contents/Helpers/llama-server"
[[ -x "$HELPER_SOURCE" ]] || { echo "missing signed llama-server helper: $HELPER_SOURCE" >&2; exit 1; }

swift build -c release --product Tilde
swift build -c release --product InlineGhostIME
BIN_PATH="$(swift build -c release --show-bin-path)"
mkdir -p "$ROOT_DIR/dist"
rm -rf -- "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Helpers" "$IME/Contents/MacOS"
cp "$BIN_PATH/Tilde" "$CONTENTS/MacOS/Tilde"
cp "$BIN_PATH/InlineGhostIME" "$IME/Contents/MacOS/InlineGhostIME"
cp "$HELPER_SOURCE" "$CONTENTS/Helpers/llama-server"
chmod +x "$CONTENTS/MacOS/Tilde" "$IME/Contents/MacOS/InlineGhostIME" "$CONTENTS/Helpers/llama-server"
cp Sources/InlineGhostIME/Info.plist "$IME/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $IME_ID" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :InputMethodConnectionName $IME_CONNECTION" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :TISInputSourceID $IME_ID" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :TildeProductProfile string $PROFILE" "$IME/Contents/Info.plist"

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Tilde</string>
  <key>CFBundleIdentifier</key><string>$APP_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>TildeProductProfile</key><string>$PROFILE</string>
</dict></plist>
PLIST

codesign --force --options runtime --sign "$SIGN_IDENTITY" "$CONTENTS/Helpers/llama-server" >/dev/null
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$IME" >/dev/null
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"
[[ "$(defaults read "$CONTENTS/Info" CFBundleIdentifier)" == "$APP_ID" ]]
[[ "$(defaults read "$IME/Contents/Info" CFBundleIdentifier)" == "$IME_ID" ]]

MODEL_TARGET="$HOME/Library/Application Support/$APP_NAME/Models/gemma-4-26b-a4b-q4km-preview/model.gguf"
mkdir -p "$(dirname "$MODEL_TARGET")"
chmod 700 "$HOME/Library/Application Support/$APP_NAME" \
  "$HOME/Library/Application Support/$APP_NAME/Models" \
  "$(dirname "$MODEL_TARGET")"
if [[ ! -e "$MODEL_TARGET" ]]; then
  cp -c "$MODEL_SOURCE" "$MODEL_TARGET"
  chmod 600 "$MODEL_TARGET"
fi
[[ "$(stat -f '%z' "$MODEL_TARGET")" == "$EXPECTED_MODEL_BYTES" ]]
[[ "$(shasum -a 256 "$MODEL_TARGET" | awk '{print $1}')" == "$EXPECTED_MODEL_SHA256" ]]

if ((INSTALL_AND_LAUNCH)); then
  INSTALLED="/Applications/$APP_NAME.app"
  [[ ! -e "$INSTALLED" ]] || { echo "existing preview app must be quit and replaced explicitly: $INSTALLED" >&2; exit 1; }
  ditto "$APP" "$INSTALLED"
  open -n "$INSTALLED"
  echo "Installed and launched: $INSTALLED"
else
  echo "Built preview without touching production Tilde: $APP"
fi
