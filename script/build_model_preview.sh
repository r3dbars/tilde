#!/usr/bin/env bash
# Build one isolated preview whose menu can switch between verified 9B and 26B models.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/signing_identity.sh"

MODEL_9B_SOURCE="${TILDE_PREVIEW_9B_MODEL_SOURCE:-$HOME/Library/Application Support/Tilde Lab/Models/qwen3.5-9b-base-q4_k_m.gguf}"
MODEL_26B_SOURCE="${TILDE_PREVIEW_26B_MODEL_SOURCE:-$HOME/Library/Application Support/Tilde Lab/Models/gemma-4-26b-a4b-base-q4_k_m.gguf}"
HELPER_SOURCE="${TILDE_PREVIEW_HELPER_SOURCE:-/Applications/Tilde.app/Contents/Helpers/llama-server}"
MODEL_9B_BYTES=5629109312
MODEL_9B_SHA256="4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
MODEL_26B_BYTES=16795999232
MODEL_26B_SHA256="5049347370bb87ebfe4cb65a7588ff6cdd945c456f951256ced8ea203b5572a7"
APP_NAME="Tilde Model Preview"
APP_ID="bar.r3d.tilde.modelpreview"
IME_ID="bar.r3d.inputmethod.InlineGhostModelPreview"
IME_CONNECTION="InlineGhostIME_Model_Preview_Connection"
PROFILE="model-preview"
VERSION="0.1.0-model-preview"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
SIGN_IDENTITY=""
INSTALL_AND_LAUNCH=0

usage() {
  cat <<'EOF'
Usage: script/build_model_preview.sh [--install-and-launch] [options]

Builds dist/Tilde Model Preview.app. Its menu and Settings window can switch
between the verified Qwen 3.5 9B and Gemma 4 26B experimental models.

Options:
  --install-and-launch      Install to /Applications and open the preview.
  --9b-model PATH           Seed the exact verified Qwen 3.5 9B Q4_K_M model.
  --26b-model PATH          Seed the exact verified Gemma 4 26B Q4_K_M model.
  --helper PATH             Use this already signed llama-server helper.
  --sign-identity SHA1      Sign with this exact Apple Development identity.
  --version VERSION         Set CFBundleShortVersionString.
  --build-number NUMBER     Set CFBundleVersion.
EOF
}

while (($#)); do
  case "$1" in
    --install-and-launch) INSTALL_AND_LAUNCH=1 ;;
    --9b-model|--26b-model|--helper|--sign-identity|--version|--build-number)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --9b-model) MODEL_9B_SOURCE="$2" ;;
        --26b-model) MODEL_26B_SOURCE="$2" ;;
        --helper) HELPER_SOURCE="$2" ;;
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

verify_model() {
  local path="$1" expected_bytes="$2" expected_sha="$3" label="$4"
  [[ -f "$path" ]] || { echo "missing $label model: $path" >&2; exit 1; }
  [[ "$(stat -f '%z' "$path")" == "$expected_bytes" ]] \
    || { echo "$label model size mismatch" >&2; exit 1; }
  [[ "$(shasum -a 256 "$path" | awk '{print $1}')" == "$expected_sha" ]] \
    || { echo "$label model checksum mismatch" >&2; exit 1; }
  [[ "$(LC_ALL=C head -c 4 "$path")" == "GGUF" ]] \
    || { echo "$label model is not a GGUF" >&2; exit 1; }
}

seed_model() {
  local source="$1" target="$2" expected_bytes="$3" expected_sha="$4" label="$5"
  mkdir -p "$(dirname "$target")"
  chmod 700 "$(dirname "$target")"
  if [[ ! -e "$target" ]]; then
    cp -c "$source" "$target"
    chmod 600 "$target"
  fi
  verify_model "$target" "$expected_bytes" "$expected_sha" "$label"
}

[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }
verify_model "$MODEL_9B_SOURCE" "$MODEL_9B_BYTES" "$MODEL_9B_SHA256" "9B"
verify_model "$MODEL_26B_SOURCE" "$MODEL_26B_BYTES" "$MODEL_26B_SHA256" "26B"

SIGN_IDENTITY="$(tilde_resolve_signing_identity "$SIGN_IDENTITY")"
APP="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP/Contents"
IME="$CONTENTS/Library/InlineGhostIME.app"
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

MODEL_ROOT="$HOME/Library/Application Support/$APP_NAME/Models"
mkdir -p "$MODEL_ROOT"
chmod 700 "$HOME/Library/Application Support/$APP_NAME" "$MODEL_ROOT"
seed_model "$MODEL_9B_SOURCE" \
  "$MODEL_ROOT/qwen3.5-9b-base-q4km-preview/model.gguf" \
  "$MODEL_9B_BYTES" "$MODEL_9B_SHA256" "9B"
seed_model "$MODEL_26B_SOURCE" \
  "$MODEL_ROOT/gemma-4-26b-a4b-q4km-preview/model.gguf" \
  "$MODEL_26B_BYTES" "$MODEL_26B_SHA256" "26B"

if ((INSTALL_AND_LAUNCH)); then
  INSTALLED="/Applications/$APP_NAME.app"
  [[ ! -e "$INSTALLED" ]] || { echo "existing preview app must be quit and replaced explicitly: $INSTALLED" >&2; exit 1; }
  ditto "$APP" "$INSTALLED"
  open -n "$INSTALLED"
  echo "Installed and launched: $INSTALLED"
else
  echo "Built selectable model preview: $APP"
fi
