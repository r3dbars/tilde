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
- The helper mirrors the production prose-register prompt, token budget,
  and final-only request shape. It does not exercise the chat or email recipes.
  Latency is `request_to_model_final`; there is no partial-response metric.
- Pair a baseline and candidate only when both are complete and their
  `selection_digest_sha256` values match. The two small aggregate reports are
  the manifest; there is no per-case results file.

This is raw-model evidence. It does not exercise the authenticated Tilde-to-IME
socket, production output cleaning, marked-text rendering, or acceptance.
Manual editor compatibility remains separate proof.

Personal History is never exported automatically and is not an input to this
raw-model evaluator. When explicitly enabled, Tilde separately runs an
on-device paired personal next-word shadow. The fixed baseline is
`r1435-live-v1`; the candidate is `r1945-live-v1`. At each fresh eligible word
boundary, both recipes freeze a prediction from the same prior authored words,
score against the same next authored word, and then learn that word. Accepted
suggestions are censored from both truth and training. This paired score is
observational and does not itself choose the visible suggestion. Separately,
when Personal History is enabled, production can query the conservative
baseline recipe without mutating the score and select its word over Gemma only
when the personal result clears the serving policy's support checks.

The aggregate result contains shared opportunities, baseline and candidate
prediction and exact-hit counts, a paired 3-by-3 silent/correct/wrong outcome
table, disagreements, active UTC days, learned-table capacity status, and rates.
It contains no words, candidate strings, or per-case rows. Tilde persists only
these lifetime aggregates and at most 64 aggregate daily buckets, encrypted in
the same history-log append as the events they score. The envelope validates the exact local
history identifier, durable exclusion generation, and exact exclusion set. Disable retains the checkpoint;
an exclusion change or Personal History deletion clears it.

At launch the live experiment restores that aggregate checkpoint and rebuilds
both learned recipes, without scoring, from the most recent complete events in
a bounded 4 MiB retained-history tail. It discards the first possibly truncated
token. Writing stored during that rebuild warms the model but is not scored;
after the referee is ready, new allowed batches are scored and checkpointed in
the same encrypted append. The current
dogfood corpus fits within that replay bound, but the live contract remains
bounded as the corpus grows. The first-token censor is intentional boundary
safety. The menu reports `memory limit reached` if the bounded derived table
fills.

Before reporting an outcome, the menu shows progress toward all four descriptive
minimums: 2,000 shared fresh-word opportunities, 200 candidate predictions, 100
baseline/candidate disagreements, and 14 active days. After all four are met it
shows candidate versus baseline effective rate, defined as exact hits divided by
the shared fresh-word opportunities. These thresholds are a descriptive reading
rule, not a significance test or a causal claim.

This live shadow remains observational evidence, not proof that personal
serving improves acceptance. A conservative personal lookup is already on the
visible path when Personal History is enabled; its product value still requires
separate visible-path evaluation.
