# Q05 — Qwen confidence capture and small filtering pilot

Status: PROPOSED
Experiment class: display-policy (exploratory synthetic replay)
Owner: Tilde research program

## Pre-registration

Question: can mean selected-token confidence remove at least 20% of bad
suggestions while retaining at least 95% of useful ones?

Q04 cached no numeric token probabilities despite requesting them. A separate
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

Pending the corrected client's bounded pilot. No threshold has been selected.

## Follow-up boundary

The longer 1,000-fresh-root plan is conditional on a useful pilot and separate
owner authorization. No nomination, validation, holdout, live intervention,
production change, or research-stage unlock follows from this diagnostic.
