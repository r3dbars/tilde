#!/usr/bin/env bash
set -euo pipefail

# Fast, local high-water report. Structural/refactor PRs opt into the stricter
# diff rule with PROOF_STRUCTURAL_CHANGE=1; an exception is valid only when the
# PR description explains it and PROOF_STRUCTURAL_LOC_EXCEPTION=1 is set.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TOTAL_MAX=90000
APP_DELEGATE_MAX=17244
OTHER_FILE_MAX=3000
SCRIPTS_MAX=35
DOCS_MAX=30
APP_DELEGATE="Sources/AutocompleteLabApp/App/AppDelegate.swift"
COUNTS="$(mktemp "${TMPDIR:-/tmp}/steadytype-complexity.XXXXXX")"
trap 'rm -f "$COUNTS"' EXIT

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

total=0
while IFS= read -r file; do
  lines="$(wc -l < "$file" | tr -d '[:space:]')"
  total=$((total + lines))
  printf '%s\t%s\n' "$lines" "$file" >> "$COUNTS"
done < <(find Sources -type f -name '*.swift' -print | LC_ALL=C sort)

app_delegate_lines=0
[ ! -f "$APP_DELEGATE" ] || app_delegate_lines="$(wc -l < "$APP_DELEGATE" | tr -d '[:space:]')"
scripts="$(find script -maxdepth 1 -type f -print | awk 'END { print NR + 0 }')"
docs="$(find docs -type f -print | awk 'END { print NR + 0 }')"

echo "SteadyType complexity budget"
printf '  production Swift LOC: %d / %d\n' "$total" "$TOTAL_MAX"
printf '  AppDelegate LOC:      %d / %d\n' "$app_delegate_lines" "$APP_DELEGATE_MAX"
printf '  scripts:              %d / %d\n' "$scripts" "$SCRIPTS_MAX"
printf '  docs files:           %d / %d\n' "$docs" "$DOCS_MAX"
printf '  largest production Swift files (top 5; non-AppDelegate ceiling %d):\n' "$OTHER_FILE_MAX"
LC_ALL=C sort -t $'\t' -k1,1nr -k2,2 "$COUNTS" | sed -n '1,5p' | while IFS=$'\t' read -r lines file; do
  printf '    %6d  %s\n' "$lines" "$file"
done

failed=0
check_max() {
  if [ "$2" -gt "$3" ]; then
    echo "[FAIL] $1 exceeds $3" >&2
    failed=1
  fi
}

check_max "production Swift LOC" "$total" "$TOTAL_MAX"
check_max "AppDelegate.swift LOC" "$app_delegate_lines" "$APP_DELEGATE_MAX"
while IFS=$'\t' read -r lines file; do
  if [ "$file" != "$APP_DELEGATE" ] && [ "$lines" -gt "$OTHER_FILE_MAX" ]; then
    echo "[FAIL] $file exceeds $OTHER_FILE_MAX LOC" >&2
    failed=1
  fi
done < "$COUNTS"
check_max "script count" "$scripts" "$SCRIPTS_MAX"
check_max "docs count" "$docs" "$DOCS_MAX"

if is_truthy "${PROOF_STRUCTURAL_CHANGE:-}"; then
  base="${PROOF_DIFF_BASE:-origin/main}"
  if ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
    echo "[FAIL] structural diff base '$base' is not a commit" >&2
    exit 2
  fi
  read -r added deleted < <(
    git diff --numstat "${base}...HEAD" -- ':(glob)Sources/**/*.swift' |
      awk '{ added += $1; deleted += $2 } END { printf "%d %d\n", added, deleted }'
  )
  net=$((added - deleted))
  printf '  structural production Swift delta (%s...HEAD): +%d -%d net %+d\n' "$base" "$added" "$deleted" "$net"
  if [ "$net" -ge 0 ]; then
    if is_truthy "${PROOF_STRUCTURAL_LOC_EXCEPTION:-}"; then
      echo "  structural LOC exception acknowledged; the PR description must explain the justification"
    else
      echo "[FAIL] structural/refactor production Swift LOC must be net-negative" >&2
      failed=1
    fi
  fi
fi

[ "$failed" -eq 0 ] || exit 1
echo "[PASS] complexity budget"
