#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CHECKER="./script/check_lightweight_budget.py"
TMP_DIR="$(mktemp -d)"
APP_BUNDLE="$TMP_DIR/SteadyType.app"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "lightweight budget self-test failed: $*" >&2
  exit 1
}

mkdir -p \
  "$APP_BUNDLE/Contents/MacOS" \
  "$APP_BUNDLE/Contents/Resources/mlx-swift_Cmlx.bundle" \
  "$APP_BUNDLE/Contents/_CodeSignature"

printf 'plist' >"$APP_BUNDLE/Contents/Info.plist"
printf 'app' >"$APP_BUNDLE/Contents/MacOS/SteadyType"
printf 'helper' >"$APP_BUNDLE/Contents/MacOS/SteadyTypeTextEventHelper"
printf 'icon' >"$APP_BUNDLE/Contents/Resources/AppIcon.icns"
printf 'metal' >"$APP_BUNDLE/Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib"
printf 'signature' >"$APP_BUNDLE/Contents/_CodeSignature/CodeResources"
chmod +x \
  "$APP_BUNDLE/Contents/MacOS/SteadyType" \
  "$APP_BUNDLE/Contents/MacOS/SteadyTypeTextEventHelper"

"$CHECKER" --source-only >/dev/null
"$CHECKER" --app-bundle "$APP_BUNDLE" --max-app-bytes 1024 >/dev/null

printf 'model' >"$APP_BUNDLE/Contents/Resources/model.safetensors"
if "$CHECKER" --app-bundle "$APP_BUNDLE" --max-app-bytes 1024 >"$TMP_DIR/unexpected.out" 2>&1; then
  fail "unexpected payload passed"
fi
grep -F "unexpected payload" "$TMP_DIR/unexpected.out" >/dev/null \
  || fail "unexpected payload failure was unclear"
rm "$APP_BUNDLE/Contents/Resources/model.safetensors"

dd if=/dev/zero of="$APP_BUNDLE/Contents/MacOS/SteadyType" bs=2048 count=1 2>/dev/null
if "$CHECKER" --app-bundle "$APP_BUNDLE" --max-app-bytes 1024 >"$TMP_DIR/oversize.out" 2>&1; then
  fail "oversize bundle passed"
fi
grep -F "over the 1,024 bytes budget" "$TMP_DIR/oversize.out" >/dev/null \
  || fail "oversize failure was unclear"

if "$CHECKER" --source-only --max-model-bytes 1 >"$TMP_DIR/model.out" 2>&1; then
  fail "oversize pinned model passed"
fi
grep -F "pinned qwen35-4b model payload" "$TMP_DIR/model.out" >/dev/null \
  || fail "model budget failure was unclear"

grep -F 'check_lightweight_budget.py --source-only' script/proof.sh >/dev/null \
  || fail "fast proof gate does not run the source budget"
grep -F 'check_lightweight_budget.py" --app-bundle "$APP_BUNDLE"' script/check_app_bundle.sh >/dev/null \
  || fail "release bundle check does not run the artifact budget"

echo "Lightweight budget self-test passed."
