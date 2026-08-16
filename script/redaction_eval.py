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

Recall is measured by SUBSTRING ABSENCE: a planted secret string "recalls"
if it no longer appears verbatim, anywhere, in the redacted output for that
record. This is deliberately simpler than span-overlap scoring and doesn't
require the corpus to know anything about token boundaries — it directly
answers the question the bar cares about ("did this leak"), and it is
exactly as strict for partial-overlap cases: if only half of a planted
string got redacted, the other half is still a verbatim substring of the
original, so it still counts as a miss.

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
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_CORPUS = ROOT_DIR / "script/testdata/redaction_eval_corpus.jsonl"

STRUCTURED_BAR = 0.99
UNSTRUCTURED_BAR = 0.90


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
            if secret not in redacted:
                structured_hits += 1
        for secret in record["unstructured_secrets"]:
            unstructured_total += 1
            if secret not in redacted:
                unstructured_hits += 1

    structured_rate = structured_hits / structured_total if structured_total else 1.0
    unstructured_rate = unstructured_hits / unstructured_total if unstructured_total else 1.0

    return {
        "schema": "tilde.redaction-eval.v1",
        "corpus": {"records": len(corpus), "dropped_records": dropped_records},
        "structured": {
            "recall_count": structured_hits,
            "total": structured_total,
            "rate": structured_rate,
            "bar": STRUCTURED_BAR,
            "meets_bar": structured_rate >= STRUCTURED_BAR,
        },
        "unstructured": {
            "recall_count": unstructured_hits,
            "total": unstructured_total,
            "rate": unstructured_rate,
            "bar": UNSTRUCTURED_BAR,
            "meets_bar": unstructured_rate >= UNSTRUCTURED_BAR,
        },
        "privacy": {
            "aggregate_only": True,
            "contains_raw_text": False,
            "contains_matched_secrets": False,
            "contains_per_record_breakdown": False,
        },
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
