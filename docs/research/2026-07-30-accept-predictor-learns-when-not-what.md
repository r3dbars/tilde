# The accept predictor learns *when*, not *what*

2026-07-30. Built to shrink the feedback loop: acceptance is the metric that
matters most and the one no quiz can measure, because it needs a human
reacting in the moment. If a model could predict acceptance from capture, a
new build could be scored offline in minutes instead of a week of typing.

Verdict: **half-works, and the half that works is a different thing than the
one I set out to build.** Saved as evidence, not adopted.

## What it does

AUC **0.798** on held-out sessions (0.50 = coin flip). But the weights say
what it actually learned:

    app_InlineGhost   -3.64      app_atlas       -3.56
    app_xos           -2.43      hour_morning    +1.56
    hour_afternoon    +1.11      src_model       +1.03

Almost all of its power is **context** — which app, what time — and almost
none is **content**. It has essentially no opinion about whether the suggested
words are good. It learned "Atlas and Zoom are hopeless, mornings are good,
the model beats the dictionary."

So it is not a *"would you accept this text?"* judge. It is a
*"should I speak right now?"* judge — the measured version of the mid-line
editing guard, and a real selectivity lever. Just not the one advertised.

## Two things that stop it being usable today

**The probabilities are wrong.** Where it predicts 35-60%, the true rate is
2.6%. Ranking is sound; the numbers are not. An artifact of class-balancing
during training, fixable with a calibration pass that has not been done. Safe
as "rank these and suppress the bottom"; unsafe as "this is 40% likely".

**The sample is thin.** 17,001 resolved rows, but only **135 sessions**, 27 of
them held out. Sessions are the real unit here, and 27 is not many.

## The labeling trap, worth remembering

Two honest measurements of "acceptance by length" point in opposite
directions, and both are correct:

| question | 1 word | 4+ words |
|---|---|---|
| of what you TOOK, how long was it? | 25.4% | ~2% |
| of what was OFFERED, did you take *any* of it? | 5.5% | ~9% |

A long offer that yields a single Tab counts as a hit under the second
definition and a miss under the first. **Neither is wrong; they answer
different questions.** Any acceptance number is meaningless without saying
which one it is — and the first labeling attempt here silently mixed them,
producing a 23.6% positive rate against a true 4.4%.

Two labeling bugs preceded the working version, both caught by sanity-checking
against the known accept rate rather than by inspection:

1. Matching shown→outcome on ghost *text* let one accepted "the" mark every
   "the" ever shown as accepted (23.6% vs true 4.4%).
2. Stopping the search at the next `shown` event hid two thirds of accepts,
   because a Tab-walk re-shows the remainder between presses (1.6% vs 4.4%).

**Rule: when a labeling produces a rate that disagrees with a number you
already trust, the labeling is wrong.** It was, twice.

## Status

`script/accept_predictor.py`, reproducible. Not wired into anything, not used
by any gate. Revisit after a full week of ordinary typing, and calibrate
before trusting any probability it prints.

The finding worth keeping even if the tool is discarded: **the app already has
a measurable signal for when to stay quiet, independent of getting smarter.**
Browsers, meeting apps and weekday afternoons are known-bad terrain, and the
keyboard could act on that today.
