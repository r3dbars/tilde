# Q03 — Qwen 9B factorial replication v3

Status: PROPOSED
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-27T12:15:00Z

## Pre-registration

### Hypothesis

With the identical deterministic pre-inference scene safety policy frozen
across every arm, Qwen 9B at temperature 0.10 with a 12-token generation
budget (`qwen-factorial-a5`, God v1) will outperform the greedy 20-token
baseline (`qwen-factorial-a0`) on paired Certified Corpus V2 development cases
without weakening hard gates, harm, protected slices, net keystroke savings,
or latency.

### Why this should work

An earlier search associated God v1 with slightly more useful and fewer wrong
suggestions. Q02 could not test that signal because invariant smoke correctly
caught Qwen following hostile instructions embedded in screen context. PR #425
now suppresses that unsafe scene class before inference, identically for all
arms. This fresh campaign tests configuration quality without weakening the
sentinel or reusing the failed campaign.

### Arms

The fixed generator factorial crosses temperatures 0, 0.05, 0.10, and 0.15
with generation budgets of 20 and 12 tokens. Prompt, context, cleaner, scene
safety, scoring, interaction, runtime, three-word display cap, and model bytes
remain identical. Arm a0 is the control and a5 is the only pre-registered
treatment; the other six arms are exploratory and cannot substitute for a5.

### Data, pairing, and runtime

- Certified Corpus V2 development partition;
- fixed generation seeds 17, 41, and 73;
- 24 repetitions per seed;
- interleaved root blocks of 20 after invariant smoke;
- one worker with eight local model slots;
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
paired comparison. Start this fresh campaign without `--resume`; use
`--resume` only if reconciled state later reports this exact campaign aborted.

### Frozen public provenance

- Source commit: `706dbbc28e6ce02ef3c74e744e7f268fbd0dfe74`
- Dirty state: clean detached source clone
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`
- Model SHA-256:
  `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`
- Helper SHA-256:
  `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`
- Runner SHA-256:
  `6d4c1d5a2a427392ac496ed938d6b5401578d8cd946c60ea98b73bc262987b69`
- Campaign document SHA-256:
  `aa897b01337e058e5d14abd007888db19ba7e02454ec4a5044f8132cab4b18cd`
- Campaign ID: `09CCA7F7-63B3-4346-81AC-719A38F275D7`

### Known limitations

- Synthetic development cases cannot establish retained live usefulness.
- One local Mac cannot remove all thermal and scheduling variation.
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
- Regression IDs: scene-instruction gate covered by PR #425
- Results pull request: pending
- Rollback: retain the public result even if the treatment is rejected or the
  campaign is inconclusive

### Follow-up

If and only if a5 passes the pre-registered rule, freeze it for a separately
authorized protected validation run. Otherwise close the bounded Qwen question.
