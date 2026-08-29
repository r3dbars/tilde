# Coordinating the interruption of people (McFarlane 1999/2002)

**Sources:**
- Comparison of Four Primary Methods for Coordinating the Interruption of People in HCI, HCI Journal 2002, https://doi.org/10.1207/s15327051hci1701_2
- McFarlane & Latorella, The Scope and Importance of Human Interruption in HCI Design, 2002
**License:** Taylor & Francis / Lawrence Erlbaum; author copies exist at interruptions.net. Link and attribute.

## What it does (plain words)

Interruptions are not only "on" or "off." McFarlane compared four ways to deliver them: immediate, negotiated (user picks when), mediated (a helper picks a moment), and scheduled. Negotiation was best overall unless a few milliseconds of delay were truly dangerous.

## Method

Thirty-six people did an abstract dual-task. The interrupting task arrived under one of the four coordination methods. They measured errors, time, and how well people got back to the first task (resumption).

## Key findings

- Immediate interruption is fast to deliver and expensive to recover from.
- Negotiation has overhead, and still wins when the user can finish a subtask first.
- Scheduled interruptions are predictable and inflexible.
- Mediation is only as good as the mediator's guess about a safe moment.
- Warnings before an interruption help. So do clear ways to resume.

## What Tilde should take from it

A ghost is an interruption of typing. Tilde already negotiates: the owner can Tab, Escape, or type through. H04 is mediated interruption — wait for a pause or a word boundary. Do not become immediate (flash a rewrite on every key) and do not become scheduled (suggest every N seconds).

Resumption lag is the missing live metric beside RNKS. If a dismissed ghost delays the next key, that is an interruption cost even when zero characters were accepted. F03 should leave room for a next-key delay after hide/dismiss, without storing text.

## Limits and caveats

Not typing, not suggestions, laboratory dual-task. The ranking (negotiate > mediate > schedule > immediate for most work) is a prior, not a measured Tilde result. Ghost text is milder than a modal dialog; do not import their absolute times.
