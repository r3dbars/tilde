# Road to paid — agent plan

Status: HISTORICAL PLAN, IMPLEMENTED IN PART. Personal serving and the first-run
setup described below now exist; their remaining proof gaps are noted in place.
Current product and privacy behavior lives in `README.md`, `PRIVACY.md`, and
`docs/evaluation.md`. The product goal, in the owner's words (2026-08-17): "I
want to charge people for this app eventually, and I want it to be a good
experience for them and make it feel like magic."

## What magic means here, measurably

Magic = the ghost completes with something the user was actually about to
type, visibly informed by their screen or their history. Anti-magic = a wrong
ghost at a sensitive moment, flicker, over-talking, or lost text. Every phase
below moves one of four numbers, all instrumented today:

- accept rate (shown/accepted counters, menu line)
- interruption rate (arena + judges; wrong ghosts per shown)
- personal-recognition events (ghost contains user- or screen-specific
  tokens the base model could not have guessed — measurable in replay)
- text-integrity incidents (must stay zero, forever)

Sequencing rule: trust before delight, delight before onboarding, onboarding
before money. A paying stranger forgives a dumb ghost once; they never
forgive lost text or a creepy one.

## Phase 1 — Trust everywhere (exit: the ten-app matrix is green)

1. Extend `script/real_app_smoke.sh` to a maintained matrix: Slack, Discord,
   iMessage, Mail, Notes, Notion, VS Code, Chrome (Gmail + Docs fixtures),
   Safari, Terminal-exclusion behavior. One lane per app, each asserting
   served suggestions AND no text corruption (checksum the field content
   after scripted accept/dismiss cycles).
2. Land the held Chromium blur fix (#341) behind that proof — the matrix is
   exactly the Electron dogfood it was waiting for.
3. Fold the release egress gap flagged in PR #357 (capture-path stimulus in
   the egress proof) — required before marketing "nothing leaves your Mac."
4. Exit bar: matrix green two consecutive releases; zero integrity incidents
   in owner dogfood over 14 days (diagnostics counter, not vibes).

## Phase 2 — Judgment (exit: interruption rate halved at ≤15% accept loss)

1. Silence gate: arena sweep over confidence/silence thresholds (the harness
   exists; port typist_arena.py into script/ with a context arm). Ship the
   knee of the curve.
2. Already merged: sensitive-scene suppression (#360). Extend classes only
   with evidence.
3. Land the brevity/self-repetition fix (chip task, in flight).
4. Times/dates regression arm in the arena (raid-tonight case); if the model
   loses date facts to priors, gate long time-containing ghosts on match
   with screen facts.
5. Exit bar: arena interruption rate ≤ half of tonight's baseline with
   accept-rate loss ≤15%; judges' "BAD" share under 15%.

## Phase 3 — The moat becomes real (exit: measured personal lift)

1. Vault (Screen Memory 3c): persistence of redacted screen text into the
   encrypted store. Gated on #355 (GLiNER) merged and the redaction eval
   bars holding in release proof.
2. Shipped baseline: when Personal History is enabled, a conservative read-only
   personal lookup runs beside Gemma and may replace the base suggestion after
   support checks; per-app exclusions apply to serving. This is not Smart
   Compose probability interpolation, and visible-path lift remains unproven.
   The next decision is to prove this serving behavior or remove it.
3. Personal-recognition metric added to replay-eval output (count ghosts
   containing tokens present only in personal/screen history).
4. Exit bar: replay shows ≥5% relative accept-rate lift from the blend
   (Smart Compose precedent: 6–10%), zero privacy-sentinel failures.

## Phase 4 — Stranger-ready (exit: cold-start install succeeds unassisted)

1. Shipped baseline: one setup window explains the product, requests Screen
   Recording, installs the keyboard, and downloads/resumes the pinned model.
   The 20-second interactive Tab sandbox and fresh-account unassisted proof
   remain open.
2. Auto-update: Sparkle 2 fed by the notarized pipeline (appcast generation
   in package_app.sh; EdDSA keys pinned like other release inputs). The
   fast dev-lane (in flight) stays separate from this channel.
3. Support surface: a "Copy diagnostics" menu item exporting count-only
   state (versions, permission state, counters — the existing redaction
   rules already guarantee no text).
4. Exit bar: a fresh macOS account goes install → permission → first accept
   in under 3 minutes with no human help (scripted VM test + one real
   stranger).

## Phase 5 — Charge (exit: money moves)

1. Pricing per the open-core sketch (#328): free core autocomplete; paid
   tier = the personal layer (vault, personal serving, screen context) —
   the parts with a moat and a marginal story ("it learns you").
2. License audit before invoicing: Gemma terms (cleared 2026-07), NVIDIA
   Open Model License for GLiNER (flagged for legal glance in #355), llama.cpp
   MIT, font/assets.
3. Launch evidence: publish the benchmark story (docs/research + the
   demo-page methodology) — define the category's scoreboard in public.
4. Website + purchase flow (out of repo scope; separate plan when Phase 4
   exits).

## Standing rules through all phases

- Every change through the existing gates: tests, proof.sh, independent
  review pass, notarized release; small PRs; complexity budget.
- The eval loop runs continuously: nightly arena + replay once scheduled;
  every phase's exit bar is a measured number, not a feeling.
- The demo page (Desktop/tilde-demo.html) is the standing acceptance test;
  keep extending it with every regression found in the wild.
