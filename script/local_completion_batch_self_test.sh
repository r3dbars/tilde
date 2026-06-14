#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import importlib.util
import json
import os
import tempfile
from pathlib import Path

module_path = Path("script/local_completion_batch.py").resolve()
spec = importlib.util.spec_from_file_location("local_completion_batch", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

# Unknown alias has no local target and falls back to the HF repo id. Point the
# model root at an empty dir so the result does not depend on which assets happen
# to be installed on this machine.
with tempfile.TemporaryDirectory() as empty:
    os.environ["AUTOCOMPLETE_LAB_MODEL_ROOT"] = str(Path(empty) / "Models")
    try:
        assert module.installed_asset_path("does-not-exist") is None
        source, kind = module.resolve_model_source("qwen35-4b")
        assert kind == "hf-repo", kind
        assert source == "mlx-community/Qwen3.5-4B-MLX-4bit", source
    finally:
        del os.environ["AUTOCOMPLETE_LAB_MODEL_ROOT"]

# A populated local asset dir is preferred over the repo id.
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    asset = root / "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit"
    asset.mkdir(parents=True)
    (asset / "config.json").write_text("{}", encoding="utf-8")
    (asset / "model.safetensors").write_text("weights", encoding="utf-8")
    os.environ["AUTOCOMPLETE_LAB_MODEL_ROOT"] = str(root / "Models")
    try:
        assert module.installed_asset_path("qwen35-4b") == asset
        source, kind = module.resolve_model_source("qwen35-4b")
        assert kind == "local-asset", kind
        assert source == str(asset), source
        # A local dir without weights is not considered installed.
        empty = root / "Models/Qwen3Small/MLX/qwen3-0.6b-4bit"
        empty.mkdir(parents=True)
        (empty / "config.json").write_text("{}", encoding="utf-8")
        assert module.installed_asset_path("qwen3-0.6b") is None
    finally:
        del os.environ["AUTOCOMPLETE_LAB_MODEL_ROOT"]

# An explicit MLX model override wins and is classified by whether it is a dir.
os.environ["AUTOCOMPLETE_LAB_MLX_MODEL"] = "some/repo-id"
try:
    source, kind = module.resolve_model_source("qwen35-4b")
    assert source == "some/repo-id" and kind == "hf-repo", (source, kind)
finally:
    del os.environ["AUTOCOMPLETE_LAB_MLX_MODEL"]


class FakeTokenizer:
    def apply_chat_template(self, messages, tokenize, add_generation_prompt, enable_thinking=None):
        assert tokenize is False
        assert add_generation_prompt is True
        assert enable_thinking is False
        roles = "+".join(message["role"] for message in messages)
        return f"<{roles}>"


# chat_instruct builds a system+user chat prompt; raw_completion stays literal.
chat_payload = {
    "system": "rules",
    "user": "The draft should",
    "mode": "phrase",
    "template": "chat_instruct",
    "promptIsBuilt": True,
}
assert module.build_prompt(chat_payload, FakeTokenizer()) == "<system+user>"

raw_payload = {
    "template": "raw_completion",
    "rawPrompt": "Inline.\n\nBefore cursor:\nThe draft should",
    "system": "ignored",
    "user": "ignored",
    "promptIsBuilt": True,
}
assert module.build_prompt(raw_payload, FakeTokenizer()) == "Inline.\n\nBefore cursor:\nThe draft should"

# read_rows parses JSONL and skips blank lines.
import io
rows = module.read_rows(io.StringIO('{"id": "a"}\n\n{"id": "b"}\n'))
assert [row["id"] for row in rows] == ["a", "b"], rows
PY

# The --print-source path resolves a model without importing mlx_lm. Use an empty
# model root so the result does not depend on locally-installed assets.
EMPTY_ROOT="$(mktemp -d)"
SOURCE_OUTPUT="$(AUTOCOMPLETE_LAB_MODEL_ROOT="$EMPTY_ROOT/Models" script/local_completion_batch.py --model qwen35-4b --print-source)"
rm -rf "$EMPTY_ROOT"
grep -q "alias=qwen35-4b" <<<"$SOURCE_OUTPUT"
grep -q "kind=hf-repo" <<<"$SOURCE_OUTPUT"

echo "Local completion batch self-test: PASS"
