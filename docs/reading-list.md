# Reading list

The external knowledge Tilde builds on: annotated links, never copied text
(free to read is not free to redistribute). Each entry earns its place with a
one-line note on what it teaches *for Tilde*. Ideas from here are hypotheses;
once measured, the result graduates to `docs/model-lessons.md` as fact.

Most entries have an original-words digest in `docs/research/` — method,
numbers, what applies to Tilde, and what does not — written for fast parsing
by humans and agents alike. Read the digest first; fetch the source only when
the digest isn't enough.

## Shipped-system playbooks

- [Gmail Smart Compose: Real-Time Assisted Writing](https://arxiv.org/abs/1906.00080)
  (Chen et al., 2019) — the closest thing to Tilde's product in the
  literature: trigger policy, latency budgets, confidence thresholding, and
  global+personal model interpolation. The personalization blend is the
  template for promoting the Personal History next-word model into serving.
- [Federated Learning for Mobile Keyboard Prediction](https://arxiv.org/abs/1811.03604)
  (Hard et al., Gboard) — ignore the federation (Tilde is single-device by
  design); adopt the metric vocabulary: impressions, acceptance rate,
  keystrokes saved. Our shown/accepted counters follow this framing.
- [Examination and Extension of Strategies for Improving Personalized Language
  Modeling via Interpolation](https://arxiv.org/abs/2006.05469) — per-user
  Kneser-Ney n-gram blended with a global model:
  `P = α·P_personal + (1-α)·P_global`, over 80% of users improved. The
  concrete recipe for wiring the shadow model into live suggestions.

## Foundations

- [Speech and Language Processing, ch. 3: N-gram Language Models](https://web.stanford.edu/~jurafsky/slp3/)
  (Jurafsky & Martin, free draft) — smoothing and backoff theory behind the
  Personal History next-word table; read before touching its counting logic.
- [Generalization through Memorization: Nearest Neighbor Language Models](https://arxiv.org/abs/1911.00172)
  (Khandelwal et al.) — retrieval over a user's own past text as a second
  personalization signal; gains concentrate on rare personal tokens (names,
  project words). Candidate phase-2 personalization after interpolation.
- [Dasher](https://dasher.at/) (MacKay) — text entry as navigation of
  probability space; the deepest treatment of the information theory behind
  keystrokes-saved, Tilde's north-star metric.

## Human factors

- [Observations on Typing from 136 Million Keystrokes](https://userinterfaces.aalto.fi/136Mkeystrokes/)
  (Dhakal et al., CHI 2018) — real typing dynamics: bursts, pauses,
  corrections. Grounds reveal-delay and debounce choices.
- AAC word-prediction literature (search: "word prediction keystroke savings
  AAC") — decades of measurement of exactly our metric; key finding: reading
  a suggestion has a cognitive cost that can exceed the typing it saves. The
  research ancestor of "suggestions must help more than they interrupt."
- [Are Word Suggestions Beneficial?](https://doi.org/10.1145/3772716)
  (TOCHI 2025) — suggestions help speed only when they are highly accurate,
  and fast typists mostly ignore them. Inline ghosts save a bit more than a
  suggestion bar and also distract more. Use this when designing H01 length
  and H04 cooldown; do not assume any ghost is a gift.
- [Predictive Text Encourages Predictable Writing](https://www.eecs.harvard.edu/~kgajos/papers/2020/arnold20predictcive.shtml)
  (Arnold, Chauncey & Gajos) — stronger prediction makes writing more
  generic. A Tilde win that flattens the owner's voice is a product failure
  even if keystrokes fall. Keep authorial-agency checks beside RNKS.

## Intervention and display policy

These are the papers the staged roadmap already depends on. They argue that
generation is cheap compared with the decision to show, hide, or wait.

- [When to Show a Suggestion?](https://arxiv.org/abs/2306.04930)
  (Mozannar et al., AAAI 2024) — Copilot telemetry from 535 programmers:
  hide likely rejects, skip some generation entirely, and do not train the
  generator on Tab presses. This is the template for H06/H07 after F03
  exists. Digest: `docs/research/when-to-show-suggestion-2023.md`.
- [Sequential Decision-Making for Inline Text Autocomplete](https://arxiv.org/abs/2403.15502)
  (Chitnis, Yang & Geramifard, 2024) — a wrong glance costs ~50 ms, a right
  one ~10 ms, and length is not the reading cost. RL did not beat a simple
  threshold on speed. Start with deterministic quiet rules, not a learned
  agent. Digest: `docs/research/sequential-autocomplete-2024.md`.
- [The road to better completions](https://github.blog/ai-and-ml/github-copilot/the-road-to-better-completions-building-a-faster-smarter-github-copilot-with-a-new-custom-model/)
  (GitHub, 2025) — Copilot stopped optimizing acceptance after it rewarded
  short suggestions people deleted. Retained characters became the headline.
  This is why F03 and RNKS exist. Digest:
  `docs/research/copilot-retained-completions-2025.md`.
- [A Cost-Benefit Study of Text Entry Suggestion Interaction](https://doi.org/10.1145/2858036.2858305)
  (Quinn & Zhai, CHI 2016) — always-on suggestions cut keystrokes and still
  slow people down because looking is not free. The ancestor of Tilde's
  attention-tax estimate.
- [Multi-line AI-assisted Code Authoring](https://arxiv.org/abs/2402.04141)
  — longer suggestions can save more input and also cost latency and visual
  stability. Read before H08 dynamic length; do not jump to whole-sentence
  ghosts because a long completion looks impressive offline.

## Engine techniques

- [Efficient Training of Language Models to Fill in the Middle](https://arxiv.org/abs/2207.14255)
  (Bavarian et al.) — the FIM training transform. No natural-language FIM
  model exists to download (verified 2026-08-15); this is the recipe if we
  ever build one for mid-text completion. `llama-server` already exposes
  `/infill`.
- [Fast Inference from Transformers via Speculative Decoding](https://arxiv.org/abs/2211.17192)
  (Leviathan et al.) and
  [llama.cpp speculative docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md)
  — draft-and-verify decoding; the prompt-lookup n-gram variant is a config
  flag on the bundled server and doubles as a personalization win because the
  user's own context self-repeats.
- [Improving Neural Language Models with a Continuous Cache](https://arxiv.org/abs/1612.04426)
  (Grave, Joulin & Usunier) — a cheap decaying pointer over recent tokens
  beats waiting for neural retraining. This is the prior for H10 (decayed
  recent cache) after personal experts are unlocked. Do not start it before
  Stage 3.

## Contributing an entry

Add a link plus one honest line on what it changes about how we build Tilde.
No copied text, no PDFs. If an entry inspires an experiment, run it through
the quiz or replay harness and record the measured outcome in
`docs/model-lessons.md`; entries that never produce a testable idea should be
pruned.
