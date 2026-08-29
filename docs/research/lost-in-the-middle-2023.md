# Lost in the Middle (Liu, Lin, Hewitt, et al., 2023/2024)

**Source:** https://arxiv.org/abs/2307.03172
**License:** arXiv; later TACL version exists.

## What it does (plain words)

Long-context models do not use the middle of the prompt as well as the start or the end. If the fact you need is buried, accuracy drops even when the window can hold it.

## Method

Controlled multi-document question answering and key-value retrieval. They move the relevant needle through the prompt and plot accuracy against position. Models with long advertised windows still show a U-shaped use of context.

## Key findings

- Position bias is large. Beginning and end beat the middle.
- A bigger window is not the same as a used window.
- Retrieval that puts the needed span at the edges beats stuffing more text.

## What Tilde should take from it

Screen Memory and document context are a packing problem. Tilde already bounds what it sends. This paper says *order* matters: recent typed prefix and the highest-value scene span should sit at the edges, not in a muddled middle.

H03 (context-quality routing) should include packing, not only source choice. Fresh Accessibility text that is stuffed behind a long stale OCR dump can lose to a shorter, correctly ordered prompt.

Do not "just raise context length" as a product bet. That is a locked generator change and this paper says it may not help.

## Limits and caveats

QA and retrieval probes, not inline completion. Gemma 4 E2B's exact position curve is unmeasured. Do not log packed prompts. Test packing with synthetic fixtures in Lab, never with owner screen text in Git.
