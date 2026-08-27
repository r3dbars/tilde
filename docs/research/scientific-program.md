# How to think about Tilde as an AI research program

The hole in the literature is real. Filling it is not "try more models."
This note is the scientific stance: what problem we are solving, why the
usual ML objective is the wrong one, what would count as a contribution,
and how to identify a cause on one writer's machine.

It does not move the executable queue. The Learning Ledger still decides
what may run.

## The problem, stated as research

Tilde is **assistive decoding under a hard privacy constraint**.

At each keystroke the system sees a prefix, a (possibly missing or wrong)
screen span, local personal statistics, and recent timing. The writer has
an unobserved intent: the text they will want to have written. The system
must choose:

- skip inference,
- generate and hide,
- or show a span of length *k*.

The true utility is not next-token likelihood. It is the characters the
writer keeps, minus the cost of looking, waiting, correcting, and being
steered into someone else's phrasing — subject to hard gates (privacy,
suffix damage, Secure Event Input, excluded apps).

Write it once so we do not drift back to perplexity:

> Maximize expected retained useful characters at a declared horizon,
> minus look-cost, latency-cost, and voice-divergence, subject to
> fail-closed safety and a ban on storing the writing.

Smart Compose already knew log-perplexity moves less than ExactMatch.
Ziegler showed acceptance predicts how helped people *feel*. GitHub 2025
showed acceptance still rewards junk people delete. Those are three
measurements of the same fact: **the training / logging proxy is not the
utility.** The scientific job is to get the utility closer to the writing
outcome without taking the writing off the machine.

## Why this is not a 2019 paper with a 2026 model

A researcher who swapped Gemma for Smart Compose's LSTM would still be
doing Chen et al. 2019: cloud or local, the *question* is "can a neural
LM propose phrases, gated by confidence, blended with an n-gram?"

That question is answered. The unanswered questions are structural.

**Reward misspecification.** The field optimized PPL, then ExactMatch /
CTR, then accept rate, then retained-in-file for *code*. Nobody has a
privacy-projected retained-character reward for *personal prose* at
multiple horizons, with type-through and next-key delay as first-class
losses. Building that reward is instrument science. Without it every
later fit is unidentifiable.

**The object to learn is the controller, not the generator.** Mozannar
treated display as a decision. They had Copilot logs and an acceptance
proxy. We have a stricter reward (retention) and a stricter observation
(no text). Sample efficiency and privacy both say: freeze the generator,
learn a small policy from outcomes. That is the same move robotics made
when perception was expensive to retrain. H16 (a Tilde-native generator
objective) stays a moonshot because you cannot credit a new net until
the reward is real.

**Roy estimated a slice, not a law.** TOCHI 2025 shows

`use ≈ f(scripted_accuracy, unaided_speed)`

with personal fit and scene fit held at zero, on transcription. The
structural hypothesis is

`use ≈ g(expected RNKS, look-cost, personal_fit, scene_fit, flow)`.

If *g* is still flat in speed when personal_fit and scene_fit are high,
Roy's skip result is a human fact and Tilde should be almost silent on
a fast desktop. If *g* rises, the skip result was a *generic-suggestion*
artifact. That interaction is the first result the literature cannot
already quote. It does not need a new GGUF. It does need F03, then a
frozen generator, then one treatment at a time.

**Privacy is an information bottleneck, not only an ethic.** The
forbidden channel (raw text in logs, Git, or the network) forces a
scientific claim: *the policy-relevant sufficient statistics of writing
are lower-dimensional than the writing.* Candidates: counts, decaying
caches, retrieval keys, and text-free events (shown, hidden, accepted,
typed-through, dismissed, retained at *h*). If those suffice for a
controller that beats a fixed gate on RNKS, we have learned something
about what personal autocomplete actually needs. If they do not, that
is also a result — and it would argue, later and in isolation, for a
harder personal expert, not for silently shipping LoRA.

## Architecture as a hypothesis

Two timescales, one frozen world model:

| Layer | What it is | What it may learn from | When |
| --- | --- | --- | --- |
| Generator | Pinned Gemma 4 E2B | Nothing from the owner | Frozen except the open Qwen close |
| Lexical memory | Counts, cache, exact phrases | Local accepted writing, user-controlled | Stage 3, locked |
| Controller | Show / hide / skip / length | Text-free outcomes | Stage 2, after the ruler and cheap bets |
| Context packer | What to put at the prompt edges | Source quality, not extra tokens | H03, locked until F03 |

This is a claim, not a slogan: **most of the remaining loss is decision
and context, not next-token capacity.** We already have a directional
Lab signal that three visible words beat eight on the quiz. That is
evidence for the claim. It is not yet a live retained-character result.

## Identification (how not to fool ourselves)

Lab already encodes the identification strategy. Name it as science:

1. **One causal question per campaign.** One experiment class. Otherwise
   model quality masquerades as policy, or scene quality masquerades as
   length.
2. **Same test for control and treatment.** Same suite, split, prompt,
   scorer, helper, power state class.
3. **Freeze the generator while testing policy.** Reverse only inside an
   isolated preview with its own ID.
4. **Pre-register the horizon and the kill rule** before looking.
5. **N-of-1 is a design, not an apology.** Interleaved paired
   comparisons, app/register slices, and a worst protected slice beat a
   50-person transcription mean that never saw this writer's mail.
6. **Do not promote on a proxy the hypothesis says is biased.** Tab
   rate, satisfaction, and PPL stay diagnostics.

Threats we must write down every time:

- **Intent confounding.** Composition is not transcription. A ghost can
  change what the owner meant to write (Arnold). RNKS without a voice
  check will call that a win.
- **Scene confounding.** Fluent wrong-window text looks like a better
  model (H03).
- **Survival bias.** Counting only accepted ghosts ignores type-through
  after a correct show (Li & Feit).
- **Flicker accepts.** Credit only ghosts that were visible long enough
  to have been read (CodeCompose's 750 ms floor is the prior).
- **Non-stationarity.** The owner adapts. Chronological splits, not
  i.i.d. row shuffles.
- **Missingness.** If F03 coverage is sparse, H05 must return
  inconclusive, not "retention does not help."

## What a contribution would look like

We do not claim the owner's coefficients generalize. We claim these
objects do:

1. **A privacy-projected utility** (RNKS at 5s / 30s / segment, plus
   type-through and next-key delay, minus hard-gate failures).
2. **An n-of-1 causal method** other people can run on their machine
   without sending anyone their writing.
3. **An interaction result:** whether personal fit and scene grounding
   attenuate the fast-typist skip.

That is enough for a real paper later. It is not a paper now. The
instrument is unfinished (F03/F04). Publishing a story before the ruler
exists is how this field stayed on CTR for seven years.

Venue-shaped, so we do not wander:

- The *method and live result* is CHI / TOCHI (intervention, cost,
  agency).
- The *reward and off-policy comparison* (H05) is closer to ACL or a
  workshop on human-LM interaction.
- A *new generator objective* (H16) is ML, and it is locked until the
  reward exists. Training first is how you overfit a lie.

## What I will do, thinking like a researcher

- Argue from mechanisms and identification, not from vendor blogs.
- Prefer a smaller model of the *decision* to a larger model of the
  *token*.
- Treat rejected and inconclusive as first-class outcomes.
- Refuse to start a locked stage because the hypothesis is pretty.
- Write the protocol before the number exists.

What I will not do: stand up another bake-off, treat Tab as ground
truth, or call a reading-list sweep a scientific result. The sweep
found the hole. The science starts when a pre-registered campaign
fills it or fails to.

How we work as colleagues — teaching, session shape, what "push the
field" means — is [`lab-partnership.md`](lab-partnership.md). Every try,
learn, and fail is appended to [`lab-log.md`](lab-log.md). The Mac
handoff for live ingest is [`next-on-device.md`](next-on-device.md).
The first timestamped instrument question is
[`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md).
