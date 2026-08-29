# Q04 — Qwen 9B factorial replication v4

Status: REJECTED
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

Status: REJECTED — completed successfully; no configuration qualifies to advance.

### Aggregate evidence

The local campaign ran from 2026-08-27T12:25:44Z through
2026-08-27T18:49:10Z (6.39 active hours). Reconciled state records
345,600/345,600 completed work items, zero failed items, zero live sessions,
and eight complete v6 reports. All eight received the same explicit rejected
review before comparison. The runner exited successfully and both launch jobs
were removed. No validation or holdout was consumed.

There are **600 independent roots**, not 345,600 independent generations.
Each arm has 43,200 observations: 600 roots × three seeds × 24 repetitions.
The synthetic raw cache contains 10,176 entries; cached responses are reused
across repetitions. The pre-registration's “requests” count is therefore a
work-item budget, not a count of fresh model calls.

| Arm | Temperature | Token cap | Useful | Wrong | Unwanted | Net keystrokes | Net savings rate | Total p95 (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| a0 — control | 0 | 20 | 11,328 | 6,528 | 5,472 | 67,776 | 10.374% | 2,836 |
| a1 | 0 | 12 | 11,328 | 6,528 | 5,472 | 67,776 | 10.374% | 2,582 |
| a2 | 0.05 | 20 | 11,424 | 6,384 | 5,472 | 67,824 | 10.381% | 2,896 |
| a3 | 0.05 | 12 | 11,472 | 6,312 | 5,472 | 67,680 | 10.359% | 2,613 |
| a4 | 0.10 | 20 | 11,353 | 6,407 | 5,472 | 67,369 | 10.312% | 2,878 |
| a5 — God v1 | 0.10 | 12 | 11,400 | 6,360 | 5,472 | 67,272 | 10.297% | 2,483 |
| a6 | 0.15 | 20 | 11,400 | 6,480 | 5,472 | 67,440 | 10.323% | 2,797 |
| a7 | 0.15 | 12 | 11,424 | 6,480 | 5,472 | 67,440 | 10.323% | 2,565 |

Only **a5 versus a0** bears on the registered decision. The canonical
10,000-iteration paired root-cluster bootstrap gives:

- Expected utility: 2,843.55 → 2,706.19 milliseconds per 1,000 characters;
  delta **−137.35**, 95% interval **[−806.14, +551.54]**, bootstrap probability
  of a positive effect **0.3477** (required: at least 0.95).
- Bad when shown: 51.440% → 50.930%; delta −0.511 percentage points,
  95% interval [−1.146, +0.086] points. The interval does not establish
  non-increasing harm.
- Net savings rate: delta −0.077 percentage points,
  95% interval [−0.349, +0.170] points; 504 fewer net keystrokes.
- Paired first-token-or-fallback p95: delta +5 ms, 95% interval [−37, +60] ms.
  Its upper bound exceeds the registered +25 ms noninferiority margin.
  This is a different endpoint from the descriptive **total** p95 above,
  which fell by 353 ms; the total-latency improvement cannot substitute for
  the paired gate.
- Root utility outcomes: 59 wins, 472 ties, 69 losses. Seed utility deltas
  were +65.00 (17), −243.47 (41), and −233.59 (73).
- Worst slice: `stress.sensitive-near-miss`, 12 independent roots,
  utility delta −5,222.17 milliseconds per 1,000 characters.

The frozen CLI's `compare` command emits every non-control arm against a0;
it has no single-arm selector. Those additional artifacts remain exploratory
and cannot nominate an alternative candidate.

All eight reports fail `bad-suggestion-gate` and `latency-gate`. Privacy,
sensitive-situation, and temporal-integrity report gates pass; interaction
integrity is **not run**, not a demonstrated pass. Execution errors and
timeouts are zero. Review/provenance completeness does not imply gate success.

### Result provenance

The frozen source, model, helper, runner, and campaign hashes above remain
unchanged. Additional identities recorded by the reports:

- Hypothesis ID: `QWEN-GEN-04`
- Manifest SHA-256:
  `6ca1e1792d17fd9a9bda12f56cb8f769f3442396f87b962e85f008d6af9b358f`
- Suite SHA-256:
  `126505c04c21386333236c1844d9a6cf5a139b722c0959e3eb1af55629f3c8b2`
- Canonical invocation SHA-256:
  `3b53e140075c147ef459d2cf16e99e3857947779b4ffb955ac53dae5b13d5f75`
- Baseline report: `4FA868FF-1E0C-4613-BC2D-67DBA42C2040`
- Treatment report: `2019E8AC-4763-4DEB-BA49-6F78AE71F07C`
- Hardware class: `Mac17,7`; macOS 26.6.2, build `25G83`;
  AC power, low-power mode off, nominal thermal state at provenance capture.

### Failures and limitations

The experiment completed; the hypothesis failed its promotion rule. This is
not proof that every possible Qwen configuration is inferior, or that the
negative primary estimate differs statistically from zero. It is sufficient
to reject advancing this candidate under the registered rules.

Shorter generation lowered descriptive total p95 in each temperature pair,
but did not solve unwanted interruptions or establish a utility gain.
Temperature tuning changed relatively few outcomes. No exploratory arm may
replace a5 post hoc.

Synthetic deterministic scoring is not independent human semantic judgment
or retained live usefulness. Repetitions and cached outputs do not create new
coverage or independent generation draws. The root-cluster intervals preserve
the 600-root sampling unit; per-observation rare-event bounds must not be read
as independent safety trials. Latency reflects this one Mac's eight-slot,
cache-enabled campaign, not single-request live IMKit performance. No live
interaction or retention conclusion follows. The frozen arm records
`factualGrounding: off`; this run does not establish a separate factual-grounding
guarantee. Report gates and the narrower invariant smoke must not be conflated.

### Decision

**Reject God v1 advancement.** The primary probability threshold, harm
noninferiority, protected-slice rule, paired latency bound, and report hard
gates do not pass. Do not nominate a candidate, consume validation or holdout,
change production Gemma, or start another sweep from this result. Preserve the
earlier preview finding as historical evidence, not a current promotion claim.

### Durable changes

- Learning Ledger entry: `qwen-factorial-v4-rejected`; close the bounded Qwen
  replication route without unlocking any research stage
- Regression IDs: covered by PRs #425 and #427
- Results pull request: [#428](https://github.com/r3dbars/tilde/pull/428)
- Rollback: retain the public result for every outcome
- Verification: five focused Learning Ledger tests pass;
  `./script/proof.sh fast` passes all blocking lanes, including 748 tests
  across 94 suites. This verifies the checked-in record and repository, not
  the model's quality or a production release.

### Follow-up

Return to the existing Stage 0 evidence-foundation queue (retained outcomes
and permanent sanitized regressions). Any later Qwen investigation needs a
new, separately authorized causal question and pre-registration; this result
does not authorize one.
