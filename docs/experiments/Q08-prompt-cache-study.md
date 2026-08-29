# Q08 — Local prompt-cache reuse study

Status: REJECTED — registered p95 target not met; no production change
Experiment class: generator (the isolated request-level cache flag)
Owner: r3dbars
Approved duration: five hours including two bounded 15-minute pilot attempts

## Pre-registration

### Hypothesis

Request-level prompt-cache reuse reduces Qwen's p95 completion latency by at
least 10 percent without a material quality or sampled helper-memory regression.
This is a bounded development study, never authorization to change production.

### Control and treatment

Use the exact Q07 model, helper, prompt, cleaner, confidence cutoff 0.475,
12-token generation, temperature 0.1, five token-probability alternatives,
and three-word display cap. Request cache_prompt=false is control; true is
treatment. Every other arm field must match after removing the arm ID.
Runtime is identical: one worker, one slot, 4,096-token context, shared
long-lived helper, prefix caching supported, chunk cache-reuse zero, warmup
on. Keep the model/helper digests from Q07 and verify them before launch.

Use real local inference with --no-cache; never replay candidate responses.
Only synthetic Certified V2 development data are allowed. No private history,
live writing, validation or holdout. Repeated roots are not independent data.

### Pilot readiness gate

Q07 remains aborted and cannot satisfy its gate. After the owner's renewed
instruction to continue, the separately pre-registered
[Q07B](Q07B-cache-ac-pilot.md) must reconcile completed with 1,200/1,200 evaluations, two complete v6
reports, at least 100 model requests and 30 correctly attributed RSS samples
per arm, alternating AB/BA order, no runtime/sentinel failure and no surviving
pilot helper. Quality failures remain visible, separate from this functional
gate. If the pilot is aborted, failed or incomplete, do not launch Q08 or
silently relax this requirement; report the blocker.

### Fixed workload rule

After the pilot completes, freeze repetitions as
max(1, floor(0.90 * 16,200 / (3 * pilot_elapsed_seconds))), where elapsed is
Q07B's complete one-seed supervisor duration including startup; multiplication
by three accounts for the full study's three seeds. Each repetition has
the same 3,600 evaluations: all selected development cases, seeds 17/41/73,
both arms. Freeze the resulting integer and exact total in the campaign and
this record before launch. No post-result resizing or padding.

Frozen workload: Q07B elapsed 302.643 seconds; the formula gives **16
repetitions**, **57,600 evaluations total** (28,800 per arm). This is not
57,600 guaranteed model requests; policy-suppressed items remain separately
counted. The helper/run configuration and corpus are not tuned to pilot
quality or latency differences.

Use 10-root blocks rather than Q07's 50-root blocks to bound paired-arm time
separation in a repeated multi-hour workload. Alternate AB/BA including the
unchanged mandatory invariant block. The cache's shared warm state is part
of this protocol, not a cold-start benchmark or an app typing-sequence replay.
The main run has a 4.5-hour active and supervisor wall ceiling, reserving the
two pilot ceilings inside the owner's five-hour total. Complete early
if all frozen work is done; if the cap wins, preserve incomplete evidence
instead of extending the campaign.

### Measurements and decision

- Primary study metric: relative p95 full-response latency reduction among
  paired model-requested cases. Also report p50/p99 and first-token latency.
  The CLI's expected-utility field is an auxiliary quality summary, not this
  latency study's decision metric. Do not run CLI comparison or promotion.
- Exact paired identity: root/scenario/checkpoint/context variant/seed/
  repetition. No unmatched rows or missing request latency may silently enter
  the primary denominator. Count evaluations and actual model requests
  separately, including errors, timeouts and policy suppressions.
- Estimate 95 percent intervals with 10,000 paired counterfactual-cluster
  bootstrap draws (root cluster sensitivity), deterministic analysis seed
  73017. Keep every seed/repetition for a sampled cluster together. Do not
  treat thousands of repeat generations as thousands of independent roots.
- Speed support requires at least 10 percent point improvement and a 95
  percent interval excluding no improvement. Otherwise reject a clearly
  smaller effect or report inconclusive when uncertainty straddles the target.
- Quality gates: no more than one percentage point loss of useful/safe
  opportunities, no more than one percentage point increase of bad/shown,
  using paired intervals; report zero-denominator slices as unavailable.
  All absolute privacy, safety, temporal and bad-suggestion report gates
  remain independent requirements. Never call evidence completeness quality.
- Sample owned-helper RSS and numeric native cache/prefill/generation counters
  about once per second with the corrected supervisor. Require at least 95
  percent of in-helper samples to be numeric and at least 30 attributed
  samples per arm per evaluable non-sentinel block; insufficient coverage
  makes memory evidence inconclusive. Keep transition samples unassigned.
- Memory guard: paired-block sampled peak RSS no more than 10 percent higher
  with cache on; after the first non-sentinel block, final-quartile median RSS
  no more than 10 percent above first-quartile median in either arm. This is
  process RSS, not total GPU/unified memory or proof of absence of leaks.
- Attribute native cumulative counter deltas only between consecutive samples
  with identical arm, block and helper identity and no missing/decreasing
  counters. Nonzero on-only cached-token counts support mechanism engagement;
  they do not by themselves prove user-visible speed improvement.
- Report all complete paired data. Sensitivity excludes whole paired blocks
  with observed other-helper CPU above 5 percent, non-nominal recorded block
  thermal state, or power instability. CPU is only a contention proxy; this
  shared daily-use Mac is not an exclusive hardware benchmark. Fewer than 100
  roots in the quiet sensitivity means no quiet-machine speed conclusion.

### Hard controls and stop rule

AC required; no --allow-battery. Existing thermal, low-power, sentinel and
safety gates remain intact. The supervisor stops on observed AC loss, more
than one owned helper, owned-helper RSS above 16 GiB, or wall-time expiry.
Any runtime failure is preserved, not hidden by automatic restarts. No resume
or replacement without an explicit new decision.

Launch once under launchd with RunAtLoad true, KeepAlive false, an absolute
working directory and an idle-sleep assertion. The CLI creates its own
SQLite campaign session and helper; do not attach to the daily preview.
The supervisor verifies frozen source, runner, monitor, campaign, model and
helper hashes and refuses existing execution artifacts.

Real caller: the owner-only launchd job invokes
`ruby script/lab_cache_study.rb CAMPAIGN_DIRECTORY SOURCE_DIRECTORY`.
Test the supervisor with `ruby script/lab_cache_study.rb --self-test`.
The experiment index and completion heartbeat are the durable readers.

### Provenance to freeze before launch

Record exact source/runner/monitor/campaign/model/helper/suite/selection/
scoring/arm/invocation digests, selected count, repetitions, hardware/OS and
power state. Do not write private paths or campaign JSON into Git.
The underlying Lab fix descends from
5034de21c25185a5be9803784b5e7427ad4f9d6f.

Frozen campaign ID: 4C22544A-0E77-4164-A690-E5BFFC61A121.
Campaign SHA-256: 8a8f9318d0e064661c4ec2ca1a36ed14e31842395f92268d7834f822bb50046a.
Runner SHA-256: 2364f28736ba9bee57bd63072dfa74455b31249bafc22bfff86cfa1e0f3b11be.
Supervisor SHA-256: bbbee465cbf01747fd8cacf7b6c7002a7b8c7d822b2cf244d98faa8562edbaa8.
The execution source is the clean commit completing this registration;
its exact SHA is frozen locally before launch and carried by v6 provenance.
Model/helper hashes remain those in Q07B. CLI validation passes with 57,600
planned evaluations, two arms and the 4.5-hour ceiling. Fast proof passed
all blocking lanes (778 tests / 101 suites) before the readiness pilot;
subsequent changes only record evidence and this frozen workload.

## Result

Status: **REJECTED** for the registered at-least-10% p95 improvement.
Completed: **2026-08-28T16:27:25Z**. The supervisor exited successfully after
14,309.540 seconds (3 hours, 58 minutes, 29.540 seconds), before the ceiling.
Both complete v6 reports received an explicit rejected review. Review makes
the evidence complete; it does not make failed quality gates pass.

### What happened, in plain language

Prompt reuse genuinely engaged and the typical response was 14 ms faster.
But the slow-end response improved by only 2 ms, nowhere near the registered
target. The settings produced identical scored quality outcomes, including
the same bad-suggestion labels. This run does **not** justify changing a default.

### Complete, matched evidence

All 57,600 evaluations completed: 28,800 exact paired identities, with 20,352
matched real-model-request pairs and 8,448 policy-suppressed pairs. That is
40,704 fresh generations, not 57,600 generations. There were zero missing
request/first-token latencies, unmatched identities, errors, timeouts, or
failed work items. Every durable observation reconciled exactly with its
report. The response cache remained disabled and empty.

There are **600 synthetic roots and 300 counterfactual clusters**, not 57,600
independent situations. Each arm covered every root at seeds 17/41/73 and
16 repetitions. All 58 recorded blocks followed alternating AB/BA order,
with one worker, one slot, and a shared helper. The launch job was unloaded
after completion; the campaign helper exited and the daily preview was left
alone. A first launch attempt failed in source-access preflight before any
campaign state or inference; switching to an independent clone preserved the
same source and binary bytes. No execution was resumed or replaced.

### Latency

Positive reductions favor cache-on. Percentiles use LabScorer's nearest-index
integer-millisecond convention. Intervals below are 10,000 paired
counterfactual-cluster bootstrap draws, seed 73017; all seeds/repetitions stay
inside their sampled cluster. Supporting metrics do not replace the primary.

| Metric | Cache off | Cache on | Reduction | 95% interval for reduction |
| --- | ---: | ---: | ---: | ---: |
| Full response p50 | 348 ms | 334 ms | 4.02% | 3.46% to 4.65% |
| **Full response p95 (primary)** | **429 ms** | **427 ms** | **0.47%** | **0.00% to 0.93%** |
| Full response p99 | 453 ms | 453 ms | 0.00% | -0.67% to 0.88% |
| First token p50 | 175 ms | 171 ms | 2.29% | 1.71% to 2.29% |
| First token p95 | 198 ms | 192 ms | 3.03% | 2.03% to 6.02% |
| First token p99 | 238 ms | 232 ms | 2.52% | 1.69% to 4.29% |

The 600-root sensitivity gives a primary interval of 0.00% to 0.93% as well
(unrounded upper bound 0.928074%). The primary point effect is far below 10%,
its interval includes no improvement, and its upper bound is below the
registered target. The registered speed hypothesis is rejected in this
workload, not rescued by the more favorable median.

### Quality and hard gates

The two arms have identical outcome, offered/hidden, expected-suggestion, and
decision-reason labels on **every** paired evaluation. This proves equality
of recorded labels here, not raw-output equivalence or live typing quality.

| Per-arm measure | Both settings |
| --- | ---: |
| Useful / safe opportunities | 7,568 / 17,280 = 43.80% |
| Bad / shown | 5,776 / 13,344 = 43.29% |
| Bad / all evaluations (CLI gate denominator) | 5,776 / 28,800 = 20.06% |
| Wrong / unwanted | 2,992 / 2,784 |
| Missed safe opportunities / correct silence | 6,720 / 8,736 |
| Net keystrokes saved (offline scoring) | 46,448 |

Both paired quality differences are 0.00 percentage points, with [0.00, 0.00]
intervals under both clustering choices. Thus relative quality noninferiority
passes on these fixed labels. **Absolute bad-suggestion quality fails in both
arms**: the CLI requires at most 1% bad per evaluation. Privacy, sensitive
situations, temporal integrity, and the absolute latency gate pass.
Interaction integrity is **not run**, not passed.

| Synthetic slice, per arm | Evaluations | Useful / safe opportunities | Bad / shown |
| --- | ---: | ---: | ---: |
| Replies | 11,520 | 5,264 / 11,520 | 2,368 / 7,632 |
| Stress cases | 5,760 | 2,304 / 5,760 | 624 / 2,928 |
| Ordinary silence | 8,640 | unavailable (no safe opportunities) | 2,784 / 2,784 |
| Sensitive silence | 2,880 | unavailable (no safe opportunities) | unavailable (nothing shown) |

The companion aggregate JSON retains all 40 category-level slices for both
arms. Worst displayed slices include delay acknowledgements, delivery
commitments, time corrections, and contradiction stress: every shown item
scored bad in those slices. Preference replies and long-context requests
produced no useful displays. Zero shown/safe denominators are explicitly
unavailable rather than interpreted as perfect precision or useful coverage.
These are deterministic synthetic judgments, not a blinded semantic review.

### Memory and mechanism

There were 11,532 samples, 11,529 with a live owned helper; all in-helper
samples had numeric RSS. Cache-off had 5,495 attributed samples and cache-on
5,126; 908 in-helper transition/unassigned samples remain unassigned.

Peak sampled helper RSS was 5,947,664 KiB (about 5.67 GiB). The largest paired
block peak increase was 0.8733%, below 10%. After excluding the first
non-sentinel block, first-to-final-quartile median RSS was effectively flat:
5,896,176 to 5,896,144 KiB off; 5,947,648 to 5,947,616 KiB on.
However, **one of 114 evaluable arm-blocks had only 28 samples**, below the
registered 30. Memory coverage therefore remains **INCONCLUSIVE**, despite
the reassuring observed values. RSS is not total GPU/unified memory, and this
does not prove absence of a leak.

Strict consecutive same-arm/block/helper native-counter deltas covered 5,064
off intervals and 4,666 on intervals, with zero missing/decreasing-counter
intervals among those candidates. Attributed cached-token deltas were **0 off
versus 453,463 on**. This supports real prefix-reuse engagement. Different
interval coverage means native prefill/decode totals are descriptive only,
not complete matched timing denominators. Transition counters were not
attributed across arms.

### Limitations and decision

- The machine remained on AC in all 1,334 power samples, but battery charge
  fell from 84% to 43%. AC status is not proof that the adapter supplied the
  entire load; this is not an energy-efficiency result.
- Of 58 block environment records, 56 were thermally fair and only two
  nominal. The pre-registered quiet sensitivity retained 42 roots and 432
  requested pairs, below its 100-root minimum. **No quiet-machine speed
  conclusion is available.** The separate helper's maximum sampled CPU proxy
  was 0.1%; CPU is not GPU isolation, and the daily preview remained present.
- Shared warm cache state and repeated synthetic cases are intentional here.
  This is neither cold-reset testing nor a real typing-sequence replay.
  Repetition tightens within-workload measurements without creating new roots
  or establishing generalization to other writing, models, or devices.
- Q07 remains aborted/inconclusive. Q07B passed functional readiness but was
  inconclusive for superiority and failed absolute quality; neither record
  is rewritten as a successful quality experiment.

Keep the result as a bounded negative finding: genuine cache engagement and
a modest median improvement did not deliver the desired tail-latency gain.
No CLI compare, promotion, nomination, validation, holdout, live-preview change,
or production change was performed. No further experiment is authorized.
Any future typing-sequence cache question needs a new owner-approved protocol.

### Provenance and reproducibility

The clean pre-registration commit was made at 2026-08-28T12:26:43Z, before
inference started at 12:28:56Z. Hardware class was Mac17,7, macOS 26.6.2
build 25G83. The model was Qwen3.5 9B Base Q4_K_M, revision
ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6. Additional exact digests:

| Item | SHA-256 / commit |
| --- | --- |
| Clean execution source | 9857295778f0dd49ed45ae0de921c09f826ca1bb |
| Model | 4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2 |
| Helper | 66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5 |
| Selected suite | 126505c04c21386333236c1844d9a6cf5a139b722c0959e3eb1af55629f3c8b2 |
| Selection: sorted distinct root IDs, UTF-8 newline-delimited, final newline | fac0c7adf8aebf07781f80c00d999f742bbfcecdb580f5d99231089877b5ddbd |
| Scoring: sorted-key compact JSON | 501281ce724f829e8fe3d6316fcb29bcee997b3a5a452560dcf9e6a07077a0c4 |
| Cache-off arm | 44692a9ecf108e214185b7ffa91e504d28a8368ee51f3a9aeadc2803bca26053 |
| Cache-on arm | 45334a3117e2dc1730069c9656fe7fa8516df7a0901ab7c4ad592 |
| Canonical manifest | facb0cc0088ebb6d5e6d29b02c021f86cb822829daaf69fc31b2da5739fb0b76 |
| Canonical invocation | cb31593460c0b591bc0c570283ce20a2a42679d41dd4ef6d29df323a21188577 |

Runner, supervisor, and campaign byte hashes are in the frozen registration
above and the [aggregate evidence](Q08-aggregate-results.json). Report IDs:
047783CA-99E1-48A3-BCC6-B88EC801CF4B (off) and
3910E3A4-4BA0-411D-9AE7-A7E22CABA2FF (on). The JSON includes reviewed-input
report hashes, aggregate metrics and slices; no case rows or local paths.

The publication caller is
`python3 script/lab_cache_analysis.py CAMPAIGN_DIRECTORY OUTPUT_JSON`.
It requires owner-only existing artifacts and NumPy (2.0.2 used here), refuses
overwrite, and never launches inference or changes campaign state. Its
`--self-test` checks quantiles, denominators, duplicate rejection, weighted
cluster multiplicities, paired bootstrap, native counter resets/missingness,
transition exclusion, and RSS coverage. SQLite/report equality and direct
percentile reconciliation also passed on all real observations. The analysis
normalizes only declared Swift Set fields; no ordered controls are discarded.

Analysis assessment: **share with caveats**, with no unresolved arithmetic or
pairing blocker; the memory and quiet-condition limitations remain visible.
The raw evidence remains owner-only. See the [lab log](../research/lab-log.md)
and Learning Ledger entry `qwen-prefix-cache-tail-target-rejected`.

Publication verification passed: analyzer and supervisor self-tests, three
arm-order/request-flag tests, five Learning Ledger tests, and every blocking
lane of `./script/proof.sh fast` (778 tests / 101 suites). The initial
publication proof caught the ledger's old expected entry counts; updating
those counts and asserting this rejected result fixed the fixture check.
The queue, stage gates and promotion path were verified unchanged. No release
package, live interaction proof, or production configuration change is implied.
