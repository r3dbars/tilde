#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from check_model_asset import MODEL_VALIDATION, PREFERRED_MODEL


APP_BUNDLE_MAX_BYTES = 180_000_000
MODEL_ASSET_MAX_BYTES = 3_100_000_000

EXPECTED_BUNDLE_FILES = {
    "Contents/Info.plist",
    "Contents/MacOS/SteadyType",
    "Contents/MacOS/SteadyTypeTextEventHelper",
    "Contents/Resources/AppIcon.icns",
    "Contents/Resources/mlx-swift_Cmlx.bundle/default.metallib",
    "Contents/_CodeSignature/CodeResources",
}
EXPECTED_EXECUTABLES = {
    "Contents/MacOS/SteadyType",
    "Contents/MacOS/SteadyTypeTextEventHelper",
}


def format_bytes(value: int) -> str:
    return f"{value:,} bytes"


def fail(message: str) -> None:
    print(f"lightweight budget check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def expected_model_bytes() -> int:
    validation = MODEL_VALIDATION.get(PREFERRED_MODEL)
    if validation is None:
        fail(f"release model {PREFERRED_MODEL!r} has no validation policy")

    expected_files = validation.get("expected_files")
    if not isinstance(expected_files, dict) or not expected_files:
        fail(f"release model {PREFERRED_MODEL!r} has no pinned file inventory")

    byte_counts: list[int] = []
    for relative_path, metadata in expected_files.items():
        if not isinstance(metadata, dict):
            fail(f"release model inventory is invalid for {relative_path}")
        byte_count = metadata.get("byte_count")
        if not isinstance(byte_count, int) or byte_count < 0:
            fail(f"release model inventory has an invalid byte count for {relative_path}")
        byte_counts.append(byte_count)
    return sum(byte_counts)


def check_model_budget(max_bytes: int) -> None:
    model_bytes = expected_model_bytes()
    if model_bytes > max_bytes:
        fail(
            f"pinned {PREFERRED_MODEL} model payload is {format_bytes(model_bytes)}, "
            f"over the {format_bytes(max_bytes)} budget"
        )
    print(
        f"Model asset budget passed: {format_bytes(model_bytes)} "
        f"<= {format_bytes(max_bytes)} ({PREFERRED_MODEL})."
    )


def relative_entries(app_bundle: Path) -> tuple[set[str], list[str]]:
    files: set[str] = set()
    symlinks: list[str] = []
    for entry in app_bundle.rglob("*"):
        relative_path = entry.relative_to(app_bundle).as_posix()
        if entry.is_symlink():
            symlinks.append(relative_path)
        elif entry.is_file():
            files.add(relative_path)
    return files, symlinks


def check_app_bundle(app_bundle: Path, max_bytes: int) -> None:
    if not app_bundle.is_dir():
        fail(f"missing app bundle: {app_bundle}")

    files, symlinks = relative_entries(app_bundle)
    if symlinks:
        fail(f"unexpected symlink payload: {symlinks[0]}")

    missing_files = sorted(EXPECTED_BUNDLE_FILES.difference(files))
    if missing_files:
        fail(f"missing expected payload: {missing_files[0]}")

    unexpected_files = sorted(files.difference(EXPECTED_BUNDLE_FILES))
    if unexpected_files:
        fail(f"unexpected payload: {unexpected_files[0]}")

    executable_files = {
        relative_path
        for relative_path in files
        if os.access(app_bundle / relative_path, os.X_OK)
    }
    if executable_files != EXPECTED_EXECUTABLES:
        missing_executables = sorted(EXPECTED_EXECUTABLES.difference(executable_files))
        if missing_executables:
            fail(f"expected executable is not executable: {missing_executables[0]}")
        unexpected_executables = sorted(executable_files.difference(EXPECTED_EXECUTABLES))
        fail(f"unexpected executable payload: {unexpected_executables[0]}")

    bundle_bytes = sum((app_bundle / relative_path).stat().st_size for relative_path in files)
    if bundle_bytes > max_bytes:
        fail(
            f"app bundle is {format_bytes(bundle_bytes)}, "
            f"over the {format_bytes(max_bytes)} budget"
        )

    print(
        f"App bundle budget passed: {format_bytes(bundle_bytes)} "
        f"<= {format_bytes(max_bytes)} ({len(files)} files, 2 executables)."
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Enforce SteadyType's shipped app and pinned model size budgets."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--source-only",
        action="store_true",
        help="Check the pinned release model inventory without requiring a built app.",
    )
    mode.add_argument(
        "--app-bundle",
        type=Path,
        help="Check the exact release app payload and logical file bytes.",
    )
    parser.add_argument(
        "--max-app-bytes",
        type=int,
        default=APP_BUNDLE_MAX_BYTES,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--max-model-bytes",
        type=int,
        default=MODEL_ASSET_MAX_BYTES,
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args()
    if args.max_app_bytes < 0 or args.max_model_bytes < 0:
        parser.error("budgets must be non-negative")
    return args


def main() -> None:
    args = parse_args()
    check_model_budget(args.max_model_bytes)
    if args.app_bundle is not None:
        check_app_bundle(args.app_bundle, args.max_app_bytes)


if __name__ == "__main__":
    main()
