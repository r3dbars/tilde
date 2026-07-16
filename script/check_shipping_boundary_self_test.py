#!/usr/bin/env python3
"""Self-test for check_shipping_boundary.py using injected package JSON."""

from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "script" / "check_shipping_boundary.py"


def target(
    name: str,
    memberships: list[str],
    sources: list[str],
    dependencies: list[str] | None = None,
    target_type: str = "library",
) -> dict[str, Any]:
    return {
        "c99name": name,
        "name": name,
        "path": f"Sources/{name}",
        "product_memberships": memberships,
        "sources": sources,
        "target_dependencies": dependencies or [],
        "type": target_type,
    }


def fixture(*, split: bool) -> dict[str, Any]:
    targets = [
        target(
            "AutocompleteLabApp",
            ["SteadyType"],
            [
                "App/AppDelegate.swift",
                "Mac/CompatibilityLearningStore.swift",
                "Mac/KeyboardEventTap.swift",
            ],
            ["AutocompleteLabCore"],
            "executable",
        ),
        target(
            "AutocompleteLabCore",
            ["AutocompleteLabCore", "SteadyType", "AutocompleteTraceReplay"],
            [
                "Configuration/CompatibilityLearning.swift",
                "Engine/LocalCompletionEngine.swift",
                "Tracing/AutocompleteTraceEvent.swift",
                "Tracing/AutocompleteTracePrivacyFilter.swift",
                "Tracing/TracePrivacyFingerprint.swift",
            ],
        ),
        target(
            "AutocompleteTraceReplay",
            ["AutocompleteTraceReplay"],
            ["main.swift"],
            ["AutocompleteLabCore"],
            "executable",
        ),
    ]
    if split:
        targets.append(
            target(
                "AutocompleteLabResearch",
                ["AutocompleteLabResearch", "AutocompleteTraceReplay"],
                [
                    "Experiments/AutocompleteExperimentPlan.swift",
                    "Tracing/AutocompleteTraceReplay.swift",
                    "Session/PersonalCapturePolicy.swift",
                    "App/AppProofModeCoordinator.swift",
                    "ResearchOnlyHelper.swift",
                ],
                ["AutocompleteLabCore"],
            )
        )
        targets[2]["target_dependencies"].append("AutocompleteLabResearch")
    else:
        # The same source is intentionally tolerated only before the atomic
        # AutocompleteLabResearch split appears.
        targets[1]["sources"].append("Tracing/AutocompleteTraceReplay.swift")

    return {
        "products": [
            {
                "name": "SteadyType",
                "targets": ["AutocompleteLabApp"],
                "type": {"executable": None},
            },
            {
                "name": "AutocompleteTraceReplay",
                "targets": ["AutocompleteTraceReplay"],
                "type": {"executable": None},
            },
        ],
        "targets": targets,
    }


def run_case(
    temp_dir: Path,
    label: str,
    description: dict[str, Any],
    expected_status: int,
    expected_text: str,
) -> None:
    fixture_path = temp_dir / f"{label}.json"
    fixture_path.write_text(json.dumps(description), encoding="utf-8")
    result = subprocess.run(
        [sys.executable, str(CHECKER), "--describe-json", str(fixture_path)],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    if result.returncode != expected_status:
        raise SystemExit(
            f"{label}: expected exit {expected_status}, got {result.returncode}\n{output}"
        )
    if expected_text not in output:
        raise SystemExit(f"{label}: missing expected output {expected_text!r}\n{output}")


def main() -> None:
    with tempfile.TemporaryDirectory() as raw_temp_dir:
        temp_dir = Path(raw_temp_dir)
        pre_split = fixture(split=False)
        good_split = fixture(split=True)

        run_case(
            temp_dir,
            "pre-split-deferred",
            pre_split,
            0,
            "strict source checks deferred",
        )
        run_case(
            temp_dir,
            "good-split",
            good_split,
            0,
            "AutocompleteLabResearch and denied sources excluded",
        )

        leaked_research = copy.deepcopy(good_split)
        leaked_research["targets"][0]["target_dependencies"].append(
            "AutocompleteLabResearch"
        )
        run_case(
            temp_dir,
            "leaked-research",
            leaked_research,
            1,
            "AutocompleteLabResearch is transitively included in SteadyType",
        )

        leaked_source = copy.deepcopy(good_split)
        leaked_source["targets"][1]["sources"].append(
            "Experiments/AutocompleteExperimentPlan.swift"
        )
        run_case(
            temp_dir,
            "leaked-source",
            leaked_source,
            1,
            "contains nonshipping source",
        )

        leaked_research_source = copy.deepcopy(good_split)
        leaked_research_source["targets"][1]["sources"].append(
            "Support/ResearchOnlyHelper.swift"
        )
        run_case(
            temp_dir,
            "leaked-dynamic-research-source",
            leaked_research_source,
            1,
            "contains nonshipping source",
        )

        leaked_personalization = copy.deepcopy(good_split)
        leaked_personalization["targets"].append(
            target(
                "AutocompleteLabPersonalization",
                ["SteadyType"],
                ["SuggestionProfile.swift"],
            )
        )
        leaked_personalization["targets"][0]["target_dependencies"].append(
            "AutocompleteLabPersonalization"
        )
        run_case(
            temp_dir,
            "leaked-personalization-target",
            leaked_personalization,
            1,
            "shipping target/module has a nonshipping name",
        )

        for forbidden_name in (
            "AutocompleteLabExperimentSupport",
            "AutocompleteLabProofSupport",
        ):
            leaked_named_target = copy.deepcopy(good_split)
            leaked_named_target["targets"].append(
                target(forbidden_name, ["SteadyType"], ["Support.swift"])
            )
            leaked_named_target["targets"][0]["target_dependencies"].append(
                forbidden_name
            )
            run_case(
                temp_dir,
                f"leaked-{forbidden_name.lower()}",
                leaked_named_target,
                1,
                "shipping target/module has a nonshipping name",
            )

        missing_replay_product = copy.deepcopy(good_split)
        missing_replay_product["products"] = [missing_replay_product["products"][0]]
        run_case(
            temp_dir,
            "missing-replay-product",
            missing_replay_product,
            1,
            "AutocompleteTraceReplay must remain a separate product",
        )

        replay_leaked_into_app = copy.deepcopy(good_split)
        replay_leaked_into_app["targets"][2]["product_memberships"].append("SteadyType")
        run_case(
            temp_dir,
            "replay-leaked-into-app",
            replay_leaked_into_app,
            1,
            "AutocompleteTraceReplay target leaked into SteadyType",
        )

    print("Shipping boundary checker self-test passed.")


if __name__ == "__main__":
    main()
