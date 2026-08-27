# F01 — Report provenance v6

Status: PROPOSED
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

Status: PENDING
Completed: pending

### Aggregate evidence

Pending implementation and proof.

### Failures and limitations

Pending implementation and proof.

### Decision

Pending implementation and proof.

### Durable changes

- Learning Ledger entry: pending
- Regression IDs: pending
- Implementation pull request: pending
- Rollback: revert the v6 implementation while retaining v1-v5 decoding

### Follow-up

If supported, proceed to F02 campaign-state reconciliation. Do not unlock Stage
1 until every Stage 0 exit condition passes.
