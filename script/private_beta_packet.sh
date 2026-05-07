#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-create}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${AUTOCOMPLETE_LAB_DIST_DIR:-$ROOT_DIR/dist}"
ARCHIVE_PATH="$DIST_DIR/AutocompleteLab.zip"
PACKET_DIR="$DIST_DIR/private-beta"
README_PATH="$PACKET_DIR/README.md"
INSTALL_PATH="$PACKET_DIR/install-checklist.md"
FEEDBACK_PATH="$PACKET_DIR/feedback-log.md"
SESSION_REPORT_PATH="$PACKET_DIR/session-report.md"
CHECKSUM_PATH="$PACKET_DIR/checksums.txt"
BETA_REPORT_PATH="$PACKET_DIR/beta-readiness-report.md"
STOP_CONDITIONS_PATH="$PACKET_DIR/stop-conditions.md"
ROLLBACK_PATH="$PACKET_DIR/rollback.md"
APP_PLIST="$DIST_DIR/AutocompleteLab.app/Contents/Info.plist"

cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: script/private_beta_packet.sh [create|--check]

create   Create a local private-beta packet beside dist/AutocompleteLab.zip.
--check  Validate that the packet exists and points at the current archive.

This script only writes local files. It never uploads or sends beta data.
EOF
}

archive_sha() {
  shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}'
}

archive_size() {
  du -h "$ARCHIVE_PATH" | awk '{print $1}'
}

git_commit() {
  git rev-parse --short=12 HEAD 2>/dev/null || echo "unknown"
}

app_version() {
  if [[ ! -f "$APP_PLIST" ]]; then
    echo "app bundle missing"
    return
  fi

  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PLIST" 2>/dev/null \
    || echo "unversioned"
}

bundle_version() {
  if [[ ! -f "$APP_PLIST" ]]; then
    echo "app bundle missing"
    return
  fi

  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST" 2>/dev/null \
    || echo "unversioned"
}

model_expected_path() {
  echo "$HOME/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit"
}

model_state() {
  local path
  path="$(model_expected_path)"

  if [[ ! -d "$path" ]]; then
    echo "missing expected Qwen3.5 4B app-owned model at $path"
    return
  fi

  local missing=()
  for required_file in config.json tokenizer.json tokenizer_config.json; do
    if [[ ! -f "$path/$required_file" ]]; then
      missing+=("$required_file")
    fi
  done

  if ! find "$path" -maxdepth 1 -name '*.safetensors' -type f -print -quit | grep -q .; then
    missing+=("*.safetensors")
  fi

  local size
  size="$(du -sh "$path" 2>/dev/null | awk '{print $1}')"

  if (( ${#missing[@]} > 0 )); then
    echo "needs repair at $path; missing ${missing[*]}"
    return
  fi

  echo "present at $path (${size:-unknown size})"
}

manual_smoke_state() {
  ./script/manual_smoke_status.sh 2>&1 || true
}

require_archive() {
  if [[ ! -s "$ARCHIVE_PATH" ]]; then
    echo "missing archive: $ARCHIVE_PATH" >&2
    echo "Run ./script/beta_readiness.sh first." >&2
    exit 1
  fi
}

create_packet() {
  require_archive
  mkdir -p "$PACKET_DIR"

  local sha
  sha="$(archive_sha)"
  local commit created_utc version build model proof archive_bytes
  commit="$(git_commit)"
  created_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  version="$(app_version)"
  build="$(bundle_version)"
  model="$(model_state)"
  proof="$(manual_smoke_state)"
  archive_bytes="$(archive_size)"

  cat >"$README_PATH" <<EOF
# Autocomplete Lab Private Beta Packet

Archive: ../AutocompleteLab.zip
SHA-256: $sha
Git commit: $commit
App version: $version ($build)

This is a local-only packet for a tiny private beta. Nothing here uploads
traces, screenshots, prompts, or typed text anywhere.

Start with TextEdit. Then try Notes. Then try Obsidian. Chrome textarea is a
sanity check, not the main product loop.

Do not beta-test in Mail, password managers, System Settings, Safari, Slack,
VS Code, Cursor, Atlas, or any field that looks private or sensitive. Those are
unsupported or diagnostics-only until there is separate proof.

Useful commands:

\`\`\`bash
./script/beta_readiness.sh
./script/manual_smoke_status.sh --require-all
./script/check_trace_eval.sh
./script/model_latency_report.py --latest
open "\$HOME/Library/Logs/AutocompleteLab"
\`\`\`

Packet files:

- \`beta-readiness-report.md\`
- \`install-checklist.md\`
- \`feedback-log.md\`
- \`session-report.md\`
- \`stop-conditions.md\`
- \`rollback.md\`
- \`checksums.txt\`
EOF

  cat >"$INSTALL_PATH" <<'EOF'
# Install Checklist

1. Unzip `AutocompleteLab.zip`.
2. Open `AutocompleteLab.app`.
3. Grant Accessibility when macOS asks.
4. Confirm the menu bar item says the model is ready.
5. Open TextEdit and type a normal sentence.
6. Use Tab for one-word accept.
7. Use the key above Tab for full accept.
8. Press Esc if a suggestion feels wrong.

Stop the test if suggestions feel distracting, appear in the wrong app, or
insert text somewhere surprising.
EOF

  cat >"$FEEDBACK_PATH" <<'EOF'
# Feedback Log

Use one short row per real writing session.

| Date | Tester | App | Minutes | Helped? | Interrupted? | Broke trust? | Wrong app? | Too slow? | Notes |
| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
|  |  | TextEdit / Notes / Obsidian / Chrome |  | yes/no | yes/no | yes/no | yes/no | yes/no |  |

Questions to answer after each session:

- Did it help you keep writing?
- Did it interrupt you?
- Did anything break trust?
- Did it ever appear in the wrong app?
- Did it feel too slow?
- Did Tab feel predictable?
- Did the suggestion appear in a sane place?
- Did it finish words you were already typing?
- Did it suggest weird repeated phrases?
- Did it ever insert text you did not expect?
EOF

  cat >"$SESSION_REPORT_PATH" <<'EOF'
# Session Report

Use this after each real beta writing session.

## Commands

```bash
./script/check_trace_eval.sh
./script/model_latency_report.py --latest
./script/model_latency_report.py --latest --require-shown-samples 5
```

## Notes

- Record the app, minutes, and whether Tab felt predictable.
- Copy the top repeated misses from Diagnostics or the trace eval report.
- If the latency report has no samples, type one short sentence, wait for a phrase suggestion, and rerun it.
- Fix the top repeated miss before inviting more testers.
EOF

  cat >"$BETA_REPORT_PATH" <<EOF
# Beta Readiness Report

Generated UTC: $created_utc
Git commit: \`$commit\`
App version: \`$version\`
Bundle version: \`$build\`
Archive: \`$ARCHIVE_PATH\`
Archive size: \`$archive_bytes\`
SHA-256: \`$sha\`

## Runtime

- Default model: Qwen3.5 4B
- Runtime ownership: app-owned MLX path
- Expected model path: \`$(model_expected_path)\`
- Model state: $model
- Separate model server required: no

## Smoke State

\`\`\`text
$proof
\`\`\`

The one-command beta gate is:

\`\`\`bash
./script/beta_readiness.sh
\`\`\`

That gate runs repository smoke tests, manual app proof, release packaging, and
private beta packet verification before printing "Beta readiness passed."
EOF

  cat >"$STOP_CONDITIONS_PATH" <<'EOF'
# Private Beta Stop Conditions

Stop the beta immediately if any item below happens once.

- Insertion happens in the wrong app.
- A suggestion appears in a sensitive field.
- Tab is captured without a visible suggestion.
- Model setup requires a separate server.
- The app falls back to mock runtime.
- The panel frequently detaches from the typing location.
- A tester cannot understand why suggestions are missing.

When a stop condition fires, quit the app, write one row in `feedback-log.md`,
run `./script/check_trace_eval.sh`, and fix that trust issue before inviting
another tester.
EOF

  cat >"$ROLLBACK_PATH" <<'EOF'
# Rollback

Use this when a beta build breaks trust or feels noisy.

1. Quit Autocomplete Lab from the menu bar.
2. Delete the beta `AutocompleteLab.app`.
3. Reinstall the last trusted `AutocompleteLab.zip`, if one exists.
4. Open System Settings > Privacy & Security > Accessibility and remove the old Autocomplete Lab entry if macOS keeps a stale permission row.
5. Keep `~/Library/Logs/AutocompleteLab` only if you still need local diagnostics for the failed beta.

Do not continue a beta session after rollback until the stop condition has a
specific fix and a fresh `./script/beta_readiness.sh` pass.
EOF

  printf 'AutocompleteLab.zip  %s\n' "$sha" >"$CHECKSUM_PATH"
  echo "Private beta packet created: $PACKET_DIR"
}

check_packet() {
  require_archive

  for path in \
    "$README_PATH" \
    "$INSTALL_PATH" \
    "$FEEDBACK_PATH" \
    "$SESSION_REPORT_PATH" \
    "$BETA_REPORT_PATH" \
    "$STOP_CONDITIONS_PATH" \
    "$ROLLBACK_PATH" \
    "$CHECKSUM_PATH"; do
    if [[ ! -s "$path" ]]; then
      echo "missing beta packet file: $path" >&2
      exit 1
    fi
  done

  local expected_sha actual_sha
  expected_sha="$(archive_sha)"
  actual_sha="$(awk '/AutocompleteLab.zip/ {print $2; exit}' "$CHECKSUM_PATH")"

  if [[ "$expected_sha" != "$actual_sha" ]]; then
    echo "beta packet checksum is stale" >&2
    echo "expected: $expected_sha" >&2
    echo "actual:   $actual_sha" >&2
    exit 1
  fi

  local expected_commit
  expected_commit="$(git_commit)"
  if ! grep -F "Git commit: \`$expected_commit\`" "$BETA_REPORT_PATH" >/dev/null; then
    echo "beta readiness report is stale for the current git commit" >&2
    echo "expected commit: $expected_commit" >&2
    exit 1
  fi

  if ! grep -F "SHA-256: \`$expected_sha\`" "$BETA_REPORT_PATH" >/dev/null; then
    echo "beta readiness report is stale for the current archive checksum" >&2
    echo "expected sha: $expected_sha" >&2
    exit 1
  fi

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
  *)
    usage >&2
    exit 2
    ;;
esac
