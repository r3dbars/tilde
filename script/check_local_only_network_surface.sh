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

NETWORK_PATTERN='URLSession|NSURLConnection|NWConnection|NWListener|HubApi|HubClient|snapshot\(|downloadSnapshot\(|https?://'
failures=()
matches=()

allow_reference() {
  local path="$1"
  local line="$2"

  case "$path" in
	    Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift)
	      return 0
	      ;;
	    Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift)
	      [[ "$line" == *"HubClient"* || "$line" == *"downloadSnapshot"* ]]
	      return
	      ;;
	    Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift)
	      [[ "$line" == *"MLXHuggingFace"* ]]
	      return
	      ;;
	    Sources/AutocompleteLabApp/UI/BetaFeedbackLink.swift)
	      [[ "$line" == *"https://github.com/r3dbars/transcripted-autocomplete-lab/issues/new"* ]]
	      return
	      ;;
	    Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift)
	      [[ "$line" == *"https://private.example/redbars"* ]]
	      return
	      ;;
	    Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift)
	      [[ "$line" == *"licenseURL"* || "$line" == *"https://huggingface.co/"* ]]
	      return
      ;;
	    Sources/AutocompleteLabCore/Runtime/RuntimeCancellationCoordinator.swift)
	      [[ "$line" == *"func snapshot() -> Int"* ]]
	      return
      ;;
	    Sources/AutocompleteLabCore/Experiments/EvalV2BlindCorpus.swift)
	      [[ "$line" =~ ^[[:space:]]*url:[[:space:]]\"https://www\.gutenberg\.org/ebooks/[0-9]+\",?[[:space:]]*$ \
	        || "$line" =~ ^[[:space:]]*url:[[:space:]]\"https://www\.archives\.gov/founding-docs/constitution-transcript\",?[[:space:]]*$ \
	        || "$line" =~ ^[[:space:]]*url:[[:space:]]\"https://www\.archives\.gov/milestone-documents/gettysburg-address\",?[[:space:]]*$ \
	        || "$line" =~ ^[[:space:]]*if[[:space:]]+!source\.url\.hasPrefix\(\"https://\"\)[[:space:]]*\{[[:space:]]*$ ]]
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
echo "- Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift: synthetic URL sentinel for redaction proof only"
echo "- Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift: explicit user-triggered model install"
echo "- Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift: explicit user-triggered pinned model install"
echo "- Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift: MLX local model import"
echo "- Sources/AutocompleteLabApp/UI/BetaFeedbackLink.swift: hard-coded GitHub feedback issue URL"
echo "- Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift: model license URLs only"
echo "- Sources/AutocompleteLabCore/Experiments/EvalV2BlindCorpus.swift: offline public-domain source citation URLs only"
