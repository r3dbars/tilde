# Prompt Lookup Decoding / speculative n-gram drafts (Saxena 2023 and llama.cpp)

**Source:** https://github.com/apoorvumang/prompt-lookup-decoding (commonly cited write-up); llama.cpp speculative docs, https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md
**Related:** Leviathan et al., Fast Inference via Speculative Decoding, https://arxiv.org/abs/2211.17192 (already digested).
**License:** Project documentation; Leviathan is CC BY 4.0 on arXiv.

## What it does (plain words)

Speculative decoding drafts several tokens cheaply and has the big model verify them in one pass. Prompt-lookup decoding skips even the draft model: it copies n-grams that already appeared in the prompt. That is a win when the user is repeating themselves.

## Method

Find n-gram matches in the current context, propose them as the continuation,
and verify them with the main model. If the copy is wrong, verification rejects
it and pays some wasted work; if it is right, the target can accept several
tokens in one step.

The signed Model Preview helper was inspected on 2026-08-30. Its current
`llama-server --help` exposes `ngram-simple`, `ngram-map-k`,
`ngram-map-k4v`, `ngram-mod`, and `ngram-cache` under `--spec-type`. The old
`--draft` spelling has been removed in favor of the `--spec-*` family. That is
a compatibility observation, not proof that any mode is active or faster in
Tilde.

## Key findings

- Prompt-lookup helps when text self-repeats: boilerplate, headers, the phrase you used last sentence.
- It does not need a second GGUF.
- Gains are workload-dependent. Unique prose sees less lift than repetitive code or templates.

## What Tilde should take from it

This is a runtime experiment that does not change the generator's weights and
does not need private training. Once H01 freezes visible-output semantics,
pre-register one output-equivalent A/B on the signed helper: direct generation
versus one supported n-gram speculation mode. Freeze everything else and report
drafted tokens, accepted tokens, p50/p95/p99 latency, energy/thermal evidence,
and RNKS non-inferiority. Draft acceptance proves mechanism activation, not
user benefit.

Prompt repetition may make the mechanism more useful on familiar phrases, but
that does not make it a Personal History expert. It remains an H02 runtime
follow-up, not H19 and not a Stage 3 unlock.

## Limits and caveats

Verify-reject can waste work on highly original sentences. Do not turn it on in
production from this note. Do not log draft strings. The pinned helper and its
flags may drift in later builds, so every registered run must re-verify the
helper hash and accepted option names. Pair with the existing speculative-
decoding digest; this note is the "no extra model" variant.
