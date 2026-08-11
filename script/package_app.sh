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
BUILD_NUMBER=""
VERIFY_INPUTS_ONLY=0
SELFTEST=0

usage() {
  cat <<'EOF'
Usage: script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --model PATH --model-sha256 SHA256 --build-number NUMBER \
  --notary-profile PROFILE [options]
       script/package_app.sh --llama-server PATH --llama-sha256 SHA256 \
  --model PATH --model-sha256 SHA256 --verify-inputs-only
       script/package_app.sh --selftest

Release inputs:
  --llama-server PATH       Static llama-server with system-only dependencies.
  --llama-sha256 SHA256     Human-reviewed SHA-256 pin for the helper bytes.
  --model PATH              GGUF model embedded in the app.
  --model-sha256 SHA256     Human-reviewed SHA-256 pin for the model bytes.

Full release only:
  --notary-profile PROFILE  Stored notarytool keychain profile.
  --build-number NUMBER     Required numeric bundle build number.

Options:
  --sign-identity IDENTITY  Developer ID Application identity (auto-detected).
  --version VERSION         Release version (default: 0.1.0).
  --verify-inputs-only      Verify pinned inputs, then exit without building,
                            signing, notarizing, or uploading anything.
  --selftest                Test Developer ID identity selection without using
                            the keychain or performing release actions.

This is intentionally fail-closed. It creates release artifacts only after the
full test suite, isolated packaged-helper health/completion/socket observation,
Apple notarization, stapling, and Gatekeeper assessment all pass. The proof may
append privacy-safe diagnostics but leaves the daily driver and input method
untouched.
Shape checks and matching hashes do not establish input provenance; the release
operator remains responsible for reviewing where the helper and model came from.
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
    --selftest)
      SELFTEST=1
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

developer_id_application_candidates() {
  /usr/bin/sed -nE \
    's/^[[:space:]]*[0-9]+\)[[:space:]]+([[:xdigit:]]{40})[[:space:]]+"(Developer ID Application:[^"]+)"[[:space:]]*$/\1|\2/p' \
    <<<"$1"
}

resolve_developer_id_application() {
  local details="$1"
  local wanted="${2:-}"
  local hash name selected="" count=0
  while IFS='|' read -r hash name; do
    [[ -n "$hash" ]] || continue
    if [[ -z "$wanted" || "$wanted" == "$hash" || "$wanted" == "$name" ]]; then
      selected="$hash"
      count=$((count + 1))
    fi
  done < <(developer_id_application_candidates "$details")
  [[ "$count" -gt 0 ]] || return 1
  [[ "$count" -eq 1 ]] || return 2
  printf '%s\n' "$selected"
}

run_identity_selftest() {
  local real_hash="0123456789ABCDEF0123456789ABCDEF01234567"
  local second_hash="89ABCDEF0123456789ABCDEF0123456789ABCDEF"
  local fake_hash="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  local real_name="Developer ID Application: Real Person (ABCDE12345)"
  local details selected status
  details="$(printf '%s\n' \
    "  1) $fake_hash \"Fake Developer ID Application: Lookalike (FAKE123456)\"" \
    "  2) $real_hash \"$real_name\"" \
    "  3) $second_hash Developer ID Application: unquoted" \
    "     3 valid identities found")"
  selected="$(resolve_developer_id_application "$details")" \
    || { echo "selftest failed: unique real identity was not selected" >&2; return 1; }
  [[ "$selected" == "$real_hash" ]] \
    || { echo "selftest failed: lookalike identity was selected" >&2; return 1; }
  if resolve_developer_id_application "$details" "$fake_hash" >/dev/null; then
    echo "selftest failed: lookalike identity hash was accepted" >&2
    return 1
  fi
  if selected="$(resolve_developer_id_application \
    "  1) $fake_hash \"Fake Developer ID Application: Lookalike (FAKE123456)\"")"; then
    echo "selftest failed: lookalike-only output selected $selected" >&2
    return 1
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] \
    || { echo "selftest failed: no real identity did not fail distinctly" >&2; return 1; }

  details="$(printf '%s\n' \
    "  1) $real_hash \"$real_name\"" \
    "  2) $second_hash \"Developer ID Application: Other Person (ZYXWV98765)\"")"
  if selected="$(resolve_developer_id_application "$details")"; then
    echo "selftest failed: ambiguous identities selected $selected" >&2
    return 1
  else
    status=$?
  fi
  [[ "$status" -eq 2 ]] \
    || { echo "selftest failed: ambiguity did not fail distinctly" >&2; return 1; }
  [[ "$(resolve_developer_id_application "$details" "$second_hash")" == "$second_hash" ]] \
    || { echo "selftest failed: exact identity hash did not resolve" >&2; return 1; }

  echo "selftest OK: Developer ID selection rejects lookalikes, absence, and ambiguity"
}

if [[ "$SELFTEST" == "1" ]]; then
  [[ -z "$LLAMA_SERVER$LLAMA_SHA256$MODEL$MODEL_SHA256$SIGN_IDENTITY$NOTARY_PROFILE$BUILD_NUMBER" \
    && "$VERIFY_INPUTS_ONLY" == "0" ]] \
    || { echo "--selftest cannot be combined with release options" >&2; exit 2; }
  run_identity_selftest
  exit 0
fi

[[ -f "$LLAMA_SERVER" ]] || { echo "missing --llama-server file: $LLAMA_SERVER" >&2; exit 2; }
[[ -x "$LLAMA_SERVER" ]] || { echo "llama-server is not executable: $LLAMA_SERVER" >&2; exit 2; }
[[ -s "$MODEL" ]] || { echo "missing --model file: $MODEL" >&2; exit 2; }
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$MODEL"
LLAMA_SHA256="$(normalize_sha256 --llama-sha256 "$LLAMA_SHA256")"
MODEL_SHA256="$(normalize_sha256 --model-sha256 "$MODEL_SHA256")"

verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
verify_sha256 "model input" "$MODEL" "$MODEL_SHA256"

if [[ "$VERIFY_INPUTS_ONLY" == "1" ]]; then
  echo "Release shapes passed and caller-provided SHA-256 pins match."
  echo "Input provenance remains a human review boundary."
  echo "No build, signing, notarization, or upload performed."
  exit 0
fi

[[ -n "$BUILD_NUMBER" ]] || { echo "--build-number is required for a full release" >&2; exit 2; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }
[[ -n "$NOTARY_PROFILE" ]] || { echo "--notary-profile is required" >&2; exit 2; }

IDENTITY_DETAILS="$(security find-identity -p codesigning -v 2>/dev/null)" \
  || { echo "unable to list code-signing identities" >&2; exit 1; }
if RESOLVED_IDENTITY="$(resolve_developer_id_application "$IDENTITY_DETAILS" "$SIGN_IDENTITY")"; then
  SIGN_IDENTITY="$RESOLVED_IDENTITY"
else
  IDENTITY_STATUS=$?
  if [[ "$IDENTITY_STATUS" -eq 2 ]]; then
    echo "Developer ID Application signing identity is ambiguous; use --sign-identity with its exact hash" >&2
  elif [[ -n "$SIGN_IDENTITY" ]]; then
    echo "signing identity is unavailable or is not Developer ID Application: $SIGN_IDENTITY" >&2
  else
    echo "missing Developer ID Application signing identity" >&2
  fi
  exit 1
fi

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

echo "==> embedding app-owned runtime, input method, and model"
./script/check_app_bundle.sh --release-inputs "$LLAMA_SERVER" "$MODEL"
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

echo "==> exercising the exact packaged helper without touching the input method"
RELEASE_PROOF_ACTIVE=1
./script/restart_app.sh --release-proof
python3 script/check_runtime_network_egress.py \
  --app-binary "$APP/Contents/MacOS/Tilde" \
  --port 17873 \
  --synthetic-helper-proof \
  --proof-out "$PROOF_DIR/runtime-socket-observation.json"
./script/restart_app.sh --release-proof --cleanup
RELEASE_PROOF_ACTIVE=0

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
