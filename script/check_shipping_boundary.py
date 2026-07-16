#!/usr/bin/env python3
"""Verify that research and proof code cannot enter the SteadyType product.

The strict source-membership checks activate when the package contains the
AutocompleteLabResearch target. This lets the target split land atomically
without making the pre-split package red. The trace replay product invariant is
always checked because that tool already exists as a separate executable.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import PurePosixPath
from typing import Any


SHIPPING_PRODUCT = "SteadyType"
RESEARCH_TARGET = "AutocompleteLabResearch"
TRACE_REPLAY_PRODUCT = "AutocompleteTraceReplay"
FORBIDDEN_TARGET_NAME = re.compile(
    r"(?:experiment|research|replay|personaliz|proof)",
    re.IGNORECASE,
)

# Exact source basenames whose top-level types exist only for local research,
# replay, personalization, or proof workflows. Do not replace these entries
# with a broad "replay" text match: KeyboardEventReplay is required shipping
# compatibility behavior in KeyboardEventTap.swift.
NONSHIPPING_SOURCE_BASENAMES = frozenset(
    {
        # Experiment and offline evaluation support.
        "AutocompleteExperimentArm.swift",
        "AutocompleteExperimentPlan.swift",
        "CompletionPredictionQualityEval.swift",
        "DailyDriverPhraseQualityEval.swift",
        "EvalV2BlindCorpus.swift",
        "HumanJudgedSuggestionRound.swift",
        "OfflineModelQualityEval.swift",
        "SuggestionUsefulnessScorecardEval.swift",
        "WordCompletionQualityEval.swift",
        # Trace replay and research-only scorecards. The trace analyzer and
        # report generator remain shipping privacy/diagnostics dependencies:
        # they power the local, redacted export available from Settings.
        "AutocompleteTraceReplay.swift",
        "BetaAcceptanceScorecard.swift",
        # Personalization and personal capture.
        "AcceptedAndKeptLearning.swift",
        "AcceptedTextStyleMemory.swift",
        "PersonalCaptureEpisodeStore.swift",
        "PersonalCaptureJournalWriter.swift",
        "PersonalCapturePolicy.swift",
        "RecentWordMemory.swift",
        # Proof-only policies, commands, and capture helpers.
        "AppProofCommandRunner.swift",
        "AppProofModeCoordinator.swift",
        "AutocompleteTraceProofMetadata.swift",
        "ClaudeCodeTerminalHostProofPolicy.swift",
        "GenericAppSafetyProofHarness.swift",
        "ObsidianProofDocumentInsertionPlan.swift",
        "PrivacyExportProofCommand.swift",
        "ProofActivationModePolicy.swift",
        "ProofModeAppEnablementPolicy.swift",
        "ProofModeScopePolicy.swift",
        "ProofOnlyAcceptCommand.swift",
        "ProofOnlyAcceptRecentSuggestionPolicy.swift",
        "RuntimeProofOptions.swift",
        "SensitiveFieldProofHarness.swift",
        "SuggestionAcceptanceProofPolicy.swift",
    }
)


class BoundaryFailure(Exception):
    """A deterministic package-boundary violation."""


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--describe-json",
        metavar="PATH",
        help="read an injected `swift package describe --type json` result",
    )
    return parser.parse_args()


def load_description(injected_path: str | None) -> dict[str, Any]:
    if injected_path:
        try:
            with open(injected_path, encoding="utf-8") as handle:
                return json.load(handle)
        except (OSError, json.JSONDecodeError) as error:
            raise BoundaryFailure(
                f"unable to read package description {injected_path}: {error}"
            ) from error

    result = subprocess.run(
        ["swift", "package", "describe", "--type", "json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "no output"
        raise BoundaryFailure(f"swift package describe failed: {detail}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise BoundaryFailure(f"swift package describe returned invalid JSON: {error}") from error


def named_entries(entries: Any, label: str) -> dict[str, dict[str, Any]]:
    if not isinstance(entries, list):
        raise BoundaryFailure(f"package description is missing {label}")

    result: dict[str, dict[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
            raise BoundaryFailure(f"package description contains a malformed {label} entry")
        name = entry["name"]
        if name in result:
            raise BoundaryFailure(f"package description contains duplicate {label} name {name}")
        result[name] = entry
    return result


def target_dependencies(target: dict[str, Any]) -> list[str]:
    dependencies = target.get("target_dependencies", [])
    if dependencies is None:
        return []
    if not isinstance(dependencies, list) or not all(
        isinstance(dependency, str) for dependency in dependencies
    ):
        raise BoundaryFailure(f"target {target['name']} has malformed target_dependencies")
    return dependencies


def product_target_closure(
    product: dict[str, Any], targets: dict[str, dict[str, Any]]
) -> set[str]:
    roots = product.get("targets")
    if not isinstance(roots, list) or not roots or not all(
        isinstance(root, str) for root in roots
    ):
        raise BoundaryFailure(f"product {product['name']} has malformed targets")

    closure: set[str] = set()
    pending = list(roots)
    while pending:
        name = pending.pop()
        if name in closure:
            continue
        target = targets.get(name)
        if target is None:
            raise BoundaryFailure(
                f"product {product['name']} references missing target {name}"
            )
        closure.add(name)
        pending.extend(target_dependencies(target))
    return closure


def product_memberships(target: dict[str, Any]) -> set[str]:
    memberships = target.get("product_memberships", [])
    if memberships is None:
        return set()
    if not isinstance(memberships, list) or not all(
        isinstance(membership, str) for membership in memberships
    ):
        raise BoundaryFailure(f"target {target['name']} has malformed product_memberships")
    return set(memberships)


def verify_trace_replay_tool(
    products: dict[str, dict[str, Any]], targets: dict[str, dict[str, Any]]
) -> None:
    product = products.get(TRACE_REPLAY_PRODUCT)
    if product is None:
        raise BoundaryFailure("AutocompleteTraceReplay must remain a separate product")
    if product.get("targets") != [TRACE_REPLAY_PRODUCT]:
        raise BoundaryFailure(
            "AutocompleteTraceReplay product must contain only its executable target"
        )
    product_type = product.get("type")
    if not isinstance(product_type, dict) or "executable" not in product_type:
        raise BoundaryFailure("AutocompleteTraceReplay product must remain executable")

    target = targets.get(TRACE_REPLAY_PRODUCT)
    if target is None or target.get("type") != "executable":
        raise BoundaryFailure("AutocompleteTraceReplay executable target is missing")
    memberships = product_memberships(target)
    if TRACE_REPLAY_PRODUCT not in memberships:
        raise BoundaryFailure(
            "AutocompleteTraceReplay target is not a member of its separate product"
        )
    if SHIPPING_PRODUCT in memberships:
        raise BoundaryFailure("AutocompleteTraceReplay target leaked into SteadyType")


def shipping_target_names(
    shipping_product: dict[str, Any], targets: dict[str, dict[str, Any]]
) -> set[str]:
    closure = product_target_closure(shipping_product, targets)
    described_members = {
        name
        for name, target in targets.items()
        if SHIPPING_PRODUCT in product_memberships(target)
    }
    return closure | described_members


def target_source_paths(target: dict[str, Any]) -> list[PurePosixPath]:
    sources = target.get("sources", [])
    if sources is None:
        return []
    if not isinstance(sources, list) or not all(isinstance(source, str) for source in sources):
        raise BoundaryFailure(f"target {target['name']} has malformed sources")

    target_path = target.get("path")
    if target_path is not None and not isinstance(target_path, str):
        raise BoundaryFailure(f"target {target['name']} has malformed path")
    base = PurePosixPath(target_path) if target_path else PurePosixPath()
    return [base / PurePosixPath(source) for source in sources]


def verify_shipping_boundary(
    products: dict[str, dict[str, Any]], targets: dict[str, dict[str, Any]]
) -> None:
    shipping_product = products.get(SHIPPING_PRODUCT)
    if shipping_product is None:
        raise BoundaryFailure("SteadyType executable product is missing")

    research = targets.get(RESEARCH_TARGET)
    if research is None:
        raise BoundaryFailure(
            "internal error: strict boundary ran before AutocompleteLabResearch appeared"
        )

    # The named denylist catches known files accidentally left in an otherwise
    # shipping target. The research target's exact source set catches future
    # additions without relying on broad words such as "replay".
    denied_source_basenames = NONSHIPPING_SOURCE_BASENAMES | {
        source_path.name for source_path in target_source_paths(research)
    }
    shipping_targets = shipping_target_names(shipping_product, targets)
    violations: list[str] = []
    for target_name in sorted(shipping_targets):
        target = targets[target_name]
        module_names = {target_name}
        c99name = target.get("c99name")
        if isinstance(c99name, str):
            module_names.add(c99name)
        forbidden_names = sorted(
            name for name in module_names if FORBIDDEN_TARGET_NAME.search(name)
        )
        if forbidden_names:
            violations.append(
                f"shipping target/module has a nonshipping name: {', '.join(forbidden_names)}"
            )

        for source_path in target_source_paths(target):
            if source_path.name in denied_source_basenames:
                violations.append(
                    f"shipping target {target_name} contains nonshipping source {source_path}"
                )

    if RESEARCH_TARGET in shipping_targets or SHIPPING_PRODUCT in product_memberships(research):
        violations.append("AutocompleteLabResearch is transitively included in SteadyType")

    if violations:
        raise BoundaryFailure("\n".join(violations))

    print(
        "Shipping boundary verified: "
        f"{len(shipping_targets)} SteadyType target(s); "
        "AutocompleteLabResearch and denied sources excluded."
    )


def main() -> int:
    try:
        description = load_description(parse_arguments().describe_json)
        products = named_entries(description.get("products"), "products")
        targets = named_entries(description.get("targets"), "targets")
        verify_trace_replay_tool(products, targets)
        print("Trace replay tool verified: separate executable product.")

        if RESEARCH_TARGET not in targets:
            print(
                "Shipping boundary pending: AutocompleteLabResearch target is not present; "
                "strict source checks deferred."
            )
            return 0

        verify_shipping_boundary(products, targets)
        return 0
    except BoundaryFailure as error:
        print(f"shipping boundary check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
