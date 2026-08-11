# Continuation evaluation

`script/golden_eval.py` verifies that the running Tilde app owns its exact
packaged `llama-server` child, then runs one bounded continuation quiz. It
deterministically cuts each approved corpus record into a typed prefix and
expected continuation, then emits one aggregate JSON report.

The input contract is JSONL with one required string field:

```json
{"text":"a complete piece of writing with enough words to split"}
```

Other fields are ignored. The repository no longer includes a dataset fetcher:
corpus sourcing and approval are separate from evaluation, and the evaluator
must not create, copy, display, or persist raw writing.

## Run it

```sh
python3 script/golden_eval.py --selftest

python3 script/golden_eval.py \
  --corpus approved-corpus.jsonl \
  --max-cases 200 \
  --arm baseline \
  --build-id 1.2.3+456 \
  --model-id gemma-2-2b-q4km \
  --config-id defaults-v1 > baseline.json

python3 script/golden_eval.py \
  --corpus approved-corpus.jsonl \
  --max-cases 200 \
  --arm candidate \
  --build-id 1.2.3+457 \
  --model-id gemma-2-2b-q4km \
  --config-id candidate-v1 > candidate.json
```

Runtime identifiers are optional. Use exact, short identifiers when known;
unknown values remain `null`. Paths and free-text labels are rejected.

The default target is `dist/Tilde.app`; that exact app must be running with its
packaged helper listening on localhost. Ownership is checked before the quiz.
Use `--app-binary` only when evaluating another exact packaged build. There is
no option to bypass the ownership check.

## Trust contract

- Case membership is stable: canonical text is identified by SHA-256, sorted,
  deduplicated, and bounded to `--max-cases` (default 200, hard maximum 2,000).
- Reports contain fixed schema and proof labels, validated runtime identifiers,
  corpus and selection digests, outcomes, counts, rates, and latency aggregates.
  They never contain contexts, continuations, suggestions, bundle identifiers,
  corpus paths, socket paths, or per-case results.
- Outcomes are explicit: `ok`, `silent`, `protocol_error`, and `timeout`.
  Any protocol error or timeout makes `complete=false` and exits nonzero.
- The helper is called with the same deterministic prose prompt, token budget,
  and final-only request shape as production. Latency is
  `request_to_model_final`; there is no partial-response metric.
- Pair a baseline and candidate only when both are complete and their
  `selection_digest_sha256` values match. The two small aggregate reports are
  the manifest; there is no per-case results file.

This is raw-model evidence. It does not exercise the authenticated Tilde-to-IME
socket, production output cleaning, marked-text rendering, or acceptance.
Manual editor compatibility remains separate proof.
