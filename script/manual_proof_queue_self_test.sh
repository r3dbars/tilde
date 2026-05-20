#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/manual_proof_queue.sh --print >"$TMP_DIR/print.txt"
script/manual_proof_queue.sh --dry-run >"$TMP_DIR/dry-run.txt"
script/manual_proof_queue.sh --help >"$TMP_DIR/help.txt"

for expected in \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-theme --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-pane --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-long-note --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-font-zoom --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-markdown-bold --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-markdown-list --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-multiline --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian-run-on --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host terminal --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host iterm2 --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host ghostty --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-empty --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-long --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-wrapped --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-narrow --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-context --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-light --manual-gate" \
  "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-dark --manual-gate"; do
  if ! grep -F "$expected" "$TMP_DIR/print.txt" >/dev/null; then
    echo "manual proof queue print output missed: $expected" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$TMP_DIR/dry-run.txt" >/dev/null; then
    echo "manual proof queue dry-run output missed: $expected" >&2
    exit 1
  fi
done

if ! grep -F "Do not press Enter in Codex, Claude desktop, or Claude Code." "$TMP_DIR/print.txt" >/dev/null; then
  echo "manual proof queue must include prompt no-submit safety copy" >&2
  exit 1
fi

if ! grep -F "Build and verify this checkout's app once" "$TMP_DIR/help.txt" >/dev/null; then
  echo "manual proof queue help must describe the single verified build behavior" >&2
  exit 1
fi

if script/manual_proof_queue.sh --unknown >/dev/null 2>&1; then
  echo "manual proof queue should reject unknown options" >&2
  exit 1
fi

echo "Manual proof queue self-test passed."
