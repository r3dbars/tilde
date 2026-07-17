#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${AUTOCOMPLETE_LAB_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

fail() {
  echo "agent guide contract FAILED: $*" >&2
  exit 1
}

for guide in docs/research/AGENTS.md docs/research/CLAUDE.md; do
  [ ! -e "$guide" ] || fail "redundant research guide was reintroduced: $guide"
done

grep -Fq "Research notes cite public sources" docs/AGENTS.md \
  || fail "docs/AGENTS.md is missing the consolidated research boundary"
grep -Fq "Research notes cite public sources" docs/CLAUDE.md \
  || fail "docs/CLAUDE.md is missing the consolidated research boundary"

echo "agent guide contract: PASS"
