#!/usr/bin/env bash
# Build and sign the InlineGhostIME development bundle. Release signing and
# notarization belong only to script/package_app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
SIGN_IDENTITY=""

usage() {
    cat <<'EOF'
Usage: script/build_ime.sh [options]

Build and sign dist/InlineGhostIME.app without installing or notarizing it.

Options:
  --version VERSION         Set CFBundleShortVersionString.
  --build-number NUMBER     Set CFBundleVersion.
  --sign-identity IDENTITY  Sign with this identity; use - for ad hoc signing.
  -h, --help                Show this help.

Without --sign-identity, local builds use an ad hoc signature.
EOF
}

while (($#)); do
    case "$1" in
        --version|--build-number|--sign-identity)
            [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
            case "$1" in
                --version) VERSION="$2" ;;
                --build-number) BUILD_NUMBER="$2" ;;
                --sign-identity) SIGN_IDENTITY="$2" ;;
            esac
            shift
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
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "build number must be numeric" >&2; exit 2; }

if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    RESOLVED_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
        | awk -v wanted="$SIGN_IDENTITY" '$2 == wanted || index($0, "\"" wanted "\"") { print $2; exit }')"
    [[ -n "$RESOLVED_IDENTITY" ]] \
        || { echo "signing identity is unavailable: $SIGN_IDENTITY" >&2; exit 1; }
    SIGN_IDENTITY="$RESOLVED_IDENTITY"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
    echo "warning: no signing identity found; using an ad hoc signature" >&2
fi

APP="dist/InlineGhostIME.app"
swift build -c release --product InlineGhostIME

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/InlineGhostIME "$APP/Contents/MacOS/InlineGhostIME"
cp Sources/InlineGhostIME/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
