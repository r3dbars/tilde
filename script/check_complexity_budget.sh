#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TOTAL_SWIFT_LOC_MAX=90000
APP_DELEGATE_LOC_MAX=17244
OTHER_SWIFT_FILE_LOC_MAX=3000
SCRIPT_FILE_COUNT_MAX=35
DOC_FILE_COUNT_MAX=30
APP_DELEGATE_PATH="Sources/AutocompleteLabApp/App/AppDelegate.swift"

STRUCTURAL=0
STRUCTURAL_EXCEPTION=0
DIFF_BASE="origin/main"

usage() {
  cat <<'EOF'
Usage: script/check_complexity_budget.sh [options]

Report production Swift LOC, AppDelegate LOC, the largest production files,
script count, and docs count. Stable high-water ceilings are blocking.

Options:
  --structural             Require the production Swift diff to be net-negative.
  --base <ref>             Diff base for --structural (default: origin/main).
  --structural-exception   Allow a non-negative structural diff only when the
                           pull request description explains the justification.
  -h, --help               Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --structural)
      STRUCTURAL=1
      shift
      ;;
    --base)
      if [ "$#" -lt 2 ]; then
        echo "complexity budget: --base requires a ref" >&2
        exit 2
      fi
      DIFF_BASE="$2"
      shift 2
      ;;
    --structural-exception)
      STRUCTURAL_EXCEPTION=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "complexity budget: unknown option '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$STRUCTURAL_EXCEPTION" -eq 1 ] && [ "$STRUCTURAL" -ne 1 ]; then
  echo "complexity budget: --structural-exception requires --structural" >&2
  exit 2
fi

SWIFT_COUNTS="$(mktemp "${TMPDIR:-/tmp}/steadytype-swift-counts.XXXXXX")"
trap 'rm -f "$SWIFT_COUNTS"' EXIT

total_swift_loc=0
while IFS= read -r file; do
  loc="$(wc -l < "$file" | tr -d '[:space:]')"
  total_swift_loc=$((total_swift_loc + loc))
  printf '%s\t%s\n' "$loc" "$file" >> "$SWIFT_COUNTS"
done < <(find Sources -type f -name '*.swift' -print | LC_ALL=C sort)

if [ -f "$APP_DELEGATE_PATH" ]; then
  app_delegate_loc="$(wc -l < "$APP_DELEGATE_PATH" | tr -d '[:space:]')"
else
  app_delegate_loc=0
fi

count_files() {
  local directory="$1"
  local max_depth="${2:-}"
  if [ ! -d "$directory" ]; then
    echo 0
    return
  fi
  if [ -n "$max_depth" ]; then
    find "$directory" -maxdepth "$max_depth" -type f -print | wc -l | tr -d '[:space:]'
  else
    find "$directory" -type f -print | wc -l | tr -d '[:space:]'
  fi
}

script_count="$(count_files script 1)"
docs_count="$(count_files docs)"

echo "SteadyType complexity budget"
printf '  production Swift LOC: %d / %d\n' "$total_swift_loc" "$TOTAL_SWIFT_LOC_MAX"
printf '  AppDelegate LOC:      %d / %d\n' "$app_delegate_loc" "$APP_DELEGATE_LOC_MAX"
printf '  scripts:              %d / %d\n' "$script_count" "$SCRIPT_FILE_COUNT_MAX"
printf '  docs files:           %d / %d\n' "$docs_count" "$DOC_FILE_COUNT_MAX"
printf '  largest production Swift files (top 5; non-AppDelegate ceiling %d):\n' "$OTHER_SWIFT_FILE_LOC_MAX"
LC_ALL=C sort -t $'\t' -k1,1nr -k2,2 "$SWIFT_COUNTS" | sed -n '1,5p' | while IFS=$'\t' read -r loc file; do
  printf '    %6d  %s\n' "$loc" "$file"
done

failures=()
if [ "$total_swift_loc" -gt "$TOTAL_SWIFT_LOC_MAX" ]; then
  failures+=("production Swift LOC exceeds $TOTAL_SWIFT_LOC_MAX")
fi
if [ "$app_delegate_loc" -gt "$APP_DELEGATE_LOC_MAX" ]; then
  failures+=("AppDelegate.swift exceeds $APP_DELEGATE_LOC_MAX LOC")
fi
while IFS=$'\t' read -r loc file; do
  if [ "$file" != "$APP_DELEGATE_PATH" ] && [ "$loc" -gt "$OTHER_SWIFT_FILE_LOC_MAX" ]; then
    failures+=("$file exceeds the non-AppDelegate ceiling of $OTHER_SWIFT_FILE_LOC_MAX LOC")
  fi
done < "$SWIFT_COUNTS"
if [ "$script_count" -gt "$SCRIPT_FILE_COUNT_MAX" ]; then
  failures+=("script count exceeds $SCRIPT_FILE_COUNT_MAX")
fi
if [ "$docs_count" -gt "$DOC_FILE_COUNT_MAX" ]; then
  failures+=("docs count exceeds $DOC_FILE_COUNT_MAX")
fi

if [ "$STRUCTURAL" -eq 1 ]; then
  if ! git rev-parse --verify --quiet "${DIFF_BASE}^{commit}" >/dev/null; then
    echo "complexity budget: diff base '$DIFF_BASE' is not a commit" >&2
    exit 2
  fi
  read -r added deleted < <(
    git diff --numstat "${DIFF_BASE}...HEAD" -- ':(glob)Sources/**/*.swift' |
      awk '{ added += $1; deleted += $2 } END { printf "%d %d\n", added, deleted }'
  )
  net=$((added - deleted))
  printf '  structural production Swift delta (%s...HEAD): +%d -%d net %+d\n' \
    "$DIFF_BASE" "$added" "$deleted" "$net"
  if [ "$net" -ge 0 ]; then
    if [ "$STRUCTURAL_EXCEPTION" -eq 1 ]; then
      echo "  structural LOC exception acknowledged; the PR description must explain the justification"
    else
      failures+=("structural/refactor production Swift LOC must be net-negative (or use --structural-exception with a PR-description justification)")
    fi
  fi
fi

if [ "${#failures[@]}" -gt 0 ]; then
  echo
  for failure in "${failures[@]}"; do
    echo "[FAIL] $failure" >&2
  done
  exit 1
fi

echo "[PASS] complexity budget"
