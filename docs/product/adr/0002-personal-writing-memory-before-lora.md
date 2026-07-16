# ADR-0002: Personal writing memory before LoRA

- Status: Accepted
- Date: 2026-07-15
- Supersedes: none

## Context

SteadyType needs to learn Justin's writing without making the dogfood app harder
to understand or operate. Fine-tuning a model could eventually help, but it also
adds training, model-version, rollback, and privacy work before we know whether
personalization improves the typing loop.

The existing Personal Capture journal already contains the opted-in local
writing corpus needed for a smaller experiment. A replay scorecard can compare
the same cases with and without that memory.

## Decision

Use retrieval-based personal writing memory first:

- Build a capped, decay-weighted local index from every daily file in the
  opted-in Personal Capture journal. Older writing remains available at lower
  weight instead of disappearing at a fixed cutoff.
- Use local n-gram continuations for the instant lane and short retrieved
  snippets plus an aggregate style profile for the model prompt.
- Attach personal context only when Personal Capture is enabled, the existing
  `PersonalCapturePolicy` allows the focused field, and the request is a phrase
  or sentence continuation. Word completion stays unpersonalized.
- Prefer the current document's n-gram when it competes with personal memory;
  the current field is fresher and more specific.
- Keep all personal text local. Committed eval artifacts contain aggregate
  numbers only.

LoRA fine-tuning is deferred. Replay trend rows keep a `variant` field so a
future `lora-*` variant can be compared against `baseline` and `personalized`
without replacing the eval system.

## Why

This is the smallest experiment that can answer the product question: does
learning Justin's phrasing save more keystrokes without making suggestions more
annoying? It is fast to rebuild, easy to delete, uses no new dependency, and can
be turned off with the existing Personal Capture control.

## Consequences

- Personalization remains Justin-only dogfood and defaults off.
- A replay improvement is evidence for the retrieval approach, not automatic
  proof that it is ready for beta users.
- If replay gains plateau, a future ADR may authorize LoRA work. That change
  must preserve paired cases, within-model comparisons, and the no-personal-text
  artifact boundary.
