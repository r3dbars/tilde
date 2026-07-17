# SteadyType Replay Eval

- Engine: batch
- Requested model: gemma-4-e4b-it-optiq
- Effective model: qwen3.5-4b
- Corpus: fixture
- Cases: 3
- Seed: 0
- Prompt context characters: 360
- Text after cursor: disabled
- Few-shot source: built-in
- Decoding: tokens-20-temp-0.0-top-p-0.0-repeat-1.0

The installed Gemma runtime could not load `gemma4_text`, so the harness used its documented local Qwen 3.5 4B proxy fallback.

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
