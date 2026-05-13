#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="full"
PRIMARY_ARTIFACT="$ROOT_DIR/dist/SteadyType.dmg"
SECONDARY_ARCHIVE="$ROOT_DIR/dist/SteadyType.zip"

usage() {
  cat <<'EOF'
Usage: script/beta_readiness.sh [--check-only]

Runs the full private-beta gate by default.

--check-only  Report current blockers without building archives or creating the
              private beta packet.
EOF
}

while (($#)); do
  case "$1" in
    --check-only)
      MODE="check-only"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run_check() {
  local label="$1"
  shift

  echo
  echo "== $label =="
  if "$@"; then
    echo "$label: OK"
    return 0
  fi

  echo "$label: blocked"
  return 1
}

check_clipboard_fallback_disabled() {
  local failed=0

  if rg -n \
    'NSPasteboard\.general|pasteboard\.clearContents|pasteboard\.setString|writeObjects\(|keyboardEventSource: nil, virtualKey: 9' \
    Sources/AutocompleteLabApp/Mac/InsertionEngine.swift; then
    failed=1
  fi

  if rg -n 'acceptMode: \.clipboardFallback' \
    Sources/AutocompleteLabCore/Compatibility/AppCompatibilityProfile.swift; then
    failed=1
  fi

  if ((failed > 0)); then
    echo "clipboard fallback insertion is not beta-safe"
    return 1
  fi

  echo "clipboard fallback insertion disabled"
}

check_current_artifact_checksum() {
  local checksums_path="$ROOT_DIR/dist/release-proof/checksums.txt"
  local expected_sha actual_sha

  if [[ ! -s "$PRIMARY_ARTIFACT" ]]; then
    echo "missing primary beta artifact: $PRIMARY_ARTIFACT"
    return 1
  fi

  if [[ ! -s "$checksums_path" ]]; then
    echo "missing release proof checksum file: $checksums_path"
    return 1
  fi

  expected_sha="$(shasum -a 256 "$PRIMARY_ARTIFACT" | awk '{print $1}')"
  actual_sha="$(awk '/SteadyType\.dmg/ {print $2; exit}' "$checksums_path")"

  if [[ -z "$actual_sha" ]]; then
    echo "missing SteadyType.dmg checksum in $checksums_path"
    return 1
  fi

  if [[ "$expected_sha" != "$actual_sha" ]]; then
    echo "release proof checksum is stale for SteadyType.dmg"
    echo "expected: $expected_sha"
    echo "actual:   $actual_sha"
    return 1
  fi

  echo "current DMG checksum matches release proof"
}

write_current_artifact_checksums() {
  local checksums_path="$ROOT_DIR/dist/release-proof/checksums.txt"
  local artifact_path

  mkdir -p "$(dirname "$checksums_path")"
  : >"$checksums_path"
  for artifact_path in "$PRIMARY_ARTIFACT" "$SECONDARY_ARCHIVE"; do
    if [[ -f "$artifact_path" ]]; then
      printf '%s  %s\n' "$(basename "$artifact_path")" "$(shasum -a 256 "$artifact_path" | awk '{print $1}')" >>"$checksums_path"
    fi
  done
}

record_release_proof_command() {
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

attach_dmg_for_inspection() {
  local dmg_path="$1"
  local mount_path="$2"
  local output

  if output="$(hdiutil attach "$dmg_path" -readonly -mountpoint "$mount_path" -nobrowse 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  sleep 1
  if output="$(hdiutil attach "$dmg_path" -readonly -mountpoint "$mount_path" -nobrowse 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  printf '%s\n' "$output" >&2
  return 1
}

check_release_dmg_signature() {
  local verify_dir mount_path app_path

  if [[ ! -s "$PRIMARY_ARTIFACT" ]]; then
    echo "missing primary beta artifact: $PRIMARY_ARTIFACT"
    return 1
  fi

  verify_dir="$(mktemp -d)"
  mount_path="$verify_dir/mount"
  app_path="$verify_dir/SteadyType.app"
  mkdir -p "$mount_path"

  if ! attach_dmg_for_inspection "$PRIMARY_ARTIFACT" "$mount_path"; then
    rm -rf "$verify_dir"
    echo "DMG inspection blocked: could not mount $PRIMARY_ARTIFACT"
    return 1
  fi

  cp -R "$mount_path/SteadyType.app" "$app_path" 2>/dev/null || true
  hdiutil detach "$mount_path" -quiet || true

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "Developer ID DMG signature blocked: DMG does not contain SteadyType.app"
    return 1
  fi

  if ! ./script/check_app_bundle.sh --release "$app_path"; then
    rm -rf "$verify_dir"
    echo "Developer ID DMG signature blocked: DMG app is not signed with Developer ID Application"
    echo "This is separate from Apple notarization credentials."
    return 1
  fi

  rm -rf "$verify_dir"
  echo "Developer ID DMG app signature: OK"
}

check_notarized_install_proof() {
  local proof_dir="$ROOT_DIR/dist/release-proof"
  local blocker_path="$proof_dir/notarization-blocker.txt"
  local verify_dir mount_path app_path
  local failed=0

  if [[ -s "$blocker_path" ]]; then
    cat "$blocker_path"
    return 1
  fi

  for path in \
    "$proof_dir/notarytool-submit.txt" \
    "$proof_dir/fresh-install-gatekeeper-proof.md"; do
    if [[ ! -s "$path" ]]; then
      echo "missing release proof: $path"
      failed=1
    fi
  done

  if ((failed > 0)); then
    return 1
  fi

  write_current_artifact_checksums
  check_current_artifact_checksum || return 1

  if ! record_release_proof_command "$proof_dir/stapler-validate.txt" \
    xcrun stapler validate "$PRIMARY_ARTIFACT"; then
    echo "current DMG stapler validation failed"
    return 1
  fi

  if ! record_release_proof_command "$proof_dir/spctl-dmg.txt" \
    spctl -a -t open --context context:primary-signature -v "$PRIMARY_ARTIFACT"; then
    echo "current DMG Gatekeeper assessment failed"
    return 1
  fi

  verify_dir="$(mktemp -d)"
  mount_path="$verify_dir/mount"
  app_path="$verify_dir/SteadyType.app"
  mkdir -p "$mount_path"

  if ! attach_dmg_for_inspection "$PRIMARY_ARTIFACT" "$mount_path"; then
    rm -rf "$verify_dir"
    echo "current DMG install proof failed: could not mount $PRIMARY_ARTIFACT"
    return 1
  fi

  cp -R "$mount_path/SteadyType.app" "$app_path" 2>/dev/null || true
  hdiutil detach "$mount_path" -quiet || true

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "current DMG install proof failed: DMG does not contain SteadyType.app"
    return 1
  fi

  if ! record_release_proof_command "$proof_dir/spctl-installed-app.txt" \
    spctl --assess --type execute --verbose=4 "$app_path"; then
    rm -rf "$verify_dir"
    echo "current installed-app Gatekeeper assessment failed"
    return 1
  fi

  rm -rf "$verify_dir"
  echo "current DMG notarization, stapling, and Gatekeeper proof: OK"
}

check_release_archive_signature() {
  local archive_path="$ROOT_DIR/dist/SteadyType.zip"
  local verify_dir app_path

  if [[ ! -s "$archive_path" ]]; then
    echo "missing archive: $archive_path"
    return 1
  fi

  verify_dir="$(mktemp -d)"
  app_path="$verify_dir/SteadyType.app"

  if ! ditto -x -k "$archive_path" "$verify_dir"; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: could not expand $archive_path"
    return 1
  fi

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: archive does not contain SteadyType.app"
    return 1
  fi

  if ! ./script/check_app_bundle.sh --release "$app_path"; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: archive app is not signed with Developer ID Application"
    echo "This is separate from Apple notarization credentials."
    return 1
  fi

  rm -rf "$verify_dir"
  echo "Developer ID archive signature: OK"
}

latency_beta_gate() {
  local start_env=()

  if [[ -z "${AUTOCOMPLETE_LAB_LOG_START_LINE:-}" && -z "${AUTOCOMPLETE_LAB_TRACE_START_LINE:-}" ]]; then
    local selector_output
    if ! selector_output="$(./script/select_latency_window.py \
      --diagnostics-log "${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}" \
      --trace-log "${AUTOCOMPLETE_LAB_TRACE_LOG:-${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}}" \
      --expected-asset "${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
      --min-first-visible-samples "${AUTOCOMPLETE_LAB_BETA_MIN_FIRST_VISIBLE_SAMPLES:-5}" \
      --min-model-samples "${AUTOCOMPLETE_LAB_BETA_MIN_MODEL_SAMPLES:-5}" \
      --required-proof-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_PROOF_APP:-com.apple.TextEdit}" \
      --required-trace-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_TRACE_APP:-com.apple.TextEdit}" \
      --require-model-backed-visible
    )"; then
      return 1
    fi

    while IFS= read -r assignment; do
      [[ -n "$assignment" ]] && start_env+=("$assignment")
    done <<<"$selector_output"
  fi

  if ((${#start_env[@]})); then
    echo "Latency window: ${start_env[*]}"
    env "${start_env[@]}" ./script/latency_benchmark_report.py --beta-gate
    return
  fi

  ./script/latency_benchmark_report.py --beta-gate
}

if [[ "$MODE" == "check-only" ]]; then
  failures=0

  run_check "Model asset" ./script/check_model_asset.py || failures=$((failures + 1))
  run_check "Runtime production gate" env \
    AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
    AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    ./script/check_diagnostics_log.sh || failures=$((failures + 1))
  run_check "Latency beta gate" latency_beta_gate || failures=$((failures + 1))
  run_check "Controls and diagnostics readiness" ./script/check_controls_diagnostics_readiness.sh || failures=$((failures + 1))
  run_check "Redacted report export" ./script/check_redacted_report_export.sh || failures=$((failures + 1))
  run_check "Issue template validation" ./script/validate_beta_issue_template.sh || failures=$((failures + 1))
  run_check "Clipboard fallback disabled" check_clipboard_fallback_disabled || failures=$((failures + 1))
  run_check "Prompt app proof gate" ./script/check_prompt_app_proof.sh || failures=$((failures + 1))
  run_check "Manual app proof" ./script/manual_smoke_status.sh --require-all || failures=$((failures + 1))
  run_check "Visual placement proof" ./script/check_visual_placement_evidence.sh --require-all || failures=$((failures + 1))
  run_check "Release package prerequisites" ./script/package_release.sh --check --require-developer-id --require-notary-profile || failures=$((failures + 1))

  echo
  echo "== Private beta artifact =="
  if [[ -s "$PRIMARY_ARTIFACT" ]]; then
    echo "Private beta artifact: OK - $PRIMARY_ARTIFACT"
    run_check "Developer ID DMG signature" check_release_dmg_signature || failures=$((failures + 1))
    run_check "Notarized install proof" check_notarized_install_proof || failures=$((failures + 1))
  else
    echo "Private beta artifact: blocked"
    echo "missing primary beta artifact: $PRIMARY_ARTIFACT"
    failures=$((failures + 1))
  fi

  if [[ -s "$PRIMARY_ARTIFACT" ]]; then
    run_check "Private beta packet" ./script/private_beta_packet.sh --check || failures=$((failures + 1))
  else
    echo
    echo "== Private beta packet =="
    echo "Private beta packet: skipped until primary DMG exists"
  fi

  if ((failures > 0)); then
    echo
    echo "Beta readiness check-only found $failures blocker(s)."
    exit 1
  fi

  echo
  echo "Beta readiness check-only passed."
  exit 0
fi

echo "== Model asset =="
./script/check_model_asset.py

echo
echo "== Smoke =="
./script/smoke_test.sh

echo
echo "== Runtime production gate =="
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
  ./script/check_diagnostics_log.sh
echo
echo "== Latency beta gate =="
latency_beta_gate


echo
echo "== Controls and diagnostics readiness =="
./script/check_controls_diagnostics_readiness.sh

echo
echo "== Redacted report export =="
./script/check_redacted_report_export.sh

echo
echo "== Issue template validation =="
./script/validate_beta_issue_template.sh

echo
echo "== Clipboard fallback disabled =="
check_clipboard_fallback_disabled

echo
echo "== Prompt app proof gate =="
./script/check_prompt_app_proof.sh

echo
echo "== Manual app proof =="
./script/manual_smoke_status.sh --require-all

echo
echo "== Visual placement proof =="
./script/check_visual_placement_evidence.sh --require-all

echo
echo "== Release package =="
./script/package_release.sh --check --require-developer-id --require-notary-profile
./script/package_release.sh archive
check_release_dmg_signature
if [[ "${AUTOCOMPLETE_LAB_BETA_READINESS_NOTARIZE:-0}" =~ ^(1|true|yes|on)$ ]]; then
  ./script/package_release.sh --notarize
else
  echo "Apple notarization not run by default."
  echo "Set AUTOCOMPLETE_LAB_BETA_READINESS_NOTARIZE=1 to let this full gate submit the current DMG to Apple, then rerun."
  exit 1
fi
check_notarized_install_proof

echo
echo "== Private beta packet =="
./script/private_beta_packet.sh create
./script/private_beta_packet.sh --check

echo
echo "Beta readiness passed."
echo "Primary artifact: $PRIMARY_ARTIFACT"
echo "Secondary archive: $SECONDARY_ARCHIVE"
echo "Private beta packet: $ROOT_DIR/dist/private-beta"
