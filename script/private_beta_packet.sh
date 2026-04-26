#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-create}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$DIST_DIR/AutocompleteLab.zip"
PACKET_DIR="$DIST_DIR/private-beta"
README_PATH="$PACKET_DIR/README.md"
INSTALL_PATH="$PACKET_DIR/install-checklist.md"
FEEDBACK_PATH="$PACKET_DIR/feedback-log.md"
CHECKSUM_PATH="$PACKET_DIR/checksums.txt"

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
./script/beta_readiness.sh
./script/manual_smoke_status.sh --require-all
open "\$HOME/Library/Logs/AutocompleteLab"
\`\`\`
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

  printf 'AutocompleteLab.zip  %s\n' "$sha" >"$CHECKSUM_PATH"
  echo "Private beta packet created: $PACKET_DIR"
}

check_packet() {
  require_archive

  for path in "$README_PATH" "$INSTALL_PATH" "$FEEDBACK_PATH" "$CHECKSUM_PATH"; do
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
