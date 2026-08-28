# Tilde Lab log

The public notebook of what we tried, what we learned, and what failed.
Newest first. Failures and inconclusive stops are required, not optional.

This is not the Learning Ledger. The ledger stores a *reusable lesson or
decision*. This log stores the *attempt*, including work that taught us
nothing durable enough for a ledger row.

After every research attempt, append a block using the template below.
If the attempt produced a decision-grade result, also complete the
experiment record. If it produced a reusable lesson, also add a ledger
entry. Never check in private writing, screens, prompts, candidates, or
paths.

How we work: [`lab-partnership.md`](lab-partnership.md).

## Template

```markdown
## YYYY-MM-DD — <short title>

- **Try:** one sentence. What we actually did.
- **Learn:** one sentence. What we now believe, or "nothing durable yet."
- **Fail:** one sentence. What broke, was rejected, or stayed incomplete.
  Write `none` only if the attempt fully succeeded.
- **Where:** experiment ID, ledger ID, digest, or PR.
- **Next:** the one following question. Not a list.
```

## 2026-08-28 — Prefix reuse engaged but missed the tail-latency target

- **Try:** Complete Q08's 57,600 matched synthetic evaluations with cache off
  versus on, 40,704 fresh generations, one worker/slot and no response cache.
- **Learn:** Median response improved 348 to 334 ms, but p95 only 429 to
  427 ms: 0.47%, with paired counterfactual-cluster 95% interval 0.00–0.93%.
  Real cache engagement does not imply a meaningful tail-latency improvement.
- **Fail:** Reject the registered 10% p95 target. Scored quality was identical
  and both arms failed absolute bad-suggestion quality (43.29% bad/shown).
  Memory looked stable but one arm-block missed coverage; only 42 roots
  qualified for quiet sensitivity. Neither limitation is waived.
- **Where:** [Q08](../experiments/Q08-prompt-cache-study.md), its aggregate
  evidence and analyzer; ledger `qwen-prefix-cache-tail-target-rejected`.
- **Next:** Preserve the negative result. Any typing-sequence follow-up needs
  a new approved protocol; no production, preview, or protected-stage change.

## 2026-08-28 — Prompt-cache pilot expired; full study initially blocked

Follow-up: the owner renewed execution. The separate
[Q07B AC pilot](../experiments/Q07B-cache-ac-pilot.md) completed all 1,200
evaluations and 848 fresh requests in 302.643 seconds, with valid memory
coverage, no runtime errors and complete reports. Both arms still failed
absolute quality; the review is inconclusive for superiority. Its functional
readiness gate permits the separately registered Q08 run, not production.

- **Try:** Run matched synthetic Qwen cache-off/on arms with fresh inference,
  balanced blocks and process-memory sampling under a 15-minute limit.
- **Learn:** Native cached-token counters engaged only for cache-on in observed
  intervals; a UUID-case attribution bug needs a real SQLite regression test.
- **Fail:** The budget expired at 3,299/3,600 evaluations and 2,388 actual model
  requests, producing no complete reports. Mixed power, concurrent preview
  and build load, and missing early sample labels prohibit a speed verdict.
- **Where:** [Q07](../experiments/Q07-prompt-cache-pilot.md); the later
  [Q08](../experiments/Q08-prompt-cache-study.md) result is recorded above.
- **Next at the time:** Ask the owner to approve a smaller fixed AC pilot
  without a simultaneous build. The approved Q07B follow-up above did that;
  this aborted Q07 campaign was never extended or resumed.

## 2026-08-27 — Confirm a bounded confidence-filter effect on more roots

- **Try:** Freeze cutoff 0.475 against the identical cached Qwen outputs on 505
  development roots, with 473 non-pilot roots primary, three seeds and 3,030
  scored evaluations; cluster uncertainty by counterfactual pair and root.
- **Learn:** Bad displays fell 413 to 299 while useful displays fell 389 to
  388; the pre-registered relative-effect and protected-slice rules passed.
- **Fail:** Both arms still failed absolute bad-suggestion quality; 43.52% of
  filtered displays scored bad. Existing templates do not prove live utility.
- **Where:** [Q06](../experiments/Q06-confidence-filter-followup.md); ledger
  `qwen-confidence-filter-bounded`.
- **Next:** Preserve the offline lesson and finish the existing retained-outcome
  instrument before considering any live policy change.

## 2026-08-27 — Repair confidence capture and reject the pilot selection

- **Try:** Probe the helper schema, fix selected-token log-probability parsing,
  verify cache round-trips, then run a 381-evaluation confidence pilot.
- **Learn:** Requested probabilities were previously not retained. After the
  repair, all 213 generated candidates had usable evidence; the selected 0.50
  cutoff removed 34.57% of bad displays while retaining 97.65% useful overall.
- **Fail:** The original cache could not support replay, and the pilot's selected
  policy lost 10.53% useful in the answer slice, above the fixed 10% limit.
- **Where:** [Q05](../experiments/Q05-confidence-filter-pilot.md);
  `Tests/TildeLabKitTests/LabTokenProbabilityTests.swift`.
- **Next:** Test the conservative point in a separately registered campaign;
  Q06 above records that authorized follow-up without rewriting Q05's failure.

## 2026-08-27 — Wire the live counter and a local word diary

- **Try:** Produce text-free v3 counts from the IME, keep accepted
  words in a second owner-only diary, and ingest keep versus rewrite
  with `tilde-lab ingest-events --instrument`.
- **Learn:** Lab can tell keep from rewrite from counts alone. The
  words the owner wants to reread cannot live on that event. Password
  managers must not emit a displayed-and-unsafe event, and a privacy
  wipe must not turn a real Tab into an ignored zero.
- **Fail:** F03 is still not supported. The IME is wired, but this
  Mac has not yet written events from ordinary typing.
- **Where:** branch `cursor/f03-live-ruler-and-local-diary`; ledger
  `score-counts-diary-words`.
- **Next:** Rebuild the daily-driver IME, type as usual, ingest the
  local count file, and only then decide if the promotion rule is met.

## 2026-08-27 — Hand the ruler to an on-device thread

- **Try:** Write down the cloud-vs-Mac split, the play-vs-decision
  rule, and a briefing so a new local thread can wire live ingest
  without rereading this chat.
- **Learn:** GitHub can hold the schema. Only a Mac can watch whether
  words stay. Config play is a hunch until one change wins on kept
  characters. First live bet after F03 is three words versus eight.
- **Fail:** F03 is still not supported. No live events exist.
- **Where:** [`next-on-device.md`](next-on-device.md); ledger
  `cloud-protocol-mac-live-split`.
- **Next:** In a new on-device thread, produce v3 counts from IMKit
  and ingest them locally.

## 2026-08-27 — Start F03 as the first deep-research object

- **Try:** Explain the ruler in plain language, then implement the v3
  text-free event, XOR horizons, typed-through, flicker floor, and
  coverage report with fixtures.
- **Learn:** Nothing durable about live writing yet. The schema can now
  tell keep from rewrite-after-Tab, and missing from zero, without
  storing words.
- **Fail:** Live IME ingest on a Mac is not done. F03 is not supported.
  Suggestion behavior is unchanged.
- **Where:** [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md);
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`.
- **Next:** Wire a Mac-side producer that writes only counts, then see
  whether fixtures plus live ingest satisfy the promotion rule.

## 2026-08-27 — Save the lab so tries and failures persist

- **Try:** Make the colleague working agreement durable: a public lab log,
  a ledger decision, and pointers from the agent guides so the next session
  does not start from a blank chat.
- **Learn:** Chat is not memory. The ledger is too curated to hold every
  attempt. We need both: ledger for lessons, log for tries and fails.
- **Fail:** none yet for this save. The log only works if later sessions
  actually append.
- **Where:** this file; ledger `lab-partnership-and-failure-log`;
  [`lab-partnership.md`](lab-partnership.md).
- **Next:** Implement F03 against the pre-registered instrument protocol.

## 2026-08-27 — Pre-register F03 before building it

- **Try:** Write the F03 experiment record while the hypothesis is still
  unconstrained by an implementation.
- **Learn:** The v2 online event already has 5-second replacement. The
  missing science is 30s / segment, typed-through, settled-visible, and
  missingness that cannot look like zero kept characters.
- **Fail:** F03 is not implemented. Live RNKS still cannot support a
  decision.
- **Where:** [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md).
- **Next:** Implement that protocol; do not start H01 until it is supported.

## 2026-08-27 — State the scientific program

- **Try:** Write the research stance: privacy-projected utility, learn the
  controller, treat Roy's skip result as an interaction hypothesis.
- **Learn:** Swapping in a newer GGUF would still be Smart Compose 2019.
  The new question is whether personal fit and scene grounding change
  skip for a fast desktop typist.
- **Fail:** none. This is a stance, not a result.
- **Where:** [`scientific-program.md`](scientific-program.md),
  [`where-the-field-stopped.md`](where-the-field-stopped.md).
- **Next:** Keep the generator frozen; finish the instrument.

## 2026-08-27 — Literature sweep for personal autocomplete

- **Try:** Catalog HCI, AAC, mail, Copilot, interruption, and agency
  papers we can actually run, with Tilde digests and run flags.
- **Learn:** Shipped personal keyboard papers stop at 2018–2020. Recent
  work is generic suggestion HCI or code-completion metrics. Desktop
  fast typists skip generic ghosts in transcription (Roy 2025). Tab
  tracks feeling (Ziegler) and still rewards deleted junk (GitHub 2025).
- **Fail:** The sweep is not a measured Tilde result. Several indexed
  papers still lack digests (see reading-list §10). We did not find a
  published on-device personal + screen + retained-character system.
- **Where:** [`docs/reading-list.md`](../reading-list.md),
  [`docs/research/`](./).
- **Next:** Use the catalog as priors; do not implement a paper.

## Earlier attempts already on record

These happened before this log existed. Do not rewrite them here; point
at the canonical record.

| Attempt | Outcome | Where |
| --- | --- | --- |
| F01 report provenance v6 | SUPPORTED | [`docs/experiments/F01-report-provenance-v6.md`](../experiments/F01-report-provenance-v6.md) |
| F02 campaign state reconciliation | SUPPORTED | [`docs/experiments/F02-campaign-state-reconciliation.md`](../experiments/F02-campaign-state-reconciliation.md) |
| Q01 Qwen God v1 replication | INCONCLUSIVE (runner died before a clean comparison) | [`docs/experiments/Q01-qwen-god-v1-replication.md`](../experiments/Q01-qwen-god-v1-replication.md) |
| Three-word cap on certified quiz | directional offline win; not live RNKS | Learning Ledger / `docs/learning-ledger.md` |
| Short-cap echo and repeat-penalty "wins" | rejected as scoring cheats | Ledger tags; F04 will freeze them |
| Million-eval Reply archive | depth in one lane, not product proof | Ledger `lab-evidence-coverage-gap` |

If you find an attempt that is only in chat, add a log block the same day.
A missing fail line is how this field forgot why Tab died as a metric.
