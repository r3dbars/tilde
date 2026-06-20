# Append-only registry merge strategy

Two append-only registries are edited by nearly every PR, so parallel branches
keep colliding on them and naive union-merges leave duplicates that the wiring /
proof checks then reject. This is the structural cause of the recurring "red
wall" (and the recent `HostPolicyRuntimeState` duplicate). This note records the
landed first step and the larger change still pending human approval.

## The two registries

| Registry | Format | Produced by | Consumed by |
| --- | --- | --- | --- |
| `public-core-reachability-allowlist.psv` | line-oriented, pipe-separated | hand-appended when a public `AutocompleteLabCore` type is not yet app-wired | `script/check_public_core_wiring.py` (blocking, via `check_test_coverage_manifest.sh`) |
| `proof-manifest.json` | JSON | hand-edited; growth lists `surfaces`, `profileCoverage`, `hostPolicy.entries` | `script/check_proof_manifest.py` + scorecard/graduation checks |

Both checks are order-independent (they key entries by name/bundle), so reordering
is behavior-identical. The one exception is `graduationDecisions`, whose insertion
order is an explicit contract enforced by `check_graduation_score.py` — it is a
closed, enumerated set, not an every-PR append target, so it is left untouched.

## Landed first step (safe, reversible)

### `.psv` — `merge=union` + canonical normalize
- `.gitattributes` marks the file `merge=union`, so git auto-merges concurrent
  appends instead of emitting conflict markers.
- `script/normalize_public_core_allowlist.py` re-asserts canonical form: header
  preserved, rows sorted by `(Source, Type)`, exact-duplicate rows collapsed.
  Conflicting rows (same Type, different fields) fail loudly — a real ambiguity.
- `check_public_core_wiring.py` now tolerates an exact-duplicate row (the harmless
  union artifact) and only fails on a *conflicting* duplicate. The existing
  duplicate gate is preserved for the dangerous case, not weakened.
- A blocking CI lane (`script/proof.sh`) runs `--check`; a union merge that leaves
  the file unsorted fails fast with the one-line fix: `normalize_… --write`.

### `.json` — deterministic sort + dedup-on-write (NOT union)
Union corrupts JSON, so it is not applied. Instead the manifest is kept in a
deterministic canonical form (`script/normalize_proof_manifest.py`): the three
growth lists are sorted by key and deduped on write. Sorted order spreads new
entries to stable, alphabetically-distinct positions, so git's 3-way merge
resolves non-overlapping inserts cleanly; dedup-on-write removes the duplicate a
hand-resolved conflict would otherwise leave. A blocking `--check` lane prevents
silent drift. No format change, so no migration is required; fully reversible by
deleting the script + CI lane.

## Bigger change pending human approval: split the manifest into fragments

The normalizer makes JSON merges *clean and duplicate-proof* but the file is still
**single and shared**, so the closing-bracket / same-region contention is reduced,
not eliminated. The structural fix that removes contention entirely:

- Split each growth list into per-entry fragment files, e.g.
  `docs/product/proof-manifest.d/profile-coverage/<bundle>.json`,
  `…/host-policy/<bundle>.json`, `…/surfaces/<surface>.json`.
- A build step aggregates fragments into `proof-manifest.json` (sorted), and a CI
  freshness check asserts `proof-manifest.json == aggregate(fragments)`.
- Each PR that adds an app/surface touches only its own new fragment file — two
  PRs adding different apps can never collide.

**Tradeoffs.** Pros: eliminates contention; smaller, reviewable diffs; impossible
to merge-duplicate. Cons: a real format/migration change — every consumer keeps
reading the aggregated `proof-manifest.json` (so they are unaffected), but authors
now edit fragments and must regenerate; the generated manifest must stay in the
repo (consumers read it directly) and be kept fresh by CI. It is a one-way-ish
migration, which is why it is staged behind explicit approval rather than landed
with the plumbing.

**Recommendation.** Land the normalizer now (done). Adopt the fragment split next
if profile/host-policy churn stays high; the normalizer is forward-compatible —
the aggregator would emit the same canonical sorted form the `--check` already
enforces.
