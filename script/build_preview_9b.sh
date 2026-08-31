#!/usr/bin/env bash
# Build the separately identified Qwen 9B preview without mutating production or 26B Tilde.
set -euo pipefail
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

ROOT_DIR="$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/signing_identity.sh"
source "$ROOT_DIR/script/source_provenance.sh"

MODEL_SOURCE="${TILDE_PREVIEW_MODEL_SOURCE:-$HOME/Library/Application Support/Tilde Lab/Models/qwen3.5-9b-base-q4_k_m.gguf}"
HELPER_SOURCE="${TILDE_PREVIEW_HELPER_SOURCE:-/Applications/Tilde 9B Preview.app/Contents/Helpers/llama-server}"
HELPER_SHA256="${TILDE_PREVIEW_HELPER_SHA256:-}"
HELPER_TEAM="${TILDE_PREVIEW_HELPER_TEAM:-}"
EXPECTED_MODEL_BYTES=5629109312
EXPECTED_MODEL_SHA256="4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
APP_NAME="Tilde 9B Preview"
APP_ID="bar.r3d.tilde.preview9b"
IME_ID="bar.r3d.inputmethod.InlineGhostPreview9B"
IME_CONNECTION="InlineGhostIME_9B_Preview_Connection"
PROFILE="preview-9b"
VERSION="0.1.0-preview9b"
BUILD_NUMBER=""
SIGN_IDENTITY=""
INSTALL_AND_LAUNCH=0
SOURCE_EVIDENCE_CLASS="decision-grade"
OWNER_APPROVED_F03_RUN=0
PREVIOUS_LEDGER=""

usage() {
  /bin/cat <<'EOF'
Usage: script/build_preview_9b.sh [--install-and-launch] [options]

Builds dist/Tilde 9B Preview.app with an isolated app identity, input source,
socket, settings, history, model directory, diagnostics log, and server port.
Build-only mode verifies model/helper inputs but does not install or alter them.

Options:
  --install-and-launch      Publish only if /Applications has no existing preview.
  --owner-approved-f03-run  After a clean build, transactionally install it,
                            rotate the text-free F03 ledger, launch it, and
                            write an aggregate-only local run receipt.
  --previous-ledger MODE    Required with --owner-approved-f03-run; explicitly
                            choose archive or delete for the previous ledger.
  --diagnostic-dirty-source Allow a dirty tree, label both bundles diagnostic,
                            and make the package ineligible as F03 evidence.
  --model PATH              Use/verify the exact Qwen 3.5 9B Q4_K_M model.
  --helper PATH             Use this already signed llama-server helper.
  --helper-sha256 SHA256    Required SHA-256 of the approved helper input.
  --helper-team TEAMID      Required TeamIdentifier of the approved helper input.
  --sign-identity SHA1      Sign with this exact Apple Development identity.
  --version VERSION         Set CFBundleShortVersionString.
  --build-number NUMBER     Set CFBundleVersion; defaults to source commit count.
EOF
}

while (($#)); do
  case "$1" in
    --install-and-launch) INSTALL_AND_LAUNCH=1 ;;
    --owner-approved-f03-run) OWNER_APPROVED_F03_RUN=1 ;;
    --diagnostic-dirty-source) SOURCE_EVIDENCE_CLASS="diagnostic" ;;
    --model|--helper|--helper-sha256|--helper-team|--sign-identity|--version|--build-number|--previous-ledger)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --model) MODEL_SOURCE="$2" ;;
        --helper) HELPER_SOURCE="$2" ;;
        --helper-sha256) HELPER_SHA256="$2" ;;
        --helper-team) HELPER_TEAM="$2" ;;
        --sign-identity) SIGN_IDENTITY="$2" ;;
        --version) VERSION="$2" ;;
        --build-number) BUILD_NUMBER="$2" ;;
        --previous-ledger) PREVIOUS_LEDGER="$2" ;;
      esac
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ "$INSTALL_AND_LAUNCH" == "0" || "$OWNER_APPROVED_F03_RUN" == "0" ]] \
  || { echo "choose either --install-and-launch or --owner-approved-f03-run" >&2; exit 2; }
if [[ "$OWNER_APPROVED_F03_RUN" == "1" ]]; then
  [[ "$SOURCE_EVIDENCE_CLASS" == "decision-grade" ]] \
    || { echo "an F03 run cannot use a diagnostic dirty-source package" >&2; exit 2; }
  [[ "$PREVIOUS_LEDGER" == "archive" || "$PREVIOUS_LEDGER" == "delete" ]] \
    || { echo "--owner-approved-f03-run requires --previous-ledger archive|delete" >&2; exit 2; }
else
  [[ -z "$PREVIOUS_LEDGER" ]] \
    || { echo "--previous-ledger requires --owner-approved-f03-run" >&2; exit 2; }
fi
tilde_validate_preview_version "$VERSION"
[[ -z "$BUILD_NUMBER" || "$BUILD_NUMBER" =~ ^[0-9]+$ ]] \
  || { echo "build number must be numeric" >&2; exit 2; }
[[ "$HELPER_SHA256" =~ ^[0-9a-f]{64}$ ]] \
  || { echo "--helper-sha256 is required and must be lowercase SHA-256" >&2; exit 2; }
[[ "$HELPER_TEAM" =~ ^[A-Z0-9]{10}$ ]] \
  || { echo "--helper-team is required and must be a 10-character TeamIdentifier" >&2; exit 2; }

trap 'tilde_release_preview_build_lock || true; tilde_cleanup_build_source' EXIT
tilde_prepare_build_source "$ROOT_DIR" "$SOURCE_EVIDENCE_CLASS"
tilde_capture_f03_runner_identity \
  "$TILDE_BUILD_SOURCE_ROOT/script/f03_preview_run.sh"
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(tilde_git_raw "$ROOT_DIR" rev-list --count "$TILDE_SOURCE_COMMIT")"
fi
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "derived build number is invalid" >&2; exit 1; }
tilde_capture_apple_swift_toolchain
tilde_verify_model_file \
  "$MODEL_SOURCE" "$EXPECTED_MODEL_BYTES" "$EXPECTED_MODEL_SHA256" "9B"

SIGN_IDENTITY="$(tilde_resolve_signing_identity "$SIGN_IDENTITY")"
[[ "$SOURCE_EVIDENCE_CLASS" == "diagnostic" || "$SIGN_IDENTITY" != "-" ]] \
  || { echo "decision-grade previews require authenticated Apple Development signing" >&2; exit 1; }
APP="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP/Contents"
IME="$CONTENTS/Library/InlineGhostIME.app"

[[ ! -L "$ROOT_DIR/dist" ]] || { echo "refusing linked dist directory" >&2; exit 1; }
/bin/mkdir -p "$ROOT_DIR/dist"
[[ -d "$ROOT_DIR/dist" \
    && "$(/usr/bin/stat -f '%u' "$ROOT_DIR/dist")" == "$(/usr/bin/id -u)" ]] \
  || { echo "dist directory is not owner-controlled" >&2; exit 1; }
tilde_acquire_preview_build_lock "$ROOT_DIR/dist"
if [[ -e "$APP" || -L "$APP" ]]; then
  [[ -d "$APP" && ! -L "$APP" \
      && "$(/usr/bin/stat -f '%u' "$APP")" == "$(/usr/bin/id -u)" ]] \
    || { echo "refusing unsafe preview output target" >&2; exit 1; }
  /bin/rm -rf -- "$APP"
fi

SWIFT_BUILD_ARGS=(
  --package-path "$TILDE_BUILD_SOURCE_ROOT"
  --scratch-path "$TILDE_BUILD_SCRATCH_PATH"
)
tilde_assert_build_source_unchanged "$ROOT_DIR"
tilde_swift build "${SWIFT_BUILD_ARGS[@]}" -c release --product Tilde
tilde_assert_build_source_unchanged "$ROOT_DIR"
tilde_swift build "${SWIFT_BUILD_ARGS[@]}" -c release --product InlineGhostIME
BIN_PATH="$(tilde_swift build "${SWIFT_BUILD_ARGS[@]}" -c release --show-bin-path)"
tilde_assert_build_source_unchanged "$ROOT_DIR"

/bin/mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Helpers" \
  "$IME/Contents/MacOS"
/bin/cp "$BIN_PATH/Tilde" "$CONTENTS/MacOS/Tilde"
/bin/cp "$BIN_PATH/InlineGhostIME" "$IME/Contents/MacOS/InlineGhostIME"
tilde_stage_authenticated_helper \
  "$HELPER_SOURCE" "$CONTENTS/Helpers/llama-server" \
  "$HELPER_SHA256" "$HELPER_TEAM"
/bin/chmod +x "$CONTENTS/MacOS/Tilde" \
  "$IME/Contents/MacOS/InlineGhostIME" "$CONTENTS/Helpers/llama-server"
/bin/cp "$TILDE_BUILD_SOURCE_ROOT/Sources/InlineGhostIME/Info.plist" \
  "$IME/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $IME_ID" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :InputMethodConnectionName $IME_CONNECTION" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :TISInputSourceID $IME_ID" "$IME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :TildeProductProfile string $PROFILE" "$IME/Contents/Info.plist"

/bin/cat >"$CONTENTS/Info.plist" <<PLIST
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

tilde_embed_build_provenance "$CONTENTS/Info.plist"
tilde_embed_build_provenance "$IME/Contents/Info.plist"
/bin/bash "$TILDE_BUILD_SOURCE_ROOT/script/check_app_bundle.sh" \
  --release-helper "$CONTENTS/Helpers/llama-server"
tilde_assert_build_source_unchanged "$ROOT_DIR"
tilde_assert_apple_swift_toolchain_unchanged
/usr/bin/codesign --force --options runtime --sign "$SIGN_IDENTITY" "$IME" >/dev/null
tilde_assert_build_source_unchanged "$ROOT_DIR"
tilde_assert_apple_swift_toolchain_unchanged
/usr/bin/codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
tilde_assert_build_source_unchanged "$ROOT_DIR"
tilde_assert_apple_swift_toolchain_unchanged
[[ "$(/usr/bin/shasum -a 256 "$CONTENTS/Helpers/llama-server" \
      | /usr/bin/awk '{ print $1 }')" == "$HELPER_SHA256" ]] \
  || { echo "approved helper bytes changed during bundle signing" >&2; exit 1; }

[[ "$(/usr/bin/defaults read "$CONTENTS/Info" CFBundleIdentifier)" == "$APP_ID" ]]
[[ "$(/usr/bin/defaults read "$IME/Contents/Info" CFBundleIdentifier)" == "$IME_ID" ]]
tilde_verify_build_provenance "$CONTENTS/Info.plist"
tilde_verify_build_provenance "$IME/Contents/Info.plist"
for key in \
  TildeSourceCommit TildeSourceTree TildeSourceSnapshotSHA256 \
  TildeSourceState TildeEvidenceClass TildeAppleToolchainSHA256 \
  TildeAppleToolchainIdentitySchema \
  TildeXcodeVersion TildeXcodeBuild TildeXcodeCDHash TildeSwiftVersionSHA256 \
  TildeSwiftExecutableSHA256 TildeSwiftBuildExecutableSHA256 \
  TildeSwiftDriverExecutableSHA256 TildeClangExecutableSHA256 \
  TildeLinkerExecutableSHA256 TildeLibtoolExecutableSHA256 \
  TildeArchiverExecutableSHA256 TildeMacOSSDKVersion TildeMacOSSDKBuild \
  TildeMacOSSDKSettingsSHA256 TildeApprovedHelperInputSHA256 \
  TildeApprovedHelperTeamIdentifier TildeF03RunnerSHA256; do
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$CONTENTS/Info.plist")" \
      == "$(/usr/libexec/PlistBuddy -c "Print :$key" "$IME/Contents/Info.plist")" ]] \
    || { echo "app/IME build provenance mismatch: $key" >&2; exit 1; }
done
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  APP_TEAM="$(tilde_codesign_team_from_details \
    "$(/usr/bin/codesign --display --verbose=4 "$APP" 2>&1)")"
  IME_TEAM="$(tilde_codesign_team_from_details \
    "$(/usr/bin/codesign --display --verbose=4 "$IME" 2>&1)")"
  FINAL_HELPER_TEAM="$(tilde_codesign_team_from_details \
    "$(/usr/bin/codesign --display --verbose=4 "$CONTENTS/Helpers/llama-server" 2>&1)")"
  [[ "$APP_TEAM" == "$HELPER_TEAM" && "$IME_TEAM" == "$HELPER_TEAM" \
      && "$FINAL_HELPER_TEAM" == "$HELPER_TEAM" ]] \
    || { echo "signed app, IME, and helper must use the approved helper team" >&2; exit 1; }
fi
BUNDLE_MANIFEST="$(tilde_bundle_manifest_sha256 "$APP")"

MODEL_TARGET="$HOME/Library/Application Support/$APP_NAME/Models/qwen3.5-9b-base-q4km-preview/model.gguf"
if ((INSTALL_AND_LAUNCH || OWNER_APPROVED_F03_RUN)); then
  tilde_prepare_owner_only_model_target \
    "$MODEL_SOURCE" "$MODEL_TARGET" \
    "$EXPECTED_MODEL_BYTES" "$EXPECTED_MODEL_SHA256" "9B"
fi

if ((OWNER_APPROVED_F03_RUN)); then
  /bin/bash "$TILDE_BUILD_SOURCE_ROOT/script/f03_preview_run.sh" \
    --candidate "$APP" \
    --owner-approved \
    --previous-ledger "$PREVIOUS_LEDGER"
elif ((INSTALL_AND_LAUNCH)); then
  INSTALLED="/Applications/$APP_NAME.app"
  tilde_publish_new_bundle "$APP" "$INSTALLED" "$BUNDLE_MANIFEST" >/dev/null
  /usr/bin/open -n "$INSTALLED"
  echo "Installed and launched: $INSTALLED"
else
  echo "Built $SOURCE_EVIDENCE_CLASS preview without changing installed apps or models: $APP"
fi
