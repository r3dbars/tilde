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
- [Dasher](http://www.dasher.org.uk/) (MacKay) — text entry as navigation of
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

## Contributing an entry

Add a link plus one honest line on what it changes about how we build Tilde.
No copied text, no PDFs. If an entry inspires an experiment, run it through
the quiz or replay harness and record the measured outcome in
`docs/model-lessons.md`; entries that never produce a testable idea should be
pruned.
