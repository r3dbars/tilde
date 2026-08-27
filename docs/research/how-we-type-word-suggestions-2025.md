# How We Type with Word Suggestions (Li & Feit, 2025)

**Source:** https://doi.org/10.1145/3749520
**License:** ACM; link and attribute.

## What it does (plain words)

People typed on their own phones while eye tracking recorded every look at the suggestion bar. The headline is not that suggestions are inaccurate. It is that people *look* far more often than they *take*, and often look at the right word and then type it anyway.

## Method

Eye-tracking plus screen recording during transcription and composition on personal devices. They split looks into takes and failed checks, then asked whether the algorithm had even offered the right word.

## Key findings

- 68% of suggestion-bar checks did not end in a selection.
- Only about half of those failed checks were the model's fault.
- In 43.6% of failed checks, the person had fixated the correct suggestion and still typed the word by hand.
- Checking has a measurable time cost. Misaligned checking made people slower even though they "use suggestions every day."

## What Tilde should take from it

Ignored ghosts are not free. Sequential autocomplete measured a 50 ms penalty for a wrong glance in a lab UI. This paper measures the everyday version: habitual checking that does not pay.

H04 and a future quiet gate should treat *looks without accepts* as a loss if we can ever see them. Tilde will not ship eye tracking. The on-device proxy is type-through after a settled ghost, or a next-key delay after display. Count those in F03. Do not celebrate a high show rate.

The 43.6% "saw it, typed it anyway" slice is why Tab is incomplete. Some value is real and still never accepted. RNKS will miss that help; a type-through-after-show event is the honest label.

## Limits and caveats

Mobile bar, not desktop inline ghost. Gaze on a phone is not gaze on IMKit marked text. Composition plus transcription, still not owner Mail. Do not add Accessibility-based gaze or screenshot logging to "copy this study." Use the behavioral proxies we can already record without pixels.
