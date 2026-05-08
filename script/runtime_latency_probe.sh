#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SAMPLES="${1:-5}"

./script/check_model_asset.py --quiet
MLX_METALLIB="$(./script/build_mlx_metallib.sh)"
swift build --product AutocompleteRuntimeProbe
BIN_DIR="$(swift build --show-bin-path)"
cp "$MLX_METALLIB" "$BIN_DIR/mlx.metallib"
"$BIN_DIR/AutocompleteRuntimeProbe" --samples "$SAMPLES"
./script/model_latency_report.py --default-model-proof
