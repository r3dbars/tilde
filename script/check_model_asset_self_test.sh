#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MODEL_ROOT="$TMP_DIR/Application Support/AutocompleteLab"
MODEL_PATH="$(script/check_model_asset.py --model-root "$MODEL_ROOT" --print-path)"
MISSING_OUTPUT="$TMP_DIR/missing-output.txt"
REQUIRED_OUTPUT="$TMP_DIR/required-output.txt"
SMALL_OUTPUT="$TMP_DIR/small-output.txt"
STALE_REVISION_OUTPUT="$TMP_DIR/stale-revision-output.txt"
VALID_OUTPUT="$TMP_DIR/valid-output.txt"
EXPECTED_REVISION="32f3e8ecf65426fc3306969496342d504bfa13f3"

if script/check_model_asset.py --model-root "$MODEL_ROOT" >"$MISSING_OUTPUT" 2>&1; then
  echo "model asset self-test expected a missing model to fail" >&2
  exit 1
fi

if ! grep -F "model asset check failed: missing Qwen3.5 4B MLX model" "$MISSING_OUTPUT" >/dev/null; then
  echo "model asset self-test did not explain the missing model" >&2
  cat "$MISSING_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Open Autocomplete Lab Settings and use the Local model action." "$MISSING_OUTPUT" >/dev/null; then
  echo "model asset self-test did not point testers to the in-app model action" >&2
  cat "$MISSING_OUTPUT" >&2
  exit 1
fi

if ! grep -F "./script/download_mlx_model.py --model qwen35-4b" "$MISSING_OUTPUT" >/dev/null; then
  echo "model asset self-test did not print the download fix" >&2
  cat "$MISSING_OUTPUT" >&2
  exit 1
fi

mkdir -p "$MODEL_PATH"
cat >"$MODEL_PATH/config.json" <<'JSON'
{"model_type":"qwen3"}
JSON
cat >"$MODEL_PATH/tokenizer.json" <<'JSON'
{"version":"1.0"}
JSON

if script/check_model_asset.py --model-root "$MODEL_ROOT" >"$REQUIRED_OUTPUT" 2>&1; then
  echo "model asset self-test expected missing tokenizer_config.json to fail" >&2
  exit 1
fi

if ! grep -F "missing required file(s): tokenizer_config.json" "$REQUIRED_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report missing required files" >&2
  cat "$REQUIRED_OUTPUT" >&2
  exit 1
fi

cat >"$MODEL_PATH/tokenizer_config.json" <<'JSON'
{"model_max_length":32768}
JSON
printf 'tiny' >"$MODEL_PATH/model.safetensors"

if script/check_model_asset.py --model-root "$MODEL_ROOT" >"$SMALL_OUTPUT" 2>&1; then
  echo "model asset self-test expected small weights to fail" >&2
  exit 1
fi

if ! grep -F "model weights are too small" "$SMALL_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report small weights" >&2
  cat "$SMALL_OUTPUT" >&2
  exit 1
fi

python3 - "$MODEL_PATH/model.safetensors" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
with path.open("wb") as handle:
    handle.seek((2 * 1024 * 1024 * 1024) + 1)
    handle.write(b"\0")
PY

METADATA_DIR="$MODEL_PATH/.cache/huggingface/download"
mkdir -p "$METADATA_DIR"
for file_name in config.json tokenizer.json tokenizer_config.json model.safetensors; do
  printf 'older-revision\netag-for-%s\n0\n' "$file_name" >"$METADATA_DIR/$file_name.metadata"
done

if script/check_model_asset.py --model-root "$MODEL_ROOT" >"$STALE_REVISION_OUTPUT" 2>&1; then
  echo "model asset self-test expected stale revision metadata to fail" >&2
  exit 1
fi

if ! grep -F "revision mismatch for config.json" "$STALE_REVISION_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report stale revision metadata" >&2
  cat "$STALE_REVISION_OUTPUT" >&2
  exit 1
fi

for file_name in config.json tokenizer.json tokenizer_config.json model.safetensors; do
  printf '%s\netag-for-%s\n0\n' "$EXPECTED_REVISION" "$file_name" >"$METADATA_DIR/$file_name.metadata"
done

script/check_model_asset.py --model-root "$MODEL_ROOT" >"$VALID_OUTPUT"

if ! grep -F "Model asset verified: Qwen3.5 4B MLX (qwen35-4b)" "$VALID_OUTPUT" >/dev/null; then
  echo "model asset self-test did not pass the synthetic valid model" >&2
  cat "$VALID_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Revision: $EXPECTED_REVISION" "$VALID_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report the verified pinned revision" >&2
  cat "$VALID_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Metadata fingerprint: sha256:" "$VALID_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report the metadata fingerprint" >&2
  cat "$VALID_OUTPUT" >&2
  exit 1
fi

echo "Model asset self-test passed."
