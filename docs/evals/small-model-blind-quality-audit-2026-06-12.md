# Small Model Blind Quality Audit - 2026-06-12

This is a blind local quality lane for the 1B-class draft model. The fixture
uses public-facing synthetic snippets such as library notices, museum labels,
recipe cards, transit alerts, and community flyers. It avoids the current
complaint-language fixtures around wrong fields, placement, timid suggestions,
or annoyance.

## Lane

- 1B-class lane: `small-draft-1b` / `qwen3-1.7b`.
- Default model remains: `qwen35-4b`.
- Default switch: no.
- Source mix: synthetic-public.
- No private text: yes.
- Blindness check: no current complaint-language fixtures.
- Result status: measured-failed-quality-bar.

## Command

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT=45 \
  ./script/local_quality_audit.py \
    --input docs/evals/small-model-blind-prompts-2026-06-12.jsonl \
    --generate \
    --model small-draft-1b \
    --timeout 45 \
    --min-overall 92 \
    --min-relevance 72
```

## Result

- Rows scored: 36.
- Display rows: 30.
- Expected suppression rows: 6.
- Display-eligible rows after scoring: 0.
- Suppressed/no-suggestion rows after scoring: 36.
- Expected suppressions passed: 6.
- Overall score: 63/100.
- Relevance score: 7/100.
- Raw output persisted: no.

## Interpretation

The 1.7B lane is runnable and privacy-safe, but it failed the quality bar. It
mostly echoed or drifted from the public/synthetic prompts, while the safety
suppression rows passed. Keep `qwen35-4b` as the quality default until a small
model beats it on both this blind audit and latency.
