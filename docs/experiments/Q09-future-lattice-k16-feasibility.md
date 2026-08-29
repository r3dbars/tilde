# Q09 — Future Lattice K=16 feasibility

Status: PROPOSED
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-29T11:36:05Z

## Pre-registration

### Hypothesis

Adding bounded short Qwen futures beyond one direct greedy completion will
materially increase exact useful-prefix coverage on reply writing, and the
gain will remain visible when the same candidate set is read cumulatively at
K=1, K=4, K=8, and K=16.

### Why this should work

Starting inference before the next word boundary can hide model latency only
when an early candidate remains compatible with what the writer eventually
types. A larger bounded set may cover more plausible wording, but it may also
collapse into duplicates or purchase small recall gains with excessive local
compute. This diagnostic isolates that coverage-versus-cost question before
any live IME, scene-lifetime, or reveal-policy work.

The owner explicitly authorized this out-of-order diagnostic on 2026-08-29.
It does not unlock roadmap Stage 4, authorize live precomputation, or alter the
production or Model Preview applications.

### Control and nested treatments

- K=1: one greedy Qwen completion.
- K=4: K=1 plus three sampled short futures.
- K=8: K=4 plus four sampled short futures.
- K=16: K=8 plus eight sampled short futures.

Every K reads a prefix of the exact same ordered candidate set. Candidate 1
uses temperature 0. The fifteen additional candidates use temperature 0.40
with fixed distinct generation seeds. All candidates use the production
prompt, scene context, safety suppression, 12 generated tokens, and the
production cleaner capped at three visible words. No intent-diversity forcing
or post-result seed selection is permitted.

### Data and split

- Certified Corpus V2 development partition only;
- all 360 speak-expected development situations;
- one pass, 16 candidates per situation, 5,760 planned local generations;
- project-owned synthetic text only; and
- a 20-situation protocol pilot before the full run. The pilot may stop the
  run for machinery, privacy, protocol, or resource failure, never for a weak
  efficacy result.

Validation and holdout remain unopened.

### Primary metric

`golden_exact_prefix_coverage_at_16`: percentage of situations where at least
one of the first 16 cleaned candidates shares six or more exact visible future
characters with the recorded golden continuation.

### Supporting metrics

- golden exact-prefix coverage at K=1, K=4, and K=8;
- reviewed-path exact-prefix coverage using frozen acceptable continuations;
- marginal coverage for 4−1, 8−4, and 16−4;
- best exact future characters available at each K;
- unique cleaned candidates and unique first-two-content-word paths;
- candidate-set readiness p50/p95 at each K;
- summed request latency and decoded-token count as compute proxies; and
- protocol errors, timeouts, thermal state, and power state.

Exact Unicode-normalized character prefixes are the only coverage signal.
Semantic similarity cannot count as a match.

### Hard gates

- no personal writing, screen text, raw prompt, raw candidate, or per-case
  output may be persisted, printed, logged, or checked into Git;
- Qwen and the helper must match their frozen verified hashes;
- every planned situation must receive exactly 16 terminal candidate outcomes;
- the running production and Model Preview applications must not be stopped,
  replaced, or reconfigured;
- no validation or holdout data may be opened; and
- any protocol error, timeout, model/helper mismatch, non-loopback inference,
  memory-pressure warning, or serious/critical thermal state makes the result
  `INCONCLUSIVE`, not a pass. Fair thermal state is reported and requires a
  nominal-state sensitivity check before latency can support a decision.

### Promotion rule

This diagnostic may promote only to a later shadow timing/lock experiment when:

- golden exact-prefix coverage at K=16 is at least 30%;
- K=16 improves coverage by at least five percentage points over K=4;
- at least half of K=16 sets contain four distinct first-two-content-word
  paths; and
- no hard gate fails.

Passing does not authorize a live lattice.

### Kill rule

Reject the 16-branch lattice when any of these occurs:

- K=16 golden exact-prefix coverage is below 30%;
- K=16 gains less than five percentage points over K=4;
- median distinct first-two-content-word paths at K=16 is below four; or
- producing 16 independent short futures costs more than eight times the K=1
  summed request latency without a qualifying coverage gain.

If K=4 passes but K=16 fails its marginal-value bar, retain only the smaller
candidate-set hypothesis. Do not respond to failure by trying K above 16.

### Known confounders

- The golden continuation is a frozen synthetic path, not proof of a writer's
  latent intent or live acceptance.
- Independent sampled requests are a pessimistic compute implementation of a
  shared tree/beam decode.
- Candidate-set coverage is an upper bound; a safe target-blind lock rule may
  reveal far fewer suggestions.
- Running beside the daily Model Preview can affect timing even when it does
  not affect candidate content.
- A sampled K set is not calibrated world confidence.

### Frozen provenance

- Source commit: to be recorded before execution
- Dirty state: to be recorded before execution
- Model: Qwen 3.5 9B Base Q4_K_M
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256: `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256: to be recorded before execution
- Runner SHA-256: to be recorded before execution
- Suite SHA-256: to be recorded before execution
- Candidate seeds: frozen in the runner implementation
- Invocation digest: to be recorded before execution
- OS, hardware class, power state: to be recorded before execution

## Result

Status: PENDING

### Aggregate evidence

Pending.

### Failures and limitations

Pending.

### Decision

Pending.

### Durable changes

- Learning Ledger entry: only if the completed result changes durable knowledge
- Regression IDs: none
- Implementation pull request: pending
- Rollback: delete the development-only runner path; production is unchanged

### Follow-up

Only a passing coverage result may proceed to a separate target-blind consensus
lock and real typing-window experiment.
