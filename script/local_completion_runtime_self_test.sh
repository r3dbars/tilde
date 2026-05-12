#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import importlib.util
import os
from pathlib import Path

module_path = Path("script/local_completion_runtime.py").resolve()
spec = importlib.util.spec_from_file_location("local_completion_runtime", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

assert module.DEFAULT_MODEL_NAME == "Qwen3.5 4B"
assert module.mlx_model_name("Qwen3.5 4B") == "mlx-community/Qwen3.5-4B-MLX-4bit"
assert module.mlx_model_name(" qwen3.5 9b ") == "mlx-community/Qwen3.5-9B-MLX-4bit"
assert module.mlx_model_name("Gemma 4 E2B") == "mlx-community/gemma-4-E2B-it-4bit"
assert module.mlx_model_name("unknown") == module.DEFAULT_MLX_MODEL

os.environ["AUTOCOMPLETE_LAB_MLX_MODEL"] = "local/test-model"
assert module.mlx_model_name("Qwen3.5 4B") == "local/test-model"
PY

echo "Local completion runtime self-test: PASS"
