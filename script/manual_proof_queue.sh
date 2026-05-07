#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="print"

usage() {
  cat <<'EOF'
Usage: script/manual_proof_queue.sh [--print|--dry-run|--run]

Prints or runs the remaining manual-gated beta proof queue.

--print    Show the exact commands and safety rules. This is the default.
--dry-run  Show each command that --run would invoke.
--run      Run each manual-gated recorder in sequence. The child recorders
           print the safe steps and wait for you to press Enter before they
           validate. This script never types into Notes, Obsidian, Codex,
           Claude desktop, or Claude Code by itself.
EOF
}

while (($#)); do
  case "$1" in
    --print)
      MODE="print"
      ;;
    --dry-run)
      MODE="dry-run"
      ;;
    --run)
      MODE="run"
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

declare -a QUEUE=(
  "Notes title|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate"
  "Notes body|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate"
  "Notes checklist|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate"
  "Obsidian disposable note|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate"
  "Codex one-word no-submit|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
  "Claude Code one-word no-submit|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate"
  "Claude desktop one-word no-submit|AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate"
)

print_header() {
  cat <<'EOF'
Manual beta proof queue

Hard rules:
- Use only disposable notes, disposable vault files, and harmless prompt text.
- Do not press Enter in Codex, Claude desktop, or Claude Code.
- Do not use private notes, real vault content, customer text, messages, or real work.
- Leave prompt-app full accept disabled until separate full-accept no-submit proof exists.

Before inviting testers, this queue must be followed by:

```bash
./script/manual_smoke_status.sh --strict
./script/beta_readiness.sh --check-only
```

EOF
}

print_queue() {
  print_header
  local item label command
  for item in "${QUEUE[@]}"; do
    label="${item%%|*}"
    command="${item#*|}"
    printf '# %s\n%s\n\n' "$label" "$command"
  done
}

if [[ "$MODE" == "print" ]]; then
  print_queue
  exit 0
fi

if [[ "$MODE" == "dry-run" ]]; then
  local_index=1
  for item in "${QUEUE[@]}"; do
    label="${item%%|*}"
    command="${item#*|}"
    printf 'would run %d/%d: %s\n%s\n' "$local_index" "${#QUEUE[@]}" "$label" "$command"
    local_index=$((local_index + 1))
  done
  exit 0
fi

print_header

index=1
for item in "${QUEUE[@]}"; do
  label="${item%%|*}"
  command="${item#*|}"
  printf '\n== %d/%d: %s ==\n' "$index" "${#QUEUE[@]}" "$label"
  printf '%s\n\n' "$command"
  env AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 bash -c "$command"
  index=$((index + 1))
done

echo
./script/manual_smoke_status.sh --strict
