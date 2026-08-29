# Improving Neural Language Models with a Continuous Cache (Grave, Joulin & Usunier, ICLR 2017)

**Source:** https://arxiv.org/abs/1612.04426
**License:** ICLR / arXiv. Check the paper page before quoting; treat as link-and-attribute.

## What it does (plain words)

A neural language model forgets that you just said a rare name. This paper adds a cheap memory of recent hidden states and looks them up with a dot product, like the old n-gram cache models, without retraining. Recent tokens become more likely again.

## Method

As the model reads, it stores hidden activations. At each step it compares the current hidden state to that memory and interpolates the cache distribution with the network's next-token distribution. This is a simplified memory network and a neural cousin of Kuhn's cache language model. They show gains on standard LM datasets against heavier memory architectures.

## Key findings

- Recency can be a pointer, not a finetune.
- The cache helps most on repeated rare tokens — names, technical words, the thing you used two sentences ago.
- It stays cheap as memory grows because access is a dot product, not a second model.

## What Tilde should take from it

This is the prior for H10 (decayed recent cache), which stays locked until Personal History experts are unlocked. Do not start it now.

When it is legal to run: prefer a count/cache over a private LoRA. Tilde already wants "counts, caches, retrieval, and calibration" instead of training on private writing. Grave's cache is the neural picture; a decaying n-gram over recent accepted *local* text is the product-shaped version.

Do not store raw activations or raw text in Git or in a Lab report. A live cache lives in app memory or user-controlled storage and dies with delete-everything.

## Limits and caveats

Offline language-model perplexity, not suggestions, not a user study. Hidden-state caches assume we own the decoder loop. Tilde's helper is llama-server; a pointer-over-recent-tokens may have to sit in front of the helper as a blend, the way Smart Compose blended n-grams, rather than inside the net.
