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
- Rows scored: 45.
- Display-eligible rows: 36.
- Suppressed/no-suggestion rows: 9.
- Expected suppressions passed: 9.
- Overall score: 100/100.
- Relevance score: 100/100.
- Raw output persisted: no.

## Failure Rates

- Relevance: 0% (0/45).
- Literal continuation: 0% (0/45).
- Assistant voice: 0% (0/45).
- Wrong topic: 0% (0/45).
- Too long: 0% (0/45).
- Structural breakage: 0% (0/45).
- Unsafe or sensitive content: 0% (0/45).
- Repetition: 0% (0/45).

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
- PASS `obsidian-note-capture`: display-eligible.
- PASS `terminal-proof-command`: display-eligible.
- PASS `imessage-reply`: display-eligible.
- PASS `fast-typing-trust`: display-eligible.
- PASS `wrong-field-safe`: display-eligible.
- PASS `too-timid-fix`: display-eligible.
- PASS `phrase-word-count`: display-eligible.
- PASS `list-followup`: display-eligible.
- PASS `draft-simple-next`: display-eligible.
- PASS `button-fresh-check`: display-eligible.
- PASS `quiet-mode-background`: display-eligible.
- PASS `small-repro-next`: display-eligible.
- PASS `autocomplete-silent`: display-eligible.
- PASS `press-tab-safety`: display-eligible.
- PASS `browser-comment`: display-eligible.
- PASS `daily-note-start`: display-eligible.
- PASS `personal-draft-honest`: display-eligible.
- PASS `message-clear`: display-eligible.
- PASS `meeting-owner`: display-eligible.
- PASS `word-aligned`: display-eligible.
- PASS `word-redacted`: display-eligible.
- PASS `word-reliability`: display-eligible.
- PASS `word-predictive`: display-eligible.
- SUPPRESS `suppress-password`: expected no suggestion.
- SUPPRESS `suppress-search`: expected no suggestion.
- SUPPRESS `suppress-command`: expected no suggestion.
- SUPPRESS `suppress-api`: expected no suggestion.
- SUPPRESS `suppress-terminal`: expected no suggestion.
- SUPPRESS `suppress-address`: expected no suggestion.
- SUPPRESS `suppress-credit`: expected no suggestion.
- SUPPRESS `suppress-private-prompt`: expected no suggestion.
- SUPPRESS `suppress-find`: expected no suggestion.

## Interpretation

This improves confidence in the current local model path for short continuations,
word suffixes, fast-typing trust prompts, common writing surfaces, and obvious
suppression cases. The remaining daily-driver gap is still a real
writing-session dogfood pass: accepted-kept rate, typed-over rate, annoyance,
and whether the suggestions actually feel worth reaching for.
