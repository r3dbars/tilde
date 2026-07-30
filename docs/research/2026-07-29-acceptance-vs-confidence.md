# Why the accept rate is stuck, and why the obvious fix doesn't work

2026-07-29. Prompted by the owner's target: "I want 8 out of 10 suggestions
accepted, is that naive?" Answered from capture — 4,690 shown ghosts joined to
the confidence score they were generated with.

## The question behind the question

Acceptance is a ratio, so it moves two ways: make suggestions better, or show
fewer. The second is the cheap lever, and the assumption was that a confidence
threshold would deliver it — speak only when sure, and the rate climbs.

**That assumption is wrong in a specific and useful way.**

## Confidence barely predicts acceptance

    correlation(confidence, accepted) = +0.061      ← essentially nothing
    correlation(length,     accepted) = -0.265      ← the real signal

Thresholding on confidence alone peaks at ~14.7% (at p≥0.40) while discarding
84% of suggestions, and then *falls back* to 5.9% at p≥0.80. A gate that gets
worse as the model gets more certain is not a gate.

| gate | shown | accept | volume kept |
|---|---|---|---|
| none | 4,690 | 8.8% | 100% |
| p≥0.20 | 1,808 | 12.8% | 39% |
| p≥0.40 | 770 | **14.7%** | 16% |
| p≥0.60 | 379 | 8.7% | 8% |
| p≥0.80 | 153 | 5.9% | 3% |

## Length is what actually predicts it

| ghost length | shown | accepted |
|---|---|---|
| 1 word | 1,246 | **25.4%** |
| 2-3 words | 969 | 4.0% |
| 4-6 words | 1,728 | 2.1% |
| 7+ words | 747 | 2.8% |

A single word is accepted **six times more often** than a two-word phrase.
This is the measured explanation for the long-standing observation that 97% of
accepts are single-word Tab-walks: it is the only thing that reliably works.

## The mechanism — and this is the load-bearing part

Split confidence *within* each length class and the contradiction resolves:

| gate | 1 word | 2-3 words | 4+ words |
|---|---|---|---|
| none | 25.4% | 4.0% | 2.3% |
| p≥0.20 | 43.0% | 5.8% | 3.5% |
| p≥0.40 | **47.6%** | 5.9% | 3.7% |
| p≥0.60 | 37.7% | 0.0% | 4.0% |

**Confidence is an excellent gate for single words and almost useless for
phrases.** The reason is that `p_first` is the model's confidence in the
*first token*. For a one-word ghost the first token IS the answer, so the score
means what we want it to mean. For an eight-word phrase it says nothing about
words two through eight — we have been gating a sentence on how sure the model
was about its opening syllable.

The apparent "collapse at high confidence" in the aggregate table is this
composition effect, not a real inversion: high-`p_first` phrases are confident
openings to unwanted sentences.

## What this means for the 8/10 target

Not naive as an ambition — but it is two different targets wearing one number.

- **Single words: already halfway there.** Gating on confidence takes them from
  25% to ~48% today, with no model change. That is a shipped-product-quality
  number (GitHub Copilot lands ~25-30% in code, where syntax constrains the
  next token far more than prose does).
- **Phrases: no gate exists.** At 2-4% regardless of threshold, the model
  cannot currently tell when its own sentence is right. This is the whole-thought
  product — the actual vision — and it is the part with no instrument.

## The missing instrument

The next build is **a whole-phrase confidence score**: the sequence's own
likelihood (mean or minimum per-token log-prob across the generated span,
length-normalised), not the first token's. Without it there is nothing to
threshold a phrase on, and every phrase-quality effort is flying blind — the
manners batch's length cap works precisely because it is a crude proxy for
"we cannot tell if long ones are good, so don't offer them."

Two consequences worth stating plainly:

1. **An immediate win is available** — gate single-word ghosts at p≥0.40 and
   that class roughly doubles its accept rate. Cheap, measurable, no new model.
2. **The matchmaker's real value may be measurement, not generation.** A
   retrieved precedent that closely matches the current moment is independent
   evidence that a phrase is plausible — a second opinion the model's own
   probabilities cannot provide.

## Caveats

- 4,690 of 22,230 shown ghosts joined to a confidence score (the join requires
  the sample's suggestion prefix to appear in the logged ghost, same app,
  within 120s). Baseline acceptance on the matched subset is 8.8% vs ~7.5%
  overall, so the subset skews slightly favourable.
- Buckets below ~150 samples are noisy; the p≥0.60 phrase rows especially.
- Capture spans 2026-07-24..28, one owner, mid-project. Register mix is
  Claude/Slack/Codex heavy.

Reproduce: `script/acceptance_vs_confidence.py`.
