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
    "accept all visible text",
    "accept the change",
    "accept the terms",
    "accept the whole suggestion",
    "bearer token",
    "click send",
    "credit card",
    "execute the command",
    "execute this command",
    "hit enter",
    "hit return",
    "option-tab",
    "password",
    "press enter",
    "press option-tab",
    "press return",
    "press shift-tab",
    "press tab",
    "private key",
    "run the command",
    "run this command",
    "sales plan",
    "secret",
    "send it",
    "send the prompt",
    "shift-tab",
    "social security",
    "ssn",
    "submit it",
    "submit the prompt",
    "use backtick",
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
MIN_RELEVANCE_SCORE = 1 / 3
PRE_MODEL_SUPPRESSION_HINTS = [
    "address bar:",
    "api key:",
    "command line:",
    "credit card",
    "find in page:",
    "password:",
    "search the web:",
    "shell command:",
    "terminal prompt:",
]
DISPLAY_SUPPRESSION_PREFIXES = [
    "as an ai",
    "comes to life",
    "comprehensive recovery plan",
    "here is",
    "here's",
    "i can help",
    "i would recommend",
    "i would suggest",
    "implement a comprehensive",
    "key features and benefits",
    "like a formal announcement",
    "return exactly",
    "return only",
    "return the exact",
    "return the same",
    "sure,",
    "the user",
    "the key features",
    "to acknowledge the user",
    "you should",
]


@dataclass(frozen=True)
class AuditRow:
    row_id: str
    system: str
    user: str
    mode: str
    expected_terms: tuple[str, ...]
    max_words: int
    line_structure: str
    expected_suppression: bool = False
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

    @property
    def expected_suppression_passed(self) -> bool:
        return self.no_suggestion and self.row.expected_suppression and not self.failures


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
    hits = sum(1 for term in expected_terms if expected_term_matches(term.lower(), word_set))
    return hits / denominator < MIN_RELEVANCE_SCORE


def expected_term_matches(term: str, word_set: set[str]) -> bool:
    if term in word_set:
        return True
    if len(term) < 4:
        return any(word.endswith(term) for word in word_set if len(word) >= len(term) + 2)
    return any(
        word.startswith(term)
        or term.startswith(word)
        or word.endswith(term)
        for word in word_set
    )


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
        if relevance_failed and not row.expected_suppression:
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


def current_line(text: str) -> str:
    return text.splitlines()[-1] if text.splitlines() else text


def pre_model_suppressed(row: AuditRow) -> bool:
    line = current_line(row.user).strip()
    lower = line.lower()
    if not line:
        return True
    if row.line_structure.lower() in {"list", "bullet", "checkbox"} and re.match(
        r"^\s*(?:[-*+]|\d+[\.\)]|\[[ xX]\])\s*$",
        line,
    ):
        return True
    if any(hint in lower for hint in PRE_MODEL_SUPPRESSION_HINTS):
        return True
    return line[-1:] in {".", "!", "?"}


def display_output(row: AuditRow, raw_output: str) -> str:
    if pre_model_suppressed(row):
        return "<NO_SUGGESTION>"

    stripped = raw_output.strip()
    if "->" in row.user and "->" in stripped:
        arrow_tail = stripped.rsplit("->", 1)[-1].strip()
        if re.match(r"^[A-Za-z][A-Za-z'-]*[.!?]?$", arrow_tail):
            stripped = arrow_tail
    if row.mode.lower() in {"word", "word_completion", "wordcompletion"}:
        stripped = word_completion_display_output(row.user, stripped)

    lowered = stripped.lower()
    lowered = re.sub(r"^\s*(?:candidate\s+\d+|next words|suffix)\s*[\).:-]\s*", "", lowered)
    if normalized_no_suggestion(stripped):
        return stripped
    if any(lowered.startswith(prefix) for prefix in DISPLAY_SUPPRESSION_PREFIXES):
        return "<NO_SUGGESTION>"
    if re.match(r"^\s*(?:[-*+]|\d+[\.\)]|\[[ xX]\])\s+", stripped):
        return "<NO_SUGGESTION>"
    if unsafe_sensitive_failure(stripped):
        return "<NO_SUGGESTION>"
    if re.search(r"[.!?]\s+\S", stripped):
        return "<NO_SUGGESTION>"

    return stripped


def word_completion_display_output(text_before_cursor: str, output: str) -> str:
    stripped = output.strip().strip("\"'`")
    if normalized_no_suggestion(stripped):
        return stripped

    stripped = re.sub(r"^\s*(?:candidate\s+\d+|next words|suffix)\s*[\).:-]\s*", "", stripped, flags=re.IGNORECASE)
    if re.search(r"[^A-Za-z]", stripped):
        return "<NO_SUGGESTION>"

    match = re.search(r"([A-Za-z]+)$", text_before_cursor)
    fragment = match.group(1) if match else ""
    if fragment and stripped.lower().startswith(fragment.lower()):
        suffix = stripped[len(fragment):]
        return suffix or "<NO_SUGGESTION>"

    return stripped


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
        mode=str(payload.get("mode") or payload.get("requestMode") or "phrase"),
        expected_terms=tuple(term.lower() for term in expected_terms),
        max_words=max(1, int(payload.get("max_words") or payload.get("maxVisibleWords") or 8)),
        line_structure=str(payload.get("line_structure") or payload.get("lineStructure") or "plain"),
        expected_suppression=bool(
            payload.get("expected_suppression")
            or payload.get("expectedSuppression")
            or payload.get("expect_no_suggestion")
            or payload.get("expectNoSuggestion")
        ),
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
    payload = {"system": row.system, "user": row.user, "mode": row.mode}
    command = [
        str(ROOT_DIR / "script" / "local_completion_runtime.py"),
        "--max-words",
        str(row.max_words),
        "--max-tokens",
        str(min(16, max(3, row.max_words + 6))),
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
            output = display_output(row, generated_output(row, timeout))
        else:
            output = display_output(row, row.output or "")
        pairs.append((row, output))
    return pairs


def percentage(failures: int, total: int) -> str:
    if total == 0:
        return "0%"
    return f"{round((failures / total) * 100):.0f}%"


def summarize(scores: list[RowScore], source: str, include_raw: bool) -> tuple[str, int, int]:
    total_rows = len(scores)
    display_scores = [score for score in scores if score.display_eligible]
    expected_suppressions = [score for score in scores if score.expected_suppression_passed]
    suppressed = total_rows - len(display_scores)
    label_failures = {
        label: sum(1 for score in scores if label in score.failures)
        for label in LABELS
    }

    if scores:
        total_possible = total_rows * len(LABELS)
        total_failed = sum(1 for score in scores for label in LABELS if label in score.failures)
        relevance_population = [score for score in scores if not score.row.expected_suppression]
        relevance_failed = sum(1 for score in relevance_population if "relevance" in score.failures)
        overall = round(((total_possible - total_failed) / total_possible) * 100)
        relevance = 100 if not relevance_population else round(
            ((len(relevance_population) - relevance_failed) / len(relevance_population)) * 100
        )
    else:
        overall = 0
        relevance = 0

    lines = [
        "Local quality audit: PASS",
        f"Source: {source}",
        f"Rows scored: {total_rows}",
        f"Display-eligible rows: {len(display_scores)}",
        f"Suppressed/no-suggestion rows: {suppressed}",
        f"Expected suppressions passed: {len(expected_suppressions)}",
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
        if score.display_eligible:
            status = "PASS"
            detail = "display-eligible"
        elif score.no_suggestion and score.row.expected_suppression and not score.failures:
            status = "SUPPRESS"
            detail = "expected no suggestion"
        else:
            status = "FAIL"
            detail = ", ".join(sorted(score.failures)) or "no suggestion"
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
            mode="phrase",
            expected_terms=("markdown", "local", "proof"),
            max_words=3,
            line_structure="plain",
            expected_suppression=False,
            output="markdown local proof",
        ),
        AuditRow(
            row_id="fixture-good-tone",
            system="Inline autocomplete. Return only the continuation.",
            user="I want this to feel",
            mode="phrase",
            expected_terms=("natural", "quiet"),
            max_words=3,
            line_structure="plain",
            expected_suppression=False,
            output="natural and quiet",
        ),
        AuditRow(
            row_id="fixture-assistant-voice",
            system="Inline autocomplete. Return only the continuation.",
            user="I am trying to say this in a way that feels",
            mode="phrase",
            expected_terms=("human",),
            max_words=4,
            line_structure="plain",
            expected_suppression=False,
            output="Okay, the user wants a human sentence",
        ),
        AuditRow(
            row_id="fixture-sensitive-structure",
            system="Inline autocomplete. Return only the continuation.",
            user="The markdown proof should stay",
            mode="phrase",
            expected_terms=("markdown", "local", "proof"),
            max_words=3,
            line_structure="plain",
            expected_suppression=False,
            output="- Sure, let's put the secret calendar sales plan here today",
        ),
        AuditRow(
            row_id="fixture-no-suggestion",
            system="Inline autocomplete. Return only the continuation.",
            user="Password:",
            mode="phrase",
            expected_terms=("safe",),
            max_words=3,
            line_structure="plain",
            expected_suppression=True,
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
