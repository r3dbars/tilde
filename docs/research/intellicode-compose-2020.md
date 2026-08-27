# IntelliCode Compose: Code Generation using Transformer (Svyatkovskiy, Deng, Fu & Sundaresan, FSE 2020)

**Source:** https://arxiv.org/abs/2005.08025
**License:** arXiv non-exclusive distribution license.

## What it does (plain words)

Microsoft's first whole-line ghost-text system for Visual Studio Code. A GPT-2-style model trained on 1.2 billion lines of code proposes the rest of the line. The serving trick that matters for Tilde is on the client: they cache scored completions in a trie keyed by prefix, then cheaply walk that trie as the user keeps typing instead of calling the model again.

## Method

GPT-C, 24 layers, trained from scratch on Python, C#, JavaScript, and TypeScript. Beam search stops at newline or a language-specific end. Client post-process stores the beam as a trie. Further keystrokes prune the trie. A length-relevance score balances long vs short (`α = 0.8`, `κ = 10` in the paper). They report 86.7% average edit similarity and 1.82 perplexity for Python. Later Copilot work cites their online CTR near 10%.

## Key findings

- Edit-time completion is a cache problem as much as a model problem. Most keystrokes only extend the last prefix.
- A length prior is required or beam search prefers safe short tails — or, with a different reward, bloated long ones.
- Perplexity and edit similarity are offline. Their live CTR was much lower than those offline numbers, the same Smart Compose lesson.

## What Tilde should take from it

Reuse, do not rebuild: Tilde Lab already caches synthetic candidates. The IntelliCode move that is still missing on the *product* side is a prefix trie for the last ghost so a continued word does not pay a full helper round-trip. That is a runtime experiment, not a new model, and it only helps if cancellation and marked-text identity stay correct.

The length score is a prior for H01/H08: explicitly penalize or boost length instead of hoping the sampler lands on three words. H01's fixed cap is the simple version. Do not start H08 until the cap is live-proven.

Do not chase 86.7% edit similarity. That is code, offline, and it did not become their live CTR.

## Limits and caveats

Cloud IDE plugin, code tokens, newline as a natural stop. Tilde's stop is punctuation, word count, and IMKit. Their trie holds suggestion text; Tilde must not persist that trie to disk or logs. A memory-only, request-scoped cache is the only shape that fits the privacy rules.
