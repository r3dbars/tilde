# Tilde autoresearch lessons — 2026-08-02

## Decision

Keep the baseline. Do not promote `TOKEN_BUDGET=8`.

This was a research-only, synthetic, aggregate-only evaluation. It changed no
product code and no live app configuration.

## What happened

The 1,000-case screen made `TOKEN_BUDGET=8` look promising:

| Run | Safe accepts | Missed opportunities | Interruptions | p95 | Errors |
| --- | ---: | ---: | ---: | ---: | ---: |
| Screen baseline | 89 | 164 | 747 | 144 ms | 0 |
| Screen, budget 8 | 93 | 159 | 748 | 96 ms | 0 |
| Fresh confirmation, budget 8 | 4 | 170 | 826 | 269 ms | 0 |

The confirmation used one fresh, balanced 1,000-case exact-3 holdout with zero
case overlap with the prior screen. The candidate failed the confirmation
thresholds: interruptions <= 747, missed opportunities <= 159, safe accepts >=
89, p95 <= 144 ms, and errors = 0.

## Lessons

1. A screen candidate is not a winner. The apparent screen improvement did not
   generalize to the fresh holdout, so it was correctly rejected.
2. A fresh candidate-only holdout is enough to reject a bad candidate, but not
   enough to measure the candidate's causal delta. The next confirmation must
   run baseline and candidate on the same holdout, with the same warmup and
   evaluator rules.
3. Protocol health and product quality are separate gates. The run had zero
   protocol errors, but quality and latency still failed badly.
4. The keep-if-better rule must use the strict incumbent contract, not the
   looser screen gate. No small-screen win should change product settings.
5. Aggregate reports should preserve the failure, the holdout identity, and the
   limitation without storing contexts, continuations, or suggestions.

## Next action

Baseline remains the incumbent. Do not run or promote another knob until a new
experiment is approved with a paired baseline-versus-candidate design.

## External aggregate artifacts

- Screen ledger: `~/.cache/tilde-eval/gym/autoresearch-missed-opportunities-20260802/expanded/results.jsonl`
- Confirmation ledger: `~/.cache/tilde-eval/gym/autoresearch-missed-opportunities-20260802/confirm-token-budget-8-20260802/results.jsonl`
- Updated resume: `~/.cache/tilde-eval/gym/autoresearch-missed-opportunities-20260802/resume.md`
