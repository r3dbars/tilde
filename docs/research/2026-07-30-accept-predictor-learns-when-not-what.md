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

**The probabilities were wrong — now fixed, and the fix exposed the real
limit.** The first version predicted 35-60% where the true rate was 2.6%, an
artifact of the class-balancing needed for a 7%-positive dataset. A Platt
calibration fitted on a held-out slice cut calibration error from **0.312 to
0.008** (40x).

But honest probabilities collapse into a narrow band: every held-out row now
scores between 0% and 5%. Nothing earns a confident yes. That follows from
what it knows — app and hour can prove a moment is hopeless but never that one
is promising. The old scores looked decisive only because balancing inflated
them.

**So it is a reliable "don't bother" detector, not a "go for it" detector.**
It can say Atlas at 3pm is dead ground; it cannot say this suggestion is good.
The original hope — an offline judge for scoring new models — is closed off by
this, which is worth knowing after an afternoon rather than a week.

(AUC moved 0.798 -> 0.778 when the calibration slice was carved out of
training. At 135 sessions that difference is probably noise; it is the honest
cost of measuring calibration on data the model never saw.)

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

## Postscript: v2 read the words, and the comparison settled it

Rebuilt with 11 content features (fragments, echoes of context, stopword
runs, dangling endings, openers) and trained three variants on the identical
session split:

| variant | AUC |
|---|---|
| context only (app + hour) | **0.813** |
| content only (the words) | 0.678 |
| both | 0.778 |

The words carry real signal (0.678 is far from coin-flip) but the situation
carries more, and combining them helps nothing at this data size.

**The explanation is survivor bias, and it reframes the whole question:**
every row in this dataset already passed the app's ~15-filter cleaner before
being shown. Fragments, echoes and junk were killed before they could be
measured — the cleaner already spent the content signal upstream. **The
cleaner IS the content model.** Among suggestions good enough to survive it,
what remains to predict is mostly whether the moment was right.

So the division of labour is already correct in the product: filters judge
words before display; this predictor judges moments. The gap identified
earlier stands unchanged — for PHRASES the cleaner has no confidence
instrument (p_first scores one token), and that, not another accept
predictor, is still the missing piece.

One content detail worth keeping: suggestions that start lowercase are far
more accepted (+1.97) — mid-sentence continuations beat sentence starters.
The "I" opener also scored positive here (+1.51), which cuts against the
flagged opener bias; at 27 test sessions, treat both as leads, not findings.

