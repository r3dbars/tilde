#!/usr/bin/env python3
"""GLiNER-PII inference helper — the app's redaction model-layer child process.

Architecture (see PR 3b body for the full in-process-vs-helper-process
rationale): `RedactionService` in the app runs `SecretRules` (structured
secrets) itself, in-process, in pure Swift. For freeform PII it hands text
to THIS process over a stdin/stdout JSON-lines pipe — no TCP port, no
network stack at all, just two OS pipes to a child the app spawned. This
process's only job is to run the real, upstream `gliner` package's
`predict_entities` against the pinned ONNX artifact and hand back spans.

Why a helper process runs the real `gliner` package instead of the Swift
side reimplementing GLiNER's pre/post-processing (DeBERTa-v3 SentencePiece
word-splitting, span-grid construction, biaffine decode + greedy overlap
resolution — collectively ~2,500 lines across gliner's processor.py and
decoder.py): that logic is the ENTIRE correctness surface of a fail-closed
security feature. A from-scratch Swift/C++ port could not be cross-checked
against the reference implementation within this PR, and a subtly wrong
decode is a SILENT PII leak, not a crash — the worst possible failure mode
to risk on unverified new code. Running the actual, spike-validated
`gliner` code path trades a process boundary (which this repo already has
a hardened pattern for — see `LlamaServerProcessHost`) for certainty that
redaction spans match the reference exactly.

Packaging note: the release driver does not yet bundle a frozen Python
runtime for this helper (that is `package_app.sh`'s job, tracked as
follow-up — see PR 3b body). For now this script runs under a dev-only
override (`TILDE_DEV_REDACTION_HELPER_PYTHON` /
`TILDE_DEV_REDACTION_HELPER_SCRIPT` / `TILDE_DEV_REDACTION_MODEL_DIR`, see
`GLiNERRedactionHelperHost.swift`), the same pattern
`LlamaServerProcessHost` already uses for `TILDE_DEV_LLAMA_SERVER` /
`TILDE_DEV_MODEL_PATH` before a model is sealed into a release bundle.

Protocol (line-delimited JSON, UTF-8, one request per line):
  Startup: this process prints exactly one line, `{"ready": true}` or
    `{"ready": false, "reason": "<code>"}`, then either serves requests or
    exits (fail-closed: caller must treat "ready": false or an unexpected
    exit as unavailable, never retry-forever).
  Request:  {"text": "...", "labels": [...], "threshold": 0.5}
  Response: {"ok": true, "spans": [{"start": int, "end": int, "label": str,
             "score": float}]}
          or {"ok": false, "reason": "<code>"}  — NEVER includes the input
             text, a stack trace, or any fragment of the text in the
             `reason` code; reasons are a small fixed vocabulary
             (`bad-json`, `missing-text`, `inference-error`) so a caller
             can log them safely.

This process never writes anything to stderr containing request text —
only fixed, text-free diagnostic strings. `main()` wraps every per-request
step in a narrow try/except specifically so one bad request cannot dump a
Python traceback (which would include the input text in the frame locals
formatting) to any stream.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REASON_BAD_JSON = "bad-json"
REASON_MISSING_TEXT = "missing-text"
REASON_INFERENCE_ERROR = "inference-error"


def emit(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def load_model(model_path: Path, tokenizer_dir: Path):
    from gliner import GLiNER  # noqa: PLC0415

    return GLiNER.from_pretrained(
        str(tokenizer_dir),
        load_tokenizer=True,
        load_onnx_model=True,
        onnx_model_file=str(model_path),
    )


def serve(model, default_threshold: float) -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            emit({"ok": False, "reason": REASON_BAD_JSON})
            continue

        text = request.get("text")
        if not isinstance(text, str) or not text:
            emit({"ok": False, "reason": REASON_MISSING_TEXT})
            continue
        labels = request.get("labels") or DEFAULT_LABELS
        threshold = request.get("threshold", default_threshold)

        try:
            entities = model.predict_entities(text, labels, threshold=threshold)
        except Exception:  # noqa: BLE001 — fail-closed, never propagate text via a traceback
            emit({"ok": False, "reason": REASON_INFERENCE_ERROR})
            continue

        spans = [
            {
                "start": entity["start"],
                "end": entity["end"],
                "label": entity["label"],
                "score": entity["score"],
            }
            for entity in entities
        ]
        emit({"ok": True, "spans": spans})


# The PII surface GLiNER-PII was trained on that has no reliable regex
# shape — exactly the set `SecretRules` cannot catch structurally. Kept
# here (not hardcoded caller-side) so the label vocabulary and the model
# artifact it was validated against stay next to each other.
#
# This exact 11-label set (and no more) was chosen empirically, not
# arbitrarily — see PR 3b body for the measurements. Two things were
# measured and both matter:
#   1. Label WORDING matters a lot: "address" scores far higher than
#      "street_address" for the identical span; "employer" alone (not
#      "employer_name") was the reliable one for employer names.
#   2. Label SET SIZE matters independently of wording: the same wording
#      that scores >=0.9 in an 8-11 label prompt can drop below the 0.5
#      ship threshold entirely once the type-prompt grows past ~14 labels
#      (observed with a 14-label prompt that included national_id,
#      passport_number, driver_license_number — none of which had been
#      validated to score reliably on their own, and adding them
#      measurably hurt recall on the OTHER, previously-reliable labels
#      too). Anyone adding a label here must re-run
#      `script/redaction_eval.py` against the full set, not just spot-check
#      the new label in isolation — the bar is on the SET as shipped.
DEFAULT_LABELS = [
    "person_name",
    "email",
    "phone_number",
    "credit_card_number",
    "api_key",
    "password",
    "ssn",
    "date_of_birth",
    "address",
    "medical_condition",
    "employer",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", type=Path, required=True, help="Path to the ONNX model file to load.")
    parser.add_argument(
        "--tokenizer-dir", type=Path, required=True,
        help="Directory containing gliner_config.json/tokenizer.json/tokenizer_config.json.",
    )
    parser.add_argument("--threshold", type=float, default=0.5, help="Default confidence threshold.")
    args = parser.parse_args()

    try:
        model = load_model(args.model, args.tokenizer_dir)
    except Exception:  # noqa: BLE001
        emit({"ready": False, "reason": "model-load-failed"})
        return 1

    emit({"ready": True})
    serve(model, args.threshold)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
