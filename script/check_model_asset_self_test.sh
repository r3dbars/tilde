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
RECEIPT_OUTPUT="$TMP_DIR/receipt-output.txt"
KNOWN_OUTPUT="$TMP_DIR/known-output.txt"
VALID_OUTPUT="$TMP_DIR/valid-output.txt"
KNOWN_GOOD_OUTPUT="$TMP_DIR/known-good-output.txt"
CHECK_ENV=(env AUTOCOMPLETE_LAB_MODEL_MINIMUM_WEIGHT_BYTES=8)
SYNTHETIC_CHECK_ENV=(
  env
  AUTOCOMPLETE_LAB_MODEL_MINIMUM_WEIGHT_BYTES=8
  AUTOCOMPLETE_LAB_SKIP_KNOWN_MODEL_CHECKSUMS=1
)

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$MISSING_OUTPUT" 2>&1; then
  echo "model asset self-test expected a missing model to fail" >&2
  exit 1
fi

if ! grep -F "model asset check failed: missing Qwen3.5 4B MLX model" "$MISSING_OUTPUT" >/dev/null; then
  echo "model asset self-test did not explain the missing model" >&2
  cat "$MISSING_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Open SteadyType Settings and use the Local model action." "$MISSING_OUTPUT" >/dev/null; then
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

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$REQUIRED_OUTPUT" 2>&1; then
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

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$SMALL_OUTPUT" 2>&1; then
  echo "model asset self-test expected small weights to fail" >&2
  exit 1
fi

if ! grep -F "model weights are too small" "$SMALL_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report small weights" >&2
  cat "$SMALL_OUTPUT" >&2
  exit 1
fi

printf 'large-enough' >"$MODEL_PATH/model.safetensors"

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$RECEIPT_OUTPUT" 2>&1; then
  echo "model asset self-test expected a missing integrity receipt to fail" >&2
  exit 1
fi

if ! grep -F "missing integrity receipt .steadytype-model-integrity.json" "$RECEIPT_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report the missing integrity receipt" >&2
  cat "$RECEIPT_OUTPUT" >&2
  exit 1
fi

"${SYNTHETIC_CHECK_ENV[@]}" script/check_model_asset.py \
  --model-root "$MODEL_ROOT" \
  --write-integrity-receipt \
  >"$VALID_OUTPUT"

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$KNOWN_OUTPUT" 2>&1; then
  echo "model asset self-test expected synthetic bytes to fail known-good checksum validation" >&2
  exit 1
fi

if ! grep -E "known-good|unexpected file" "$KNOWN_OUTPUT" >/dev/null; then
  echo "model asset self-test did not enforce known-good model checksums" >&2
  cat "$KNOWN_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Model asset verified: Qwen3.5 4B MLX (qwen35-4b)" "$VALID_OUTPUT" >/dev/null; then
  echo "model asset self-test did not pass the synthetic valid model" >&2
  cat "$VALID_OUTPUT" >&2
  exit 1
fi

if ! grep -F "Integrity receipt:" "$VALID_OUTPUT" >/dev/null; then
  echo "model asset self-test did not print the integrity receipt path" >&2
  cat "$VALID_OUTPUT" >&2
  exit 1
fi

if "${CHECK_ENV[@]}" script/check_model_asset.py --model-root "$MODEL_ROOT" >"$KNOWN_GOOD_OUTPUT" 2>&1; then
  echo "model asset self-test expected synthetic files to fail known-good checksum validation" >&2
  exit 1
fi

if ! grep -F ".steadytype-model-integrity.json is missing known-good file: chat_template.jinja" "$KNOWN_GOOD_OUTPUT" >/dev/null; then
  echo "model asset self-test did not report the missing known-good model file" >&2
  cat "$KNOWN_GOOD_OUTPUT" >&2
  exit 1
fi

echo "Model asset self-test passed."
