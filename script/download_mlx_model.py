#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path

MODELS = {
    "qwen35-4b": {
        "repo_id": "mlx-community/Qwen3.5-4B-MLX-4bit",
        "revision": "32f3e8ecf65426fc3306969496342d504bfa13f3",
        "target": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    },
    "qwen3.5-4b": {
        "repo_id": "mlx-community/Qwen3.5-4B-MLX-4bit",
        "revision": "32f3e8ecf65426fc3306969496342d504bfa13f3",
        "target": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    },
    "qwen35-9b": {
        "repo_id": "mlx-community/Qwen3.5-9B-MLX-4bit",
        "target": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    },
    "qwen3.5-9b": {
        "repo_id": "mlx-community/Qwen3.5-9B-MLX-4bit",
        "target": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    },
    "qwen3-1.7b": {
        "repo_id": "mlx-community/Qwen3-1.7B-4bit",
        "target": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    },
    "qwen3-0.6b": {
        "repo_id": "mlx-community/Qwen3-0.6B-4bit",
        "target": "Models/Qwen3Small/MLX/qwen3-0.6b-4bit",
    },
    "gemma-4-e2b": {
        "repo_id": "mlx-community/gemma-4-e2b-mlx",
        "target": "Models/Gemma4E2B/MLX/gemma-4-e2b-mlx",
    },
    "gemma-4-e4b": {
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma4-e4b": {
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma-4-e4b-4bit": {
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma-4-e4b-it-optiq": {
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma-4-e4b-it-optiq-4bit": {
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma4-e4b-it-optiq": {
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma-4-26b": {
        "repo_id": "mlx-community/gemma-4-26b-a4b-it-4bit",
        "target": "Models/Gemma4A4B/MLX/gemma-4-26b-a4b-it-4bit",
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
    parser.add_argument(
        "--list-models",
        action="store_true",
        help="Print supported model aliases and exit.",
    )
    parser.add_argument(
        "--print-target",
        action="store_true",
        help="Print the selected repo and target path without downloading.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.list_models:
        for alias in sorted(MODELS):
            print(alias)
        return 0

    model = MODELS[args.model]
    repo_id = model["repo_id"]
    target = (
        Path.home()
        / "Library/Application Support/AutocompleteLab"
        / model["target"]
    )

    if args.print_target:
        print(f"alias={args.model}")
        print(f"repo_id={repo_id}")
        print(f"revision={model.get('revision', 'main')}")
        print(f"target={target}")
        return 0

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
        revision=model.get("revision", "main"),
        local_dir=str(target),
        allow_patterns=ALLOW_PATTERNS,
        token=os.environ.get("HF_TOKEN"),
    )

    print("Model download complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
