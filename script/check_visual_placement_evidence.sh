#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCORECARD_PATH="${AUTOCOMPLETE_LAB_SCORECARD:-docs/product/deep-dive-scorecard-2026-05-06.md}"
MIN_WIDTH="${AUTOCOMPLETE_LAB_VISUAL_EVIDENCE_MIN_WIDTH:-64}"
MIN_HEIGHT="${AUTOCOMPLETE_LAB_VISUAL_EVIDENCE_MIN_HEIGHT:-32}"

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
