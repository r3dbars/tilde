# SteadyType Replay Eval

Phase 4 prompt comparison against the same seeded three-case fixture and Qwen 3.5 4B proxy:

- Before: 360 context characters, suffix disabled, 1.67 saved keystrokes/case, 33.3% top-1 word accuracy, 490 ms p95.
- After: 600 context characters, suffix enabled, 1.67 saved keystrokes/case, 33.3% top-1 word accuracy, 494 ms p95.
- Verdict: no quality regression on the tiny deterministic fixture; the 4 ms p95 increase is acceptable. Broader personal replay remains necessary before claiming a quality lift.

- Engine: batch
- Requested model: qwen3.5-4b
- Effective model: qwen3.5-4b
- Corpus: fixture
- Cases: 3
- Seed: 0
- Prompt context characters: 600
- Text after cursor: enabled
- Few-shot source: built-in
- Decoding: tokens-20-temp-0.0-top-p-0.0-repeat-1.0

## chat-instruct / Baseline

# Typing Replay Scorecard

- Cases: 3
- Keystrokes saved: 5 (1.67/case)
- Shown keystrokes saved: 1.67/case
- Missed magic: 0.0%
- Top-1 word accuracy: 33.3%
- Exact 2/3/4-word prefix: 33.3% / 0.0% / 0.0%
- Suggestion rate: 100.0%
- Wrong first word among suggestions: 66.7%
