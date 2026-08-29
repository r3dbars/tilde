# Q07 — Prompt-cache instrumentation pilot

Status: INCONCLUSIVE — budget expired; no superiority or promotion decision
Experiment class: generator (request-level cache flag; all generation otherwise fixed)
Owner: r3dbars
Pre-registered: 2026-08-28

## Pre-registration

Question: can a 15-active-minute local battery pilot complete matched synthetic
Qwen requests with cache_prompt off versus on, explicit balanced order, fresh
inference, complete scoring, and attributable helper-memory observations?

This is instrumentation discovery, not the approved longer latency study.
The owner authorized this pilot only; the five-hour run remains on hold.

- Control/treatment: Qwen 3.5 9B Base Q4_K_M, confidence cutoff 0.475,
  production prompt and cleaner, Intent Futures, three visible words, 12
  generated tokens, temperature 0.1, five probability alternatives. Only
  request cache_prompt false/true differs. Helper prefix-cache support is on
  in both; chunk relocation cache-reuse is zero in both.
- Certified Corpus V2 development, all available roots (selection cap 1,000),
  mandatory sentinels included unchanged, seeds 17/41/73, one repetition,
  one worker and one slot. CLI validation freezes 3,600 evaluations total
  (1,800 per arm; not 3,600 actual inferences). Shared helper; 50-root blocks
  alternate AB/BA including sentinels.
  This is not a cold-reset cache comparison or a typing-sequence replay.
- Response candidate cache disabled with --no-cache. Count actual inference
  separately from policy-suppressed evaluations and repeated templates.
- Primary pilot metric: completion and measurement coverage, not speed.
  Supporting diagnostics: p50/p95/p99 full-response and first-token latency,
  useful/bad/quiet counts and existing hard gates, helper RSS sampled about
  once per second, and numeric native helper metrics when available.
- Attribute RSS to an arm only when its durable running-work identity agrees
  before and after sampling. Mixed transition samples are excluded. RSS is
  not total GPU/unified memory, and a sampled peak can miss short spikes.
  Native counters are diagnostics, not proof of cache hits unless their
  meaning and coverage are actually established.
- Functional success requires all planned work, two complete v6 reports,
  at least 100 fresh requests per arm, no runtime/sentinel failure, correct
  alternating block order, at least 30 attributable RSS samples per arm,
  and no surviving pilot helper. Failure to meet these is reported honestly.
- Budget: 0.25 active hours, at most 6,000 planned evaluations/requests,
  two trials, at most 1,000 roots per trial. No padding after completion.
  If the time cap wins, record aborted/incomplete, never fabricate reports or
  extend/restart the campaign. External watchdog permits cleanup only.
- Kill/pause: existing thermal, low-power, safety and sentinel gates remain
  intact; battery override is authorized for this pilot only. Stop if battery
  falls below 25 percent or owned helper RSS exceeds 16 GiB.
- Limitations: battery, concurrent daily preview, shared cache state, and
  synthetic repeated roots prohibit a shipping or causal speed verdict.
  Existing absolute bad-suggestion failures remain failures even if counts
  match. No comparison, nomination, validation, holdout, or production edits.

## Frozen assets

- Base source: c9493560d55c1d9dd064f87ff4a1cd336605d34c.
- Runner changes: correct two-arm block order; regression-test explicit
  request flag. Final clean source/runner/campaign/monitor hashes recorded
  locally before launch and published with the eventual aggregate result.
- Model revision: ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6.
- Model SHA-256: 4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2.
- Helper SHA-256: 66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5.
- Machine: Mac17,7, 128 GiB RAM; battery override, low-power off and nominal
  thermal state required at launch.

## Result

Status: INCONCLUSIVE — pilot readiness failed
Completed: 2026-08-28T12:09:04Z (approximately)

### Aggregate evidence

The fixed 15-active-minute budget expired. The supervisor exited after
900.792 seconds with the CLI's budget-expired / active-budget-exhausted
classification. No watchdog, battery-floor or RSS-ceiling stop was recorded.

- 3,299 of 3,600 planned evaluations completed (91.6 percent).
- The database had materialized 3,342 items: 3,299 completed and 43 pending;
  another 258 planned items were not materialized. The smaller status
  denominator is not the frozen full workload.
- 2,388 actual model requests; 911 policy suppressions; zero candidate-cache
  entries. No completed observation had an error/timeout outcome.
- Zero live campaign sessions, zero running/failed work items, zero complete
  v6 reports, and no surviving pilot helper. The daily preview remained live.
- All 12 recorded block orders alternate AB/BA. The mandatory sentinel block
  completed and subsequent blocks executed; no sentinel stop was recorded.
- Corrected observer: 355 attributed cache-off RSS samples and 364 cache-on,
  with six transition samples excluded. Sampled peaks were 5,947,440 KiB off
  and 5,947,456 KiB on, approximately 5.67 GiB of process RSS, not total
  GPU/unified memory.
- Within consecutive same-arm/block/helper sampling intervals, native
  cached-token counter deltas were zero off and 4,663 on (344/353 intervals).
  This is evidence of mechanism engagement in the observed intervals, not a
  complete cache-hit rate or a speed result.

The incomplete arm counts below are descriptive only and are **not paired
quality comparisons**, since coverage differs:

| Arm | Completed evaluations | Actual requests | Useful | Wrong or unwanted |
| --- | ---: | ---: | ---: | ---: |
| Cache off | 1,596 | 1,167 | 473 | 277 |
| Cache on | 1,703 | 1,221 | 473 | 321 |

### Failures and limitations

The workload estimate was too ambitious for the fixed pilot duration.
The initial supervisor's UUID-case mismatch left its samples unattributed;
only the separately attached corrected observer supplies arm-labeled samples,
beginning about 69 seconds after launch. The original data are not rewritten.
Battery-to-AC transition, nominal-to-fair thermal state, the separate daily
preview, and a concurrent study build/proof beginning around 12:02:45Z further
prevent a comparative speed or energy conclusion. No estimate is made of how
much the concurrent build contributed to expiry. Repeating synthetic roots
does not establish live usefulness or independent-template replication.

No complete reports exist, so full report quality gates and paired effect
uncertainty are unavailable. Partial useful/bad counts cannot establish
quality approval. Do not confuse the absence of recorded inference errors
with successful pilot completion.

### Frozen execution provenance

- Source: 5034de21c25185a5be9803784b5e7427ad4f9d6f, clean at execution.
- Runner SHA-256: 6ee93ea729eb151a7591eaef90b26b2a9239cb12600c4354be444e1cea76f77f.
- Campaign SHA-256: d77e77f6056f92767f0de826bdcd0fd9b7aadff696012569632e567092471ba0.
- Manifest SHA-256: af8a82f0d97781e12cd57e0e7da26e833f64e76e613b93639a45cfd4808ceb84.
- Suite SHA-256: 126505c04c21386333236c1844d9a6cf5a139b722c0959e3eb1af55629f3c8b2.
- Cache-off arm SHA-256: 44692a9ecf108e214185b7ffa91e504d28a8368ee51f3a9aeadc2803bca26053.
- Cache-on arm SHA-256: 45334a3117e2dc1730069c9656fe7fa8516df7a32fa5334f7a0901ab7c4ad592.
- Model and helper hashes are unchanged from pre-registration.

### Decision

The CLI terminal-failure review is INCONCLUSIVE. Q07 did not meet its
pre-registered completion gate. Q08 was **not launched**. No resume, replacement,
comparison, promotion, nomination, validation, holdout or production change was
performed. Automatic launch is paused pending an explicit revised pilot
decision. A smaller fixed AC pilot with no simultaneous build is the proposed
next step, not an authorized or launched run.

### Durable changes

- Aggregate record and lab log updated; original frozen runner/source retained.
- The prepared Q08 supervisor has a real SQLite mixed-case UUID regression
  self-test. Its build and fast proof passed (778 tests / 101 suites).
- No Learning Ledger stage or quality decision changed. These are instrument
  findings, not a demonstrated product benefit.
