#!/usr/bin/env python3
"""Canonicalize the public-core reachability allowlist (.psv).

The allowlist is append-only and edited by nearly every PR, so it is the classic
parallel-branch conflict magnet. `.gitattributes` marks it `merge=union` so git
auto-merges concurrent appends, but union can leave the file unsorted and can
duplicate a row that both sides added. This script re-asserts the canonical form:

    * a stable header comment block, preserved verbatim at the top
    * data rows sorted by (Source, Type)
    * exact-duplicate rows collapsed (the harmless artifact of a union merge)

Conflicting rows -- the same Type with a different Classification/Source/Reason --
are NOT collapsed: that is a real ambiguity a human must resolve, so we fail loudly.

Usage:
    normalize_public_core_allowlist.py            # alias for --check
    normalize_public_core_allowlist.py --check     # exit 1 if not canonical
    normalize_public_core_allowlist.py --write      # rewrite in place

The matching `--check` runs as a blocking CI lane (script/proof.sh) so the file
can never silently drift out of canonical form or land a conflicting duplicate.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWLIST_PATH = ROOT / "docs" / "product" / "public-core-reachability-allowlist.psv"
ALLOWED_CLASSIFICATIONS = {"experimental", "research", "proof-only"}
FIELDS = 4


def fail(message: str) -> "None":
    print(f"normalize allowlist failed: {message}", file=sys.stderr)
    raise SystemExit(2)


def canonical_text(raw: str) -> str:
    """Return the canonical rendering of the allowlist, or fail on conflicts."""
    header: list[str] = []
    rows: dict[str, tuple[str, str, str, str]] = {}
    seen_data = False

    for index, raw_line in enumerate(raw.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            # Header comments/blanks are only meaningful before the first data
            # row; keep that leading block verbatim and drop stray trailing blanks.
            if not seen_data:
                header.append(raw_line.rstrip())
            continue

        seen_data = True
        parts = [part.strip() for part in line.split("|")]
        if len(parts) != FIELDS:
            fail(f"malformed row {index}: {raw_line!r}")
        name, classification, source, reason = parts
        if not all(parts):
            fail(f"empty field on row {index}: {raw_line!r}")
        if classification not in ALLOWED_CLASSIFICATIONS:
            fail(
                f"unknown classification '{classification}' for {name}; "
                f"use one of {', '.join(sorted(ALLOWED_CLASSIFICATIONS))}"
            )

        entry = (name, classification, source, reason)
        existing = rows.get(name)
        if existing is not None and existing != entry:
            fail(
                f"conflicting allowlist rows for {name}: "
                f"{'|'.join(existing)}  vs  {'|'.join(entry)} -- resolve by hand"
            )
        rows[name] = entry

    # Trim a trailing run of blank header lines so the body starts cleanly.
    while header and header[-1] == "":
        header.pop()

    ordered = sorted(rows.values(), key=lambda entry: (entry[2], entry[0]))
    lines = list(header)
    lines.extend("|".join(entry) for entry in ordered)
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="verify canonical form (default)")
    group.add_argument("--write", action="store_true", help="rewrite the file in place")
    parser.add_argument("--path", default=str(ALLOWLIST_PATH))
    args = parser.parse_args()

    path = Path(args.path)
    if not path.is_file():
        fail(f"missing {path}")

    raw = path.read_text(encoding="utf-8")
    canonical = canonical_text(raw)

    if args.write:
        if raw != canonical:
            path.write_text(canonical, encoding="utf-8")
            print(f"normalized {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")
        else:
            print("already canonical")
        return 0

    if raw != canonical:
        print(
            "public-core allowlist is not canonical (sorted + deduped). "
            "Run: script/normalize_public_core_allowlist.py --write",
            file=sys.stderr,
        )
        return 1
    print("public-core allowlist is canonical.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
