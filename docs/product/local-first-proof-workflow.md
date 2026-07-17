# Local-First Proof Workflow

SteadyType treats local deterministic proof as the source of truth for code
changes. Hosted Actions and manual app proof answer different questions and
must not be combined with the local result.

## Proof lanes

- **Deterministic/local:** Run `PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`
  from a clean checkout at the exact PR head. This is the authoritative
  pre-merge proof. Run any mapped focused tests as well.
- **Hosted:** `.github/workflows/fast-proof.yml` is manual-only. If a hosted run
  is available, record its URL and status separately. Runner, billing, or
  spending-limit failures do not invalidate a green local proof and are not a
  PR gate.
- **Manual/hardware:** Real app, Accessibility, screen, audio, and hardware
  checks remain explicitly manual. Do not claim them from local tests or hosted
  workflow status.

## Exact PR evidence

Every PR handoff should record:

1. Base commit SHA and exact PR head SHA.
2. The exact local command, `PROOF_DIFF_BASE=origin/main ./script/proof.sh fast`,
   with its blocking result and any report-only pending lanes.
3. Mapped focused test commands and results.
4. Hosted workflow URL and result, or `not run (manual-only)`.
5. Manual/hardware proof status: `GREEN`, `PENDING`, or `UNKNOWN`, with no
   implication that deterministic or hosted proof covers it.

Do not include typed text, prompts, screenshots, document names, URLs, or other
user content in the PR evidence. Prefer command summaries, commit SHAs, and
redacted local proof artifact paths.

## Merge handoff

A PR is ready for the serialized merger when the exact head is clean, the local
deterministic proof is green, mapped tests are green, and an independent full-
diff review has no actionable findings. A hosted failure caused by unavailable
runners is reported separately; it does not create a source-code failure or a
new paid-runner dependency.
