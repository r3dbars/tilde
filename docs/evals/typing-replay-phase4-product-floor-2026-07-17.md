# SteadyType Replay Eval

Aggregate-only personal replay of the production local prediction floor:

- Baseline without personal memory: 0% suggestion and top-1 accuracy on these 30 cases.
- Personalized n-gram memory: 23.3% top-1 accuracy, 6.17 raw and 5.67 shown keystrokes saved/case, 23.3% suggestion rate, and 0% wrong-first-word rate.
- The 6.7% missed-magic rate comes from presentation/confidence gating in this product-floor replay, not `CompletionOutputCleaner` (the product-floor engine does not call the cleaner). Cleaner filters therefore remain unchanged; the evidence does not convict them.
- This report contains aggregates only. No captured text, prompts, continuations, or suggestions are stored here.

- Engine: product
- Requested model: product
- Effective model: product
- Corpus: personal
- Cases: 30
- Seed: 0
- Prompt context characters: 360
- Text after cursor: disabled
- Few-shot source: built-in
- Decoding: tokens-20-temp-0.0-top-p-0.0-repeat-1.0

## chat-instruct / Baseline

# Typing Replay Scorecard

- Cases: 30
- Keystrokes saved: 0 (0.00/case)
- Shown keystrokes saved: 0.00/case
- Missed magic: 0.0%
- Top-1 word accuracy: 0.0%
- Exact 2/3/4-word prefix: 0.0% / 0.0% / 0.0%
- Suggestion rate: 0.0%
- Wrong first word among suggestions: 0.0%

## chat-instruct / Personalized

# Typing Replay Scorecard

- Cases: 30
- Keystrokes saved: 185 (6.17/case)
- Shown keystrokes saved: 5.67/case
- Missed magic: 6.7%
- Top-1 word accuracy: 23.3%
- Exact 2/3/4-word prefix: 16.7% / 13.3% / 13.3%
- Suggestion rate: 23.3%
- Wrong first word among suggestions: 0.0%
