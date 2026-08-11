#!/usr/bin/env bash
# Single release driver: test, build, embed, sign, exercise, notarize, staple,
# package, and checksum a self-contained Tilde release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LLAMA_SERVER=""
LLAMA_SHA256=""
MODEL=""
MODEL_SHA256=""
SIGN_IDENTITY=""
NOTARY_PROFILE=""
VERSION="0.1.0"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
VERIFY_INPUTS_ONLY=0

usage() {
  cat <<'EOF'
Usage: script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --model PATH --model-sha256 SHA256 --notary-profile PROFILE [options]
       script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --model PATH --model-sha256 SHA256 --verify-inputs-only

Release inputs:
  --llama-server PATH       Static llama-server with system-only dependencies.
  --llama-sha256 SHA256     Exact SHA-256 of the llama-server input.
  --model PATH              GGUF model embedded in the app.
  --model-sha256 SHA256     Exact SHA-256 of the model input.

Full release only:
  --notary-profile PROFILE  Stored notarytool keychain profile.

Options:
  --sign-identity IDENTITY  Developer ID Application identity (auto-detected).
  --version VERSION         Release version (default: 0.1.0).
  --build-number NUMBER     Numeric bundle build number.
  --verify-inputs-only      Verify pinned inputs, then exit without building,
                            signing, notarizing, or uploading anything.

This is intentionally fail-closed. It creates release artifacts only after the
full test suite, packaged-runtime health/completion/socket observation, Apple
notarization, stapling, and Gatekeeper assessment all pass.
EOF
}

while (($#)); do
  case "$1" in
    --llama-server|--llama-sha256|--model|--model-sha256|--notary-profile|--sign-identity|--version|--build-number)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --llama-server) LLAMA_SERVER="$2" ;;
        --llama-sha256) LLAMA_SHA256="$2" ;;
        --model) MODEL="$2" ;;
        --model-sha256) MODEL_SHA256="$2" ;;
        --notary-profile) NOTARY_PROFILE="$2" ;;
        --sign-identity) SIGN_IDENTITY="$2" ;;
        --version) VERSION="$2" ;;
        --build-number) BUILD_NUMBER="$2" ;;
      esac
      shift
      ;;
    --verify-inputs-only)
      VERIFY_INPUTS_ONLY=1
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

normalize_sha256() {
  local label="$1"
  local value
  value="$(tr '[:upper:]' '[:lower:]' <<<"$2")"
  [[ "$value" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "$label must be exactly 64 hexadecimal characters" >&2; return 2; }
  printf '%s' "$value"
}

verify_sha256() {
  local label="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(shasum -a 256 "$path" | awk '{ print $1 }')"
  [[ "$actual" == "$expected" ]] \
    || { echo "$label SHA-256 mismatch: expected $expected, got $actual" >&2; return 1; }
}

[[ -f "$LLAMA_SERVER" ]] || { echo "missing --llama-server file: $LLAMA_SERVER" >&2; exit 2; }
[[ -x "$LLAMA_SERVER" ]] || { echo "llama-server is not executable: $LLAMA_SERVER" >&2; exit 2; }
[[ -s "$MODEL" ]] || { echo "missing --model file: $MODEL" >&2; exit 2; }
LLAMA_SHA256="$(normalize_sha256 --llama-sha256 "$LLAMA_SHA256")"
MODEL_SHA256="$(normalize_sha256 --model-sha256 "$MODEL_SHA256")"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }

verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
verify_sha256 "model input" "$MODEL" "$MODEL_SHA256"

if otool -L "$LLAMA_SERVER" | tail -n +2 | awk '{ print $1 }' \
  | grep -Ev '^(/System/|/usr/lib/)' >/dev/null; then
  echo "llama-server links a non-system library; use a static release build" >&2
  exit 1
fi

if [[ "$VERIFY_INPUTS_ONLY" == "1" ]]; then
  echo "Release inputs verified. No build, signing, notarization, or upload performed."
  exit 0
fi

[[ -n "$NOTARY_PROFILE" ]] || { echo "--notary-profile is required" >&2; exit 2; }

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
    | awk '/Developer ID Application/ { print $2; exit }')"
fi
[[ -n "$SIGN_IDENTITY" ]] \
  || { echo "missing Developer ID Application signing identity" >&2; exit 1; }
RESOLVED_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
  | awk -v wanted="$SIGN_IDENTITY" '$2 == wanted || index($0, "\"" wanted "\"") { print $2; exit }')"
[[ -n "$RESOLVED_IDENTITY" ]] \
  || { echo "signing identity is unavailable: $SIGN_IDENTITY" >&2; exit 1; }
SIGN_IDENTITY="$RESOLVED_IDENTITY"

echo "==> validating Apple notary credentials"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null

APP="$ROOT_DIR/dist/Tilde.app"
IME="$ROOT_DIR/dist/InlineGhostIME.app"
PROOF_DIR="$ROOT_DIR/dist/release-proof"
NOTARY_ZIP="$ROOT_DIR/dist/Tilde-notarize.zip"
STAGING_DMG="$ROOT_DIR/dist/Tilde-notarize.dmg"
FINAL_ZIP="$ROOT_DIR/dist/Tilde.zip"
FINAL_DMG="$ROOT_DIR/dist/Tilde.dmg"
CHECKSUMS="$ROOT_DIR/dist/checksums.txt"
rm -rf "$PROOF_DIR"
rm -f "$NOTARY_ZIP" "$STAGING_DMG" "$FINAL_ZIP" "$FINAL_DMG" "$CHECKSUMS"
mkdir -p "$PROOF_DIR"

record() {
  local output="$1"
  shift
  "$@" 2>&1 | tee "$output"
}

require_notary_accepted() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if payload.get("status") != "Accepted":
    raise SystemExit(f"notarization was not accepted: {payload.get('status', 'missing status')}")
PY
}

echo "==> full pre-release proof"
./script/proof.sh fast

echo "==> building release app without touching the running app"
./script/build_and_run.sh \
  --release \
  --scratch-path "$ROOT_DIR/.build-release" \
  --version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --sign-identity "$SIGN_IDENTITY"

echo "==> building packaged input method"
IME_SIGN_IDENTITY="$SIGN_IDENTITY" ./script/build_ime.sh \
  --no-install --no-notarize --version "$VERSION" --build-number "$BUILD_NUMBER"

echo "==> embedding app-owned runtime, input method, and model"
verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
verify_sha256 "model input" "$MODEL" "$MODEL_SHA256"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Library" "$APP/Contents/Resources"
cp "$LLAMA_SERVER" "$APP/Contents/Helpers/llama-server"
chmod +x "$APP/Contents/Helpers/llama-server"
rm -rf "$APP/Contents/Library/InlineGhostIME.app"
cp -R "$IME" "$APP/Contents/Library/InlineGhostIME.app"
cp "$MODEL" "$APP/Contents/Resources/bundled-model.gguf"
verify_sha256 "bundled llama-server" "$APP/Contents/Helpers/llama-server" "$LLAMA_SHA256"
verify_sha256 "bundled model" "$APP/Contents/Resources/bundled-model.gguf" "$MODEL_SHA256"

echo "==> signing nested code and app with hardened runtime"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Helpers/llama-server"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Library/InlineGhostIME.app"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
record "$PROOF_DIR/codesign-verify.txt" codesign --verify --deep --strict --verbose=2 "$APP"
./script/check_app_bundle.sh --release "$APP"

echo "==> exercising the exact packaged process tree"
./script/restart_app.sh
python3 script/check_runtime_network_egress.py \
  --app-binary "$APP/Contents/MacOS/Tilde" \
  --proof-out "$PROOF_DIR/runtime-socket-observation.json"

echo "==> notarizing and stapling the app"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
record "$PROOF_DIR/notarytool-app-submit.txt" \
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json
require_notary_accepted "$PROOF_DIR/notarytool-app-submit.txt"
record "$PROOF_DIR/stapler-app.txt" xcrun stapler staple "$APP"
record "$PROOF_DIR/stapler-app-validate.txt" xcrun stapler validate "$APP"
record "$PROOF_DIR/spctl-app.txt" spctl --assess --type execute --verbose=4 "$APP"

echo "==> creating, notarizing, and stapling the DMG"
DMG_SOURCE="$(mktemp -d "${TMPDIR:-/tmp}/tilde-dmg.XXXXXX")"
trap 'rm -rf "$DMG_SOURCE"' EXIT
cp -R "$APP" "$DMG_SOURCE/Tilde.app"
ln -s /Applications "$DMG_SOURCE/Applications"
rm -f "$STAGING_DMG"
hdiutil create -volname Tilde -srcfolder "$DMG_SOURCE" -ov -format UDZO "$STAGING_DMG" >/dev/null
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$STAGING_DMG"
record "$PROOF_DIR/notarytool-dmg-submit.txt" \
  xcrun notarytool submit "$STAGING_DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json
require_notary_accepted "$PROOF_DIR/notarytool-dmg-submit.txt"
record "$PROOF_DIR/stapler-dmg.txt" xcrun stapler staple "$STAGING_DMG"
record "$PROOF_DIR/stapler-dmg-validate.txt" xcrun stapler validate "$STAGING_DMG"
record "$PROOF_DIR/spctl-dmg.txt" \
  spctl --assess --type open --context context:primary-signature --verbose=4 "$STAGING_DMG"

echo "==> creating final ZIP and checksums"
mv "$STAGING_DMG" "$FINAL_DMG"
rm -f "$FINAL_ZIP"
ditto -c -k --keepParent "$APP" "$FINAL_ZIP"
(cd "$ROOT_DIR/dist" && shasum -a 256 Tilde.dmg Tilde.zip) | tee "$CHECKSUMS"
rm -f "$NOTARY_ZIP"

echo "Release ready:"
echo "  $FINAL_DMG"
echo "  $FINAL_ZIP"
echo "  $CHECKSUMS"
echo "  $PROOF_DIR"
