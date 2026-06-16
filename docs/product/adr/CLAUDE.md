# Claude Code Guide

Decision records live here. Each file is one decision of record.

Start with:

- `0001-breadth-vs-depth.md`

Rules:

- One decision per numbered file (`NNNN-short-slug.md`); never silently rewrite
  an accepted one. Supersede it with a new ADR instead.
- Every ADR names the invariants it locks and the test that enforces them. If you
  change the decision, update the ADR and that test together.
- Keep proof gates honest: pending proof stays pending.
- Keep language plain and tie back to the typing loop: useful, calm, safe, and
  easy to stop.
