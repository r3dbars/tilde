# Q02 — Qwen 9B factorial replication v2

Status: PROPOSED
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-27T11:49:13Z

## Pre-registration

### Hypothesis

Qwen 9B at temperature 0.10 with a 12-token generation budget
(`qwen-factorial-a5`, God v1) will outperform the identical greedy 20-token
baseline (`qwen-factorial-a0`) on paired Certified Corpus V2 development cases
without weakening hard gates, bad-when-shown rate, protected slices, net
keystroke savings, or latency.

### Why this should work

The earlier 50-arm search associated God v1 with slightly more useful and
fewer wrong suggestions. Q01 could not test whether that signal replicated:
its baseline failed invariant smoke before any aggregate v6 report existed.
F01 and F02 now make provenance and terminal campaign state decision-grade.

### Arms

The fixed generator factorial crosses temperatures 0, 0.05, 0.10, and 0.15
with generation budgets of 20 and 12 tokens. Prompt, context, cleaner, safety,
scoring, interaction, runtime, three-word display cap, and model bytes remain
identical. Arm a0 is the control and a5 is the only pre-registered treatment;
the other six arms are exploratory and cannot substitute for a5.

### Data, pairing, and runtime

- Certified Corpus V2 development partition;
- fixed generation seeds 17, 41, and 73;
- 24 repetitions per seed;
- interleaved root blocks of 20 after invariant smoke;
- one worker with eight slots;
- 345,600 planned paired model requests;
- 350,000-request ceiling and eight active-hour ceiling; and
- AC power, Low Power Mode off, and a separate sleep-prevention job.

### Primary metric

Paired expected utility under `net-keystrokes-v1`, comparing a5 against a0.

### Supporting metrics

Net keystroke savings, useful and wrong suggestions, bad-when-shown rate,
protected-slice deltas, first-stable-word latency, total latency, per-seed
effects, and the worst seed.

### Hard gates

Every arm must pass prompt-leak, sensitive-scene, stale-context,
echo-or-replay, unsupported-fact, temporal-integrity, privacy, interaction, and
latency gates. Invariant smoke is terminal. No failed gate may be averaged into
the primary metric or repaired after output is observed.

### Promotion rule

Advance only a5, and only if the complete reviewed v6 comparison shows a
positive paired primary effect with at least 0.95 bootstrap probability, no
bad-when-shown increase, no protected-slice regression, every hard gate
passing, and no more than 25 milliseconds of latency regression. This campaign
does not consume protected validation or change production.

### Kill rule

Stop on invariant or hard-gate failure, provenance or protocol drift, helper
failure, exhausted request or active-time budget, or an incomplete exactly
paired comparison. Start the fresh campaign without `--resume`; use `--resume`
only if F02 later reconciles this exact campaign as `aborted`.

### Frozen public provenance

- Source commit: `559586ebdfc6a3075edae072c6de271f8e3449df`
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256:
  `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256:
  `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`
- Runner SHA-256:
  `b56b04628ee79fe178a3fe900b56c04884300b4f306ae1cf88a363fe861c2c5d`
- Campaign document SHA-256:
  `db9c686cc9a8ce98348b5c2e93a40ae22f8bdf18e039e6c416a359cc3088a0ff`
- Campaign ID: `69DC285E-586D-4DDF-B05F-0851EB8C8571`

### Known limitations

- Synthetic development cases cannot establish retained live usefulness.
- One local Mac cannot remove all thermal and scheduling variation.
- The existing idle Model Preview helper remains a background memory resident;
  its activity is monitored and any material interference makes the result
  inconclusive.
- The six exploratory arms may generate hypotheses but cannot win this
  pre-registered comparison.
- Invariant smoke may correctly end the experiment before the planned long run.

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
- Regression IDs: pending
- Results pull request: pending
- Rollback: retain the public result even if the treatment is rejected or the
  campaign is inconclusive

### Follow-up

If and only if a5 passes the pre-registered rule, freeze it for a separately
authorized protected validation run. Otherwise close the bounded Qwen question.
