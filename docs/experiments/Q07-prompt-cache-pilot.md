# Q07 — Prompt-cache instrumentation pilot

Status: PRE-REGISTERED PILOT; no superiority or promotion decision
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

Not run yet. Report pilot functionality separately from quality approval.
Publish aggregate evidence only; owner-only state, prompts, outputs and paths
stay local. The experiment index is the durable reader for this record.
