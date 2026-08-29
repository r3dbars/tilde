# Predicting interruptibility (Fogarty, Hudson, and the CMU sensors line)

**Source:** Fogarty, Hudson, Atkeson, et al., "Predicting Human Interruptibility with Sensors," TOCHI / CHI mid-2000s (https://doi.org/10.1145/1089733.1089735 is a common TOCHI entry)
**Related:** Iqbal & Bailey on breakpoint detection; Horvitz BusyBody.
**License:** ACM. Link and attribute.

## What it does (plain words)

Can a computer tell when a person is interruptible without asking? These systems used cheap sensors — typing, mouse, talking, calendar — to guess the cost of an interruption. Typing was one of the strongest "do not bother me" signals.

## Method

Office workers, optional self-reports of interruptibility, sensor logs. Models classified high vs low cost-of-interruption. Later work added task breakpoints (just finished a sentence, just sent mail) as safer moments.

## Key findings

- Motor activity, especially typing, predicts "not now."
- Breakpoints between subtasks are safer than mid-burst.
- People are bad at self-scheduling interruptions; a mediator that waits for a pause beats a random ping.

## What Tilde should take from it

H04 is this paper without extra sensors. Tilde already sees key timing in the IME. Fast IKI and rollover (Dhakal) are the interruptibility features. Do not add a microphone, camera, or Accessibility-wide activity spy to "do Fogarty properly."

Release-at-word-boundary and release-after-pause are breakpoint policies. Start there, deterministically.

## Limits and caveats

Office notifications, not ghost text. Ground truth was often a self-report or a secondary-task reaction time. Tilde must not record "what app besides the focused field" beyond the exclusion list it already needs for Screen Memory.
