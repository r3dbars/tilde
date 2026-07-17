#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT_DIR}/script/check_agent_guide_contract.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

AUTOCOMPLETE_LAB_REPO_ROOT="$ROOT_DIR" "$CHECK" >/dev/null

mkdir -p "$TMP_DIR/docs/research"
cp "$ROOT_DIR/docs/AGENTS.md" "$TMP_DIR/docs/AGENTS.md"
cp "$ROOT_DIR/docs/CLAUDE.md" "$TMP_DIR/docs/CLAUDE.md"
touch "$TMP_DIR/docs/research/AGENTS.md"

if AUTOCOMPLETE_LAB_REPO_ROOT="$TMP_DIR" "$CHECK" >"$TMP_DIR/fail.out" 2>&1; then
  echo "agent guide contract self-test: reintroduced guide unexpectedly passed" >&2
  exit 1
fi

grep -Fq "redundant research guide was reintroduced" "$TMP_DIR/fail.out" \
  || { echo "agent guide contract self-test: failure did not identify the reintroduced guide" >&2; exit 1; }

echo "agent guide contract self-test: PASS"
