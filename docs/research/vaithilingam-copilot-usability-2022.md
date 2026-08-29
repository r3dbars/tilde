# Expectation vs experience with Copilot (Vaithilingam, Zhang & Glassman, CHI 2022)

**Source:** https://doi.org/10.1145/3491102.3501873
**Related:** Prather et al., "It's Weird That It Knows What I Want," TOCHI 2023, https://doi.org/10.1145/3617367
**License:** ACM. Link and attribute.

## What it does (plain words)

A usability study of Copilot on Python tasks. People were optimistic, then spent a lot of time reading and repairing ghosts. The tool did not reliably beat writing the function yourself. Novice follow-ups showed the same: students accepted and rejected, and sometimes stalled.

## Method

Lab programming tasks with and without Copilot, plus interviews. Metrics mixed completion, correctness, and qualitative codes (over-reliance, confusion, repair).

## Key findings

- Reading and fixing a ghost can erase the typing it saved.
- Users over-trust fluent wrong code.
- A second suggestion pane adds choice overload (Barke's exploration mode).
- Mozannar's later observation fits here: in one study programmers spent more time evaluating suggestions than writing.

## What Tilde should take from it

Wrong fluent prose is worse than wrong code in one way: the owner may send it. Factuality and commitment errors are already hard gates. This paper is why those gates exist even when RNKS looks good.

Repair time belongs in the live score. A 5-second delete is F03. A 30-second rewrite is why RNKS-30s exists.

Do not add an N-best panel because Copilot has one. Vaithilingam and Barke both saw that panel hurt acceleration.

## Limits and caveats

Small-N lab, Python functions, 2021–2022 Copilot. Not owner dogfood. The "time spent evaluating" number is IDE-specific. Tilde's evaluate-cost has to be inferred from next-key delay, not from eye tracking or a think-aloud that would record private text.
