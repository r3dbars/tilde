# Q08 — Local prompt-cache reuse study

Status: PRE-REGISTERED; Q07B functional readiness passed
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

Q07B completed its fixed readiness gate in 302.643 seconds. Q07 remains
aborted/inconclusive. Q08 is now pre-registered for the approved durable launch;
no Q08 result is known at this registration. Build/proof success and functional
readiness never substitute for the study's quality and timing gates.
The full-run result must contain aggregate metrics, uncertainty, absolute
failures, confounders and an honest supported/rejected/inconclusive review.
Publish a results PR with the public record and lab log; do not merge it.
Add a Learning Ledger entry only for reusable knowledge. No protected-stage
advance, live preview change, production change, or new campaign is implied.
