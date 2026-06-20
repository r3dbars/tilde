#!/usr/bin/env python3
"""Check that public core symbols are wired into the app or explicitly listed.

This is intentionally a small reachability check, not a Swift parser. It scans
top-level public type declarations in AutocompleteLabCore, treats names found in
AutocompleteLabApp as live roots, then follows simple name references through
core source files. Public symbols outside that reachable set must be listed in:

    docs/product/public-core-reachability-allowlist.psv

Allowlist rows use:

    Type|Classification|Source|Reason

Classification must be one of: experimental, research, proof-only.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CORE_DIR = ROOT / "Sources" / "AutocompleteLabCore"
APP_DIR = ROOT / "Sources" / "AutocompleteLabApp"
ALLOWLIST_PATH = ROOT / "docs" / "product" / "public-core-reachability-allowlist.psv"
ALLOWED_CLASSIFICATIONS = {"experimental", "research", "proof-only"}
TYPE_DECLARATION = re.compile(
    r"^\s*public\s+(?:final\s+)?(?:struct|enum|class|actor|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)


@dataclass(frozen=True)
class PublicType:
    name: str
    source: str


@dataclass(frozen=True)
class AllowlistEntry:
    classification: str
    source: str
    reason: str


def fail(message: str) -> None:
    print(f"public core wiring check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def swift_files(directory: Path) -> list[Path]:
    return sorted(path for path in directory.rglob("*.swift") if path.is_file())


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def strip_line_comment(line: str) -> str:
    return line.split("//", 1)[0]


def top_level_public_types() -> list[PublicType]:
    types: list[PublicType] = []
    for path in swift_files(CORE_DIR):
        depth = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            code = strip_line_comment(line)
            declaration = TYPE_DECLARATION.match(code)
            if declaration and depth == 0:
                types.append(PublicType(declaration.group(1), relative(path)))
            depth += code.count("{") - code.count("}")
            depth = max(depth, 0)
    return types


def contains_name(text: str, name: str) -> bool:
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", text) is not None


def reachable_types(types: list[PublicType]) -> set[str]:
    app_text = "\n".join(path.read_text(encoding="utf-8") for path in swift_files(APP_DIR))
    core_text_by_source = {
        relative(path): path.read_text(encoding="utf-8")
        for path in swift_files(CORE_DIR)
    }
    reachable = {public_type.name for public_type in types if contains_name(app_text, public_type.name)}

    changed = True
    while changed:
        changed = False
        for public_type in types:
            if public_type.name not in reachable:
                continue
            source_text = core_text_by_source[public_type.source]
            for candidate in types:
                if candidate.name not in reachable and contains_name(source_text, candidate.name):
                    reachable.add(candidate.name)
                    changed = True
    return reachable


def load_allowlist() -> dict[str, AllowlistEntry]:
    if not ALLOWLIST_PATH.is_file():
        fail(f"missing {relative(ALLOWLIST_PATH)}")

    entries: dict[str, AllowlistEntry] = {}
    for index, raw_line in enumerate(ALLOWLIST_PATH.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        parts = line.split("|")
        if len(parts) != 4:
            fail(f"malformed allowlist row {index}: {raw_line}")

        name, classification, source, reason = [part.strip() for part in parts]
        if not name or not classification or not source or not reason:
            fail(f"empty allowlist field on row {index}: {raw_line}")
        if classification not in ALLOWED_CLASSIFICATIONS:
            fail(
                f"unknown classification '{classification}' for {name}; "
                f"use one of {', '.join(sorted(ALLOWED_CLASSIFICATIONS))}"
            )
        entry = AllowlistEntry(classification, source, reason)
        existing = entries.get(name)
        if existing is not None and existing != entry:
            # Two rows for the same type that disagree are a real ambiguity a
            # human must resolve.
            fail(f"conflicting allowlist entries for {name}")
        # An exact-duplicate row is the harmless artifact of a `merge=union`
        # auto-merge (see .gitattributes); collapse it instead of failing.
        # script/normalize_public_core_allowlist.py removes it on write.
        entries[name] = entry
    return entries


def main() -> None:
    public_types = top_level_public_types()
    public_type_by_name = {public_type.name: public_type for public_type in public_types}
    if len(public_type_by_name) != len(public_types):
        duplicates = sorted(
            name for name in public_type_by_name
            if sum(1 for public_type in public_types if public_type.name == name) > 1
        )
        fail(f"duplicate public core type names: {', '.join(duplicates)}")

    reachable = reachable_types(public_types)
    allowlist = load_allowlist()
    missing = sorted(
        (
            public_type
            for public_type in public_types
            if public_type.name not in reachable and public_type.name not in allowlist
        ),
        key=lambda public_type: (public_type.source, public_type.name),
    )
    if missing:
        print("Public core symbols are neither app-reachable nor allowlisted:", file=sys.stderr)
        for public_type in missing:
            print(f"- {public_type.name} ({public_type.source})", file=sys.stderr)
        fail("add live app wiring or an allowlist row with classification experimental/research/proof-only")

    stale = sorted(name for name in allowlist if name not in public_type_by_name)
    if stale:
        fail(f"stale allowlist entries for missing public types: {', '.join(stale)}")

    wired_but_allowlisted = sorted(name for name in allowlist if name in reachable)
    if wired_but_allowlisted:
        fail(f"allowlist entries are now wired and should be removed: {', '.join(wired_but_allowlisted)}")

    source_mismatches = sorted(
        (name, entry.source, public_type_by_name[name].source)
        for name, entry in allowlist.items()
        if name in public_type_by_name and entry.source != public_type_by_name[name].source
    )
    if source_mismatches:
        for name, expected, actual in source_mismatches:
            print(f"{name}: allowlist source {expected}, actual source {actual}", file=sys.stderr)
        fail("allowlist source paths are stale")

    print(
        "Public core wiring verified: "
        f"{len(reachable)} reachable, {len(allowlist)} explicitly classified, {len(public_types)} total."
    )


if __name__ == "__main__":
    main()
