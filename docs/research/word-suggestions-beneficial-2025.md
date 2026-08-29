# Are Word Suggestions Beneficial? (Roy, Casiez & Vogel, TOCHI 2025)

**Source:** https://doi.org/10.1145/3772716 (author copy: https://hal.science/hal-05426476)
**Also covers:** Roy, Berlioux, Casiez & Vogel, CHI 2021, https://doi.org/10.1145/3411764.3445725 — that study is Experiment 1 of this paper.
**License:** ACM author-posted version; link and attribute, do not copy the PDF into Git.

## What it does (plain words)

This is the cleanest controlled answer to whether word suggestions help people type. Three studies vary two things that earlier work mixed together: how accurate the suggestions are, and how fast the person can type without help. Experiment 1 uses desktop, tablet, and phone. Experiments 2 and 3 slow a physical keyboard on purpose so accuracy and typing speed can be crossed cleanly. They also compare a one-word inline ghost with a one-word suggestion bar.

## Method

Accuracy is not "the model is good." It is how often a *useful* suggestion appears, defined from keystroke-saving. Participants transcribe short phrases. Device type stands in for typing efficiency in Experiment 1 (36 people). Experiments 2 and 3 crowd-source 1,207 people and add a hold-down delay on every key so "slow typist" is an experimental factor, not a self-selected one. They measure suggestion use, keystroke saving, words per minute, and whether people find the ghosts distracting.

## Key findings

- Fast typists ignore suggestions even when the suggestions are excellent. Desktop use was near zero. At 0.9 accuracy, keystroke saving reached about 44% on phone and only about 15% on desktop.
- Experiment 1 desktop typists averaged 76.5 WPM. That is Tilde's world, not a phone keyboard.
- Suggestions only made people faster at the highest accuracy *and* the slowest typing. Satisfaction rose with accuracy even when speed did not.
- Inline ghosts saved about 4% more keystrokes than a bar (0.30 vs 0.26) and about 2 WPM (37.1 vs 34.9), and people rated them more distracting.
- Natural unaided speed predicted use better than device. A fast typist on a phone still skipped more than a slow typist on a desktop.

## What Tilde should take from it

Tilde is an inline desktop IME for a daily-driving owner who types well. This paper says the default should be quiet, not generous. A ghost that is merely "pretty good" will be ignored or will cost more than it saves.

This is the live-design brief for H01 and H04:

- keep the visible span short (the three-word quiz win already points the same way);
- suppress during fast bursts (H04);
- do not add a suggestion bar to "help more" — inline already saves a bit more and distracts more;
- do not treat rising satisfaction or rising Tab rate as proof the owner is faster.

The accuracy factor is also a warning for H06. A learned quiet gate has to condition on typing rhythm, not only on model confidence. A high-confidence ghost shown into a 120 ms inter-key burst is the desktop failure mode this paper measured.

## Limits and caveats

Transcription, not composition. Artificial key delays are not motor disability and are not real fatigue. Accuracy is scripted into the interface, not produced by Gemma. One-word ghosts are shorter than Tilde's current three-to-eight-word caps. None of this is IMKit, and none of it measures whether accepted text stays. Use it as a prior on *when people bother to look*, not as a live RNKS number.
