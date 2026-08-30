# Tilde Lab log

The public notebook of what we tried, what we learned, and what failed.
Newest first. Failures and inconclusive stops are required, not optional.

This is not the Learning Ledger. The ledger stores a *reusable lesson or
decision*. This log stores the *attempt*, including work that taught us
nothing durable enough for a ledger row.

After every research attempt, append a block using the template below.
If the attempt produced a decision-grade result, also complete the
experiment record. If it produced a reusable lesson, also add a ledger
entry. Never check in private writing, screens, prompts, candidates, or
paths.

How we work: [`lab-partnership.md`](lab-partnership.md).

## Template

```markdown
## YYYY-MM-DD — <short title>

- **Try:** one sentence. What we actually did.
- **Learn:** one sentence. What we now believe, or "nothing durable yet."
- **Fail:** one sentence. What broke, was rejected, or stayed incomplete.
  Write `none` only if the attempt fully succeeded.
- **Where:** experiment ID, ledger ID, digest, or PR.
- **Next:** the one following question. Not a list.
```

## 2026-08-30 — Harness audit finds the missing silence denominator

- **Try:** Trace the production outcome lifecycle from IME effects through the
  text-free event, then compare its observable states with H04's planned
  cooldown and missed-opportunity metrics.
- **Learn:** `recordOutcomeShown` starts the live opportunity only after the
  `.shown` effect, and the finished event is always generated and displayed.
  F03 can measure keep versus rewrite for visible ghosts, but future quiet
  policies cannot learn from requests that stayed silent, skipped inference,
  found the runtime unavailable, or were suppressed upstream.
- **Fail:** The current 889-test suite can prove the shown-opportunity contract
  while leaving that denominator unobservable. Adding another display gate
  before fixing the ruler would make the blind spot larger.
- **Where:** `Sources/InlineGhostIME/GhostInputController.swift`;
  `Sources/InlineGhostIME/GhostOutcomeLedger.swift`;
  `Sources/TildeCore/Policy/LiveOnlineOpportunity.swift`; H04 roadmap.
- **Next:** Keep F03 frozen; before H04 registration, add one text-free
  request-lifecycle contract with fixed reason codes and shadow missed counts.

## 2026-08-30 — Frontier source refresh does not unlock a second question

- **Try:** Recheck current primary work on chat autocomplete ranking,
  uncertainty calibration, conditional display, on-device retrieval,
  production query completion, post-action edits, and current llama.cpp
  speculative modes against the registered H01–H18 map.
- **Learn:** The strongest reusable prior is still controller-first: measure
  whether confidence ranks retained quality, learn when silence helps, and
  treat retrieval plus verification as a later calibrated expert. Current
  sources sharpen H04, H06/H07, H09–H13, and H02 follow-ups but do not reorder
  the executable queue.
- **Fail:** None of these papers is system-wide macOS prose evidence, and none
  makes a locked hypothesis eligible. Starting a cascade, verifier, retrieval
  arm, or speculative mode now would create an unregistered second question.
- **Where:** `docs/reading-list.md`; `docs/research-roadmap.md`; primary-source
  links there. No paper result was treated as a Tilde result.
- **Next:** Close F03 with one attributable fresh on-device file before
  freezing H01.

## 2026-08-30 — Clean Preview9B package passes the pre-install proof

- **Try:** Build the Preview9B app from an isolated clean checkout without
  installing or launching it, then verify product identity, the pinned model,
  code signatures, manifests, bundle contents, and the full fast proof.
- **Learn:** Source `3d84b97d211021f315d87ed964899f89dc930b5c` produced build
  2926 with the expected preview app/IME identities, the pinned Qwen asset
  (`4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`),
  strict valid signatures, no embedded GGUF, and 889/889 passing tests.
- **Fail:** This is package readiness, not F03 evidence. The package was not
  installed, the live file was not rotated, and the source freeze predates the
  documentation commit that records the audit. The decisive run must rebuild
  from its final clean source and seal that identity before rotation.
- **Where:** `script/build_preview_9b.sh`; F03 retained-outcome ledger. No
  package, event, diary, prompt, candidate, writing, or local path was checked
  in.
- **Next:** After the research branch is final, rebuild that exact source,
  record its package identity, then use the owner-approved recoverable install
  and text-free rotation procedure.

## 2026-08-30 — F03 full-file audit remains provenance-ineligible

- **Try:** Audit the active preview's complete local count file with
  aggregate-only integrity checks, isolated full-file ingest/report, diary
  separation, permission/provenance checks, F03/v2/privacy fixtures, and the
  full fast proof.
- **Learn:** The stable snapshot contained 340 v3 events across one instrument
  campaign and champion arm: 6 accepted-all, 33 accepted-word, 143
  typed-through, and 158 ignored. Privacy, schema, duplicate, domain, and
  monotonic checks were clean. Retention was 331 observed / 9 missing at five
  seconds, 17 / 323 at 30 seconds, and 39 / 301 at segment close, with
  missingness explicit.
- **Fail:** F03 remains unsupported because neither the installed build nor the
  event file carries a sealed source commit or local rotation record. Valid
  signatures, binary hashes, and a build number cannot reconstruct that
  missing provenance. A synthetic TextEdit stimulus did not append a
  qualifying F03 outcome.
- **Where:** F03 retained-outcome ledger; isolated aggregate ingest/report;
  `Tilde 9B Preview` build 2918. No events, diary, prompts, candidates, writing,
  or local paths were checked in.
- **Next:** From a clean source commit, rebuild the current daily-driver IME,
  record commit/build/binary hashes and rotation time, rotate only the
  text-free count file, then ingest the entire fresh file after ordinary use.

## 2026-08-30 — Q10R rejects third-character K=1 early start

- **Try:** Repeat Q10's exact 360-situation, 637-opportunity treatment from a
  clean frozen commit with the registered invocation, suite, production model,
  signed helper, complete v2 provenance, and a separate review.
- **Learn:** Early execution solved measured readiness but not useful survival:
  readiness was 100%, median lead 689 ms, and false locks 0%, while only
  78/637 opportunities (12.24%) remained lockable and decoded-token compute
  reached 1.87x control.
- **Fail:** The registered lockability gate (at least 15%) and compute gate (at
  most 1.5x) both failed. The hot/cold pair added only 0.78 lockability points
  at 3.06x compute. The reviewed eligible verdict is `REJECTED`; no production
  or live-shadow change is authorized.
- **Where:** [Q10](../experiments/Q10-early-start-timing-falsifier.md), reviewed
  [Q10R aggregate](../experiments/Q10R-aggregate-results.json) SHA-256
  `0dead997418b0b38ff0c2d4988094a72c3054d416427e9a7430f098e63be4b83`,
  campaign `2d06791d-1fd3-4d84-bfc2-0fb4b8eb1491`, and ledger ID
  `early-start-third-character-k1-rejected`.
- **Next:** Resume F03's clean provenance-bearing retained-outcome run; do not
  start earlier, multiply branches, or open a live prewarm from Q10R.

## 2026-08-30 — Correct Q09's evidence status after the F01 audit

- **Try:** Audit the Q09 source report and checked-in aggregate against the F01
  provenance, review, and evidence-eligibility contract adopted before Q09 ran.
- **Learn:** The 5,760 completed generations still give a strong directional
  negative: K=16 added five golden matches beyond K=8 and failed the frozen
  diversity thresholds. That remains useful triage, not a formal verdict.
- **Fail:** Q09 is `INCONCLUSIVE`, not rejected. Its custom v1 report and public
  aggregate omit F01's run-start provenance envelope, explicit review, and
  persisted eligibility decision. Narrative hashes cannot be added after the
  result to repair that evidence boundary.
- **Where:** [Q09](../experiments/Q09-future-lattice-k16-feasibility.md), its
  [aggregate](../experiments/Q09-aggregate-results.json), and stable ledger ID
  `future-lattice-k16-independent-branches-rejected` now marked directional.
- **Next:** Require an exact provenance-complete replication before treating
  Q09 as a durable verdict; meanwhile make no 16-branch or larger-K build.

## 2026-08-30 — Q10 points negative but fails its provenance gate

- **Try:** Run Q10's pre-registered third-character early-start falsifier on
  the exact frozen commit and production Gemma asset: 360 synthetic development
  situations, 637 opportunities, and 1,911/1,911 sequential generations.
- **Learn:** The directional result says moving one hidden request earlier
  solved measured timing — 100% were ready and median lead was 694 ms — while
  only 12.24% carried six useful future characters and compute reached 1.87x.
- **Fail:** Q10 is `INCONCLUSIVE`, not rejected. Its frozen invocation digest
  names the old helper command rather than the registered command, and the
  custom report lacks F01's v6 run-start provenance/review envelope. The hot
  pair's +0.78 lockability points at 3.06x compute cannot waive those defects.
- **Where:** [Q10](../experiments/Q10-early-start-timing-falsifier.md), its
  aggregate report; no Learning Ledger entry.
- **Next:** Pre-register an exact, provenance-complete replication before
  rerunning; do not start earlier, add branches, or build a live prewarm.

## 2026-08-30 — F03's clean-looking slice cannot close a dirty full file

- **Try:** Audit the complete text-free live count file and an inferred
  post-install slice with the current F03 ingest and report contract.
- **Learn:** The full file has 1,364 events and two pre-fix monotonic-retention
  violations; the inferred later slice has 575 events, 39 accepts, 225
  typed-through outcomes, and zero duplicate, XOR, domain, or monotonic
  violations.
- **Fail:** F03 remains `IMPLEMENTING`. The clean-looking slice is not
  decision-grade because its cutoff is inferred, its build provenance is not
  sealed in the events, and the complete source file still fails two checks.
- **Where:** [F03](../experiments/F03-retained-outcome-ledger.md) and the
  [on-device handoff](next-on-device.md); no event file or writing is checked in.
- **Next:** Record a clean commit, bundle build, installed binary hash, and
  rotation time; rotate the text-free file, type normally, and ingest the
  entire fresh file.

## 2026-08-30 — The Q12 nomination block was the wrong exam, not lost credit

- **Try:** Audit why campaign q12b reads arm-aggregate Net Keystrokes
  Saved 11.2% → 19.8% with useful displays 473 → 765 while
  `compare --paired-bootstrap` reports Δ utility 0.00 [0.00, 0.00] and
  `nominate` refuses, by reading the scoring and paired code and
  recomputing both quantities from the read-only campaign reports.
- **Learn:** The Q12 record's guess was wrong and the truth is simpler.
  Both views read one keystroke ledger: the arm aggregate's
  `netKeystrokeSavingsRate` and the comparator's `deltaOracleNetKSS` are
  the same per-case field, and that difference does move (+8.63 points,
  95% CI [6.71, 10.60], P(>0)=1.00, reproducing 3053/27222 → 5403/27222
  exactly). "Δ utility" is a different quantity — the latency-gated
  expected-utility proxy — and it scores a display only when that
  display's first token beats the 400 ms stable-word deadline. In this
  8×2-worker throughput run, registered quality-only with no latency
  claims, exactly 1 of 1,800 paired observations clears 400 ms, and it is
  the same unwanted case in all three arms, so expected utility is the
  identical constant −8.0817 ms/1,000 chars everywhere and every one of
  600 roots ties. Exact-path-only keystroke credit is documented and
  applied identically in both paths, so it is by design, not the bug.
  Fixed the real defect: display-policy campaigns were registered on a
  metric their class cannot move by construction. `bad-when-shown` is now
  a registrable primary metric, oriented so positive means better, with a
  class-appropriate protected-slice guard, and it is the display-policy
  default; `compare` now prints the registered metric first.
- **Fail:** This does not unblock q12b. That campaign registered
  expected-utility before the run, and its candidate reports also carry
  `bad-suggestion-gate` and `latency-gate` hard-gate failures (9.4% bad
  on the completed set, p95 far past 1,000 ms), so its decision would
  stay `reject` under any primary metric. Q12's nominations remain
  governed by its own registered rules; a paired promotion needs a newly
  registered campaign. The Q12 record's "Honest nuances" claim of a
  credit divergence between the two views was mistaken and is corrected
  in place.
- **Where:** [`Q12`](../experiments/Q12-scene-echo-grounding.md);
  `Sources/TildeLabKit/Scoring/LabPairedComparison.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) registered-primary-metric and
  keystroke-accounting sections; branch
  `claude/paired-utility-credit-audit`.
- **Next:** Register the Q12 validation campaign on `bad-when-shown` with
  a suite and runtime whose hard gates can actually pass.

## 2026-08-30 — Cross-instrument staircase: the tuned stack quadruples simulated value

- **Try:** Rerun the persona simulator with the Q12-nominated arm on both
  generators via the new --arm-file (Luna judging, 16 workers), with an
  untuned anchor, to corroborate the campaign result on a second
  instrument; wire the same tuned arm into the isolated 9B preview for
  live owner trial.
- **Learn:** The corroboration is emphatic and staircase-shaped. Qwen 9B
  simulated retained value: 7.5% (old sim defaults, cap 8) → 17.9%
  (cap 3 + confidence) → 30.5% (plus echo-24 and grounding), with accepts
  5.1%→26.9%; tuned E2B reached 7.3% (junk halved to 31%) — the filters
  lift the small model to untuned-Qwen value, and unlock 4x on Qwen,
  whose verbatim fact-carrying completions were exactly what the old echo
  floor executed. The cap-3-beats-cap-8 result reproduced independently
  on this instrument. The tuned preview is installed and serving the
  owner live (first ~138 real requests, p50 ~364 ms end-to-end).
- **Fail:** Three honest dents. The "anchor" run was a config mismatch
  (campaign control arm, not the prior sim baseline), so it became an
  accidental cap experiment rather than a replication — logged as a
  design slip that produced a useful staircase. The Grok judge column is
  postponed: batch mode trips Cursor's loop detector (batch-5 probe: 6/10
  fail), and single-moment mode exceeds the engine's fixed 20s external
  deadline — a configurable --decision-timeout is the missing feature.
  Parallel simulator processes fight over the model-server port and one
  dies; serial execution is the rule until ports are per-run. All sim
  numbers remain uncalibrated and fenced; the live preview is an isolated
  identity, not a promotion.
- **Where:** matrix reports (owner-local scratch); PRs #449/#450/#451;
  [Q12](../experiments/Q12-scene-echo-grounding.md) follow-up notes the
  preview wiring; wrong-rate attack workflow running in a peer session.
- **Next:** Owner's live verdict on the tuned preview, protected
  validation for the Q12 candidates, and a --decision-timeout flag so the
  Grok column can complete.

## 2026-08-30 — Q12's nominated filters go live in the isolated 9B preview

- **Try:** Take Q12's two nominated display-policy settings — scene-echo
  minimum characters 10 → 24 (word floor unchanged) and names-and-numbers
  factual grounding on — out of the Lab judge and into the live completion
  path for `TildeProductProfile.preview9B` only, routed through
  profile-computed properties beside `completionTemperature` and
  `maximumVisibleWords`, so the owner can dogfood the arm the campaign
  measured instead of only reading its numbers.
- **Learn:** The product had a scene-echo rejection
  (`TildeCore.SceneEchoPolicy`, applied twice in `LlamaCompletionEngine` —
  once on the final, once on every streamed partial) but no factual filter
  at all; grounding existed only inside `LabOutputJudge`. Rather than write
  a second copy, the rule moved down into
  `TildeCore.FactualGroundingPolicy` and the judge now calls it, which is
  what makes "the preview runs the nominated arm" a checkable claim rather
  than a hopeful one — a parity suite over a shared fixture set fails if the
  two ever disagree. Applying grounding to the streamed partial as well as
  the final mattered: the partial is the text the writer actually sees
  first, so a filter that only judged the final would have shown the
  invented number and then withdrawn it.
- **Fail:** No live evidence yet — this is wiring, not a result, and an
  isolated preview is explicitly not promotion. The settings remain frozen
  validation candidates selected on the development partition; production,
  the 26B preview, and the Model Preview daily driver are byte-identical in
  behavior and pinned there by regression assertions. Whatever the preview
  produces in use is dogfood that must clear the three-judges rule, and it
  cannot substitute for the protected validation path Q12 still owes.
- **Where:** [`Q12`](../experiments/Q12-scene-echo-grounding.md) § Follow-up;
  `Sources/TildeCore/Suggestions/FactualGroundingPolicy.swift`;
  `Sources/TildeCore/Suggestions/SceneEchoPolicy.swift`;
  `Sources/TildeCore/Runtime/TildeProductProfile.swift`;
  `Sources/TildeApp/Runtime/LlamaCompletionEngine.swift`.
- **Next:** Dogfood the 9B preview and see whether the recovered short
  fact-carrying displays feel useful in real typing, or merely more frequent.

## 2026-08-29 — First full-scale simulated persona run lands in 38 minutes

- **Try:** Run the simulated typist over the full replying-v2 speak-expected
  set (240 qualifying scenarios × 5 personas, ~5,000 displays) with Luna as
  the external decision brain — 12 concurrent workers, batch size 25 —
  after the 16-worker probe passed clean and two full-throttle attempts
  taught their lessons.
- **Learn:** Wrong-when-shown is strikingly uniform across personas
  (60.0–61.7%) while acceptance varies persona-to-persona (4.4–6.7%) —
  suggestion quality failure is generator/policy-side, not
  audience-dependent, which is consistent with the mining sweep's chronic
  list. Simulated acceptance rates bracket the owner's live 7.7%.
  Operational ceilings measured today: Luna holds 25-moment batches and 12
  concurrent calls with hardened retries; Grok's loop detector rejects
  large repetitive batches and its lane was benched pending an engine
  skip-a-failed-batch mode; 16 concurrent calls per provider is over the
  reliability line for long runs.
- **Fail:** Grok's second-opinion column is missing, so no inter-brain
  agreement map exists at this scale yet. The abort-on-one-bad-batch
  failure semantics killed two full runs; a counted skip mode (no silent
  caps — dropped batches must be reported) is the needed engine change.
  All numbers remain discovery-grade: uncalibrated personas, legacy suite,
  permanently fenced.
- **Where:** issue #437; report in owner-local scratch state; engine
  concurrency from PR #445; Q11 earlier today for the campaign-side result.
- **Next:** Add the counted skip-failed-batch mode, rerun with Grok, and
  score inter-brain agreement before any screening use.

## 2026-08-30 — The simulated typist can run the arm a campaign nominated

- **Try:** `simulate-typist` built its own fixed baseline arm internally, so
  the only configuration it could ever explore was the one compiled into it —
  a campaign that nominated custom judgment settings (Q12's scene-echo floor
  and factual-grounding mode) had no way to be simulated. Add
  `--arm-file /absolute/arm.json`: one campaign-manifest arm object, decoded
  by the same `Codable` type and validated by the same check `validate` runs,
  replacing the built-in baseline for that run.
- **Learn:** The engine already routed its baseline arm the way a campaign
  run routes its own — prompt configuration into the composer, generation
  configuration into the request, whole arm into the display judge — so the
  arm file needed no new plumbing, only a loader and a refusal path. That is
  worth writing down: the reason a nominated arm behaves in the simulator
  the way it behaves in a campaign is that there is one routing, not two, and
  the stubbed scene-echo-boundary test pins it — the same candidate is
  suppressed under the default floor and shown under a widened one, decided
  by the file rather than by the engine. Validation at load, before any model
  starts, is what keeps a typo from becoming a report.
- **Fail:** Infrastructure only — no result, no Q12 run, and an arm file
  changes nothing about the fence: a simulated report is still discovery-grade
  and still cannot enter a comparison. The simulator also still skips the
  pre-inference scene gates a campaign run applies before generating, so an
  arm's gate-widening settings are not exercised here; that gap predates this
  change and was deliberately left alone.
- **Where:** issue #437; `Sources/TildeLabKit/Simulation/LabSimulatedTypistArmFile.swift`;
  `Sources/TildeLabCLI/SimulatedTypistCommand.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) § Simulated typist.
- **Next:** Run Q12's nominated arm through the simulator and see whether its
  judgment settings move retained-character potential at all.

## 2026-08-30 — One flaky batch may no longer cost a whole simulated run

- **Try:** Two full-scale simulated-typist runs died overnight because a
  single decision batch failed after the external policy's own retries and
  aborted everything behind it, so add `--skip-failed-batches N`
  (0...50, default 0, external-command policy only): that many failed
  batches abandon the persona/scenario sessions they held and the run
  continues. While in the same file, give the simulated report the
  generation model identity, revision, and model/helper digests every
  other Lab report already carries.
- **Learn:** Surviving a failure is easy; surviving it *without* quietly
  changing the number is the work. Three rules did it. An abandoned
  session is dropped whole rather than zero-filled, because a session
  whose batch failed is not a writer who ignored or dismissed a ghost and
  must never aggregate like one. The failure verdict is taken in batch
  order after the round joins, never in completion order, so which batches
  a run skips is a property of the policy's answers rather than of the
  machine's scheduling — which is also what let a failed batch stop
  cancelling the siblings in flight beside it while skips remain. And the
  loss is stated everywhere a reader looks: allowance, skipped batches,
  abandoned sessions, abandoned moments, per-persona abandoned scenarios,
  cross-validated against each other, plus a limitation sentence and a
  loud CLI block. A cap you cannot see is worse than an abort. The
  provenance gap was the same lesson in miniature: the report pinned the
  suite digest but not the model, so a Gemma run and a Qwen run were
  indistinguishable once the files left the machine.
- **Fail:** Infrastructure only — no result, no LLM policy, no
  calibration, and nothing here makes a simulated number any less fenced.
  A skipped run is a smaller sample by construction, so a report with
  skips is weaker evidence than one without, and 50 is a guess at the
  point where a broken backend should just fail the run rather than a
  measured one. The two lost runs were not re-run here.
- **Where:** issue #437; `Sources/TildeLabKit/Simulation/`;
  `Sources/TildeLabCLI/SimulatedTypistCommand.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) § Simulated typist.
- **Next:** Re-launch the overnight run behind a real cheap-model policy
  and see whether a bounded allowance is enough to finish one.

## 2026-08-29 — Q11 cannot be replayed from cache; it needs fresh inference

- **Try:** Attempt to execute the registered Q11 extended ordinary-silence
  gate comparison without loading a model, by reusing the Q05/Q06 cached
  synthetic candidate replay path
  (`LabSyntheticCandidateCache` + `LabRiskCoverageAnalyzer.completeSyntheticReplay`)
  against Q11's registered control — the exact arm Q08 ran on the full
  certified V2 development suite.
- **Learn:** The replay path is real and would honour the flag — the
  analyzer applies `SceneSuggestionPolicy.suppressionReason` with the
  arm's own `sceneSuppressionOptions` before it ever consults the cache,
  which also confirms the gate is a pre-generation, candidate-independent
  decision and therefore perfectly paired. But no cache can serve Q11's
  registered control. Q08 was pre-registered to run with `--no-cache` and
  left no candidate cache at all; the only substantial caches on the
  machine are Q06's (1,059 entries, 353 scenarios, `cachePrompt` on, a
  505-root file suite) and the factorial-v4 sweep's (10,176 entries, 424
  scenarios). Q11's control differs from both in generation identity
  (`cachePrompt` off), scenario coverage (600 selected roots), and
  selected-suite digest, so every cache key misses and the replay would
  fail closed on suite fingerprint before the first lookup.
- **Fail:** Q11 was not run. There is no cache-only or helper-free run
  mode: `tilde-lab run` is the only producer of v6 reports and always
  starts the llama-server pool, so even a warm cache loads the model.
  Running the registered protocol means ~40,704 fresh generations across
  two arms on a machine the owner is actively using, which the current
  authorization forbids. No campaign was created, no `--resume` was used,
  no inference was started, and no production default was touched.
- **Where:** [`Q11`](../experiments/Q11-ordinary-silence-gate.md) (still
  REGISTERED, Result section untouched); PR #444.
- **Next:** Decide whether Q11 runs as registered on an idle machine, or
  whether its registration is amended before any run to a cache-backed
  control — never after seeing a number.

## 2026-08-29 — Q11 run: the silence gate clears its registered bar

- **Try:** Execute the registered Q11 campaign — Q08's exact Qwen arm with
  and without the extended ordinary-silence gate, 3,600 paired evaluations,
  8×2 workers on AC, seeds 17/41/73, repetitions 1 (declared pre-run).
- **Learn:** Bad-when-shown fell 43.35% to 30.13% (−13.2pp against the 8pp
  target; every seed −12pp or better) with useful displays identical at
  473 and the sensitive slice untouched. The frozen-label prediction of
  ~30.03% matched measurement almost exactly. Parallel workers cut the
  wall clock from a projected four hours to seven minutes without touching
  a single label. Reviewed SUPPORTED as a development confirmation; the
  flag is a frozen validation candidate only.
- **Fail:** Net-keystrokes utility was flat (interval touching zero) — the
  suppressed displays were mostly typed through, and keystroke accounting
  cannot price interruption. The generic utility gate would not nominate
  this change; only the registered bad-when-shown rule does. The
  interruption-cost question is live-instrument work, not offline work.
  Also recorded: an instruction to run the control on production Gemma was
  wrong and was refused pre-run — the registration's Q08 anchor governs.
- **Where:** [Q11](../experiments/Q11-ordinary-silence-gate.md); campaign
  D4DFEA6A (owner-only local state); detectors from PR #438.
- **Next:** Register scene-echo precision + grounding as the next
  display-policy question; the silence flag waits for protected validation.

## 2026-08-29 — Batch shakedown catches a miscount on its first invocation

- **Try:** Run the full mega-run pipeline in miniature — 8 scenarios, 5
  personas, real local generation, an external frontier decision policy at
  batch size 10 — before trusting it with tens of thousands of moments.
- **Learn:** The harness's fail-closed count check worked on first contact:
  the model answered 11 decisions for 10 moments and the run refused the
  batch instead of mis-assigning decisions. Stating the exact expected count
  in the adapter prompt and re-verifying the count adapter-side before
  submission fixed it; the rerun completed 161 batched decisions cleanly in
  4.7 minutes with the report confirming zero raw text, zero network
  inference, and the simulated-decision-layer fence intact. The five
  personas produced plausibly distinct behavior (accepts 0–7.1%,
  type-through 63–86%).
- **Fail:** Machinery proof only — the suite was legacy replying-v1 and the
  personas are uncalibrated, so none of the quality numbers are findings.
  A second external adapter (Cursor backend) needed the same count
  hardening from birth.
- **Where:** GitHub issue #437; batch runner from PR #442; local decision
  adapters (owner-only).
- **Next:** The first full-scale two-brain persona run, chained behind Q11
  on the same idle-machine window.

## 2026-08-29 — Calibrate the simulated typist against 1,082 live moments

- **Try:** Run two frontier decision brains (Luna via Codex, Grok via
  Cursor, ten workers each) over every live text-free outcome moment and
  score them against the owner's actual behavior; then fix the persona
  from what the misses taught and rerun the missed slice with controls.
- **Learn:** Skips are trivially predictable (100% both brains); accepts
  are the signal. Luna 68.3% on accepts, Grok 47.6%, inter-brain
  agreement 98.4%. Every Luna miss sat in one cell — mid-word exact
  completions, the owner's signature accept, which the hand-written
  persona wrongly called an interruption. Two measured persona sentences
  (long dwell ends in acceptance; short exact mid-word completions are
  the favorite accept) took the missed cell from 2/28 to 28/28 with
  typed-through controls holding 15/15.
- **Fail:** The perfect post-fix score is in-sample — the fix was derived
  from the same moments — so it is calibration, not validation. The
  persona must hold on fresh out-of-sample typing before the simulator
  earns its registered graduation test (predicting the H01 winner ahead
  of the live result). The ignored control was thin (one eligible
  moment); nearly all mid-word ignores are sub-200ms flickers.
- **Where:** GitHub issues #437 and #443; local decision adapters and
  fleet aggregates (owner-only); batching runner in PR #442.
- **Next:** Score the frozen persona v2 on the next fresh week of live
  moments before any screening use.

## 2026-08-29 — Q11 registered: gate the three leaking silence subcategories

- **Try:** Pre-register the display-policy comparison for the extended
  ordinary-silence gate (built in PR #438) before its decisive run: 8pp
  bad-when-shown target, 99.5% useful retention, 1% per-category loss
  budget, paired identical generations, frozen provenance.
- **Learn:** The registration writes down the overfitting problem plainly:
  the detectors were developed against the same development categories, so
  the dev confirmation is expected to pass and can only nominate a frozen
  validation candidate, never promote.
- **Fail:** Not yet run. The campaign needs an idle machine, so it waits
  for a window when the owner is not typing.
- **Where:** [Q11](../experiments/Q11-ordinary-silence-gate.md); detectors
  in PR #438; evidence basis in the two entries below.
- **Next:** Run Q11 on the next idle window and review it before any
  scene-echo work begins.

## 2026-08-29 — Mine every campaign for chronic versus configuration failures

- **Try:** Read all 14 observation-bearing campaign databases (~468k
  scored observations) plus the 598 archived report files (~1.03M cases,
  including the Gemma era) read-only, and classify every category as
  chronic, configuration-sensitive, or healthy.
- **Learn:** Five intent failures are chronic across both model families
  and every sampling knob — acknowledge.delay, contradiction.latest-fact,
  commit.delivery, answer.location, correct.time — all one skill: tracking
  the newest fact. The three ordinary-silence subcategories are pinned at
  ~100% in all 17 arm cells. The largest untreated loss is over-suppression:
  scene-echo silences 100% of two legitimate reply categories for zero
  bad-display gain, and the injection gate blocks 100% of its legitimate
  test category. Grounding was the only display knob to move a pinned
  failure (91.7%→54.2%); the confidence filter is at its ceiling; length
  caps did nothing and the three-word cap worsened silence leakage.
  Sensitive-scene suppression is perfect in every era and arm.
- **Fail:** Discovery, not a registered result: seven truncated
  silence-only campaigns cannot be pooled with full-suite ones, and the
  Gemma/Qwen comparison is unpaired across eras. No queue or stage change
  from this sweep alone.
- **Where:** local campaign stores (owner-only); target list frozen in
  GitHub issue #443; Q11 registration above is the first consequence.
- **Next:** After Q11, register the scene-echo precision + grounding
  question — the mining sweep's top recommendation.

## 2026-08-30 — Q12 supported, Q13 rejected: the filters were the fix; the cap was not

- **Try:** Run the registered Q12 (scene-echo floor 10→24 crossed with
  names-and-numbers grounding) and, at the owner's direction, Q13 (visible
  cap 3 vs 8 on the winning arm), each as clean paired campaigns.
- **Learn:** Q12 confirmed the offline replay to ±1 display: useful 473→765
  (+62%) at unchanged bad displays from the echo retune alone, and 35
  wrongs removed free by grounding; bad-when-shown 30.2%→18.2%, net
  keystrokes saved 11%→20%. Both arms nominated as validation candidates.
  Q13 answered the cap question emphatically the other way: cap-8 halved
  useful (766→396), tripled bad-when-shown (18.1%→48.9%), and halved NKS —
  the 3-word cap is what keeps only the reliable head of each generation
  visible. First Q12 run was correctly flagged dirty-source-tree (an
  uncommitted registration) and preserved as non-promotable; the clean
  rerun matched it exactly.
- **Fail:** The generic paired-utility comparator scored Δ0.00 while arm
  aggregates doubled NKS — its keystroke-credit definition ignores
  recovered acceptable-alternative displays and needs its own
  investigation before anything leans on it. All results remain
  development-grade nominations; protected validation and live proof are
  still ahead.
- **Where:** [Q12](../experiments/Q12-scene-echo-grounding.md),
  [Q13](../experiments/Q13-visible-cap-3v8.md); campaigns 177E07E5 and
  2C57D9F3 (owner-local).
- **Next:** Protected validation for the echo-24-grounded candidate, and
  the comparator credit-definition audit as a small instrument question.

## 2026-08-30 — The floor's cause found: our own filters eat the facts

- **Try:** Re-judge Q11's 1,110 cached raw Qwen candidates offline under
  variant judgment configurations (no inference, Lab state read from a
  copy; replay reproduces the shipped report exactly) to decide whether
  the fact-free floor is model-side, prompt-side, or filter-side.
- **Learn:** The withholding story reverses: 66% of raw candidates
  already satisfy every required term and 75% carry a scene anchor. The
  scene-echo detector killed 304 candidates and every single one was a
  fact-carrier — its floor (3 words / 10 chars) sits exactly on the
  3-word display cap, so short correct verbatim answers are
  indistinguishable from echo. Offline: retuning echo to 10→24 characters
  alone yields +292 useful (+62%) with zero measured cost on any slice;
  adding names-and-numbers grounding removes 32 wrong for free; stacked,
  bad-when-shown falls 30.1%→18.1% and useful rises 473→765. A third
  mechanism: reply.commit.delivery loses its fact to the 3-word
  truncation (fact present in every wrong shown raw). Genuine model-side
  factlessness is only ~10% of opportunities (acknowledge.delay,
  contradiction.latest-fact raws carry no anchor). The visible-text form
  of "no fact, no ghost" is destructive (−56% useful); only the
  raw-candidate form is viable, scoped and sequenced after the filter
  fixes. Longer visible windows are not the fix (words 4–6 add 61–148
  wrong).
- **Fail:** Development-grade offline re-judgment of one arm on the dev
  suite; the ~60% persona-sim floor is a different instrument, so
  30.1%→18.1% is directional for it, not a substitution. Yesterday's
  "withholding, not forgetting" mechanism entry overstated the
  model-side share; this entry supersedes its emphasis.
- **Where:** rig in owner-local scratch; issues #447 (reframed) and #448
  (deprioritized); scene-echo thresholds in LabGenerationControls;
  detector in LabOutputJudge.
- **Next:** Register the two-factor display-policy experiment — scene-echo
  minimum characters 10→24 crossed with names-and-numbers grounding — as
  Q12, ahead of everything else in the queue.

## 2026-08-30 — Three-way model portrait: size loses again

- **Try:** Complete the fair same-judge persona comparison with Gemma 4
  26B A4B Q4_K_M alongside production Gemma E2B and Qwen 9B.
- **Learn:** The 26B came last: ~67% wrong-when-shown (vs ~61/60),
  accepts and retained value at or below the tiny production model.
  Third independent confirmation that parameter count does not predict
  quality in this stack (ledger `model-size-and-quantization` called it
  months ago). Qwen 9B remains the only generator materially above
  production, and active-parameter count (~4B in the MoE) tracks the
  outcome better than total size.
- **Fail:** Registered prediction missed again (called it between E2B and
  9B; it landed below E2B) — 1-for-6 on model predictions across the
  night. Discovery-grade, uncalibrated personas, fenced.
- **Where:** owner-local simulated reports; fair-rerun entry above for
  method; prompt/filter deep-dive running as the follow-up.
- **Next:** The generator-side fix hunt moves to the prompt scaffold and
  filter pipeline, which would lift every model including the shippable
  small one.

## 2026-08-30 — The shared floor autopsy: withholding, not forgetting

- **Try:** Cross-examine Q11's fresh Qwen per-case labels (1,800
  silence-gate-off cases) against 71 config-matched Gemma v4 reports
  (~78k shown cases, same certified suite) to pinpoint what the two
  models' chronic failures share, signature by signature.
- **Learn:** The floor is deterministic, not stochastic: per scenario the
  outcome is uniformly all-wrong or all-useful across every seed,
  temperature, and sampler ever tried — an argmax property, which is why
  the entire sampler-sweep era moved nothing. Both models share three
  signatures with matching proportions: fluent continuations carrying no
  fact at all (off-path from word 1; the largest bucket, and the same
  mechanism as the ordinary-silence over-triggering), correct first word
  then a generic swerve at the entity slot (89–95% of commit.delivery
  failures in BOTH models), and genuine stale-fact import confined almost
  entirely to reply.correct.time. The "loses the newest fact" framing was
  mostly wrong — the shared disease is base-model generic-continuation
  bias: the required entity is a low-prior token and pretraining prefers
  the safe filler even when the fact is present in the prompt (the
  fact-anchor prompt arms left all five categories at 100% bad while only
  moving exactMatchAt1). Scale only changes which categories the fact
  happens to win; the objective is the disease.
- **Fail:** requiredTermsSatisfied is necessary-not-sufficient (false on
  most useful three-word prefixes too), so it can gate but never score.
  The mechanism ranking is offline and interpretive; no registered
  experiment has yet tested the implied interventions.
- **Where:** Q11 campaign store and Runs archive (owner-only, aggregate
  analysis); intervention candidates filed as GitHub issues; earlier
  chronic-failure sweep entry below for the category-level view.
- **Next:** Register the required-term-aware quiet gate ("no fact, no
  ghost") as the display-policy question after scene-echo precision, and
  hold entity-slot constrained decoding behind it.

## 2026-08-30 — Fair rerun: the judge bug hid Qwen's real advantage

- **Try:** After discovering that a persona-brief rule ("dismissed twice =
  stopped reading") cascaded against Qwen's longer suggestion style, remove
  the rule and rerun both generators with byte-identical judges over the
  same 240 scenarios and five personas.
- **Learn:** Three results. (1) The ~60% wrong-when-shown floor is
  model-independent for the third time — it survived the judge fix too.
  (2) The rigged run's verdict inverted: judged fairly, Qwen delivers
  roughly 2–3x the retained-character value (persona range 6.1–10.2% vs
  Gemma's 2.5–4.4%), with 2.5x longer accepted spans — but pays a ~25%
  correction tax on accepted characters, draws ~5x the active dismissals,
  and surfaces half the moments. Quieter, richer, more annoying when
  wrong, and still slower to generate. (3) Absolute simulated rates moved
  substantially when one judge sentence changed, so only same-judge paired
  comparisons mean anything; cross-run absolute numbers are not comparable.
- **Fail:** The first Qwen comparison shipped to chat with an instrument
  artifact that suppressed the very effect it was measuring; caught by an
  owner "are you sure?" and a totals audit, not by the harness. Session
  abandonment mechanics (dismissal cooldowns eating half of Qwen's
  moments) remain a confound the skip-mode-era engine should surface
  explicitly. All numbers stay discovery-grade and fenced.
- **Where:** issue #437; owner-local reports; skip-mode + model provenance
  in PR #446 were built the same night from these failures.
- **Next:** Once calibrated personas exist, rerun this pair as the
  simulator's first ranking-agreement exercise against live evidence.

## 2026-08-30 — Batch the simulated typist's decisions across sessions

- **Try:** Add a text-free batch contract
  (`tilde-lab.typist-moment-batch.v1` → `tilde-lab.typist-decision-batch.v1`)
  and a `--decision-batch-size N` option so an external LLM-backed policy
  resolves up to 100 moments per process invocation instead of one.
- **Learn:** Batching and the sequential keystroke driver only coexist if
  the grouping is decision-independent: within one persona/scenario pair a
  decision moves the cursor, the cooldown, and the display and dismissal
  counts the next moment reports, so the engine had to be re-cut into
  per-pair sessions that are advanced to their own next undecided moment
  and batched *across* sessions, at most one moment per session per round.
  With that invariant a batched run reproduces the batch-size-1 aggregates
  exactly, and position can safely be the only correlation in a contract
  that has no identifier it is allowed to carry.
- **Fail:** Infrastructure only — no result, no LLM policy, no calibration.
  The 100k-moment overnight run is now affordable but has not been run, and
  nothing here makes a simulated number any less fenced. A count mismatch
  or a reordered answer from a policy is refused rather than repaired, so a
  sloppy external command will abort a long run instead of quietly
  corrupting it.
- **Where:** issue #437 stage 2; `Sources/TildeLabKit/Simulation/`;
  `Sources/TildeLabCLI/SimulatedTypistCommand.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) § Simulated typist.
- **Next:** Stand a real cheap-model policy behind the batch socket and
  score sim-vs-live ranking agreement before trusting any simulated order.

## 2026-08-29 — Resolve the simulated typist's batches concurrently

- **Try:** Add `--decision-workers N` (1...16, default 1, external-command
  policy only) so up to N decision-policy calls of one round are in flight at
  once, and record the count in the simulated report.
- **Learn:** Concurrency needed no new correctness argument, only the one
  batching already made: a round collects at most one moment per
  persona/scenario session and its batches partition that round, so parallel
  calls cannot touch one timeline any more than one batch could. What did
  need care is where the parallelism is allowed to reach — moments are
  collected before the round, decisions are applied after it joins, in batch
  order — which is what keeps a concurrent run's per-persona aggregates
  byte-identical to the sequential run's rather than merely close. The
  external command was already concurrency-safe (own process, pipes, buffer,
  environment per call); we verified that instead of assuming it, and the
  round now asserts the no-collision invariant rather than trusting it.
- **Fail:** Infrastructure only — no result, no LLM policy, no calibration,
  and nothing here makes a simulated number any less fenced. Throughput is
  still bounded by whatever the owner's decision backend tolerates; 16 is a
  guess at a safe ceiling, not a measured one, and no overnight run has been
  made to find the real one. A failing batch still aborts the whole run, so
  concurrency multiplies the work one flaky command can throw away.
- **Where:** issue #437; `Sources/TildeLabKit/Simulation/`;
  `Sources/TildeLabCLI/SimulatedTypistCommand.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) § Simulated typist.
- **Next:** Stand a real cheap-model policy behind the socket and measure what
  concurrency it actually sustains before sizing a 100k-moment run.

## 2026-08-29 — Simulated-typist stage 1: build the skeleton, trust nothing

- **Try:** Build `tilde-lab simulate-typist` — five checked-in synthetic
  personas, a character-level keystroke driver that replays a scenario's
  golden continuation through the real prompt composer, generation runner,
  production cleaner, and Lab display judge, and a pluggable
  `TypistDecisionPolicy` with a frozen deterministic heuristic plus an
  external-command shim whose JSON contract is text-free by schema.
- **Learn:** The decision layer can be separated from the stack cleanly:
  the driver reuses the existing checkpoint-expansion machinery at
  character resolution, and every feature a policy needs at a display
  (length bucket, prefix-match state, persona traits, time since display,
  confidence bucket) is expressible in buckets, booleans, and counts — so
  a future cloud policy can never be handed writing.
- **Fail:** No LLM backend and no calibration. The simulated numbers are
  the heuristic's own assumptions reflected back; the report is fenced
  with the new `simulated-decision-layer` evidence reason and cannot enter
  a comparison. Until the sim-vs-live ranking-agreement protocol in issue
  #437 runs, these aggregates are untrusted and must not reorder anything
  that matters.
- **Where:** issue #437 stage 1; `Sources/TildeLabKit/Simulation/`;
  `Sources/TildeLabCLI/SimulatedTypistCommand.swift`;
  [`docs/tilde-lab.md`](../tilde-lab.md) § Simulated typist.
- **Next:** Run the simulator on situations mirroring the owner's live F03
  weeks and score sim-vs-live ranking agreement before any other stage.

## 2026-08-29 — Pre-register the early-start timing falsifier

- **Try:** Register Q10 — start one hidden continuation after the third
  character of a word instead of at the following space — freeze issue
  #434's sketch gates into numbers (ready by boundary >= 50%, median lead
  >= 200 ms, lockable >= 15%, simulated false locks < 2%, compute <= 1.5x,
  pair coverage +5pp at <= 2x), and build the aggregate-only replay runner
  on the production Gemma stack.
- **Learn:** Nothing about efficacy yet. Two protocol facts came out of the
  4-situation machinery smoke and changed the registered definitions before
  any run: a branch that survives to the boundary answers the boundary even
  when it is too short to display, so compute must charge the fallback only
  for late or contradicted branches; and the false-lock check has to compare
  scalars after the same whitespace trim the lock rule uses, or it counts its
  own normalization as a false lock.
- **Fail:** Q10 is registered and built but not run, so it supports nothing.
  The smoke also showed the production cleaner suppressing a real share of
  mid-word candidates and mid-word requests decoding longer than boundary
  requests; if those hold at 360 situations, Q10 may fail its compute gate
  for a reason that is about the cleaner and the stop rule, not about
  timing.
- **Where:** [`docs/experiments/Q10-early-start-timing-falsifier.md`](../experiments/Q10-early-start-timing-falsifier.md);
  issue #434; PR #441.
- **Next:** Run `--early-start-full` overnight on AC power with no live
  dogfood typing, then review it against the five frozen gates.

## 2026-08-29 — Build the H01 block-randomization harness, shipped disabled

- **Try:** Build, but do not start, the instrument H01 will need: a
  seeded AB/BA block randomizer in `TildeCore` with a persisted schedule,
  a Model-Preview-only wire-up that lets an arm drive the visible-word
  cap, arm tagging on the existing text-free v3 event's `variant` field,
  and a `tilde-lab online-report --by-arm` slice so the two arms can be
  compared from ingested counts.
- **Learn:** The v3 event already carried champion/challenger, so H01
  needs no second telemetry store — only a producer that stamps the arm
  and an instrument plan that admits a displayed challenger. Pinning the
  arm to the typing session and sending the arm identity (never a
  number) over the local socket keeps the two processes from disagreeing
  about what the writer actually saw.
- **Fail:** H01 is not started and nothing here is evidence. The harness
  is OFF by default and inert in every profile except an explicitly
  enabled Model Preview; Stage 0 still gates the experiment, and F03 is
  still IMPLEMENTING, not supported.
- **Where:** `Sources/TildeCore/Policy/H01BlockRandomization.swift`,
  `Sources/TildeLabKit/Models/LabInstrumentCampaign.swift`, PR "lab: build
  disabled H01 block-randomization harness for the Model Preview".
- **Next:** Finish F03 on-device ingest to SUPPORTED — then, and only
  then, pre-register H01 and turn the toggle on.

## 2026-08-29 — Build the three missing ordinary-silence detectors behind a Lab flag

- **Try:** Add complete-sentence, multiple-question, and ambiguous-reference
  detectors to `SceneSuggestionPolicy` as a development-only
  `extendedOrdinarySilenceGate` option (off in production, exposed on
  `LabJudgmentConfiguration` and in the Policy Bench), then measure them
  offline against the certified V2 corpus with the flag off and on.
- **Learn:** The three leaking subcategories are reachable with deterministic
  pre-inference rules: 0 of 90 target scenarios are gated today, 90 of 90 with
  the flag on (30/30 per subcategory), while 0 of 600 wanted-suggestion
  scenarios become newly suppressed and the only pre-existing positive
  suppression (`stress.prompt-injection.real-request`) is unchanged; 0 of the
  positives in the 400-case replying suite, the Slack gold suite, and the
  synthetic corpus suite are newly suppressed either. The multi-question rule
  only holds because it stands down when the writer names which question they
  are answering — without that it would swallow the disambiguated
  multi-question stress positives by design.
- **Fail:** This is discovery infrastructure, not a registered result. No
  hypothesis is registered, no campaign was run, no model was queried, and the
  bad-when-shown improvement predicted in issue #436 is a relabel of frozen
  Q08 evidence, not a measurement made here. Production behavior is unchanged.
- **Where:** issue #436; branch `claude/silence-gate-detectors`;
  `Sources/TildeCore/Scene/SceneSuggestionPolicy.swift`;
  `Tests/TildeLabKitTests/LabExtendedSilenceGateTests.swift`.
- **Next:** Register the display-policy experiment that compares the flag off
  and on on the exact same test, so the useful-loss budget is decided before
  the result is known.

## 2026-08-29 — F04: freeze ten known failures as toothed regression cases

- **Try:** Implement the sanitized permanent regression library:
  ten deterministic cases with stable IDs, each requiring the frozen guard
  to hold AND the historical loophole to stay reproducible under its named
  unsafe arm, running inside `swift test` so fast proof blocks on them.
- **Learn:** Every scoring loophole from `qwen-9b-scoring-confounds` and
  every interaction failure class could be represented synthetically with
  existing deterministic machinery (LabOutputJudge, the scene freshness
  gate, the prompt composer, the interaction evidence analyzer, the stable
  stream prefix). The two-sided pass rule caught two toothless first
  drafts during implementation, which is exactly the failure mode it exists
  to prevent.
- **Fail:** The repeat-penalty case guards the cleaner's deterministic
  self-repetition protection, not the sampler distribution — a model-level
  repeat sweep would still need its own registered experiment.
- **Where:** [F04](../experiments/F04-sanitized-regression-library.md);
  `Sources/TildeLabKit/Scoring/LabPermanentRegressions.swift`; ledger queue
  `sanitized-regression-library` → completed-foundation.
- **Next:** Judge F03 on a clean live count file from the rebuilt IME; that
  is the last open Stage 0 exit condition.

## 2026-08-29 — Q08's cached labels say where the 43% bad rate lives

- **Try:** Re-read Q08's 57,600 stored per-case labels (read-only, no new
  inference) to decompose bad-when-shown by loss bucket, scenario family,
  and candidate length.
- **Learn:** The 43.29% splits into exactly two causes of similar size.
  Display losses (48.2% of bad) are entirely ordinary-silence leakage:
  three scene subcategories — complete-sentence, multiple-questions,
  ambiguous-reference — leak nearly 100% while sensitive silence is
  perfect and contribute zero useful displays, so suppressing them is pure
  gain; relabeling the existing evidence puts bad-when-shown at ~30% with
  useful unchanged. Intent losses (51.8% of bad) are required-term
  omissions on wanted replies, concentrated in a dozen roots and in
  three-word candidates (47.1% bad at 3 words vs 5.3% at 1 word);
  1,040 wrong cases even open with the exactly right first word before
  dropping the required term. The two causes live in disjoint slices, so
  they need two separate fixes.
- **Fail:** All labels come from one deterministic synthetic configuration
  on development roots; the rates are not production estimates, and the
  relabeling is a hypothesis, not a run. No experiment is registered yet.
- **Where:** Q08 campaign store (local, owner-only);
  [Q08](../experiments/Q08-prompt-cache-study.md) for the workload.
- **Next:** Decide whether to pre-register a scene-gate extension for the
  three leaky ordinary-silence subcategories as the next offline question.

## 2026-08-29 — First live F03 ingest finds a resurrection bug

- **Try:** Ingest the first real typing evidence — 734 v3 outcome events
  written by the daily-driven Model Preview IME — with
  `tilde-lab ingest-events --instrument`.
- **Learn:** The instrument works on live data and fails closed as designed:
  two accept-delete-retype events claimed more retained characters at a later
  horizon than at 5 seconds, because prefix matching counts retyped text as
  retained. The remaining events ingested into a scratch database and reported
  cleanly (7.7% acceptance when shown, 232 typed-through). Missingness reads
  correctly once split by outcome: every not-yet-observed later horizon
  belongs to a non-accepted event where retention is vacuous, while accepted
  events had full segment-close coverage and 43 of 58 honestly reported
  segment-closed-early at 30s — the owner's writing segments usually end
  before 30 seconds. RNKS-segment looks like the usable live horizon;
  RNKS-30s may be structurally sparse for this writer.
- **Fail:** The full-file ingest was rejected by the two resurrection events;
  F03 stays not supported until a clean full-file ingest exists. Fixed the
  same day: `RetainedSpanWatch.monotone` now clamps 30s and segment-close
  observations so deleted characters cannot resurrect, with tests.
- **Where:** [F03](../experiments/F03-retained-outcome-ledger.md);
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`,
  `Sources/TildeCore/Policy/LiveOnlineOpportunity.swift`,
  `Tests/TildeCoreTests/RetainedSpanWatchTests.swift`.
- **Next:** Rebuild the daily-driver IME with the clamp, collect a fresh
  count file from real typing, and judge F03 on a clean full-file ingest.

## 2026-08-29 — Push the Future Lattice to sixteen branches

- **Try:** Pre-register and run one nested Qwen candidate-set test at K=1, K=4,
  K=8, and K=16 on all 360 speak-expected development situations, after a
  20-situation machinery pilot. The owner explicitly authorized the
  battery-powered run.
- **Learn:** More branches improve set-level exact-prefix coverage, but the
  curve is nearly flat after eight: K=8 found 163 golden paths and K=16 found
  168. Sixteen branches reached 46.67% coverage yet produced a median of only
  two distinct first-two-content-word paths; just 27.22% of sets reached four.
  Candidate readiness was 3,593 ms p50, with 49.12x K=1 summed request latency.
- **Fail:** K=16 failed the registered diversity gate and median-four kill
  rule. Battery power and fair thermal state make latency directional, but the
  rejection does not rely on latency. Do not build 16 independent futures into
  the IME or try a larger K.
- **Where:** [Q09](../experiments/Q09-future-lattice-k16-feasibility.md),
  [aggregate result](../experiments/Q09-aggregate-results.json), ledger
  `future-lattice-k16-independent-branches-rejected`, PR #432.
- **Next:** Return to the ordered queue. If the Future Lattice becomes eligible
  later, preregister a smaller or genuinely diversity-producing shared
  generator before any target-blind lock or typing-window experiment.

## 2026-08-28 — Prefix reuse engaged but missed the tail-latency target

- **Try:** Complete Q08's 57,600 matched synthetic evaluations with cache off
  versus on, 40,704 fresh generations, one worker/slot and no response cache.
- **Learn:** Median response improved 348 to 334 ms, but p95 only 429 to
  427 ms: 0.47%, with paired counterfactual-cluster 95% interval 0.00–0.93%.
  Real cache engagement does not imply a meaningful tail-latency improvement.
- **Fail:** Reject the registered 10% p95 target. Scored quality was identical
  and both arms failed absolute bad-suggestion quality (43.29% bad/shown).
  Memory looked stable but one arm-block missed coverage; only 42 roots
  qualified for quiet sensitivity. Neither limitation is waived.
- **Where:** [Q08](../experiments/Q08-prompt-cache-study.md), its aggregate
  evidence and analyzer; ledger `qwen-prefix-cache-tail-target-rejected`.
- **Next:** Preserve the negative result. Any typing-sequence follow-up needs
  a new approved protocol; no production, preview, or protected-stage change.

## 2026-08-28 — Prompt-cache pilot expired; full study initially blocked

Follow-up: the owner renewed execution. The separate
[Q07B AC pilot](../experiments/Q07B-cache-ac-pilot.md) completed all 1,200
evaluations and 848 fresh requests in 302.643 seconds, with valid memory
coverage, no runtime errors and complete reports. Both arms still failed
absolute quality; the review is inconclusive for superiority. Its functional
readiness gate permits the separately registered Q08 run, not production.

- **Try:** Run matched synthetic Qwen cache-off/on arms with fresh inference,
  balanced blocks and process-memory sampling under a 15-minute limit.
- **Learn:** Native cached-token counters engaged only for cache-on in observed
  intervals; a UUID-case attribution bug needs a real SQLite regression test.
- **Fail:** The budget expired at 3,299/3,600 evaluations and 2,388 actual model
  requests, producing no complete reports. Mixed power, concurrent preview
  and build load, and missing early sample labels prohibit a speed verdict.
- **Where:** [Q07](../experiments/Q07-prompt-cache-pilot.md); the later
  [Q08](../experiments/Q08-prompt-cache-study.md) result is recorded above.
- **Next at the time:** Ask the owner to approve a smaller fixed AC pilot
  without a simultaneous build. The approved Q07B follow-up above did that;
  this aborted Q07 campaign was never extended or resumed.

## 2026-08-27 — Confirm a bounded confidence-filter effect on more roots

- **Try:** Freeze cutoff 0.475 against the identical cached Qwen outputs on 505
  development roots, with 473 non-pilot roots primary, three seeds and 3,030
  scored evaluations; cluster uncertainty by counterfactual pair and root.
- **Learn:** Bad displays fell 413 to 299 while useful displays fell 389 to
  388; the pre-registered relative-effect and protected-slice rules passed.
- **Fail:** Both arms still failed absolute bad-suggestion quality; 43.52% of
  filtered displays scored bad. Existing templates do not prove live utility.
- **Where:** [Q06](../experiments/Q06-confidence-filter-followup.md); ledger
  `qwen-confidence-filter-bounded`.
- **Next:** Preserve the offline lesson and finish the existing retained-outcome
  instrument before considering any live policy change.

## 2026-08-27 — Repair confidence capture and reject the pilot selection

- **Try:** Probe the helper schema, fix selected-token log-probability parsing,
  verify cache round-trips, then run a 381-evaluation confidence pilot.
- **Learn:** Requested probabilities were previously not retained. After the
  repair, all 213 generated candidates had usable evidence; the selected 0.50
  cutoff removed 34.57% of bad displays while retaining 97.65% useful overall.
- **Fail:** The original cache could not support replay, and the pilot's selected
  policy lost 10.53% useful in the answer slice, above the fixed 10% limit.
- **Where:** [Q05](../experiments/Q05-confidence-filter-pilot.md);
  `Tests/TildeLabKitTests/LabTokenProbabilityTests.swift`.
- **Next:** Test the conservative point in a separately registered campaign;
  Q06 above records that authorized follow-up without rewriting Q05's failure.

## 2026-08-27 — Wire the live counter and a local word diary

- **Try:** Produce text-free v3 counts from the IME, keep accepted
  words in a second owner-only diary, and ingest keep versus rewrite
  with `tilde-lab ingest-events --instrument`.
- **Learn:** Lab can tell keep from rewrite from counts alone. The
  words the owner wants to reread cannot live on that event. Password
  managers must not emit a displayed-and-unsafe event, and a privacy
  wipe must not turn a real Tab into an ignored zero.
- **Fail:** F03 is still not supported. The IME is wired, but this
  Mac has not yet written events from ordinary typing.
- **Where:** branch `cursor/f03-live-ruler-and-local-diary`; ledger
  `score-counts-diary-words`.
- **Next:** Rebuild the daily-driver IME, type as usual, ingest the
  local count file, and only then decide if the promotion rule is met.

## 2026-08-27 — Hand the ruler to an on-device thread

- **Try:** Write down the cloud-vs-Mac split, the play-vs-decision
  rule, and a briefing so a new local thread can wire live ingest
  without rereading this chat.
- **Learn:** GitHub can hold the schema. Only a Mac can watch whether
  words stay. Config play is a hunch until one change wins on kept
  characters. First live bet after F03 is three words versus eight.
- **Fail:** F03 is still not supported. No live events exist.
- **Where:** [`next-on-device.md`](next-on-device.md); ledger
  `cloud-protocol-mac-live-split`.
- **Next:** In a new on-device thread, produce v3 counts from IMKit
  and ingest them locally.

## 2026-08-27 — Start F03 as the first deep-research object

- **Try:** Explain the ruler in plain language, then implement the v3
  text-free event, XOR horizons, typed-through, flicker floor, and
  coverage report with fixtures.
- **Learn:** Nothing durable about live writing yet. The schema can now
  tell keep from rewrite-after-Tab, and missing from zero, without
  storing words.
- **Fail:** Live IME ingest on a Mac is not done. F03 is not supported.
  Suggestion behavior is unchanged.
- **Where:** [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md);
  `Sources/TildeCore/Policy/RetainedCharacterObservation.swift`.
- **Next:** Wire a Mac-side producer that writes only counts, then see
  whether fixtures plus live ingest satisfy the promotion rule.

## 2026-08-27 — Save the lab so tries and failures persist

- **Try:** Make the colleague working agreement durable: a public lab log,
  a ledger decision, and pointers from the agent guides so the next session
  does not start from a blank chat.
- **Learn:** Chat is not memory. The ledger is too curated to hold every
  attempt. We need both: ledger for lessons, log for tries and fails.
- **Fail:** none yet for this save. The log only works if later sessions
  actually append.
- **Where:** this file; ledger `lab-partnership-and-failure-log`;
  [`lab-partnership.md`](lab-partnership.md).
- **Next:** Implement F03 against the pre-registered instrument protocol.

## 2026-08-27 — Pre-register F03 before building it

- **Try:** Write the F03 experiment record while the hypothesis is still
  unconstrained by an implementation.
- **Learn:** The v2 online event already has 5-second replacement. The
  missing science is 30s / segment, typed-through, settled-visible, and
  missingness that cannot look like zero kept characters.
- **Fail:** F03 is not implemented. Live RNKS still cannot support a
  decision.
- **Where:** [`docs/experiments/F03-retained-outcome-ledger.md`](../experiments/F03-retained-outcome-ledger.md).
- **Next:** Implement that protocol; do not start H01 until it is supported.

## 2026-08-27 — State the scientific program

- **Try:** Write the research stance: privacy-projected utility, learn the
  controller, treat Roy's skip result as an interaction hypothesis.
- **Learn:** Swapping in a newer GGUF would still be Smart Compose 2019.
  The new question is whether personal fit and scene grounding change
  skip for a fast desktop typist.
- **Fail:** none. This is a stance, not a result.
- **Where:** [`scientific-program.md`](scientific-program.md),
  [`where-the-field-stopped.md`](where-the-field-stopped.md).
- **Next:** Keep the generator frozen; finish the instrument.

## 2026-08-27 — Literature sweep for personal autocomplete

- **Try:** Catalog HCI, AAC, mail, Copilot, interruption, and agency
  papers we can actually run, with Tilde digests and run flags.
- **Learn:** Shipped personal keyboard papers stop at 2018–2020. Recent
  work is generic suggestion HCI or code-completion metrics. Desktop
  fast typists skip generic ghosts in transcription (Roy 2025). Tab
  tracks feeling (Ziegler) and still rewards deleted junk (GitHub 2025).
- **Fail:** The sweep is not a measured Tilde result. Several indexed
  papers still lack digests (see reading-list §10). We did not find a
  published on-device personal + screen + retained-character system.
- **Where:** [`docs/reading-list.md`](../reading-list.md),
  [`docs/research/`](./).
- **Next:** Use the catalog as priors; do not implement a paper.

## Earlier attempts already on record

These happened before this log existed. Do not rewrite them here; point
at the canonical record.

| Attempt | Outcome | Where |
| --- | --- | --- |
| F01 report provenance v6 | SUPPORTED | [`docs/experiments/F01-report-provenance-v6.md`](../experiments/F01-report-provenance-v6.md) |
| F02 campaign state reconciliation | SUPPORTED | [`docs/experiments/F02-campaign-state-reconciliation.md`](../experiments/F02-campaign-state-reconciliation.md) |
| Q01 Qwen God v1 replication | INCONCLUSIVE (runner died before a clean comparison) | [`docs/experiments/Q01-qwen-god-v1-replication.md`](../experiments/Q01-qwen-god-v1-replication.md) |
| Three-word cap on certified quiz | directional offline win; not live RNKS | Learning Ledger / `docs/learning-ledger.md` |
| Short-cap echo and repeat-penalty "wins" | rejected as scoring cheats | Ledger tags; F04 will freeze them |
| Million-eval Reply archive | depth in one lane, not product proof | Ledger `lab-evidence-coverage-gap` |

If you find an attempt that is only in chat, add a log block the same day.
A missing fail line is how this field forgot why Tab died as a metric.
