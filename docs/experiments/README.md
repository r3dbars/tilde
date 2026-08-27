# Tilde experiment records

This directory is the public index and template for decision-grade Tilde
experiments. It complements, but does not replace, the machine-readable
Learning Ledger.

- An experiment record explains one pre-registered causal question and its
  eventual result.
- The Learning Ledger records only reusable conclusions and the active priority
  queue.
- Tilde Lab CLI artifacts enforce the frozen protocol locally.

## What may be checked in

- hypothesis and rationale;
- control and one bounded treatment;
- experiment class, suite ID, split, seeds, and repetition plan;
- source commit and dirty-state declaration;
- model, helper, runner, suite, scoring, arm, and invocation digests;
- aggregate paired metrics, uncertainty, protected-slice results, and hard
  gates;
- privacy-safe failure categories and permanent synthetic regression IDs;
- limitations, decision, rollback, and follow-up; and
- links to the implementing pull request and relevant Learning Ledger entry.

## What must stay local

- personal writing or Personal History events;
- screen text, screenshots containing writing, prompts, or model output;
- per-case private results;
- document, field, recipient, conversation, or raw app identity;
- local paths, socket paths, machine usernames, or secrets;
- owner-only campaign JSON and SQLite databases;
- the synthetic raw candidate cache; and
- text-free online events when their local deletion covenant requires removal.

Shareable reports may include hashes and aggregate counts. A hash proves byte
identity; it does not make the hashed private artifact publishable.

## Workflow

1. Copy the template below to `docs/experiments/<ID>-<slug>.md`.
2. Complete every **Pre-registration** field before the decisive run.
3. Open a small protocol pull request or commit so the hypothesis is timestamped.
4. Run development discovery without editing the registered result section.
5. Freeze candidates before validation; open holdout once for one candidate.
6. Add aggregate results and a `SUPPORTED`, `REJECTED`, or `INCONCLUSIVE`
   decision.
7. Freeze any reusable failure as a sanitized regression.
8. Add or update the Learning Ledger only when the result changes durable
   knowledge or the active queue.

## Record template

```markdown
# <ID> — <short title>

Status: PROPOSED
Experiment class: <generator|display-policy|context|personalization|interaction|runtime>
Owner: <public handle or role>
Pre-registered: <ISO-8601 UTC>

## Pre-registration

### Hypothesis

<One falsifiable sentence.>

### Why this should work

<Evidence and mechanism; distinguish measured facts from inference.>

### Control

<Exact frozen baseline.>

### Treatment

<One bounded difference.>

### Data and split

<Suite ID, partition, roots, seeds, repetitions, and chronological boundary.>

### Primary metric

<One frozen primary metric.>

### Supporting metrics

<Metrics that explain the result without replacing the primary metric.>

### Hard gates

<Privacy, safety, temporal, interaction, latency, power, and protected slices.>

### Promotion rule

<Minimum effect, uncertainty requirement, and non-inferiority bars.>

### Kill rule

<What would make the mechanism not worth further work.>

### Known confounders

<Threats to causal interpretation.>

### Frozen provenance

- Git commit:
- Dirty state:
- Model revision and SHA-256:
- Helper SHA-256:
- Runner SHA-256:
- Suite and selection SHA-256:
- Scoring SHA-256:
- Arm SHA-256 values:
- Invocation digest:
- OS, hardware class, and power state:

## Result

Status: <SUPPORTED|REJECTED|INCONCLUSIVE>
Completed: <ISO-8601 UTC>

### Aggregate evidence

<Paired effect, uncertainty, slice results, and gates. No raw text.>

### Failures and limitations

<What failed, what is missing, and what the experiment cannot establish.>

### Decision

<Keep, reject, revise, or promote to the next proof stage.>

### Durable changes

- Learning Ledger entry:
- Regression IDs:
- Implementation pull request:
- Rollback:

### Follow-up

<The one next question unlocked by this result, if any.>
```

## Index

- [F01 — Report provenance v6](F01-report-provenance-v6.md) — SUPPORTED
- [F02 — Campaign state reconciliation](F02-campaign-state-reconciliation.md) — PROPOSED
- [Q01 — Qwen God v1 replication](Q01-qwen-god-v1-replication.md) — INCONCLUSIVE

The staged theory registry and current eligibility gates live in the
[Tilde research roadmap](../research-roadmap.md).
