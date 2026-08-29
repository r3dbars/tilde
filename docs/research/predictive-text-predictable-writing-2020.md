# Predictive Text Encourages Predictable Writing (Arnold, Chauncey & Gajos, IUI 2020)

**Source:** https://www.eecs.harvard.edu/~kgajos/papers/2020/arnold20predictive.pdf (also https://doi.org/10.1145/3377325.3377523)
**Related:** Arnold, Gajos & Kalai, UIST 2016, [On Suggesting Phrases vs. Predicting Words](https://eecs.harvard.edu/~kgajos/papers/2016/arnold16suggesting.pdf) — phrases were read as *what to say*; single words were read as *what I was about to type*.
**License:** ACM author-posted PDFs on the authors' site; link and attribute.

## What it does (plain words)

Most suggestion papers ask whether people type faster. This one asks whether the suggestions change the writing. People captioned photos with always-on predictions, confidence-gated predictions, or no predictions. Captions written with suggestions were shorter and used fewer words the system had not predicted.

## Method

Within-subjects, 109 people, 1,308 captions. The keyboard offered next-word predictions. One condition never showed them, one always did, and one hid low-confidence ones. Content metrics were built so process differences (how they typed) would not automatically look like content differences (what they wrote). They also recorded typing speed.

## Key findings

- Suggestions made captions about one word shorter and cut unpredictable words by about one word.
- Speed rose, with less help for faster typists — the same pattern as the later TOCHI paper.
- Hiding low-confidence suggestions reduced predictable wording relative to always-on.
- The 2016 phrase study: multi-word ghosts were treated as ideas for content and wording. Single words were treated as predictions of the next keystrokes.

## What Tilde should take from it

A Tilde win that flattens the owner's voice is a product failure even if keystrokes fall. Keep an authorial-agency check beside RNKS. That is already in the roadmap; this paper is why.

Practical consequences:

- Short, high-confidence ghosts (H01) are not only a speed bet. They are also less likely to be read as "write this instead."
- Always-on is the condition that pushed writing toward the model's prior. Confidence gating is not only an interruption control (H06/H07); it is a voice control.
- Do not add a second or third parallel phrase (Buschek 2021) to "give the owner choices." Multiple phrases increase ideation *and* steer content. Tilde is a quiet IME, not a co-writer.

## Limits and caveats

Photo captions are not Mail or Messages. The model is a generic predictor, not a personal history blend. They did not measure whether the owner later disliked the more generic wording. Tilde cannot log the words themselves; any agency check has to be a local, deletable, text-free proxy (for example, unusual-token rate hashed on device) or a blinded owner review that never enters Git.
