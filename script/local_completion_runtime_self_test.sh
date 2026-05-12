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

captured = {}

def fake_candidate_executable(env_key, names):
    assert env_key == "AUTOCOMPLETE_LAB_MLX_BIN"
    return "/tmp/mlx_lm.generate"

def fake_run_command(command, timeout):
    captured["command"] = command
    captured["timeout"] = timeout
    return "ok"

module.candidate_executable = fake_candidate_executable
module.run_command = fake_run_command
module.run_mlx("prompt", "system", 4, 3.5, "Qwen3.5 4B")
command = captured["command"]
assert "--chat-template-config" in command
config = command[command.index("--chat-template-config") + 1]
assert config == '{"enable_thinking": false}'
PY

echo "Local completion runtime self-test: PASS"
