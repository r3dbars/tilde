#!/usr/bin/env python3
import os
import sys
from pathlib import Path

REPO_ID = "mlx-community/Qwen3-0.6B-4bit"
TARGET = (
    Path.home()
    / "Library/Application Support/AutocompleteLab/Models/Qwen3Small/MLX/qwen3-0.6b-4bit"
)
ALLOW_PATTERNS = [
    "chat_template.jinja",
    "config.json",
    "generation_config.json",
    "*.safetensors",
    "*.safetensors.index.json",
    "merges.txt",
    "processor_config.json",
    "special_tokens_map.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "vocab.json",
]


def main() -> int:
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print(
            "huggingface_hub is not installed. Install it outside this script, then rerun.",
            file=sys.stderr,
        )
        return 1

    TARGET.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {REPO_ID}")
    print(f"Target: {TARGET}")

    snapshot_download(
        repo_id=REPO_ID,
        local_dir=str(TARGET),
        allow_patterns=ALLOW_PATTERNS,
        token=os.environ.get("HF_TOKEN"),
    )

    print("Model download complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
