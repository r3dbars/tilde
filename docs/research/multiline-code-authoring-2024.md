# Multi-line AI-assisted Code Authoring (Dunay, Cheng, Tait, et al., FSE 2024)

**Source:** https://arxiv.org/abs/2402.04141
**License:** arXiv non-exclusive distribution license.

## What it does (plain words)

Meta's CodeCompose already showed single-line ghosts to tens of thousands of engineers. This paper is the production postmortem of turning that into multi-line ghosts: how they stopped the ghost from shoving existing code around, how they cut latency, and what the A/B tests did to keystrokes saved.

## Method

They treat suggestions as a funnel: displayed, accepted if shown longer than 750 ms, characters accepted, keystrokes saved (accepted characters / characters typed). Latency is a guardrail because a slow ghost is dismissed by the next key. Multi-line used a scope-based trigger so a long ghost only appears when the cursor is in a place where extra lines will not rewrite trusted code. Model hosting (Flash Attention, continuous batching, persistent KV cache) cut multi-line latency about 2.5×. Rollouts were double-blind A/B tests. The model is a fine-tuned CodeLlama-7B with fill-in-the-middle.

## Key findings

- Multi-line was 16% of displayed suggestions and 42% of accepted characters.
- Keystrokes saved went from 9% (single-line) to 17% with multi-line added.
- Less than 1% of engineers opted out after the jarring-effect fix.
- They only counted an accept if the ghost had been visible for 750 ms. That drops accidental Tabs on a flicker.

## What Tilde should take from it

Longer suggestions can pay, and they also move the user's existing text. That is why H08 (dynamic length) is locked until a length policy is live-proven and visual rewrite is a hard gate.

Transfer now, without implementing multi-line:

- Count "shown long enough to have been read" as a separate event from "flashed." A 750 ms floor is a concrete F03/F04 regression idea: do not credit accepts on ghosts that never settled.
- Keystrokes saved can double while display rate falls. Do not kill a quieter policy because it shows less.
- FIM is how they avoid suffix damage. Tilde already treats suffix damage as a hard gate; this is the industrial reason that gate exists.
- Hosting tricks (batching across users) do not transfer. Persistent KV cache and "cancel on the next key" do.

Do not read 9% → 17% as a license for whole-sentence ghosts in Mail. That lift is code, at Meta, after they spent the latency budget. H08 stays parked.

## Limits and caveats

Industrial code, not prose. The model is 7B and cloud-hosted. "Keystrokes saved" here is accepted characters over typed characters, not RNKS, and they do not report 30-second retention. Opt-out rate is not the same as retained utility. The jarring-effect algorithm is language-scope for code, not IMKit marked text.
