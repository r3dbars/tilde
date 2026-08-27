# Evaluating Word Prediction: Framing Keystroke Savings (Trnka & McCoy, ACL 2008)

**Source:** https://aclanthology.org/P08-2066/
**Related:** Trnka, Yarrington & McCoy, "The Keystroke Savings Limit in Word Prediction for AAC"
**License:** ACL Anthology; typically Creative Commons. Link the official page.

## What it does (plain words)

Everyone in word prediction reports "keystroke savings," and the number is easy to game. Trnka and McCoy show the measurement traps, then put two gold standards around the score so a 50% can be read as "near the ceiling" or "lots of headroom."

## Method

Keystroke savings is the percent reduction in keys versus letter-by-letter entry. They compute two ceilings on Switchboard-style text: a *theoretical limit* (perfect model, earliest possible prediction) and a *vocabulary limit* (perfect on any word seen in training; letter-by-letter on the rest). They compare those ceilings to a real 5-prediction system.

## Key findings

- Actual savings with 5 predictions: 58.7%.
- Vocabulary limit: 77.6%. Theoretical limit: 78.4%.
- Out-of-vocabulary rate is the wrong diagnostic. Translate OOV into lost keystroke savings instead.
- You cannot reach 100%. A typical UI still needs a first letter and a select key, which is why one theoretical setup sat near 58% if one character must be typed.
- Copestake's Shannon-based practical ceiling (50–60%) and Lesher's human-oracle ~59% sit in the same band. Language itself, not only the model, caps the metric.

## What Tilde should take from it

Net Keystrokes Saved needs a ceiling, or a 3-point quiz lift looks larger than it is. Report NKS against a frozen "perfect short cap" and a "vocabulary-of-this-suite" ceiling the way Trnka framed KS. That is a GitHub-reusable F04-style scoring note, not a new model.

Also: do not chase OOV as a Personal History headline. Ask how many retained characters the missing names and project words would have saved. That is the H11 / H12 question, later.

Interface assumptions change the ceiling. Tab-to-accept with no first-letter requirement has a different maximum than AAC list selection. State the UI when we quote NKS.

## Limits and caveats

AAC / Switchboard, 5-best list, not inline ghosts, not composition, not retention. The 78% ceiling is not Tilde's product target. Tilde's live headline is retained characters after interruption cost, which this paper does not measure.
