# Phase 4 prediction-quality summary

All runs use seed 0 and persist aggregate metrics only.

| Slice | Before | After | Decision |
| --- | --- | --- | --- |
| Prompt context + suffix | 1.67 saved keys/case, 33.3% top-1, 490 ms p95 | 1.67, 33.3%, 494 ms | Ship as no-regression context upgrade; no lift claimed from the 3-case fixture. |
| Sampled decoding alone | 0% missed magic, 100% suggestion rate, 494 ms p95 | 33.3% missed magic, 66.7%, 1,026 ms | Do not replace greedy. Keep greedy as candidate one; add one sampled candidate only for long budgets. |
| Corpus phrase floor | 0% top-1 on 3 newly covered held-out phrases | 100% top-1, 13.67 saved keys/case | Ship the broader deterministic floor; claim is limited to its added coverage. |
| Personal product floor | 0% top-1 and suggestion rate without personal memory | 23.3% top-1, 5.67 shown saved keys/case, 0% wrong-first-word | Ship; this is the clearest measured quality lift and remains opt-in/local-only. |

Cleaner recalibration: the greedy model replay reported 0% missed magic. The product-floor replay reported 6.7%, but that path does not invoke `CompletionOutputCleaner`; its loss is presentation/confidence gating. No cleaner rule was relaxed without evidence.
