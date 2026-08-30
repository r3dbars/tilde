# Q13 — Visible-word cap 3 versus 8 on the tuned filter stack

Status: REGISTERED
Experiment class: display-policy
Owner: Tilde research program
Pre-registered: 2026-08-30T16:20:00Z

## Pre-registration

### Hypothesis

Owner hypothesis under test: raising the visible cap from 3 to 8 words on
the Q12-nominated echo-24-grounded arm increases retained useful value
(rescuing facts the 3-word window truncates) by more than it adds junk.
Prior evidence points the other way (offline replay: caps 4–6 added wrong
displays faster than useful ones, with the old filters), so this is a
genuine two-sided question on the new filter stack.

### Control

The Q12 echo-24-grounded nominated arm exactly (maximumVisibleWords 3).

### Treatment

The identical arm with maximumVisibleWords 8 (and the corresponding
default visible-character allowance for 8 words). One mechanism.

### Data, runtime, provenance

Certified V2 development roots, full suite, seeds 17/41/73, repetitions 1,
8×2 workers, AC, caffeinate, same generator chain as Q11/Q12. Registered
from a clean tree before the run.

### Primary metric

Bad-when-shown paired difference and useful-display count, as Q12.

### Supporting metrics

Net keystrokes saved; per-category slices with special attention to
reply.commit.delivery (the truncation-loss category) and
reply.clarify.item / stress.sensitive-near-miss (the categories wider
windows damaged in replay); silence slices.

### Promotion rule

Cap-8 nominates only if net keystrokes saved rises AND bad-when-shown
does not rise by more than 2 points AND no silence slice regresses.

### Kill rule

Kill cap-8 if bad-when-shown rises more than 2 points, any silence slice
regresses, or the truncation-rescue does not appear in
reply.commit.delivery.

### Known confounders

Offline, synthetic, development partition; visible-length feel (flicker,
reading cost, interruption) is invisible to this instrument and belongs
to live H01. A cap-8 offline win here would still need H01's live answer
before any product change.

## Result

Status: REJECTED (cap-8 killed by the registered rule)
Campaign: 2C57D9F3, clean tree, 3,600/3,600 evaluations.

- cap-3 (control): 766 useful / 169 bad / bad-when-shown 18.1% / 20% NKS
- cap-8: 396 useful / 379 bad / bad-when-shown 48.9% / 8% NKS

The kill rule fired on every clause: bad-when-shown rose 30.8 points
(limit 2), useful halved, and net keystrokes saved fell 20% to 8%. The
truncation-rescue the hypothesis predicted did not survive contact: what
the 3-word window truncates, the 8-word window shows — and the shown tail
is where the generation goes wrong. On this stack, the short cap is not a
compromise; it is the mechanism that keeps only the reliable head of each
suggestion visible.

### Follow-up

The offline prior for H01 now strongly favors 3 visible words on the
tuned stack. H01's live question (feel, interruption, retention on real
typing) remains open and is unchanged in the queue.
