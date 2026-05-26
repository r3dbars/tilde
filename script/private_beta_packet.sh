#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-create}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${AUTOCOMPLETE_LAB_DIST_DIR:-$ROOT_DIR/dist}"
DMG_PATH="$DIST_DIR/SteadyType.dmg"
ZIP_PATH="$DIST_DIR/SteadyType.zip"
PACKET_DIR="$DIST_DIR/private-beta"
README_PATH="$PACKET_DIR/README.md"
INSTALL_PATH="$PACKET_DIR/install-checklist.md"
FEEDBACK_PATH="$PACKET_DIR/feedback-log.md"
SESSION_REPORT_PATH="$PACKET_DIR/session-report.md"
DAILY_CHECKLIST_PATH="$PACKET_DIR/daily-tester-checklist.md"
REDACTED_EXPORT_PATH="$PACKET_DIR/redacted-report-export-flow.md"
FEEDBACK_TRIAGE_PATH="$PACKET_DIR/feedback-triage.md"
STOP_DASHBOARD_PATH="$PACKET_DIR/stop-condition-dashboard.md"
ISSUE_TEMPLATE_VALIDATION_PATH="$PACKET_DIR/issue-template-validation.md"
READINESS_SUMMARY_PATH="$PACKET_DIR/beta-readiness-summary.md"
TESTER_DOCS_DIR="$PACKET_DIR/tester-docs"
MODEL_ASSET_PATH="$PACKET_DIR/model-asset.md"
PRIVACY_STATUS_PATH="$PACKET_DIR/privacy-status.md"
CHECKSUM_PATH="$PACKET_DIR/checksums.txt"
RELEASE_PROOF_DIR="$DIST_DIR/release-proof"
RELEASE_CHECKSUM_PATH="$RELEASE_PROOF_DIR/checksums.txt"
NOTARY_BLOCKER_PATH="$RELEASE_PROOF_DIR/notarization-blocker.txt"

cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: script/private_beta_packet.sh [create|--check]

create   Create a local private-beta packet beside dist/SteadyType.dmg.
--check  Validate that the packet exists and points at the current DMG.
--print-feedback-template
         Print the no-raw-text feedback template used in the packet.
--print-session-report-template
         Print the one-row session report template used in the packet.
--print-daily-checklist-template
         Print the tester daily checklist used in the packet.
--print-redacted-export-template
         Print the redacted report export flow used in the packet.
--print-feedback-triage-template
         Print the feedback triage label flow used in the packet.
--print-stop-dashboard-template
         Print the stop-condition dashboard used in the packet.
--print-model-asset-template [expected-model-path]
         Print the tester-safe model asset template used in the packet.

This script only writes local files. It never uploads or sends beta data.
By default it requires the DMG to contain a Developer ID signed app and to pass
current stapler and Gatekeeper checks. Set
AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_RELEASE_SIGNATURE=0 only for local script tests.
Set AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_NOTARIZED_DMG=0 only for local script tests.
EOF
}

print_feedback_template() {
  cat <<'EOF'
# Feedback Log

Use one short row per real writing session.

Do not include raw typed text, prompts, screenshots, document names, URLs,
recipients, subject lines, or trace excerpts. Use plain labels like
`wrong app`, `late`, `too much`, or `good word finish`.

| Date | Tester | App | Minutes | Tab predictable? | Placement sane? | Helped? | Annoyed? | Broke trust? | Redacted report exported? | Notes (no private text) |
| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |
|  |  | TextEdit / Notes / Obsidian / Chrome |  | yes/no | yes/no | yes/no | yes/no | yes/no | yes/no |  |

Questions to answer after each session:

- Did Tab feel predictable?
- Did the suggestion appear in a sane place?
- Did it finish words you were already typing?
- Did it suggest weird repeated phrases?
- Did it ever insert text you did not expect?
EOF
}

print_session_report_template() {
  cat <<'EOF'
# Session Report

Use one short row in `feedback-log.md` after each real beta writing session.
Do not paste raw typed text, prompts, screenshots, document names, URLs,
recipients, subject lines, or trace excerpts into the report.

## Commands

```bash
./script/check_trace_eval.sh
./script/beta_readiness.sh --check-only
./script/model_latency_report.py --latest
./script/model_latency_report.py --latest --require-shown-samples 5
./script/check_redacted_report_export.sh
```

## Notes

- Record the app, minutes, Tab predictability, placement sanity, and whether trust broke.
- Export the redacted local report from Diagnostics.
- Copy only redacted repeated-miss titles or failure reason labels from Diagnostics or the trace eval report.
- If the latency report has no samples, type one short disposable sentence, wait for a phrase suggestion, and rerun it.
- Fix the top repeated trust miss before inviting more testers.
EOF
}

print_daily_checklist_template() {
  cat <<'EOF'
# Daily Tester Checklist

Use this once per beta day. It should take about 2 minutes.

## Before Writing

- Open SteadyType from the menu bar.
- Confirm the local model is ready in Settings.
- Confirm raw text tracing and screenshot tracing are off unless Justin asked
  for a debug session.
- Use only the apps listed in the beta packet for that day.
- Know the exits: `Esc` dismisses, menu bar pause stops suggestions, and
  `Pause Current App` stops the current app.

## During Writing

- Write normally for 5 to 20 minutes.
- Accept only with `Tab` when the next word is clearly wanted.
- Press `Esc` when a suggestion feels wrong.
- Stop immediately if a suggestion appears in a search, login, payment,
  address, URL, private, or secure field.
- Stop immediately if text inserts in the wrong app, wrong field, wrong spot,
  duplicates, submits a prompt, or makes `Tab` feel unsafe.

## After Writing

- Open Diagnostics.
- Export the Privacy Bundle.
- Add one short row to `feedback-log.md`.
- File a beta feedback issue only when something broke trust, repeated, or
  should change before the next tester.
- Do not include raw typed text, prompts, screenshots, document names, URLs,
  recipients, subject lines, or trace excerpts.
EOF
}

print_redacted_export_template() {
  cat <<'EOF'
# Redacted Report Export Flow

The default beta report is local and redacted.

## Tester Path

1. Open the SteadyType menu bar item.
2. Open `Debug` -> `Diagnostics`.
3. Choose `Export Privacy Bundle`.
4. Share only the exported privacy bundle when filing feedback.
5. If the issue form asks for details, use labels like `wrong app`, `late`,
   `too much`, `good word finish`, or `Tab surprised me`.

Do not attach raw traces, screenshots, typed text, prompts, model output,
accepted text, document names, URLs, recipients, or subject lines unless there
is a separate explicit debug session.

## Operator Proof

Run this before trusting the export flow for a new artifact:

```bash
./script/check_redacted_report_export.sh
```

The beta stops if the redacted export fails or asks for private content by
default.
EOF
}

print_feedback_triage_template() {
  cat <<'EOF'
# Feedback Triage

Every beta issue starts with:

- `beta feedback`
- `needs triage`

Use these labels after the first read:

| Label | Use when | Action |
| --- | --- | --- |
| `beta stop` | A hard stop condition happened. | Stop the beta until proof shows it is fixed. |
| `beta trust blocker` | Wrong insertion, prompt submit, secure/private field, data loss, or unsafe Tab. | Fix before more testers. |
| `beta high` | Repeated interruption or broken core flow. | Fix before expanding the beta. |
| `beta needs report` | The issue needs a redacted Privacy Bundle. | Ask only for the redacted export. |
| `beta docs` | Install, privacy, export, or uninstall copy is confusing. | Patch the packet before the next invite. |
| `beta ready to close` | The fix has proof and the tester confirmed the outcome. | Close after the proof link is attached. |

Triage order:

1. Check whether a stop condition is selected.
2. Confirm build, macOS/hardware, app, permission state, expected behavior,
   actual behavior, repro steps, and redacted diagnostics status are present.
3. Add the severity label.
4. Link the proof command or report that will close the issue.
5. Remove `needs triage` only after the next action is clear.

Never ask for raw typed text, prompts, screenshots, URLs, recipients, subject
lines, or trace excerpts in normal beta feedback.
EOF
}

print_stop_dashboard_template() {
  cat <<'EOF'
# Stop-Condition Dashboard

If any stop condition is `yes`, stop the beta before inviting or continuing
with testers.

| Stop condition | Proof command or check | Feedback label | Current status |
| --- | --- | --- | --- |
| Wrong app, wrong field, wrong spot, duplicate insertion, or focus steal | `./script/check_trace_eval.sh` plus the session Privacy Bundle | `beta stop`, `beta trust blocker` | open |
| Prompt/chat submitted from Tab or full accept | `./script/manual_proof_queue.sh --print` and same-slice no-submit proof | `beta stop`, `beta trust blocker` | open |
| Suggestion appeared in search, login, payment, address, URL, private, or secure field | `./script/beta_readiness.sh --check-only` plus the forced edge-case row | `beta stop`, `beta trust blocker` | open |
| `Tab` felt unreliable or surprising | `./script/manual_smoke_status.sh --require-all` and the tester repro | `beta stop`, `beta high` | open |
| Accepted text was deleted within 2 seconds repeatedly | `./script/check_trace_eval.sh` accepted-and-kept / annoyance section | `beta high` | open |
| Mock fallback, manual model server, Ollama, llama.cpp, Python, or shell setup was needed | `./script/beta_readiness.sh --check-only` and `./script/check_diagnostics_log.sh` | `beta stop`, `beta trust blocker` | open |
| Redacted report export failed or requested private content | `./script/check_redacted_report_export.sh` | `beta stop`, `beta needs report` | open |
| Packet checksum is stale for the tester artifact | `./script/private_beta_packet.sh --check` | `beta stop`, `beta docs` | open |

Close a stop row only after the proof command passes for the affected artifact
or the affected app is removed from beta coverage.
EOF
}

print_model_asset_template() {
  local expected_model_path="${1:-<model folder shown in SteadyType Settings>}"

  cat <<EOF
# Model Asset Check

The private beta is not ready if the app falls back to mock output.

Expected model:

\`\`\`text
$expected_model_path
\`\`\`

Verify it in the app:

1. Open SteadyType Settings.
2. Check \`Local model\`.
3. Confirm Settings says the model is ready.

If the model is missing, invalid, or needs repair, use the Settings \`Install
Local Model\` or \`Repair Local Model\` button and wait for it to finish. If
that in-app setup fails, stop the beta session.

Do not ask testers to run Python, shell scripts, Ollama, llama.cpp, or any
separate model server.
EOF
}

write_issue_template_validation() {
  cat >"$ISSUE_TEMPLATE_VALIDATION_PATH" <<'EOF'
# Issue Template Validation

The structured beta issue form is part of the beta gate.

Validate it with:

```bash
./script/validate_beta_issue_template.sh
```

The validator checks that the issue form:

- starts with `beta feedback` and `needs triage`,
- requires build, macOS/hardware, target app, permission state, severity,
  stop condition, expected behavior, actual behavior, reproduction steps, and
  redacted diagnostics status,
- offers the required trust-blocker severity,
- asks for redacted diagnostics instead of raw private content,
- has matching feedback triage labels in `.github/labels.yml`.

Status at packet generation: passed.
EOF
}

current_commit() {
  git rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

write_readiness_summary() {
  local sha="$1"
  local generated_at commit
  generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  commit="$(current_commit)"

  cat >"$READINESS_SUMMARY_PATH" <<EOF
# Beta Readiness Summary

Generated: $generated_at
Commit: $commit
Primary artifact: ../SteadyType.dmg
Secondary archive: ../SteadyType.zip
SHA-256: $sha

## Current Readiness

- Docs and feedback operations: 10/10 when this packet validates.
- Private beta readiness depends on the current DMG passing stapler, spctl, and
  install proof. Saved proof files alone do not count.
- Do not invite testers unless the stop dashboard has no open stop rows.

## Required Checks

\`\`\`bash
./script/private_beta_packet_self_test.sh
./script/validate_beta_issue_template.sh
./script/beta_readiness.sh --check-only
./script/check_current_build_privacy_export.sh
./script/check_redacted_report_export.sh
./script/private_beta_packet.sh --check
\`\`\`

Expected remaining blockers must be named in
\`docs/product/beta-readiness-checklist.md\`. Wrong insertion, sensitive-field
suggestion, unreliable Tab, mock fallback, manual model setup, stale packet
checksum, or failed redacted export are not acceptable blockers; they stop the
beta.

## Packet Files

- \`install-checklist.md\`
- \`daily-tester-checklist.md\`
- \`redacted-report-export-flow.md\`
- \`feedback-log.md\`
- \`feedback-triage.md\`
- \`stop-condition-dashboard.md\`
- \`issue-template-validation.md\`
- \`privacy-status.md\`
- \`model-asset.md\`
- \`tester-docs/PRIVACY-BETA.md\`
- \`tester-docs/FIRST-RUN-BETA.md\`
- \`tester-docs/KNOWN-LIMITATIONS.md\`
- \`tester-docs/UNINSTALL-DELETE-DATA.md\`
- \`tester-docs/DIAGNOSTIC-EXPORT.md\`
- \`tester-docs/RELEASE-NOTES.md\`
- \`tester-docs/private-beta-ops-loop.md\`
- \`tester-docs/autocomplete-beta-feedback.yml\`
- \`tester-docs/labels.yml\`
- \`checksums.txt\`
EOF
}

primary_artifact_sha() {
  shasum -a 256 "$DMG_PATH" | awk '{print $1}'
}

secondary_archive_sha() {
  if [[ -s "$ZIP_PATH" ]]; then
    shasum -a 256 "$ZIP_PATH" | awk '{print $1}'
  fi
  return 0
}

packet_checksum_for() {
  local artifact_name="$1"
  awk -v artifact_name="$artifact_name" '$1 == artifact_name { print $2; exit }' "$CHECKSUM_PATH"
}

packet_required_paths() {
  printf '%s\n' \
    "$README_PATH" \
    "$INSTALL_PATH" \
    "$DAILY_CHECKLIST_PATH" \
    "$REDACTED_EXPORT_PATH" \
    "$FEEDBACK_TRIAGE_PATH" \
    "$STOP_DASHBOARD_PATH" \
    "$ISSUE_TEMPLATE_VALIDATION_PATH" \
    "$READINESS_SUMMARY_PATH" \
    "$TESTER_DOCS_DIR/PRIVACY-BETA.md" \
    "$TESTER_DOCS_DIR/FIRST-RUN-BETA.md" \
    "$TESTER_DOCS_DIR/KNOWN-LIMITATIONS.md" \
    "$TESTER_DOCS_DIR/UNINSTALL-DELETE-DATA.md" \
    "$TESTER_DOCS_DIR/DIAGNOSTIC-EXPORT.md" \
    "$TESTER_DOCS_DIR/RELEASE-NOTES.md" \
    "$TESTER_DOCS_DIR/private-beta-ops-loop.md" \
    "$TESTER_DOCS_DIR/autocomplete-beta-feedback.yml" \
    "$TESTER_DOCS_DIR/labels.yml" \
    "$MODEL_ASSET_PATH" \
    "$FEEDBACK_PATH" \
    "$SESSION_REPORT_PATH" \
    "$PRIVACY_STATUS_PATH" \
    "$CHECKSUM_PATH"
}

packet_regeneration_reason() {
  local path expected_sha actual_sha expected_zip_sha actual_zip_sha

  while IFS= read -r path; do
    if [[ ! -s "$path" ]]; then
      echo "missing beta packet file: $path"
      return 0
    fi
  done < <(packet_required_paths)

  expected_sha="$(primary_artifact_sha)"
  actual_sha="$(packet_checksum_for "SteadyType.dmg")"
  if [[ -z "$actual_sha" || "$expected_sha" != "$actual_sha" ]]; then
    echo "beta packet checksum is stale for SteadyType.dmg"
    echo "expected: $expected_sha"
    echo "actual:   ${actual_sha:-missing}"
    return 0
  fi

  expected_zip_sha="$(secondary_archive_sha)"
  actual_zip_sha="$(packet_checksum_for "SteadyType.zip")"
  if [[ -n "$expected_zip_sha" ]]; then
    if [[ -z "$actual_zip_sha" || "$expected_zip_sha" != "$actual_zip_sha" ]]; then
      echo "beta packet checksum is stale for SteadyType.zip"
      echo "expected: $expected_zip_sha"
      echo "actual:   ${actual_zip_sha:-missing}"
      return 0
    fi
  elif [[ -n "$actual_zip_sha" ]]; then
    echo "beta packet checksum references missing SteadyType.zip"
    return 0
  fi

  return 1
}

check_secondary_archive_app() {
  local verify_dir app_path

  if [[ ! -s "$ZIP_PATH" ]]; then
    return 0
  fi

  verify_dir="$(mktemp -d)"
  app_path="$verify_dir/SteadyType.app"

  if ! ditto -x -k "$ZIP_PATH" "$verify_dir"; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: could not expand secondary archive: $ZIP_PATH" >&2
    exit 1
  fi

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: secondary archive does not contain SteadyType.app" >&2
    exit 1
  fi

  if ! ./script/check_app_bundle.sh --release "$app_path"; then
    rm -rf "$verify_dir"
    echo "Developer ID archive signature blocked: secondary archive app is not signed with Developer ID Application" >&2
    echo "Send testers the DMG, and refresh or remove the secondary ZIP before shipping the packet." >&2
    exit 1
  fi

  rm -rf "$verify_dir"
}

require_primary_artifact() {
  if [[ ! -s "$DMG_PATH" ]]; then
    echo "missing primary beta artifact: $DMG_PATH" >&2
    echo "Run ./script/package_release.sh archive, then ./script/package_release.sh --notarize." >&2
    exit 1
  fi
}

record_proof_command() {
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

run_command_read_only() {
  local output

  if output="$("$@" 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    return 0
  fi

  [[ -n "$output" ]] && printf '%s\n' "$output" >&2
  return 1
}

run_artifact_proof_command() {
  local output_path="$1"
  shift

  if [[ "$MODE" == "--check" || "$MODE" == "check" ]]; then
    run_command_read_only "$@"
    return
  fi

  record_proof_command "$output_path" "$@"
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

check_primary_artifact_app() {
  local verify_dir mount_path app_path
  local proof_dir="$DIST_DIR/release-proof"
  verify_dir="$(mktemp -d)"
  mount_path="$verify_dir/mount"
  app_path="$verify_dir/SteadyType.app"
  mkdir -p "$mount_path"

  if ! attach_dmg_for_inspection "$DMG_PATH" "$mount_path"; then
    rm -rf "$verify_dir"
    echo "DMG inspection blocked: could not mount primary beta artifact: $DMG_PATH" >&2
    exit 1
  fi

  cp -R "$mount_path/SteadyType.app" "$app_path" 2>/dev/null || true
  hdiutil detach "$mount_path" -quiet || true

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "primary beta artifact does not contain SteadyType.app" >&2
    exit 1
  fi

  if [[ "${AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_RELEASE_SIGNATURE:-1}" == "1" ]]; then
    if ! ./script/check_app_bundle.sh --release "$app_path"; then
      rm -rf "$verify_dir"
      echo "Developer ID DMG signature blocked: $DMG_PATH does not contain a Developer ID signed SteadyType.app" >&2
      echo "This is separate from Apple notarization credentials. Rebuild the archive with ./script/package_release.sh archive before checking the beta packet." >&2
      exit 1
    fi
  else
    ./script/check_app_bundle.sh "$app_path"
  fi

  if [[ "${AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_NOTARIZED_DMG:-1}" == "1" ]]; then
    if ! run_artifact_proof_command "$proof_dir/stapler-validate.txt" \
      xcrun stapler validate "$DMG_PATH"; then
      rm -rf "$verify_dir"
      echo "notarized DMG blocked: current stapler validation failed for $DMG_PATH" >&2
      exit 1
    fi

    if ! run_artifact_proof_command "$proof_dir/spctl-dmg.txt" \
      spctl -a -t open --context context:primary-signature -v "$DMG_PATH"; then
      rm -rf "$verify_dir"
      echo "notarized DMG blocked: current Gatekeeper assessment failed for $DMG_PATH" >&2
      exit 1
    fi

    if ! run_artifact_proof_command "$proof_dir/spctl-installed-app.txt" \
      spctl --assess --type execute --verbose=4 "$app_path"; then
      rm -rf "$verify_dir"
      echo "notarized DMG blocked: installed app Gatekeeper assessment failed for the current DMG" >&2
      exit 1
    fi
  fi

  rm -rf "$verify_dir"
}

check_archive_privacy_export() {
  local verify_dir proof_dir app_path
  verify_dir="$(mktemp -d)"
  proof_dir="$(mktemp -d)"

  ditto -x -k "$ZIP_PATH" "$verify_dir"
  app_path="$verify_dir/SteadyType.app"

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir" "$proof_dir"
    echo "archive does not contain SteadyType.app" >&2
    exit 1
  fi

  AUTOCOMPLETE_LAB_APP_BUNDLE="$app_path" \
  AUTOCOMPLETE_LAB_PRIVACY_PROOF_OUTPUT="$proof_dir" \
    ./script/check_current_build_privacy_export.sh >/tmp/autocomplete-private-beta-privacy-proof.txt

  rm -rf "$verify_dir" "$proof_dir"
}

require_same_file() {
  local source_path="$1"
  local packet_path="$2"

  if ! cmp -s "$source_path" "$packet_path"; then
    echo "beta packet doc is stale: $packet_path" >&2
    echo "Regenerate with ./script/private_beta_packet.sh create" >&2
    exit 1
  fi
}

require_generated_file() {
  local packet_path="$1"
  shift

  local expected_path
  expected_path="$(mktemp)"
  "$@" >"$expected_path"

  if ! cmp -s "$expected_path" "$packet_path"; then
    echo "beta packet generated file is stale: $packet_path" >&2
    echo "Regenerate with ./script/private_beta_packet.sh create" >&2
    rm -f "$expected_path"
    exit 1
  fi

  rm -f "$expected_path"
}

create_packet() {
  require_primary_artifact
  ./script/check_model_asset.py
  ./script/validate_beta_issue_template.sh --quiet
  check_primary_artifact_app
  check_secondary_archive_app
  mkdir -p "$PACKET_DIR"
  mkdir -p "$TESTER_DOCS_DIR"

  local sha zip_sha
  sha="$(primary_artifact_sha)"
  zip_sha="$(secondary_archive_sha)"

  cat >"$README_PATH" <<EOF
# SteadyType Private Beta Packet

Primary artifact: ../SteadyType.dmg
Secondary archive: ../SteadyType.zip
SHA-256: $sha

This is a local-only packet for a tiny private beta. Nothing here uploads
traces, screenshots, prompts, or typed text anywhere.

Send testers the DMG, not the ZIP. The DMG is the notarized artifact and the
packet checker revalidates the current DMG with stapler and spctl instead of
trusting old proof files.

Start with TextEdit. Then try Notes. Then try Obsidian. Chrome local
textarea/contenteditable fixtures are sanity checks, not the main product loop.

Read before inviting testers:

- \`tester-docs/PRIVACY-BETA.md\`
- \`tester-docs/FIRST-RUN-BETA.md\`
- \`tester-docs/KNOWN-LIMITATIONS.md\`
- \`tester-docs/UNINSTALL-DELETE-DATA.md\`
- \`tester-docs/DIAGNOSTIC-EXPORT.md\`
- \`tester-docs/RELEASE-NOTES.md\`
- \`tester-docs/private-beta-ops-loop.md\`
- \`tester-docs/autocomplete-beta-feedback.yml\`
- \`tester-docs/labels.yml\`
- \`daily-tester-checklist.md\`
- \`redacted-report-export-flow.md\`
- \`stop-condition-dashboard.md\`

Useful commands:

\`\`\`bash
./script/check_model_asset.py
./script/private_beta_packet_self_test.sh
./script/validate_beta_issue_template.sh
./script/beta_readiness.sh
./script/manual_smoke_status.sh --require-all
./script/manual_proof_queue.sh --print
./script/check_trace_eval.sh
./script/beta_readiness.sh --check-only
./script/model_latency_report.py --latest
./script/check_current_build_privacy_export.sh
./script/check_redacted_report_export.sh
open "\$HOME/Library/Logs/SteadyType"
\`\`\`

Default beta feedback uses only the redacted privacy bundle. Do not ask testers
for raw traces, screenshots, prompts, typed text, or accepted text by default.

If a tester needs to report something from inside the app, use the menu bar
\`Submit Feedback...\` path. It opens the structured GitHub issue form and does
not attach diagnostics or typed content automatically.
EOF

  cat >"$INSTALL_PATH" <<'EOF'
# Install Checklist

1. Open `SteadyType.dmg`.
2. Drag `SteadyType.app` to `Applications`.
3. Open `SteadyType.app`.
4. Open Settings from the menu bar item.
5. Click `Allow Accessibility` in SteadyType, then grant Accessibility in System Settings.
6. Return to Settings and confirm Accessibility updates without restarting.
7. Read `tester-docs/FIRST-RUN-BETA.md`.
8. If the local model is not ready, use `Install Local Model` or `Repair Local Model` in Settings and wait for it to finish.
9. Confirm Settings says the model is ready.
10. Click `Start TextEdit Practice`.
11. Use Tab for one-word accept.
12. Use the key above Tab for full accept only in non-prompt apps where the profile allows it.
13. Press Esc if a suggestion feels wrong.
14. Use Diagnostics -> Export to create the local redacted trace report and survival report.

Stop the test if suggestions feel distracting, appear in the wrong app, or
insert text somewhere surprising.

For rollback, removal, or a clean reset, use `UNINSTALL-DELETE-DATA.md`.
EOF

  local expected_model_path
  expected_model_path="$(./script/check_model_asset.py --print-path)"

  print_model_asset_template "$expected_model_path" >"$MODEL_ASSET_PATH"

  print_feedback_template >"$FEEDBACK_PATH"
  print_session_report_template >"$SESSION_REPORT_PATH"
  print_daily_checklist_template >"$DAILY_CHECKLIST_PATH"
  print_redacted_export_template >"$REDACTED_EXPORT_PATH"
  print_feedback_triage_template >"$FEEDBACK_TRIAGE_PATH"
  print_stop_dashboard_template >"$STOP_DASHBOARD_PATH"
  write_issue_template_validation

  cp PRIVACY-BETA.md "$TESTER_DOCS_DIR/PRIVACY-BETA.md"
  cp FIRST-RUN-BETA.md "$TESTER_DOCS_DIR/FIRST-RUN-BETA.md"
  cp KNOWN-LIMITATIONS.md "$TESTER_DOCS_DIR/KNOWN-LIMITATIONS.md"
  cp UNINSTALL-DELETE-DATA.md "$TESTER_DOCS_DIR/UNINSTALL-DELETE-DATA.md"
  cp DIAGNOSTIC-EXPORT.md "$TESTER_DOCS_DIR/DIAGNOSTIC-EXPORT.md"
  cp RELEASE-NOTES.md "$TESTER_DOCS_DIR/RELEASE-NOTES.md"
  cp docs/product/private-beta-ops-loop.md "$TESTER_DOCS_DIR/private-beta-ops-loop.md"
  cp .github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml "$TESTER_DOCS_DIR/autocomplete-beta-feedback.yml"
  cp .github/labels.yml "$TESTER_DOCS_DIR/labels.yml"

  cat >"$PRIVACY_STATUS_PATH" <<'EOF'
# Privacy Status

Default beta feedback is redacted and local.

Allowed by default:

- `privacy-export/PRIVACY-CHECKLIST.md`
- `privacy-export/manifest.json`
- `privacy-export/redacted-traces.jsonl`
- `privacy-export/survival-report.json`
- `privacy-export/trace-report.html`
- `privacy-export/visual-calibration-report.txt`

Not requested by default:

- raw traces,
- screenshots,
- typed text,
- prompts,
- model output,
- accepted text,
- document names,
- URLs,
- recipients,
- subject lines.

Use raw text or screenshots only for an explicit debug session, and write that
consent in the session notes before collecting them.
EOF

  printf 'SteadyType.dmg  %s\n' "$sha" >"$CHECKSUM_PATH"
  if [[ -n "$zip_sha" ]]; then
    printf 'SteadyType.zip  %s\n' "$zip_sha" >>"$CHECKSUM_PATH"
  fi
  write_readiness_summary "$sha"
  echo "Private beta packet created: $PACKET_DIR"
}

check_packet() {
  require_primary_artifact
  check_primary_artifact_app
  check_secondary_archive_app
  ./script/validate_beta_issue_template.sh --quiet

  ./script/check_model_asset.py --quiet || {
    echo "preferred MLX model is missing or invalid" >&2
    echo "Run ./script/check_model_asset.py for the exact fix." >&2
    exit 1
  }
  check_archive_privacy_export

  local regeneration_reason
  if regeneration_reason="$(packet_regeneration_reason)"; then
    printf '%s\n' "$regeneration_reason" >&2
    echo "Regenerating private beta packet from current artifacts..." >&2
    create_packet
  fi

  if regeneration_reason="$(packet_regeneration_reason)"; then
    printf '%s\n' "$regeneration_reason" >&2
    exit 1
  fi

  local expected_commit actual_commit
  expected_commit="$(current_commit)"
  actual_commit="$(awk -F': ' '/^Commit:/ {print $2; exit}' "$READINESS_SUMMARY_PATH")"
  if [[ "$expected_commit" != "$actual_commit" ]]; then
    echo "beta packet commit is stale" >&2
    echo "expected: $expected_commit" >&2
    echo "actual:   ${actual_commit:-missing}" >&2
    echo "Regenerate with ./script/private_beta_packet.sh create" >&2
    exit 1
  fi

  require_same_file "PRIVACY-BETA.md" "$TESTER_DOCS_DIR/PRIVACY-BETA.md"
  require_same_file "FIRST-RUN-BETA.md" "$TESTER_DOCS_DIR/FIRST-RUN-BETA.md"
  require_same_file "KNOWN-LIMITATIONS.md" "$TESTER_DOCS_DIR/KNOWN-LIMITATIONS.md"
  require_same_file "UNINSTALL-DELETE-DATA.md" "$TESTER_DOCS_DIR/UNINSTALL-DELETE-DATA.md"
  require_same_file "DIAGNOSTIC-EXPORT.md" "$TESTER_DOCS_DIR/DIAGNOSTIC-EXPORT.md"
  require_same_file "RELEASE-NOTES.md" "$TESTER_DOCS_DIR/RELEASE-NOTES.md"
  require_same_file "docs/product/private-beta-ops-loop.md" "$TESTER_DOCS_DIR/private-beta-ops-loop.md"
  require_same_file ".github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml" "$TESTER_DOCS_DIR/autocomplete-beta-feedback.yml"
  require_same_file ".github/labels.yml" "$TESTER_DOCS_DIR/labels.yml"
  require_generated_file "$FEEDBACK_PATH" ./script/private_beta_packet.sh --print-feedback-template
  require_generated_file "$SESSION_REPORT_PATH" ./script/private_beta_packet.sh --print-session-report-template
  require_generated_file "$DAILY_CHECKLIST_PATH" ./script/private_beta_packet.sh --print-daily-checklist-template
  require_generated_file "$REDACTED_EXPORT_PATH" ./script/private_beta_packet.sh --print-redacted-export-template
  require_generated_file "$FEEDBACK_TRIAGE_PATH" ./script/private_beta_packet.sh --print-feedback-triage-template
  require_generated_file "$STOP_DASHBOARD_PATH" ./script/private_beta_packet.sh --print-stop-dashboard-template
  require_generated_file "$MODEL_ASSET_PATH" ./script/private_beta_packet.sh --print-model-asset-template "$(./script/check_model_asset.py --print-path)"

  echo "Private beta packet verified: $PACKET_DIR"
}

case "$MODE" in
  -h|--help|help)
    usage
    ;;
  create)
    create_packet
    ;;
  --check|check)
    check_packet
    ;;
  --print-feedback-template)
    print_feedback_template
    ;;
  --print-session-report-template)
    print_session_report_template
    ;;
  --print-daily-checklist-template)
    print_daily_checklist_template
    ;;
  --print-redacted-export-template)
    print_redacted_export_template
    ;;
  --print-feedback-triage-template)
    print_feedback_triage_template
    ;;
  --print-stop-dashboard-template)
    print_stop_dashboard_template
    ;;
  --print-model-asset-template)
    print_model_asset_template "${2:-}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
