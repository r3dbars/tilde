# Tilde research roadmap

This document turns Tilde's autocomplete research into a staged public research
program. The machine-readable priority queue in
`Sources/TildeLabKit/Fixtures/learning-ledger-v1.json` remains the source of
truth for what is eligible to run next. This roadmap preserves the longer-term
hypotheses, their dependencies, and the conditions that must be met before they
enter that queue. Every attempt, including failures, is appended to
[`docs/research/lab-log.md`](research/lab-log.md).

The goal is not the highest next-token accuracy. It is:

> Maximize retained useful writing saved while minimizing wrong interruptions,
> latency, correction cost, loss of authorial control, and product risk.

## What the research synthesis changes

The strongest conclusion across predictive keyboards, Smart Compose, code
completion, accessibility input, cache language models, and Tilde's own Lab
results is that candidate generation is only one part of autocomplete. The
same sweep showed a second fact: the last shipped *personal* keyboard papers
are from 2018–2020. Recent work is HCI on generic suggestions or Copilot on
code. Tilde's unique shot is the combination those papers never published —
on-device personal memory, screen context, and retained characters without
stored writing, for a fast desktop typist. See
[`docs/research/where-the-field-stopped.md`](research/where-the-field-stopped.md)
and the scientific stance in
[`docs/research/scientific-program.md`](research/scientific-program.md).
That does not unlock later stages early. Tilde must still become an
intervention system that decides:

1. whether inference is worth running;
2. which source has the best candidate;
3. whether the candidate is useful enough to show;
4. how much of it is stable enough to reveal; and
5. whether the user retained the accepted text after continuing to write.

Several proposals from the research conversations already exist in the current
repository. The Tilde Lab CLI has a development/validation/holdout
firewall, resumable SQLite campaigns, interleaved paired comparisons,
root-clustered uncertainty, synthetic candidate caching, risk-coverage replay,
chronological personalization, text-free online events, confidence
calibration, interaction evidence, and soak gates. Rebuilding those systems
would be wasted motion.

The main remaining evidence gap is the live outcome loop. The current online
event can subtract text replaced within five seconds, but it cannot yet measure
30-second or segment-close retention. It also does not yet create a complete
privacy-safe record of every eligible, generated, shown, hidden, accepted,
typed-through, dismissed, corrected, and retained outcome. Until that loop is
trustworthy, a learned Control Brain would optimize an incomplete target.

## Corrections and boundaries from the repository audit

| Research idea | Current repository reality | Roadmap decision |
| --- | --- | --- |
| Build an Outcome Ledger | Text-free online events and five-second replacement already exist | Extend the existing event contract; do not create a second telemetry system |
| Cache candidates and replay policies | Synthetic raw candidates are already cached locally | Reuse it for synthetic policy work; never put private prompts or candidates in that cache or in Git |
| Make Screen Memory optional or bypass it | Current product policy requires Screen Memory and answers with silence when unavailable | Test context quality and routing, not an opt-out product path |
| Use Accessibility or overlays to insert text | Tilde is an IMKit input method | Keep all presentation and insertion in IMKit; Accessibility may only read screen text under the Screen Memory covenant |
| Change the production model while testing policy | Production is pinned to Gemma 4 E2B; Qwen 9B is an isolated preview | Finish the bounded Qwen question, then freeze the generator during policy experiments |
| Train continually on private writing | Personal writing is explicit, local, encrypted, and user-controlled | Prefer counts, caches, retrieval, and calibration; no private text leaves the device for training or evaluation |
| Treat acceptance as ground truth | Tilde records acceptance but not durable retention horizons | Add retained outcomes before fitting a decision policy |
| Try every promising mechanism | The Tilde Lab CLI enforces one experiment class per campaign | Run one causal question at a time and unlock later stages only after exit gates pass |

## Public proof contract

### Metrics

Offline work keeps **Net Keystrokes Saved** as the headline and reports Human
Acceptable, Exact Path, Accepted Alternative, bad-when-shown, restraint,
factuality, temporal integrity, and latency separately.

Live work will add three retention horizons without immediately declaring a new
headline metric:

- `RNKS-5s`: accepted characters still present after five seconds, minus
  acceptance, correction, and dismissal cost;
- `RNKS-30s`: the same calculation after 30 seconds; and
- `RNKS-segment`: accepted characters still present when the writing segment
  ends through focus change, send/commit, or a privacy-safe inactivity boundary.

All three remain visible until baseline variance and missingness are understood.
Only then may one be frozen as the primary live metric. Acceptance rate remains
a diagnostic, never the sole promotion target.

### Hard gates

No average score can excuse any of these failures:

- private text or screen content in logs, reports, Git, or network traffic;
- suggestions while Screen Memory is disabled, permission is absent, Secure
  Event Input is active, or an excluded app is visible;
- wrong-window, wrong-thread, stale-snapshot, or future-text context;
- text corruption, duplicate insertion, focus leakage, or suffix damage;
- fact, name, date, number, or commitment errors outside the registered risk
  policy;
- visible semantic rewrites of an already displayed suggestion;
- a p95 or p99 latency, memory, thermal, or battery regression outside the
  frozen non-inferiority budget.

### Evidence discipline

- One campaign asks one causal question and changes one experiment class.
- Discovery uses development data only. Validation candidates are frozen;
  holdout is opened once for one candidate.
- One user-visible challenger may be active at a time. Infrastructure work may
  continue, but it cannot change the active treatment.
- A live result is not called meaningful before the registered 200, 500, and
  1,000-completion checkpoints and its required active-day window.
- Every result reports individual app/register slices and the worst protected
  slice, not only a pooled mean.
- Rejected and inconclusive results are published with the same prominence as
  supported results.

## Stage 0 — Make the evidence loop trustworthy

No new user-visible behavior should be promoted during this stage.

### F01 — Complete report provenance

Record the Git commit, dirty state, runner hash, OS and hardware class, power
state, exact invocation digest, written hypothesis, conclusion, and review
status. Old reports remain readable but non-promotable when those fields are
missing.

### F02 — Reconcile campaign state

Add explicit failed and aborted states, persist terminal errors, and reconcile
process, lease, work-item, and checkpoint state at launch. A PID or stale JSON
file must never be presented as progress.

### F03 — Extend the text-free Outcome Ledger

Extend `LabOnlineExperimentEvent` rather than creating a parallel store. At a
minimum record, without text:

- eligible, generated, displayed, and policy-hidden state;
- candidate source and length buckets;
- accepted-all, accepted-word, typed-through, dismissed, corrected, undone,
  and unavailable outcomes;
- retained characters at five seconds, 30 seconds, and segment close;
- time to next authored action, generation, and first stable word;
- app category, register, cursor boundary, typing-speed bucket, scene quality,
  freshness, recent intervention count, and confidence-feature coverage; and
- missing-retention reasons so unavailable evidence cannot look like zero
  correction.

The event must remain local, deletable, aggregate-reportable, and incapable of
containing prompt, candidate, screen, field, recipient, document, or personal
text.

### F04 — Freeze permanent regressions

Turn every known scoring loophole and interaction failure into a sanitized,
stable case: short-cap echo bypass, repeat-penalty aggression, wrong-scene
facts, stale-target delivery, prompt-example removal, factual-filter weakening,
duplicate insertion, focus changes, runtime restart, and marked-text damage.

### Stage 0 exit gate

Stage 1 opens only when:

- new long runs have complete reproducibility provenance;
- killed and crashed campaign fixtures reconcile truthfully;
- retained-outcome coverage and missingness are visible at all three horizons;
- the permanent regression suite fails known unsafe diagnostic arms and passes
  the frozen production control; and
- no checked-in artifact contains private text or a local path.

## Close the existing Qwen question

Qwen 9B is already an installed, isolated experiment. Do not abandon the work,
but do not let it consume the program.

1. Freeze God v1 and run protected validation against its exact baseline.
2. Open holdout only if every hard gate passes.
3. Treat existing live counters as directional. After F03, collect the
   registered 200/500/1,000 retained-outcome checkpoints.
4. Either promote Qwen to a continuing preview candidate or reject it. Do not
   start another broad model or quantization sweep until this decision closes.

The policy roadmap below uses production Gemma 4 E2B unless a separately
approved experiment explicitly freezes another generator. This prevents model
quality from masquerading as a policy effect.

## Stage 1 — Test the cheap, isolated product bets

Run in this order. Each treatment changes one mechanism only.

### H01 — Three visible words beat eight in live prose and replies

**Control:** production Gemma, prompt, cleaner, streaming, and eight-word cap.

**Treatment:** the identical stack with a three-word cap.

**Proof:** block-randomized local dogfood, RNKS-30s and RNKS-segment, wrong
displays, useful-opportunity recall, app/register slices, and interaction
integrity.

**Promote if:** retained utility improves and wrong displays fall without a
material loss of useful opportunities or a hard-gate regression.

**Kill if:** the offline gain disappears because useful live completions are
disproportionately truncated.

### H02 — Stop generating once the display-safe span is complete

**Control:** generate up to 20 tokens, clean the result, show at most three
words.

**Treatment:** stop at the third complete safe word or earlier natural boundary,
with a bounded punctuation allowance.

**Proof:** visible-output equivalence, dangling-fragment rate, p50/p95/p99
latency, cache behavior, RNKS, and cleaner decisions.

**Promote if:** at least 99.5% of visible outputs are equivalent, fragments do
not increase, and tail latency improves enough to matter.

**Kill if:** hidden tail tokens are required to detect repetition, invalid
grammar, or unsafe facts.

### H03 — Context-quality routing beats treating every scene alike

**Control:** current context selection.

**Treatments:** exact fresh Accessibility text, fresh redacted OCR, typed-only,
stale scene, wrong scene, and metadata-only, using frozen generation wherever
candidate replay permits it.

**Proof:** usefulness, factuality, wrong-scene leakage, latency, attribution,
redaction failure behavior, and foreground interaction.

**Promote if:** fresh correctly attributed context wins; stale and wrong context
cannot win; redaction and exclusion always fail closed.

**Kill if:** a more complex quality router adds no value over the current
deterministic source priority.

### H04 — Flow-aware refractory periods reduce interruption

**Control:** current activation and reveal-delay policy.

**Treatments:** cooldown after dismissal or typing-through, suppression during
fast typing, release at the next word boundary, and release after a meaningful
pause. Start with deterministic rules before learning the policy.

**Proof:** RNKS, suggestions per 1,000 authored characters, wrong displays,
next-action delay, repeated rejection, and missed shadow opportunities.

**Promote if:** interruptions fall with no meaningful retained-utility loss.

**Kill if:** the cooldown consistently hides the next genuinely useful
suggestion.

### Stage 1 exit gate

Freeze one live-proven length policy, one generation-stop rule, one context
router, and one timing baseline. Do not combine individually unsupported
treatments into a package.

## Stage 2 — Build the Control Brain

This stage is strictly sequential: H05 must establish the target before H06;
H06 must beat deterministic policy before H07 or H08 begins.

### H05 — Retained outcomes train a better policy than Tab presses

Fit otherwise identical chronological models to immediate acceptance,
five-second retention, 30-second retention, and segment retention. Evaluate all
of them against held-out RNKS-segment, post-accept editing, and blinded local
review. Stop if retention coverage is too sparse or adds no predictive value.

### H06 — A global learned quiet gate beats fixed thresholds

Freeze generation and compare the current deterministic display policy with a
small interpretable model. Start with calibrated logistic regression or an
isotonic scorecard; only try boosted trees if the simple model leaves stable
residual signal. Inputs may include text-free candidate, timing, scene,
personal-support, recent-outcome, app-category, and confidence features.

The first win target is fewer wrong displays at essentially preserved retained
characters, or greater retained utility at the same wrong-display rate. A model
that merely reproduces the hard gates is rejected as unnecessary complexity.

### H07 — A pre-inference gate skips work safely

Run the generator in shadow behind proposed skips so missed useful candidates
remain measurable. Compare always-invoke, deterministic pre-gate, and the
frozen learned pre-gate. Promote only if neural calls, energy, and thermal load
fall while at least the registered share of retained opportunities survives.

### H08 — Dynamic visible length beats every fixed cap

Compare fixed one-, three-, and eight-word caps with a monotonic controller that
may expose only longer prefixes as evidence strengthens. It must never shorten
or semantically rewrite visible text on a later keystroke. Reject the idea if
length changes flicker, feel unpredictable, or increase post-accept edits.

### Stage 2 exit gate

The global controller must pass chronological out-of-sample calibration,
protected offline validation, live retained utility, and every interaction
gate before personalization changes its decisions.

## Stage 3 — Turn Personal History into small experts

Run these only with Personal History enabled and under its existing local,
encrypted, deletable covenant.

### H09 — Hierarchical personal memory beats one global or per-app model

Compare global, register, app, and smoothed hierarchical backoff across one- to
four-word contexts. Use chronological replay and report names, acronyms,
repeated phrases, chat, email, prose, and novel-writing slices separately.

### H10 — A decayed recent cache adds value beyond lifetime counts

Compare lifetime counts with session, hour, day, week, and learned decay.
Names and entities may decay differently from ordinary phrases; dates,
numbers, and commitments receive the strongest stale-value protection.

### H11 — An exact phrase expert beats next-word-only personalization

Add a deterministic repeated-phrase candidate with support, winner margin,
scope, freshness, and historical-retention evidence. First run it in shadow.
Promote only if it improves complete-phrase retained value without surfacing
secrets, stale facts, or cross-register language.

### H12 — Strong personal memory may speak when Gemma is silent

Permit this only after H11 proves a narrow eligibility rule. Compare current
base-silence behavior with exact high-support personal phrases under strict
fact, recency, scope, and recent-rejection blocks. Any creepy, stale, or
socially inappropriate output kills the visible treatment.

### Stage 3 exit gate

Personal experts must improve chronological and live personal slices without a
novel-writing regression. Deleting Personal History must remove the derived
state, calibration, and experiment evidence required by the privacy contract.

## Stage 4 — Test agreement, Consensus Prefix, and Future Lattice

These are promising architectural ideas, but they are not first experiments.

### H13 — Independent candidate agreement predicts retained value

Measure Gemma, personal phrase, higher-order n-gram, recent-cache, and
character/prefix candidates separately. Test whether agreement adds predictive
power after controlling for length and single-source confidence. If the experts
are too correlated, stop here.

### H14 — Consensus Prefix is safer than a truncated top-one future

Compare top-one full, top-one three-word, probability truncation, exact shared
prefix, and weighted consensus prefix. Promote only if consensus produces more
retained text with fewer wrong displays and zero visible rewrites. Generic or
one-word shared prefixes are not a win.

### H15 — A precomputed Future Lattice hides latency and improves intent fit

Before the next keystroke, generate a small bounded set of intent-diverse reply
futures from a fresh scene. Replay the user's prefix one character at a time and
measure top-k intent coverage, characters typed before branch lock, false
locks, compute cost, and time to first useful ghost. Build live precomputation
only if offline top-k coverage and consensus-prefix value are already strong.

### Stage 4 exit gate

Future generation must beat direct top-one generation after accounting for its
additional model calls, memory, heat, stale-scene risk, and branch-management
complexity. Novelty alone is not evidence.

## Stage 5 — Moonshots, each in a separate preview

### H16 — A Tilde-native training objective beats a generic base model

Fine-tune on public, synthetic, and explicitly reviewable examples that teach
short stable continuation, abstention, noisy prefixes, safe infill, and
intervention-sized stopping. Do not train a model merely to reproduce the
remaining target text. Start only after the failure ledger shows repeated
generator errors that policy and retrieval cannot solve.

### H17 — A selection-only Edit Brain saves revision time safely

Begin with explicit selected-text replacement through IMKit. Measure time to
stable final text, undo rate, suffix preservation, selection corruption, and
host-specific failures. Do not add an Accessibility insertion or overlay path,
and do not expand to free-form mid-line edits until selection replacement is
boringly reliable.

### H18 — Personal shorthand can become a learned compression language

Search locally in shadow for repeated relationships between abbreviated
fragments and later authored phrases. Estimate potential savings and ambiguity
without displaying anything. The visible idea is killed if it requires users
to maintain a manual abbreviation dictionary or if ambiguity cannot be gated
conservatively.

## Explicitly deferred work

These ideas stay out of the active queue until the relevant stage gate opens:

- another broad sampler grid or random larger-model tournament;
- Qwen quantization work before the current Qwen decision closes;
- continual private LoRA training;
- an Apple Foundation Models production backend;
- semantic retrieval before exact phrase and recency experts are measured;
- whole-sentence prose suggestions before dynamic length proves safe;
- per-recipient identity storage before app/register hierarchy proves useful;
- free-form mid-line editing; and
- any change that combines generator, prompt, cleaner, display, and timing in
  one unidentifiable treatment.

## How results enter the repository

The publication workflow is defined in
[`docs/experiments/README.md`](experiments/README.md). In short:

1. pre-register a privacy-safe experiment record before the decisive run;
2. keep owner-only campaign state, raw synthetic candidate cache, private
   history, and local online events out of Git;
3. publish exact hashes, protocol, aggregate results, limitations, and the
   keep/reject decision;
4. add a Learning Ledger entry only when the result creates a reusable lesson;
   and
5. update the machine-readable queue only when evidence changes what should run
   next.

## Research basis

The roadmap uses primary sources as directional evidence, not as proof that the
same effect will transfer from mobile typing, email, or code to system-wide
macOS prose. The full catalog — including runnable-now versus parked flags — is
[`docs/reading-list.md`](reading-list.md). Longer Tilde-specific digests live in
[`docs/research/`](research/). Read the digest before fetching a paper.

A 2026-08-27 sweep added the HCI, AAC, interruption, Copilot-metric, and
writing-agency papers that the first digest set had only named. The claims
that survived that sweep, and the experiments they unlock, are listed at the
top of the reading list. Headline pointers:

- [Gmail Smart Compose](https://arxiv.org/abs/1906.00080) supports fast neural
  generation combined with a lightweight personal n-gram model.
- [When to Show a Suggestion?](https://arxiv.org/abs/2306.04930) treats display
  as a utility decision and shows why optimizing acceptance alone can select
  worse suggestions.
- [Sequential Decision-Making for Inline Text Autocomplete](https://arxiv.org/abs/2403.15502)
  motivates modeling the cognitive cost of interventions rather than using a
  language-model confidence threshold alone.
- [GitHub's accepted-and-retained completion metric](https://github.blog/ai-and-ml/github-copilot/the-road-to-better-completions-building-a-faster-smarter-github-copilot-with-a-new-custom-model/)
  supports measuring whether accepted text survives later editing.
- [Ziegler et al., MAPS 2022](https://doi.org/10.1145/3520312.3534864) is the
  matching warning: acceptance predicts how productive people *feel*, which is
  why Tab cannot be the promotion target.
- [Are Word Suggestions Beneficial?](https://doi.org/10.1145/3772716) reports
  that desktop fast typists mostly skip, and that speed only rises when
  suggestions are both highly accurate and the unaided typist is slow.
- [Quinn and Zhai, CHI 2016](https://doi.org/10.1145/2858036.2858305) is the
  ancestor cost-benefit result: always-on suggestions save taps and still lose
  on time.
- [Predictive Text Encourages Predictable Writing](https://www.eecs.harvard.edu/~kgajos/papers/2020/arnold20predictive.pdf)
  motivates explicit authorial-agency and voice checks.
- [Multi-line AI-assisted Code Authoring](https://arxiv.org/abs/2402.04141)
  shows that longer suggestions can save disproportionate input while creating
  latency and visual-stability costs that must be measured separately.
- [Improving Neural Language Models with a Continuous Cache](https://arxiv.org/abs/1612.04426)
  motivates a cheap recency expert before any continual neural retraining.

The repository's own [Tilde Lab guide](tilde-lab.md),
[Learning Ledger](learning-ledger.md), and [evaluation contract](evaluation.md)
take precedence when an outside system's assumptions conflict with Tilde's
privacy, IMKit, model-asset, or Screen Memory rules.
