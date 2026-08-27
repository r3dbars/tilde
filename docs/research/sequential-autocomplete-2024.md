# Sequential Decision-Making for Inline Text Autocomplete (Chitnis, Yang & Geramifard, 2024)

**Source:** https://arxiv.org/abs/2403.15502
**License:** arXiv non-exclusive distribution license.

## What it does (plain words)

This Meta/UT Austin paper asks whether inline autocomplete should be a confidence threshold ("show if the model is sure") or a sequential policy that also prices the cost of making the user look. A language model proposes candidates. A second decision layer chooses show-one or wait. The reward is text-entry speed after subtracting the cost of reading a suggestion. They prove that looking ahead can beat a myopic threshold in a toy setting, then find that this does **not** make idealized users faster on real text. A nine-person typing study then measures how expensive a suggestion actually is to look at.

## Method

State is the typed prefix plus *k* language-model candidates and their probabilities. Actions are "show candidate *i*" or "wait." An idealized user always accepts an exact remaining-prefix match and never typos. Reward is zero if nothing is shown; positive if the user accepts; negative if they ignore. Two cost knobs: a per-character reading cost and a fixed gaze-switch cost. They compare a far-sighted policy (discount 1) to a myopic one (discount 0), run simulated RL, and then have nine people type known sentences while suggestions appear.

## Key findings

- In a restricted two-word analysis, a far-sighted policy waits at the last shared letter where a myopic policy would guess and often be wrong. Sequential reasoning *can* be better than a threshold. That is a theoretical existence proof, not a product win.
- On an idealized user plus a real language model, RL did not beat a fixed confidence threshold on typing speed.
- User study (N=9, transcription, keyboard): the cost of looking at a suggestion did **not** grow with suggestion length. It *did* depend on correctness: about 10 ms when the suggestion matched what they were typing, about 50 ms when it did not. (The abstract rounds the match cost to 9 ms.)
- They found no evidence that recent suggestion volume changed acceptance rate.
- Recommendation from the authors: stop chasing speed for perfect users. Study messy real users and experience, not WPM alone.

## What Tilde should take from it

This is the paper that justifies Tilde's "help more than interrupt" rule with a number: a wrong ghost is about five times more expensive to glance at than a right one, and length is not the main reading cost. That supports:

- a quiet gate that hides likely-wrong suggestions even if they are short (H06);
- flow-aware cooldowns after dismissals (H04);
- *not* starting with reinforcement learning (Stage 2 comes after deterministic policy, and this paper failed to beat a threshold on speed anyway).

It also supports keeping length and interruption as separate measurements. Their study says length is cheap to *read*. Tilde's own Certified V2 campaign says a three-word *visible* cap still raised human-acceptable output and net savings versus eight words. Those are not contradictions: reading cost and wrong-continuation tail are different failures. Measure both.

Do not stand up an RL show/hide agent because this paper formulated one. Their own result is that the simple threshold was enough for idealized speed.

## Limits and caveats

Nine people copying known sentences is not owner dogfood and is not composition. The idealized user never rejects a correct suggestion and never makes typos, so the simulation is optimistic for acceptance and silent about correction. Reward is speed, which they themselves say is the wrong sole objective. The 10 ms / 50 ms glance costs are laboratory glances at a research UI, not IMKit ghost text in Mail or Messages. And "length does not change glance cost" does not mean long suggestions are free: Tilde still pays latency, visual rewrite risk, and post-accept editing on long tails.
