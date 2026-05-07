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
MODEL_ASSET_PATH="$PACKET_DIR/model-asset.md"
CHECKSUM_PATH="$PACKET_DIR/checksums.txt"

cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: script/private_beta_packet.sh [create|--check]

create   Create a local private-beta packet beside dist/AutocompleteLab.zip.
--check  Validate that the packet exists and points at the current archive.

This script only writes local files. It never uploads or sends beta data.
By default it requires the archive to contain a Developer ID signed app. Set
AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_RELEASE_SIGNATURE=0 only for local script tests.
EOF
}

archive_sha() {
  shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}'
}

require_archive() {
  if [[ ! -s "$ARCHIVE_PATH" ]]; then
    echo "missing archive: $ARCHIVE_PATH" >&2
    echo "Run ./script/beta_readiness.sh first." >&2
    exit 1
  fi
}

check_archive_app() {
  local verify_dir app_path
  verify_dir="$(mktemp -d)"

  ditto -x -k "$ARCHIVE_PATH" "$verify_dir"
  app_path="$verify_dir/AutocompleteLab.app"

  if [[ ! -d "$app_path" ]]; then
    rm -rf "$verify_dir"
    echo "archive does not contain AutocompleteLab.app" >&2
    exit 1
  fi

  if [[ "${AUTOCOMPLETE_LAB_PRIVATE_BETA_REQUIRE_RELEASE_SIGNATURE:-1}" == "1" ]]; then
    ./script/check_app_bundle.sh --release "$app_path"
  else
    ./script/check_app_bundle.sh "$app_path"
  fi

  rm -rf "$verify_dir"
}

create_packet() {
  require_archive
  ./script/check_model_asset.py
  check_archive_app
  mkdir -p "$PACKET_DIR"

  local sha
  sha="$(archive_sha)"

  cat >"$README_PATH" <<EOF
# Autocomplete Lab Private Beta Packet

Archive: ../AutocompleteLab.zip
SHA-256: $sha

This is a local-only packet for a tiny private beta. Nothing here uploads
traces, screenshots, prompts, or typed text anywhere.

Start with TextEdit. Then try Notes. Then try Obsidian. Chrome textarea is a
sanity check, not the main product loop.

Useful commands:

\`\`\`bash
./script/check_model_asset.py
./script/beta_readiness.sh
./script/manual_smoke_status.sh --require-all
./script/check_trace_eval.sh
./script/model_latency_report.py --default-model-proof
open "\$HOME/Library/Logs/AutocompleteLab"
\`\`\`
EOF

  cat >"$INSTALL_PATH" <<'EOF'
# Install Checklist

1. Unzip `AutocompleteLab.zip`.
2. Open `AutocompleteLab.app`.
3. Grant Accessibility when macOS asks.
4. Open Settings from the menu bar item.
5. If the local model is missing, click `Install Local Model`.
6. If Settings says the model folder needs repair, click `Repair Local Model`.
7. Wait for Settings to show the model is ready.
8. Open TextEdit and type a normal sentence.
9. Use Tab for one-word accept.
10. Use the key above Tab for full accept only in non-prompt apps where the profile allows it.
11. Press Esc if a suggestion feels wrong.

Stop the test if suggestions feel distracting, appear in the wrong app, or
insert text somewhere surprising.
EOF

  local expected_model_path
  expected_model_path="$(./script/check_model_asset.py --print-path)"

  cat >"$MODEL_ASSET_PATH" <<EOF
# Model Asset Check

The private beta is not ready if the app falls back to mock output.

Expected model:

\`\`\`text
$expected_model_path
\`\`\`

Verify it:

\`\`\`bash
./script/check_model_asset.py
\`\`\`

Fix a missing or invalid model:

Open Autocomplete Lab Settings and use the Local model action. Developer fallback:

\`\`\`bash
python3 -m pip install --user huggingface_hub
./script/download_mlx_model.py --model qwen35-4b
./script/check_model_asset.py
\`\`\`
EOF

  cat >"$FEEDBACK_PATH" <<'EOF'
# Feedback Log

Use one short row per real writing session.

| Date | Tester | App | Minutes | Helped? | Annoyed? | Broke trust? | Notes |
| --- | --- | --- | ---: | --- | --- | --- | --- |
|  |  | TextEdit / Notes / Obsidian / Chrome |  | yes/no | yes/no | yes/no |  |

Questions to answer after each session:

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
./script/model_latency_report.py --default-model-proof
```

## Notes

- Record the app, minutes, and whether Tab felt predictable.
- Copy the top repeated misses from Diagnostics or the trace eval report.
- If the latency report has no samples, type one short sentence, wait for a phrase suggestion, and rerun it.
- Fix the top repeated miss before inviting more testers.
EOF

  printf 'AutocompleteLab.zip  %s\n' "$sha" >"$CHECKSUM_PATH"
  echo "Private beta packet created: $PACKET_DIR"
}

check_packet() {
  require_archive
  check_archive_app

  ./script/check_model_asset.py --quiet || {
    echo "preferred MLX model is missing or invalid" >&2
    echo "Run ./script/check_model_asset.py for the exact fix." >&2
    exit 1
  }

  for path in "$README_PATH" "$INSTALL_PATH" "$MODEL_ASSET_PATH" "$FEEDBACK_PATH" "$SESSION_REPORT_PATH" "$CHECKSUM_PATH"; do
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
