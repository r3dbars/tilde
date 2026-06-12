#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
from pathlib import Path

from model_asset_integrity import IMMUTABLE_REVISION_ERROR, is_immutable_revision, write_integrity_receipt

MODELS = {
    "qwen35-4b": {
        "repo_id": "mlx-community/Qwen3.5-4B-MLX-4bit",
        "revision": "32f3e8ecf65426fc3306969496342d504bfa13f3",
        "target": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    },
    "qwen3.5-4b": {
        "canonical": "qwen35-4b",
        "repo_id": "mlx-community/Qwen3.5-4B-MLX-4bit",
        "revision": "32f3e8ecf65426fc3306969496342d504bfa13f3",
        "target": "Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit",
    },
    "qwen35-9b": {
        "repo_id": "mlx-community/Qwen3.5-9B-MLX-4bit",
        "revision": "938d8919941c6e7efd3c7150eff7fe9d12afa631",
        "target": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    },
    "qwen3.5-9b": {
        "canonical": "qwen35-9b",
        "repo_id": "mlx-community/Qwen3.5-9B-MLX-4bit",
        "revision": "938d8919941c6e7efd3c7150eff7fe9d12afa631",
        "target": "Models/Qwen35NineB/MLX/Qwen3.5-9B-MLX-4bit",
    },
    "qwen3-1.7b": {
        "repo_id": "mlx-community/Qwen3-1.7B-4bit",
        "revision": "3b1b1768f8f8cf8351c712464f906e86c2b8269e",
        "target": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    },
    "small-draft-1b": {
        "canonical": "qwen3-1.7b",
        "repo_id": "mlx-community/Qwen3-1.7B-4bit",
        "revision": "3b1b1768f8f8cf8351c712464f906e86c2b8269e",
        "target": "Models/Qwen3Medium/MLX/qwen3-1.7b-4bit",
    },
    "qwen3-0.6b": {
        "repo_id": "mlx-community/Qwen3-0.6B-4bit",
        "revision": "73e3e38d981303bc594367cd910ea6eb48349da8",
        "target": "Models/Qwen3Small/MLX/qwen3-0.6b-4bit",
    },
    "gemma-4-e2b": {
        "repo_id": "mlx-community/gemma-4-e2b-mlx",
        "target": "Models/Gemma4E2B/MLX/gemma-4-e2b-mlx",
    },
    "gemma-4-e4b": {
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "revision": "1560521ede4c3196854c19b6a77fcc2db8d4e289",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma4-e4b": {
        "canonical": "gemma-4-e4b",
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "revision": "1560521ede4c3196854c19b6a77fcc2db8d4e289",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma-4-e4b-4bit": {
        "canonical": "gemma-4-e4b",
        "repo_id": "mlx-community/gemma-4-e4b-4bit",
        "revision": "1560521ede4c3196854c19b6a77fcc2db8d4e289",
        "target": "Models/Gemma4E4B/MLX/gemma-4-e4b-4bit",
    },
    "gemma-4-e4b-it-optiq": {
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "revision": "cfac466f1bca589c605b9ca1dd57c2deb63c5c63",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma-4-e4b-it-optiq-4bit": {
        "canonical": "gemma-4-e4b-it-optiq",
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "revision": "cfac466f1bca589c605b9ca1dd57c2deb63c5c63",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma4-e4b-it-optiq": {
        "canonical": "gemma-4-e4b-it-optiq",
        "repo_id": "mlx-community/gemma-4-e4b-it-OptiQ-4bit",
        "revision": "cfac466f1bca589c605b9ca1dd57c2deb63c5c63",
        "target": "Models/Gemma4E4BItOptiQ/MLX/gemma-4-e4b-it-OptiQ-4bit",
    },
    "gemma-4-26b": {
        "repo_id": "mlx-community/gemma-4-26b-a4b-it-4bit",
        "revision": "695690b33533b1f8b0395c1d6b4f00dc411353ef",
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
    parser = argparse.ArgumentParser(description="Download a SteadyType MLX model.")
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
    parser.add_argument(
        "--allow-floating-revision",
        action="store_true",
        help="Allow a model entry without a pinned revision. Never use this for beta assets.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.list_models:
        for alias in sorted(MODELS):
            print(alias)
        return 0

    model = MODELS[args.model]
    canonical_model = model.get("canonical", args.model)
    repo_id = model["repo_id"]
    revision = model.get("revision")
    target = (
        Path.home()
        / "Library/Application Support/SteadyType"
        / model["target"]
    )

    if args.print_target:
        print(f"alias={args.model}")
        print(f"canonical={canonical_model}")
        print(f"repo_id={repo_id}")
        print(f"revision={revision or '<unpinned>'}")
        print(f"target={target}")
        return 0

    if not revision and not args.allow_floating_revision:
        print(
            f"{args.model} does not have a pinned revision. Refusing a mutable download.",
            file=sys.stderr,
        )
        return 1
    if revision and not is_immutable_revision(revision):
        print(
            f"{args.model} {IMMUTABLE_REVISION_ERROR}. Refusing a mutable download.",
            file=sys.stderr,
        )
        return 1

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
    print(f"Revision: {revision or 'floating'}")
    print(f"Target: {target}")

    snapshot_download(
        repo_id=repo_id,
        revision=revision,
        local_dir=str(target),
        allow_patterns=ALLOW_PATTERNS,
        token=os.environ.get("HF_TOKEN"),
    )

    if revision:
        receipt_path = write_integrity_receipt(
            model=canonical_model,
            display_name=canonical_model,
            repo_id=repo_id,
            revision=revision,
            path=target,
        )
        print(f"Integrity receipt: {receipt_path}")
        if canonical_model == "qwen35-4b":
            validator = Path(__file__).with_name("check_model_asset.py")
            validation = subprocess.run(
                [
                    sys.executable,
                    str(validator),
                    "--model",
                    canonical_model,
                    "--quiet",
                ],
                check=False,
            )
            if validation.returncode != 0:
                print(
                    "Downloaded model did not match the app's known-good checksum set.",
                    file=sys.stderr,
                )
                return validation.returncode

    print("Model download complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
