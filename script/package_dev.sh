#!/usr/bin/env bash
# Dev packaging lane: test, build, embed the pinned helper, and sign a daily-driver
# bundle with an Apple Development identity. DMG creation, notarization,
# stapling, Gatekeeper assessment, and dist/release-proof reports belong only
# to the fail-closed release driver, script/package_app.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/signing_identity.sh"

LLAMA_SERVER=""
LLAMA_SHA256=""
SIGN_IDENTITY=""
VERSION="0.1.0"
SELFTEST=0

usage() {
  cat <<'EOF'
Usage: script/package_dev.sh --llama-server PATH --llama-sha256 SHA256 [options]
       script/package_dev.sh --selftest

Local iteration lane. Runs the same fast proof gate and bundle assembly as the
release driver, with the same pinned helper input, then signs with an
Apple Development identity and stops: no DMG, no notarization, no stapling, no
Gatekeeper assessment, and no dist/release-proof report. Install the result
with script/restart_app.sh. The fail-closed release path stays
script/package_app.sh; this lane never produces a release artifact.

Dev inputs:
  --llama-server PATH       Static llama-server with system-only dependencies.
  --llama-sha256 SHA256     Human-reviewed SHA-256 pin for the helper bytes.
The selectable Gemma 4 E2B and Qwen 3.5 9B models are never embedded. The
installed dev app uses the same verified Application Support download flow as
production.

Options:
  --version VERSION         Base version (default: 0.1.0). The bundle always
                            carries the -dev suffix so a dev build can never
                            be mistaken for a release artifact.
  --sign-identity SHA1      Exact Apple Development identity SHA-1. Without
                            it, the sole eligible Apple Development identity
                            is used. Developer ID and ad hoc identities are
                            refused here.
  --selftest                Validate this lane's labeling and refusal logic
                            without building or signing anything.

Labeling convention: CFBundleShortVersionString is always VERSION-dev and
CFBundleVersion is a minute-resolution timestamp (YYYYMMDDHHMM). Releases use
plain versions with small operator-chosen build numbers, so the two lanes can
never produce look-alike bundles. Release-only flags (--notary-profile,
--build-number, --sign-identity with a Developer ID certificate, and
--verify-inputs-only) are refused with a pointer to script/package_app.sh, and
this lane never writes the release proof report or DMG/ZIP/checksum artifacts.
EOF
}

while (($#)); do
  case "$1" in
    --llama-server|--llama-sha256|--sign-identity|--version)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --llama-server) LLAMA_SERVER="$2" ;;
        --llama-sha256) LLAMA_SHA256="$2" ;;
        --sign-identity) SIGN_IDENTITY="$2" ;;
        --version) VERSION="$2" ;;
      esac
      shift
      ;;
    --model|--model-sha256|--proof-model|--proof-model-sha256|--proof-gemma-model|--proof-gemma-model-sha256|--proof-qwen-model|--proof-qwen-model-sha256)
      echo "package_dev.sh does not accept model inputs; the model is downloaded outside the app" >&2
      exit 2
      ;;
    --notary-profile|--build-number|--verify-inputs-only)
      echo "package_dev.sh refuses release-only flag $1; releases go through script/package_app.sh" >&2
      exit 2
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

dev_version() {
  printf '%s-dev' "${1%-dev}"
}

dev_build_number() {
  date +%Y%m%d%H%M
}

# Empty output means the resolved identity is acceptable for the dev lane.
dev_identity_error() {
  local resolved="$1" details="$2"
  if [[ "$resolved" == "-" ]]; then
    printf 'ad hoc signing is refused here: the dev lane exists to daily-drive the authenticated app-to-IME runtime'
    return
  fi
  awk -v wanted="$resolved" '
    $1 ~ /^[0-9]+\)$/ && toupper($2) == toupper(wanted) \
      && /"Apple Development: [^"]+"[[:space:]]*$/ { found = 1 }
    END { exit !found }
  ' <<<"$details" \
    || printf '%s is not an Apple Development certificate; Developer ID signing belongs to script/package_app.sh' "$resolved"
}

run_selftest() {
  local a='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  local d='CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
  local details
  details="1) $a \"Apple Development: Tilde Dev (TEAMID1234)\""$'\n'"2) $d \"Developer ID Application: Tilde Dev (TEAMID1234)\""

  [[ "$(dev_version 0.1.0)" == "0.1.0-dev" ]]
  [[ "$(dev_version 0.1.0-dev)" == "0.1.0-dev" ]]
  [[ "$(dev_build_number)" =~ ^[0-9]{12}$ ]]

  [[ -z "$(dev_identity_error "$a" "$details")" ]]
  [[ -n "$(dev_identity_error "$d" "$details")" ]]
  [[ -n "$(dev_identity_error '-' "$details")" ]]

  local flag refusal
  for flag in --notary-profile --build-number --verify-inputs-only; do
    if refusal="$("$ROOT_DIR/script/package_dev.sh" "$flag" ignored 2>&1 >/dev/null)"; then
      echo "selftest FAIL: release-only flag $flag was not refused" >&2
      return 1
    fi
    [[ "$refusal" == "package_dev.sh refuses release-only flag $flag; releases go through script/package_app.sh" ]] \
      || { echo "selftest FAIL: $flag failed for a reason other than the refusal branch: $refusal" >&2; return 1; }
  done

  echo "selftest OK: dev lane labels -dev builds and refuses release-only flags and identities"
}

if [[ "$SELFTEST" == "1" ]]; then
  run_selftest
  exit 0
fi

[[ -f "$LLAMA_SERVER" ]] || { echo "missing --llama-server file: $LLAMA_SERVER" >&2; exit 2; }
[[ -x "$LLAMA_SERVER" ]] || { echo "llama-server is not executable: $LLAMA_SERVER" >&2; exit 2; }
./script/check_app_bundle.sh --release-helper "$LLAMA_SERVER"
LLAMA_SHA256="$(normalize_sha256 --llama-sha256 "$LLAMA_SHA256")"
verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "$(dev_identity_error '-' '')" >&2
  exit 2
fi
IDENTITY_DETAILS="$(security find-identity -p codesigning -v 2>/dev/null)" \
  || { echo "could not read eligible code-signing identities" >&2; exit 1; }
SIGN_IDENTITY="$(tilde_resolve_signing_identity_from_details "$SIGN_IDENTITY" "$IDENTITY_DETAILS")"
IDENTITY_ERROR="$(dev_identity_error "$SIGN_IDENTITY" "$IDENTITY_DETAILS")"
[[ -z "$IDENTITY_ERROR" ]] || { echo "$IDENTITY_ERROR" >&2; exit 1; }

VERSION="$(dev_version "$VERSION")"
BUILD_NUMBER="$(dev_build_number)"
APP="$ROOT_DIR/dist/Tilde.app"
IME="$ROOT_DIR/dist/InlineGhostIME.app"

echo "==> fast proof gate (same as the release driver)"
./script/proof.sh fast

echo "==> building dev app without touching the running app"
./script/build_and_run.sh \
  --release \
  --scratch-path "$ROOT_DIR/.build-release" \
  --version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --sign-identity "$SIGN_IDENTITY"

echo "==> building input method"
./script/build_ime.sh \
  --version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --sign-identity "$SIGN_IDENTITY"

echo "==> embedding app-owned runtime and input method (model remains external)"
./script/check_app_bundle.sh --release-helper "$LLAMA_SERVER"
verify_sha256 "llama-server input" "$LLAMA_SERVER" "$LLAMA_SHA256"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Library" "$APP/Contents/Resources"
cp "$LLAMA_SERVER" "$APP/Contents/Helpers/llama-server"
chmod +x "$APP/Contents/Helpers/llama-server"
rm -rf "$APP/Contents/Library/InlineGhostIME.app"
cp -R "$IME" "$APP/Contents/Library/InlineGhostIME.app"
verify_sha256 "bundled llama-server" "$APP/Contents/Helpers/llama-server" "$LLAMA_SHA256"
strip -S -x "$APP/Contents/Helpers/llama-server"
if find "$APP" -type f -iname '*.gguf' -print -quit | grep -q .; then
  echo "dev app unexpectedly contains a GGUF model" >&2
  exit 1
fi

echo "==> signing nested code and app with the Apple Development identity"
codesign --force --options runtime --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Helpers/llama-server"
codesign --force --options runtime --sign "$SIGN_IDENTITY" \
  "$APP/Contents/Library/InlineGhostIME.app"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
./script/check_app_bundle.sh "$APP"
./script/check_app_bundle.sh --release-helper "$APP/Contents/Helpers/llama-server"

echo "==> verifying the bundle is unmistakably a dev build"
plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}
APP_VERSION="$(plist_value CFBundleShortVersionString "$APP/Contents/Info.plist")"
APP_BUILD="$(plist_value CFBundleVersion "$APP/Contents/Info.plist")"
[[ "$APP_VERSION" == *-dev ]] || { echo "dev bundle version lacks the -dev suffix: $APP_VERSION" >&2; exit 1; }
[[ "$APP_BUILD" =~ ^[0-9]{12}$ ]] \
  || { echo "dev bundle build number does not follow the timestamp convention: $APP_BUILD" >&2; exit 1; }
IME_PLIST="$APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist"
[[ "$(plist_value CFBundleShortVersionString "$IME_PLIST")" == "$APP_VERSION" ]] \
  || { echo "input method dev version mismatch" >&2; exit 1; }
[[ "$(plist_value CFBundleVersion "$IME_PLIST")" == "$APP_BUILD" ]] \
  || { echo "input method dev build number mismatch" >&2; exit 1; }
SIGNATURE_DETAILS="$(codesign --display --verbose=4 "$APP" 2>&1)"
if grep -F "Authority=Developer ID Application" <<<"$SIGNATURE_DETAILS" >/dev/null; then
  echo "dev bundle must not carry a Developer ID signature; releases go through script/package_app.sh" >&2
  exit 1
fi

echo "Dev build ready (not a release artifact):"
echo "  $APP  version $APP_VERSION build $APP_BUILD"
echo "Install it with ./script/restart_app.sh."
echo "No DMG, notarization, stapling, Gatekeeper assessment, or release proof"
echo "report was produced; those lanes live only in script/package_app.sh."
