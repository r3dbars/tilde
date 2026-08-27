# Q06 — Fixed confidence filter on additional development roots

Status: PROPOSED
Experiment class: display-policy
Owner: Tilde research program
Pre-registered: 2026-08-27T23:44:00Z

## Pre-registration

The owner requested deeper tests and immediate launch after Q05. Q05 remains
REJECTED for its selected 0.50 policy. This new bounded discovery campaign
tests **0.475**, the conservative point identified descriptively in Q05, against
confidence floor zero. It does not revise Q05, unlock a research stage, or
authorize a live change.

Hypothesis: the fixed cutoff removes at least 20% of bad displayed suggestions
while retaining at least 95% of useful ones, without more than 10% useful loss
or increased bad-when-shown in any protected slice with a defined denominator.

### Exact comparison

- Control: Q05 Qwen 3.5 9B Q4_K_M a5; temperature 0.10, 12 generated tokens,
  three visible words, unchanged prompt, scoring, cleaner, safety and assets.
- Treatment: identical control, only minimum mean token probability = 0.475.
- No threshold search or post-result fallback. All-silent is not a win.
- Three generation seeds 17/41/73, one repetition, one worker and one slot.
  Control and treatment share identical cached synthetic responses; verify
  paired case identity, confidence values, and zero unexpected regeneration.
- 505 development roots: 473 absent from Q05 plus the 32 mandatory shared
  safety roots. Primary quality analysis excludes those 32 shared roots;
  report the full set and safety outcomes separately. These are existing Q04
  development cases, not 1,000 freshly authored situations or unseen templates.
  Validation and sealed holdout are excluded.
- 3,030 scored arm/seed/case evaluations, at most 1,515 distinct inference
  opportunities before policy suppression. Re-scoring is not new evidence.
  Ceiling: 3,240 work items, two arms, 540 roots per arm, 30 active minutes;
  finish at dataset completion rather than filling the time budget.
- Battery exception continues the owner's immediately preceding override and
  instruction to launch now. Thermal and low-power gates remain unchanged.
  Timing, energy, and time-based utility are excluded from conclusions. The
  daily-use preview is not stopped, reconfigured, or used for inference.

### Analysis and stop rules

The CLI precision-when-shown metric is descriptive. The fixed decision uses
bad-removal and useful-retention counts. Require point bad removal >=20%,
useful retention >=95%, non-increasing bad-when-shown, and all protected
category/boundary/register/context slices retaining >=90% useful. Any
undefined useful-retention denominator is reported as unavailable, not a pass.

For a supported discovery finding also require a positive lower 95% bound on
bad removal and a >=95% lower bound on useful retention. Use 10,000 paired
bootstrap samples with fixed seed 6062026, clustering all three generation
seeds and counterfactual pairs together where pair identity is available,
otherwise by root. Report root-cluster intervals as a sensitivity check. Shared
templates limit inference even after clustering. If point targets fail, reject;
if point targets pass but uncertainty or completeness fails, mark inconclusive.

Stop on safety sentinel, privacy, missing confidence, pairing, or completeness
failure. Do not resume a failed campaign, replace failed cases, increase budgets,
change seeds, or weaken gates. Do not compare/promote, nominate, validate,
consume holdout, or change live behavior. Review the terminal evidence honestly.

### Frozen provenance

- Campaign ID: `CB3B468B-3FC2-43FE-98D5-B25EDBD436B7`.
- Hypothesis ID: `QWEN-CONFIDENCE-06`.
- Code parent: `5fe7655afeaeaedd9bde605d55605fce7317bce5`; actual clean launch
  commit will be captured in the v6 reports after this registration commit.
- Runner SHA-256: `d49c8ac3b6635147b14fdd37c6954616954be5c1f3607486c51f4600cc9cda73`.
- Campaign SHA-256: `bee17042dcafb90b7974ad4a276f351e11c6751d772f3198b7bedeb21a647458`.
- Manifest SHA-256: `9fa2cd1e867d7f79b4dcfa1d57e73f887bc93c402fde06a00daeadc6af89c80e`.
- Suite file SHA-256: `b059869aac0b2d340a2dd5c95cd0f7dd201b7544d3e89b6128287fd8dfcdea28`.
- Selected suite SHA-256: `e49f0c90afe2662aa49f77b03cc795bd4e5ca54099f533c9f161ee3c9c233c3d`.
- Model revision: `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`.
- Model SHA-256: `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`.
- Helper SHA-256: `66d928b602000ee008cf8884ef97c3123b29e3a03a5b8fdef9be2bb7e3c0f0c5`.

## Result

Pending. No result was inspected during registration.

## Limitations and follow-up

This tests a conservative confidence cutoff on more synthetic development
roots. It does not establish live retained utility, prose/email coverage,
calibration, speed, or generalization to independent templates. The larger
freshly authored corpus plan remains separate. Even relative improvement would
not excuse a high absolute bad rate or replace production's protected gates.
