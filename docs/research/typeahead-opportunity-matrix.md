# TypeAhead Opportunity Matrix

Reviewed: 2026-05-26

Scores: 1 low, 5 high. For effort and risk, 5 means expensive/risky.

| Idea | User value | Annoyance reduction | Privacy fit | Effort | Risk | Repo fit | Proofability | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Human "why quiet" reasons for suppressed fields | 5 | 5 | 5 | 1 | 1 | 5 | 5 | Ship now |
| Keep `Tab` as one-word accept and explain full accept separately | 5 | 5 | 5 | 1 | 1 | 5 | 5 | Keep |
| Settings privacy proof: local runtime, redacted traces, raw opt-in state | 5 | 4 | 5 | 2 | 1 | 5 | 4 | Already strong; keep polishing |
| App proof matrix instead of broad "works everywhere" copy | 5 | 5 | 5 | 2 | 1 | 5 | 5 | Already strong; keep current |
| Per-app controls in menu/settings | 4 | 5 | 5 | 2 | 2 | 5 | 4 | Already strong |
| Inline ghost text everywhere | 5 | 3 | 3 | 5 | 5 | 2 | 2 | Avoid for now |
| Browser production-field support | 4 | 2 | 2 | 5 | 5 | 2 | 2 | Keep blocked until proof |
| Terminal and prompt-app support | 3 | 2 | 3 | 5 | 5 | 3 | 3 | Proof-only |
| Personal learning from accepts | 4 | 3 | 2 | 4 | 4 | 4 | 3 | Dogfood/local opt-in only |
| Local model picker | 3 | 2 | 5 | 4 | 3 | 3 | 3 | Later |
| Network proof in app UI | 4 | 3 | 5 | 3 | 2 | 4 | 3 | Later |

## Picked For This Pass

Ship the smallest high-confidence trust improvement: convert internal activation block codes into plain, trace-safe explanations. This directly adapts the competitive lesson without copying TypeAhead UI or claims.

Why now:

- It makes Settings and the menu feel more trustworthy.
- It reduces tester confusion when suggestions do not appear.
- It reinforces SteadyType's strongest differentiator: safe silence.
- It is easy to test as pure core policy.
