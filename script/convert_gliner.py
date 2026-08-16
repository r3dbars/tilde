#!/usr/bin/env python3
"""Operator-run conversion of nvidia/gliner-PII to a pinned ONNX artifact.

This is NOT part of the app build and is never invoked by `proof.sh`,
`package_app.sh`, or any runtime code path — it is a one-time (per model
version) conversion step an operator runs by hand, exactly like the llama
model packaging step described in AGENTS.md. Its job is to turn the
HuggingFace checkpoint into a small set of files with a sha256 the operator
can review and pin into `package_app.sh` as a third bundled input, alongside
the llama-server helper and the Gemma model.

Why this exists (spike findings, see docs/plans/screen-memory.md PR 3b):
  - nvidia/gliner-PII downloads publicly; Core ML conversion FAILS (DeBERTa-v3
    disentangled attention has no Core ML lowering as of coremltools 9.0 —
    `torch.jit.trace` succeeds but `ct.convert` cannot lower the resulting
    graph). ONNX export via gliner 0.2.28's own `export_to_onnx` (opset 17)
    works and gives byte-identical predictions against the PyTorch model.
  - INT8 dynamic quantization roughly halves the artifact size (fp32 model.onnx
    ~1.7GB -> model_int8.onnx ~620MB) and was spot-check-identical on a
    handful of examples, but upstream GLiNER issue #218 reports INT8
    degrading recall on some entity types. This script does NOT decide
    int8 vs fp16 for you — it produces both, and `script/redaction_eval.py`
    is what validates each against the ship bar before an operator picks one
    (see "Choosing a precision" below).

Pipeline:
  1. Load the cached HF checkpoint (fp32 pytorch_model.bin).
  2. Export to ONNX (opset 17) via `gliner.GLiNER.export_to_onnx`n     — the
     exact code path gliner's own onnx runtime loader expects, so the
     resulting graph's input/output contract matches what ships.
  3. Convert a float16 copy (`onnxconverter_common.float16.convert_float_to_float16`,
     keeping the io layer in fp32 — an ONNX Runtime CPU EP requirement for
     some ops) as the size/quality-preserving alternative to int8.
  4. Quantize an int8 copy via `onnxruntime.quantization.quantize_dynamic`
     (QUInt8, dynamic — the same recipe as the spike).
  5. Copy tokenizer assets needed at inference time (tokenizer.json,
     tokenizer_config.json, gliner_config.json) next to the exported models.
  6. Print a sha256 + byte size manifest for every produced file. That
     manifest — not this script's own hash — is what an operator reviews
     and pins into `package_app.sh --model-sha256`-style arguments.

Requirements (NOT bundled, NOT installed by proof.sh or the app):
  python3.11+, torch, transformers, gliner==0.2.28, onnx, onnxruntime,
  onnxruntime-tools (quantization), onnxconverter-common (fp16). Install
  into a scratch virtualenv; never into the system/app Python (there is no
  app Python — Tilde does not bundle or require a Python runtime for
  inference; see AGENTS.md "Inference is app-owned and bundled").

Choosing a precision (RESOLVED for the PR 3b checkpoint — re-run this
comparison if the checkpoint ever changes):
  Measured via `script/redaction_eval.py` against the committed synthetic
  corpus, threshold 0.5 (the shipped default), 11-label prompt (see
  `script/redaction_helper.py`'s `DEFAULT_LABELS`):
    - fp32 (model.onnx, 1.78GB):    structured 78/78 (100%), unstructured
      66/66 (100%). Clears both bars.
    - int8 (model_int8.onnx, 653MB): structured 78/78 (100% — the rules
      layer is precision-independent), unstructured 0/66 (0%). Does NOT
      clear the unstructured bar — confirms GLiNER issue #218's INT8
      degradation report, and the collapse is total, not marginal, at this
      threshold.
    - fp16 (model_fp16.onnx): FAILS TO LOAD on ONNX Runtime's CPU execution
      provider (`Type Error: Type (tensor(float16)) of output arg ... does
      not match expected type (tensor(float))` — a Cast node boundary issue
      with this graph's fp16 conversion, not a recall question; fp16 on
      onnxruntime is really a GPU/CoreML-EP path and CoreML conversion
      already fails for this model per the spike). Disqualified outright,
      not a quality tradeoff.
  Decision: SHIP fp32. It is the only precision that is both loadable and
  correct. This means the bundle is ~1.78GB, not the plan's ~300-400MB
  estimate (which assumed int8-scale sizing) — flagged explicitly for the
  owner in the PR body. Recovering int8's size at fp32's recall (e.g.
  static/QDQ quantization with calibration data, or excluding the span-
  classification head from quantization) is real follow-up work, not
  something this script attempts.

Example (matches the exact repro used for the numbers in PR 3b):
  python3 -m venv /tmp/gliner-convert-venv
  /tmp/gliner-convert-venv/bin/pip install \\
      torch==2.13.0 transformers==5.13.1 gliner==0.2.28 \\
      onnx==1.22.0 onnxruntime==1.28.0 onnxruntime-tools==1.7.0 \\
      onnxconverter-common==1.14.0
  /tmp/gliner-convert-venv/bin/python script/convert_gliner.py \\
      --model-dir ~/.cache/tilde-eval/gliner-pii \\
      --out-dir ~/.cache/tilde-eval/gliner-onnx
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

REQUIRED_SOURCE_FILES = (
    "pytorch_model.bin",
    "gliner_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "spm.model",
)

ASSETS_TO_COPY = (
    "gliner_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
)

# NVIDIA Open Model License permits commercial use of nvidia/gliner-PII per
# the model card (see PR body for the owner's legal glance). This constant
# is written into the manifest so it travels with the artifact rather than
# living only in a commit message.
LICENSE_NOTE = (
    "nvidia/gliner-PII — NVIDIA Open Model License. Commercial use permitted "
    "per the model card as of the PR 3b spike (2026-08). Re-verify at "
    "https://huggingface.co/nvidia/gliner-PII if this script is re-run "
    "against a newer checkpoint."
)


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_source_files(model_dir: Path) -> None:
    missing = [name for name in REQUIRED_SOURCE_FILES if not (model_dir / name).exists()]
    if missing:
        raise SystemExit(
            f"convert_gliner: missing required file(s) in {model_dir}: {', '.join(missing)}\n"
            "Expected a local HF snapshot of nvidia/gliner-PII "
            "(e.g. `huggingface-cli download nvidia/gliner-PII "
            f"--local-dir {model_dir}`)."
        )


def export_onnx(model_dir: Path, out_dir: Path, opset: int) -> Path:
    """Export the fp32 ONNX graph via gliner's own export path.

    Deliberately calls into `gliner`'s packaged export rather than a
    hand-rolled `torch.onnx.export` — the app's runtime loads this graph by
    input/output name (`input_ids`, `attention_mask`, `words_mask`,
    `text_lengths`, `span_idx`, `span_mask` -> `logits`), and only gliner's
    own exporter is guaranteed to produce that exact, versioned contract.
    `export_to_onnx` also writes gliner_config.json and the tokenizer files
    into `out_dir` itself as a side effect; `copy_assets` below is a no-op
    over the same files when they already match, kept so this script also
    works against a `--model-dir` that lacks tokenizer files for some reason.
    """
    from gliner import GLiNER  # noqa: PLC0415 (operator-only import, not app code)

    print(f"[convert_gliner] loading fp32 checkpoint from {model_dir}", file=sys.stderr)
    model = GLiNER.from_pretrained(str(model_dir), load_tokenizer=True)
    model.eval()

    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"[convert_gliner] exporting ONNX (opset {opset}) to {out_dir}/model.onnx", file=sys.stderr)
    result = model.export_to_onnx(str(out_dir), onnx_filename="model.onnx", opset=opset)
    onnx_path = Path(result["onnx_path"])
    if not onnx_path.exists():
        raise SystemExit(f"convert_gliner: export_to_onnx did not produce {onnx_path}")
    return onnx_path


def convert_fp16(onnx_path: Path, out_path: Path) -> Path:
    from onnxconverter_common import float16  # noqa: PLC0415
    import onnx  # noqa: PLC0415

    print(f"[convert_gliner] converting {onnx_path.name} -> fp16", file=sys.stderr)
    model = onnx.load(str(onnx_path))
    # keep_io_types=True: input_ids/attention_mask/etc. stay int64, matching
    # the app-side tensor construction regardless of which precision ships.
    fp16_model = float16.convert_float_to_float16(model, keep_io_types=True)
    onnx.save(fp16_model, str(out_path), save_as_external_data=False)
    return out_path


def quantize_int8(onnx_path: Path, out_path: Path) -> Path:
    from onnxruntime.quantization import QuantType, quantize_dynamic  # noqa: PLC0415

    print(f"[convert_gliner] quantizing {onnx_path.name} -> int8 (dynamic, QUInt8)", file=sys.stderr)
    quantize_dynamic(
        model_input=str(onnx_path),
        model_output=str(out_path),
        weight_type=QuantType.QUInt8,
    )
    return out_path


def copy_assets(model_dir: Path, out_dir: Path) -> list[Path]:
    copied = []
    for name in ASSETS_TO_COPY:
        source = model_dir / name
        destination = out_dir / name
        shutil.copyfile(source, destination)
        copied.append(destination)
    # spm.model is required for tokenization but is large-ish and
    # content-addressed by the caller's own pin already (it is unchanged
    # from the HF snapshot) — copy it too so out_dir is self-contained.
    spm_source = model_dir / "spm.model"
    spm_dest = out_dir / "spm.model"
    shutil.copyfile(spm_source, spm_dest)
    copied.append(spm_dest)
    return copied


def build_manifest(out_dir: Path, produced: list[Path]) -> dict:
    return {
        "schema": "tilde.gliner-convert-manifest.v1",
        "license": LICENSE_NOTE,
        "files": [
            {
                "name": path.name,
                "bytes": path.stat().st_size,
                "sha256": sha256_of(path),
            }
            for path in sorted(produced, key=lambda p: p.name)
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--model-dir", type=Path, required=True,
        help="Local HF snapshot directory of nvidia/gliner-PII (must contain pytorch_model.bin).",
    )
    parser.add_argument(
        "--out-dir", type=Path, required=True,
        help="Output directory for model.onnx, model_fp16.onnx, model_int8.onnx, and tokenizer assets.",
    )
    parser.add_argument("--opset", type=int, default=17, help="ONNX opset version (default 17).")
    parser.add_argument(
        "--skip-fp16", action="store_true", help="Skip fp16 conversion (only export fp32 + int8).",
    )
    parser.add_argument(
        "--skip-int8", action="store_true", help="Skip int8 quantization (only export fp32 + fp16).",
    )
    args = parser.parse_args()

    model_dir = args.model_dir.expanduser().resolve()
    out_dir = args.out_dir.expanduser().resolve()

    require_source_files(model_dir)

    produced: list[Path] = []
    fp32_path = export_onnx(model_dir, out_dir, args.opset)
    produced.append(fp32_path)

    if not args.skip_fp16:
        produced.append(convert_fp16(fp32_path, out_dir / "model_fp16.onnx"))
    if not args.skip_int8:
        produced.append(quantize_int8(fp32_path, out_dir / "model_int8.onnx"))

    produced.extend(copy_assets(model_dir, out_dir))

    manifest = build_manifest(out_dir, produced)
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    print(json.dumps(manifest, indent=2))
    print(f"\n[convert_gliner] manifest written to {manifest_path}", file=sys.stderr)
    print(
        "[convert_gliner] next: run script/redaction_eval.py against each "
        "precision's model to choose which one ships (see module docstring "
        "'Choosing a precision').",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
