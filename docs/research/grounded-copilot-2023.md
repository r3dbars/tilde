# Grounded Copilot: How Programmers Interact with Code-Generating Models (Barke, James & Polikarpova, OOPSLA 2023)

**Source:** https://arxiv.org/abs/2206.15000
**License:** arXiv; PACMPL OOPSLA 2023 version is the archival copy.

## What it does (plain words)

Twenty programmers used Copilot on real-ish tasks in several languages. The authors built a grounded theory of the interaction. Use split into two modes. In *acceleration*, the person already knows the next edit and wants the ghost to type it. In *exploration*, they do not know the next edit and treat the ghost as a menu of ideas.

## Method

Grounded theory: watch, code the tape, change the next task to test the emerging categories. Tasks included existing codebases, not only blank-file puzzles. They later checked the same patterns on public livestreams.

## Key findings

- Acceleration wants small, quickly checkable ghosts. People pattern-match and Tab.
- Exploration wants longer ghosts and the extra suggestion pane, then edits heavily.
- Over-reliance showed up: some people made less progress when they waited for the model.
- Choosing among many suggestions added load. Novice follow-up work (Prather et al.) saw the same split.

## What Tilde should take from it

Tilde is an acceleration product. The owner is mid-sentence in Mail or Messages, not hunting for an API. Design for acceleration: short, high-precision, easy to ignore. Exploration features (multiple long drafts, "surprise me") are a different product and a locked moonshot.

H04 is the acceleration rule: when the owner is already firing keys, they are in acceleration or they are ignoring you. Do not switch to exploration length because the model is excited.

Wrong-mode errors are expensive. An exploration-sized ghost during acceleration is the 50 ms bad glance from the sequential-autocomplete paper, scaled up.

## Limits and caveats

Code, 20 people, Copilot's UI (including a multi-suggestion panel Tilde will not have). Qualitative, not an A/B. Do not take "programmers enjoyed exploring" as a reason to lengthen Tilde's ghost.
