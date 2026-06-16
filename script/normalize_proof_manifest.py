#!/usr/bin/env python3
"""Canonicalize docs/product/proof-manifest.json.

The proof manifest is a single JSON file whose growth lists are append-only and
touched by nearly every PR, so concurrent branches keep colliding on it. JSON
cannot be union-merged (that corrupts the syntax), so instead we keep the file in
a deterministic canonical form: the append-target lists are sorted by their key,
which spreads new entries to stable, alphabetically-distinct positions and makes
git's 3-way merge resolve non-overlapping inserts cleanly. Dedup-on-write also
removes the duplicate entry a hand-resolved conflict would otherwise leave.

Canonical form:
    * 2-space indented JSON with a trailing newline (already the repo style)
    * `surfaces` sorted by "surface"
    * `profileCoverage` sorted by "bundle"
    * `hostPolicy.entries` sorted by "bundle"
    * object key order within each entry preserved (keeps the diff minimal)

`graduationDecisions` is intentionally NOT sorted: it is a closed, enumerated set
whose insertion order is an explicit contract checked by
script/check_graduation_score.py. It is not an every-PR append target.

Usage:
    normalize_proof_manifest.py            # alias for --check
    normalize_proof_manifest.py --check     # exit 1 if not canonical
    normalize_proof_manifest.py --write      # rewrite in place

The matching `--check` runs as a blocking CI lane (script/proof.sh) so the file
cannot silently drift out of sorted order or carry a duplicate key.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "product" / "proof-manifest.json"

# list path (within the manifest) -> key field the list is sorted/deduped by.
SORTED_LISTS = (
    (("surfaces",), "surface"),
    (("profileCoverage",), "bundle"),
    (("hostPolicy", "entries"), "bundle"),
)


def fail(message: str) -> "None":
    print(f"normalize proof manifest failed: {message}", file=sys.stderr)
    raise SystemExit(2)


def get_list(manifest: dict, path: tuple[str, ...]) -> list | None:
    node: object = manifest
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node if isinstance(node, list) else None


def sort_and_dedup(rows: list, key: str, where: str) -> list:
    deduped: dict[str, dict] = {}
    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict) or key not in row:
            # Leave structural validation to check_proof_manifest.py; just don't
            # crash on a shape we can't sort.
            fail(f"{where} entry {index} is missing '{key}' -- run check_proof_manifest first")
        identifier = str(row[key])
        existing = deduped.get(identifier)
        if existing is not None and existing != row:
            fail(
                f"{where} has conflicting entries for {key}={identifier!r} -- resolve by hand"
            )
        deduped[identifier] = row
    return sorted(deduped.values(), key=lambda row: str(row[key]))


def canonical_text(raw: str) -> str:
    manifest = json.loads(raw)
    for path, key in SORTED_LISTS:
        rows = get_list(manifest, path)
        if rows is None:
            continue
        where = ".".join(path)
        normalized = sort_and_dedup(rows, key, where)
        node = manifest
        for parent_key in path[:-1]:
            node = node[parent_key]
        node[path[-1]] = normalized
    return json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="verify canonical form (default)")
    group.add_argument("--write", action="store_true", help="rewrite the file in place")
    parser.add_argument("--path", default=str(MANIFEST_PATH))
    args = parser.parse_args()

    path = Path(args.path)
    if not path.is_file():
        fail(f"missing {path}")

    raw = path.read_text(encoding="utf-8")
    try:
        canonical = canonical_text(raw)
    except json.JSONDecodeError as error:
        fail(f"invalid JSON in {path}: {error}")

    if args.write:
        if raw != canonical:
            path.write_text(canonical, encoding="utf-8")
            print(f"normalized {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")
        else:
            print("already canonical")
        return 0

    if raw != canonical:
        print(
            "proof-manifest.json is not canonical (sorted growth lists + deduped). "
            "Run: script/normalize_proof_manifest.py --write",
            file=sys.stderr,
        )
        return 1
    print("proof-manifest.json is canonical.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
