# Q09 — Future Lattice K=16 feasibility

Status: REJECTED
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

- Source commit: `999caf70eb67cec9ee7c2322a6a64e3e623a02b0`
- Dirty state: clean
- Model: Qwen 3.5 9B Base Q4_K_M
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256: `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256: `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`
- Runner SHA-256: `f36b2dda5e3103e737d371e1cff0290dd9fefa4373d246bd6b1df75956ff8279`
- Suite SHA-256: `5bbc362c93e4cf1e3383b81dfe56a48a2f7c5160cc492ad4e1a00b99ddd5b46c`
- Candidate seeds: frozen in the runner implementation
- Invocation digest: `057c6f817e96b257e56cc9716a08d05439d5318c44a414372fa483afe60381e3`
- OS, hardware class, power state: macOS 26.6.2 (`25G83`), Mac17,7,
  battery power; 88% at decisive-run start and 47% after completion

## Result

Status: REJECTED
Completed: 2026-08-29T12:05:20Z

### Aggregate evidence

The 20-situation protocol pilot completed all 320 planned generations with
nominal thermal state and no protocol or privacy failure. The decisive
development run then completed all 5,760 planned generations across 360
situations. Its report contains aggregates only and records no personal
writing, raw prompts, raw candidates, or scenario text.

| Set | Golden coverage | 95% Wilson interval | Reviewed-path coverage | Median distinct paths | Sets with >=4 paths | Readiness p50 / p95 | Summed-latency multiple |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| K=1 | 26.94% | 22.62–31.75% | 41.67% | 1 | 0.00% | 357 / 460 ms | 1.00x |
| K=4 | 35.00% | 30.25–40.06% | 58.89% | 1 | 2.50% | 1,214 / 1,513 ms | 7.77x |
| K=8 | 45.28% | 40.21–50.44% | 68.33% | 2 | 21.39% | 1,934 / 2,384 ms | 15.14x |
| K=16 | 46.67% | 41.58–51.83% | 70.56% | 2 | 27.22% | 3,593 / 4,331 ms | 49.12x |

Because the sets are nested, the five new golden matches from K=9–16 equal a
1.39 percentage-point increment over K=8 (95% Wilson interval 0.59–3.21).
K=16 improved 11.67 points over K=4, so it passed the registered coverage
level and K=4 marginal-gain bars. It failed the diversity gate: only 27.22% of
sets had four distinct first-two-content-word paths, below 50%, and the median
was two, below the kill threshold of four. K=8 already contained 163 of the
168 golden paths found by K=16.

The shareable aggregate is
[`Q09-aggregate-results.json`](Q09-aggregate-results.json).

### Failures and limitations

- The decisive run began on battery by explicit owner authorization. Thermal
  state moved from nominal to fair, so the latency figures are directional
  and cannot establish nominal-hardware timing.
- The rejection does not depend on timing: the registered diversity kill rule
  failed, and K=16 added only five golden matches beyond nested K=8.
- Exact synthetic-prefix coverage is an upper bound on candidate availability,
  not proof that a target-blind lock can choose the right future or that a
  writer will accept it.
- Independent requests are intentionally a pessimistic implementation of a
  shared decode tree. This result rejects 16 independently sampled branches,
  not every possible speculative-decoding implementation.
- Validation and holdout remained unopened. Production and Model Preview were
  unchanged and still running after the experiment.

### Decision

Reject the 16-independent-future lattice. Do not build it into the IME and do
not increase K beyond 16. The reusable signal is narrower: most measurable
set-level coverage arrived by K=8, while the second eight branches bought only
1.39 points and still failed to create the registered path diversity.

Retain a bounded K=4/K=8 or shared-tree hypothesis for a later registered
generator experiment, but do not promote it to live shadow timing from this
result. Its candidate-set readiness is still much slower than an inline typing
window, and a target-blind selection rule remains unproved.

### Durable changes

- Learning Ledger entry: `future-lattice-k16-independent-branches-rejected`
- Lab log: `2026-08-29 — Push the Future Lattice to sixteen branches`
- Regression IDs: none
- Implementation pull request: [#432](https://github.com/r3dbars/tilde/pull/432)
- Rollback: delete the development-only runner path; production is unchanged

### Follow-up

Return to the ordered research queue. If Future Lattice becomes eligible later,
test a preregistered smaller or genuinely diversity-producing shared generator
before any target-blind lock or real typing-window experiment.
