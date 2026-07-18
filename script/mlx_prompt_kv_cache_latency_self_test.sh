#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Pure-logic self-test only. It checks token-prefix and percentile accounting
# without loading MLX or touching a model asset.
python3 script/mlx_prompt_kv_cache_latency.py --self-test

echo "MLX prompt KV-cache latency self-test: PASS"
