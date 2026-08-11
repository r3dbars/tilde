#!/usr/bin/env python3
"""Run one bounded, aggregate-only continuation evaluation against Tilde.

Input is JSONL with a string ``text`` field. Additional fields are ignored.
Raw text and model output stay in memory: stdout contains only aggregate JSON.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import socket
import sys
import time


SCHEMA = "tilde.continuation-eval.v1"
DEFAULT_SOCKET = Path.home() / "Library/Application Support/Tilde/ghost.sock"
DEFAULT_MAX_CASES = 200
HARD_MAX_CASES = 2_000
MAX_RESPONSE_BYTES = 1_048_576
CUT_FRACTIONS = (0.4, 0.6, 0.8)
MIN_CONTEXT_WORDS = 3
MIN_GOLDEN_WORDS = 2
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$")


class ProtocolError(Exception):
    """The local completion socket did not follow its documented protocol."""


def canonical_text(text):
    return " ".join(text.split())


def case_id(text):
    return hashlib.sha256(canonical_text(text).encode("utf-8")).hexdigest()


def digest_ids(ids):
    payload = "\n".join(sorted(ids)).encode("ascii")
    return hashlib.sha256(payload).hexdigest()


def build_quiz(text):
    text = canonical_text(text)
    words = text.split()
    if len(words) < MIN_CONTEXT_WORDS + MIN_GOLDEN_WORDS:
        return None
    fraction = CUT_FRACTIONS[int(case_id(text)[:8], 16) % len(CUT_FRACTIONS)]
    cut = int(round(len(words) * fraction))
    cut = max(MIN_CONTEXT_WORDS, min(cut, len(words) - MIN_GOLDEN_WORDS))
    return " ".join(words[:cut]) + " ", " ".join(words[cut:])


def load_corpus(paths):
    by_id = {}
    records = ineligible = duplicates = 0
    for corpus_number, path in enumerate(paths, start=1):
        try:
            handle = open(path, "r", encoding="utf-8")
        except OSError as exc:
            raise ValueError(f"corpus {corpus_number} could not be read") from exc
        with handle:
            try:
                lines = enumerate(handle, start=1)
                for line_number, line in lines:
                    if not line.strip():
                        continue
                    records += 1
                    try:
                        record = json.loads(line)
                    except json.JSONDecodeError as exc:
                        raise ValueError(
                            f"corpus {corpus_number} has invalid JSON at line {line_number}"
                        ) from exc
                    text = record.get("text") if isinstance(record, dict) else None
                    if not isinstance(text, str):
                        raise ValueError(
                            f"corpus {corpus_number} has a non-string text field at line {line_number}"
                        )
                    quiz = build_quiz(text)
                    if quiz is None:
                        ineligible += 1
                        continue
                    identifier = case_id(text)
                    if identifier in by_id:
                        duplicates += 1
                        continue
                    by_id[identifier] = quiz
            except UnicodeDecodeError as exc:
                raise ValueError(f"corpus {corpus_number} is not UTF-8") from exc
    cases = [(identifier, *by_id[identifier]) for identifier in sorted(by_id)]
    return cases, {
        "records": records,
        "ineligible": ineligible,
        "duplicates": duplicates,
    }


def normalize_word(word):
    return word.lower().strip(".,!?;:\"'()[]{}")


def exact_match_at_n(suggestion, golden, n):
    suggestion_words = [normalize_word(word) for word in suggestion.split()][:n]
    golden_words = [normalize_word(word) for word in golden.split()][:n]
    return len(suggestion_words) == n and suggestion_words == golden_words


def keystrokes_saved(suggestion, golden):
    matched = []
    for suggested, expected in zip(suggestion.split(), golden.split()):
        if normalize_word(suggested) != normalize_word(expected):
            break
        matched.append(suggested)
    return sum(map(len, matched)) + max(0, len(matched) - 1)


def request_completion(context, socket_path, timeout_seconds):
    request = json.dumps({"v": 1, "context": context}, separators=(",", ":"))
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(timeout_seconds)
        connection.connect(socket_path)
        started = time.monotonic()
        connection.sendall(request.encode("utf-8") + b"\n")
        buffered = b""
        received = 0
        first_partial_ms = None
        while received <= MAX_RESPONSE_BYTES:
            chunk = connection.recv(4096)
            if not chunk:
                raise ProtocolError("connection closed before a final response")
            received += len(chunk)
            if received > MAX_RESPONSE_BYTES:
                raise ProtocolError("response exceeded the byte limit")
            buffered += chunk
            while b"\n" in buffered:
                line, buffered = buffered.split(b"\n", 1)
                try:
                    response = json.loads(line)
                except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                    raise ProtocolError("response was not JSON") from exc
                if not isinstance(response, dict):
                    raise ProtocolError("response was not an object")
                partial = response.get("partial", False)
                suggestion = response.get("suggestion")
                if not isinstance(partial, bool) or not isinstance(suggestion, str):
                    raise ProtocolError("response fields had invalid types")
                elapsed_ms = round((time.monotonic() - started) * 1000)
                if partial:
                    if first_partial_ms is None:
                        first_partial_ms = elapsed_ms
                    continue
                return suggestion, first_partial_ms, elapsed_ms
    raise ProtocolError("response ended without a final response")


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, round(fraction * (len(ordered) - 1)))
    return ordered[index]


def latency_summary(values):
    return {
        "count": len(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "max": max(values) if values else None,
    }


def rate(count, denominator):
    return round(count / denominator, 6) if denominator else 0.0


def evaluate(cases, ask):
    outcomes = {"ok": 0, "silent": 0, "protocol_error": 0, "timeout": 0}
    exact = {1: 0, 2: 0, 3: 0}
    saved = 0
    first_partial_latencies = []
    final_latencies = []

    for _identifier, context, golden in cases:
        try:
            suggestion, first_partial_ms, final_ms = ask(context)
        except (socket.timeout, TimeoutError):
            outcomes["timeout"] += 1
            continue
        except (ProtocolError, OSError):
            outcomes["protocol_error"] += 1
            continue
        if suggestion.strip():
            outcomes["ok"] += 1
        else:
            outcomes["silent"] += 1
        if first_partial_ms is not None:
            first_partial_latencies.append(first_partial_ms)
        final_latencies.append(final_ms)
        for n in exact:
            exact[n] += int(exact_match_at_n(suggestion, golden, n))
        saved += keystrokes_saved(suggestion, golden)

    completed = outcomes["ok"] + outcomes["silent"]
    return {
        "outcomes": outcomes,
        "quality": {
            "completed_cases": completed,
            "exact_match_at_1": {"count": exact[1], "rate": rate(exact[1], completed)},
            "exact_match_at_2": {"count": exact[2], "rate": rate(exact[2], completed)},
            "exact_match_at_3": {"count": exact[3], "rate": rate(exact[3], completed)},
            "keystrokes_saved": {
                "total": saved,
                "per_completed_case": round(saved / completed, 6) if completed else 0.0,
            },
        },
        "latency_ms": {
            "request_to_first_partial": latency_summary(first_partial_latencies),
            "request_to_final": latency_summary(final_latencies),
        },
    }


def build_report(cases, corpus_stats, all_case_ids, args, aggregate):
    selected_ids = [case[0] for case in cases]
    outcomes = aggregate["outcomes"]
    complete = (
        sum(outcomes.values()) == len(cases)
        and outcomes["protocol_error"] == 0
        and outcomes["timeout"] == 0
    )
    return {
        "schema": SCHEMA,
        "privacy": {
            "aggregate_only": True,
            "raw_contexts": False,
            "raw_outputs": False,
            "app_ids": False,
            "paths": False,
        },
        "runtime": {
            "arm": args.arm,
            "build_id": args.build_id,
            "model_id": args.model_id,
            "config_id": args.config_id,
        },
        "corpus": {
            **corpus_stats,
            "eligible": len(all_case_ids),
            "selected": len(cases),
            "case_id_algorithm": "sha256-canonical-text-v1",
            "digest_sha256": digest_ids(all_case_ids),
            "selection_digest_sha256": digest_ids(selected_ids),
        },
        **aggregate,
        "complete": complete,
    }


def validate_args(parser, args):
    if not 1 <= args.max_cases <= HARD_MAX_CASES:
        parser.error(f"--max-cases must be between 1 and {HARD_MAX_CASES}")
    if args.timeout <= 0 or args.timeout > 120:
        parser.error("--timeout must be greater than 0 and no more than 120 seconds")
    for value in (args.build_id, args.model_id, args.config_id):
        if value is not None and not SAFE_ID.fullmatch(value):
            parser.error("runtime metadata must be a short identifier, not a path or free text")


def exit_code(report):
    return 0 if report["complete"] else 1


def selftest():
    secret_context = "PRIVATE_CONTEXT_SENTINEL alpha beta gamma delta epsilon zeta"
    cases = []
    for suffix in ("one", "two", "three", "four"):
        text = f"{secret_context} {suffix} eta theta"
        context, golden = build_quiz(text)
        cases.append((case_id(text), context, golden))

    calls = 0

    def incomplete_ask(_context):
        nonlocal calls
        calls += 1
        if calls == 1:
            return "PRIVATE_OUTPUT_SENTINEL", 4, 9
        if calls == 2:
            return "", None, 7
        if calls == 3:
            raise TimeoutError
        raise ProtocolError

    aggregate = evaluate(cases, incomplete_ask)
    args = argparse.Namespace(
        arm="single", build_id="build-1", model_id="model-1", config_id="config-1"
    )
    report = build_report(
        cases,
        {"records": 4, "ineligible": 0, "duplicates": 0},
        [case[0] for case in cases],
        args,
        aggregate,
    )
    assert report["outcomes"] == {
        "ok": 1, "silent": 1, "protocol_error": 1, "timeout": 1
    }
    assert exit_code(report) == 1, "incomplete runs must fail nonzero"
    assert set(report) == {
        "schema", "privacy", "runtime", "corpus", "outcomes",
        "quality", "latency_ms", "complete"
    }
    serialized = json.dumps(report, sort_keys=True)
    for forbidden in (
        "PRIVATE_CONTEXT_SENTINEL", "PRIVATE_OUTPUT_SENTINEL", "/Users/", "com.apple"
    ):
        assert forbidden not in serialized

    complete = evaluate(cases[:2], lambda _context: ("", None, 5))
    complete_report = build_report(
        cases[:2],
        {"records": 4, "ineligible": 0, "duplicates": 0},
        [case[0] for case in cases],
        args,
        complete,
    )
    assert exit_code(complete_report) == 0
    assert complete_report["outcomes"]["silent"] == 2
    assert build_quiz(secret_context) == build_quiz(secret_context)
    assert exact_match_at_n("Thanks, for", "thanks for today", 2)
    assert keystrokes_saved("alpha beta extra", "alpha beta gamma") == len("alpha beta")
    assert keystrokes_saved("alpha", "alpha beta") == len("alpha")
    print("selftest OK: aggregate privacy schema, stable corpus IDs, and incomplete-run failure")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", action="append", default=[], help="input JSONL (repeatable)")
    parser.add_argument("--max-cases", type=int, default=DEFAULT_MAX_CASES)
    parser.add_argument("--timeout", type=float, default=15.0, help="per-case seconds")
    parser.add_argument("--sock", default=str(DEFAULT_SOCKET), help="local Tilde socket")
    parser.add_argument("--arm", choices=("single", "baseline", "candidate"), default="single")
    parser.add_argument("--build-id")
    parser.add_argument("--model-id")
    parser.add_argument("--config-id")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    validate_args(parser, args)
    if args.selftest:
        selftest()
        return 0
    if not args.corpus:
        parser.error("--corpus is required unless --selftest is used")
    try:
        all_cases, corpus_stats = load_corpus(args.corpus)
        if not all_cases:
            raise ValueError("corpus has no eligible continuation cases")
        selected = all_cases[:args.max_cases]
        aggregate = evaluate(
            selected,
            lambda context: request_completion(context, args.sock, args.timeout),
        )
        report = build_report(
            selected, corpus_stats, [case[0] for case in all_cases], args, aggregate
        )
    except ValueError as exc:
        print(f"evaluation error: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    return exit_code(report)


if __name__ == "__main__":
    sys.exit(main())
