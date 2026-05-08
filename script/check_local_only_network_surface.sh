#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--root" ]]; then
  ROOT_DIR="$2"
fi

cd "$ROOT_DIR"

SOURCE_DIRS=(
  "Sources/AutocompleteLabApp"
  "Sources/AutocompleteLabCore"
)

NETWORK_PATTERN='URLSession|NSURLConnection|NWConnection|NWListener|HubApi|snapshot\(|https?://'
failures=()
matches=()

allow_reference() {
  local path="$1"
  local line="$2"

  case "$path" in
    Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift)
      return 0
      ;;
    Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift)
      [[ "$line" == *"MLXHuggingFace"* ]]
      return
      ;;
    Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift)
      [[ "$line" == *"licenseURL"* || "$line" == *"https://huggingface.co/"* ]]
      return
      ;;
  esac

  return 1
}

for source_dir in "${SOURCE_DIRS[@]}"; do
  [[ -d "$source_dir" ]] || continue
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    path="${hit%%:*}"
    rest="${hit#*:}"
    line_number="${rest%%:*}"
    line="${rest#*:}"
    matches+=("$path:$line_number")
    if ! allow_reference "$path" "$line"; then
      failures+=("$path:$line_number: $line")
    fi
  done < <(grep -RInE "$NETWORK_PATTERN" "$source_dir" || true)
done

if ((${#failures[@]} > 0)); then
  echo "local-only network surface check failed:" >&2
  printf -- "- %s\n" "${failures[@]}" >&2
  exit 1
fi

echo "Local-only network surface verified."
echo "Allowed network-adjacent source references: ${#matches[@]}"
echo "- Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift: explicit user-triggered model install"
echo "- Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift: MLX local model import"
echo "- Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift: model license URLs only"
