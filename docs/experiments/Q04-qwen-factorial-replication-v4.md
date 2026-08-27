# Q04 — Qwen 9B factorial replication v4

Status: PROPOSED
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-27T12:24:44Z

## Pre-registration

### Hypothesis

With deterministic prompt-injection and non-actionable-scene suppression
frozen identically across arms, Qwen 9B God v1 at temperature 0.10 with a
12-token budget (`qwen-factorial-a5`) will outperform the greedy 20-token
baseline (`qwen-factorial-a0`) on paired Certified Corpus V2 development cases
without weakening hard gates, harm, protected slices, net keystroke savings,
or latency.

### Why this should work

Earlier search associated God v1 with slightly more useful and fewer wrong
suggestions. Q02 exposed prompt-injection and non-actionable-scene failures;
Q03 verified that the first fix removed those classes but isolated 98 remaining
interruptions to irrelevant declarative scenes. PRs #425 and #427 now suppress
both classes before inference, with corpus-wide positive-reply coverage.

### Arms and controls

The fixed eight-arm factorial crosses temperatures 0, 0.05, 0.10, and 0.15
with generation budgets of 20 and 12 tokens. All other model, prompt, context,
safety, scoring, display, and runtime controls are identical. Only a5 versus a0
is decision-bearing; the other arms are exploratory.

### Data and runtime

- Certified Corpus V2 development partition;
- seeds 17, 41, and 73 with 24 repetitions per seed;
- interleaved root blocks of 20 after invariant smoke;
- one worker and eight local Qwen slots;
- 345,600 planned requests, 350,000 ceiling, eight active-hour ceiling; and
- AC power with a separate sleep-prevention job.

### Primary metric

Paired expected utility under `net-keystrokes-v1`, a5 versus a0.

### Supporting metrics and hard gates

Net keystroke savings, useful and wrong suggestions, bad-when-shown rate,
protected slices, per-seed effects, worst seed, and latency. Every prompt-leak,
sensitive-scene, stale-context, echo, unsupported-fact, temporal, privacy,
interaction, and latency gate must pass. Invariant smoke is terminal.

### Promotion and kill rules

Advance only a5 and only with positive paired effect, at least 0.95 bootstrap
probability, no bad-when-shown or protected-slice regression, every hard gate
passing, and at most 25 milliseconds latency regression. Stop on any gate,
provenance, protocol, helper, pairing, request, or active-time failure. This
campaign does not consume protected validation or change production.

### Frozen public provenance

- Source commit: `320a0e93f5e8dbde5313e3d049c0a8bcd186e3ca`
- Dirty state: clean detached source clone
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256:
  `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256:
  `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`
- Runner SHA-256:
  `a57674994898fbd41de5bc4d0feb6177f99460bd3b2d86c5f1cc3969729eb187`
- Campaign document SHA-256:
  `80c138a2749d4fb5f85bd75f1eb72597c3f3df430808163ebeeeab06331fd052`
- Campaign ID: `8602BAE2-87CA-4FD4-8E05-22252FD40886`

### Known limitations

Synthetic cases cannot establish live retained usefulness. One Mac cannot
remove all thermal variation. Exploratory arms cannot replace a5. Invariant
smoke may correctly stop before the long run.

## Result

Status: PENDING

### Aggregate evidence

Pending execution.

### Failures and limitations

Pending execution.

### Decision

Pending execution.

### Durable changes

- Learning Ledger entry: pending reusable result
- Regression IDs: covered by PRs #425 and #427
- Results pull request: pending
- Rollback: retain the public result for every outcome

### Follow-up

Freeze a5 for separately authorized protected validation only if the complete
reviewed comparison passes every registered rule.
