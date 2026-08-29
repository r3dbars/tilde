# Multiple Parallel Phrase Suggestions (Buschek, Zürn & Houben, CHI 2021)

**Source:** https://arxiv.org/abs/2101.09157
**License:** arXiv non-exclusive distribution license; CHI 2021 proceedings copy is separate.

## What it does (plain words)

A GPT-2 email editor showed 0, 1, 3, or 6 phrase ghosts at once. The paper asks whether extra choices help people invent wording (ideation) or just slow them down. It also splits native and non-native English writers.

## Method

Prestudy N=30 to tune the editor, then an online composition study N=156. People wrote emails under the four suggestion-count conditions. They logged accepts, edits, time, and how the text changed.

## Key findings

- More parallel phrases helped ideation and hurt efficiency.
- Non-native writers gained more from extra choices than native writers.
- More parallel suggestions raised the chance that *something* was accepted.
- Arnold's earlier split held: phrases read as "what to write," not "what I was about to type."

## What Tilde should take from it

Do not add a second ghost, a chip row, or a cycle-through-N-best key to "use the model more." Acceptance will go up and the owner will write more like the model. Tilde's product is one quiet inline span.

If Lab ever ranks multiple internal candidates, keep that ranking invisible. Show one. The rest can only inform agreement tests (H13/H14), which are locked.

Non-native benefit is real and is not the owner's daily-drive case. Do not generalize from that slice to production policy.

## Limits and caveats

GPT-2 web editor, not IMKit. Composition study, so content effects are the point — and those texts must never enter Tilde's Git. The efficiency cost is about reading six ghosts, which Tilde should never pay.
