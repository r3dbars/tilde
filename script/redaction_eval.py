#!/usr/bin/env python3
"""Blocking recall eval for the Screen Memory redaction gate (PR 3b).

Runs the SHIPPED `RedactionService` pipeline (`SecretRules` in-process,
then the real GLiNER helper-process model layer) over the committed
synthetic planted-secrets corpus (`script/testdata/redaction_eval_corpus.jsonl`)
via the Tilde binary's `--redaction-eval-json` subcommand, and checks two
blocking bars:

  >= 99% structured recall  — every planted card/IBAN/SSN/API-key/JWT/PEM/
                               email/phone that `SecretRules` should catch
  >= 90% unstructured recall — every planted freeform PII (name, address,
                               medical condition, date of birth, employer)
                               that only the GLiNER model layer can catch

Recall is measured by PER-FRAGMENT ABSENCE: a planted secret string
"recalls" only if EVERY meaningful fragment of it (each alphanumeric run of
3+ characters — see `secret_fragments`) no longer appears verbatim,
anywhere, in the redacted output for that record. A whole-string-only check
(`secret not in redacted`) under-counts: "John Smith" redacted down to just
"Smith" (only the "John" span got applied) is NOT a substring match for the
full "John Smith" string, so a whole-string check would score it a hit even
though a real name fragment is still sitting in the output. Per-fragment
scoring catches that: "Smith" is still present, so the secret is NOT fully
redacted, and it counts as a miss.

Recall is reported both PER-CATEGORY (structured/unstructured) and
IN AGGREGATE per the plan's "report aggregate-only" requirement — this
script's stdout report never contains the corpus text, a matched secret
value, or a per-record breakdown; only counts and rates.

`RedactionService` is fail-closed as a WHOLE (see its doc comment): a
capture with the model layer unavailable is dropped entirely, not shipped
rules-only. That means both bars can only be measured together, through
one real run with the model layer configured and working — there is no
meaningful "rules-only" mode of this script, because a rules-only run would
just show every record dropped (0% on both bars) by design, not because
`SecretRules` failed. For a fast, dependency-free check that `SecretRules`
itself still catches every planted structured secret, see the Swift-only
`RedactionCorpusSanityTests` (`swift test --filter RedactionCorpusSanityTests`)
— that suite runs in `proof.sh` and needs no Python/GLiNER/ONNX Runtime at
all. This script is the full, blocking, both-bars-at-once eval and always
requires a real, working model layer.

Usage:
  script/redaction_eval.py \\
      --tilde-binary .build/debug/Tilde \\
      --corpus script/testdata/redaction_eval_corpus.jsonl \\
      --python /path/to/gliner-venv/bin/python \\
      --helper-script script/redaction_helper.py \\
      --model /path/to/model.onnx \\
      --tokenizer-dir /path/to/onnx-out-dir

Exit code is 0 iff both bars are met.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_CORPUS = ROOT_DIR / "script/testdata/redaction_eval_corpus.jsonl"

STRUCTURED_BAR = 0.99
UNSTRUCTURED_BAR = 0.90

_FRAGMENT_PATTERN = re.compile(r"[A-Za-z0-9]+")


def secret_fragments(secret: str) -> list[str]:
    """Break a planted secret into the pieces that must ALL be gone from the
    redacted output for a hit. Splitting on runs of non-alphanumeric
    characters (whitespace, `-`, `@`, `.`, etc.) catches partial redactions
    a whole-string check misses — see the module docstring for the
    "John Smith" -> "Smith" example. Fragments shorter than 3 characters are
    dropped: a lone digit or two-letter piece is common enough as an
    incidental substring elsewhere in ordinary text that requiring its
    absence would manufacture false misses, and on its own it rarely
    identifies anyone. If a secret has no fragment that long (e.g. a very
    short planted value), fall back to the whole secret so it is still
    scored on something.
    """
    fragments = [fragment for fragment in _FRAGMENT_PATTERN.findall(secret) if len(fragment) >= 3]
    return fragments or ([secret] if secret else [])


def is_fully_redacted(secret: str, redacted: str) -> bool:
    """A secret counts as a hit only if every meaningful fragment of it
    (see `secret_fragments`) is absent from the redacted output — not just
    the exact, whole-string secret."""
    return all(fragment not in redacted for fragment in secret_fragments(secret))


def load_corpus(path: Path) -> list[dict]:
    records = []
    with path.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise ValueError(f"corpus line {line_number} is not valid JSON") from exc
    return records


def run_tilde_redaction_eval(tilde_binary: Path, corpus_path: Path, env: dict) -> list[dict]:
    result = subprocess.run(
        [str(tilde_binary), "--redaction-eval-json", str(corpus_path)],
        capture_output=True, text=True, env=env, timeout=600,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Tilde --redaction-eval-json exited {result.returncode}: {result.stderr.strip()}")
    outputs = []
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        outputs.append(json.loads(line))
    return outputs


def score(corpus: list[dict], outputs: list[dict]) -> dict:
    by_id = {record["id"]: record for record in corpus}
    output_by_id = {output["id"]: output for output in outputs}

    structured_total = 0
    structured_hits = 0
    unstructured_total = 0
    unstructured_hits = 0
    dropped_records = 0

    for record_id, record in by_id.items():
        output = output_by_id.get(record_id)
        if output is None or output.get("dropped"):
            dropped_records += 1
            structured_total += len(record["structured_secrets"])
            unstructured_total += len(record["unstructured_secrets"])
            continue
        redacted = output.get("redacted") or ""
        for secret in record["structured_secrets"]:
            structured_total += 1
            if is_fully_redacted(secret, redacted):
                structured_hits += 1
        for secret in record["unstructured_secrets"]:
            unstructured_total += 1
            if is_fully_redacted(secret, redacted):
                unstructured_hits += 1

    return {
        "schema": "tilde.redaction-eval.v1",
        "corpus": {"records": len(corpus), "dropped_records": dropped_records},
        "structured": category_report(structured_hits, structured_total, STRUCTURED_BAR),
        "unstructured": category_report(unstructured_hits, unstructured_total, UNSTRUCTURED_BAR),
        "privacy": {
            "aggregate_only": True,
            "contains_raw_text": False,
            "contains_matched_secrets": False,
            "contains_per_record_breakdown": False,
        },
    }


def category_report(hits: int, total: int, bar: float) -> dict:
    """Per-category recall report. An EMPTY category (`total == 0`) is a
    hard eval failure, not a free 100% — a category with nothing planted in
    the corpus means the corpus never actually exercised that redactor, so
    passing here would be measuring nothing and calling it a pass. Report
    `rate: 0.0` and `meets_bar: False` with an explicit `error` so this
    shows up loudly instead of silently inflating the aggregate bar.
    """
    if total == 0:
        return {
            "recall_count": hits,
            "total": total,
            "rate": 0.0,
            "bar": bar,
            "meets_bar": False,
            "error": "empty category: corpus has zero planted secrets for this redactor — cannot be scored as a pass",
        }
    rate = hits / total
    return {
        "recall_count": hits,
        "total": total,
        "rate": rate,
        "bar": bar,
        "meets_bar": rate >= bar,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tilde-binary", type=Path, required=True, help="Path to the built Tilde executable.")
    parser.add_argument("--corpus", type=Path, default=DEFAULT_CORPUS, help="Synthetic corpus JSONL path.")
    parser.add_argument("--python", type=Path, required=True, help="Interpreter for the redaction helper.")
    parser.add_argument("--helper-script", type=Path, default=ROOT_DIR / "script/redaction_helper.py")
    parser.add_argument("--model", type=Path, required=True, help="ONNX model file for the model layer.")
    parser.add_argument("--tokenizer-dir", type=Path, required=True)
    args = parser.parse_args()

    corpus = load_corpus(args.corpus)

    env = dict(os.environ)
    env["TILDE_DEV_REDACTION_HELPER_PYTHON"] = str(args.python)
    env["TILDE_DEV_REDACTION_HELPER_SCRIPT"] = str(args.helper_script)
    env["TILDE_DEV_REDACTION_MODEL"] = str(args.model)
    env["TILDE_DEV_REDACTION_TOKENIZER_DIR"] = str(args.tokenizer_dir)

    outputs = run_tilde_redaction_eval(args.tilde_binary, args.corpus, env)
    report = score(corpus, outputs)
    if report["corpus"]["dropped_records"] > 0:
        report["warning"] = (
            f"{report['corpus']['dropped_records']} of {report['corpus']['records']} records were DROPPED "
            "(model layer unavailable for that call) — both bars below are computed with dropped records "
            "counted as full misses, so a dropped-records warning here means the real numbers are worse "
            "than what a healthy run would show, not better."
        )

    print(json.dumps(report, indent=2))

    ok = report["structured"]["meets_bar"] and report["unstructured"]["meets_bar"]
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
