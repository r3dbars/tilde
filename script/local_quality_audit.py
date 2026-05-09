#!/usr/bin/env python3
"""Local opt-in quality audit for disposable autocomplete prompts.

The audit intentionally keeps raw prompts and raw model output in memory only.
By default it prints aggregate labels and row ids, not raw text.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


ROOT_DIR = Path(__file__).resolve().parents[1]
OPT_IN_ENV = "AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT"
RAW_ENV = "AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT_INCLUDE_RAW"
NO_SUGGESTION = "no_suggestion"

LABELS = [
    "relevance",
    "literal continuation",
    "assistant voice",
    "wrong topic",
    "too long",
    "structural breakage",
    "unsafe or sensitive content",
    "repetition",
]
HARD_DISPLAY_FAILURES = {
    "assistant voice",
    "wrong topic",
    "structural breakage",
    "unsafe or sensitive content",
    "repetition",
}
ASSISTANT_MARKERS = [
    "analyze the request",
    "as an ai",
    "certainly,",
    "happy to help",
    "here is",
    "here's",
    "i can help",
    "i would recommend",
    "i would suggest",
    "let's",
    "okay, let's",
    "okay, the user",
    "sure,",
    "the user",
    "thinking process",
    "you should",
]
UNSAFE_MARKERS = [
    "api key",
    "bearer token",
    "credit card",
    "password",
    "private key",
    "sales plan",
    "secret",
    "sensitive",
    "social security",
    "ssn",
]
LOW_SIGNAL_WORDS = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "been",
    "being",
    "but",
    "by",
    "can",
    "could",
    "do",
    "does",
    "for",
    "from",
    "had",
    "has",
    "have",
    "he",
    "her",
    "here",
    "him",
    "his",
    "i",
    "if",
    "in",
    "is",
    "it",
    "its",
    "just",
    "may",
    "maybe",
    "might",
    "of",
    "on",
    "or",
    "our",
    "probably",
    "really",
    "she",
    "should",
    "so",
    "some",
    "that",
    "the",
    "their",
    "there",
    "they",
    "this",
    "to",
    "very",
    "was",
    "we",
    "were",
    "will",
    "with",
    "would",
    "you",
    "your",
}


@dataclass(frozen=True)
class AuditRow:
    row_id: str
    system: str
    user: str
    expected_terms: tuple[str, ...]
    max_words: int
    line_structure: str
    output: Optional[str] = None


@dataclass(frozen=True)
class RowScore:
    row: AuditRow
    output: str
    failures: frozenset[str]
    no_suggestion: bool

    @property
    def display_eligible(self) -> bool:
        return not self.no_suggestion and not bool(self.failures & HARD_DISPLAY_FAILURES)


def word_tokens(text: str) -> list[str]:
    return [token for token in re.split(r"[^A-Za-z0-9']+", text.lower()) if token]


def normalized_no_suggestion(text: str) -> bool:
    stripped = text.strip().strip("\"'`").lower()
    stripped = stripped.strip(".! ")
    return stripped in {"<no_suggestion>", "no_suggestion", NO_SUGGESTION}


def relevance_failure(output_words: list[str], expected_terms: tuple[str, ...]) -> bool:
    if not output_words or not expected_terms:
        return True

    word_set = set(output_words)
    content_word_count = max(1, sum(1 for word in output_words if word not in LOW_SIGNAL_WORDS))
    denominator = min(3, len(expected_terms), content_word_count)
    hits = sum(1 for term in expected_terms if term.lower() in word_set)
    return hits / denominator < 0.34


def literal_continuation_failure(output: str) -> bool:
    stripped = output.strip()
    lower = stripped.lower()
    if not stripped:
        return True
    if stripped.startswith(('"', "'", "`")):
        return True
    if "\n" in stripped:
        return True
    return lower.startswith((
        "sure",
        "here",
        "i can",
        "i will",
        "as an ai",
        "let me",
    ))


def assistant_voice_failure(output: str) -> bool:
    lower = output.lower()
    return any(marker in lower for marker in ASSISTANT_MARKERS)


def wrong_topic_failure(relevance_failed: bool, output: str) -> bool:
    return bool(output.strip()) and relevance_failed


def too_long_failure(output_words: list[str], max_words: int) -> bool:
    return len(output_words) > max_words


def structural_breakage_failure(output: str, line_structure: str) -> bool:
    stripped = output.strip()
    if not stripped:
        return False
    if "\n" in stripped:
        return True
    if stripped.startswith("```") or stripped.startswith("# "):
        return True
    if re.match(r"^\s*(?:[-*+]|\d+[\.\)]|\[[ xX]\])\s+", stripped):
        return True
    if line_structure == "plain" and re.search(r"[*_`#]", stripped):
        return True
    return False


def unsafe_sensitive_failure(output: str) -> bool:
    lower = output.lower()
    return any(marker in lower for marker in UNSAFE_MARKERS)


def repetition_failure(output_words: list[str], context_words: list[str]) -> bool:
    if not output_words:
        return True
    if any(left == right for left, right in zip(output_words, output_words[1:])):
        return True
    if len(output_words) == 1 and len(output_words[0]) > 3 and output_words[0] in context_words:
        return True
    maximum = min(3, len(output_words), len(context_words))
    for count in range(maximum, 1, -1):
        lead = output_words[:count]
        for index in range(0, len(context_words) - count + 1):
            if context_words[index : index + count] == lead:
                return True
    return False


def score_row(row: AuditRow, output: str) -> RowScore:
    output_words = word_tokens(output)
    context_words = word_tokens(row.user)
    no_suggestion = normalized_no_suggestion(output) or not output.strip()
    relevance_failed = relevance_failure(output_words, row.expected_terms)
    failures = set()

    if no_suggestion:
        if relevance_failed:
            failures.add("relevance")
        return RowScore(
            row=row,
            output=output,
            failures=frozenset(failures),
            no_suggestion=True,
        )

    if relevance_failed:
        failures.add("relevance")
    if literal_continuation_failure(output):
        failures.add("literal continuation")
    if assistant_voice_failure(output):
        failures.add("assistant voice")
    if wrong_topic_failure(relevance_failed, output):
        failures.add("wrong topic")
    if too_long_failure(output_words, row.max_words):
        failures.add("too long")
    if structural_breakage_failure(output, row.line_structure):
        failures.add("structural breakage")
    if unsafe_sensitive_failure(output):
        failures.add("unsafe or sensitive content")
    if repetition_failure(output_words, context_words):
        failures.add("repetition")

    return RowScore(
        row=row,
        output=output,
        failures=frozenset(failures),
        no_suggestion=no_suggestion,
    )


def parse_row(line: str, line_number: int) -> AuditRow:
    try:
        payload = json.loads(line)
    except json.JSONDecodeError as error:
        raise ValueError(f"line {line_number}: invalid JSON: {error}") from error

    expected_terms = payload.get("expected_terms") or payload.get("expectedMeaningTerms") or []
    if not isinstance(expected_terms, list) or not all(isinstance(term, str) for term in expected_terms):
        raise ValueError(f"line {line_number}: expected_terms must be a string array")

    return AuditRow(
        row_id=str(payload.get("id") or f"row-{line_number}"),
        system=str(payload.get("system") or ""),
        user=str(payload.get("user") or payload.get("text_before_cursor") or ""),
        expected_terms=tuple(term.lower() for term in expected_terms),
        max_words=max(1, int(payload.get("max_words") or payload.get("maxVisibleWords") or 8)),
        line_structure=str(payload.get("line_structure") or payload.get("lineStructure") or "plain"),
        output=None if payload.get("output") is None else str(payload.get("output")),
    )


def read_rows(path: Path) -> list[AuditRow]:
    rows = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            stripped = line.strip()
            if not stripped:
                continue
            rows.append(parse_row(stripped, line_number))
    return rows


def generated_output(row: AuditRow, timeout: float) -> str:
    payload = {"system": row.system, "user": row.user}
    command = [
        str(ROOT_DIR / "script" / "local_completion_runtime.py"),
        "--max-words",
        str(row.max_words),
    ]
    completed = subprocess.run(
        command,
        input=json.dumps(payload),
        cwd=ROOT_DIR,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"{row.row_id}: runtime failed: {completed.stderr.strip()}")
    return completed.stdout.strip()


def outputs_for_rows(rows: Iterable[AuditRow], generate: bool, timeout: float) -> list[tuple[AuditRow, str]]:
    pairs = []
    for row in rows:
        if generate:
            output = generated_output(row, timeout)
        else:
            output = row.output or ""
        pairs.append((row, output))
    return pairs


def percentage(failures: int, total: int) -> str:
    if total == 0:
        return "0%"
    return f"{round((failures / total) * 100):.0f}%"


def summarize(scores: list[RowScore], source: str, include_raw: bool) -> tuple[str, int, int]:
    total_rows = len(scores)
    display_scores = [score for score in scores if score.display_eligible]
    suppressed = total_rows - len(display_scores)
    label_failures = {
        label: sum(1 for score in scores if label in score.failures)
        for label in LABELS
    }

    if display_scores:
        total_possible = len(display_scores) * len(LABELS)
        total_failed = sum(1 for score in display_scores for label in LABELS if label in score.failures)
        relevance_failed = sum(1 for score in display_scores if "relevance" in score.failures)
        overall = round(((total_possible - total_failed) / total_possible) * 100)
        relevance = round(((len(display_scores) - relevance_failed) / len(display_scores)) * 100)
    else:
        overall = 0
        relevance = 0

    lines = [
        "Local quality audit: PASS",
        f"Source: {source}",
        f"Rows scored: {total_rows}",
        f"Display-eligible rows: {len(display_scores)}",
        f"Suppressed/no-suggestion rows: {suppressed}",
        f"Overall score: {overall}/100",
        f"Relevance score: {relevance}/100",
        "Raw output persisted: no",
        "Label failure rates:",
    ]
    for label in LABELS:
        failed = label_failures[label]
        lines.append(f"- {label}: {percentage(failed, total_rows)} ({failed}/{total_rows})")

    lines.append("Rows:")
    for score in scores:
        status = "PASS" if score.display_eligible else "FAIL"
        detail = "display-eligible" if score.display_eligible else ", ".join(sorted(score.failures)) or "no suggestion"
        if include_raw:
            detail = f"{detail}; raw={score.output!r}"
        lines.append(f"- {status} {score.row.row_id}: {detail}")

    return "\n".join(lines), overall, relevance


def self_test_rows() -> list[AuditRow]:
    return [
        AuditRow(
            row_id="fixture-good-markdown",
            system="Inline autocomplete. Return only the continuation.",
            user="The current Obsidian note should prove",
            expected_terms=("markdown", "local", "proof"),
            max_words=3,
            line_structure="plain",
            output="markdown local proof",
        ),
        AuditRow(
            row_id="fixture-good-tone",
            system="Inline autocomplete. Return only the continuation.",
            user="I want this to feel",
            expected_terms=("natural", "quiet"),
            max_words=3,
            line_structure="plain",
            output="natural and quiet",
        ),
        AuditRow(
            row_id="fixture-assistant-voice",
            system="Inline autocomplete. Return only the continuation.",
            user="I am trying to say this in a way that feels",
            expected_terms=("human",),
            max_words=4,
            line_structure="plain",
            output="Okay, the user wants a human sentence",
        ),
        AuditRow(
            row_id="fixture-sensitive-structure",
            system="Inline autocomplete. Return only the continuation.",
            user="The markdown proof should stay",
            expected_terms=("markdown", "local", "proof"),
            max_words=3,
            line_structure="plain",
            output="- Sure, let's put the secret calendar sales plan here today",
        ),
        AuditRow(
            row_id="fixture-no-suggestion",
            system="Inline autocomplete. Return only the continuation.",
            user="Password:",
            expected_terms=("safe",),
            max_words=3,
            line_structure="plain",
            output="<NO_SUGGESTION>",
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a local opt-in autocomplete quality audit.")
    parser.add_argument("--input", type=Path, help="JSONL disposable prompt set")
    parser.add_argument("--generate", action="store_true", help="Generate current local model output")
    parser.add_argument("--self-test", action="store_true", help="Run fixture self-test without opt-in env")
    parser.add_argument("--timeout", type=float, default=8)
    parser.add_argument("--min-overall", type=int, default=0)
    parser.add_argument("--min-relevance", type=int, default=0)
    parser.add_argument("--include-raw-output", action="store_true")
    args = parser.parse_args()

    include_raw = args.include_raw_output
    if include_raw and os.environ.get(RAW_ENV) != "1":
        print(f"--include-raw-output requires {RAW_ENV}=1", file=sys.stderr)
        return 64

    if args.self_test:
        rows = self_test_rows()
        source = "self-test fixtures"
        generate = False
    else:
        if os.environ.get(OPT_IN_ENV) != "1":
            print(f"local quality audit requires {OPT_IN_ENV}=1", file=sys.stderr)
            return 64
        if not args.input:
            print("--input is required unless --self-test is used", file=sys.stderr)
            return 64
        rows = read_rows(args.input)
        source = "current local model" if args.generate else "labeled local outputs"
        generate = args.generate

    pairs = outputs_for_rows(rows, generate=generate, timeout=args.timeout)
    scores = [score_row(row, output) for row, output in pairs]
    summary, overall, relevance = summarize(scores, source=source, include_raw=include_raw)
    print(summary)

    if overall < args.min_overall or relevance < args.min_relevance:
        print(
            f"quality audit below threshold: overall {overall}/100, relevance {relevance}/100",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
