# SteadyType Replay Eval

Same-seed deterministic comparison against the former 18-phrase floor:

- Before (`common`): 0.00 saved keystrokes/case, 0% top-1 accuracy, 33.3% suggestion rate, 100% wrong-first-word rate.
- After (`corpus`): 13.67 saved keystrokes/case, 100% top-1 and exact 2/3-word prefix accuracy, 100% suggestion rate, 0% wrong-first-word rate.
- Scope: three new held-out common-phrase cases. This proves the broader table is reachable and correct for its added coverage; it is not a general-language quality claim.

- Engine: corpus
- Requested model: corpus
- Effective model: corpus
- Corpus: fixture
- Cases: 3
- Seed: 0
- Prompt context characters: 360
- Text after cursor: disabled
- Few-shot source: built-in
- Decoding: tokens-20-temp-0.0-top-p-0.0-repeat-1.0

## chat-instruct / Baseline

# Typing Replay Scorecard

- Cases: 3
- Keystrokes saved: 41 (13.67/case)
- Shown keystrokes saved: 13.67/case
- Missed magic: 0.0%
- Top-1 word accuracy: 100.0%
- Exact 2/3/4-word prefix: 100.0% / 100.0% / 0.0%
- Suggestion rate: 100.0%
- Wrong first word among suggestions: 0.0%
