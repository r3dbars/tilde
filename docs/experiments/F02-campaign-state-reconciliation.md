# F02 — Campaign state reconciliation

Status: PROPOSED
Experiment class: runtime
Owner: Tilde research program
Pre-registered: 2026-08-27T10:09:35Z

## Pre-registration

### Hypothesis

Canonical durable digests plus explicit run sessions, terminal states, and
aggregate-only failure artifacts will make Tilde Lab report killed, failed,
resumed, and completed campaigns truthfully without repeating completed work.

### Why this should work

The Q01 replication completed its invariant work but stopped before report
creation. Its SQLite campaign and trials remained `running` and `pending`, and
automatic resume was rejected even though the registered inputs had not
changed. The current schema contains campaign and trial status columns, but no
code advances them. The CLI accepts `--resume` without enforcing a distinct
resume transition. Manifest and arm digests directly encode Swift `Set`
values, whose array order is not stable across processes.

The existing WAL work-item and observation tables already provide idempotent
completed-work recovery. F02 should reconcile and expose that state rather
than add a second execution system.

### Control

Campaign control-plane behavior at Git commit
`08a31dc0df422b9d871bb37b2e17706c16549d39`: campaign rows stay `running`,
trial rows stay `pending`, only expired leases recover, terminal errors are not
persisted, reportless failures cannot be reviewed, and semantic manifests may
produce different digests across processes.

### Treatment

- Encode every set-valued manifest field in stable raw-value order before it
  contributes to a durable digest.
- Add explicit `running`, `completed`, `failed`, and `aborted` campaign and
  trial states.
- Persist one owner-scoped run session with heartbeat and bounded process
  identity; reconcile dead or stale sessions and their leases at status or
  launch.
- Require `--resume` for an interrupted campaign, refuse a second live runner,
  preserve completed observations, and make the resume transition explicit.
- Persist terminal errors as aggregate-only artifacts with fixed categories,
  bounded reason codes, work counts, immutable occurrence data, and a separate
  supported/rejected/inconclusive review.
- Show reconciled campaign, session, work, report, and failure state in text
  and JSON status output.

### Data and split

This is a deterministic evidence-infrastructure experiment. Fixtures cover a
new run, semantically identical encodings, invariant failure, helper failure,
killed runner, stale session, live-session collision, explicit resume,
completed work recovery, and clean completion. No model inference, holdout,
private corpus, screen text, or Personal History is used.

### Primary metric

Every deterministic campaign fixture reports exactly one truthful reconciled
state, and a reopened process produces the same state and durable digest.

### Supporting metrics

- stable manifest, arm, scoring, runtime, and campaign fingerprints;
- terminal artifacts persisted and reviewable without an arm report;
- dead sessions and leases recovered;
- completed observations retained and never re-enqueued as model work;
- active-run collision refused;
- explicit resume transition exercised; and
- privacy-forbidden keys absent from encoded state and artifacts.

### Hard gates

- No raw prompt, candidate, model output, scenario text, personal writing,
  screen text, local path, username, or free-form error string is persisted in
  a terminal artifact.
- Completed observations are never deleted or executed twice.
- A live campaign is never stolen by a second runner.
- A dead PID, expired lease, stale heartbeat, JSON document, or aggregate work
  count alone is never described as live progress.
- Failed and completed campaigns cannot silently resume under the same ID.
- Production Tilde, its model pin, and network policy remain unchanged.

### Promotion rule

Support F02 only if deterministic tests exercise every registered state and
transition, semantically equal inputs resume after reopening the database,
dead-runner reconciliation is immediate, reportless terminal evidence can be
reviewed, completed work remains idempotent, status is truthful, and the full
fast proof passes.

### Kill rule

Reject the design if truthful reconciliation requires storing raw content or
local paths, if liveness can be inferred only from a PID or stale file, if
resume can repeat completed work, or if canonicalization changes the semantic
meaning of ordered arrays.

### Known confounders

- Process identifiers can be reused; owner nonce, heartbeat freshness, and
  lease state must be considered together.
- A process may be alive but stalled, so liveness and progress are different
  claims.
- A hard kill cannot write its own terminal event; the next status or launch
  must reconcile it.
- Existing pre-F02 databases have no run-session rows and require an explicit,
  conservative migration state.
- Infrastructure fixtures prove state truth, not Qwen quality or runtime
  stability.

### Frozen provenance

- Git commit: `08a31dc0df422b9d871bb37b2e17706c16549d39`
- Dirty state: clean
- Model revision and SHA-256: not applicable; deterministic infrastructure test
- Helper SHA-256: not applicable; deterministic infrastructure test
- Runner SHA-256: deterministic test executable and the required fast proof
- Suite and selection SHA-256: deterministic state-machine fixtures
- Scoring SHA-256: not applicable; no model comparison
- Arm SHA-256 values: deterministic canonicalization fixtures
- Invocation digest: deterministic CLI parsing and transition fixtures
- OS, hardware class, and power state: not applicable to state-machine verdict

## Result

Status: PENDING

### Aggregate evidence

Pending implementation and deterministic proof.

### Failures and limitations

Pending.

### Decision

Pending.

### Durable changes

- Learning Ledger entry: pending reusable result
- Regression IDs: pending
- Implementation pull request: pending
- Rollback: revert the F02 implementation while retaining the public result
  record

### Follow-up

If supported, pre-register a fresh Qwen a0-versus-a5 replication from clean
`main`; do not reuse or edit the failed Q01 campaign.
