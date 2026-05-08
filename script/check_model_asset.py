#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
DOWNLOAD_SCRIPT = ROOT_DIR / "script" / "download_mlx_model.py"

PREFERRED_MODEL = "qwen35-4b"
MODEL_VALIDATION = {
    "qwen35-4b": {
        "display_name": "Qwen3.5 4B",
        "required_files": {"config.json", "tokenizer.json", "tokenizer_config.json"},
        "minimum_weight_bytes": 2 * 1024 * 1024 * 1024,
        "weight_extension": ".safetensors",
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
        default=Path.home() / "Library/Application Support/AutocompleteLab",
        help="Autocomplete Lab Application Support root.",
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


def read_huggingface_metadata(path: Path, file_name: str) -> tuple[str, str, str | None]:
    metadata_path = path / ".cache" / "huggingface" / "download" / f"{file_name}.metadata"
    try:
        lines = metadata_path.read_text().splitlines()
    except OSError as error:
        return "", "", f"missing revision metadata for {file_name} ({error})"

    if not lines or not lines[0].strip():
        return "", "", f"empty revision metadata for {file_name}"

    revision = lines[0].strip()
    etag = lines[1].strip() if len(lines) > 1 else ""
    return revision, etag, None


def validation_failure(model: str, path: Path, reason: str) -> str:
    display_name = MODEL_VALIDATION[model]["display_name"]
    return "\n".join(
        [
            f"model asset check failed: {reason}",
            f"Model: {display_name} MLX ({model})",
            f"Expected: {path}",
            "",
            "Fix:",
            "  Open Autocomplete Lab Settings and use the Local model action.",
            "  The app shows the expected model folder and keeps suggestions off until the model is valid.",
            "",
            "Developer fallback:",
            "  python3 -m pip install --user huggingface_hub",
            f"  ./script/download_mlx_model.py --model {model}",
            "",
            "Then rerun:",
            "  ./script/check_model_asset.py",
        ]
    )


def validate_model(model: str, path: Path) -> tuple[bool, str, int, int, str | None, str | None]:
    validation = MODEL_VALIDATION[model]
    model_definition = load_download_models()[model]
    expected_revision = model_definition.get("revision", "main")
    required_files = validation["required_files"]
    weight_extension = validation["weight_extension"]
    minimum_weight_bytes = validation["minimum_weight_bytes"]

    if not path.exists():
        return False, f"missing {validation['display_name']} MLX model", 0, 0, None, None

    if not path.is_dir():
        return False, "expected a model directory", 0, 0, None, None

    children = {child.name: child for child in path.iterdir()}
    missing_files = sorted(required_files.difference(children))
    if missing_files:
        return False, f"missing required file(s): {', '.join(missing_files)}", 0, 0, None, None

    for file_name in sorted(required_files):
        json_error = read_json_object(children[file_name])
        if json_error:
            return False, json_error, 0, 0, None, None

    weight_files = [
        child for child in children.values()
        if child.is_file() and child.name.lower().endswith(weight_extension)
    ]
    if not weight_files:
        return False, f"missing {weight_extension} weights", 0, 0, None, None

    weight_bytes = sum(child.stat().st_size for child in weight_files)
    if weight_bytes < minimum_weight_bytes:
        return (
            False,
            "model weights are too small "
            f"({format_bytes(weight_bytes)} found, need at least {format_bytes(minimum_weight_bytes)})",
            len(weight_files),
            weight_bytes,
            None,
            None,
        )

    verified_revision = None
    metadata_fingerprint = None
    if expected_revision != "main":
        fingerprint = hashlib.sha256()
        fingerprint.update(f"{model}\0{expected_revision}\n".encode())
        metadata_file_names = sorted(required_files.union({file.name for file in weight_files}))
        for file_name in metadata_file_names:
            revision, etag, metadata_error = read_huggingface_metadata(path, file_name)
            if metadata_error:
                return False, metadata_error, len(weight_files), weight_bytes, None, None
            if revision != expected_revision:
                return (
                    False,
                    f"revision mismatch for {file_name} "
                    f"(found {revision}, expected {expected_revision})",
                    len(weight_files),
                    weight_bytes,
                    None,
                    None,
                )
            file_size = children[file_name].stat().st_size
            fingerprint.update(f"{file_name}\0{file_size}\0{revision}\0{etag}\n".encode())

        verified_revision = expected_revision
        metadata_fingerprint = fingerprint.hexdigest()

    return True, "ok", len(weight_files), weight_bytes, verified_revision, metadata_fingerprint


def main() -> int:
    args = parse_args()
    path = model_target(args.model, args.model_root)

    if args.print_path:
        print(path)
        return 0

    is_valid, reason, weight_count, weight_bytes, revision, fingerprint = validate_model(args.model, path)
    if not is_valid:
        print(validation_failure(args.model, path, reason), file=sys.stderr)
        return 1

    if not args.quiet:
        display_name = MODEL_VALIDATION[args.model]["display_name"]
        print(f"Model asset verified: {display_name} MLX ({args.model})")
        print(f"Path: {path}")
        if revision:
            print(f"Revision: {revision}")
        if fingerprint:
            print(f"Metadata fingerprint: sha256:{fingerprint}")
        print(f"Weights: {format_bytes(weight_bytes)} across {weight_count} file(s)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
