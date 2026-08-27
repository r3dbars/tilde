# F03 — Extend the text-free Outcome Ledger

Status: PROPOSED
Experiment class: runtime
Owner: Tilde research program
Pre-registered: 2026-08-27T12:30:00Z

## Pre-registration

### Hypothesis

Extending the existing `LabOnlineExperimentEvent` with settled-display,
typed-through, 30-second and segment retention, and explicit missing-retention
reasons will make later live campaigns evidence-eligible for retained utility,
without storing writing and without creating a second telemetry store.

### Why this should work

The v2 online event already records display, accept, 5-second replacement,
next-action time, typing-speed bucket, and several integrity flags. That is
enough to subtract a quick undo. It is not enough to tell "Tabbed and kept"
from "Tabbed and rewrote before send," and it cannot mark "shown, not Tabbed,
but the next keys matched" as distinct from "ignored because they never
looked."

GitHub Copilot had to move from acceptance to retained characters after the
first proxy failed. Ziegler showed the first proxy tracks feeling. Roy and
Quinn showed an unused look is still a cost. Li and Feit showed people often
see the right suggestion and type it anyway. F03 is the instrument that lets
those facts become Tilde measurements instead of citations.

Mechanism: keep one schema, add horizons and missingness, reject any field
that can hold text. Coverage and missingness must be visible or later H05
will treat silence as zero correction.

### Control

`tilde-lab.online-event.v2` as defined in
`Sources/TildeLabKit/Models/LabOnlineExperiment.swift` at the commit that
implements this record's start. Known gaps versus the Stage 0 contract:

- replacement is only counted inside five seconds;
- no 30-second or segment-close retained-character fields;
- no missing-retention reason codes;
- `ignored` does not distinguish typed-through after a settled show from a
  ghost that never landed;
- no settled-visible duration, so a flicker accept can look like a read;
- eligible / generated / policy-hidden are only partly implied by `displayed`,
  `outcome`, and `guardReason`.

### Treatment

Extend the same event (new schema version, same store):

- eligible, generated, displayed, policy-hidden as explicit states;
- candidate source and length buckets (not the candidate text);
- outcomes: accepted-all, accepted-word, typed-through, dismissed, corrected,
  undone, hidden, unavailable (typed-through must not collapse into ignored);
- retained characters at 5s, 30s, and segment close (focus change, send/commit,
  or a privacy-safe inactivity boundary);
- missing-retention reasons so "not yet observed" cannot equal "zero kept";
- time to next authored action, generation, first stable word, and a
  settled-visible millisecond count;
- existing app category, register, boundary, typing-speed bucket, plus scene
  quality, freshness, recent-intervention count, and confidence-feature
  coverage already sketched in the roadmap.

The event remains local, deletable, aggregate-reportable, and schematically
incapable of prompt, candidate, screen, field, recipient, document, or
personal text. Do not add a parallel Outcome Ledger.

### Data and split

Deterministic evidence-infrastructure experiment. Fixtures must cover:

- accept then keep at all three horizons;
- accept then replace before 5s, before 30s, and before segment close;
- typed-through after a settled show;
- dismissed / hidden with next-key delay present or missing;
- flicker accept below the settled-visible floor;
- missing-retention at each horizon;
- privacy rejection if a text-bearing key is supplied;
- v2 events remaining readable.

No owner writing in Git. No model-quality comparison. No holdout.

### Primary metric

One hundred percent of newly encoded events that claim a retained-outcome
campaign can state, for each horizon, either a retained-character count or a
missingness reason, and never both as if they were the same fact.

### Supporting metrics

- v2 events still decode;
- typed-through distinct from ignored and from dismissed;
- flicker accepts do not increment a "read" counter;
- aggregate reports show coverage and missingness at 5s / 30s / segment;
- forbidden keys rejected;
- no second database or log format appears.

### Hard gates

- No prompt, candidate, screen, field, or personal text is representable.
- Production insertion path stays IMKit; this event does not write text.
- A missing horizon is never coerced to zero retained characters.
- Fast proof and the existing online-event validators stay green.
- Local deletion still deletes these events.

### Promotion rule

Support F03 only when the fixtures above pass, Lab and CLI can show coverage
and missingness, a live ingest path exists on the Mac without checking in
events, and Stage 0's "visible retained-outcome coverage" exit clause is
honestly satisfied. Then F04 may start. Live H01 may not start before that.

### Kill rule

Reject this design if retained characters require storing the accepted span, if
v2 must be silently rewritten, or if missingness cannot be distinguished from
zero. Redesign the event before any decision-grade live campaign.

### Known confounders

- Segment close is a policy (focus, send, idle). A bad boundary looks like
  retention or like churn.
- 30-second retention during a long pause is not the same as 30 seconds of
  continued writing.
- Type-through cannot be an exact string match in the event; it has to be a
  local, text-free judgment (for example, continued typing after a settled
  show without Tab or Escape). Document the rule in code, not in stored text.
- App category is coarse. Protected slices will be noisy until we have volume.
- The owner's awareness that logging exists can change behavior. Do not hide
  that the Outcome Ledger is on; do keep it deletable.

### Frozen provenance

- Git commit: pin at implementation start; this record timestamps the
  hypothesis before that commit exists
- Dirty state: this branch may be dirty relative to `main` until F03 lands
- Model revision and SHA-256: not applicable; instrument test
- Helper SHA-256: not applicable
- Runner SHA-256: captured by fixtures when implemented
- Suite and selection SHA-256: deterministic event fixtures
- Scoring SHA-256: not applicable; no model comparison
- Arm SHA-256 values: not applicable
- Invocation digest: captured by fixtures when implemented
- OS, hardware class, and power state: not required for decode fixtures;
  required for any live ingest proof

## Result

Status: not yet run

### Follow-up

If supported: F04 (freeze scoring cheats as tests), then close Qwen, then H01
as the first live scientific question with RNKS as the primary metric.
