#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="SteadyType"
HELPER_NAME="SteadyTypeTextEventHelper"
BUNDLE_ID="bar.r3d.steadytype"
MIN_SYSTEM_VERSION="26.0"
BUILD_CONFIGURATION="${AUTOCOMPLETE_LAB_BUILD_CONFIGURATION:-debug}"
APP_VERSION="${AUTOCOMPLETE_LAB_VERSION:-0.1.0}"
APP_BUILD="${AUTOCOMPLETE_LAB_BUILD:-$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${AUTOCOMPLETE_LAB_DIST_DIR:-$ROOT_DIR/dist}"
SWIFT_BUILD_ROOT="${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
HELPER_BINARY="$APP_MACOS/$HELPER_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS_PLIST="$ROOT_DIR/script/SteadyType.entitlements"
APP_ICON="$APP_RESOURCES/AppIcon.icns"
GENERATED_APP_ICON_REL="dist/$APP_NAME.generated-icon.$$.icns"
GENERATED_APP_ICON="$ROOT_DIR/$GENERATED_APP_ICON_REL"
MLX_METALLIB="$SWIFT_BUILD_ROOT/mlx-metal/default.metallib"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
SMOKE_LOCK_DIR="${AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-real-app-smoke.lock}"
FRESH_LATENCY_LOCK_DIR="${AUTOCOMPLETE_LAB_FRESH_LATENCY_LOCK_DIR:-${TMPDIR:-/tmp}/autocomplete-lab-fresh-latency.lock}"
PROOF_LOCK_WAIT_SECONDS="${AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS:-300}"

cd "$ROOT_DIR"

SWIFT_SCRATCH_ARGS=()
SWIFT_JOB_ARGS=()

if [[ -n "${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-}" ]]; then
  mkdir -p "$SWIFT_BUILD_ROOT"
  SWIFT_SCRATCH_ARGS+=(--scratch-path "$SWIFT_BUILD_ROOT")
fi

if [[ -n "${AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS:-}" ]]; then
  SWIFT_JOB_ARGS+=(--jobs "$AUTOCOMPLETE_LAB_SWIFT_BUILD_JOBS")
fi

truthy() {
  [[ "${1:-}" =~ ^(1|true|yes|on)$ ]]
}

proof_lock_status_requested() {
  case "$MODE" in
    --proof-lock-status|proof-lock-status|--status|status)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lock_pid_value() {
  local lock_dir="$1"
  local pid=""

  [[ -f "$lock_dir/pid" ]] || return 1
  pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  printf '%s\n' "$pid"
}

active_lock_pid() {
  local lock_dir="$1"
  local pid=""

  pid="$(lock_pid_value "$lock_dir" || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1 || return 1
  printf '%s\n' "$pid"
}

process_elapsed() {
  local pid="$1"
  ps -p "$pid" -o etime= 2>/dev/null | awk '{$1=$1; print; exit}'
}

process_command() {
  local pid="$1"
  ps -p "$pid" -o command= 2>/dev/null | sed -n 's/^[[:space:]]*//p' | head -n 1
}

describe_proof_lock() {
  local label="$1"
  local lock_dir="$2"
  local show_idle="${3:-0}"
  local pid=""
  local raw_pid=""
  local elapsed=""
  local command=""

  pid="$(active_lock_pid "$lock_dir" || true)"
  if [[ -n "$pid" ]]; then
    elapsed="$(process_elapsed "$pid")"
    command="$(process_command "$pid")"
    echo "$label: active"
    echo "  pid: $pid"
    echo "  elapsed: ${elapsed:-unknown}"
    echo "  command: ${command:-unknown}"
    echo "  lock: $lock_dir"
    return 0
  fi

  if [[ "$show_idle" == "1" ]]; then
    raw_pid="$(lock_pid_value "$lock_dir" || true)"
    if [[ -n "$raw_pid" ]]; then
      echo "$label: stale lock (pid $raw_pid is not running)"
      echo "  lock: $lock_dir"
    elif [[ -d "$lock_dir" ]]; then
      echo "$label: stale lock (missing pid)"
      echo "  lock: $lock_dir"
    else
      echo "$label: idle"
      echo "  lock: $lock_dir"
    fi
  fi

  return 1
}

print_active_proof_locks() {
  local active_count=0

  if describe_proof_lock "real app smoke" "$SMOKE_LOCK_DIR"; then
    active_count=$((active_count + 1))
  fi
  if describe_proof_lock "fresh latency proof" "$FRESH_LATENCY_LOCK_DIR"; then
    active_count=$((active_count + 1))
  fi

  ((active_count > 0))
}

proof_lock_retry_command() {
  if [[ "$MODE" == "run" ]]; then
    printf './script/build_and_run.sh\n'
  else
    printf './script/build_and_run.sh %s\n' "$MODE"
  fi
}

print_proof_lock_retry_hint() {
  local retry_command=""

  echo "Build/run will not relaunch or kill another proof run while these locks are active."
  echo "Check lock status without launching: ./script/build_and_run.sh --proof-lock-status"
  if proof_lock_status_requested; then
    echo "Retry your original build/run command after the proof run finishes."
    echo "Common retry: ./script/build_and_run.sh --verify"
    echo "Fail fast instead of waiting by setting AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS=0 on the build/run command."
  else
    retry_command="$(proof_lock_retry_command)"
    echo "Retry after the proof run finishes: $retry_command"
    echo "Fail fast instead of waiting: AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS=0 $retry_command"
  fi
}

print_proof_lock_status() {
  local active_count=0

  echo "Proof lock status for $APP_NAME build/run:"
  if describe_proof_lock "real app smoke" "$SMOKE_LOCK_DIR" 1; then
    active_count=$((active_count + 1))
  fi
  if describe_proof_lock "fresh latency proof" "$FRESH_LATENCY_LOCK_DIR" 1; then
    active_count=$((active_count + 1))
  fi

  if ((active_count > 0)); then
    echo "Build/run would wait up to ${PROOF_LOCK_WAIT_SECONDS}s before relaunching."
    print_proof_lock_retry_hint
    return 1
  fi

  echo "No active proof locks. Build/run can proceed."
  return 0
}

wait_for_proof_locks_if_needed() {
  if truthy "${AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE:-}"; then
    return 0
  fi

  if ! [[ "$PROOF_LOCK_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
    echo "AUTOCOMPLETE_LAB_BUILD_RUN_PROOF_LOCK_WAIT_SECONDS must be a non-negative integer" >&2
    exit 2
  fi

  local deadline=$((SECONDS + PROOF_LOCK_WAIT_SECONDS))
  local announced=0
  local next_update=0
  local smoke_pid fresh_pid

  while true; do
    smoke_pid="$(active_lock_pid "$SMOKE_LOCK_DIR" || true)"
    fresh_pid="$(active_lock_pid "$FRESH_LATENCY_LOCK_DIR" || true)"
    if [[ -z "$smoke_pid$fresh_pid" ]]; then
      return 0
    fi

    if ((SECONDS >= deadline)); then
      echo "Timed out after ${PROOF_LOCK_WAIT_SECONDS}s waiting for active proof run; refusing to relaunch $APP_NAME." >&2
      print_active_proof_locks >&2 || true
      print_proof_lock_retry_hint >&2
      exit 1
    fi

    if [[ "$announced" == "0" ]] || ((SECONDS >= next_update)); then
      echo "Waiting for active proof run before build/run relaunch. Timeout: ${PROOF_LOCK_WAIT_SECONDS}s." >&2
      print_active_proof_locks >&2 || true
      print_proof_lock_retry_hint >&2
      announced=1
      next_update=$((SECONDS + 30))
    fi
    sleep 2
  done
}

if proof_lock_status_requested; then
  if print_proof_lock_status; then
    exit 0
  fi
  exit 1
fi

running_app_process_rows() {
  ps ax -o pid=,command= 2>/dev/null |
    awk -v app_name="$APP_NAME" '
      {
        pid = $1
        command = $0
        sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", command)
      }
      command ~ ("^/.*/" app_name "\\.app/Contents/MacOS/" app_name "([[:space:]]|$)") {
        print pid "\t" command
      }
    '
}

running_app_pids() {
  running_app_process_rows | awk -F '\t' '{ print $1 }'
}

command_matches_binary() {
  local command="$1"
  local binary="$2"
  [[ "$command" == "$binary" || "$command" == "$binary "* ]]
}

running_app_services() {
  launchctl print "gui/$(id -u)" 2>/dev/null |
    awk -v needle="application.$BUNDLE_ID." 'index($0, needle) { print $NF }'
}

quarantine_other_worktrees_enabled() {
  [[ "${AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES:-}" =~ ^(1|true|yes|on)$ ]]
}

stale_app_bundles() {
  if ! quarantine_other_worktrees_enabled; then
    return 0
  fi

  local search_root="$HOME/.codex/worktrees"
  [[ -d "$search_root" ]] || return 0
  find "$search_root" \
    \( -name .build -o -name .git -o -name .swiftpm -o -name node_modules -o -name DerivedData \) -type d -prune -o \
    -path "*/dist/$APP_NAME.app" -type d -print 2>/dev/null || true
}

unregister_stale_app_bundles() {
  local bundle
  [[ -x "$LSREGISTER" ]] || return 0

  while IFS= read -r bundle; do
    [[ -z "$bundle" || "$bundle" == "$APP_BUNDLE" ]] && continue
    "$LSREGISTER" -u "$bundle" >/dev/null 2>&1 || true
  done < <(stale_app_bundles) || true

  return 0
}

quarantine_stale_app_bundles() {
  local bundle

  while IFS= read -r bundle; do
    [[ -z "$bundle" || "$bundle" == "$APP_BUNDLE" ]] && continue
    if [[ -x "$LSREGISTER" ]]; then
      "$LSREGISTER" -u "$bundle" >/dev/null 2>&1 || true
    fi
    if [[ "${AUTOCOMPLETE_LAB_MOVE_STALE_APP_BUNDLES:-}" =~ ^(1|true|yes|on)$ ]]; then
      local disabled timestamp
      timestamp="$(date +%Y%m%d%H%M%S)"
      disabled="${bundle}.disabled-${timestamp}-$$"
      mv "$bundle" "$disabled" >/dev/null 2>&1 || true
    fi
  done < <(stale_app_bundles) || true

  return 0
}

stop_running_apps() {
  local pid
  local service
  while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    launchctl bootout "gui/$(id -u)/$service" >/dev/null 2>&1 || true
  done < <(running_app_services)

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(running_app_pids)

  for _ in {1..20}; do
    [[ -z "$(running_app_pids)" ]] && return 0
    sleep 0.1
  done

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -9 "$pid" >/dev/null 2>&1 || true
  done < <(running_app_pids)
}

current_bundle_is_running() {
  [[ -n "$(current_bundle_pid)" ]]
}

current_bundle_pid() {
  local command
  local pid

  while IFS=$'\t' read -r pid command; do
    [[ -z "$pid" ]] && continue
    if command_matches_binary "$command" "$APP_BINARY"; then
      echo "$pid"
      return 0
    fi
  done < <(running_app_process_rows)

  return 1
}

pid_is_current_bundle() {
  local pid="$1"
  local command
  command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  command_matches_binary "$command" "$APP_BINARY"
}

stale_bundle_is_running() {
  local command
  local pid

  while IFS=$'\t' read -r pid command; do
    [[ -z "$pid" ]] && continue
    if [[ -n "$command" ]] && ! command_matches_binary "$command" "$APP_BINARY"; then
      return 0
    fi
  done < <(running_app_process_rows)

  return 1
}

print_running_apps() {
  local command
  local pid

  while IFS=$'\t' read -r pid command; do
    [[ -z "$pid" ]] && continue
    [[ -z "$command" ]] && continue
    echo "$pid $command" >&2
  done < <(running_app_process_rows)
}

skip_stale_app_bundle_scan() {
  [[ "${AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN:-}" =~ ^(1|true|yes|on)$ ]]
}

proof_launch_requested() {
  truthy "${AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION:-}" ||
    truthy "${AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION:-}" ||
    truthy "${AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION:-}" ||
    truthy "${AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK:-}" ||
    truthy "${AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING:-}" ||
    [[ -n "${AUTOCOMPLETE_LAB_PROOF_SCENARIO:-}" ]] ||
    [[ -n "${AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS:-}" ]]
}

scrub_proof_model_root_if_needed() {
  if proof_launch_requested && ! truthy "${AUTOCOMPLETE_LAB_ALLOW_PROOF_MODEL_ROOT:-}"; then
    unset AUTOCOMPLETE_LAB_MODEL_ROOT
    unset AUTOCOMPLETE_LAB_SKIP_KNOWN_MODEL_CHECKSUMS
    launchctl unsetenv AUTOCOMPLETE_LAB_MODEL_ROOT >/dev/null 2>&1 || true
    launchctl unsetenv AUTOCOMPLETE_LAB_SKIP_KNOWN_MODEL_CHECKSUMS >/dev/null 2>&1 || true
  fi
}

wait_for_proof_locks_if_needed

trap 'rm -f "$GENERATED_APP_ICON"' EXIT
mkdir -p "$DIST_DIR"
swift script/generate_app_icon.swift "$GENERATED_APP_ICON_REL"

if skip_stale_app_bundle_scan; then
  echo "Skipping stale app bundle scan because AUTOCOMPLETE_LAB_SKIP_STALE_APP_BUNDLE_SCAN is enabled." >&2
else
  quarantine_stale_app_bundles
fi
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

sign_app_bundle() {
  local identity="$1"

  if codesign --force --options runtime --entitlements "$ENTITLEMENTS_PLIST" --sign "$identity" "$APP_BUNDLE" >/dev/null; then
    return 0
  fi

  sleep 0.5
  codesign --force --options runtime --entitlements "$ENTITLEMENTS_PLIST" --sign "$identity" "dist/$APP_NAME.app" >/dev/null
}

run_swift_package_resolve() {
  if ((${#SWIFT_SCRATCH_ARGS[@]})); then
    swift package "${SWIFT_SCRATCH_ARGS[@]}" resolve
  else
    swift package resolve
  fi
}

run_swift_build_product() {
  local product="$1"
  local args=(-c "$BUILD_CONFIGURATION" --product "$product")
  if ((${#SWIFT_JOB_ARGS[@]})); then
    args=("${SWIFT_JOB_ARGS[@]}" "${args[@]}")
  fi
  if ((${#SWIFT_SCRATCH_ARGS[@]})); then
    args=("${SWIFT_SCRATCH_ARGS[@]}" "${args[@]}")
  fi
  swift build "${args[@]}"
}

run_swift_build() {
  run_swift_build_product "$APP_NAME"
  run_swift_build_product "$HELPER_NAME"
}

swift_build_bin_path() {
  local args=(-c "$BUILD_CONFIGURATION" --show-bin-path)
  if ((${#SWIFT_SCRATCH_ARGS[@]})); then
    args=("${SWIFT_SCRATCH_ARGS[@]}" "${args[@]}")
  fi
  swift build "${args[@]}"
}

run_swift_package_resolve
./script/patch_mlx_swift_lm.sh
run_swift_build
BUILD_BINARY="$(swift_build_bin_path)/$APP_NAME"
BUILD_HELPER_BINARY="$(swift_build_bin_path)/$HELPER_NAME"

build_mlx_metallib_if_needed() {
  if [[ -f "$MLX_METALLIB" ]]; then
    return 0
  fi

  local mlx_checkout="$SWIFT_BUILD_ROOT/checkouts/mlx-swift"
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
cp "$BUILD_HELPER_BINARY" "$HELPER_BINARY"
cp "$MLX_METALLIB" "$APP_RESOURCES/mlx-swift_Cmlx.bundle/default.metallib"
cp "$GENERATED_APP_ICON" "$APP_ICON"
chmod +x "$APP_BINARY"
chmod +x "$HELPER_BINARY"

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
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSAccessibilityUsageDescription</key>
  <string>SteadyType needs Accessibility permission to read the active text field and show local suggestions near the cursor.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>SteadyType uses Automation only for opted-in terminal hosts, so accepted suggestions can be inserted into supported prompts without submitting them.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

SIGNING_IDENTITY="$(find_signing_identity)"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$HELPER_BINARY" >/dev/null
  sign_app_bundle "$SIGNING_IDENTITY"
else
  codesign --force --options runtime --sign - "$HELPER_BINARY" >/dev/null
  codesign --force --options runtime --entitlements "$ENTITLEMENTS_PLIST" --sign - "$APP_BUNDLE" >/dev/null
  echo "warning: no stable code signing identity found; Accessibility may ask again after rebuilds" >&2
fi

open_app() {
  stop_running_apps
  scrub_proof_model_root_if_needed

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

  if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION \
      "$AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION \
      "$AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION \
      "$AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK \
      "$AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_PROOF_SCENARIO:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_SCENARIO "$AUTOCOMPLETE_LAB_PROOF_SCENARIO"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_SCENARIO >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING:-}" =~ ^(1|true|yes|on)$ ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING \
      "$AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS "$AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS >/dev/null 2>&1 || true
  fi

  if [[ -n "${AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS:-}" ]]; then
    launchctl setenv AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS "$AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
  else
    launchctl unsetenv AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS >/dev/null 2>&1 || true
  fi

  if [[ "${AUTOCOMPLETE_LAB_DIRECT_LAUNCH:-}" =~ ^(1|true|yes|on)$ ]]; then
    nohup "$APP_BINARY" >"$DIST_DIR/$APP_NAME.launch.log" 2>&1 </dev/null &
    disown "$!" 2>/dev/null || true
  else
    if [[ -x "$LSREGISTER" ]]; then
      "$LSREGISTER" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
    fi
    /usr/bin/open -n -F "$APP_BUNDLE"
  fi
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
    for attempt in {1..2}; do
      open_app
      for _ in {1..30}; do
        current_pid=""
        if stale_bundle_is_running; then
          if [[ "$attempt" == "1" ]]; then
            stop_running_apps
            quarantine_stale_app_bundles
            break
          fi
          echo "stale $APP_NAME process is running; expected $APP_BINARY" >&2
          print_running_apps
          exit 1
        fi
        current_pid="$(current_bundle_pid || true)"
        if [[ -n "$current_pid" ]]; then
          sleep "${AUTOCOMPLETE_LAB_VERIFY_STABILITY_SECONDS:-20}"
          if stale_bundle_is_running; then
            if [[ "$attempt" == "1" ]]; then
              stop_running_apps
              quarantine_stale_app_bundles
              break
            fi
            echo "stale $APP_NAME process is running; expected $APP_BINARY" >&2
            print_running_apps
            exit 1
          fi
          if pid_is_current_bundle "$current_pid"; then
            exit 0
          fi
          if [[ "$attempt" == "1" ]]; then
            stop_running_apps
            break
          fi
          echo "$APP_NAME exited or restarted during the verification stability window; expected pid $current_pid at $APP_BINARY to keep running" >&2
          exit 1
        fi
        sleep 1
      done
    done
    exit 1
    ;;
  --bundle-only|bundle-only)
    echo "App bundle built: $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle-only|--proof-lock-status]" >&2
    exit 2
    ;;
esac
