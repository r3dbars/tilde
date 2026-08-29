# Where the field stopped, and where Tilde can go

This is not a paper digest. It is the map of the hole the 2026-08-27
literature sweep found. The owner asked to push personal autocomplete
somewhere published systems have not gone. This note says what "new"
honestly means, so we do not confuse a bigger model with a new question.

## The honest timeline

There are two literatures. People mix them and then think the field is
moving.

**Shipped personal systems** peaked in 2018–2020:

- Gboard federated next-word (2018)
- Gmail Smart Compose (2019)
- n-gram interpolation with a global neural model (2020)

Those are the last papers that say: here is a real keyboard or mail
ghost, here is how we personalized it, here is a live metric. Google did
not publish the sequel. The product kept going. The method did not.

**Recent papers that look like progress** are mostly not personal
systems:

- Roy / TOCHI 2025 and Li & Feit 2025 are good HCI. They study *generic*
  word suggestions, often on transcription, often on phones. They are
  not on-device personal models and they do not use what is on screen.
- Copilot 2022–2025 is excellent metric work (Tab vs retained
  characters) on *code in an IDE*.
- Sequential autocomplete (2024) and Mozannar (2023) are display-policy
  papers on research UIs or Copilot logs.

So the owner's read is correct. The best *personal autocomplete
keyboard* writeups are about seven years old. The best *recent* papers
are either "do suggestions help a stranger copy a sentence?" or "did a
programmer keep the ghost in the file?"

Commercial local Mac ghosts exist now. None of them published a
measurement method. A product without a public ruler is not a research
program.

## What those papers never measured

Put the missing pieces on one line. No published system has all of
these, and most have none:

1. **System-wide desktop IME**, not Gmail-only and not an IDE plugin.
2. **On-device inference** with no user-derived network egress.
3. **Personal memory that never leaves the machine** (not federated
   weight uploads, not server-side sent-mail n-grams).
4. **On-screen context** as a first-class input, with fail-closed
   redaction and a real exclusion list.
5. **Retained characters** as the live headline, counted without storing
   the writing.
6. **Authorial voice** as a companion check, not a blog afterthought.
7. **A fast desktop typist** as the user, not a phone typist and not a
   1.5-billion-user average.

Roy's headline — desktop fast typists skip even accurate suggestions —
was measured on *generic* ghosts in a transcription box. Smart Compose
never answered the follow-up: do they still skip when the ghost is
their own phrasing, grounded in the thread on screen, hidden during a
burst, and scored by whether it stays?

That follow-up is the first new paper. It does not require a new model.
The scientific stance — objective, identification, why the controller
is the object to learn — is
[`scientific-program.md`](scientific-program.md).

## The claim we can uniquely test

> A quiet, personal, scene-aware inline ghost can pay for itself for a
> fast desktop typist if — and only if — we count kept characters and
> refuse to count a voice-flattening Tab as a win.

Google could not run that experiment in public. Their advantage was
data they would not share and a cloud they would not give up. Tilde's
advantage is the opposite: one daily-driving owner, a Lab that already
knows how to pre-register a campaign, and a privacy rule that *forces*
the interesting method (text-free outcomes).

N=1 is a feature if the protocol is honest. Decision-grade single-user
science with frozen controls, paired comparisons, and published
aggregate decisions is rarer than another 50-person transcription
study. Do not dress it up as a population result. Do publish the
method so someone else can run it on their machine without sending us
their mail.

## How we collaborate

Split the work the same way the catalog already splits research:

- **GitHub (this repo):** questions, protocols, sanitized tests,
  digests, ledger entries after a result exists. No private text.
- **Local Mac:** campaigns, dogfood, Screen Memory, Personal History,
  the text-free event log. That is the only place the new evidence can
  appear.

The owner runs the live question. The agent keeps the ruler honest,
writes the next protocol before the result is known, and refuses to
advance a locked stage because a paper or a feeling arrived.

Order does not change because the hole is exciting:

1. Finish the ruler (F03, then F04). Without kept-character horizons,
   we would be publishing 2019 Google metrics.
2. Close Qwen or kill it. One generator while we test policy.
3. Ask the new question on real writing: does a short personal/scene
   ghost get used by a fast typist, and does it stay?
4. Only then learn a quiet gate from retained outcomes.

## What would count as "gone somewhere new"

A result we can put in the Learning Ledger, with no owner text, that
says one of:

- supported: a fast typist kept more characters from a quiet
  personal/scene ghost than from the generic production cap;
- rejected: they still skipped, so desktop-skip is not a generic-model
  artifact;
- inconclusive: the ruler was not yet good enough, and we say so.

Any of those three is new. A bigger GGUF is not.

## What this note is not

It is not a license to start Future Lattice, private LoRA,
whole-sentence ghosts, or a third testing brand. It is not a claim
that Tilde has already beaten Smart Compose. It is the reason the
reading list exists: so we steal the old playbooks and spend our
unique shots on the questions those playbooks left on the table.
