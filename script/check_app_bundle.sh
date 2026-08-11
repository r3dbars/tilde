#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_MODE=0
SELFTEST=0
APP_BUNDLE="$ROOT_DIR/dist/Tilde.app"

fail() {
  echo "bundle check failed: $*" >&2
  exit 1
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

run_selftest() {
  [[ "$(team_identifier_from_details $'Executable=/tmp/Tilde\nTeamIdentifier=ABCDE12345')" \
    == "ABCDE12345" ]] || return 1
  if team_identifier_from_details "Executable=/tmp/Tilde" >/dev/null; then return 1; fi
  if team_identifier_from_details "TeamIdentifier=" >/dev/null; then return 1; fi
  if team_identifier_from_details "TeamIdentifier=not set" >/dev/null; then return 1; fi
  if team_identifier_from_details $'TeamIdentifier=ABCDE12345\nTeamIdentifier=ABCDE12345' >/dev/null; then
    return 1
  fi
  echo "selftest OK: signing TeamIdentifier parser fails closed"
}

for arg in "$@"; do
  case "$arg" in
    --release)
      RELEASE_MODE=1
      ;;
    --selftest)
      SELFTEST=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: script/check_app_bundle.sh [--release] [path/to/Tilde.app]
       script/check_app_bundle.sh --selftest

Checks the local app bundle shape, signature, and hardened runtime.
Use --release to require the packaged model, server, input method, and a
Developer ID Application signature.
EOF
      exit 0
      ;;
    -*)
      fail "unknown option: $arg"
      ;;
    *)
      APP_BUNDLE="$arg"
      ;;
  esac
done

if [[ "$SELFTEST" == "1" ]]; then
  run_selftest
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
  [[ -x "$LLAMA_SERVER" ]] || fail "missing packaged llama-server"
  [[ -s "$MODEL" ]] || fail "missing packaged model"
  [[ -x "$IME/Contents/MacOS/InlineGhostIME" ]] || fail "missing packaged InlineGhostIME"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$IME_INFO_PLIST")" \
    == "$(plist_value CFBundleShortVersionString)" ]] || fail "input method release version mismatch"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$IME_INFO_PLIST")" \
    == "$(plist_value CFBundleVersion)" ]] || fail "input method build number mismatch"

  if otool -L "$LLAMA_SERVER" | tail -n +2 \
    | awk '{ print $1 }' \
    | grep -Ev '^(/System/|/usr/lib/)' >/dev/null; then
    fail "packaged llama-server links a non-system library"
  fi

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
