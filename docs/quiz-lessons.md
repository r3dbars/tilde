# Continuation evaluation

`script/golden_eval.py` runs one bounded continuation quiz against the local
Tilde socket. It deterministically cuts each approved corpus record into a typed
prefix and expected continuation, then emits one aggregate JSON report.

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

## Trust contract

- Case membership is stable: canonical text is identified by SHA-256, sorted,
  deduplicated, and bounded to `--max-cases` (default 200, hard maximum 2,000).
- Reports contain only corpus/selection digests, counts, rates, and latency
  aggregates. They never contain contexts, continuations, suggestions, app IDs,
  corpus paths, or socket paths.
- Outcomes are explicit: `ok`, `silent`, `protocol_error`, and `timeout`.
  Any protocol error or timeout makes `complete=false` and exits nonzero.
- Latencies are named for what the client can observe:
  `request_to_first_partial` and `request_to_final`.
- Pair a baseline and candidate only when both are complete and their
  `selection_digest_sha256` values match. The two small aggregate reports are
  the manifest; there is no per-case results file.

The historical model bakeoff selected Gemma 2 2B as the size/latency balance.
That is product-decision context, not current proof; new claims require a fresh,
paired baseline/candidate run under this contract.
