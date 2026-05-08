#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/.build/checkouts/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift"
PATCH_FILE="$ROOT_DIR/patches/mlx-swift-lm/gemma4-optiq-scaled-linear.patch"

if [[ ! -f "$TARGET" ]]; then
  echo "missing mlx-swift-lm checkout: $TARGET" >&2
  echo "Run swift package resolve, then rerun this script." >&2
  exit 1
fi

if grep -F '@ModuleInfo(key: "scales") var scales: MLXArray?' "$TARGET" >/dev/null; then
  exit 0
fi

chmod u+w "$TARGET"
patch -d "$ROOT_DIR" -p0 <"$PATCH_FILE"
echo "Applied Gemma OptiQ mlx-swift-lm patch."
