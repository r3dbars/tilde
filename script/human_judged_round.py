#!/usr/bin/env python3
"""Build a blind 50-pair human suggestion judging round.

The judge-facing round file intentionally omits candidate labels and scores.
The key file is separate so results can be joined only after judgments exist.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import tempfile
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "pair_id",
    "case_id",
    "text_before_cursor",
    "candidate_a_id",
    "candidate_a",
    "candidate_b_id",
    "candidate_b",
}


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{path}:{line_number}: invalid JSON: {exc}") from exc
        missing = sorted(REQUIRED_FIELDS - row.keys())
        if missing:
            raise SystemExit(f"{path}:{line_number}: missing fields: {', '.join(missing)}")
        rows.append(row)
    return rows


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True))
            handle.write("\n")


def round_item_id(index: int) -> str:
    return f"round-{index + 1:03d}"


def build_round(
    rows: list[dict[str, Any]],
    *,
    count: int,
    seed: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    if count <= 0:
        raise SystemExit("--count must be greater than zero")

    seen_pair_ids: set[str] = set()
    for row in rows:
        pair_id = str(row["pair_id"])
        if pair_id in seen_pair_ids:
            raise SystemExit(f"duplicate pair_id: {pair_id}")
        seen_pair_ids.add(pair_id)
        for field in REQUIRED_FIELDS:
            if str(row[field]).strip() == "":
                raise SystemExit(f"{pair_id}: blank field: {field}")
        if row["candidate_a_id"] == row["candidate_b_id"]:
            raise SystemExit(f"{pair_id}: candidate ids must differ")

    if len(rows) < count:
        raise SystemExit(f"need at least {count} candidate pairs; found {len(rows)}")

    rng = random.Random(seed)
    selected = list(rows)
    rng.shuffle(selected)
    selected = selected[:count]

    round_rows: list[dict[str, Any]] = []
    key_rows: list[dict[str, Any]] = []
    judgment_rows: list[dict[str, Any]] = []

    for index, row in enumerate(selected):
        item_id = round_item_id(index)
        first_goes_left = rng.choice([True, False])
        if first_goes_left:
            left_id, left_text = row["candidate_a_id"], row["candidate_a"]
            right_id, right_text = row["candidate_b_id"], row["candidate_b"]
        else:
            left_id, left_text = row["candidate_b_id"], row["candidate_b"]
            right_id, right_text = row["candidate_a_id"], row["candidate_a"]

        round_rows.append(
            {
                "item_id": item_id,
                "case_id": row["case_id"],
                "text_before_cursor": row["text_before_cursor"],
                "left_suggestion": left_text,
                "right_suggestion": right_text,
            }
        )
        key_rows.append(
            {
                "item_id": item_id,
                "pair_id": row["pair_id"],
                "left_candidate_id": left_id,
                "right_candidate_id": right_id,
            }
        )
        judgment_rows.append(
            {
                "item_id": item_id,
                "winner": "",
                "reason_tags": [],
                "notes": "",
            }
        )

    return round_rows, key_rows, judgment_rows


def run_self_test() -> None:
    fixture_rows = [
        {
            "pair_id": f"pair-{index:03d}",
            "case_id": f"case-{index:03d}",
            "text_before_cursor": f"Disposable prompt {index} should",
            "candidate_a_id": f"baseline-{index:03d}",
            "candidate_a": f"finish plainly {index}",
            "candidate_b_id": f"challenger-{index:03d}",
            "candidate_b": f"continue quietly {index}",
        }
        for index in range(1, 61)
    ]

    round_rows, key_rows, judgment_rows = build_round(
        fixture_rows,
        count=50,
        seed="self-test",
    )

    assert len(round_rows) == 50
    assert len(key_rows) == 50
    assert len(judgment_rows) == 50
    assert [row["item_id"] for row in round_rows] == [row["item_id"] for row in key_rows]
    assert all("candidate_id" not in key for row in round_rows for key in row)
    assert all(row["winner"] == "" and row["reason_tags"] == [] and row["notes"] == "" for row in judgment_rows)
    assert any(row["left_candidate_id"].startswith("challenger-") for row in key_rows)
    assert any(row["right_candidate_id"].startswith("challenger-") for row in key_rows)

    with tempfile.TemporaryDirectory() as temp_dir:
        base = Path(temp_dir)
        write_jsonl(base / "round.jsonl", round_rows)
        write_jsonl(base / "key.jsonl", key_rows)
        write_jsonl(base / "judgments-template.jsonl", judgment_rows)
        assert (base / "round.jsonl").read_text(encoding="utf-8").count("\n") == 50

    print("Human judged round scaffold: PASS")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="JSONL candidate-pair input")
    parser.add_argument("--round-output", type=Path, help="Judge-facing blind JSONL output")
    parser.add_argument("--key-output", type=Path, help="Hidden answer-key JSONL output")
    parser.add_argument("--judgments-output", type=Path, help="Blank judgment template JSONL output")
    parser.add_argument("--count", type=int, default=50)
    parser.add_argument("--seed", default="wave4-human-round-1")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        run_self_test()
        return 0

    required_paths = {
        "--input": args.input,
        "--round-output": args.round_output,
        "--key-output": args.key_output,
        "--judgments-output": args.judgments_output,
    }
    missing = [flag for flag, value in required_paths.items() if value is None]
    if missing:
        raise SystemExit(f"missing required arguments: {', '.join(missing)}")

    rows = load_jsonl(args.input)
    round_rows, key_rows, judgment_rows = build_round(
        rows,
        count=args.count,
        seed=args.seed,
    )
    write_jsonl(args.round_output, round_rows)
    write_jsonl(args.key_output, key_rows)
    write_jsonl(args.judgments_output, judgment_rows)
    print(f"Wrote {len(round_rows)} blind suggestion pairs to {args.round_output}")
    print(f"Wrote hidden key to {args.key_output}")
    print(f"Wrote blank judgments to {args.judgments_output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
