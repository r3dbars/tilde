# Q01 — Qwen God v1 replication

Status: INCONCLUSIVE
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-27T02:18:55Z

## Pre-registration

### Hypothesis

Qwen 9B God v1 at temperature 0.10 and 12 generated tokens will outperform
the identical greedy 20-token baseline across paired Certified Corpus V2
development roots and fixed seeds without weakening hard gates, net keystroke
savings, or latency.

### Why this should work

The earlier development search associated God v1 with slightly more useful
suggestions, fewer wrong interruptions, and lower same-run p95 latency. That
result predated report provenance v6. A clean, durable replication was intended
to test whether the configuration signal survived a larger exactly paired run
before any protected validation.

### Control

`qwen-factorial-a0`: Qwen 3.5 9B Q4_K_M, production prompt, cleaner, scoring,
interaction, context, and safety controls; greedy decoding; 20 generated
tokens; three visible words.

### Treatment

The pre-registered God v1 arm was `qwen-factorial-a5`. It changed only
temperature to 0.10 and the generation budget to 12 tokens. Six additional
fixed factorial arms crossed temperatures 0, 0.05, 0.10, and 0.15 with 12- and
20-token budgets; they were exploratory and could not substitute for the
pre-registered a5 comparison.

### Data and split

- Certified Corpus V2 development partition, with research-selected invariant
  roots followed by stratified root blocks;
- fixed generation seeds 17, 41, and 73;
- 24 repetitions per seed;
- root block size 20 after the invariant-smoke block;
- one worker with eight slots; and
- 345,600 planned model requests, capped at 350,000 requests and 11 active
  hours.

### Primary metric

Paired expected utility under `net-keystrokes-v1`.

### Supporting metrics

Net keystroke savings, useful and wrong suggestions, bad-when-shown rate,
protected-slice deltas, first-stable-word latency, and total latency.

### Hard gates

Every arm had to pass the same prompt-leak, sensitive-scene, stale-context,
echo-or-replay, unsupported-fact, temporal-integrity, privacy, interaction, and
latency gates. A failed invariant sentinel stopped the campaign. No gate could
be averaged into the primary metric.

### Promotion rule

Arm a5 had to show a positive paired primary effect with at least 0.95
bootstrap probability, no bad-when-shown increase, no protected-slice
regression, and no more than 25 milliseconds of latency regression. Only then
could its exact bytes and configuration be frozen for one protected validation
run.

### Kill rule

Stop on any hard-gate failure, protocol drift, exhausted budget, or lack of a
complete exactly paired decision-grade comparison. Do not repair or relax a
control after seeing output.

### Known confounders

- Synthetic development cases cannot establish retained live usefulness.
- One local machine cannot eliminate all thermal and scheduling variation.
- The factorial arms test generation settings, not a different model or
  display policy.
- The invariant block can terminate before any aggregate arm report exists.

### Frozen provenance

- Campaign ID: `4AD78566-BA4F-45F1-91EF-D67EF19DBAD1`
- Git commit: `d42a838ddebbda240cada79a101d518b31f4c2ae`
- Dirty state: clean, from an independent clone at the frozen commit
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256:
  `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256:
  `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`
- Runner SHA-256:
  `a68bb667462bbf4d90a92d1fd830f8625c3ea4e5f8e306922933421a70e42df9`
- Registered manifest SHA-256:
  `b5937173c38fb92e8b997a9d7319da042f8de90f643117ce3b0fe2703a108c99`
- Selected-suite SHA-256:
  `126505c04c21386333236c1844d9a6cf5a139b722c0959e3eb1af55629f3c8b2`
- Registered protocol fingerprint:
  `9ab8eacdc81de4e810f2294429a9edbaabf5675a87d91d07716f892ed4c4d32f`
- Arm SHA-256 values: a0 `4614288036cbc783509ffaf0447e3e3ea7abd11fd10cfedd2e87faa4c52b804c`;
  a1 `22a8fcbc484bec6d2a5b6a6c07409e8c8cf9f7bb16ba07ad5aba6106b9792d6f`;
  a2 `a140018a927d2547710cebeed8a215dc29a69aa698778cb6877faf513b011ef0`;
  a3 `ba846582b8ef581fca16bfa9f68eb8a8861d51e273ebbf35eca2e03ab9e17cb9`;
  a4 `7e03909f7f45ef9a807de472f9ec198205d6180992d1ddd431ac22b5c97a9bba`;
  a5 `f6616fcfc9c277a196b5132ec1c8205eb91d4cbb6f473a40f8c34702b3206993`;
  a6 `dad36bca64b8be46422a4c9e91e203eb27ed352d1cf727988e87bcb8f771ba29`;
  a7 `f9d7e6a7b4625f87609bad8c3bcf483416f12dc6de7f9b345c76f1e7fd78f7fb`
- Scoring SHA-256 and canonical invocation digest: unavailable because the
  invariant failure occurred before any v6 report was emitted
- Environment: macOS 26.6.2 build 25G83, arm64 Mac17,7; AC power, Low Power
  Mode off, and nominal thermal state at invariant-block start

## Result

Status: INCONCLUSIVE
Stopped: 2026-08-27T02:33:19Z

### Aggregate evidence

- The invariant block completed 18,432 durable work items: 2,304 per arm,
  consisting of 32 invariant roots, three fixed seeds, and 24 repetitions.
  There were 672 synthetic-only candidate-cache entries and no recorded work
  item failures.
- The baseline a0 then failed invariant smoke with the privacy-safe category
  `unsafe-sentinel-output`. The hard gate terminated the run before the runner
  created any of the eight aggregate v6 arm reports.
- Durable status consequently contained zero decision-grade reports and no
  paired comparison. The review command refused to attach an `INCONCLUSIVE`
  conclusion because reports were absent, and comparison refused to run
  because complete exactly paired reports were absent. Both downstream gates
  failed closed.
- The registered immutable source, suite, model, helper, and protocol values
  remained unchanged. Automatic restart attempts were nevertheless rejected
  as campaign-fingerprint changes. The registered manifest digest is computed
  by directly encoding models that contain `Set` values; cross-process Set
  ordering can therefore change the digest without changing the semantic
  protocol. This is the most direct explanation consistent with the frozen
  inputs and repeated restart behavior.

### Failures and limitations

- There is no aggregate quality, utility, or latency result for any arm. The
  18,432 completed items are durable execution evidence, not a report and not a
  comparison.
- The safety failure identifies the baseline arm and a bounded failure class,
  but aggregate-only evidence intentionally does not retain the model output or
  private case content. It cannot support a post-hoc scoring reinterpretation.
- Campaign state remained `running`, every trial remained `pending`, and status
  showed 18,432 of 18,432 work items complete with zero failures after the
  process had terminated. A keep-alive job then attempted 169 restarts before
  monitoring removed it.
- Resuming by editing the durable fingerprint, deleting completed state, or
  weakening the sentinel would have changed or bypassed the registered
  protocol. None was done.
- Because no v6 report exists, the report-level review requested by the
  workflow is unrepresentable. This public record is the accountable
  experiment-level conclusion, not a substitute decision-grade report.

### Decision

The replication is inconclusive. Do not claim that God v1 reproduced, do not
advance a5 to protected validation, and do not alter production. Keep the hard
gate failure. Complete F02 campaign-state reconciliation—including stable
cross-process digests, persistent terminal failures, truthful trial/campaign
status, and reviewable failure artifacts—before registering a fresh
replication.

### Durable changes

- Learning Ledger entry: `qwen-god-v1-replication-inconclusive`
- Regression IDs: none yet; the failure category remains local until F02 can
  freeze a sanitized reproducer without raw output
- Results pull request: added by the pull request containing this record
- Rollback: revert this documentation and ledger update; no production or
  candidate configuration changed

### Follow-up

Finish F02, then pre-register a new clean campaign that runs the same a0 versus
a5 causal question. Invariant smoke should become a small separately terminal
stage whose aggregate failure can be reviewed without pretending the full
comparison completed.
