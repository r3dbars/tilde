# Typing Behavior is About More than Speed (Lehmann, Kornecki, Buschek & Feit, PACMHCI 2023)

**Source:** https://doi.org/10.1145/3604276
**License:** ACM PACMHCI; link and attribute.

## What it does (plain words)

Mobile word suggestions often slow people down, and people still use them. This paper separates "I am a slow typist" from "suggestions made me slower," then lists eight reasons someone taps a suggestion anyway: complete the word, fix a typo, take the next word, capitalize, contract, and so on.

## Method

Logs from 15,162 mobile typists. They control for unaided speed, which earlier studies mixed into the treatment. They predict suggestion selection from word length, frequency, and strategy, and sketch a model that could rerank suggestions for those strategies.

## Key findings

- Slower typists use suggestions more, and using them still slows those typists down.
- Speed is not the only job a suggestion does. Correction and capitalization are real jobs.
- Word length and frequency, plus the current strategy, predict takes.
- A system that only maximizes keystroke saving will miss the strategies people actually have.

## What Tilde should take from it

Quinn, Roy, and Koester already said suggestions can lose on speed and win on feeling. This paper names the non-speed jobs. Tilde should not grow a correction bar or an auto-capitalizer to chase them. It should recognize that some Tabs are "fix the last word" or "give me the long rare word," not "I am going faster."

For F03: tag accepts by cheap, text-free context if possible (mid-word vs word-boundary vs after a backspace). Do not store the word. A mid-word accept after backspaces is a different success than a next-phrase ghost.

Do not use this as a reason to show more often to slow moments only. Their slow typists were still slowed. Accuracy still has to be high (Roy/TOCHI).

## Limits and caveats

Mobile, suggestion bar, huge vendor-style log, not desktop IME. Eight strategies are mobile-bar strategies. Tilde has no tap targets for capitalization. The selection model is a ranking idea for a bar UI we will not ship.
