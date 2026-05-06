#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCORECARD_PATH="${AUTOCOMPLETE_LAB_SCORECARD:-docs/product/deep-dive-scorecard-2026-05-06.md}"
MIN_WIDTH="${AUTOCOMPLETE_LAB_VISUAL_EVIDENCE_MIN_WIDTH:-64}"
MIN_HEIGHT="${AUTOCOMPLETE_LAB_VISUAL_EVIDENCE_MIN_HEIGHT:-32}"
REQUIRE_ALL=0

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      cat <<'EOF'
Usage: script/check_visual_placement_evidence.sh [--require-all|--strict]

Verifies linked visual placement screenshots and reports scorecard rows that
still need screenshot-backed proof.

Use --require-all or --strict to fail when any visual placement row is still
pending screenshot proof.
EOF
      exit 0
      ;;
    --require-all | --strict)
      REQUIRE_ALL=1
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$SCORECARD_PATH" ]]; then
  echo "Visual placement evidence check failed: missing scorecard $SCORECARD_PATH" >&2
  exit 1
fi

SCORECARD_DIR="$(cd "$(dirname "$SCORECARD_PATH")" && pwd)"
VISUAL_DIR="$SCORECARD_DIR/visual-placement-screenshots"

declare -a links=()
while IFS= read -r link; do
  links+=("$link")
done < <(
  grep -Eo '\]\(visual-placement-screenshots/[^)]*[.]png\)' "$SCORECARD_PATH" |
    sed -E 's/^\]\((.*)\)$/\1/' |
    sort -u
)

if ((${#links[@]} == 0)); then
  echo "Visual placement evidence check failed: no visual-placement-screenshots links in $SCORECARD_PATH" >&2
  exit 1
fi

REFERENCED_PATHS="$(mktemp)"
trap 'rm -f "$REFERENCED_PATHS"' EXIT
failures=0
visual_rows=0
pending_visual_rows=0
png_link_regex='visual-placement-screenshots/[^)]*[.]png'
declare -a pending_visuals=()

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

for link in "${links[@]}"; do
  evidence_path="$SCORECARD_DIR/$link"
  printf '%s\n' "$evidence_path" >>"$REFERENCED_PATHS"

  if [[ ! -f "$evidence_path" ]]; then
    echo "Missing screenshot evidence: $link" >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ ! -s "$evidence_path" ]]; then
    echo "Empty screenshot evidence: $link" >&2
    failures=$((failures + 1))
    continue
  fi

  file_summary="$(file -b "$evidence_path")"
  if [[ "$file_summary" != PNG\ image\ data* ]]; then
    echo "Invalid screenshot evidence type: $link ($file_summary)" >&2
    failures=$((failures + 1))
    continue
  fi

  width="$(sips -g pixelWidth "$evidence_path" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')"
  height="$(sips -g pixelHeight "$evidence_path" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')"

  if [[ -z "$width" || -z "$height" ]]; then
    echo "Could not read screenshot dimensions: $link" >&2
    failures=$((failures + 1))
    continue
  fi

  if (( width < MIN_WIDTH || height < MIN_HEIGHT )); then
    echo "Screenshot evidence too small: $link (${width}x${height}, minimum ${MIN_WIDTH}x${MIN_HEIGHT})" >&2
    failures=$((failures + 1))
  fi
done

in_visual_table=0
while IFS= read -r line; do
  if [[ "$line" =~ ^##[[:space:]]+Visual[[:space:]] ]]; then
    in_visual_table=1
    continue
  fi

  if (( in_visual_table == 1 )) && [[ "$line" =~ ^##[[:space:]]+ ]]; then
    break
  fi

  (( in_visual_table == 1 )) || continue
  [[ "$line" == \|* ]] || continue
  [[ "$line" != *"| App or surface |"* ]] || continue
  [[ "$line" != *"| --- |"* ]] || continue

  IFS='|' read -r _ surface grade evidence good work _ <<<"$line"
  surface="$(trim "$surface")"
  evidence="$(trim "$evidence")"
  work="$(trim "$work")"

  [[ -n "$surface" ]] || continue
  visual_rows=$((visual_rows + 1))

  if [[ ! "$evidence" =~ $png_link_regex ]]; then
    pending_visual_rows=$((pending_visual_rows + 1))
    if [[ -n "$work" ]]; then
      pending_visuals+=("$surface: $evidence - next: $work")
    else
      pending_visuals+=("$surface: $evidence")
    fi
  fi
done <"$SCORECARD_PATH"

if (( pending_visual_rows > 0 )); then
  echo "Pending screenshot-backed visual proof:" >&2
  for pending in "${pending_visuals[@]}"; do
    echo "- $pending" >&2
  done

  if (( REQUIRE_ALL == 1 )); then
    failures=$((failures + pending_visual_rows))
  fi
elif (( visual_rows > 0 )); then
  echo "All visual placement audit rows are screenshot-backed."
fi

if [[ -d "$VISUAL_DIR" ]]; then
  while IFS= read -r screenshot_path; do
    if ! grep -Fx "$screenshot_path" "$REFERENCED_PATHS" >/dev/null; then
      echo "Unreferenced screenshot evidence: ${screenshot_path#$SCORECARD_DIR/}" >&2
      failures=$((failures + 1))
    fi
  done < <(find "$VISUAL_DIR" -maxdepth 1 -type f -name '*.png' | sort)
fi

if (( failures > 0 )); then
  echo "Visual placement evidence check failed with $failures issue(s)." >&2
  exit 1
fi

echo "Visual placement evidence verified: ${#links[@]} screenshot(s)."
