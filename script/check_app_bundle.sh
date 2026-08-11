#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_MODE=0
SELFTEST=0
RELEASE_INPUTS_MODE=0
RELEASE_INPUT_HELPER=""
RELEASE_INPUT_MODEL=""
APP_BUNDLE_SET=0
APP_BUNDLE="$ROOT_DIR/dist/Tilde.app"
MIN_MODEL_BYTES=1500000000
MAX_HELPER_MIN_MACOS=26.0
SELFTEST_TMP_DIR=""

fail() {
  echo "bundle check failed: $*" >&2
  exit 1
}

cleanup_selftest() {
  local temp_dir="${SELFTEST_TMP_DIR:-}"
  SELFTEST_TMP_DIR=""
  [[ -z "$temp_dir" ]] || /bin/rm -rf -- "$temp_dir"
}

team_identifier_from_details() {
  local details="$1"
  local line identifier="" count=0
  while IFS= read -r line; do
    if [[ "$line" == TeamIdentifier=* ]]; then
      identifier="${line#TeamIdentifier=}"
      count=$((count + 1))
    fi
  done <<<"$details"
  [[ "$count" == "1" && -n "$identifier" && "$identifier" != "not set" ]] || return 1
  printf '%s\n' "$identifier"
}

signing_team_identifier() {
  local details
  details="$(codesign --display --verbose=4 "$1" 2>&1)" || return 1
  team_identifier_from_details "$details"
}

is_macho_execute() {
  local headers
  headers="$(/usr/bin/otool -arch all -hv "$1" 2>/dev/null)" || return 1
  /usr/bin/awk '
    $1 == "magic" {
      filetype_column = 0
      for (column = 1; column <= NF; column++) {
        if ($column == "filetype") filetype_column = column
      }
      if (filetype_column == 0 || getline <= 0 || $filetype_column != "EXECUTE") {
        invalid = 1
      }
      headers += 1
    }
    END { exit !(headers > 0 && invalid == 0) }
  ' <<<"$headers"
}

helper_platform_error() {
  local architectures build_versions architecture
  architectures="$(/usr/bin/lipo -archs "$1" 2>/dev/null)" \
    || { printf 'llama-server architecture inspection failed'; return; }
  for architecture in $architectures; do
    [[ "$architecture" == "arm64" || "$architecture" == "arm64e" ]] && break
  done
  [[ "$architecture" == "arm64" || "$architecture" == "arm64e" ]] \
    || { printf 'llama-server must include an arm64 or arm64e slice'; return; }

  build_versions="$(/usr/bin/xcrun vtool -show-build "$1" 2>/dev/null)" \
    || { printf 'llama-server build-version inspection failed'; return; }
  /usr/bin/awk -v expected="$(/usr/bin/awk '{ print NF }' <<<"$architectures")" \
    -v maximum="$MAX_HELPER_MIN_MACOS" '
    function newer(version, limit, version_parts, limit_parts, part) {
      split(version, version_parts, "."); split(limit, limit_parts, ".")
      for (part = 1; part <= 3; part++) {
        if ((version_parts[part] + 0) != (limit_parts[part] + 0))
          return (version_parts[part] + 0) > (limit_parts[part] + 0)
      }
      return 0
    }
    $1 == "cmd" && ($2 == "LC_BUILD_VERSION" || $2 == "LC_VERSION_MIN_MACOSX") {
      commands++; active = 1; legacy = ($2 == "LC_VERSION_MIN_MACOSX"); macos = legacy; next
    }
    active && $1 == "platform" { macos = ($2 == "MACOS"); next }
    active && ((legacy && $1 == "version") || (!legacy && $1 == "minos")) {
      if (!macos || newer($2, maximum)) invalid = 1
      completed++; active = 0
    }
    END { exit !(commands == expected && completed == expected && !invalid) }
  ' <<<"$build_versions" \
    || printf 'every llama-server architecture must target macOS %s or earlier' \
      "$MAX_HELPER_MIN_MACOS"
}

has_system_only_dependencies() {
  local dependencies
  dependencies="$(/usr/bin/otool -arch all -L "$1" 2>/dev/null)" || return 1
  /usr/bin/awk '
    /^[[:space:]]/ {
      if ($1 !~ /^\/System\// && $1 !~ /^\/usr\/lib\//) invalid = 1
    }
    END { exit invalid == 0 ? 0 : 1 }
  ' <<<"$dependencies"
}

has_gguf_magic() {
  [[ "$(LC_ALL=C /usr/bin/head -c 4 "$1" 2>/dev/null)" == "GGUF" ]]
}

has_release_model_size() {
  local size
  size="$(/usr/bin/stat -f '%z' "$1" 2>/dev/null)" || return 1
  [[ "$size" =~ ^[0-9]+$ ]] && ((size >= MIN_MODEL_BYTES))
}

validate_release_inputs() {
  local helper="$1" model="$2" platform_error
  [[ -f "$helper" && -x "$helper" ]] || fail "missing executable llama-server: $helper"
  is_macho_execute "$helper" || fail "llama-server is not Mach-O filetype EXECUTE"
  platform_error="$(helper_platform_error "$helper")"
  [[ -z "$platform_error" ]] || fail "$platform_error"
  has_system_only_dependencies "$helper" \
    || fail "llama-server dependency inspection failed or found a non-system library"
  [[ -f "$model" ]] || fail "missing model: $model"
  has_gguf_magic "$model" || fail "model does not begin with GGUF magic"
  has_release_model_size "$model" \
    || fail "model is smaller than the 1500000000-byte release minimum"
}

run_selftest() {
  local selftest_dir invalid_helper valid_model readme_model small_gguf
  local fixture_source invalid_dylib invalid_executable valid_helper
  local future_helper ios_helper mixed_filetype_helper mixed_dependency_helper rejection_output
  [[ "$(team_identifier_from_details $'Executable=/tmp/Tilde\nTeamIdentifier=ABCDE12345')" \
    == "ABCDE12345" ]] || return 1
  if team_identifier_from_details "Executable=/tmp/Tilde" >/dev/null; then return 1; fi
  if team_identifier_from_details "TeamIdentifier=" >/dev/null; then return 1; fi
  if team_identifier_from_details "TeamIdentifier=not set" >/dev/null; then return 1; fi
  if team_identifier_from_details $'TeamIdentifier=ABCDE12345\nTeamIdentifier=ABCDE12345' >/dev/null; then
    return 1
  fi

  SELFTEST_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tilde-bundle-selftest.XXXXXX")"
  trap cleanup_selftest EXIT
  selftest_dir="$SELFTEST_TMP_DIR"
  invalid_helper="$selftest_dir/not-a-helper"
  valid_model="$selftest_dir/valid.gguf"
  readme_model="$selftest_dir/README"
  small_gguf="$selftest_dir/small.gguf"
  fixture_source="$selftest_dir/fixture.c"
  invalid_dylib="$selftest_dir/invalid.dylib"
  invalid_executable="$selftest_dir/invalid-dependency"
  valid_helper="$selftest_dir/valid-helper"
  future_helper="$selftest_dir/future-helper"
  ios_helper="$selftest_dir/ios-helper"
  mixed_filetype_helper="$selftest_dir/mixed-filetype-helper"
  mixed_dependency_helper="$selftest_dir/mixed-dependency-helper"

  printf '#!/bin/sh\nexit 0\n' >"$invalid_helper"
  chmod +x "$invalid_helper"
  printf 'GGUF' >"$valid_model"
  /bin/dd if=/dev/zero of="$valid_model" bs=1 seek="$((MIN_MODEL_BYTES - 1))" \
    count=1 conv=notrunc >/dev/null 2>&1
  printf 'README' >"$readme_model"
  /bin/dd if=/dev/zero of="$readme_model" bs=1 seek="$((MIN_MODEL_BYTES - 1))" \
    count=1 conv=notrunc >/dev/null 2>&1
  printf 'GGUF' >"$small_gguf"
  printf '#if CLIENT\nint dependency(void); int main(void) { return dependency(); }\n#elif LIBRARY\nint dependency(void) { return 0; }\n#else\nint main(void) { return 0; }\n#endif\n' \
    >"$fixture_source"

  /usr/bin/xcrun clang -arch arm64 -mmacosx-version-min="$MAX_HELPER_MIN_MACOS" \
    "$fixture_source" -o "$valid_helper" >/dev/null 2>&1
  /usr/bin/xcrun vtool -set-build-version macos 27.0 27.0 -replace \
    -output "$future_helper" "$valid_helper" >/dev/null 2>&1
  /usr/bin/xcrun vtool -set-build-version ios 26.0 26.0 -replace \
    -output "$ios_helper" "$valid_helper" >/dev/null 2>&1
  /usr/bin/xcrun clang -arch x86_64 -mmacosx-version-min="$MAX_HELPER_MIN_MACOS" \
    -DLIBRARY=1 -dynamiclib \
    -Wl,-install_name,@rpath/libtilde-selftest.dylib \
    "$fixture_source" -o "$invalid_dylib" >/dev/null 2>&1
  /usr/bin/xcrun clang -arch x86_64 -mmacosx-version-min="$MAX_HELPER_MIN_MACOS" \
    -DCLIENT=1 "$fixture_source" "$invalid_dylib" \
    -o "$invalid_executable" >/dev/null 2>&1
  /usr/bin/lipo -create "$valid_helper" "$invalid_dylib" -output "$mixed_filetype_helper"
  /usr/bin/lipo -create "$valid_helper" "$invalid_executable" -output "$mixed_dependency_helper"
  chmod +x "$future_helper" "$ios_helper" "$mixed_filetype_helper" "$mixed_dependency_helper"

  "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$valid_helper" "$valid_model" \
    >/dev/null 2>&1 || return 1
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$invalid_helper" "$valid_model" \
    >/dev/null 2>&1; then return 1; fi
  if rejection_output="$("$ROOT_DIR/script/check_app_bundle.sh" \
    --release-inputs "$invalid_executable" "$valid_model" 2>&1)"; then return 1; fi
  [[ "$rejection_output" == *"llama-server must include an arm64 or arm64e slice"* ]] \
    || return 1
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$future_helper" "$valid_model" \
    >/dev/null 2>&1; then return 1; fi
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$ios_helper" "$valid_model" \
    >/dev/null 2>&1; then return 1; fi
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$valid_helper" "$readme_model" \
    >/dev/null 2>&1; then return 1; fi
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$valid_helper" "$small_gguf" \
    >/dev/null 2>&1; then return 1; fi
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$mixed_filetype_helper" "$valid_model" \
    >/dev/null 2>&1; then return 1; fi
  if "$ROOT_DIR/script/check_app_bundle.sh" --release-inputs "$mixed_dependency_helper" "$valid_model" \
    >/dev/null 2>&1; then return 1; fi

  cleanup_selftest
  trap - EXIT
  echo "selftest OK: signing parser and every release-input architecture fail closed"
}

while (($#)); do
  case "$1" in
    --release)
      RELEASE_MODE=1
      shift
      ;;
    --selftest)
      SELFTEST=1
      shift
      ;;
    --release-inputs)
      [[ $# -ge 3 ]] || fail "--release-inputs requires HELPER and MODEL paths"
      RELEASE_INPUTS_MODE=1
      RELEASE_INPUT_HELPER="$2"
      RELEASE_INPUT_MODEL="$3"
      shift 3
      ;;
    -h|--help)
      cat <<'EOF'
Usage: script/check_app_bundle.sh [--release] [path/to/Tilde.app]
       script/check_app_bundle.sh --selftest
       script/check_app_bundle.sh --release-inputs HELPER MODEL

Checks the local app bundle shape, signature, and hardened runtime.
Use --release to require the packaged model, server, input method, and a
Developer ID Application signature.
Use --release-inputs to check only the helper and model file shapes.
EOF
      exit 0
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      [[ "$APP_BUNDLE_SET" == "0" ]] || fail "multiple app bundle paths provided"
      APP_BUNDLE="$1"
      APP_BUNDLE_SET=1
      shift
      ;;
  esac
done

if [[ "$SELFTEST" == "1" && ("$RELEASE_MODE" == "1" || "$RELEASE_INPUTS_MODE" == "1" || "$APP_BUNDLE_SET" == "1") ]]; then
  fail "--selftest cannot be combined with bundle or release-input checks"
fi
if [[ "$RELEASE_INPUTS_MODE" == "1" && ("$RELEASE_MODE" == "1" || "$APP_BUNDLE_SET" == "1") ]]; then
  fail "--release-inputs cannot be combined with a bundle check"
fi

if [[ "$SELFTEST" == "1" ]]; then
  run_selftest
  exit 0
fi
if [[ "$RELEASE_INPUTS_MODE" == "1" ]]; then
  validate_release_inputs "$RELEASE_INPUT_HELPER" "$RELEASE_INPUT_MODEL"
  echo "Release helper and model shapes verified."
  exit 0
fi

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/Tilde"
APP_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
LLAMA_SERVER="$APP_BUNDLE/Contents/Helpers/llama-server"
MODEL="$APP_BUNDLE/Contents/Resources/bundled-model.gguf"
IME="$APP_BUNDLE/Contents/Library/InlineGhostIME.app"
IME_INFO_PLIST="$IME/Contents/Info.plist"
ICON_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$ICON_TMP_DIR"' EXIT

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

[[ -d "$APP_BUNDLE" ]] || fail "missing app bundle: $APP_BUNDLE"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist"
[[ -x "$EXECUTABLE" ]] || fail "missing executable: $EXECUTABLE"
[[ -s "$APP_ICON" ]] || fail "missing app icon: $APP_ICON"

ICONSET_DIR="$ICON_TMP_DIR/AppIcon.iconset"
/usr/bin/iconutil -c iconset "$APP_ICON" -o "$ICONSET_DIR" >/dev/null 2>&1 \
  || fail "app icon is not a valid ICNS file"
for icon_file in \
  icon_32x32.png \
  icon_32x32@2x.png \
  icon_256x256.png \
  icon_256x256@2x.png \
  icon_512x512.png \
  icon_512x512@2x.png; do
  [[ -s "$ICONSET_DIR/$icon_file" ]] || fail "app icon missing $icon_file"
done

[[ "$(plist_value CFBundlePackageType)" == "APPL" ]] || fail "CFBundlePackageType is not APPL"
[[ "$(plist_value CFBundleExecutable)" == "Tilde" ]] || fail "CFBundleExecutable mismatch"
[[ "$(plist_value CFBundleIconFile)" == "AppIcon" ]] || fail "CFBundleIconFile mismatch"
[[ "$(plist_value CFBundleIdentifier)" == "bar.r3d.tilde" ]] || fail "CFBundleIdentifier mismatch"
[[ -n "$(plist_value CFBundleShortVersionString)" ]] || fail "missing CFBundleShortVersionString"
[[ -n "$(plist_value CFBundleVersion)" ]] || fail "missing CFBundleVersion"
[[ "$(plist_value LSUIElement)" == "true" ]] || fail "LSUIElement must be true for menu bar agent"
[[ "$(plist_value NSSupportsAutomaticTermination)" == "false" ]] \
  || fail "NSSupportsAutomaticTermination must be false for persistent menu bar agent"

[[ -z "$(plist_value NSAccessibilityUsageDescription)" ]] \
  || fail "unused Accessibility usage description is present"
[[ -z "$(plist_value NSAppleEventsUsageDescription)" ]] \
  || fail "unused Apple Events usage description is present"

codesign --verify --deep --strict "$APP_BUNDLE" >/dev/null 2>&1 || fail "codesign verification failed"

SIGNATURE_DETAILS="$(codesign --display --verbose=4 "$APP_BUNDLE" 2>&1 || true)"
grep -F "runtime" <<<"$SIGNATURE_DETAILS" >/dev/null || fail "hardened runtime flag is missing"

if [[ "$RELEASE_MODE" == "1" ]]; then
  validate_release_inputs "$LLAMA_SERVER" "$MODEL"
  [[ -x "$IME/Contents/MacOS/InlineGhostIME" ]] || fail "missing packaged InlineGhostIME"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$IME_INFO_PLIST")" \
    == "$(plist_value CFBundleShortVersionString)" ]] || fail "input method release version mismatch"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$IME_INFO_PLIST")" \
    == "$(plist_value CFBundleVersion)" ]] || fail "input method build number mismatch"

  codesign --verify --strict "$LLAMA_SERVER" >/dev/null 2>&1 \
    || fail "llama-server signature verification failed"
  codesign --verify --deep --strict "$IME" >/dev/null 2>&1 \
    || fail "InlineGhostIME signature verification failed"
  grep -F "Authority=Developer ID Application" <<<"$SIGNATURE_DETAILS" >/dev/null \
    || fail "release bundle is not signed with Developer ID Application"

  APP_TEAM="$(team_identifier_from_details "$SIGNATURE_DETAILS")" \
    || fail "release app has no unambiguous TeamIdentifier"
  IME_TEAM="$(signing_team_identifier "$IME")" \
    || fail "InlineGhostIME has no unambiguous TeamIdentifier"
  HELPER_TEAM="$(signing_team_identifier "$LLAMA_SERVER")" \
    || fail "llama-server has no unambiguous TeamIdentifier"
  [[ "$IME_TEAM" == "$APP_TEAM" ]] || fail "InlineGhostIME TeamIdentifier differs from app"
  [[ "$HELPER_TEAM" == "$APP_TEAM" ]] || fail "llama-server TeamIdentifier differs from app"
fi

echo "App bundle verified: $APP_BUNDLE"
