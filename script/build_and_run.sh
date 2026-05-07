#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AutocompleteLab"
BUNDLE_ID="bar.r3d.autocomplete-lab"
MIN_SYSTEM_VERSION="26.0"
BUILD_CONFIGURATION="${AUTOCOMPLETE_LAB_BUILD_CONFIGURATION:-debug}"
APP_VERSION="${AUTOCOMPLETE_LAB_VERSION:-0.1.0}"
APP_BUILD="${AUTOCOMPLETE_LAB_BUILD:-$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$APP_RESOURCES/AppIcon.icns"
MLX_METALLIB="$ROOT_DIR/.build/mlx-metal/default.metallib"

cd "$ROOT_DIR"

stop_running_apps() {
  local app_process_pattern
  local pid

  app_process_pattern="/[${APP_NAME:0:1}]${APP_NAME:1}.app/Contents/MacOS/$APP_NAME"
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(pgrep -f "$app_process_pattern" 2>/dev/null || true)
}

current_bundle_is_running() {
  pgrep -f "^$APP_BINARY$" >/dev/null 2>&1
}

stop_running_apps

find_signing_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "$SIGN_IDENTITY"
    return 0
  fi

  local identity
  identity="$(security find-identity -p codesigning -v 2>/dev/null \
    | awk -F '"' '/Apple Development/ { print $2; exit }')"

  if [[ -z "$identity" ]]; then
    identity="$(security find-identity -p codesigning -v 2>/dev/null \
      | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
  fi

  echo "$identity"
}

swift package resolve
./script/patch_mlx_swift_lm.sh
swift build -c "$BUILD_CONFIGURATION" --product "$APP_NAME"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

build_mlx_metallib_if_needed() {
  if [[ -f "$MLX_METALLIB" ]]; then
    return 0
  fi

  local mlx_checkout="$ROOT_DIR/.build/checkouts/mlx-swift"
  local mlx_root="$mlx_checkout/Source/Cmlx/mlx"
  local kernel_dir="$mlx_root/mlx/backend/metal/kernels"
  local build_dir
  build_dir="$(dirname "$MLX_METALLIB")"

  if [[ ! -d "$kernel_dir" ]]; then
    echo "warning: MLX checkout not found; real MLX runtime may fail to load Metal kernels" >&2
    return 0
  fi

  mkdir -p "$build_dir"

  local kernels=(
    arg_reduce
    conv
    gemv
    layer_norm
    random
    rms_norm
    rope
    scaled_dot_product_attention
    fence
    arange
    binary
    binary_two
    copy
    fft
    reduce
    quantized
    fp_quantized
    scan
    softmax
    logsumexp
    sort
    ternary
    unary
    steel/conv/kernels/steel_conv
    steel/conv/kernels/steel_conv_3d
    steel/conv/kernels/steel_conv_general
    steel/gemm/kernels/steel_gemm_fused
    steel/gemm/kernels/steel_gemm_gather
    steel/gemm/kernels/steel_gemm_masked
    steel/gemm/kernels/steel_gemm_splitk
    steel/gemm/kernels/steel_gemm_segmented
    gemv_masked
    steel/attn/kernels/steel_attention
  )

  local air_files=()
  local kernel
  for kernel in "${kernels[@]}"; do
    local air_file="$build_dir/$(basename "$kernel").air"
    xcrun -sdk macosx metal \
      -x metal \
      -Wall \
      -Wextra \
      -fno-fast-math \
      -Wno-c++17-extensions \
      -Wno-c++20-extensions \
      -c "$kernel_dir/$kernel.metal" \
      -I"$mlx_root" \
      -o "$air_file"
    air_files+=("$air_file")
  done

  xcrun -sdk macosx metallib "${air_files[@]}" -o "$MLX_METALLIB"
}

build_mlx_metallib_if_needed

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES/mlx-swift_Cmlx.bundle"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$MLX_METALLIB" "$APP_RESOURCES/mlx-swift_Cmlx.bundle/default.metallib"
swift "$ROOT_DIR/script/generate_app_icon.swift" "$APP_ICON"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>AutocompleteLab needs Accessibility permission to read the active text field and show local suggestions near the cursor.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

SIGNING_IDENTITY="$(find_signing_identity)"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE" >/dev/null
else
  codesign --force --options runtime --sign - "$APP_BUNDLE" >/dev/null
  echo "warning: no stable code signing identity found; Accessibility may ask again after rebuilds" >&2
fi

open_app() {
  if [[ "${AUTOCOMPLETE_LAB_TRACE:-}" =~ ^(0|false|no|off)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_TRACE "$AUTOCOMPLETE_LAB_TRACE"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_TRACE >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_SCREENSHOT_TRACE:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_SCREENSHOT_TRACE "$AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_SCREENSHOT_TRACE >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_RAW_TRACE:-}" =~ ^(1|true|yes|on|0|false|no|off)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_RAW_TRACE "$AUTOCOMPLETE_LAB_RAW_TRACE"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_RAW_TRACE >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_MODEL:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_MODEL "$AUTOCOMPLETE_LAB_MODEL"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_MODEL >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_VISIBLE_WORDS:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_VISIBLE_WORDS "$AUTOCOMPLETE_LAB_VISIBLE_WORDS"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_VISIBLE_WORDS >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS "$AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS "$AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS >/dev/null 2>&1 || true
  fi

  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..30}; do
      if current_bundle_is_running; then
        exit 0
      fi
      sleep 1
    done
    exit 1
    ;;
  --bundle-only|bundle-only)
    echo "App bundle built: $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle-only]" >&2
    exit 2
    ;;
esac
