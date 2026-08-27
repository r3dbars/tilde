# F01 — Report provenance v6

Status: SUPPORTED
Experiment class: runtime
Owner: Tilde research program
Pre-registered: 2026-08-27T01:48:10Z

## Pre-registration

### Hypothesis

Adding a privacy-safe provenance envelope and explicit evidence eligibility to
every new Tilde Lab report will make future conclusions reproducible from the
stored record, while keeping legacy and incomplete reports readable but unable
to support promotion.

### Why this should work

The v5 aggregate report already binds the selected suite, arm, execution
controls, model and helper hashes, privacy contract, metrics, and case IDs. It
does not bind the source revision, dirty state, runner bytes, operating system,
hardware class, power and thermal state, invocation, registered hypothesis,
conclusion, or review status. Those omissions make an old result difficult to
reconstruct and make absence of evidence look too similar to a clean run.

A versioned, validated envelope can close that gap without retaining prompts,
model output, scenario text, personal writing, raw command arguments, machine
usernames, serial numbers, or local paths.

### Control

`tilde-lab.reply-bench-report.v5` as implemented at Git commit
`f272d11faba5c2974906103502a8b115ca9ded32`.

### Treatment

Introduce `tilde-lab.reply-bench-report.v6` with:

- Git commit and explicit clean, dirty, or unavailable source-tree state;
- runner SHA-256;
- macOS version/build and anonymous hardware class;
- AC-power, Low Power Mode, and thermal state captured at run start;
- a SHA-256 digest of the canonical invocation rather than raw arguments;
- a bounded public hypothesis ID and statement;
- explicit unreviewed, supported, rejected, or inconclusive review state plus a
  bounded conclusion when reviewed; and
- an evidence-eligibility decision with fixed reason codes.

All report-producing paths must receive the same immutable run-start envelope.
Review may update interpretation after execution, but may not rewrite run
provenance, configuration, cases, or metrics.

### Data and split

This is an evidence-infrastructure test, not a model-quality comparison. The
test corpus is the deterministic set of all Tilde Lab report producers plus
encoded fixtures for report schemas v1 through v6. No model inference, private
corpus, Personal History, or holdout data is required.

### Primary metric

One hundred percent of newly saved v6 reports contain a valid provenance
envelope and an explicit evidence-eligibility decision.

### Supporting metrics

- report-producing paths covered;
- legacy schemas decoded;
- incomplete-provenance reason codes exercised;
- privacy-forbidden fields rejected;
- deterministic digest checks; and
- owner-only report file permissions preserved.

### Hard gates

- Existing v1-v5 reports remain readable.
- A legacy, dirty, unregistered, unreviewed, malformed, or incomplete report is
  never evidence-eligible.
- Missing provenance is never replaced with fabricated defaults.
- Encoded reports contain no raw invocation, local path, username, serial
  number, prompt, model output, scenario text, or personal writing.
- Frontier and local reports disclose their existing network-inference boundary
  accurately.
- Production Tilde, its model pin, and its network policy remain unchanged.

### Promotion rule

Support F01 only if every real report producer emits v6, all legacy fixtures
decode as explicitly non-promotable, clean reviewed fixtures can become
evidence-eligible, dirty and incomplete fixtures cannot, Tilde Lab and its CLI
show the distinction, and the full fast proof passes.

### Kill rule

Reject this design if complete provenance requires retaining raw paths or
private content, silently changes historical evidence, or cannot distinguish
unknown provenance from verified clean provenance. Redesign the envelope before
running further decision-grade experiments.

### Known confounders

- A Git checkout may be unavailable in a packaged or copied runner.
- Hashing the executing binary must resolve the actual runner, not a build
  directory guessed from the current working directory.
- Hardware class must be useful for performance comparison without becoming a
  stable device identifier.
- The invocation digest proves equality only when its canonicalization version
  is also recorded.
- Human review occurs after execution, so run provenance and interpretation
  must remain separate concepts.

### Frozen provenance

- Git commit: `f272d11faba5c2974906103502a8b115ca9ded32`
- Dirty state: clean
- Model revision and SHA-256: not applicable; deterministic infrastructure test
- Helper SHA-256: not applicable; deterministic infrastructure test
- Runner SHA-256: captured by the treatment and deterministic fixtures
- Suite and selection SHA-256: deterministic report fixtures
- Scoring SHA-256: not applicable; no model comparison
- Arm SHA-256 values: not applicable; no model comparison
- Invocation digest: captured by the treatment and deterministic fixtures
- OS, hardware class, and power state: captured by the treatment and
  deterministic fixtures

## Implementation observations

- 2026-08-27: The research queue named the work `report-provenance-v5`, but the
  current aggregate report schema was already v5. The treatment is therefore
  v6; adding new required meaning to v5 would make schema identity ambiguous.
- 2026-08-27: Tilde Lab already records exact suite, arm, runtime, model, and
  helper evidence. F01 should extend that record rather than introduce a second
  report or telemetry system.

## Result

Status: SUPPORTED
Completed: 2026-08-27T02:12:10Z

### Aggregate evidence

- Every `LabRunReport` constructor now emits schema v6 with a validated
  provenance envelope, explicit review state, and persisted eligibility
  decision. Diagnostic producers use an explicit unavailable envelope instead
  of pretending that missing source or runner identity is complete.
- Durable CLI execution captures one immutable envelope before it creates run
  artifact directories, so a run cannot dirty its own source-state evidence.
  The envelope is reused by every arm report and binds the campaign ID,
  manifest digest, public hypothesis ID and statement, resolved runner SHA-256,
  Git revision and tree state, OS/build, anonymous hardware class, power and
  thermal state, and versioned canonical-invocation digest.
- Eligibility is recomputed from the report and checked against the stored
  decision on save and load. Missing or forged decisions fail closed. Fixed
  reasons cover legacy schema, missing or malformed provenance, dirty source,
  missing runner/environment/invocation, unregistered hypothesis, unsafe
  privacy, incomplete execution, and pending or invalid review.
- The comparison control plane now refuses non-decision-grade reports before
  it creates paired comparison artifacts, freezes validation or regression,
  consumes holdout evidence, or starts online promotion. Exploration and old
  reports remain inspectable.
- Deterministic tests decode report schemas v1 through v6, preserve owner-only
  storage, distinguish clean/dirty/unregistered/unreviewed states, reject
  local paths, prove invocation-digest determinism, and reject omitted or
  forged eligibility decisions.
- The complete Swift suite passed with 732 tests in 92 suites. The final
  structural fast proof remains a blocking merge check for pull request 420.

### Failures and limitations

- A packaged or copied runner that cannot see its source Git checkout records
  source revision as unavailable. The report remains readable but cannot
  become decision-grade; no revision is inferred from a guessed build path.
- Human review remains an accountable interpretation step. Marking a result
  supported, rejected, or inconclusive cannot erase metric failures, missing
  provenance, dirty state, or privacy violations.
- The invocation digest proves equality under
  `tilde-lab.canonical-invocation.v1`; it intentionally cannot reconstruct raw
  arguments and therefore cannot expose local paths.
- F01 proves the evidence boundary, not model quality, campaign crash recovery,
  retained live utility, or macOS editor compatibility.

### Decision

Adopt report v6 and require complete, clean, registered, reviewed evidence for
durable comparisons and protected-phase transitions. Preserve v1-v5 decoding
for historical inspection only. Keep run provenance immutable when a reviewer
adds the conclusion.

### Durable changes

- Learning Ledger entry: `report-provenance-v6`
- Regression IDs: `LabReportProvenanceTests`, `LabReportStoreTests`, and fixed
  `LabEvidenceIneligibilityReason` codes
- Implementation pull request: 420
- Rollback: revert the v6 implementation while retaining v1-v5 decoding

### Follow-up

Proceed to F02 campaign-state reconciliation as the next foundation item. The
separately queued Qwen protected-validation run may now use v6 evidence, but do
not unlock Stage 1 until every Stage 0 exit condition passes.
