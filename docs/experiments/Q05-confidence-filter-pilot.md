# Q05 — Qwen confidence capture and small filtering pilot

Status: REJECTED (registered selected policy; confidence capture passed)
Experiment class: display-policy (exploratory synthetic replay)
Owner: Tilde research program

## Pre-registration

Question: can mean selected-token confidence remove at least 20% of bad
suggestions while retaining at least 95% of useful ones?

[Q04](https://github.com/r3dbars/tilde/pull/428) cached no numeric token
probabilities despite requesting them. A separate
20-request synthetic wire probe found modern `logprob` and `top_logprobs`
evidence in all 20 responses, while the legacy parser could read none. Five
responses contained nonempty content and 15 were empty; all had probability
rows, 27 rows total. Empty responses are not excluded from accounting. The
isolated helper exited cleanly. This motivates correcting evidence parsing,
not changing model sampling or weakening a safety gate.

The corrected Lab client reads selected-token pre-sampling log probabilities,
converts them to probabilities for the existing mean-confidence feature, and
preserves the original logs. It must not substitute the top alternative's
probability for the emitted token. Unit fixtures cover modern, post-sampling,
legacy, missing/invalid, and cache-round-trip evidence. Production is unchanged.

### Small test

- Fixed Qwen 9B a5: temperature 0.10, 12 tokens, three visible words, original
  Q04 prompt, cleaner, safety, scoring, model and helper bytes.
- 100 development roots selected by the existing deterministic evenly-spaced
  selector from Certified Corpus V2. These overlap Q04; this is a pilot, not
  fresh-data confirmation or independent replication. Seeds 17/41/73, one
  observation each, one worker/one slot, 30-minute maximum. The CLI adds its
  mandatory invariant sentinels: allow up to 32 extra roots and 400 total work
  items without removing any safety coverage. Preflight rejected the initial
  300-item budget before execution; this explicit allowance is frozen before
  launch, not a change made after observing outcomes.
- Freeze the exact new campaign and corrected clean source/runner hashes
  locally before execution. Do not resume or mutate Q04.
- Require usable confidence on every generated nonempty completion, complete
  cache replay, and exact threshold-zero agreement with the original new report.
- Sweep the frozen 0 to 1 grid by 0.025 using `risk-coverage`; no new inference
  during replay. Its 1% trust-limit output is descriptive, not the pilot target.
- Select maximum bad removal subject to >=95% useful retention and
  non-increasing bad-when-shown; ties choose the lower threshold. Call the pilot
  promising only at >=20% bad removal and no protected slice losing >10% useful
  observations where its control useful count is nonzero. All-silent is not a win.
- Report missingness, all empty completions, remaining absolute bad rate,
  root counts, and tradeoffs. Repetitions/seeds are not new independent roots.
- Stop on failed capture, pairing, invariant smoke, or privacy evidence. Do not
  bypass safety sentinels to obtain a result. Runtime timing is diagnostic only.

## Result

Completed: 2026-08-27T23:37:09Z

The local campaign completed 381/381 evaluations on 127 independent roots:
100 development roots and 27 mandatory safety roots, each with seeds 17/41/73.
It made 213 generation requests; the other 168 evaluations were suppressed by
the unchanged policy before inference. All 213 generated completions were
nonempty and had usable mean confidence and token-log-probability vectors.
There were zero missing-confidence responses, errors, or timeouts. Complete
synthetic cache replay exactly reproduced the threshold-zero report counts.
The separate corrected-client capture check also passed all 20 requests and
20 exact cache round-trips before this campaign.

The pre-registered selection rule chose **0.50**, but that setting failed the
protected-slice guardrail. It is not replaced with another threshold after
observing that failure.

| Mean-confidence cutoff | Useful shown | Bad shown | Useful retained | Bad removed | Bad among shown |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 (control) | 85 | 81 | 100% | 0% | 48.80% |
| 0.475 (descriptive only) | 85 | 62 | 100% | 23.46% | 42.18% |
| 0.50 (registered selection) | 83 | 53 | 97.65% | 34.57% | 38.97% |
| 0.525 (descriptive only) | 76 | 43 | 89.41% | 46.91% | 36.13% |

At 0.50, the `reply.answer` slice retained 17 of 19 useful observations:
89.47% retention, or **10.53% loss**, exceeding the allowed 10%. All other
category slices with nonzero useful control counts retained every useful
observation. Zero-useful slices provide no useful-retention evidence. The
lower 0.475 point preserves every useful observation and meets the descriptive
overall target, but is not a pre-authorized fallback for a failed selected
point. This is evidence for a possible revised selection rule, not rejection
of confidence filtering as a mechanism or confirmation on fresh data.

The remaining absolute bad rate is still high. No grid point met the
descriptive 1% upper-Wilson-bound trust limit; all-silent points are not wins.
The unfiltered report failed its bad-suggestion gate. Privacy, sensitive-case,
and temporal gates passed; real-host interaction was not tested. A reviewed,
complete report does not imply that the selected policy passed its gates.

### Provenance and limitations

- Campaign ID: `7900840F-12E5-4DBA-BB42-DA45FAF8750C`.
- Hypothesis ID: `QWEN-CONFIDENCE-05`.
- Report ID: `8829FDF9-310F-4FF7-978D-90863C9ED0C1`.
- Source/pre-registration commit: `87f2498cd11d9ca1dad37c5ab6233d7445d97e8a`; tree clean at execution.
- Runner SHA-256: `d49c8ac3b6635147b14fdd37c6954616954be5c1f3607486c51f4600cc9cda73`.
- Campaign file SHA-256: `8e88e1a830809faa2ba62db099f1dc4b8614012182d68a99b41f194fb8034ad4`.
- Canonical manifest SHA-256: `34786620b3681468552a5377892bf356377cf15030fec049d94e9b8e686fe0af`.
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`.
- Model SHA-256: `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`.
- Helper SHA-256: `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`.
- Suite/selection SHA-256: `3d131b5ae4e5167f9831dd23b341c2275d2895938078724ee3f5d3a6457c4f77`.
- Invocation SHA-256: `f5c3a90f8cf45b510a019ed17f35edfc1a27de7e57ffcb85d19eeb6d3e15c23f`.
- Hardware class `Mac17,7`, OS build `25G83`; battery power explicitly authorized
  before resume, thermal nominal, low-power mode off. The earlier AC-gated
  session was cooperatively aborted with zero completed work. Only the power
  exception changed on resume; campaign bytes and safety controls did not.
- The new campaign work-order seed was frozen as `6073469428589937000` after
  integer rounding during preparation; this is not an exact Q04 runtime replay.
  Generation seeds remained 17/41/73.

This is an in-sample synthetic threshold-selection pilot using development
roots that overlap Q04, not independent confirmation or evidence of live
usefulness. The 381 observations are not 381 independent situations. Slice
counts are small; no confirmatory uncertainty claim is made. Mean token
probability is a ranking feature, not a calibrated probability of usefulness.
Battery use and the separate daily-use preview exclude speed, energy, and
time-based-utility conclusions. No private writing was used or published.

### Decision

Attach a REJECTED review for the registered selected policy and stop before
the longer run. Preserve the successful evidence-capture repair. Do not run a
formal comparison, nomination, validation, holdout, live intervention, or
production change. No research stage is unlocked. A revised selection rule
would require a new pre-registration and owner authorization; the lower
cutoff's descriptive result cannot retroactively turn this selection into a
pass.

Verification: four focused probability-parser tests passed; the pre-run fast
proof passed all blocking lanes with 752 tests in 95 suites. Post-run checks
confirmed completed durable state, no active campaign session or helper,
complete confidence coverage, and exact zero-threshold count reconciliation.

## Follow-up boundary

The longer 1,000-fresh-root plan is conditional on a useful pilot and separate
owner authorization. No nomination, validation, holdout, live intervention,
production change, or research-stage unlock follows from this diagnostic.
