# Tilda expanded screen sweep — 2026-08-02

## Purpose

This is a research-only one-knob screen of the remaining supported runtime controls. It ran against a fresh, deterministic 1,000-case synthetic split (`case_hash=536fc3dee8d75673afb1bf6a0fad9a9924ddaf98e2d07ba708a302fab4690c2d`) with the exact-3 retrieval mode. It did not change production settings.

The screen guardrails were: zero errors; at least five fewer final-only misses; no safe-accept loss; no more than five additional interruptions; and p95 no worse than `max(150 ms, baseline + 20 ms)`. The screen baseline was 89 safe accepts, 164 final-only misses, 747 interruptions, and 144 ms p95.

## Results

Two settings qualified for confirmation only:

| candidate | safe | misses | interruptions | p95 | decision |
| --- | ---: | ---: | ---: | ---: | --- |
| `TOKEN_BUDGET=8` | 93 | 159 | 748 | 96 ms | candidate; confirm twice on fresh 3,000-case runs |
| `MAX_SCREEN_CHARS=700` | 92 | 156 | 752 | 122 ms | candidate; confirm twice on fresh 3,000-case runs |

All other settings were rejected by the same guardrails. The most useful negative results were:

- `ECHO_GUARD_MIN_WORDS=2`: misses rose to 215 despite fewer interruptions; this guard is suppressing useful completions.
- `MAX_VISIBLE_WORDS=10`: misses rose to 172; shortening the visible phrase did not recover opportunities.
- `TEMPERATURE=0.05`, `TOP_P=0.8/0.95/1.0`, and `TOP_K=20/80`: none reduced misses by the required five without another tradeoff.
- `CONFIDENCE=0.08`, short-confidence thresholds, token floors, and context sizes: no candidate cleared the joint safety/quality gate. Token floors were especially harmful, removing safe accepts.
- `MIN_P=0` and `MIN_P=0.05`, plus repeat penalties 1.0 and 1.10, produced 1,000 interruptions with zero safe accepts and zero misses. This is a fail-closed runtime compatibility result, not a quality result; those controls must not be enabled without a dedicated configuration contract and a preflight check.

The ledger is the authoritative raw record at:

`~/.cache/steadytype-eval/gym/autoresearch-missed-opportunities-20260802/expanded/results.jsonl`

It includes the initial interrupted attempts and their successful retries. A crash row is retained as evidence that the run was resumed safely after a host/tool interruption.

## Interpretation

The screen did not identify a production winner. The two provisional candidates are small, noisy changes on a 1,000-case screen and must be held out before any promotion. More importantly, the miss count is not yet a faithful proxy for the live IME: the evaluator counts an empty final as a miss even when the IME has already displayed a useful partial. The next instrumentation pass must score the complete event path (`ever shown`, `safe`, `interrupted`, `final retracted`, and time-to-first-token) while keeping the old final-only metric for continuity.

## Next experiments

1. Confirm the two candidates twice on fresh 3,000-case subsets; keep/revert only from paired holdout evidence.
2. Run the preregistered per-surface retrieval policy (`browser=3`, `email=2`, `messages=1`, `notes=3`, `slack=0`, `writing=0`) on two fresh 10,000-case holdouts. The prior 10,000-case retrospective estimate was 1,020 safe, 1,495 misses, and 7,485 interruptions versus 953/1,546/7,501 for global exact-3, but it is not promotion evidence.
3. Measure weak retrieval matches separately. The selector currently substitutes corpus-wide examples when exact app/topic matches are scarce; test available-only, zero-on-weak-match, and same-app-only fallback.
4. Screen a bounded retry only for true empty-final/no-partial episodes. Do not retry partial-only episodes until the complete event-path evaluator exists.

All settings were restored after the run. No production files, model weights, or user data were changed.
