#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="${ROOT_DIR}/script/local_completion_runtime.py"

WARMUP_COUNT="${AUTOCOMPLETE_GEMMA_WARMUP_COUNT:-3}"
SAMPLE_COUNT="${AUTOCOMPLETE_GEMMA_SAMPLE_COUNT:-10}"
TARGET_MS="${AUTOCOMPLETE_GEMMA_TARGET_MS:-700}"
STRETCH_MS="${AUTOCOMPLETE_GEMMA_STRETCH_MS:-300}"
GENERATED_TOKENS="${AUTOCOMPLETE_GEMMA_GENERATED_TOKENS:-16}"

if [[ ! -x "$HELPER" ]]; then
  echo "missing executable runtime helper: $HELPER" >&2
  exit 2
fi

python3 - "$HELPER" "$WARMUP_COUNT" "$SAMPLE_COUNT" "$TARGET_MS" "$STRETCH_MS" "$GENERATED_TOKENS" <<'PY'
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

helper = sys.argv[1]
warmup_count = int(sys.argv[2])
sample_count = int(sys.argv[3])
target_ms = int(sys.argv[4])
stretch_ms = int(sys.argv[5])
generated_tokens = int(sys.argv[6])
root = Path(helper).resolve().parents[1]

payload = json.dumps({
    "system": "Complete the user's writing. Return only the next 8 words or fewer. No quotes. No explanation. No reasoning.",
    "user": "I think this should"
})


def local_bin(name):
    path = root / ".venv" / "bin" / name
    if os.access(path, os.X_OK):
        return str(path)
    return shutil.which(name)


def available(backend):
    if backend == "litert":
        return bool(os.environ.get("AUTOCOMPLETE_LAB_LITERT_BIN") or local_bin("litert-lm"))
    if backend == "mlx":
        if os.environ.get("AUTOCOMPLETE_LAB_MLX_BIN") or local_bin("mlx_lm.generate"):
            return True
        python = local_bin("python3")
        if not python:
            return False
        return subprocess.run(
            [python, "-c", "import mlx_lm.generate"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
    return False


def run_once(backend):
    started = time.perf_counter()
    completed = subprocess.run(
        [
            helper,
            "--model",
            "Gemma 4 E2B",
            "--max-tokens",
            str(generated_tokens),
            "--max-words",
            "8",
            "--reasoning",
            "off",
        ],
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "AUTOCOMPLETE_LAB_RUNTIME_BACKEND": backend},
        timeout=float(os.environ.get("AUTOCOMPLETE_LAB_BENCHMARK_TIMEOUT", "30")),
        check=False,
    )
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"exit code {completed.returncode}")
    return elapsed_ms, completed.stdout.strip()


def benchmark(backend):
    if not available(backend):
        return {"backend": backend, "available": False, "error": "runtime command not found"}

    try:
        for _ in range(warmup_count):
            run_once(backend)

        samples = []
        last_output = ""
        for _ in range(sample_count):
            elapsed_ms, last_output = run_once(backend)
            samples.append(elapsed_ms)

        average = int(sum(samples) / len(samples))
        return {
            "backend": backend,
            "available": True,
            "average_ms": average,
            "samples": samples,
            "last_output": last_output,
        }
    except Exception as error:
        return {"backend": backend, "available": False, "error": str(error)}


results = [benchmark("litert"), benchmark("mlx")]

print("Gemma 4 E2B runtime benchmark")
print(f"warmup={warmup_count} samples={sample_count} target={target_ms}ms stretch={stretch_ms}ms")

recommendation = None
for result in results:
    name = "LiteRT-LM" if result["backend"] == "litert" else "MLX"
    if not result["available"]:
        print(f"{name}: unavailable - {result['error']}")
        continue

    average = result["average_ms"]
    if average <= stretch_ms:
        label = "passes stretch"
    elif average <= target_ms:
        label = "passes target"
    else:
        label = "too slow"

    print(f"{name}: {average}ms avg, {label}")
    if result.get("last_output"):
        print(f"{name} sample: {result['last_output'][:120]}")
    if recommendation is None and average <= target_ms:
        recommendation = name

print(f"recommendation={recommendation or 'none'}")
if recommendation is None:
    print("No user-managed server was started. Install LiteRT-LM or MLX locally, then run this again.")
PY
