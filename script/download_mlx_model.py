#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path

MODELS = {
    "qwen35-4b": {
        "repo_id": "mlx-community/Qwen3.5-4B-4bit",
        "target": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    },
    "gemma-4-e4b": {
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
}

ALLOW_PATTERNS = [
    "chat_template.jinja",
    "config.json",
    "generation_config.json",
    "*.safetensors",
    "*.safetensors.index.json",
    "merges.txt",
    "preprocessor_config.json",
    "processor_config.json",
    "special_tokens_map.json",
    "tokenizer.model",
    "tokenizer.json",
    "tokenizer_config.json",
    "video_preprocessor_config.json",
    "vocab.json",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download an Autocomplete Lab MLX model.")
    parser.add_argument(
        "--model",
        choices=sorted(MODELS),
        default="qwen35-4b",
        help="Model alias to download.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    model = MODELS[args.model]
    repo_id = model["repo_id"]
    target = (
        Path.home()
        / "Library/Application Support/AutocompleteLab"
        / model["target"]
    )

    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print(
            "huggingface_hub is not installed. Install it outside this script, then rerun.",
            file=sys.stderr,
        )
        return 1

    target.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {repo_id}")
    print(f"Target: {target}")

    snapshot_download(
        repo_id=repo_id,
        local_dir=str(target),
        allow_patterns=ALLOW_PATTERNS,
        token=os.environ.get("HF_TOKEN"),
    )

    print("Model download complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
