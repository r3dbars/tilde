#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SCORECARD = ROOT_DIR / "docs/product/steadytype-product-scorecard.md"

REQUIRED_AREAS = [
    "suggestion quality",
    "placement",
    "tab safety",
    "latency",
    "privacy",
    "app coverage",
    "onboarding",
    "controls",
    "diagnostics",
    "model readiness",
    "beta readiness",
    "test/proof coverage",
]

EVIDENCE_MARKERS = (
    "`./script/",
    "`script/",
    "`swift test",
    "`git ",
    "docs/product/",
    "docs/evals/",
    "Tests/",
    "Sources/",
    ".png",
    "trace slice",
    "screenshot",
    "proof manifest row",
    "documented manual gate",
    "manual gate",
    "lines ",
)

NEXT_PROOF_MARKERS = (
    "`./script/",
    "`script/",
    "documented manual gate",
    "manual gate",
    "proof-manifest",
    "proof manifest",
    "checklist",
)

LOW_SCORE_PATTERNS = (
    ("stale", re.compile(r"\bstale\b"), 75),
    ("pending", re.compile(r"\bpending\b"), 75),
    ("blocked", re.compile(r"\bblocked\b"), 75),
    ("missing", re.compile(r"\bmissing\b"), 75),
    ("failed", re.compile(r"\b(?:failed|failing)\b"), 85),
)

PERFECT_SCORE_UNRESOLVED_PATTERNS = (
    ("stale", re.compile(r"\bstale\b")),
    ("pending", re.compile(r"\bpending\b")),
    ("blocked", re.compile(r"\bblocked\b")),
    ("missing", re.compile(r"\bmissing\b")),
    ("failed", re.compile(r"\b(?:failed|failing)\b")),
    ("incomplete", re.compile(r"\bincomplete\b")),
    ("open gap", re.compile(r"\b(?:open|remaining)\b[^.]*\b(?:gap|proof|gate|lane|issue|item|row)s?\b|\bgaps?\b")),
    ("still needs", re.compile(r"\bstill\s+(?:needs?|requires?|depends)\b")),
    (
        "needs proof",
        re.compile(
            r"\bneeds?\s+(?:fresh|current|manual|proof|evidence|screenshot|latency|runtime|app|signed|notarized|distribution|tester|walkthrough|gate)\b"
        ),
    ),
    ("short of", re.compile(r"\bshort of\b")),
    ("not yet", re.compile(r"\bnot yet\b")),
    ("not complete", re.compile(r"\bnot complete\b|\bbefore\b[^.]*\bcomplete\b")),
)

PERFECT_SCORE_NEXT_PROOF_ACTION = re.compile(
    r"^\s*(?:add|check|close|finish|notarize|produce|record|refresh|recheck|rerun|run|staple|validate|verify)\b"
)


def split_markdown_row(line: str) -> list[str]:
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]

    cells: list[str] = []
    current: list[str] = []
    in_code = False
    for character in body:
        if character == "`":
            in_code = not in_code
            current.append(character)
            continue
        if character == "|" and not in_code:
            cells.append("".join(current).strip())
            current = []
            continue
        current.append(character)
    cells.append("".join(current).strip())
    return cells


def normalize_area(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def parse_score(value: str, area: str, failures: list[str]) -> int | None:
    match = re.fullmatch(r"([0-9]{1,3})/100", value.strip())
    if not match:
        failures.append(f"{area}: score must look like N/100, got {value!r}")
        return None
    score = int(match.group(1))
    if not 0 <= score <= 100:
        failures.append(f"{area}: score must be between 0 and 100, got {score}")
        return None
    return score


def parse_rows(source: str, failures: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    in_table = False
    headers: list[str] = []

    for raw_line in source.splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            if in_table and rows:
                break
            continue

        cells = split_markdown_row(line)
        lowered = [cell.lower() for cell in cells]
        if lowered[:5] == ["area", "score", "evidence", "why it is not higher", "next proof"]:
            headers = lowered
            in_table = True
            continue
        if not in_table:
            continue
        if set("".join(cells)) <= {"-", ":", " "}:
            continue
        if len(cells) != len(headers):
            failures.append(f"score row has {len(cells)} cells, expected {len(headers)}: {line}")
            continue
        rows.append(dict(zip(headers, cells)))

    if not rows:
        failures.append("missing score table with Area, Score, Evidence, Why It Is Not Higher, and Next Proof columns")
    return rows


def parse_overall(source: str, failures: list[str]) -> int | None:
    match = re.search(r"^Overall score:\s*([0-9]{1,3})/100\.\s*$", source, re.MULTILINE)
    if not match:
        failures.append("missing overall score line")
        return None
    overall = int(match.group(1))
    if not 0 <= overall <= 100:
        failures.append(f"overall score must be between 0 and 100, got {overall}")
        return None
    return overall


def validate_scorecard(path: Path) -> list[str]:
    failures: list[str] = []
    try:
        source = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return [f"missing scorecard: {path}"]

    overall = parse_overall(source, failures)
    rows = parse_rows(source, failures)
    seen: dict[str, tuple[int, str]] = {}

    for row in rows:
        raw_area = row["area"]
        area = normalize_area(raw_area)
        if area in seen:
            failures.append(f"duplicate score row: {raw_area}")
            continue

        score = parse_score(row["score"], raw_area, failures)
        if score is None:
            continue
        seen[area] = (score, raw_area)

        evidence = row["evidence"]
        next_proof = row["next proof"]
        combined = " ".join(row.values()).lower()

        if any(bad in combined for bad in ("tbd", "todo", "vibes", "round up", "green enough")):
            failures.append(f"{raw_area}: scorecard language must stay evidence-based")

        if not any(marker.lower() in evidence.lower() for marker in EVIDENCE_MARKERS):
            failures.append(f"{raw_area}: evidence must name a command, trace slice, screenshot, proof row, or documented manual gate")

        if not any(marker.lower() in next_proof.lower() for marker in NEXT_PROOF_MARKERS):
            failures.append(f"{raw_area}: next proof must name a command or documented manual gate")

        for term, pattern, maximum in LOW_SCORE_PATTERNS:
            if pattern.search(combined) and score > maximum:
                failures.append(f"{raw_area}: contains {term!r}, so score must stay <= {maximum}/100")

        if score == 100:
            unresolved_terms = [
                term for term, pattern in PERFECT_SCORE_UNRESOLVED_PATTERNS if pattern.search(combined)
            ]
            if PERFECT_SCORE_NEXT_PROOF_ACTION.search(next_proof.lower()):
                unresolved_terms.append("unfinished next proof")
            if unresolved_terms:
                joined = ", ".join(dict.fromkeys(unresolved_terms))
                failures.append(f"{raw_area}: 100/100 requires resolved row gates; unresolved language found: {joined}")

    missing = [area for area in REQUIRED_AREAS if area not in seen]
    extra = [raw for key, (_, raw) in seen.items() if key not in REQUIRED_AREAS]
    for area in missing:
        failures.append(f"missing required score area: {area}")
    for area in extra:
        failures.append(f"unexpected score area: {area}")

    if overall is not None and len(seen) == len(REQUIRED_AREAS):
        average = sum(score for score, _ in seen.values()) / len(REQUIRED_AREAS)
        expected = math.floor(average + 0.5)
        if overall != expected:
            failures.append(f"overall score is {overall}/100, expected rounded average {expected}/100")

    return failures


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT_DIR))
    except ValueError:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the SteadyType product scorecard.")
    parser.add_argument(
        "--scorecard",
        default=str(DEFAULT_SCORECARD),
        help="Path to the scorecard markdown file.",
    )
    args = parser.parse_args()

    path = Path(args.scorecard)
    if not path.is_absolute():
        path = ROOT_DIR / path

    failures = validate_scorecard(path)
    if failures:
        print("SteadyType scorecard check failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"SteadyType scorecard verified: {display_path(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
