#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DOC="$ROOT_DIR/docs/product/dependency-sdk-data-inventory.md"
APP_BUNDLE="${AUTOCOMPLETE_LAB_APP_BUNDLE:-$ROOT_DIR/dist/SteadyType.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/SteadyType"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
ENTITLEMENTS_TMP="$(mktemp)"
RUN_DIR="$ROOT_DIR/docs/diagnostics/runs/dependency-inventory"
trap 'rm -f "$ENTITLEMENTS_TMP"' EXIT

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
}

require_contains() {
  local path="$1"
  local needle="$2"
  local label="$3"
  if ! grep -F "$needle" "$path" >/dev/null; then
    echo "dependency inventory missing $label: $needle in $path" >&2
    exit 1
  fi
}

require_file "$DOC"
require_contains Package.swift 'https://github.com/ml-explore/mlx-swift-lm.git' "MLX Swift package pin"
require_contains Package.swift 'https://github.com/huggingface/swift-huggingface.git' "Swift Hugging Face package pin"
require_contains Package.swift 'https://github.com/huggingface/swift-transformers.git' "Swift Transformers package pin"

for needle in \
  "mlx-swift-lm" \
  "swift-huggingface" \
  "swift-transformers" \
  "NSAccessibilityUsageDescription" \
  "NSAppleEventsUsageDescription" \
  "com.apple.security.automation.apple-events" \
  "No analytics SDK" \
  "No crash reporting SDK" \
  "download_mlx_model.py" \
  "LocalModelAssetInstaller" \
  "real_app_smoke.sh"; do
  require_contains "$DOC" "$needle" "documented inventory item"
done

if rg -n 'Sentry|PostHog|Firebase|Amplitude|Mixpanel|Bugsnag|Crashlytics|TelemetryDeck' Package.swift Sources script --glob '!script/check_dependency_inventory.sh' >/tmp/autocomplete-dependency-forbidden-sdk.txt; then
  echo "unexpected analytics/crash SDK reference found" >&2
  cat /tmp/autocomplete-dependency-forbidden-sdk.txt >&2
  exit 1
fi

if [[ ! -x "$APP_BINARY" || ! -f "$INFO_PLIST" || "${AUTOCOMPLETE_LAB_REBUILD_DEPENDENCY_INVENTORY:-0}" =~ ^(1|true|yes|on)$ ]]; then
  ./script/build_and_run.sh --bundle-only >/tmp/autocomplete-dependency-inventory-build.log
fi

if [[ ! -x "$APP_BINARY" ]]; then
  echo "missing app binary for dependency inventory: $APP_BINARY" >&2
  cat /tmp/autocomplete-dependency-inventory-build.log >&2 2>/dev/null || true
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "missing app Info.plist for dependency inventory: $INFO_PLIST" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c 'Print :NSAccessibilityUsageDescription' "$INFO_PLIST" >/tmp/autocomplete-accessibility-usage.txt
/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' "$INFO_PLIST" >/tmp/autocomplete-apple-events-usage.txt
codesign -d --entitlements :- "$APP_BUNDLE" >"$ENTITLEMENTS_TMP" 2>/dev/null
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.automation.apple-events' "$ENTITLEMENTS_TMP" >/tmp/autocomplete-apple-events-entitlement.txt

for forbidden_key in \
  NSCameraUsageDescription \
  NSMicrophoneUsageDescription \
  NSScreenCaptureDescription \
  NSLocationWhenInUseUsageDescription \
  NSContactsUsageDescription \
  NSCalendarsUsageDescription; do
  if /usr/libexec/PlistBuddy -c "Print :$forbidden_key" "$INFO_PLIST" >/dev/null 2>&1; then
    echo "unexpected app permission in Info.plist: $forbidden_key" >&2
    exit 1
  fi
done

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"
otool -L "$APP_BINARY" >"$RUN_DIR/linked-libraries.txt"
find "$APP_BUNDLE/Contents" \( -name '*.framework' -o -name '*.dylib' \) -print | sort >"$RUN_DIR/bundled-frameworks.txt"

if grep -E 'Sentry|PostHog|Firebase|Amplitude|Mixpanel|Bugsnag|Crashlytics|TelemetryDeck' "$RUN_DIR/linked-libraries.txt" "$RUN_DIR/bundled-frameworks.txt" >/tmp/autocomplete-dependency-bundled-sdk.txt; then
  echo "unexpected analytics/crash SDK in built app bundle" >&2
  cat /tmp/autocomplete-dependency-bundled-sdk.txt >&2
  exit 1
fi

echo "Dependency and SDK inventory check passed."
