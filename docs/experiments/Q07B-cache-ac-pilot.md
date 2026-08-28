# Q07B — Fixed AC prompt-cache readiness pilot

Status: PRE-REGISTERED
Experiment class: generator (request cache flag only)
Owner: r3dbars
Pre-registered: 2026-08-28

## Authorization and question

After Q07 expired, the owner instructed: "Run it when you are fone".
The assistant explained that continuation would use a smaller fixed AC pilot,
then launch the full study only after functional completion. Q07 remains
aborted/inconclusive; it is not resumed, extended, renamed or overwritten.

Can both cache settings complete all development cases, fresh inference and
correctly attributed numeric measurements within a 15-minute AC budget?
This is an instrumentation readiness question, not a test of superiority.

## Frozen protocol

- Copy Q07's exact two arms, model/helper, prompt, confidence 0.475, generation
  and scoring. Only cache_prompt false/true differs between arms.
- All 600 selected Certified V2 development cases including mandatory
  sentinels, seed 17, one repetition: 1,200 planned evaluations, 600 per arm.
  The reduced seed count is frozen before results, not a favorable-case
  selection. Q08 still uses all three original seeds, 17/41/73.
- One worker/slot, shared long-lived helper, 50-root blocks alternating AB/BA,
  warmup on, chunk cache-reuse zero, --no-cache, no response replay.
- AC required, no battery override. No simultaneous build or proof run.
  Daily preview is left unchanged and remains a possible contention source.
- Fresh campaign and database, 0.25-hour active/wall ceiling; corrected
  script/lab_cache_study.rb launched with the Q07B-ac-pilot registration.
  Existing low-power, thermal, safety and sentinel rules remain intact.
  Stop on power loss, helper RSS above 16 GiB, multiple owned helpers or budget.
- Require 1,200/1,200 completed, two complete v6 reports, no live session/helper,
  no runtime/sentinel failure, at least 100 actual model requests and at least
  30 valid arm-attributed RSS samples per arm. All observed block orders must
  match the frozen AB/BA schedule.
- Check native cached-token counters within same-arm/block/helper intervals.
  Initial missing samples, transitions and absent counters are never zeros.
  RSS is sampled process memory, not total GPU/unified memory.
- Quality counts and absolute gates are reported honestly, independently of
  functional readiness. No comparison/promotion, validation or holdout.
  Review inconclusive for cache superiority; readiness may pass separately.
- Failure means stop and report, not create another retry automatically.

## Provenance

Q07's model revision and hashes are retained:

- Model revision: ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6.
- Model SHA-256: 4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2.
- Helper SHA-256: 66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5.

Freeze clean source, runner, supervisor and campaign hashes before launch.
Record local artifacts owner-only. Publish aggregate evidence only.
The experiment index and Q08 launch decision are the durable readers.

## Result

Not run yet. Q08 cannot launch before this fixed readiness gate is met.
