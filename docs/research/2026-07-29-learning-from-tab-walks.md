# Learning from Tab-walks: the signal we were throwing away

2026-07-29. Owner's idea, and it is a better instrument than the one I was
about to build.

## The problem in one line

`accept_word` logged only the single word taken, so the offer it came from was
lost. Every Tab press produced one bit — "a word was accepted" — when it
actually carries a per-word verdict.

## Why the stopping point is worth so much

Take 4 words of an 8-word offer and you have not said "this suggestion was
bad". You have said: **right through word 4, wrong at word 5.** One press
labels every word in the sentence.

Measured over 620 reconstructed walks in existing capture:

| words taken | walks |
|---|---|
| 1 | **471** |
| 2 | 68 |
| 3 | 46 |
| 4 | 26 |
| 5 | 7 |
| 6 | 2 |

The overwhelming case is stopping immediately — and until now nothing recorded
*what was abandoned*. The longest walk observed was six words
("going to be 10 min late").

## How this is normally done

This is **implicit feedback**: never ask the writer to rate anything, measure
what they did. The signal hierarchy, weakest first:

1. shown vs not shown
2. accepted vs rejected ← what we had
3. **how much was accepted before stopping** ← what we now have

Tier 3 is what production completion systems (Gmail Smart Compose, GitHub
Copilot) learn from, and it enables the technique worth copying:
**truncation** — don't show words you aren't confident about. Users accept
short correct suggestions far more readily than long ones that are two-thirds
right, which the app's own numbers already shout: single words 25.4%,
phrases 2-4% (`2026-07-29-acceptance-vs-confidence.md`).

**The trap the literature is emphatic about:** model confidence and human
acceptance are different things. Confidently wrong is common, so a confidence
score must be *calibrated* against real behaviour before it is trusted as a
gate. Tab-walk stopping points are the ideal calibration set precisely because
they say where the sentence died, not merely that it did.

## What shipped

**`GhostUsageLog.Walk`** — every `accept_word` row now carries:

    offered         the full suggestion on screen when the walk began
    offered_words   how many words that was
    taken_words     how many are taken as of this press (1-based)
    walk_id         ties the presses of one walk together

`walk_id` matters: reassembling a chain from timestamp gaps is guesswork, and
the analysis that produced the table above had to do exactly that.

**`walk_stopped`** — a new event logged when a walk ends with words left on
the table. The accept rows say what was taken; this says what was *left*. A
walk that consumes the whole offer logs nothing, because nothing was rejected.
Emitted from `clearGhost`, which every abandonment path already funnels
through.

**Six tests** (`WalkLabelTests`) pinning the arithmetic: an off-by-one here
would mislabel every training row this produces. They cover the common
one-word stop, a mid-phrase stop naming the first wrong word, a completed walk
producing no failure point, punctuation and double spaces, and a counter that
cannot claim more words than were offered.

## What this unlocks next

1. **Per-word confidence, joined to per-word outcomes.** The server already
   returns a `logprob` for every generated token (verified against the live
   model). Group tokens into words, and each word gets both a predicted
   confidence and — via walks — an observed accept/abandon. That is a
   calibration table.
2. **Truncation.** If confidence reliably falls at the word walks stop on,
   cut the suggestion there instead of showing the rest.
3. **Preference pairs at word granularity** — a far sharper training signal
   than whole-suggestion accept/reject.

## Honest limitation

This changes only what is *recorded from here on*. Historical capture cannot
be back-filled — the offers were never written down. The 620 walks above were
reconstructed by chaining consecutive accepts within 8 seconds, which recovers
walk *length* but never what was on the table. **Every day this ships late is
a day of the best training data the app can produce, discarded.**

Live capture resumes when the owner is back at the Mac and this build is
deployed (`script/tilde_deploy.sh`).
