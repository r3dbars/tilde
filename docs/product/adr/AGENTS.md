# ADR Guide

Decision records live here: one numbered file per decision of record
(`NNNN-short-slug.md`).

- One decision per file. State the current decision, its non-negotiable
  guardrails, and the proof that keeps it honest.
- Supersede; do not silently rewrite an accepted ADR. Changing a decision means
  a new ADR plus updating the lock test it names, in the same change.
- Every ADR should name the invariants it locks and the test that enforces them.
- Keep language plain and tie the decision back to the typing loop.
