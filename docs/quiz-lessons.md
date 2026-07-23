# Quiz lessons — what moves ghost quality (and what doesn't)

The "quiz" (owner's word, not "eval") is `script/golden_eval.py`: it replays real
human-finished messages against the live ghost socket, cuts each at a word
boundary, and scores the ghost's guess against what the author actually wrote
next. Metrics: **spoke rate**, **ExactMatch@1/2/3**, **keystrokes saved**,
**latency p50/p95**. Corpora are built by `script/fetch_eval_sets.py` and live
outside the repo under `~/.cache/steadytype-eval/` (never committed).

The rule this unlocks: **change one knob → re-run the same frozen questions →
keep it only if the number moves.** Tuning stopped being vibes.

## Measurement trust

- **The measurement has ~zero noise at 2,000 questions.** Two identical baseline
  controls, run at the start and end of a 23-version sweep, scored *byte-identical*
  (17.2% EM@1 / 0.96 keystrokes / 144ms). So any delta below is real, not luck.
- Greedy decoding (temperature 0) makes the quiz deterministic per corpus.

## First ground-truth scores (Discord chat, Gemma E4B q4_0, 2026-07-22/23)

Baseline: **EM@1 17.2%**, keystrokes/spoken 0.96, spoke 95.6%, p50 ~140ms.
(Without screen context it was 14.5% — see the OCR result below.)

## Screen context (OCR) is worth a lot

Feeding the conversation being replied to (as OCR would) lifted **EM@1 14.5% →
17.2% (+19% relative)** and keystrokes 0.8 → 1.0 (+29%) for **+5ms**. Grounding
in what's on screen is one of the biggest levers we have. But **how much**
context barely matters: 1 prior turn scored the same as 5 — so send less, cheaper.

## The 23-version sweep (all vs the 17.2% baseline)

### What HELPED
- **Authentic example messages beat polished hand-written ones: +1.3 EM@1 AND
  ~35ms faster.** The few-shot "scaffold" examples in the prompt teach the model
  the room's voice. Replacing hand-written (too-polished) examples with real,
  short, casual mined Discord ones was the single best knob — better *and* faster
  (shorter prompt = less to process). This confirmed the miss-gallery theory: the
  model was imitating the tidy examples and sounding more polished than real chat.
- **Short/few authentic examples win.** very-short and short scaffolds (+1.3) beat
  long (+1.1) and were much faster; a *single* example hurt (−1.6). Sweet spot:
  ~3–6 short authentic examples.
- **Speaker-labeling the context** ("them: …") gave a small real +0.4.

### What DID NOT MATTER (flat vs baseline — real null results)
- **Suggestion length (token budget 8/12/20/28):** zero effect on first-word
  accuracy. Expected — EM@1 is about the first word.
- **Context depth (1/2/5 prior turns):** flat. More conversation ≠ better.
- **The register system (chat vs email vs prose voice):** forcing the *wrong*
  scaffold voice on Discord text scored *identical* to the right one. The
  hand-written scaffolds barely carry signal — which is *why* swapping in
  authentic ones helped. OPEN QUESTION: does the chat/email/prose switch earn its
  complexity? Re-test once the quiz is multi-register (below).

### What HURT
- **Temperature > 0:** 0.15 neutral, 0.3 −0.6. Greedy confirmed best for exact-match.
- **Model E2B (the <24GB / M1 tier): −8.1 (9.2% vs 17.2%).** Nearly half the
  accuracy for ~half the latency (85ms). WARNING for the M1 MacBook plan: the
  low-RAM tier is a steep quality cliff, not a gentle trade. Revisit tiering
  before the M1 test.

## Biggest untested lever

**Confidence gating.** The system speaks 95% of the time but is right ~18% —
most ghosts shown are wrong at word one, and the misses are overwhelmingly
plausible-but-different phrasings, not garbage. llama.cpp can report per-token
logprobs; a threshold that stays silent below X% confidence should trade
spoke-rate for precision and make the ghost feel *trustworthy*. Plot the whole
curve against the quiz and pick the point where it feels right. Not yet built.

## Playbook

1. One knob per run, same frozen questions, keystrokes-saved as the north star.
2. Triage a knob on a 300-question subset (~3 min); confirm keepers on the full
   2,000 (~13 min).
3. Read the **miss gallery** (`--verbose K`): the *shape* of failures picks the
   next knob (polished-voice → scaffold; cut-off → budget; parrots screen →
   context framing; plausible-but-different → confidence gate or personalization).
4. Bookend long sweeps with baseline controls to prove the noise floor.

## Machinery

- `script/golden_eval.py` — quiz harness. Flags: `--context off|prior|live`,
  `--context-turns N`, `--context-style plain|labeled`, `--force-app` (register
  ablation), `--limit N`, `--json`, `--config-only`, `--selftest`.
- `script/fetch_eval_sets.py` — corpus sifter (discord implemented; email/prose
  loaders being added for a diverse quiz).
- `script/mine_scaffolds.py` — mine casual scaffold candidates from the corpus.
- `script/tuning_sweep.py` — relaunch-per-version driver with launch-time env
  overrides (`STEADYTYPE_SCAFFOLD_<REG>_FILE`, `STEADYTYPE_TOKEN_BUDGET`,
  `STEADYTYPE_TEMPERATURE`, `STEADYTYPE_MODEL`), a config-echo verification guard
  (never quiz a stale build), a streaming results log, and a ranked league table.
- Stability: `signal(SIGPIPE, SIG_IGN)` + `SO_NOSIGPIPE` — peer-vanish socket
  writes were silently killing the app under sustained quiz load (no crash report).
