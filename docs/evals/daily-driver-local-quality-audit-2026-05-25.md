# Daily Driver Local Quality Audit - 2026-05-25

This is a local opt-in audit against disposable prompts only. It is not a real
private writing dogfood pass, and it does not persist raw prompt text or raw
model output.

## Command

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
AUTOCOMPLETE_LAB_RUNTIME_TIMEOUT=45 \
  ./script/local_quality_audit.py \
    --input docs/evals/daily-driver-disposable-prompts-2026-05-25.jsonl \
    --generate \
    --timeout 45 \
    --min-overall 92 \
    --min-relevance 72
```

## Result

- Source: current local model.
- Rows scored: 18.
- Display-eligible rows: 15.
- Suppressed/no-suggestion rows: 3.
- Expected suppressions passed: 3.
- Overall score: 100/100.
- Relevance score: 100/100.
- Raw output persisted: no.

## Failure Rates

- Relevance: 0% (0/18).
- Literal continuation: 0% (0/18).
- Assistant voice: 0% (0/18).
- Wrong topic: 0% (0/18).
- Too long: 0% (0/18).
- Structural breakage: 0% (0/18).
- Unsafe or sensitive content: 0% (0/18).
- Repetition: 0% (0/18).

## Rows

- PASS `daily-note-tone`: display-eligible.
- PASS `draft-calm-specific`: display-eligible.
- PASS `review-user-risk`: display-eligible.
- PASS `reply-short-kind`: display-eligible.
- PASS `ship-small-check`: display-eligible.
- PASS `meeting-next-step`: display-eligible.
- PASS `permission-clear`: display-eligible.
- PASS `proof-missing`: display-eligible.
- PASS `copy-short-clear`: display-eligible.
- PASS `hold-risky-path`: display-eligible.
- PASS `bug-fixture-case`: display-eligible.
- PASS `demo-open-questions`: display-eligible.
- PASS `product-one-change`: display-eligible.
- PASS `word-aligned`: display-eligible.
- PASS `word-redacted`: display-eligible.
- SUPPRESS `suppress-password`: expected no suggestion.
- SUPPRESS `suppress-search`: expected no suggestion.
- SUPPRESS `suppress-command`: expected no suggestion.

## Interpretation

This improves confidence in the current local model path for short continuations,
word suffixes, and obvious suppression cases. The remaining daily-driver gap is
still a real writing-session dogfood pass: accepted-kept rate, typed-over rate,
annoyance, and whether the suggestions actually feel worth reaching for.
