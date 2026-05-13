#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_SCRATCH_PATH="${AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build}"
TARGET="$SWIFT_SCRATCH_PATH/checkouts/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift"
PATCH_FILE="$ROOT_DIR/patches/mlx-swift-lm/gemma4-optiq-scaled-linear.patch"

if [[ ! -f "$TARGET" ]]; then
  echo "missing mlx-swift-lm checkout: $TARGET" >&2
  echo "Run swift package resolve with AUTOCOMPLETE_LAB_SWIFT_SCRATCH_PATH=$SWIFT_SCRATCH_PATH, then rerun this script." >&2
  exit 1
fi

if grep -F '@ModuleInfo(key: "scales") var scales: MLXArray?' "$TARGET" >/dev/null; then
  exit 0
fi

chmod u+w "$TARGET"
patch -d "$SWIFT_SCRATCH_PATH" -p0 <"$PATCH_FILE"
echo "Applied Gemma OptiQ mlx-swift-lm patch."
