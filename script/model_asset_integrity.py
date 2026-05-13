from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path
from typing import Any


RECEIPT_NAME = ".steadytype-model-integrity.json"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def model_files(path: Path) -> list[Path]:
    return sorted(
        child
        for child in path.iterdir()
        if child.is_file()
        and child.name != RECEIPT_NAME
        and not child.name.startswith(".")
    )


def write_integrity_receipt(
    *,
    model: str,
    display_name: str,
    repo_id: str,
    revision: str,
    path: Path,
) -> Path:
    files = [
        {
            "path": child.name,
            "byte_count": child.stat().st_size,
            "sha256": sha256_file(child),
        }
        for child in model_files(path)
    ]
    receipt = {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "model": model,
        "display_name": display_name,
        "repo_id": repo_id,
        "revision": revision,
        "files": files,
    }
    receipt_path = path / RECEIPT_NAME
    temp_path = path / f"{RECEIPT_NAME}.tmp"
    temp_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    temp_path.replace(receipt_path)
    return receipt_path


def validate_integrity_receipt(
    *,
    model: str,
    repo_id: str,
    revision: str,
    path: Path,
    expected_files: dict[str, dict[str, int | str]] | None = None,
) -> str | None:
    receipt_path = path / RECEIPT_NAME
    if not receipt_path.exists():
        return f"missing integrity receipt {RECEIPT_NAME}"

    try:
        receipt: Any = json.loads(receipt_path.read_text())
    except json.JSONDecodeError as error:
        return f"{RECEIPT_NAME} is not valid JSON ({error.msg})"
    except OSError as error:
        return f"{RECEIPT_NAME} could not be read ({error})"

    if not isinstance(receipt, dict):
        return f"{RECEIPT_NAME} must contain a JSON object"
    if receipt.get("schema_version") != 1:
        return f"{RECEIPT_NAME} has an unsupported schema"
    if receipt.get("model") != model:
        return f"{RECEIPT_NAME} model mismatch"
    if receipt.get("repo_id") != repo_id:
        return f"{RECEIPT_NAME} repo mismatch"
    if receipt.get("revision") != revision:
        return f"{RECEIPT_NAME} revision mismatch"

    files = receipt.get("files")
    if not isinstance(files, list) or not files:
        return f"{RECEIPT_NAME} has no file checksums"

    seen: set[str] = set()
    entries_by_path: dict[str, dict[str, Any]] = {}
    for entry in files:
        if not isinstance(entry, dict):
            return f"{RECEIPT_NAME} has an invalid file entry"
        relative_path = entry.get("path")
        expected_size = entry.get("byte_count")
        expected_sha = entry.get("sha256")
        if not isinstance(relative_path, str) or "/" in relative_path or relative_path.startswith("."):
            return f"{RECEIPT_NAME} has an unsafe file path"
        if not isinstance(expected_size, int) or expected_size < 0:
            return f"{RECEIPT_NAME} has an invalid size for {relative_path}"
        if not isinstance(expected_sha, str) or len(expected_sha) != 64:
            return f"{RECEIPT_NAME} has an invalid sha256 for {relative_path}"
        if relative_path in entries_by_path:
            return f"{RECEIPT_NAME} has a duplicate file entry: {relative_path}"
        entries_by_path[relative_path] = entry
        seen.add(relative_path)

    if expected_files:
        expected_paths = set(expected_files)
        missing_expected = sorted(expected_paths.difference(seen))
        if missing_expected:
            return f"{RECEIPT_NAME} is missing known-good file: {missing_expected[0]}"
        unexpected_files = sorted(seen.difference(expected_paths))
        if unexpected_files:
            return f"{RECEIPT_NAME} has unexpected file: {unexpected_files[0]}"

        for relative_path in sorted(expected_paths):
            expected = expected_files[relative_path]
            entry = entries_by_path[relative_path]
            if entry["byte_count"] != expected["byte_count"]:
                return f"known-good size mismatch: {relative_path}"
            if str(entry["sha256"]).lower() != str(expected["sha256"]).lower():
                return f"known-good checksum mismatch: {relative_path}"

    for relative_path, entry in sorted(entries_by_path.items()):
        expected_size = entry["byte_count"]
        expected_sha = str(entry["sha256"]).lower()
        file_path = path / relative_path
        if not file_path.is_file():
            return f"receipt file is missing: {relative_path}"
        if file_path.stat().st_size != expected_size:
            return f"receipt size mismatch: {relative_path}"
        if sha256_file(file_path) != expected_sha:
            return f"receipt checksum mismatch: {relative_path}"

    current_files = {child.name for child in model_files(path)}
    extra_files = sorted(current_files.difference(seen))
    if extra_files:
        return f"model files are not in the integrity receipt: {', '.join(extra_files)}"

    return None
