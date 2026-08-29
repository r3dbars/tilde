# When to Show a Suggestion? Integrating Human Feedback in AI-Assisted Programming (Mozannar, Bansal, Fourney & Horvitz, 2023/2024)

**Source:** https://arxiv.org/abs/2306.04930 (AAAI 2024)
**License:** arXiv non-exclusive distribution license; AAAI proceedings copy is a separate publication.

## What it does (plain words)

This is the Microsoft/MIT paper that treats ghost-text autocomplete as a *display* problem, not a generation problem. Using 168k Copilot suggestions from 535 programmers, they ask: when is showing a suggestion worth the time it costs to read and reject? They build a two-stage gate. First, look only at the current context and decide whether generation is even worth starting. If that is unclear, generate the suggestion and then decide whether to show it. The point is to hide suggestions that would have been rejected anyway, and to skip some model calls entirely.

## Method

They define suggestion utility as the change in time-to-finish if a suggestion is shown versus hidden. That true utility is not measurable, so they use two proxies they can estimate: probability of acceptance (higher is better) and generation latency (higher is worse). At each typing pause, a cascade of acceptance predictors runs:

1. Stage 1 uses only the prompt/context. If acceptance looks hopeless, do not generate.
2. Stage 2 uses context plus the generated suggestion. If acceptance still looks low, hide it.

The cascade is tuned so a hidden or skipped suggestion would have been rejected with a chosen high probability (they discuss 0.95–0.99). They also show that adding the writer's unobserved state (what they were doing, not just what they typed) improves the predictor, and that ranking candidates by acceptance probability alone prefers short partial completions over complete useful ones.

## Key findings

- Retrospective on 168k suggestions: hide 25% of shown suggestions while estimating that 95% of those hidden ones would have been rejected; skip generating 13% of them.
- Hypothesized acceptance-rate lift from that hiding: about 7.2%.
- Optimizing acceptance as a reward makes suggestions shorter and less complete. Acceptance is a useful display signal and a bad generation objective.
- A weaker form of this gate later appeared in Copilot. The paper's claim is that the *idea* transfers, not that Tilde should copy their model.

## What Tilde should take from it

This is the strongest published argument for Tilde's Stage 2 Control Brain, and for why Stage 0 has to exist first. The paper only works because they already had a complete accept/reject log. Tilde does not yet have the equivalent retained-outcome loop, so a learned quiet gate is not the next experiment.

The transferable design is the cascade, not the Copilot telemetry:

- a cheap pre-inference skip (Tilde's H07);
- a post-generation show/hide gate (Tilde's H06);
- a guarantee that hidden suggestions are mostly ones the user would have rejected;
- never train the generator to maximize Tab presses.

It also warns that "more accepted" can mean "shorter and emptier." That is why Tilde's live headline has to be retained characters (RNKS), not acceptance rate. The three-word offline win already showed the same trap: short caps can look safer by speaking less.

Do not import their latency math as a Mac SLA. Copilot is a networked IDE plugin. Tilde is a local IME. Use the *structure*: skip, then hide, then measure retained value.

## Limits and caveats

This is code completion inside an IDE, not macOS prose in every app. Programmers pause more, accept longer spans, and have a different interruption cost than someone writing a chat reply. The evaluation is retrospective, not a live A/B. The 7.2% acceptance lift is hypothesized from hidden rejections, not measured retained utility. Their telemetry includes prompts and suggestion text; Tilde's online event must stay text-free. And their "latent state" study used extra instrumentation Tilde will not copy.
