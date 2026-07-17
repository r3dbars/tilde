# SteadyType Replay Eval

This isolated sampled-decoding probe is a negative result against the Phase 4 greedy prompt run:

- Greedy: 494 ms p95, 0% missed magic, 100% suggestion rate, 1.67 shown keystrokes saved/case.
- Sampled: 1,026 ms p95, 33.3% missed magic, 66.7% suggestion rate, 0 shown keystrokes saved/case.
- Decision: do not replace greedy decoding. Production keeps greedy as candidate one and adds one sampled candidate only for continuation budgets of at least 24 tokens, then reranks the union. Word and short completion stay greedy.

- Engine: batch
- Requested model: qwen3.5-4b
- Effective model: qwen3.5-4b
- Corpus: fixture
- Cases: 3
- Seed: 0
- Prompt context characters: 600
- Text after cursor: enabled
- Few-shot source: built-in
- Decoding: tokens-20-temp-0.35-top-p-0.9-repeat-1.05

## chat-instruct / Baseline

# Typing Replay Scorecard

- Cases: 3
- Keystrokes saved: 5 (1.67/case)
- Shown keystrokes saved: 0.00/case
- Missed magic: 33.3%
- Top-1 word accuracy: 33.3%
- Exact 2/3/4-word prefix: 33.3% / 0.0% / 0.0%
- Suggestion rate: 66.7%
- Wrong first word among suggestions: 50.0%
