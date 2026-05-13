#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/SteadyType.app"
ZIP_PATH="$DIST_DIR/SteadyType.zip"
DMG_PATH="$DIST_DIR/SteadyType.dmg"
PROOF_DIR="$DIST_DIR/release-proof"
CHECKSUM_PATH="$PROOF_DIR/checksums.txt"
NOTARY_BLOCKER_PATH="$PROOF_DIR/notarization-blocker.txt"
FRESH_INSTALL_PROOF_PATH="$PROOF_DIR/fresh-install-gatekeeper-proof.md"
BUNDLE_ID="bar.r3d.steadytype"
MODE="archive"
REQUIRE_NOTARY_PROFILE=0
REQUIRE_DEVELOPER_ID=0

cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: script/package_release.sh [archive|--check|--notarize] [--require-developer-id] [--require-notary-profile]

archive    Build a release app, sign with Developer ID, validate, and create
           primary dist/SteadyType.dmg plus secondary dist/SteadyType.zip.
--check    Report whether local signing/notary prerequisites are present.
--notarize Submit the DMG to Apple notarytool. This uploads the app to Apple.
--require-notary-profile
           Make --check fail when no usable notarytool profile is available.
--require-developer-id
           Make --check fail when a Developer ID Application identity is missing.
--print-proof-template
           Print the saved release-proof checklist template.

For --notarize, set NOTARYTOOL_PROFILE to a keychain profile created with:
  xcrun notarytool store-credentials <profile-name>
If NOTARYTOOL_PROFILE is unset, the script tries stored profile aliases from
AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES, then SteadyType, AutocompleteLab,
and Transcripted.
EOF
}

while (($#)); do
  case "$1" in
    archive|--check|check|--notarize|notarize|--print-proof-template)
      MODE="$1"
      ;;
    --require-notary-profile)
      REQUIRE_NOTARY_PROFILE=1
      ;;
    --require-developer-id)
      REQUIRE_DEVELOPER_ID=1
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
    security find-identity -p codesigning -v 2>/dev/null \
      | awk -v wanted="$SIGN_IDENTITY" '
          /Developer ID Application/ {
            hash = $2
            name = $0
            sub(/^[^"]*"/, "", name)
            sub(/".*$/, "", name)
            if (hash == wanted || name == wanted || index($0, wanted) > 0) {
              print hash
              exit
            }
          }
        '
    return
  fi

  security find-identity -p codesigning -v 2>/dev/null \
    | awk '/Developer ID Application/ { print $2; exit }'
}

developer_id="$(developer_id_identity)"

validate_notary_profile() {
  local profile="$1"
  local quiet="${2:-0}"
  local output_path="/tmp/autocomplete-notary-profile-check.txt"

  if xcrun notarytool history \
    --keychain-profile "$profile" \
    --output-format json >"$output_path" 2>&1; then
    return 0
  fi

  if [[ "$quiet" != "1" ]]; then
    cat "$output_path" >&2 2>/dev/null || true
  fi
  return 1
}

notary_profile_candidates() {
  if [[ -n "${AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES+x}" ]]; then
    printf '%s\n' "$AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES" | tr ',' '\n'
    return
  fi

  printf '%s\n' \
    "SteadyType" \
    "AutocompleteLab" \
    "Transcripted"
}

resolve_notary_profile() {
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    printf '%s' "$NOTARYTOOL_PROFILE"
    return 0
  fi

  local candidate
  while IFS= read -r candidate; do
    candidate="${candidate#"${candidate%%[![:space:]]*}"}"
    candidate="${candidate%"${candidate##*[![:space:]]}"}"
    [[ -n "$candidate" ]] || continue
    if validate_notary_profile "$candidate" 1; then
      printf '%s' "$candidate"
      return 0
    fi
  done < <(notary_profile_candidates)

  return 1
}

artifact_sha() {
  local artifact_path="$1"
  if [[ -f "$artifact_path" ]]; then
    shasum -a 256 "$artifact_path" | awk '{print $1}'
  else
    echo "missing"
  fi
}

write_checksums() {
  mkdir -p "$PROOF_DIR"
  : >"$CHECKSUM_PATH"
  for artifact_path in "$DMG_PATH" "$ZIP_PATH"; do
    if [[ -f "$artifact_path" ]]; then
      printf '%s  %s\n' "$(basename "$artifact_path")" "$(artifact_sha "$artifact_path")" >>"$CHECKSUM_PATH"
    fi
  done
}

print_proof_template() {
  local stage="${1:-template}"
  local notarization_status="${2:-pending}"
  local stapler_status="${3:-pending}"
  local gatekeeper_status="${4:-pending}"
  local created_at
  created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  cat <<EOF
# SteadyType Release Proof

- Created UTC: $created_at
- Stage: $stage
- App bundle: dist/SteadyType.app
- Preferred artifact: dist/SteadyType.dmg
- Secondary artifact: dist/SteadyType.zip
- Bundle ID: $BUNDLE_ID
- Developer ID app signature: required before private-beta packet
- Notarization status: $notarization_status
- Stapler status: $stapler_status
- Gatekeeper status: $gatekeeper_status
- Checksum file: dist/release-proof/checksums.txt

## Local Proof Files

- codesign verify: dist/release-proof/codesign-verify.txt
- signature and entitlements: dist/release-proof/signature-and-entitlements.txt
- pre-notary app assessment: dist/release-proof/spctl-app-pre-notary.txt
- DMG assessment: dist/release-proof/spctl-dmg.txt
- installed app assessment: dist/release-proof/spctl-installed-app.txt
- notary submission: dist/release-proof/notarytool-submit.txt
- stapler validation: dist/release-proof/stapler-validate.txt
- fresh install / Gatekeeper / quarantine proof: dist/release-proof/fresh-install-gatekeeper-proof.md
- notarization blocker, when present: dist/release-proof/notarization-blocker.txt

## Manual Proof Still Required

- Fresh quarantined download on a machine or VM that has not seen this build.
- Drag the app from the DMG to /Applications.
- Grant Accessibility and verify safe suggestions in TextEdit.
- Deny Accessibility and verify safe degradation.
- Export redacted diagnostics.
- Run uninstall/delete-data instructions.
- Launch with network disconnected after stapling to prove offline trust.
EOF
}

write_fresh_install_proof_instructions() {
  mkdir -p "$PROOF_DIR"
  cat >"$FRESH_INSTALL_PROOF_PATH" <<EOF
# Fresh Install / Gatekeeper / Quarantine Proof

Use this after \`dist/SteadyType.dmg\` is notarized and stapled.

## Automated Local Quarantine Check

\`\`\`bash
verify_dir="\$(mktemp -d)"
mkdir -p "\$verify_dir/mount"
xattr -w com.apple.quarantine "0081;\$(printf '%x' "\$(date +%s)");SteadyType;$(uuidgen)" dist/SteadyType.dmg
hdiutil attach dist/SteadyType.dmg -mountpoint "\$verify_dir/mount" -nobrowse -quiet
cp -R "\$verify_dir/mount/SteadyType.app" "\$verify_dir/SteadyType.app"
hdiutil detach "\$verify_dir/mount" -quiet
spctl --assess --type execute --verbose=4 "\$verify_dir/SteadyType.app" 2>&1 | tee dist/release-proof/spctl-installed-app.txt
rm -rf "\$verify_dir"
\`\`\`

## Fresh Machine / VM Check

1. Download or copy \`dist/SteadyType.dmg\` onto a machine or VM that has not seen this exact build.
2. Confirm the DMG has quarantine metadata:

\`\`\`bash
xattr -p com.apple.quarantine SteadyType.dmg
\`\`\`

3. Open the DMG, drag \`SteadyType.app\` to \`/Applications\`, and launch it.
4. Confirm Gatekeeper does not warn that the app cannot be checked for malware.
5. Grant Accessibility, verify one safe TextEdit suggestion, then deny Accessibility and verify safe degradation.
6. Run:

\`\`\`bash
spctl --assess --type execute --verbose=4 /Applications/SteadyType.app 2>&1 | tee dist/release-proof/spctl-installed-app.txt
xcrun stapler validate dist/SteadyType.dmg 2>&1 | tee dist/release-proof/stapler-validate.txt
\`\`\`
EOF
}

write_notary_blocker() {
  mkdir -p "$PROOF_DIR"
  cat >"$NOTARY_BLOCKER_PATH" <<EOF
Notarization blocked: no usable notarytool keychain profile was resolved.

The release artifacts exist locally, but private beta readiness must remain
blocked until the DMG is submitted to Apple, stapled, and fresh-install
Gatekeeper proof is saved.

Set a stored notary profile or add its alias to
AUTOCOMPLETE_LAB_NOTARY_PROFILE_CANDIDATES, then rerun:

  export NOTARYTOOL_PROFILE=<profile-name>
  ./script/package_release.sh --notarize
  ./script/beta_readiness.sh --check-only
EOF
}

clear_notary_blocker() {
  rm -f "$NOTARY_BLOCKER_PATH"
}

write_proof_checklist() {
  mkdir -p "$PROOF_DIR"
  print_proof_template "$@" >"$PROOF_DIR/release-proof-checklist.md"
}

record_command() {
  local output_path="$1"
  shift
  mkdir -p "$(dirname "$output_path")"
  if "$@" >"$output_path" 2>&1; then
    cat "$output_path"
    return 0
  fi

  cat "$output_path" >&2
  return 1
}

record_command_allow_failure() {
  local output_path="$1"
  shift
  mkdir -p "$(dirname "$output_path")"
  "$@" >"$output_path" 2>&1 || true
  cat "$output_path"
}

create_zip() {
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
}

create_dmg() {
  local dmg_src
  dmg_src="$(mktemp -d)"

  cp -R "$APP_BUNDLE" "$dmg_src/SteadyType.app"
  ln -s /Applications "$dmg_src/Applications"
  rm -f "$DMG_PATH"
  hdiutil create \
    -volname "SteadyType" \
    -srcfolder "$dmg_src" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

  if [[ -n "$developer_id" ]]; then
    codesign --sign "$developer_id" --timestamp "$DMG_PATH"
  fi

  rm -rf "$dmg_src"
}

case "$MODE" in
  help)
    usage
    exit 0
    ;;
  --print-proof-template)
    print_proof_template
    exit 0
    ;;
  --check|check)
    check_failed=0
    resolved_notary_profile=""
    notary_profile_source=""
    if [[ -n "$developer_id" ]]; then
      developer_id_name="$(security find-identity -p codesigning -v 2>/dev/null \
        | awk -v hash="$developer_id" '$2 == hash { sub(/^[^"]*"/, ""); sub(/"$/, ""); print; exit }')"
      echo "Developer ID signing identity: OK - $developer_id ${developer_id_name:+($developer_id_name)}"
    else
      echo "Developer ID signing identity: blocked - missing Developer ID Application identity"
      if [[ "$REQUIRE_DEVELOPER_ID" == "1" ]]; then
        check_failed=1
      fi
    fi

    if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
      resolved_notary_profile="$NOTARYTOOL_PROFILE"
      notary_profile_source="NOTARYTOOL_PROFILE"
    elif resolved_notary_profile="$(resolve_notary_profile)"; then
      notary_profile_source="stored keychain profile"
    fi

    if [[ -n "$resolved_notary_profile" ]]; then
      if [[ "$REQUIRE_NOTARY_PROFILE" == "1" ]]; then
        if validate_notary_profile "$resolved_notary_profile"; then
          echo "Apple notary credentials: OK - $notary_profile_source=$resolved_notary_profile"
        else
          echo "Apple notary credentials: blocked - $notary_profile_source is not usable"
          check_failed=1
        fi
      else
        echo "Apple notary credentials: present - $notary_profile_source=$resolved_notary_profile (not verified without --require-notary-profile)"
      fi
    else
      echo "Apple notary credentials: blocked - no usable NOTARYTOOL_PROFILE or stored profile alias was found"
      if [[ "$REQUIRE_NOTARY_PROFILE" == "1" ]]; then
        check_failed=1
      fi
    fi

    if ./script/check_model_asset.py --quiet; then
      echo "Preferred MLX model: ready"
    else
      echo "Preferred MLX model: blocked - required app-owned model is missing, invalid, corrupt, or not checksum-verified"
      echo "Run ./script/check_model_asset.py for the exact fix."
      check_failed=1
    fi
    exit "$check_failed"
    ;;
  archive)
    if [[ -z "$developer_id" ]]; then
      echo "release packaging requires a Developer ID Application signing identity" >&2
      echo "Run script/package_release.sh --check to inspect local prerequisites." >&2
      exit 1
    fi

    ./script/check_model_asset.py

    release_scratch_path="${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build-release}"
    release_build_jobs="${AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS:-4}"
    AUTOCOMPLETE_LAB_BUILD_CONFIGURATION=release \
      AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH="$release_scratch_path" \
      AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS="$release_build_jobs" \
      SIGN_IDENTITY="$developer_id" \
      ./script/build_and_run.sh --bundle-only

    ./script/check_app_bundle.sh --release "$APP_BUNDLE"

    mkdir -p "$PROOF_DIR"
    record_command "$PROOF_DIR/codesign-verify.txt" \
      codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    record_command_allow_failure "$PROOF_DIR/signature-and-entitlements.txt" \
      codesign -d --entitlements :- --verbose=4 "$APP_BUNDLE"
    record_command_allow_failure "$PROOF_DIR/spctl-app-pre-notary.txt" \
      spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

    create_zip
    create_dmg
    write_checksums
    write_proof_checklist "archive" "pending" "pending" "pending"
    write_fresh_install_proof_instructions
    if ! resolve_notary_profile >/dev/null; then
      write_notary_blocker
      echo "Notarization blocked: set NOTARYTOOL_PROFILE or a stored profile alias and run ./script/package_release.sh --notarize"
    else
      clear_notary_blocker
    fi
    echo "Primary beta artifact created: $DMG_PATH"
    echo "Secondary archive created: $ZIP_PATH"
    echo "Release proof checklist: $PROOF_DIR/release-proof-checklist.md"
    ;;
  --notarize|notarize)
    resolved_notary_profile=""
    gatekeeper_failed=0
    if [[ ! -f "$DMG_PATH" ]]; then
      echo "missing preferred artifact: $DMG_PATH" >&2
      echo "Run script/package_release.sh archive first." >&2
      exit 1
    fi

    if ! resolved_notary_profile="$(resolve_notary_profile)"; then
      echo "missing usable NOTARYTOOL_PROFILE or stored notarytool keychain profile" >&2
      exit 1
    fi

    mkdir -p "$PROOF_DIR"
    echo "Submitting $DMG_PATH to Apple notarization for $BUNDLE_ID with keychain profile $resolved_notary_profile..."
    record_command "$PROOF_DIR/notarytool-submit.txt" \
      xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$resolved_notary_profile" \
      --wait
    record_command "$PROOF_DIR/stapler-staple.txt" \
      xcrun stapler staple "$DMG_PATH"
    write_checksums
    record_command "$PROOF_DIR/stapler-validate.txt" \
      xcrun stapler validate "$DMG_PATH"
    if ! record_command "$PROOF_DIR/spctl-dmg.txt" \
      spctl -a -t open --context context:primary-signature -v "$DMG_PATH"; then
      gatekeeper_failed=1
    fi

    create_zip
    write_checksums

    verify_dir="$(mktemp -d)"
    trap 'rm -rf "$verify_dir"' EXIT
    mkdir -p "$verify_dir/mount"
    hdiutil attach "$DMG_PATH" -mountpoint "$verify_dir/mount" -nobrowse -quiet
    cp -R "$verify_dir/mount/SteadyType.app" "$verify_dir/SteadyType.app"
    hdiutil detach "$verify_dir/mount" -quiet
    if ! record_command "$PROOF_DIR/spctl-installed-app.txt" \
      spctl --assess --type execute --verbose=4 "$verify_dir/SteadyType.app"; then
      gatekeeper_failed=1
    fi
    if ((gatekeeper_failed > 0)); then
      write_proof_checklist "notarized" "accepted" "validated" "blocked"
      echo "Gatekeeper assessment failed; saved spctl output in $PROOF_DIR" >&2
      exit 1
    fi
    write_checksums
    write_proof_checklist "notarized" "accepted" "validated" "accepted"
    write_fresh_install_proof_instructions
    clear_notary_blocker
    echo "Notarized preferred artifact verified: $DMG_PATH"
    echo "Secondary ZIP refreshed: $ZIP_PATH"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
