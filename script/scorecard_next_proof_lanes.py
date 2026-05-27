#!/usr/bin/env python3
"""Print the lowest-score proof lanes from the SteadyType scorecard."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_SCORECARD = Path("docs/product/steadytype-product-scorecard.md")


@dataclass(frozen=True)
class ProofLane:
    area: str
    score: int
    next_proof: str


MANUAL_BLOCKER_PATTERNS = (
    r"\brecord\b.*\bproof\b",
    r"\brecord\b.*\brun\b",
    r"\bcomplete\b.*\bchecklist\b",
    r"\bclean-user\b",
    r"\bclean user\b",
    r"\bguided\b.*\bwalkthrough\b",
    r"\bgrant accessibility\b",
    r"\bdocumented manual gate\b",
    r"\bmanual gate\b",
    r"\bhuman\b",
)


def strip_markdown(text: str) -> str:
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def load_lanes(scorecard_path: Path) -> list[ProofLane]:
    lines = scorecard_path.read_text(encoding="utf-8").splitlines()
    lanes: list[ProofLane] = []
    in_scores_table = False

    for line in lines:
        if line.startswith("| Area | Score | Evidence | Why It Is Not Higher | Next Proof |"):
            in_scores_table = True
            continue

        if not in_scores_table:
            continue

        if line.startswith("| ---"):
            continue

        if not line.startswith("|"):
            break

        cells = split_table_row(line)
        if len(cells) != 5:
            continue

        area, score_text, _, _, next_proof = cells
        score_match = re.search(r"\d+", score_text)
        if not score_match:
            continue

        lanes.append(
            ProofLane(
                area=strip_markdown(area),
                score=int(score_match.group(0)),
                next_proof=strip_markdown(next_proof),
            )
        )

    return lanes


def is_automation_ready(lane: ProofLane) -> bool:
    proof = lane.next_proof.lower()
    return not any(re.search(pattern, proof) for pattern in MANUAL_BLOCKER_PATTERNS)


def format_lanes(
    lanes: list[ProofLane],
    limit: int,
    *,
    automation_ready_only: bool = False,
) -> str:
    if automation_ready_only:
        lanes = [lane for lane in lanes if is_automation_ready(lane)]

    ranked = sorted(lanes, key=lambda lane: (lane.score, lane.area.lower()))[:limit]
    if not ranked:
        if automation_ready_only:
            return "No automation-ready proof lanes found."
        return "No proof lanes found."

    if automation_ready_only:
        lines = ["Automation-ready proof lanes:"]
    else:
        lines = ["Next proof lanes:"]
    for lane in ranked:
        lines.append(f"- {lane.area} ({lane.score}/100): {lane.next_proof}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize the lowest-score next-proof lanes from the scorecard."
    )
    parser.add_argument(
        "--scorecard",
        type=Path,
        default=DEFAULT_SCORECARD,
        help=f"Scorecard path. Default: {DEFAULT_SCORECARD}",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=5,
        help="Number of lanes to print. Default: 5",
    )
    parser.add_argument(
        "--automation-ready",
        action="store_true",
        help="Skip lanes whose next proof requires a clean-user/manual-permission run.",
    )
    args = parser.parse_args()

    if args.limit < 1:
        print("--limit must be a positive integer", file=sys.stderr)
        return 2

    if not args.scorecard.exists():
        print(f"scorecard not found: {args.scorecard}", file=sys.stderr)
        return 2

    lanes = load_lanes(args.scorecard)
    if not lanes:
        print(f"no score rows found in: {args.scorecard}", file=sys.stderr)
        return 1

    print(format_lanes(lanes, args.limit, automation_ready_only=args.automation_ready))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
