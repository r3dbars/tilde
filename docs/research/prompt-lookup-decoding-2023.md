# Prompt Lookup Decoding / speculative n-gram drafts (Saxena 2023 and llama.cpp)

**Source:** https://github.com/apoorvumang/prompt-lookup-decoding (commonly cited write-up); llama.cpp speculative docs, https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md
**Related:** Leviathan et al., Fast Inference via Speculative Decoding, https://arxiv.org/abs/2211.17192 (already digested).
**License:** Project documentation; Leviathan is CC BY 4.0 on arXiv.

## What it does (plain words)

Speculative decoding drafts several tokens cheaply and has the big model verify them in one pass. Prompt-lookup decoding skips even the draft model: it copies n-grams that already appeared in the prompt. That is a win when the user is repeating themselves.

## Method

Find n-gram matches in the current context, propose them as the continuation, verify with the main model. llama.cpp exposes this as a server flag. If the copy is wrong, verification rejects it and you pay a small waste; if it is right, you skip decode steps.

## Key findings

- Prompt-lookup helps when text self-repeats: boilerplate, headers, the phrase you used last sentence.
- It does not need a second GGUF.
- Gains are workload-dependent. Unique prose sees less lift than repetitive code or templates.

## What Tilde should take from it

This is a runtime experiment that does not change the generator's weights and does not need private training. It is one of the few engine papers Tilde can actually run on the owner's Mac without a new model tournament: flip the helper flag, freeze everything else, watch p95 latency and RNKS.

It doubles as a personalization mechanism. Personal History phrases that are already in the prompt can be drafted for free. That is adjacent to H11 (exact phrase expert) but cheaper, and it can be tried earlier as a runtime A/B once F03 exists — still one causal question, still not a Stage 3 unlock.

## Limits and caveats

Verify-reject can waste work on highly original sentences. Do not turn it on in production from this note. Do not log draft strings. Pair with the existing speculative-decoding digest; this note is the "no extra model" variant.
