#!/usr/bin/env bash
set -euo pipefail

script/download_mlx_model.py --list-models >/tmp/autocomplete-download-model-aliases.txt

for alias in \
  qwen35-4b \
  qwen3.5-4b \
  qwen35-9b \
  qwen3.5-9b \
  qwen3-1.7b \
  small-draft-1b \
  qwen3-0.6b \
  gemma-4-e2b \
  gemma-4-e4b \
  gemma4-e4b \
  gemma-4-e4b-4bit \
  gemma-4-e4b-it-optiq \
  gemma-4-e4b-it-optiq-4bit \
  gemma4-e4b-it-optiq \
  gemma-4-26b; do
  if ! grep -Fx "$alias" /tmp/autocomplete-download-model-aliases.txt >/dev/null; then
    echo "missing download alias: $alias" >&2
    cat /tmp/autocomplete-download-model-aliases.txt >&2
    exit 1
  fi
done

script/download_mlx_model.py --model qwen35-4b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "repo_id=mlx-community/Qwen3.5-4B-MLX-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not point qwen35-4b at the preferred repo" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi
if ! grep -F "revision=32f3e8ecf65426fc3306969496342d504bfa13f3" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not pin qwen35-4b to the expected revision" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi
if ! grep -F "check_model_asset.py" script/download_mlx_model.py >/dev/null ||
   ! grep -F "known-good checksum" script/download_mlx_model.py >/dev/null; then
  echo "download helper does not validate the preferred model against known-good checksums" >&2
  exit 1
fi

python3 - <<'PY'
import importlib.util
from pathlib import Path

module_path = Path("script/model_asset_integrity.py")
spec = importlib.util.spec_from_file_location("model_asset_integrity", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

assert module.is_immutable_revision("32f3e8ecf65426fc3306969496342d504bfa13f3")
assert not module.is_immutable_revision("main")
assert not module.is_immutable_revision("32f3e8ecf65426fc3306969496342d504bfa13f")
PY

script/download_mlx_model.py --model qwen3.5-4b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "repo_id=mlx-community/Qwen3.5-4B-MLX-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not point qwen3.5-4b at the preferred repo" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi
if ! grep -F "canonical=qwen35-4b" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not normalize the qwen3.5-4b alias for receipts" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi

script/download_mlx_model.py --model qwen3.5-9b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "target=$HOME/Library/Application Support/SteadyType/Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not match the runtime qwen3.5-9b target" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi
if ! grep -F "revision=938d8919941c6e7efd3c7150eff7fe9d12afa631" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not pin qwen3.5-9b to the expected revision" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi

script/download_mlx_model.py --model small-draft-1b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "repo_id=mlx-community/Qwen3-1.7B-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not point small-draft-1b at the 1B-class repo" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi
if ! grep -F "canonical=qwen3-1.7b" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not normalize the small-draft-1b alias for receipts" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi

echo "Download model alias self-test passed."
