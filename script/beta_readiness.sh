#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="full"
PRIMARY_ARTIFACT="$ROOT_DIR/dist/SteadyType.dmg"
SECONDARY_ARCHIVE="$ROOT_DIR/dist/SteadyType.zip"
READINESS_SCRATCH_PATH_CREATED=""

cleanup_readiness_scratch_path() {
  if [[ -n "$READINESS_SCRATCH_PATH_CREATED" ]]; then
    rm -rf "$READINESS_SCRATCH_PATH_CREATED"
  fi
}

trap cleanup_readiness_scratch_path EXIT

configure_readiness_scratch_path() {
  local parent

  if [[ -n "${AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH:-}" ]]; then
    if ! mkdir -p "$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"; then
      echo "SwiftPM readiness scratch blocked: could not create AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH=$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH" >&2
      echo "Set AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH to a writable directory and rerun." >&2
      return 1
    fi

    export AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH
    echo "SwiftPM readiness scratch: $AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"
    return 0
  fi

  if ! [[ "${AUTOCOMPLETE_LAB_READINESS_ISOLATED_SCRATCH:-}" =~ ^(1|true|yes|on)$ ]]; then
    unset AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH
    echo "SwiftPM readiness scratch: default SwiftPM build cache"
    return 0
  fi

  parent="${TMPDIR:-/tmp}"
  if ! AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH="$(mktemp -d "${parent%/}/autocomplete-lab-beta-readiness.XXXXXX")"; then
    echo "SwiftPM readiness scratch blocked: could not create a unique SwiftPM scratch path under $parent." >&2
    echo "Set AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH to a writable directory and rerun." >&2
    return 1
  fi

  READINESS_SCRATCH_PATH_CREATED="$AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"
  export AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH
  echo "SwiftPM readiness scratch: $AUTOCOMPLETE_LAB_READINESS_SCRATCH_PATH"
}

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

configure_readiness_scratch_path || exit 1

READINESS_FAILED_LANES=()
READINESS_NEXT_ACTIONS=()
READINESS_SUMMARY_PRINTED=0
ACTIVE_READINESS_LANE=""

append_next_action() {
  local action="$1"
  local existing
  local action_count

  [[ -z "$action" ]] && return
  action_count=${#READINESS_NEXT_ACTIONS[@]}
  if ((action_count > 0)); then
    for existing in "${READINESS_NEXT_ACTIONS[@]}"; do
      [[ "$existing" == "$action" ]] && return
    done
  fi

  READINESS_NEXT_ACTIONS+=("$action")
}

readiness_next_action() {
  local lane="$1"

  case "$lane" in
    "Model asset")
      echo "Repair or install the local model in Settings, then rerun ./script/check_model_asset.py."
      ;;
    "Smoke")
      echo "Fix the first smoke failure, then rerun ./script/smoke_test.sh."
      ;;
    "Runtime production gate")
      echo "Launch SteadyType with Qwen3.5-4B-4bit ready, then rerun ./script/check_diagnostics_log.sh."
      ;;
    "Runtime no-egress proof")
      echo "Refresh the runtime no-egress proof, then rerun ./script/check_runtime_network_egress.py through beta readiness."
      ;;
    "Controls and diagnostics readiness")
      echo "Fix the named controls/diagnostics subcheck, then rerun ./script/check_controls_diagnostics_readiness.sh."
      ;;
    "Redacted report export")
      echo "Fix redacted export proof, then rerun ./script/check_redacted_report_export.sh."
      ;;
    "Issue template validation")
      echo "Fix the beta issue template, then rerun ./script/validate_beta_issue_template.sh."
      ;;
    "Onboarding walkthrough proof")
      echo "Record the clean TextEdit walkthrough row, then rerun ./script/check_onboarding_walkthrough_proof.py."
      ;;
    "Onboarding permission QA")
      echo "Complete the clean-user permission checklist, then rerun ./script/check_onboarding_permission_qa.sh --check."
      ;;
    "Clipboard fallback disabled")
      echo "Remove beta-unsafe clipboard fallback surfaces, then rerun ./script/beta_readiness.sh --check-only."
      ;;
    "Production mock fallback disabled")
      echo "Remove production mock fallback surfaces, then rerun ./script/beta_readiness.sh --check-only."
      ;;
    "Prompt app manifest proof gate")
      echo "Refresh bounded prompt-app manifest proof, then rerun ./script/check_prompt_app_manifest_proof.sh."
      ;;
    "Manual app proof")
      echo "Refresh beta-safe manual rows with ./script/manual_proof_refresh.sh, then rerun ./script/manual_smoke_status.sh --require-all."
      ;;
    "Visual placement proof")
      echo "Refresh missing screenshot-backed placement rows, then rerun ./script/check_visual_placement_evidence.sh --require-all."
      ;;
    "Latency beta gate")
      echo "Run current TextEdit model-latency proof, then rerun the latency beta gate."
      ;;
    "Release package prerequisites"|"Release package"|"Developer ID DMG signature"|"Developer ID archive signature"|"Notarized install proof"|"Private beta artifact"|"Apple notarization")
      echo "Rebuild, Developer ID sign, notarize, staple, and verify dist/SteadyType.dmg before rerunning beta readiness."
      ;;
    "Private beta packet")
      echo "Regenerate the private beta packet from the current DMG, then rerun ./script/private_beta_packet.sh --check."
      ;;
    *)
      echo "Fix the $lane lane, then rerun ./script/beta_readiness.sh --check-only."
      ;;
  esac
}

remember_readiness_failure() {
  local lane="$1"
  local existing
  local failed_count

  [[ -z "$lane" ]] && return
  failed_count=${#READINESS_FAILED_LANES[@]}
  if ((failed_count > 0)); then
    for existing in "${READINESS_FAILED_LANES[@]}"; do
      [[ "$existing" == "$lane" ]] && return
    done
  fi

  READINESS_FAILED_LANES+=("$lane")
  append_next_action "$(readiness_next_action "$lane")"
}

print_readiness_answer() {
  local answer="$1"
  local mode="$2"
  local index=1
  local lane
  local action
  local failed_count
  local action_count

  READINESS_SUMMARY_PRINTED=1
  echo
  echo "== Beta readiness answer =="
  if [[ "$answer" == "GO" ]]; then
    echo "GO: beta readiness passed in $mode mode."
    return
  fi

  failed_count=${#READINESS_FAILED_LANES[@]}
  echo "HOLD: $failed_count blocker(s) in $mode mode."
  echo "Failing lanes:"
  if ((failed_count > 0)); then
    for lane in "${READINESS_FAILED_LANES[@]}"; do
      echo "- $lane"
    done
  fi

  echo "Next 3 actions:"
  action_count=${#READINESS_NEXT_ACTIONS[@]}
  if ((action_count == 0)); then
    echo "1. Rerun ./script/beta_readiness.sh --check-only and fix the first blocked lane."
    return
  fi

  if ((action_count > 0)); then
    for action in "${READINESS_NEXT_ACTIONS[@]}"; do
      echo "$index. $action"
      index=$((index + 1))
      ((index > 3)) && break
    done
  fi
}

readiness_err_trap() {
  local status=$?

  if ((status != 0)) && [[ -n "$ACTIVE_READINESS_LANE" ]] && [[ "$READINESS_SUMMARY_PRINTED" == "0" ]]; then
    remember_readiness_failure "$ACTIVE_READINESS_LANE"
    print_readiness_answer "HOLD" "$MODE"
  fi

  exit "$status"
}

trap readiness_err_trap ERR

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
  remember_readiness_failure "$label"
  return 1
}

current_process_pgid() {
  ps -o pgid= -p "${BASHPID:-$$}" 2>/dev/null | tr -d '[:space:]'
}

with_privacy_export_proof_tree() {
  local pgid existing allowed_pgids

  pgid="$(current_process_pgid || true)"
  if [[ -z "$pgid" ]]; then
    "$@"
    return
  fi

  existing="${AUTOCOMPLETE_LAB_PRIVACY_EXPORT_ALLOWED_PROOF_PGIDS:-}"
  allowed_pgids="$pgid"
  if [[ -n "$existing" ]]; then
    allowed_pgids="$existing $pgid"
  fi

  AUTOCOMPLETE_LAB_PRIVACY_EXPORT_ALLOWED_PROOF_PGIDS="$allowed_pgids" "$@"
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

check_production_mock_fallback_disabled() {
  local failed=0

  if rg -n \
    'Mock Fallback|Mock Suggestions|gemmaLocalWithMockFallback|mockOnly' \
    Sources/AutocompleteLabApp; then
    failed=1
  fi

  if python3 - <<'PY'
from pathlib import Path
import re
import sys

engine = Path("Sources/AutocompleteLabResearch/LocalCompletionEngine.swift").read_text()
runtime = Path("Sources/AutocompleteLabCore/Runtime/CompletionRuntimeBenchmark.swift").read_text()

blocked = []
if re.search(r"public\s+init\s*\([^)]*\bfallback\s*:", engine, re.S):
    blocked.append("public LocalCompletionEngine fallback initializer")
if re.search(r"\bprivate\s+let\s+fallback\s*:", engine):
    blocked.append("LocalCompletionEngine runtime fallback slot")
if re.search(r"\btestFallback\s*:", engine):
    blocked.append("LocalCompletionEngine test fallback initializer")
if "fallbackCandidate: .liteRTLM" in runtime:
    blocked.append("MVP LiteRT-LM fallback candidate")

for item in blocked:
    print(item)
sys.exit(1 if blocked else 0)
PY
  then
    :
  else
    failed=1
  fi

  if ((failed > 0)); then
    echo "production mock fallback surfaces are not beta-safe"
    return 1
  fi

  echo "production mock fallback surfaces disabled"
}

check_runtime_no_egress_proof() {
  local proof_path="${AUTOCOMPLETE_LAB_NO_EGRESS_PROOF_JSON:-$ROOT_DIR/docs/product/runtime-network-egress-latest.json}"
  local diagnostics_log="${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}"
  local app_binary="${AUTOCOMPLETE_LAB_NO_EGRESS_APP_BINARY:-$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType}"
  local max_age_seconds="${AUTOCOMPLETE_LAB_NO_EGRESS_MAX_AGE_SECONDS:-86400}"
  local min_samples="${AUTOCOMPLETE_LAB_NO_EGRESS_MIN_SAMPLES:-10}"
  local args=(
    --validate-proof "$proof_path"
    --max-proof-age-seconds "$max_age_seconds"
    --min-samples "$min_samples"
    --diagnostics-log "$diagnostics_log"
    --require-newer-than-latest-launch
  )

  if [[ -n "$app_binary" ]]; then
    args+=(--app-binary "$app_binary")
  fi

  ./script/check_runtime_network_egress.py "${args[@]}"
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

run_release_proof_check() {
  local output

  if output="$("$@" 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  [[ -n "$output" ]] && printf '%s\n' "$output" >&2
  return 1
}

attach_dmg_for_inspection() {
  local dmg_path="$1"
  local mount_path="$2"
  local output

  if output="$(hdiutil attach "$dmg_path" -readonly -mountpoint "$mount_path" -nobrowse -quiet 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  sleep 1
  if output="$(hdiutil attach "$dmg_path" -readonly -mountpoint "$mount_path" -nobrowse -quiet 2>&1)"; then
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
  local checksum_path="$proof_dir/checksums.txt"
  local verify_dir mount_path app_path
  local failed=0

  if [[ -s "$blocker_path" ]]; then
    cat "$blocker_path"
    return 1
  fi

  for path in \
    "$proof_dir/notarytool-submit.txt" \
    "$proof_dir/stapler-validate.txt" \
    "$proof_dir/spctl-dmg.txt" \
    "$proof_dir/spctl-installed-app.txt" \
    "$checksum_path" \
    "$proof_dir/fresh-install-gatekeeper-proof.md"; do
    if [[ ! -s "$path" ]]; then
      echo "missing release proof: $path"
      failed=1
    fi
  done

  if [[ -s "$checksum_path" ]]; then
    for artifact_name in SteadyType.dmg SteadyType.zip; do
      local artifact_path="$ROOT_DIR/dist/$artifact_name"
      if [[ ! -f "$artifact_path" ]]; then
        continue
      fi

      local expected_sha actual_sha
      expected_sha="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"
      actual_sha="$(awk -v artifact="$artifact_name" '$1 == artifact {print $2; exit}' "$checksum_path")"

      if [[ -z "$actual_sha" ]]; then
        echo "release proof checksum is missing $artifact_name"
        failed=1
      elif [[ "$expected_sha" != "$actual_sha" ]]; then
        echo "release proof checksum is stale for $artifact_name"
        echo "expected: $expected_sha"
        echo "actual:   $actual_sha"
        failed=1
      fi
    done
  fi

  local archive_path="$ROOT_DIR/dist/SteadyType.zip"
  if [[ -s "$archive_path" ]]; then
    local verify_dir
    verify_dir="$(mktemp -d)"
    if ditto -x -k "$archive_path" "$verify_dir" &&
      [[ -d "$verify_dir/SteadyType.app" ]]; then
      if ! ./script/check_app_bundle.sh --release "$verify_dir/SteadyType.app"; then
        failed=1
      fi
    else
      echo "release archive cannot be expanded for signature proof: $archive_path"
      failed=1
    fi
    rm -rf "$verify_dir"
  fi

  if ((failed > 0)); then
    return 1
  fi

  check_current_artifact_checksum || return 1

  if ! run_release_proof_check \
    xcrun stapler validate "$PRIMARY_ARTIFACT"; then
    echo "current DMG stapler validation failed"
    return 1
  fi

  if ! run_release_proof_check \
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

  if ! run_release_proof_check \
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
  local selector_output

  if ! selector_output="$(./script/select_latency_window.py \
    --diagnostics-log "${AUTOCOMPLETE_LAB_LOG:-$HOME/Library/Logs/SteadyType/diagnostics.log}" \
    --trace-log "${AUTOCOMPLETE_LAB_TRACE_LOG:-${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/SteadyType/traces.jsonl}}" \
    --expected-asset "${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    --min-first-visible-samples "${AUTOCOMPLETE_LAB_BETA_MIN_FIRST_VISIBLE_SAMPLES:-5}" \
    --min-model-samples "${AUTOCOMPLETE_LAB_BETA_MIN_MODEL_SAMPLES:-5}" \
    --required-proof-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_PROOF_APP:-com.apple.TextEdit}" \
    --required-proof-scenario "${AUTOCOMPLETE_LAB_BETA_LATENCY_PROOF_SCENARIO:-textedit-model-latency}" \
    --required-trace-app "${AUTOCOMPLETE_LAB_BETA_LATENCY_TRACE_APP:-com.apple.TextEdit}" \
    --required-request-mode "${AUTOCOMPLETE_LAB_BETA_LATENCY_REQUEST_MODE:-wordCompletion}" \
    --app-binary "${AUTOCOMPLETE_LAB_BETA_LATENCY_APP_BINARY:-$ROOT_DIR/dist/SteadyType.app/Contents/MacOS/SteadyType}" \
    --require-model-backed-visible \
    --forbid-fast-word-visible
  )"; then
    return 1
  fi

  while IFS= read -r assignment; do
    [[ -n "$assignment" ]] && start_env+=("$assignment")
  done <<<"$selector_output"

  if ((${#start_env[@]})); then
    echo "Latency window: ${start_env[*]}"
    env "${start_env[@]}" ./script/latency_benchmark_report.py --beta-gate
    return
  fi

  ./script/latency_benchmark_report.py --beta-gate
}

print_next_beta_readiness_lanes() {
  local onboarding_failed="${1:-0}"

  echo
  echo "== Next proof lanes =="
  ./script/scorecard_next_proof_lanes.py --limit 5 || echo "Next proof lane listing failed."

  echo
  echo "== Automation-ready proof lanes =="
  ./script/scorecard_next_proof_lanes.py --limit 5 --automation-ready || echo "Automation-ready proof lane listing failed."

  if [[ "$onboarding_failed" == "1" ]]; then
    echo
    echo "== Onboarding walkthrough row template =="
    ./script/check_onboarding_walkthrough_proof.py --print-template || echo "Onboarding walkthrough template unavailable."
  fi
}

if [[ "$MODE" == "check-only" ]]; then
  failures=0
  onboarding_failed=0

  run_check "Model asset" ./script/check_model_asset.py || failures=$((failures + 1))
  run_check "Runtime production gate" env \
    AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
    AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
    ./script/check_diagnostics_log.sh || failures=$((failures + 1))
  run_check "Runtime no-egress proof" check_runtime_no_egress_proof || failures=$((failures + 1))
  run_check "Controls and diagnostics readiness" with_privacy_export_proof_tree ./script/check_controls_diagnostics_readiness.sh || failures=$((failures + 1))
  run_check "Redacted report export" with_privacy_export_proof_tree ./script/check_redacted_report_export.sh || failures=$((failures + 1))
  run_check "Issue template validation" ./script/validate_beta_issue_template.sh || failures=$((failures + 1))
  run_check "Onboarding walkthrough proof" ./script/check_onboarding_walkthrough_proof.py || {
    failures=$((failures + 1))
    onboarding_failed=1
  }
  run_check "Clipboard fallback disabled" check_clipboard_fallback_disabled || failures=$((failures + 1))
  run_check "Production mock fallback disabled" check_production_mock_fallback_disabled || failures=$((failures + 1))
  run_check "Prompt app manifest proof gate" ./script/check_prompt_app_manifest_proof.sh || failures=$((failures + 1))
  run_check "Onboarding permission QA" ./script/check_onboarding_permission_qa.sh --check || failures=$((failures + 1))
  run_check "Manual app proof" ./script/manual_smoke_status.sh --require-all || failures=$((failures + 1))
  run_check "Visual placement proof" ./script/check_visual_placement_evidence.sh --require-all || failures=$((failures + 1))
  # Run latency after proof/readiness checks so a later app relaunch cannot make
  # the sampled TextEdit proof stale.
  run_check "Latency beta gate" latency_beta_gate || failures=$((failures + 1))
  run_check "Release package prerequisites" ./script/package_release.sh --check --require-developer-id --require-notary-profile || failures=$((failures + 1))

  echo
  echo "== Private beta artifact =="
  if [[ -s "$PRIMARY_ARTIFACT" ]]; then
    echo "Private beta artifact: OK - $PRIMARY_ARTIFACT"
    run_check "Developer ID DMG signature" check_release_dmg_signature || failures=$((failures + 1))
    run_check "Developer ID archive signature" check_release_archive_signature || failures=$((failures + 1))
    run_check "Notarized install proof" check_notarized_install_proof || failures=$((failures + 1))
  else
    echo "Private beta artifact: blocked"
    echo "missing primary beta artifact: $PRIMARY_ARTIFACT"
    remember_readiness_failure "Private beta artifact"
    failures=$((failures + 1))
  fi

  if [[ -s "$PRIMARY_ARTIFACT" ]]; then
    run_check "Private beta packet" with_privacy_export_proof_tree ./script/private_beta_packet.sh --check || failures=$((failures + 1))
  else
    echo
    echo "== Private beta packet =="
    echo "Private beta packet: skipped until primary DMG exists"
  fi

  if ((failures > 0)); then
    print_readiness_answer "HOLD" "$MODE"
    echo "Beta readiness check-only found $failures blocker(s)."
    print_next_beta_readiness_lanes "$onboarding_failed"
    exit 1
  fi

  print_readiness_answer "GO" "$MODE"
  echo "Beta readiness check-only passed."
  exit 0
fi

ACTIVE_READINESS_LANE="Model asset"
echo "== Model asset =="
./script/check_model_asset.py

echo
ACTIVE_READINESS_LANE="Smoke"
echo "== Smoke =="
./script/smoke_test.sh

echo
ACTIVE_READINESS_LANE="Runtime production gate"
echo "== Runtime production gate =="
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
  AUTOCOMPLETE_LAB_EXPECTED_ASSET="${AUTOCOMPLETE_LAB_EXPECTED_ASSET:-Qwen3.5-4B-4bit}" \
  ./script/check_diagnostics_log.sh

echo
ACTIVE_READINESS_LANE="Runtime no-egress proof"
echo "== Runtime no-egress proof =="
check_runtime_no_egress_proof

echo
ACTIVE_READINESS_LANE="Controls and diagnostics readiness"
echo "== Controls and diagnostics readiness =="
./script/check_controls_diagnostics_readiness.sh

echo
ACTIVE_READINESS_LANE="Redacted report export"
echo "== Redacted report export =="
./script/check_redacted_report_export.sh

echo
ACTIVE_READINESS_LANE="Issue template validation"
echo "== Issue template validation =="
./script/validate_beta_issue_template.sh

echo
ACTIVE_READINESS_LANE="Onboarding walkthrough proof"
echo "== Onboarding walkthrough proof =="
./script/check_onboarding_walkthrough_proof.py

echo
ACTIVE_READINESS_LANE="Clipboard fallback disabled"
echo "== Clipboard fallback disabled =="
check_clipboard_fallback_disabled

echo
ACTIVE_READINESS_LANE="Production mock fallback disabled"
echo "== Production mock fallback disabled =="
check_production_mock_fallback_disabled

echo
ACTIVE_READINESS_LANE="Prompt app manifest proof gate"
echo "== Prompt app manifest proof gate =="
./script/check_prompt_app_manifest_proof.sh

echo
ACTIVE_READINESS_LANE="Onboarding permission QA"
echo "== Onboarding permission QA =="
./script/check_onboarding_permission_qa.sh --check

echo
ACTIVE_READINESS_LANE="Manual app proof"
echo "== Manual app proof =="
./script/manual_smoke_status.sh --require-all

echo
ACTIVE_READINESS_LANE="Visual placement proof"
echo "== Visual placement proof =="
./script/check_visual_placement_evidence.sh --require-all

echo
ACTIVE_READINESS_LANE="Latency beta gate"
echo "== Latency beta gate =="
latency_beta_gate

echo
ACTIVE_READINESS_LANE="Release package"
echo "== Release package =="
./script/package_release.sh --check --require-developer-id --require-notary-profile
./script/package_release.sh archive
check_release_dmg_signature
check_release_archive_signature
if [[ "${AUTOCOMPLETE_LAB_BETA_READINESS_NOTARIZE:-0}" =~ ^(1|true|yes|on)$ ]]; then
  ./script/package_release.sh --notarize
else
  echo "Apple notarization not run by default."
  echo "Set AUTOCOMPLETE_LAB_BETA_READINESS_NOTARIZE=1 to let this full gate submit the current DMG to Apple, then rerun."
  remember_readiness_failure "Apple notarization"
  print_readiness_answer "HOLD" "$MODE"
  exit 1
fi
check_notarized_install_proof

echo
ACTIVE_READINESS_LANE="Notarized install proof"
echo "== Notarized install proof =="
check_notarized_install_proof

echo
ACTIVE_READINESS_LANE="Private beta packet"
echo "== Private beta packet =="
./script/private_beta_packet.sh create
with_privacy_export_proof_tree ./script/private_beta_packet.sh --check

ACTIVE_READINESS_LANE=""
print_readiness_answer "GO" "$MODE"
echo
echo "Beta readiness passed."
echo "Primary artifact: $PRIMARY_ARTIFACT"
echo "Secondary archive: $SECONDARY_ARCHIVE"
echo "Private beta packet: $ROOT_DIR/dist/private-beta"
