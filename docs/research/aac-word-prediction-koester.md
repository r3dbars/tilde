# Word prediction's cognitive cost (Koester & Levine, 1994–1996, and the AAC line)

**Sources:**
- Modeling the speed of text entry with a word prediction interface, IEEE Trans. Rehab. Eng. 1994, https://doi.org/10.1109/86.331567
- Effect of a word prediction feature on user performance, AAC 1996, https://doi.org/10.1080/07434619612331277608
**See also:** Anson et al., Assistive Technology 2006; Venkatagiri; Copestake 1997; Lesher, Moulton & Higginbotham 2002; Trnka & McCoy 2008.
**License:** IEEE / Taylor & Francis; link and attribute.

## What it does (plain words)

This is the research ancestor of "suggestions must help more than they interrupt." AAC word prediction was built to save keystrokes for people who type with a mouthstick or a switch. Koester and Levine measured the time to press a key and the time to search a prediction list, then showed that the search often ate the savings.

## Method

Fourteen people transcribed text for seven sessions, with and without word prediction. Eight were able-bodied and used a mouthstick. Six had high-level spinal cord injuries and used their usual keyboard access. The authors split performance into keypress time and list-search time and put those parameters into a two-parameter model of word-entry time (about 16% average model error).

## Key findings

- Word prediction *decreased* text-generation rate for the spinal-cord-injured group and only modestly helped the mouthstick group.
- Fewer selections were required, and each selection took longer.
- Everyone's keypress time got slower once a prediction list was on screen — the list taxed the keystroke, not only the look.
- SCI participants had much slower list-search times, possibly because they were already experts at letters-only typing.
- Later AAC work kept finding the same shape: keystroke saving is real; speed is not automatic. Anson 2006 reported mixed or negative rate effects for on-screen keyboards. Copestake estimated a practical ceiling around 50–60% keystroke saving. Lesher's human oracles averaged about 59%.

## What Tilde should take from it

Keystrokes saved is a necessary metric and an insufficient one. Tilde already knew this (RNKS, attention tax). These papers are the oldest quantitative version of that rule, and they add a mechanism: a visible suggestion slows the *next ordinary key*, even when the user does not take the suggestion.

That is a live H04 / F03 design constraint. A ghost that is ignored is not free. The 136-million-keystroke study gives the rhythm; this line gives the tax. Do not add a candidate list beside the marked text. One inline ghost is already the expensive thing.

The modeling move is still useful: estimate look-cost and key-cost separately, then ask whether a candidate's saved characters clear both. Sequential autocomplete (2024) is the modern version of the same ledger.

## Limits and caveats

This is AAC, list UIs, and transcription, often with access methods Tilde will never use. Absolute rates do not transfer to a fast Mac typist. The lesson that transfers is the cost accounting, not the user population.
