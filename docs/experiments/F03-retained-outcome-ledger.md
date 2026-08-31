# F03 — Extend the text-free Outcome Ledger

Status: IMPLEMENTING
Experiment class: runtime
Owner: Tilde research program
Pre-registered: 2026-08-27T12:30:00Z
Protocol amended before a decisive run: 2026-08-30T23:45:49Z

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
will treat unavailable retention as zero correction.

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
- the broader schema can encode eligible / generated / policy-hidden states,
  but the live IME lifecycle begins only after `.shown` and therefore cannot
  observe upstream silence with this event.

### Treatment

Extend the same event (new schema version, same store). The original schema
target included states for later campaigns, while the amended decisive F03
claim below is explicitly limited to shown opportunities:

- generated, displayed, and policy-hidden as explicit schema states; the live
  F03 producer emits only generated-and-displayed opportunities;
- candidate source and length buckets (not the candidate text);
- outcomes: accepted-all, accepted-word, typed-through, dismissed, corrected,
  undone, hidden, unavailable (typed-through must not collapse into ignored);
  hidden and unavailable remain schema/fixture coverage, not live F03 coverage;
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

One hundred percent of newly encoded shown events that claim a retained-outcome
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
- A decisive fresh file contains only the current v3 event schema; reports
  expose v2/v3 counts instead of hiding legacy rows in a total.
- Production insertion path stays IMKit; this event does not write text.
- A missing horizon is never coerced to zero retained characters.
- Retention is counted only at the original accepted insertion range. A
  duplicate word elsewhere in the bounded field cannot receive credit; if the
  original range has rolled out of the in-memory snapshot, the horizon is
  explicitly missing.
- Fast proof and the existing online-event validators stay green.
- Local deletion still deletes these events.

### Protocol amendment — 2026-08-30, before the decisive live run

Static lifecycle tracing and hostile closeout fixtures found several gaps after the
original registration but before any eligible live result. This dated
amendment narrows and strengthens the protocol; it does not rewrite the earlier
diagnostic files into evidence.

- **Observable scope:** F03 measures retention only for ghosts that reached the
  IME's `.shown` effect. It does not measure eligible keystrokes, skipped
  inference, runtime-unavailable requests, filtering, cooldown suppression, or
  useful missed opportunities. Those require the separately planned
  aggregate-only request lifecycle before H04; they are not F03 promotion
  criteria.
- **Write completeness:** the current wipe generation reports aggregate
  attempted, written, and dropped event writes. A decisive file requires
  `dropped == 0`, `attempted == written`, and `written ==` the exact full-file
  row count after a terminal IME flush acknowledgement. The final event must be
  no later than that acknowledgement. Closeout advances the generation before
  taking the authoritative old-generation counter snapshot and requires the
  same accounting and flush values again at the report's atomic commit gate.
- **Run identity:** before ordinary typing, the local owner-only receipt freezes
  the exact clean commit, Git tree, canonical clean-commit content-manifest
  SHA-256, sealed runner SHA-256, fixed invocation profile, and a v2
  Apple/Xcode/Swift/SDK identity over the signed Xcode seal and exact SwiftPM,
  Swift driver, compiler, linker, libtool, archiver, and SDK inputs. Both signed
  plists must independently exact-match every receipt-linked field, including
  runner and toolchain identity; the receipt also binds the approved
  helper-input SHA-256 and team, signed app/IME/helper and plist hashes, final
  signing team, installed model identity, environment, rotation timestamp, and
  wipe generation. The Qwen 9B preview model remains
  exactly 5,629,109,312
  bytes with SHA-256
  `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`.
  Toolchain capture rejects tools outside the selected Xcode bundle and pins
  its platform Applications directory and bundle inode across compiler calls.
- **Terminal closeout:** closeout holds the same owner-only maintenance lock as
  rotation and binds that lock plus the Outcome Ledger walk to one held,
  repeatedly revalidated support-directory identity. It requires the exact
  preview processes stopped, re-verifies the
  installed identity against the receipt, and rejects a generation, row count,
  digest, or flush snapshot that does not describe the complete file. An
  eligible closeout advances to an unused generation while holding the ledger
  locks, renames the sealed file to `events.closed-<runID>.jsonl`, and publishes
  the new report before allowing any next-generation writer to continue. A
  failed publication restores the old generation and event name or fails
  closed for manual recovery; it cannot publish false eligible evidence.
- **Publication boundary:** closeout creates one aggregate-only, path-free
  `tilde-lab.f03-closeout.v2` report only after the generation and event-file
  seal. Its no-replace rename is the definitive success boundary: every
  fallible evidence gate runs before visibility, and later diagnostic/durability
  probes cannot turn a visible eligible file into an ambiguous thrown failure.
  Closeout refuses to overwrite or remove an earlier published report. The
  receipt, events, diary, preferences, and local paths never enter Git.
  A failed post-rename durability or final-path check preserves the sealed
  generation but returns the explicit
  `terminal-publication-indeterminate` blocker, never an eligible verdict.

### Promotion rule

Support F03 only when the fixtures above pass, Lab and CLI can show coverage
and missingness, a live ingest path exists on the Mac without checking in
events, and Stage 0's "visible retained-outcome coverage" exit clause is
honestly satisfied. F04 is already a completed foundation. Live H01 may not
start before F03 and the rest of the Stage 0 exit gate are honestly closed.

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
- The exact-offset watch is deliberately conservative when a length-changing
  edit occurs before the accepted span: the span may score zero or missing even
  if it shifted intact. This avoids inflating utility from an unrelated copy.
  Deletion followed by an identical retype at the same offset between samples
  remains indistinguishable without retaining an edit stream, which F03 does
  not do.

### Frozen provenance for deterministic fixtures

- Git commit: implementation started from
  `3c34990a657acf391a566b7d983997865ae58b11` (lab-log save; this record
  timestamps the hypothesis before that work)
- Dirty state: this branch may be dirty relative to `main` until F03 lands
- Model revision and SHA-256: not applicable to deterministic fixtures
- Helper SHA-256: not applicable to deterministic fixtures
- Runner SHA-256: fixture source is bound by the tested commit
- Suite and selection SHA-256: deterministic event fixtures
- Scoring SHA-256: not applicable; no model comparison
- Arm SHA-256 values: not applicable
- Invocation digest: captured by fixtures when implemented
- OS, hardware class, and power state: not required for decode fixtures;
  required for any live ingest proof

The amended live-closeout provenance is frozen in the pre-outcome local receipt
described above. Deterministic fixture provenance cannot substitute for it.

## Result

Status: not yet supported

The v3 event, XOR horizons, typed-through, flicker floor, privacy allowlist,
v2 decode, and aggregate coverage fields are implemented with fixtures. The
Mac-side producer is now wired: IME writes text-free counts next to a local
word diary and Delete Personalization Data wipes both. Generic
`ingest-events --instrument` remains useful for diagnostics, but it is
explicitly ineligible to close F03. The receipt-bound `f03-closeout` command is
the only decision-grade aggregate path.

An earlier 2026-08-30 diagnostic snapshot recorded at research commit
`78df853f` contained 1,364 rows spanning pre-fix history and two
monotonic-retention violations. Its inferred post-install slice contained 575
events, including 39 accepts and 225 typed-through outcomes, with zero
duplicate, XOR, domain, or monotonic violations. Accepted-horizon coverage in
that slice was 34/39 at five seconds, 12/39 at 30 seconds, and 39/39 at segment
close; the missing observations were explicit rather than coerced to zero.

This does not support F03. The slice boundary is inferred from install timing,
the installed build has no sealed source revision in the event provenance, and
the complete count file still contains the two earlier violations. A clean,
provenance-bearing full-file run is still required by the promotion rule.

A distinct later 2026-08-30 snapshot recorded at research commit `d3bc71d5`
examined the then-active `Tilde 9B Preview` build-2918 file in an isolated Lab
database. All 374 v3 rows decoded and ingested: 6 accepted-all, 35
accepted-word, 148 typed-through, and 185 ignored. There were zero malformed
lines, unknown or raw-text keys, duplicate IDs, domain violations, cross-field
violations, or monotonic-retention violations. Correctly using accepted spans
as the retention denominator gives 31 observed / 10 explicit missing
observations at five seconds, 17 / 24 at 30 seconds, and 41 / 0 at segment
close. The aggregate net retained counts were 217, 11, and 62 respectively.
The separate word diary failed closed at count ingest as required. This is a
different diagnostic snapshot from the 1,364-row file; their counts must never
be combined or treated as one campaign.

That clean structure is still not decision-grade provenance. The signed
preview bundle is build 2918, but neither the installed binaries nor the event
file seals a source commit or a rotation run record. Build number and hashes
cannot reconstruct that missing link after the fact, so F03 remains
**IMPLEMENTING**.

Partial installed-artifact snapshot for this diagnostic only:

- app SHA-256: `db7643507fca2bd204d43d36df89efd5bd03c80bd7e0c538404f01d77ecc767d`
- IME SHA-256: `b956695285a762cd962881edb756e7089e82acef670a295b430b4b6724f09009`
- helper SHA-256: `e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546`

### Clean pre-install package proof

An isolated clean checkout at source
`3d84b97d211021f315d87ed964899f89dc930b5c` produced Preview9B build 2926
without installing or launching it. The app identity, IME identity, and
preview profile matched the intended daily-driver lane. The pinned Qwen model
was exactly 5,629,109,312 bytes with SHA-256
`4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`.
Strict code-signature checks passed for every signed component, hardened
runtime was present, no entitlements were added, no GGUF was embedded in the
app, and the full fast proof passed 889/889 tests.

Aggregate pre-install artifact snapshot:

- app binary SHA-256: `9e654c0a672b6f98e419a4d7db2366139985aa9bdc639fae4bc1d2afd2331cef`
- IME binary SHA-256: `01e487c16dc2ae4c0409914de109d7c3f345ae8138908b29c70a24c5933fbbd7`
- helper SHA-256: `5736147adcac17fa1566233b024ae9f892f38b5e90e3784031114a4391edbf48`
- app manifest SHA-256: `1d0afbbe7bdcb5b2d1b3ebcda446acebb07cd1579a0a589b4eb079c0f5f54fde`
- IME manifest SHA-256: `379712a5e01b4a4da3a52120c4986e92a3ecd7a4123340a7f1aade89b93ba817`

This proves only that the clean replacement package can be reproduced and is
ready for the pre-install boundary. It does not repair build 2918's missing
provenance and does not authorize installation or file rotation. Because a
later documentation commit records this attempt, the decisive run must rebuild
from the final clean source so its frozen commit and package identity match.

Playing with Lab configs is discovery, not a supported F03 result.

### Follow-up

From a clean source commit, rebuild the daily-driver IME and record the commit,
bundle build, installed binary hash, and rotation time in the local run record.
Then rotate the text-free count file, type normally, deactivate the IME so its
write queue publishes a terminal flush acknowledgement, stop the exact preview
processes, and close the entire fresh file with the local receipt. Mark F03
supported only if the new aggregate report has no blockers and passes the
registered gates. F04 is already a completed foundation; H01 remains locked
until F03 and the Stage 0 exit gate are honestly closed.

The source-to-run handoff is now fail-closed in the Preview9B tooling. Clean
decision-grade builds compile a read-only archive of the clean commit and embed
the same commit, Git tree, canonical path/mode/length/content manifest digest,
source state, Apple toolchain/SDK identity, approved helper-input identity, and
evidence class in the app and IME; dirty source requires an explicitly
diagnostic build. The separate
`--owner-approved-f03-run --previous-ledger archive|delete` path is the only
combined install/rotation/receipt workflow. Its presence is not authorization
to run it: the owner must approve the exact maintenance window and previous-file
disposition. The closeout independently binds the receipt to the still-installed
bytes, current generation, complete event-file digest and row count, write/flush
accounting, and stopped processes. See
[`next-on-device.md`](../research/next-on-device.md).

Preview assembly is serialized before touching the fixed `dist` bundle, and an
owner-approved F03 transaction executes the runner from the same retained
read-only source archive whose SHA-256 was embedded. External-model verification
also rejects metadata change during hashing. The F03 receipt binds the installed
Qwen model exactly; a direct signed per-profile model-manifest digest remains a
separate follow-up before making broader standalone-preview provenance claims.
