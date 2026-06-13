# Small Model Blind Quality Audit - 2026-06-12

This is the Wave 1 rerun lane for the small-model bet. The old 1.7B result is
not enough to promote anything because it may have used an instruct/chat prompt
shape for a completion-shaped task.

## Lane

- 1B-class lane: `small-draft-1b` / `qwen3-1.7b`.
- Base completion lane: `qwen3-1.7b-base` / `raw_completion`.
- Small alternative: `qwen3-0.6b` / `raw_completion`.
- Default model remains: `qwen35-4b`.
- Default switch: no.
- Source mix: synthetic-public.
- No private text: yes.
- Blindness check: no current complaint-language fixtures.
- Result status: runnable-not-measured.

## Prompt Set

- Prompt rows: 36.
- Display rows: 30.
- Expected suppression rows: 6.
- Fresh generated rows scored in this rerun: 0.
- Raw output persisted: no.

## Command

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT=45 \
  ./script/small_model_blind_audit_report.py --run
```

Fallback single-model command:

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT=45 \
  ./script/local_quality_audit.py \
    --input docs/evals/small-model-blind-prompts-2026-06-12.jsonl \
    --generate \
    --model qwen3-1.7b-base \
    --timeout 45
```

## Local Availability Snapshot

`./script/small_model_blind_audit_report.py` was run locally. It found installed
assets for `qwen3-1.7b-base`, `qwen3-0.6b`, and `qwen35-4b`, and the runtime
bridge detected an `mlx_lm`-capable Python. A generated `--run` attempt was
started, but it was stopped after more than two minutes without completing the
first model row, so no fresh blind-audit quality numbers were generated.

| Model | Template | Quality | Latency | Memory | Decision | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `qwen3-1.7b-base` | `raw_completion` | overall unknown, relevance unknown | unknown | 938.4 MiB | no decision | installed; generated run not completed |
| `qwen3-0.6b` | `raw_completion` | overall unknown, relevance unknown | unknown | 335.1 MiB | no decision | installed; generated run not completed |
| `qwen35-4b` | `chat_instruct` | overall unknown, relevance unknown | unknown | 2.9 GiB | no decision | installed; baseline still default |

## Decision Gate

Promotion gate: default only if blind-audit overall >= (4B score - 5) and first-token p50 <= 50% of 4B.

Draft/speculative gate: if quality misses but latency wins big, keep it out of default and test only as draft/speculative.

## Interpretation

No default model change. The new template layer makes the base-model rerun
possible, but this PR does not contain a measured win. The next valid decision
requires the generated blind audit to run with `raw_completion` for the base
models and `chat_instruct` for the 4B baseline.
