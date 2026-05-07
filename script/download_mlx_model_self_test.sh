#!/usr/bin/env bash
set -euo pipefail

script/download_mlx_model.py --list-models >/tmp/autocomplete-download-model-aliases.txt

for alias in \
  qwen35-4b \
  qwen3.5-4b \
  qwen35-9b \
  qwen3.5-9b \
  qwen3-1.7b \
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

script/download_mlx_model.py --model qwen3.5-4b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "repo_id=mlx-community/Qwen3.5-4B-MLX-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not point qwen3.5-4b at the preferred repo" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi

script/download_mlx_model.py --model qwen3.5-9b --print-target >/tmp/autocomplete-download-model-target.txt
if ! grep -F "target=$HOME/Library/Application Support/AutocompleteLab/Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit" /tmp/autocomplete-download-model-target.txt >/dev/null; then
  echo "download helper did not match the runtime qwen3.5-9b target" >&2
  cat /tmp/autocomplete-download-model-target.txt >&2
  exit 1
fi

echo "Download model alias self-test passed."
