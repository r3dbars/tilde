#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/AutocompleteLab.app"
ZIP_PATH="$DIST_DIR/AutocompleteLab.zip"
BUNDLE_ID="bar.r3d.autocomplete-lab"
MODE="archive"
REQUIRE_NOTARY_PROFILE=0

cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: script/package_release.sh [archive|--check|--notarize] [--require-notary-profile]

archive    Build a release app, sign with Developer ID, validate, and create dist/AutocompleteLab.zip.
--check    Report whether local signing/notary prerequisites are present.
--notarize Submit the zip to Apple notarytool. This uploads the app to Apple.
--require-notary-profile
           Make --check fail when NOTARYTOOL_PROFILE is missing.

For --notarize, set NOTARYTOOL_PROFILE to a keychain profile created with:
  xcrun notarytool store-credentials <profile-name>
EOF
}

while (($#)); do
  case "$1" in
    archive|--check|check|--notarize|notarize)
      MODE="$1"
      ;;
    --require-notary-profile)
      REQUIRE_NOTARY_PROFILE=1
      ;;
    -h|--help|help)
      MODE="help"
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

developer_id_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "$SIGN_IDENTITY"
    return 0
  fi

  security find-identity -p codesigning -v 2>/dev/null \
    | awk '/Developer ID Application/ { print $2; exit }'
}

developer_id="$(developer_id_identity)"

case "$MODE" in
  help)
    usage
    exit 0
    ;;
  --check|check)
    if [[ -n "$developer_id" ]]; then
      developer_id_name="$(security find-identity -p codesigning -v 2>/dev/null \
        | awk -v hash="$developer_id" '$2 == hash { sub(/^[^"]*"/, ""); sub(/"$/, ""); print; exit }')"
      echo "Developer ID identity: $developer_id ${developer_id_name:+($developer_id_name)}"
    else
      echo "Developer ID identity: missing"
    fi

    if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
      echo "Notary profile: $NOTARYTOOL_PROFILE"
    else
      echo "Notary profile: missing (set NOTARYTOOL_PROFILE to submit)"
      if [[ "$REQUIRE_NOTARY_PROFILE" == "1" ]]; then
        exit 1
      fi
    fi

    if ./script/check_model_asset.py --quiet; then
      echo "Preferred MLX model: ready"
    else
      echo "Preferred MLX model: missing or invalid (run ./script/check_model_asset.py)"
    fi
    exit 0
    ;;
  archive)
    if [[ -z "$developer_id" ]]; then
      echo "release packaging requires a Developer ID Application signing identity" >&2
      echo "Run script/package_release.sh --check to inspect local prerequisites." >&2
      exit 1
    fi

    ./script/check_model_asset.py

    AUTOCOMPLETE_LAB_BUILD_CONFIGURATION=release \
      SIGN_IDENTITY="$developer_id" \
      ./script/build_and_run.sh --bundle-only

    ./script/check_app_bundle.sh --release "$APP_BUNDLE"

    if ! spctl --assess --type execute --verbose=4 "$APP_BUNDLE"; then
      echo "warning: Gatekeeper assessment is expected to fail before notarization" >&2
    fi

    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
    echo "Release archive created: $ZIP_PATH"
    ;;
  --notarize|notarize)
    if [[ ! -f "$ZIP_PATH" ]]; then
      echo "missing archive: $ZIP_PATH" >&2
      echo "Run script/package_release.sh archive first." >&2
      exit 1
    fi

    if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
      echo "missing NOTARYTOOL_PROFILE" >&2
      exit 1
    fi

    echo "Submitting $ZIP_PATH to Apple notarization for $BUNDLE_ID..."
    xcrun notarytool submit "$ZIP_PATH" \
      --keychain-profile "$NOTARYTOOL_PROFILE" \
      --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    verify_dir="$(mktemp -d)"
    trap 'rm -rf "$verify_dir"' EXIT
    ditto -x -k "$ZIP_PATH" "$verify_dir"
    xcrun stapler validate "$verify_dir/AutocompleteLab.app"
    spctl --assess --type execute --verbose=4 "$verify_dir/AutocompleteLab.app"
    echo "Notarized release archive verified: $ZIP_PATH"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
