#!/usr/bin/env python3
"""Run a bounded, aggregate-only evaluation against Tilde's local model.

Input is JSONL with a string ``text`` field. Raw text and model output stay in
memory; stdout contains only aggregate JSON. The evaluator calls the exact
packaged ``llama-server`` child on loopback. It does not use Tilde's
authenticated input-method socket, so it measures the raw model recipe rather
than end-to-end inline suggestion behavior.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

from check_runtime_network_egress import model_request as production_model_request, require_owned_model


SCHEMA = "tilde.raw-model-continuation-eval.v1"
ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_APP_BINARY = ROOT_DIR / "dist/Tilde.app/Contents/MacOS/Tilde"
DEFAULT_PORT = 17872
LOCAL_HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}))
DEFAULT_MAX_CASES = 200
HARD_MAX_CASES = 2_000
MAX_RESPONSE_BYTES = 1_048_576
CUT_FRACTIONS = (0.4, 0.6, 0.8)
MIN_CONTEXT_WORDS = 3
MIN_GOLDEN_WORDS = 2
SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$")


class ProtocolError(Exception):
    """The local model helper did not follow its documented HTTP contract."""


def model_request(context):
    """Use the production prompt recipe but request one aggregate final body."""

    request = production_model_request(context)
    request["stream"] = False
    return request


def canonical_text(text):
    return " ".join(text.split())


def case_id(text):
    return hashlib.sha256(canonical_text(text).encode()).hexdigest()


def digest_ids(ids):
    return hashlib.sha256("\n".join(sorted(ids)).encode("ascii")).hexdigest()


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
                for line_number, line in enumerate(handle, start=1):
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
                    else:
                        by_id[identifier] = quiz
            except UnicodeDecodeError as exc:
                raise ValueError(f"corpus {corpus_number} is not UTF-8") from exc
    cases = [(identifier, *by_id[identifier]) for identifier in sorted(by_id)]
    return cases, {"records": records, "ineligible": ineligible, "duplicates": duplicates}


def normalize_word(word):
    return word.lower().strip(".,!?;:\"'()[]{}")


def exact_match_at_n(suggestion, golden, n):
    suggested = [normalize_word(word) for word in suggestion.split()][:n]
    expected = [normalize_word(word) for word in golden.split()][:n]
    return len(suggested) == n and suggested == expected


def keystrokes_saved(suggestion, golden):
    matched = []
    for suggested, expected in zip(suggestion.split(), golden.split()):
        if normalize_word(suggested) != normalize_word(expected):
            break
        matched.append(suggested)
    return sum(map(len, matched)) + max(0, len(matched) - 1)


def normalize_model_output(raw, context):
    lines = raw.splitlines()
    first_line = lines[0] if lines else ""
    return first_line.lstrip(" ") if context[-1:].isspace() else first_line


def request_completion(context, port, timeout_seconds):
    body = json.dumps(model_request(context), separators=(",", ":")).encode()
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/completion",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    started = time.monotonic()
    with LOCAL_HTTP.open(request, timeout=timeout_seconds) as response:
        if response.status != 200:
            raise ProtocolError(f"model helper returned HTTP {response.status}")
        data = response.read(MAX_RESPONSE_BYTES + 1)
    if len(data) > MAX_RESPONSE_BYTES:
        raise ProtocolError("response exceeded the byte limit")
    try:
        payload = json.loads(data)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise ProtocolError("response was not JSON") from exc
    content = payload.get("content") if isinstance(payload, dict) else None
    if not isinstance(content, str):
        raise ProtocolError("response did not contain string content")
    final_ms = round((time.monotonic() - started) * 1_000)
    return normalize_model_output(content, context), final_ms


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round(fraction * (len(ordered) - 1)))]


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
    final_latencies = []
    for _identifier, context, golden in cases:
        try:
            suggestion, final_ms = ask(context)
        except TimeoutError:
            outcomes["timeout"] += 1
            continue
        except urllib.error.URLError as exc:
            key = "timeout" if isinstance(exc.reason, TimeoutError) else "protocol_error"
            outcomes[key] += 1
            continue
        except (ProtocolError, OSError):
            outcomes["protocol_error"] += 1
            continue
        outcomes["ok" if suggestion.strip() else "silent"] += 1
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
        "latency_ms": {"request_to_model_final": latency_summary(final_latencies)},
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
            "target": "owned_packaged_llama_helper",
            "arm": args.arm,
            "build_id": args.build_id,
            "model_id": args.model_id,
            "config_id": args.config_id,
        },
        "proof_boundary": {
            "measures": "raw deterministic prose completion from the packaged local model helper",
            "does_not_measure": "authenticated input-method transport, output cleaning, inline rendering, or acceptance",
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
    if not 1 <= args.port <= 65_535:
        parser.error("--port must be between 1 and 65535")
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
            return "PRIVATE_OUTPUT_SENTINEL", 9
        if calls == 2:
            return "", 7
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
    assert exit_code(report) == 1
    serialized = json.dumps(report, sort_keys=True)
    for forbidden in (
        "PRIVATE_CONTEXT_SENTINEL", "PRIVATE_OUTPUT_SENTINEL", "/Users/", "com.apple"
    ):
        assert forbidden not in serialized
    complete = evaluate(cases[:2], lambda _context: ("", 5))
    complete_report = build_report(
        cases[:2],
        {"records": 4, "ineligible": 0, "duplicates": 0},
        [case[0] for case in cases],
        args,
        complete,
    )
    assert exit_code(complete_report) == 0
    assert exact_match_at_n("Thanks, for", "thanks for today", 2)
    assert keystrokes_saved("alpha beta extra", "alpha beta gamma") == len("alpha beta")
    request = model_request("alpha beta ")
    assert request["stream"] is False and request["temperature"] == 0
    assert request["prompt"].endswith("Text: alpha beta\nContinuation:")
    assert normalize_model_output("  gamma delta\nignored", "alpha beta ") == "gamma delta"
    print("selftest OK: aggregate privacy, final-only model recipe, and incomplete-run failure")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", action="append", default=[], help="input JSONL (repeatable)")
    parser.add_argument("--max-cases", type=int, default=DEFAULT_MAX_CASES)
    parser.add_argument("--timeout", type=float, default=15.0, help="per-case seconds")
    parser.add_argument("--app-binary", type=Path, default=DEFAULT_APP_BINARY)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
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
        require_owned_model(args.app_binary, args.port)
        all_cases, corpus_stats = load_corpus(args.corpus)
        if not all_cases:
            raise ValueError("corpus has no eligible continuation cases")
        selected = all_cases[:args.max_cases]
        aggregate = evaluate(
            selected,
            lambda context: request_completion(context, args.port, args.timeout),
        )
        report = build_report(
            selected, corpus_stats, [case[0] for case in all_cases], args, aggregate
        )
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as exc:
        print(f"evaluation error: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    return exit_code(report)


if __name__ == "__main__":
    sys.exit(main())
