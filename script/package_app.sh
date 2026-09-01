#!/usr/bin/env bash
# Single release driver: test, build, stage, sign, exercise, notarize, staple,
# package, and checksum a Tilde release. The GGUF is never embedded in the app;
# Both --proof-*-model inputs are proof-only preseeds used by isolated runtime lanes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LLAMA_SERVER=""
LLAMA_SHA256=""
PROOF_GEMMA_MODEL=""
PROOF_GEMMA_MODEL_SHA256="389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2"
PROOF_QWEN_MODEL=""
PROOF_QWEN_MODEL_SHA256="4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
SIGN_IDENTITY=""
NOTARY_PROFILE=""
VERSION="0.1.0"
BUILD_NUMBER=""
VERIFY_INPUTS_ONLY=0

GEMMA_MODEL_REVISION="3762686d74ff8db6c98f8d3c389f56fbdf994d5a"
GEMMA_MODEL_FILENAME="gemma-4-E2B.Q4_K_M.gguf"
GEMMA_MODEL_BYTES=3427861984
GEMMA_MODEL_SHA256="389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2"
GEMMA_MODEL_URL="https://huggingface.co/mradermacher/gemma-4-E2B-GGUF/resolve/${GEMMA_MODEL_REVISION}/${GEMMA_MODEL_FILENAME}"
QWEN_MODEL_REVISION="ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6"
QWEN_MODEL_FILENAME="Qwen3.5-9B-Base.Q4_K_M.gguf"
QWEN_MODEL_BYTES=5629109312
QWEN_MODEL_SHA256="4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
QWEN_MODEL_URL="https://huggingface.co/mradermacher/Qwen3.5-9B-Base-GGUF/resolve/${QWEN_MODEL_REVISION}/${QWEN_MODEL_FILENAME}"

usage() {
  cat <<'EOF'
Usage: script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --proof-gemma-model PATH --proof-qwen-model PATH --build-number NUMBER \
  --notary-profile PROFILE [options]
       script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --proof-gemma-model PATH --proof-qwen-model PATH --verify-inputs-only

Release inputs:
  --llama-server PATH       Static llama-server with system-only dependencies.
  --llama-sha256 SHA256     Human-reviewed SHA-256 pin for the helper bytes.
  --proof-gemma-model PATH  Preseeded Gemma 4 E2B GGUF for release proof only;
                            it is copied to isolated external model storage and
                            never copied into Tilde.app.
  --proof-gemma-model-sha256 SHA256
                            Optional assertion of the fixed Gemma pin.
  --proof-qwen-model PATH   Preseeded Qwen 3.5 9B GGUF for release proof only.
  --proof-qwen-model-sha256 SHA256
                            Optional assertion of the fixed Qwen pin.

Full release only:
  --notary-profile PROFILE  Stored notarytool keychain profile.
  --build-number NUMBER     Required numeric bundle build number.
  --sign-identity SHA1      Required Developer ID Application certificate hash.

Options:
  --version VERSION         Release version (default: 0.1.0).
  --verify-inputs-only      Verify pinned inputs, then exit without building,
                            signing, notarizing, or uploading anything.

This is intentionally fail-closed. It creates release artifacts only after the
full test suite, isolated helper health/completion/socket observation against
the preseeded external model, the in-process Screen Memory capture/redaction
stimulus (synthetic conversation classified, scene-bearing prompt completed
over loopback, redaction redacts or fails closed), Apple notarization,
stapling, and Gatekeeper
assessment all pass. The proof may append privacy-safe diagnostics but leaves
the daily driver and input method untouched.
The production app may download either exact immutable model URL during its
separate user-selected asset phase; no user-derived request data is sent:
https://huggingface.co/mradermacher/gemma-4-E2B-GGUF/resolve/3762686d74ff8db6c98f8d3c389f56fbdf994d5a/gemma-4-E2B.Q4_K_M.gguf
https://huggingface.co/mradermacher/Qwen3.5-9B-Base-GGUF/resolve/ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6/Qwen3.5-9B-Base.Q4_K_M.gguf
Both exact byte counts and SHA-256 pins are verified below.
Shape checks and matching hashes do not establish input provenance; the release
operator remains responsible for reviewing where the helper and models came from.
EOF
}

while (($#)); do
  case "$1" in
    --llama-server|--llama-sha256|--proof-gemma-model|--proof-gemma-model-sha256|--proof-qwen-model|--proof-qwen-model-sha256|--notary-profile|--sign-identity|--version|--build-number)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --llama-server) LLAMA_SERVER="$2" ;;
        --llama-sha256) LLAMA_SHA256="$2" ;;
        --proof-gemma-model) PROOF_GEMMA_MODEL="$2" ;;
        --proof-gemma-model-sha256) PROOF_GEMMA_MODEL_SHA256="$2" ;;
        --proof-qwen-model) PROOF_QWEN_MODEL="$2" ;;
        --proof-qwen-model-sha256) PROOF_QWEN_MODEL_SHA256="$2" ;;
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
    --model|--model-sha256|--proof-model|--proof-model-sha256)
      echo "$1 is obsolete: releases require explicit Gemma and Qwen proof-model inputs" >&2
      exit 2
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

[[ "$VERSION" != *-dev* ]] \
  || { echo "release version must not carry the -dev suffix; that labels script/package_dev.sh builds" >&2; exit 2; }

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
[[ -s "$PROOF_GEMMA_MODEL" ]] || { echo "missing --proof-gemma-model file: $PROOF_GEMMA_MODEL" >&2; exit 2; }
[[ -s "$PROOF_QWEN_MODEL" ]] || { echo "missing --proof-qwen-model file: $PROOF_QWEN_MODEL" >&2; exit 2; }
[[ "$(basename "$PROOF_GEMMA_MODEL")" == "$GEMMA_MODEL_FILENAME" ]] \
  || { echo "--proof-gemma-model must be named $GEMMA_MODEL_FILENAME" >&2; exit 2; }
[[ "$(basename "$PROOF_QWEN_MODEL")" == "$QWEN_MODEL_FILENAME" ]] \
  || { echo "--proof-qwen-model must be named $QWEN_MODEL_FILENAME" >&2; exit 2; }
PROOF_GEMMA_MODEL_SHA256="$(normalize_sha256 --proof-gemma-model-sha256 "$PROOF_GEMMA_MODEL_SHA256")"
PROOF_QWEN_MODEL_SHA256="$(normalize_sha256 --proof-qwen-model-sha256 "$PROOF_QWEN_MODEL_SHA256")"
[[ "$PROOF_GEMMA_MODEL_SHA256" == "$GEMMA_MODEL_SHA256" ]] \
  || { echo "Gemma proof-model SHA-256 must match $GEMMA_MODEL_SHA256" >&2; exit 2; }
[[ "$PROOF_QWEN_MODEL_SHA256" == "$QWEN_MODEL_SHA256" ]] \
  || { echo "Qwen proof-model SHA-256 must match $QWEN_MODEL_SHA256" >&2; exit 2; }
PROOF_GEMMA_MODEL_BYTES="$(/usr/bin/stat -f '%z' "$PROOF_GEMMA_MODEL" 2>/dev/null || true)"
PROOF_QWEN_MODEL_BYTES="$(/usr/bin/stat -f '%z' "$PROOF_QWEN_MODEL" 2>/dev/null || true)"
[[ "$PROOF_GEMMA_MODEL_BYTES" == "$GEMMA_MODEL_BYTES" ]] \
  || { echo "Gemma proof-model size mismatch: expected $GEMMA_MODEL_BYTES, got ${PROOF_GEMMA_MODEL_BYTES:-unknown}" >&2; exit 1; }
[[ "$PROOF_QWEN_MODEL_BYTES" == "$QWEN_MODEL_BYTES" ]] \
  || { echo "Qwen proof-model size mismatch: expected $QWEN_MODEL_BYTES, got ${PROOF_QWEN_MODEL_BYTES:-unknown}" >&2; exit 1; }
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$PROOF_GEMMA_MODEL"
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$PROOF_QWEN_MODEL"
LLAMA_SHA256="$(normalize_sha256 --llama-sha256 "$LLAMA_SHA256")"

verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
verify_sha256 "proof-only Gemma 4 E2B model" "$PROOF_GEMMA_MODEL" "$GEMMA_MODEL_SHA256"
verify_sha256 "proof-only Qwen 3.5 9B model" "$PROOF_QWEN_MODEL" "$QWEN_MODEL_SHA256"

if [[ "$VERIFY_INPUTS_ONLY" == "1" ]]; then
  echo "Release helper shape and both proof-only model pins passed."
  echo "Gemma revision: $GEMMA_MODEL_REVISION"
  echo "Gemma URL: $GEMMA_MODEL_URL"
  echo "Qwen revision: $QWEN_MODEL_REVISION"
  echo "Qwen URL: $QWEN_MODEL_URL"
  echo "Input provenance remains a human review boundary."
  echo "No build, signing, notarization, or upload performed."
  exit 0
fi

[[ -n "$BUILD_NUMBER" ]] || { echo "--build-number is required for a full release" >&2; exit 2; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }
[[ -n "$NOTARY_PROFILE" ]] || { echo "--notary-profile is required" >&2; exit 2; }
[[ -n "$SIGN_IDENTITY" ]] || { echo "--sign-identity is required for a full release" >&2; exit 2; }
SIGN_IDENTITY="$(tr '[:lower:]' '[:upper:]' <<<"$SIGN_IDENTITY")"
[[ "$SIGN_IDENTITY" =~ ^[[:xdigit:]]{40}$ ]] \
  || { echo "--sign-identity must be an exact 40-character SHA-1" >&2; exit 2; }
IDENTITY_DETAILS="$(security find-identity -p codesigning -v 2>/dev/null)" \
  || { echo "unable to list code-signing identities" >&2; exit 1; }
RESOLVED_IDENTITY="$(awk -v wanted="$SIGN_IDENTITY" \
  '$2 == wanted && /"Developer ID Application:[^"]+"[[:space:]]*$/ { print $2; exit }' \
  <<<"$IDENTITY_DETAILS")"
[[ "$RESOLVED_IDENTITY" == "$SIGN_IDENTITY" ]] \
  || { echo "Developer ID Application identity is unavailable: $SIGN_IDENTITY" >&2; exit 1; }

echo "==> validating Apple notary credentials"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null

APP="$ROOT_DIR/dist/Tilde.app"
IME="$ROOT_DIR/dist/InlineGhostIME.app"
PROOF_DIR="$ROOT_DIR/dist/release-proof"
PROOF_MODEL_ROOT="$PROOF_DIR/model-store"
PROOF_GEMMA_DIRECTORY="$PROOF_MODEL_ROOT/gemma-4-e2b-q4km"
PROOF_GEMMA_PATH="$PROOF_GEMMA_DIRECTORY/model.gguf"
PROOF_QWEN_DIRECTORY="$PROOF_MODEL_ROOT/qwen3.5-9b-base-q4km"
PROOF_QWEN_PATH="$PROOF_QWEN_DIRECTORY/model.gguf"
NOTARY_ZIP="$ROOT_DIR/dist/Tilde-notarize.zip"
STAGING_DMG="$ROOT_DIR/dist/Tilde-notarize.dmg"
FINAL_ZIP="$ROOT_DIR/dist/Tilde.zip"
FINAL_DMG="$ROOT_DIR/dist/Tilde.dmg"
CHECKSUMS="$ROOT_DIR/dist/checksums.txt"
DMG_SOURCE=""
RELEASE_PROOF_ACTIVE=0
rm -rf "$PROOF_DIR"
rm -f "$NOTARY_ZIP" "$STAGING_DMG" "$FINAL_ZIP" "$FINAL_DMG" "$CHECKSUMS"
mkdir -p "$PROOF_DIR"

cleanup() {
  if [[ "$RELEASE_PROOF_ACTIVE" == "1" ]]; then
    ./script/restart_app.sh --release-proof --cleanup >/dev/null 2>&1 \
      || echo "warning: exact release-proof candidate cleanup failed" >&2
  fi
  unset TILDE_MODEL_DIRECTORY
  [[ -z "${PROOF_MODEL_ROOT:-}" ]] || rm -rf "$PROOF_MODEL_ROOT"
  [[ -z "$DMG_SOURCE" ]] || rm -rf "$DMG_SOURCE"
}
trap cleanup EXIT

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
./script/build_ime.sh \
  --version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --sign-identity "$SIGN_IDENTITY"

echo "==> staging app-owned runtime and input method (model remains external)"
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$PROOF_GEMMA_MODEL"
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$PROOF_QWEN_MODEL"
verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Library" "$APP/Contents/Resources"
cp "$LLAMA_SERVER" "$APP/Contents/Helpers/llama-server"
chmod +x "$APP/Contents/Helpers/llama-server"
rm -rf "$APP/Contents/Library/InlineGhostIME.app"
cp -R "$IME" "$APP/Contents/Library/InlineGhostIME.app"
verify_sha256 "bundled llama-server" "$APP/Contents/Helpers/llama-server" "$LLAMA_SHA256"
strip -S -x "$APP/Contents/Helpers/llama-server"
if find "$APP" -type f -iname '*.gguf' -print -quit | grep -q .; then
  echo "release app unexpectedly contains a GGUF model" >&2
  exit 1
fi

echo "==> signing nested code and app with hardened runtime"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Helpers/llama-server"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Library/InlineGhostIME.app"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
record "$PROOF_DIR/codesign-verify.txt" codesign --verify --deep --strict --verbose=2 "$APP"
./script/check_app_bundle.sh --release "$APP"

echo "==> exercising both selectable models with the exact packaged helper"
mkdir -p "$PROOF_GEMMA_DIRECTORY" "$PROOF_QWEN_DIRECTORY"
cp "$PROOF_GEMMA_MODEL" "$PROOF_GEMMA_PATH"
cp "$PROOF_QWEN_MODEL" "$PROOF_QWEN_PATH"
chmod 600 "$PROOF_GEMMA_PATH" "$PROOF_QWEN_PATH"
verify_sha256 "isolated Gemma proof model" "$PROOF_GEMMA_PATH" "$GEMMA_MODEL_SHA256"
verify_sha256 "isolated Qwen proof model" "$PROOF_QWEN_PATH" "$QWEN_MODEL_SHA256"
export TILDE_MODEL_DIRECTORY="$PROOF_MODEL_ROOT"
RELEASE_PROOF_ACTIVE=1

for proof_choice in gemma-4-e2b-q4km qwen-3.5-9b-base-q4km; do
  if [[ "$proof_choice" == "gemma-4-e2b-q4km" ]]; then
    proof_label="gemma-e2b"
    proof_path="$PROOF_GEMMA_PATH"
  else
    proof_label="qwen-9b"
    proof_path="$PROOF_QWEN_PATH"
  fi
  export TILDE_RELEASE_PROOF_MODEL="$proof_choice"
  export TILDE_RELEASE_PROOF_STIMULUS_OUT="$PROOF_DIR/screen-memory-stimulus-$proof_label.json"
  ./script/restart_app.sh --release-proof
  python3 script/check_runtime_network_egress.py \
    --app-binary "$APP/Contents/MacOS/Tilde" \
    --port 17873 \
    --model-path "$proof_path" \
    --synthetic-helper-proof \
    --stimulus-proof "$TILDE_RELEASE_PROOF_STIMULUS_OUT" \
    --proof-out "$PROOF_DIR/runtime-socket-observation-$proof_label.json"
  ./script/restart_app.sh --release-proof --cleanup
done

RELEASE_PROOF_ACTIVE=0
unset TILDE_MODEL_DIRECTORY
unset TILDE_RELEASE_PROOF_MODEL
unset TILDE_RELEASE_PROOF_STIMULUS_OUT

echo "==> notarizing and stapling the app"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
record "$PROOF_DIR/notarytool-app-submit.txt" \
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json
require_notary_accepted "$PROOF_DIR/notarytool-app-submit.txt"
record "$PROOF_DIR/stapler-app.txt" xcrun stapler staple "$APP"
record "$PROOF_DIR/stapler-app-validate.txt" xcrun stapler validate "$APP"
./script/check_app_bundle.sh --release "$APP"
record "$PROOF_DIR/spctl-app.txt" spctl --assess --type execute --verbose=4 "$APP"

echo "==> creating, notarizing, and stapling the DMG"
DMG_SOURCE="$(mktemp -d "${TMPDIR:-/tmp}/tilde-dmg.XXXXXX")"
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
