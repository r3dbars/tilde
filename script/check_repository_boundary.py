#!/usr/bin/env python3
"""Fail when the shipped Tilde target graph crosses into Tilde Lab."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def dependency_names(target: dict[str, object]) -> set[str]:
    names: set[str] = set()
    for dependency in target.get("dependencies", []):
        if not isinstance(dependency, dict):
            continue
        for value in dependency.values():
            if isinstance(value, list) and value and isinstance(value[0], str):
                names.add(value[0])
    return names


def fail(message: str) -> None:
    print(f"repository boundary: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    result = subprocess.run(
        ["swift", "package", "dump-package"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    package = json.loads(result.stdout)
    targets = {target["name"]: target for target in package["targets"]}
    products = {product["name"]: product["targets"] for product in package["products"]}

    expected_products = {
        "Tilde": ["TildeApp"],
        "InlineGhostIME": ["InlineGhostIME"],
        "TildeLab": ["TildeLab"],
        "tilde-lab": ["TildeLabCLI"],
        "tilde-lab-runner": ["TildeLabRunner"],
    }
    if products != expected_products:
        fail(f"unexpected product map: {products!r}")

    expected_production_dependencies = {
        "TildeCore": set(),
        "TildeApp": {"TildeCore"},
        "InlineGhostIME": {"TildeCore"},
    }
    for name, expected in expected_production_dependencies.items():
        target = targets.get(name)
        if target is None:
            fail(f"missing production target {name}")
        actual = dependency_names(target)
        if actual != expected:
            fail(f"{name} dependencies are {sorted(actual)}, expected {sorted(expected)}")
        if any(dependency.startswith("TildeLab") for dependency in actual):
            fail(f"shipped target {name} depends on Tilde Lab")

    old_names = {"AutocompleteLabCore", "AutocompleteLabApp", "TildeResearchCLI", "tilde-research"}
    returned = set(targets) | set(products)
    if stale := sorted(old_names & returned):
        fail(f"ambiguous legacy names returned: {stale}")

    print("repository boundary: Tilde ships independently; Tilde Lab remains development-only")


if __name__ == "__main__":
    main()
