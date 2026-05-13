#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path

from model_asset_integrity import (
    RECEIPT_NAME,
    validate_integrity_receipt,
    write_integrity_receipt,
)

ROOT_DIR = Path(__file__).resolve().parents[1]
DOWNLOAD_SCRIPT = ROOT_DIR / "script" / "download_mlx_model.py"

PREFERRED_MODEL = "qwen35-4b"
QWEN35_4B_EXPECTED_FILES = {
    "chat_template.jinja": {
        "byte_count": 7756,
        "sha256": "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715",
    },
    "config.json": {
        "byte_count": 3366,
        "sha256": "f3efc81b2ea8d96a45301037d3ccccbcccdef44a961845c87f286aaddbc6eaaa",
    },
    "model.safetensors": {
        "byte_count": 3034300695,
        "sha256": "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db",
    },
    "model.safetensors.index.json": {
        "byte_count": 101944,
        "sha256": "52e534c41f7b97708329c85f762e5882bf48bd5955a422c6ae74eba321e6048a",
    },
    "preprocessor_config.json": {
        "byte_count": 390,
        "sha256": "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516",
    },
    "processor_config.json": {
        "byte_count": 1300,
        "sha256": "14932921ca485d458a04dafd8069fbb0a4505622a48208d19ed247115801385b",
    },
    "tokenizer.json": {
        "byte_count": 19989343,
        "sha256": "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4",
    },
    "tokenizer_config.json": {
        "byte_count": 1139,
        "sha256": "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182",
    },
    "video_preprocessor_config.json": {
        "byte_count": 385,
        "sha256": "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13",
    },
    "vocab.json": {
        "byte_count": 6722759,
        "sha256": "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003",
    },
}
MODEL_VALIDATION = {
    "qwen35-4b": {
        "display_name": "Qwen3.5 4B",
        "required_files": {"config.json", "tokenizer.json", "tokenizer_config.json"},
        "minimum_weight_bytes": 2 * 1024 * 1024 * 1024,
        "weight_extension": ".safetensors",
        "expected_files": QWEN35_4B_EXPECTED_FILES,
    },
}


def load_download_models() -> dict[str, dict[str, str]]:
    spec = importlib.util.spec_from_file_location("download_mlx_model", DOWNLOAD_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {DOWNLOAD_SCRIPT}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.MODELS


def format_bytes(value: int) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(size)} {unit}"
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{value} B"


def model_target(model: str, model_root: Path) -> Path:
    models = load_download_models()
    return model_root / models[model]["target"]


def parse_args() -> argparse.Namespace:
    models = load_download_models()
    parser = argparse.ArgumentParser(
        description="Verify the app-owned MLX model asset needed for beta/release readiness."
    )
    parser.add_argument(
        "--model",
        choices=sorted(MODEL_VALIDATION),
        default=PREFERRED_MODEL,
        help="Model alias to verify.",
    )
    parser.add_argument(
        "--model-root",
        type=Path,
        default=Path.home() / "Library/Application Support/SteadyType",
        help="SteadyType Application Support root.",
    )
    parser.add_argument(
        "--print-path",
        action="store_true",
        help="Print the expected model path and exit without validating.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print failures.",
    )
    parser.add_argument(
        "--write-integrity-receipt",
        action="store_true",
        help="Write or refresh the local checksum receipt before validating it.",
    )

    args = parser.parse_args()
    if args.model not in models:
        parser.error(f"{args.model} is not available in {DOWNLOAD_SCRIPT}")
    return args


def read_json_object(path: Path) -> str | None:
    try:
        value = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        return f"{path.name} is not valid JSON ({error.msg})"
    except OSError as error:
        return f"{path.name} could not be read ({error})"

    if not isinstance(value, dict):
        return f"{path.name} must contain a JSON object"

    return None


def validation_failure(model: str, path: Path, reason: str) -> str:
    display_name = MODEL_VALIDATION[model]["display_name"]
    return "\n".join(
        [
            f"model asset check failed: {reason}",
            f"Model: {display_name} MLX ({model})",
            f"Expected: {path}",
            "",
            "Fix:",
            "  Open SteadyType Settings and use the Local model action.",
            "  The app shows the expected model folder and keeps suggestions off until the model is valid.",
            f"  The verifier requires the pinned revision and {RECEIPT_NAME} checksum receipt.",
            "",
            "Developer fallback:",
            "  python3 -m pip install --user huggingface_hub",
            f"  ./script/download_mlx_model.py --model {model}",
            "",
            "Then rerun:",
            "  ./script/check_model_asset.py",
        ]
    )


def validate_model(
    model: str,
    path: Path,
    *,
    write_receipt: bool = False,
) -> tuple[bool, str, int, int]:
    models = load_download_models()
    model_info = models[model]
    validation = MODEL_VALIDATION[model]
    required_files = validation["required_files"]
    weight_extension = validation["weight_extension"]
    minimum_weight_bytes = int(
        os.environ.get(
            "AUTOCOMPLETE_LAB_MODEL_MINIMUM_WEIGHT_BYTES",
            str(validation["minimum_weight_bytes"]),
        )
    )
    repo_id = model_info["repo_id"]
    revision = model_info.get("revision")

    if not revision:
        return False, "model download is not pinned to an immutable revision", 0, 0

    if not path.exists():
        return False, f"missing {validation['display_name']} MLX model", 0, 0

    if not path.is_dir():
        return False, "expected a model directory", 0, 0

    children = {child.name: child for child in path.iterdir()}
    missing_files = sorted(required_files.difference(children))
    if missing_files:
        return False, f"missing required file(s): {', '.join(missing_files)}", 0, 0

    for file_name in sorted(required_files):
        json_error = read_json_object(children[file_name])
        if json_error:
            return False, json_error, 0, 0

    weight_files = [
        child for child in children.values()
        if child.is_file() and child.name.lower().endswith(weight_extension)
    ]
    if not weight_files:
        return False, f"missing {weight_extension} weights", 0, 0

    weight_bytes = sum(child.stat().st_size for child in weight_files)
    if weight_bytes < minimum_weight_bytes:
        return (
            False,
            "model weights are too small "
            f"({format_bytes(weight_bytes)} found, need at least {format_bytes(minimum_weight_bytes)})",
            len(weight_files),
            weight_bytes,
        )

    if write_receipt:
        write_integrity_receipt(
            model=model,
            display_name=validation["display_name"],
            repo_id=repo_id,
            revision=revision,
            path=path,
        )

    receipt_error = validate_integrity_receipt(
        model=model,
        repo_id=repo_id,
        revision=revision,
        path=path,
        expected_files=(
            None
            if os.environ.get("AUTOCOMPLETE_LAB_SKIP_KNOWN_MODEL_CHECKSUMS") == "1"
            else validation.get("expected_files")
        ),
    )
    if receipt_error:
        return False, receipt_error, len(weight_files), weight_bytes

    return True, "ok", len(weight_files), weight_bytes


def main() -> int:
    args = parse_args()
    path = model_target(args.model, args.model_root)

    if args.print_path:
        print(path)
        return 0

    is_valid, reason, weight_count, weight_bytes = validate_model(
        args.model,
        path,
        write_receipt=args.write_integrity_receipt,
    )
    if not is_valid:
        print(validation_failure(args.model, path, reason), file=sys.stderr)
        return 1

    if not args.quiet:
        models = load_download_models()
        model_info = models[args.model]
        display_name = MODEL_VALIDATION[args.model]["display_name"]
        print(f"Model asset verified: {display_name} MLX ({args.model})")
        print(f"Path: {path}")
        print(f"Revision: {model_info.get('revision')}")
        print(f"Integrity receipt: {path / RECEIPT_NAME}")
        print(f"Weights: {format_bytes(weight_bytes)} across {weight_count} file(s)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
