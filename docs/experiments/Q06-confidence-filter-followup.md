# Q06 — Fixed confidence filter on additional development roots

Status: SUPPORTED (bounded synthetic filtering effect; not production eligibility)
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

Completed: 2026-08-27T23:50:27Z. Durable state reconciled to completed, with
3,030/3,030 evaluations, two complete v6 reports, zero failed work, zero live
campaign sessions, and no remaining campaign helper. Both reports carry an
explicit SUPPORTED review for this bounded relative-effect hypothesis.

### Aggregate evidence

The primary set contains 473 roots and 1,419 paired observations per arm,
excluding 32 shared mandatory sentinel roots. Those sentinels contributed no
displayed suggestions, so the full-set displayed counts equal the primary
counts. There were 1,059 actual generated candidates, all nonempty, all with
numeric mean confidence and token-log-probability evidence. Every generated
control/treatment pair had identical confidence and exactly one cache miss
plus one cache hit. The 3,030 scored evaluations are not 3,030 model calls.

| Primary result | Control | Cutoff 0.475 |
| --- | ---: | ---: |
| Useful displayed | 389 | 388 |
| Wrong displayed | 224 | 161 |
| Unwanted displayed | 189 | 138 |
| Total bad displayed | 413 | 299 |
| Bad among displayed | 51.50% | 43.52% |

The filter removed 114 bad suggestions (**27.60%**) while losing one useful
suggestion (**99.74% useful retention**). Net keystrokes across the full set
rose from 2,269 to 2,355 (9.998% to 10.377% net keystroke savings); that is an
offline scoring proxy, not retained live writing or measured time saved.

The pre-registered paired counterfactual-cluster bootstrap used 284 clusters,
10,000 samples, and seed 6062026. Its 95% intervals were **19.57–36.06% bad
removal** and **99.12–100% useful retention**. This satisfies the registered
point-effect target plus positive lower bad-removal bound; it does **not**
establish that the true reduction is at least 20%. Root-cluster sensitivity
(473 clusters) gave 21.33–34.18% and 99.15–100%, respectively. Repeated seeds
and paired counterfactuals were not treated as independent observations.

Seed-specific bad reductions were 26.81%, 29.71%, and 26.28% for seeds 17,
41, and 73. Useful retention was 100%, 99.23%, and 100%, respectively.

### Protected slices and negative findings

| Primary category | Useful: control → filter | Bad: control → filter |
| --- | ---: | ---: |
| reply.acknowledge | 0 → 0 | 60 → 55 |
| reply.answer | 73 → 72 | 47 → 21 |
| reply.clarify | 60 → 60 | 0 → 0 |
| reply.commit | 0 → 0 | 44 → 35 |
| reply.confirm | 27 → 27 | 0 → 0 |
| reply.correct | 0 → 0 | 24 → 5 |
| reply.decline | 60 → 60 | 0 → 0 |
| reply.thank | 49 → 49 | 11 → 11 |
| silence.ordinary | 0 → 0 | 189 → 138 |
| silence.sensitive | 0 → 0 | 0 → 0 |
| stress.contradiction | 0 → 0 | 30 → 26 |
| stress.full-reply | 0 → 0 | 2 → 2 |
| stress.irrelevant-context | 30 → 30 | 0 → 0 |
| stress.long-context | 0 → 0 | 0 → 0 |
| stress.mid-word | 0 → 0 | 6 → 6 |
| stress.multiple-questions | 30 → 30 | 0 → 0 |
| stress.prompt-injection | 0 → 0 | 0 → 0 |
| stress.sensitive-near-miss | 30 → 30 | 0 → 0 |
| stress.stale-context | 30 → 30 | 0 → 0 |
| stress.typo | 0 → 0 | 0 → 0 |

The worst defined useful-retention slice was `reply.answer`: 72/73, or
98.63%. All other categories with useful control observations retained 100%.
No defined category/boundary/register/context bad-when-shown rate increased.
Zero-useful slices supply no useful-retention evidence. All cases were chat
with structured-thread context; no prose/email generalization is established.
The mid-word slice still had six bad displays and no useful displays.

Both arms **failed the absolute bad-suggestion gate**. Privacy, sensitive-case,
and temporal gates passed; IMKit interaction was not run. The recorded latency
gate passed but is excluded from the decision, as are all speed/energy claims.
The machine was on AC power, thermal nominal, low-power mode off at provenance
capture, despite the permitted battery flag. Replayed timings are not fresh
performance observations, and the daily-use preview remained running.

### Final provenance and decision

- Clean execution/pre-registration commit: `04ae396040c761757ddf406131375a20a8b804f5`.
- Control report: `932710FF-8FE0-42B7-A40F-DDC009B43086`.
- Filter report: `893E19C4-9F2A-41C4-948B-59B521FE232E`.
- Invocation digest: `60846990e006a4119196f8e87a9d9439d14efcdddcabe7ea2b95d039478510e9`.
- Hardware class `Mac17,7`, OS build `25G83`; active campaign budget used 0.11 hours.
- Campaign and runner hashes were rechecked after completion and unchanged.

Keep the evidence-capture repair and the narrow finding that fixed confidence
filtering reduced bad displays on these development templates with negligible
useful loss. Do not deploy this cutoff: 43.52% bad-when-shown remains high.
Q05 stays rejected, and the separate Q04 record remains in
[PR #428](https://github.com/r3dbars/tilde/pull/428). No comparison/promotion,
nomination, validation, holdout, new campaign, or live change was performed.
The existing foundation queue and protected stage gates are unchanged.

Publication verification on current main: nine focused parser/ledger tests
passed; `./script/proof.sh fast` passed all blocking checks, including 775
tests in 100 suites. The publication branch changes no shipped app, IME, or
TildeCore code. The original execution checkout and source commit remain
unchanged; publication is a separate branch based on current main.

Durable lesson: `qwen-confidence-filter-bounded`. The attempt is also recorded
in the [lab log](../research/lab-log.md). A future independent-template or live
retained-outcome test requires its own authorization and the existing gates.

## Limitations and follow-up

This tests a conservative confidence cutoff on more synthetic development
roots. It does not establish live retained utility, prose/email coverage,
calibration, speed, or generalization to independent templates. The larger
freshly authored corpus plan remains separate. Even relative improvement would
not excuse a high absolute bad rate or replace production's protected gates.
