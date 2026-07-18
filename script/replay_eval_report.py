#!/usr/bin/env python3
"""Render aggregate SteadyType replay/live trend JSONL as markdown."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


ALLOWED_KEYS = {
    "dateISO",
    "gitSHA",
    "engine",
    "model",
    "decodingVariant",
    "fewShotSource",
    "promptContextCharacters",
    "promptFormat",
    "variant",
    "corpusKind",
    "caseCount",
    "keystrokesSavedPerCase",
    "shownKeystrokesSavedPerCase",
    "missedMagicRate",
    "top1WordAccuracy",
    "wordPrefixAccuracy2",
    "wordPrefixAccuracy3",
    "wordPrefixAccuracy4",
    "suggestionRate",
    "wrongFirstWordRate",
    "endToEndP95LatencyMs",
    "modelResultLatencyP50Ms",
    "visibleCompletionAcceptanceQualityRate",
    "suffixEnabled",
    "acceptedAndKeptRate",
    "acceptRate",
}


def load_rows(paths: list[Path], check_privacy: bool) -> list[dict]:
    rows: list[dict] = []
    forbidden: set[str] = set()
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError as error:
            print(f"warning: skipped {path}: {error}", file=sys.stderr)
            continue
        for line in lines:
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except (json.JSONDecodeError, TypeError) as error:
                if check_privacy:
                    raise ValueError(f"invalid trend row in {path}: {error}") from error
                continue
            if not isinstance(row, dict):
                if check_privacy:
                    raise ValueError(f"non-object trend row in {path}")
                continue
            extra = set(row) - ALLOWED_KEYS
            forbidden.update(extra)
            if extra:
                continue
            rows.append(row)
    if check_privacy and forbidden:
        raise ValueError("forbidden trend keys: " + ", ".join(sorted(forbidden)))
    return rows


def percent(value: object) -> str:
    return f"{float(value or 0) * 100:.1f}%"


def render(rows: list[dict]) -> str:
    grouped: dict[tuple[str, str, str], list[dict]] = defaultdict(list)
    for row in rows:
        grouped[(
            str(row.get("model", "unknown")),
            str(row.get("promptFormat", "unknown")),
            str(row.get("variant", "unknown")),
        )].append(row)

    sections = ["# SteadyType Eval Trends"]
    if not grouped:
        return "\n\n".join(sections + ["No valid aggregate trend rows found."]) + "\n"

    for (model, prompt_format, variant), group in sorted(grouped.items()):
        sections.append(f"## {model} / {prompt_format} / {variant}")
        sections.append(
            "| Date | Engine | Corpus | Cases | Raw keys/case | Shown keys/case | Missed magic | Model p50/p95 ms | Visible completion quality | Top-1 | Prefix 2/3/4 | Suggest | Wrong first | Accept | Accepted + kept |\n"
            "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
            + "\n".join(
                "| {date} | {engine} | {corpus} | {cases} | {keys:.2f} | {shown:.2f} | {missed} | {latency} | {quality} | {top1} | {prefixes} | {suggest} | {wrong} | {accept} | {kept} |".format(
                    date=str(row.get("dateISO", "")),
                    engine=str(row.get("engine", "")),
                    corpus=str(row.get("corpusKind", "")),
                    cases=int(row.get("caseCount", 0) or 0),
                    keys=float(row.get("keystrokesSavedPerCase", 0) or 0),
                    shown=float(row.get("shownKeystrokesSavedPerCase", 0) or 0),
                    missed=percent(row.get("missedMagicRate")),
                    latency="{}/{}".format(
                        "—" if row.get("modelResultLatencyP50Ms") is None else f"{float(row['modelResultLatencyP50Ms']):.0f}",
                        "—" if row.get("endToEndP95LatencyMs") is None else f"{float(row['endToEndP95LatencyMs']):.0f}",
                    ),
                    quality=percent(row.get("visibleCompletionAcceptanceQualityRate")) if row.get("visibleCompletionAcceptanceQualityRate") is not None else "—",
                    top1=percent(row.get("top1WordAccuracy")),
                    prefixes="/".join(percent(row.get(key)) for key in ("wordPrefixAccuracy2", "wordPrefixAccuracy3", "wordPrefixAccuracy4")),
                    suggest=percent(row.get("suggestionRate")),
                    wrong=percent(row.get("wrongFirstWordRate")),
                    accept="—" if row.get("acceptRate") is None else percent(row.get("acceptRate")),
                    kept="—" if row.get("acceptedAndKeptRate") is None else percent(row.get("acceptedAndKeptRate")),
                )
                for row in sorted(group, key=lambda item: str(item.get("dateISO", "")))
            )
        )
    return "\n\n".join(sections) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="Replay/live trend JSONL file(s).")
    parser.add_argument("--check-privacy", action="store_true", help="Fail if a decoded row has a non-aggregate key.")
    args = parser.parse_args()
    try:
        rows = load_rows(args.paths, check_privacy=args.check_privacy)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    print(render(rows), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
