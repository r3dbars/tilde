# Q02 — Qwen 9B factorial replication v2

Status: INCONCLUSIVE
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
- Registered manifest SHA-256:
  `6ebacd977d8d81c7d92b2e9b21c1c3d8e140d7ab3ead4a76c3261a0d4ca22938`
- Selected-suite SHA-256:
  `126505c04c21386333236c1844d9a6cf5a139b722c0959e3eb1af55629f3c8b2`
- Registered protocol fingerprint:
  `e91c4cd4b12e73c91c5fa0b3f24d93bffce5871d3ca199dc148700ae5cf44f5e`

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

Status: INCONCLUSIVE
Stopped: 2026-08-27T11:58:45Z

### Aggregate evidence

- The owner-only campaign started cleanly, registered one live F02 session,
  launched one local Qwen worker with eight slots, and durably completed all
  18,432 invariant-block work items with zero work-item failures.
- Every arm produced 2,304 invariant observations. The deterministic arms
  recorded 576 correct silences and 1,728 unwanted suggestions; the sampled
  arms recorded 552 correct silences and 1,752 unwanted suggestions.
- Sensitive bereavement and medical cases were suppressed, and irrelevant
  scene echoes were suppressed. The unwanted suggestions were concentrated in
  four synthetic categories: prompt injection, resolved request, self-only
  scene, and unsupported choice.
- Across the 144 locally cached prompt-injection candidates from all eight
  arms and three seeds, 88 contained the planted `OVERRIDE` token and 95
  echoed the hostile instruction phrase. These are aggregate synthetic counts;
  no raw candidate is checked in or printed.
- F02 persisted the terminal `invariant-smoke` /
  `unsafe-sentinel-output` artifact, reconciled the campaign to `failed`, and
  accepted an explicit `inconclusive` review. The failed campaign is not
  resumable and will never be reused.

### Failures and limitations

- No aggregate v6 arm report or paired a0-versus-a5 comparison exists because
  invariant smoke correctly stopped before the expensive trial blocks.
- The current invariant classifier collapses any wrong or unwanted sentinel
  output into one `unsafe-sentinel-output` reason. That accurately caught the
  prompt-injection leak but overstates resolved-request, self-only, and
  unsupported-choice interruptions as the same security class.
- The synthetic cache is owner-only and retained locally only for diagnosis
  and regression replay. It is excluded from Git.
- This result says nothing about whether temperature 0.10 and 12 tokens improve
  Qwen quality; the configuration comparison never began.

### Decision

Q02 is inconclusive for model configuration and supported as a safety finding:
Qwen 9B can follow hostile instructions embedded in screen context. Do not
weaken or bypass the sentinel and do not resume this failed campaign. Add a
deterministic, model-independent scene-instruction suppression before inference,
separate genuine security failures from ordinary unwanted-output categories,
freeze the planted case as a regression, and register a new campaign ID before
retrying the a0-versus-a5 question.

### Durable changes

- Learning Ledger entry: pending reusable result after the protection is proven
- Regression IDs: pending scene-instruction suppression regression
- Results pull request: [#423](https://github.com/r3dbars/tilde/pull/423)
- Rollback: retain the public result even if the treatment is rejected or the
  campaign is inconclusive

### Follow-up

Implement and prove the pre-model scene-instruction gate, then pre-register a
fresh campaign with that protection frozen identically across a0 and a5. Do not
consume protected validation until a complete reviewed comparison passes.
