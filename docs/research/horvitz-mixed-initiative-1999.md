# Principles of Mixed-Initiative User Interfaces (Horvitz, CHI 1999)

**Source:** https://doi.org/10.1145/302979.303030 (author PDF: https://interruptions.net/literature/Horvitz-CHI99-p159-horvitz.pdf)
**License:** ACM CHI 1999; author-posted copy is commonly used. Link and attribute.

## What it does (plain words)

Horvitz's answer to the 1990s fight between "just give me direct manipulation" and "let an agent do it." The useful claim: an assistant should act only when the expected benefit beats the expected cost of being wrong, and the user must be able to ignore, correct, or invoke the help. LookOut, a meeting-from-email prototype, is the running example.

## Method

This is a principles paper, not a typing study. It lists design factors (about a dozen) for coupling automation with direct manipulation: consider uncertainty about goals, value the user's attention, time the intervention, make poor guesses cheap to dismiss, let the user refine, and prefer socially appropriate timing. LookOut used learned intent plus a decision about whether to open the calendar now, later, or not at all.

## Key findings

- Bad guesses are not a UX footnote. They are the main risk of initiative.
- Timing is a first-class decision, separate from "is the inference correct?"
- Immediate action is justified only when delay is costly. Otherwise negotiate or wait.
- Users should be able to invoke the same help on demand so the agent can stay quiet.

## What Tilde should take from it

This is the oldest clean statement of Tilde's Control Brain. H06/H07 are Horvitz's value-of-information test applied to a ghost: show only when the expected retained characters beat the expected look-cost of a wrong span.

Practical translations that do not need a learned model yet:

- dismiss must be cheaper than accept (Escape / type-through already; keep it that way);
- do not auto-insert (Tilde already uses marked text, not silent mutation);
- H04 is timing, not confidence;
- a "suggest now" invoke is a later escape hatch if silence becomes too aggressive — not a current experiment.

Mozannar 2023 is this paper with Copilot telemetry. Read Horvitz for the decision rule; read Mozannar for the cascade.

## Limits and caveats

Email-to-calendar agents, 1999, no ghost text, no keystroke metrics. The math is decision theory under uncertainty, not a trained classifier Tilde can paste in. Do not build a general "agent." Apply the cost/benefit test to one inline span.
