# A Cost-Benefit Study of Text Entry Suggestion Interaction (Quinn & Zhai, CHI 2016)

**Source:** https://doi.org/10.1145/2858036.2858305
**License:** ACM CHI 2016; Google also hosts a research page. Link and attribute.

## What it does (plain words)

Quinn and Zhai asked how eager a keyboard should be to show word completions. They named that eagerness *assertiveness* and tested three settings: always show (extraverted), never show (introverted), and show only when a probability clears a threshold (ambiverted). The question is the ancestor of Tilde's quiet gate: is a suggestion worth the look?

## Method

Seventeen people transcribed phrases on an iPod Touch. Input was forced error-free so the study isolated attending and tapping suggestions, not typing mistakes. Completions came from the Android dictionary. Extraverted refreshed the top three after every letter. Ambiverted showed them only when a score passed 0.1. Introverted showed none. They measured characters per second, taps per character, and NASA-TLX.

## Key findings

- Introverted was fastest: 3.09 characters per second versus 2.81 ambiverted and 2.66 extraverted.
- Extraverted saved the most taps (9.44% realized versus 4.66% ambiverted) and still lost on time.
- People rated no-suggestions as more physically demanding and more effortful. They disliked the fastest condition.
- Always-on suggestions offered 17.59% potential tap savings; the thresholded interface offered 9.44%. People used only part of either offer.

## What Tilde should take from it

Showing more saves keystrokes and still slows people down, because looking is not free. A confidence threshold is faster than always-on, and silence is faster still. That is the product rule in numbers: help more than you interrupt, and do not confuse tap savings with speed.

Two Tilde consequences:

- H04 and H06 should start from "show less than we generate," not from "use every good candidate."
- Subjective ease will lie. Owners can prefer a noisier ghost because it feels less like work, the same way these subjects preferred the slower keyboards. RNKS and interruption counts have to overrule that feeling.

Their utility sketch is the right cheap rule before any learned gate: do not spend a glance on the last character of a word the owner can type faster than they can read.

## Limits and caveats

Mobile tap keyboard, copying task, perfect input, word completion only, 17 people. Ambiverted used a fixed 0.1 threshold, not a calibrated acceptance model. Tilde's accept key is Tab in an IME, not a tap on a bar. The direction transfers; the CPS numbers do not.
