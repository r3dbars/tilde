# Tilde Lab

Tilde Lab is the separate macOS experiment studio in this repository. Its
locked mission is: **save the user's actual keystrokes without getting in their
way.** It does not ship inside the input method.

The headline is **Net Keystrokes Saved**: accepted characters minus Tab/word
accepts, corrections, and dismissal overhead. Weighted reply scores remain
diagnostics. Bad suggestions, sensitive situations, temporal integrity,
privacy, interaction integrity, and p95 latency are separate hard gates that
cannot be averaged away.

Reply quality is reported separately as **Human acceptable**, **Exact path**,
and **Accepted alternative**. A different reviewed reply can be good without
pretending it was the user's recorded next text or earning unobserved
keystroke savings.

## What the studio contains

The sidebar separates six kinds of evidence so a fast model score cannot be
mistaken for complete product proof:

| Bench | Evidence today |
| --- | --- |
| Reply Quality | Live pinned-production or Lab-only local GGUF runs, plus a synthetic-only Codex subscription ceiling |
| Judgment | Live cleaner/silence/factuality decisions in Reply runs plus deterministic policy fixtures |
| Scene Memory | Deterministic geometry/capture-policy fixtures and a complete configurable manifest |
| Personalization | Synthetic support/confidence/arbitration fixtures; private exported history may be read in memory by Reply Quality but is never copied into reports |
| Interaction | An instrumented foreground AppKit text host that observes marked ranges, selection, Tab/Escape, commits, and in-memory integrity checks |
| Performance | Live worker/slot/cache/batching/KV/Metal runtime measurements |

The synthetic audit card on each bench checks its configuration without loading
the model. A synthetic audit is not a substitute for a live model run, and the
instrumented Scene Host is not a substitute for driving the real Tilde input
source in each target application.

## Tilde Lab command line

`tilde-lab` runs long experiments and controls promotion evidence. The
macOS studio and `tilde-lab-runner` remain useful for interactive diagnostics,
but their point estimates do not nominate a production candidate. The v2 CLI
binds one causal question to one experiment class, runs durable paired work,
and makes the protected phases structurally unreachable from an optimizer.

Build it once, then inspect its complete command map:

```bash
swift build --product tilde-lab
.build/debug/tilde-lab --help
```

### End-to-end campaign

```bash
# Development-only discovery. The first launch does not use --resume.
.build/debug/tilde-lab init \
  --name qwen-factorial \
  --hypothesis-id QWEN-GEN-01 \
  --hypothesis "The registered treatment improves expected utility without increasing harm." \
  --class generator \
  --suite certified-v2 \
  --seeds 17,41,73 \
  --repetitions 1 \
  --output qwen-factorial.json
.build/debug/tilde-lab validate qwen-factorial.json
caffeinate -dimsu .build/debug/tilde-lab run qwen-factorial.json
.build/debug/tilde-lab status qwen-factorial.json
# Only after status reports `aborted`, resume the unfinished registered work:
caffeinate -dimsu .build/debug/tilde-lab run qwen-factorial.json --resume
.build/debug/tilde-lab review \
  --campaign qwen-factorial.json \
  --status supported \
  --conclusion "The preregistered criteria passed; see the experiment record."
.build/debug/tilde-lab compare --campaign qwen-factorial.json

# Freeze at most three passing candidates. No optimizer runs beyond this point.
.build/debug/tilde-lab nominate \
  --campaign qwen-factorial.json \
  --top 3 \
  --output validation-plan.json
.build/debug/tilde-lab validate-candidates \
  validation-plan.json \
  --campaign qwen-factorial.json
.build/debug/tilde-lab review \
  --campaign validation-plan.json \
  --status supported \
  --conclusion "The frozen validation criteria passed."
.build/debug/tilde-lab compare --campaign validation-plan.json

# Consume one frozen candidate against one baseline once per exact evidence set.
.build/debug/tilde-lab holdout \
  --campaign qwen-factorial.json \
  --validation-plan validation-plan.json \
  --candidate CANDIDATE_ID \
  --confirm-consume \
  --output holdout-plan.json
.build/debug/tilde-lab review \
  --campaign holdout-plan.json \
  --status supported \
  --conclusion "The one-time holdout criteria passed."
.build/debug/tilde-lab compare --campaign holdout-plan.json
```

Campaign JSON is owner-only (`0700` directories and `0600` files). It may hold
local model/helper paths. Shareable reports contain hashes and aggregate case
evidence, never those paths, prompts, fixture text, screen text, or raw model
output. Synthetic raw candidates can be cached locally to replay display
policy; `cache-clear` irreversibly deletes that explicit cache. Private-history
and hand-curated inputs can never enter it.

Every newly saved aggregate report uses schema v6 and stores a privacy-safe
eligibility decision alongside the source commit and clean/dirty state, runner
hash, OS/build and anonymous hardware class, power/thermal state, versioned
invocation digest, registered hypothesis, and review state. It does not store
raw command arguments. Reports from v1-v5 and reports with missing, dirty,
unregistered, incomplete, or unreviewed evidence remain readable, but the CLI
will not create a comparison or advance a protected phase from them. Run
`status`, resolve every named blocker, attach the honest supported/rejected/
inconclusive conclusion with `review`, and only then run `compare`.

### Phase firewall

| Phase | Data | Candidates | Adaptive search |
| --- | --- | ---: | --- |
| Discovery | development only | bounded by campaign budget | allowed |
| Development confirmation | frozen development | baseline + at most 10 | no |
| Validation | untouched validation | baseline + at most 3 | no |
| Holdout | one-time holdout | baseline + exactly 1 | no |
| Regression | immutable regression/adversarial suite | baseline + exactly 1 | no |
| Shadow / dogfood / soak | local text-free product events | one frozen challenger | no |

Every protected plan freezes the selected-suite digest, scorecard, model bytes,
helper bytes, arm manifests, and—when relevant—each per-arm runtime. A changed
byte or control fails before inference. Holdout consumption is idempotently
recorded in SQLite and cannot be repurposed as another search round.

Research selection also injects same-partition prompt-leak, sensitive,
stale-context, echo/replay, and unsupported-fact sentinels. They run in block
zero. A timeout, protocol error, unsafe suggestion, forbidden fact, or temporal
violation stops the campaign before the expensive blocks.

### Execution and statistics

The durable coordinator uses SQLite WAL tables for campaigns, owner-scoped run
sessions, leases, work items, observations, comparisons, promotions, agent
proposals, online events, holdout receipts, and cumulative active-time budget.
Each work identity binds campaign, arm hash, scenario, context variant,
generation seed, repetition, and block. Manifest identities canonicalize the
known set-valued fields while preserving ordered arrays, so semantically equal
campaigns keep the same digest across processes.

Campaign state is explicit: `ready`, `running`, `completed`, `failed`, or
`aborted`. A session is live only while its owner process, heartbeat, and lease
state agree. `status` reconciles dead or stale sessions before displaying
progress, releases only their unfinished leases, and preserves completed
observations. The initial launch must omit `--resume`; an interrupted `aborted`
campaign requires it. A second live runner is refused, while `failed` and
`completed` campaigns require a newly registered campaign ID. Completion is
refused while durable work is absent, pending, running, or failed, and only a
reconciled completed campaign may create paired comparisons.

Hard-gate and other terminal failures are persisted as aggregate-only artifacts
with fixed categories and reason codes, even if the run stopped before creating
an arm report. In that case `review` attaches the honest supported, rejected,
or inconclusive interpretation to the failure artifact. It never turns the
failure into a comparison or stores model output, prompts, paths, or writing.

Root situations are the independent units. Blocks are deterministically
stratified by category, register, and typing boundary; arm order rotates and
reverses between blocks. AC power, Low Power Mode, thermal state, arm order,
workers, slots, and cache state are recorded without scenario data. Unstable
machines pause between blocks. `--allow-battery` is development-only.

Comparisons report paired root win/tie/loss counts, root-clustered bootstrap
intervals, probability of positive effect, shown/safe-opportunity denominators,
per-seed results and the worst seed, protected slice deltas, and Wilson upper
bounds for rare harm. A diagnostic cleaner can explain a failure but can never
promote. Rank alone is never a promotion rule.

### Registered primary metric

Every campaign pre-registers the one paired difference its promotion rule is
applied to, with `--primary-metric` on `init`:

| Metric | Meaning | Direction |
| --- | --- | --- |
| `expected-utility` | the latency-gated time-value proxy, in milliseconds per 1,000 baseline characters | higher is better |
| `oracle-net-keystroke-savings` | the Net Keystrokes Saved rate — the same ledger the arm aggregate reports | higher is better |
| `precision-when-shown` | useful share of displays | higher is better |
| `bad-when-shown` | harmful share of displays | lower is better |

`bad-when-shown` is the default for the `display-policy` class and the reason
that default exists: a display experiment changes which candidates are shown,
not which characters match the recorded future, so exact-path keystroke credit
and the expected-utility proxy can both be flat for it by construction. The
comparator orients the registered metric so a positive estimate always means
an improvement, and applies the protected-slice guard to the same metric. This
is a choice of exam, never a discount: the hard gates, the keystroke ledger,
and the harm ceiling are unchanged, and the metric is frozen before the result
is known like every other registered control.

Expected utility is a *proxy*, not the mission. It scores a display only when
that display's recorded first token beats the registered stable-word deadline
(400 ms by default). A high-throughput Lab matrix — many workers and slots,
declared quality-only with no latency claims — records almost no display inside
that deadline, so its expected utility collapses to a near-constant and every
paired difference reads 0.00 [0.00, 0.00] with every root a tie. That is the
instrument saying "this run carries no timing evidence", not the treatment
saying "no effect". `compare` prints the registered metric first and the
utility, net-keystroke, and harm differences beneath it so the two can never be
read as the same number again.

The default generator recipe is the exact 4 × 2 temperature/token-budget
factorial (0, 0.05, 0.10, 0.15 × 20 or 12 tokens). `qmc`, balanced successive
halving, constrained Pareto selection, and adaptive local search are available
only in discovery. Generation seed is paired measurement control, never an
optimizer dimension.

### Separate causal classes

`init` creates useful starting matrices rather than mixing unrelated knobs:

- `generator`: sampler and raw-generation controls; the default is the 8-arm
  Qwen factorial;
- `context`: typed-only, Intent Futures, turn/budget, scene placement, and
  recognition ablations with generator and policy frozen;
- `display-policy`: confidence floors, visible caps, cleaner, grounding, and
  dynamic length, replayable from the synthetic candidate cache;
- `runtime`: identical behavior arms with explicit workers, slots, context,
  Flash Attention, Q8 KV, prompt-cache, and reuse variants; each block restarts
  the arm's helper configuration and reports request latency plus cold-start
  p50/p95/p99;
- `personalization`: use `personalization-replay`; ordinary model fixtures are
  rejected because they do not apply chronological history; and
- `interaction`: use real-host evidence; ordinary model fixtures are rejected
  because they cannot exercise IMKit.

Runtime research keeps the exact model bytes fixed. Quantization or base versus
post-trained model comparisons are separate model-identity campaigns, not a
runtime-arm shortcut and never a production model change.

### Confidence, personalization, and real use

`risk-coverage` replays every cached synthetic raw candidate across confidence
thresholds without inference. It reports coverage, precision and harm when
shown, expected utility, length, Wilson harm bounds, and category/register/
boundary/context slices. The trusted frontier uses the harm upper bound, not a
small-sample point estimate.

`TildeConfidenceV1` is a text-free feature contract for chosen-token sequence
likelihood, first/minimum token probability, probability margin, token entropy,
length and stop shape, context quality, scene freshness, personal support,
first-token latency, and perturbation agreement. Missing helper capabilities
remain missing rather than fabricated. `confidence-report` fits an isotonic
acceptance calibrator on the chronological first 70% of displayed dogfood
events and reports only out-of-sample ECE/Brier metrics on the last 30%, plus
app/register/boundary/length/personal slices. It never trains on holdout.

`personalization-replay` reads one owner-selected regular JSONL file in memory,
rejects symlinks, unknown keys, duplicates, oversized lines, mixed consent or
history epochs, and future leakage. Frequency/recency weighted global and
app-specific n-grams are scored before each event is learned. Reports contain
only aggregate lift, harm, coverage, precision, stress slices, and stale
override blocks. They explicitly do not claim full-suggestion dogfood utility.

### Simulated typist (discovery-grade only)

`simulate-typist` drives checked-in synthetic personas — goal, register,
typing-speed bucket, interruption tolerance — through the real completion path:
the production prompt composer, the configured generation runner, the
production cleaner, and the Lab display judge. The only simulated part is the
human at the keyboard. At every display a `TypistDecisionPolicy` answers
accept, accept-word, continue, or dismiss, plus a would-retain judgment.

Stage 1 ships `DeterministicHeuristicTypist` (frozen rules, no randomness) and
`ExternalCommandTypist`, which writes one JSON feature object to a configured
command's stdin and reads one JSON decision from its stdout. That is the socket
a cheap frontier model plugs into later; no cloud model, endpoint, or
credential lives in this repository. Both sides of the contract are text-free
*by schema*: every field is a bucket, a boolean, or a count, and any key
outside the allowlist is rejected, so scenario text, prompts, and candidates
structurally cannot cross the boundary.

`--decision-batch-size N` (1...100, default 1) lets an external policy decide
many moments per process invocation, which is what makes an LLM-backed policy
affordable over a long run. Typing one scenario is strictly sequential — a
decision changes the characters typed, the dismissal cooldown, and the counts
the next moment reports — so a batch may never hold two moments of the same
persona/scenario pair. The engine advances every active session to its own next
undecided moment and batches *across* sessions only, at most one moment per
session per round, so every batch is decision-independent by construction and
the aggregates match a batch-size-1 run exactly. The batch envelopes
(`tilde-lab.typist-moment-batch.v1` and `tilde-lab.typist-decision-batch.v1`)
carry nothing but a schema and an ordered array; every element is validated by
the same text-free allowlists, position is the only correlation, and a count
mismatch or a short answer is an error rather than something the engine repairs.
The response byte cap and the command deadline scale with the batch, both
bounded.

`--decision-workers N` (1...16, default 1, external-command policy only)
resolves that many of a round's batches at the same time. It is safe for
exactly the reason batching is: a round holds at most one moment per session,
its batches partition that round, and so no two concurrent calls can touch one
scenario's timeline — the engine checks that invariant each round rather than
assuming it. Concurrency is confined to the policy calls. Every moment is
collected before the round and every decision is applied after it, in batch
order, so completion order cannot reach the aggregates: a concurrent run's
per-persona numbers are byte-identical to the sequential run's. Each external
invocation already owns its process, pipes, buffers, and environment, so
nothing is shared between calls in flight. The batches still running are awaited
before a failure surfaces, so no decision command outlives the run. The worker
count is recorded in the report next to the batch size.

`--skip-failed-batches N` (0...50, default 0, external-command policy only)
decides what one failed batch costs. At the default a batch that fails after
the policy's own retries aborts the run, which is the right answer for a short
run and the wrong one for an overnight run that a single provider hiccup can
throw away whole. Above 0, that many failed batches instead abandon the
persona/scenario sessions they held: those sessions are never advanced again,
their remaining moments are never judged, and their partial results are
excluded from every persona aggregate rather than zero-filled into it — an
abandoned session is not a writer who ignored or dismissed a ghost, and must
never read like one. The failure verdict is taken in batch order after the
round has joined, never in completion order, so which batches a run skips is a
property of the policy's answers and not of the machine's scheduling, and the
surviving sessions' apply order and aggregates are identical to a run where
nothing failed. While skips remain a failed batch does not cancel the sibling
batches in flight beside it; only the final abort does. Exceeding N aborts
exactly as the default does.

Nothing about a skip is silent. The report carries the allowance, the number of
batches skipped, the sessions abandoned, and the decision moments those
sessions cost; each persona slice carries its own abandoned-scenario count next
to the scenarios it actually finished; the counts are validated against one
another, so a report cannot claim a skip that cost nothing or a loss with no
skip behind it; the run's limitation text states the incompleteness in the same
sentence every reader already reads; and the CLI summary prints all of it
loudly whenever it is not zero.

`--arm-file /absolute/arm.json` pins the run to one nominated configuration.
The file holds exactly one arm object — the same shape a campaign manifest
stores in `arms[]`, decoded by the same `Codable` type and checked by the same
validation `tilde-lab validate` runs, so an out-of-range or malformed file is
refused by name before any model starts. The loaded arm replaces the built-in
`simulated-typist-baseline` wholesale: its prompt configuration composes the
prompt, its generation configuration is what the completion request carries —
the same routing a campaign run uses — and its judgment configuration is what
the display judge applies, so a custom echo threshold or grounding mode changes
what the simulated writer is actually shown. The report's `arm` field records
the arm that ran, and its provenance digest is that arm's. Without the flag the
built-in baseline runs exactly as before.

The report is aggregate-only per persona — displays, simulated acceptance,
type-through, wrong displays, corrections, and retained-character potential,
plus the decision batch size, worker count, and skip accounting the run used.
It names the generation stack behind its candidates — model identity,
revision, and the model and helper SHA-256 digests, validated the same way an
ordinary Lab report's asset snapshot is — so a Gemma run and a Qwen run are
distinguishable from their reports alone. It carries the report provenance envelope and the aggregate-only privacy contract,
and it is permanently fenced with the `simulated-decision-layer` evidence
reason. It is not a `LabRunReport`, is never written into a campaign's reports
directory, and cannot enter a comparison or advance a protected phase. Until
the sim-vs-live ranking-agreement protocol runs, treat its numbers as untrusted
search order, never as evidence.

After a passing holdout, `shadow`, `dogfood`, and `soak` create sticky local
plans. `ingest-events` accepts a closed text-free JSONL schema; raw text fields
are structurally rejected. v3 events also carry typed-through, settled-visible
time, and retained-character counts or missingness at 5s, 30s, and segment
close. `online-report` prints coverage and missingness at those horizons,
typed-through, flicker accepts, realized accepted characters, edits/undoes,
deadline misses, matched-stratum attention tax, and net time per 1,000 typed
characters. `delete-telemetry` deletes every event for the campaign.

A soak requires sustained active duration, enough events, p99 first-stable-word
at or below one second, zero crashes, timeouts, wrong insertions, committed-text
corruption, or network egress, and explicit exercise of network denial, memory
pressure, runtime restart, app switching, cache hits and misses, plus sleep/wake
for an eight-hour or longer run.

### Interaction and permanent failures

`interaction-report` accepts only text-free aggregate records from an
owner-triggered real-host harness. It requires every marked-text, acceptance,
dismissal, typing-through, cancellation/edit/focus/app/conversation-switch,
runtime-restart, and committed-text-integrity check across the Scene Host,
TextEdit, WebKit, Chromium, and Electron. It is bound to the candidate arm hash
and passing holdout digest. Missing evidence is a failure, not an inferred pass.
The CLI intentionally does not seize focus or switch the owner's input source;
use an isolated macOS account, VM, or test Mac for unattended host driving.

When a real failure is found, put its reviewed synthetic reproduction in a
`regression` or `adversarial` suite, hash the source evidence, then freeze and
run it:

```bash
.build/debug/tilde-lab freeze-regression \
  --campaign qwen-factorial.json \
  --candidate CANDIDATE_ID \
  --suite /absolute/path/permanent-regressions.json \
  --evidence-digest FAILURE_EVIDENCE_SHA256 \
  --output regression-plan.json
.build/debug/tilde-lab regression \
  regression-plan.json \
  --campaign qwen-factorial.json
```

The plan freezes the failure digest, exact suite digest, candidate, scorecard,
assets, seeds, and runtime. The candidate must make every regression case
`useful` or `correct-silence`, with no temporal, forbidden-fact, or hard-gate
failure.

### Agent boundary

An agent receives only aggregate comparisons, failure counts, slice red bars,
tested arm hashes, and remaining budget. Its snake-case proposal names one
hypothesis, parent, class, bounded changes, affected slices, success rule,
budget, and stop conditions. The deterministic validator rejects phase, seed,
scorecard, corpus, safety, and out-of-class mutations. The agent can propose;
it cannot score, promote, inspect protected examples, or rewrite the exam.

## Autoresearch campaigns

The legacy **Autoresearch** screen adapts the experiment loop from
[Andrej Karpathy's autoresearch](https://github.com/karpathy/autoresearch) to
Tilde's native Swift/macOS constraints. It does not import the original
NVIDIA/Python trainer. It preserves the useful protocol:

1. lock one suite, goal contract, model, and baseline;
2. establish the baseline before changing anything;
3. mutate one bounded knob, run the same evaluation, and append a checkpoint;
4. keep the candidate only when gate-first ranking beats the current champion;
5. discard regressions, periodically rerun the control, and confirm the final
   champion with more repetitions.

This UI is an exploratory aid. Use `tilde-lab` for uncertainty-aware
promotion, protected validation, one-time holdout, online evidence, and durable
long-run resume.

Each campaign selects one subsystem—generation, context, display, or safety.
Gate-first ranking prevents unsafe or totally silent arms from winning. Among
usable arms, Net Keystroke Savings decides first; behavioral coverage,
diagnostic quality, control-normalized latency, and simplicity break ties.

Campaigns are owner-only JSON checkpoints in
`~/Library/Application Support/Tilde Lab/Campaigns`. Every completed arm is
also saved immediately in `Runs`; Pause cancels at the current arm boundary,
and Resume skips mutations already present in the ledger. Protocol retries are
bounded. Trial order can be deterministically randomized, control arms reduce
run-order/thermal confusion, and model workers can either restart between
trials or remain loaded until confirmation.

Before a long run, the app checks AC/High Power status. This is a warning rather
than a scoring input: performance comparisons still need repeated controls,
because power mode cannot remove all thermal and background-load drift.

## Experiment arms and manifests

Every bench edits the same `LabArmConfiguration`. An arm records:

- generation: sampler preset, temperature, top-k, top-p, min-p, typical-p,
  penalties, prediction budget, seed, stop behavior, streaming/final protocol,
  prompt caching, probability evidence, and advanced llama samplers;
- prompt: register, recipe, context and scene budgets, reply reserve, cache
  quantum, turn/reference bounds, conversation selection/format/placement, and
  Intent Futures controls;
- judgment: fixed or confidence-based dynamic length, word and character caps,
  cleaner recipe, echo thresholds, dangling-tail repair, factual grounding,
  and sensitive-scene suppression;
- Scene Memory: AX/OCR source, recognition mode, freshness, conversation
  geometry, speaker buckets, wrap/dedupe thresholds, capture cadence, luminance
  change detection, synthetic OCR noise, and prompt-injection cases;
- personalization: synthetic support/confidence/tail/deadline/scope/arbitration
  controls and stale/contradictory/poisoned-history cases;
- interaction: activation boundary, host-specific reveal delays, typing speed,
  context/socket limits, host matrix, cancellation/edit/focus/accept/dismiss
  coverage;
- scenario coverage: development/validation/holdout/regression/adversarial partition,
  intent, tone, language, register, boundary, noise, fact, sensitive,
  injection, and counterfactual tags; and
- scoring: the locked `net-keystrokes-v1` goal contract, plus legacy diagnostic
  usefulness, restraint, factuality, and brevity weights.

The Performance bench owns shared execution controls: workers, slots,
repetitions, context, cache reuse, timeout, work-order seed, threads,
batch/micro-batch, Flash Attention, KV types/offload, GPU layers, load mode,
warmup, continuous batching, SWA, and slot similarity.

Use **Duplicate** to make a candidate from the selected arm. A matrix run
verifies the assets and loads one worker pool, then evaluates every arm through
that same pool. This avoids paying model startup once per arm.

**Arm actions → Apply production-fidelity recipe** restores Tilde's greedy
sampler, 20-token budget, streaming request path, production prompt shape,
non-chat Intent Futures, and production cleaner policy while preserving the
arm's scenario coverage and scorecard. **Reset all knobs to Lab defaults**
instead replaces the complete arm with the high-throughput Lab baseline.

When scoring is locked, every arm must use the identical goal contract or
validation refuses to run the matrix. Campaigns cannot weaken their own exam.

**Export experiment manifest** writes schema
`tilde-lab.experiment-manifest.v2`. It contains every experiment and runtime
knob but never model/helper paths. The CLI accepts the same file:

```bash
swift run tilde-lab-runner --manifest ./candidate-matrix.tilde-lab.json
swift run tilde-lab-runner --manifest ./candidate-matrix.tilde-lab.json --suite ./holdout.json --json
```

When a manifest is supplied, it owns arms and runtime tuning. `--helper` and
`--model` still locates the local file. Production mode verifies the exact E2B
pin. A fixed diagnostic run may explicitly select an experimental local GGUF;
its identity and exact hash are recorded in the aggregate report.

## Running the app

```bash
./script/build_and_run.sh --tilde-lab
./script/build_and_run.sh --tilde-lab --verify
```

The build stages `dist/Tilde Lab.app`; it does not stop, replace, or re-sign
the daily-driver Tilde app.

The app opens on Certified Corpus V2's development partition. A one-arm
unattended CLI run without a manifest also defaults to development; protected
partitions require a registered research protocol:

```bash
swift run tilde-lab-runner --workers 1 --slots 8 --repetitions 10
swift run tilde-lab-runner --suite ./my-suite.json --arm candidate-a --json
swift run tilde-lab-runner --built-in-suite slack-reply-gold-v1 --arm slack-check
swift run tilde-lab-runner --built-in-suite replying-v1 --arm legacy-check
```

## Model quality shootout

The **Model quality shootout** card removes the when-to-speak question so two
models receive the same exam:

- a deterministic 50-situation breadth sample across ordinary and stress cases
  in Certified Corpus V2 development where Tilde should speak;
- production prompt shape, temperature 0, and a fixed three-word visible cap;
- one worker, one slot, and one repetition; and
- one 0–100 **Output Quality** number: human-acceptable output multiplied by
  factuality and compliance with the visible cap.

Latency and throughput are still recorded as diagnostics but do not change the
quality score. The result screen breaks the score into **Human acceptable**,
**Exact path**, and **Accepted alternative** so a different valid reply is not
mistaken for an error.

In the app:

1. click **1 · Prepare E2B Baseline**, then **Run**;
2. click **2 · Prepare 26B Candidate**;
3. choose the already-downloaded local GGUF and confirm its identity; and
4. click **Run** again. The second report automatically compares with the first
   compatible result.

Then click **3 · Run Frontier Ceiling**. GPT-5.6 Sol receives the identical 50
synthetic prompts in two batches through the owner's ChatGPT-authenticated Codex
CLI. This is the best-available quality reference, not a production backend.
The lane refuses API-key authentication, private history, validation, holdout,
and every corpus except project-owned Certified Corpus V2 development. It runs
ephemerally with shell, browser, memory, app, and plugin tools disabled. OpenAI
documents both [ChatGPT subscription sign-in](https://developers.openai.com/codex/auth)
and [included Codex model access](https://developers.openai.com/codex/pricing).

Tilde Lab intentionally does not download alternate models. Production Tilde's
network and immutable-model covenant remains unchanged. The initial 26B base
candidate is `google/gemma-4-26B-A4B`; the official ggml GGUF repository is
[ggml-org/gemma-4-26B-A4B-GGUF](https://huggingface.co/ggml-org/gemma-4-26B-A4B-GGUF).
Experimental files must be GGUF. They are format-checked, hashed, labeled
**Experimental local model**, and cannot run corpus certification or adaptive
autoresearch.

The same fixed smoke test is available from the CLI:

```bash
# Production baseline
swift run tilde-lab-runner --model-quality-smoke --arm model-quality-e2b-cap3

# Full confirmation: all 360 development reply opportunities
swift run tilde-lab-runner --model-quality-full --arm model-quality-e2b-cap3-full

# Experimental candidate (paths are local and never persisted in reports)
swift run tilde-lab-runner \
  --model-quality-smoke \
  --experimental-model \
  --model '/Users/you/Library/Application Support/Tilde Lab/Models/gemma-4-26b-a4b-base-q8_0.gguf' \
  --model-id ggml-org/gemma-4-26B-A4B-GGUF \
  --model-revision 0b1367270501454da6df6c53fe46e90de8a1146e \
  --arm model-quality-26b-a4b-cap3

# Subscription-backed frontier ceiling; two batched messages, no API billing
swift run tilde-lab-runner --frontier-quality-ceiling

# Blinded semantic shootout: local E2B versus Sol, then one shared referee
swift run tilde-lab-runner --semantic-quality-shootout
```

Replace `--model-quality-smoke` with `--model-quality-full` in the experimental
candidate command for the matched 360-situation confirmation run. The prompt,
temperature, three-word cap, and quality score remain identical; only the
breadth limit changes.

## Checked-in model and configuration evidence

The **Learning Ledger** screen is the broader memory of experiments, rejected
ideas, limitations, promotion gates, and prioritized next work. It and this CLI
command read the same checked-in aggregate-only source:

```bash
swift run tilde-lab-runner --learning-ledger
```

See [Tilde Learning Ledger](learning-ledger.md) for the current synthesis and
update contract. How the owner and agent work as colleagues is
[the lab partnership](research/lab-partnership.md). Every try, learn, and
fail — including rejected work — goes in [the lab log](research/lab-log.md).
Live F03 ingest is a Mac thread; start from
[the on-device briefing](research/next-on-device.md).
External papers that can change a queued experiment are indexed in
[the reading list](reading-list.md), with Tilde-specific digests in
[`docs/research/`](research/).

The owner-visible **Model Results** screen and this command read the same
aggregate-only checked-in catalog:

```bash
swift run tilde-lab-runner --model-benchmark-leaderboard
```

The complete model table, hashes, revisions, helper hashes, generation recipes,
report IDs, quality counts, and latency diagnostics live in
`Sources/TildeLabKit/Fixtures/model-benchmark-results-v1.json`. The current
directional 360-case ranking puts Qwen 3.5 9B Base Q4_K_M first at 43/100 (158
useful, 93 wrong, 109 silent), immediately ahead of Nemotron Nano 9B v2 Base
Q4_K_M at 42/100. The historical entries share the suite, prompt, greedy
sampler, three-word cap, one worker, and one slot, but mix 8-token and 20-token
budgets across three helper hashes. Use each entry's `comparisonGroupID` for a
strict runtime claim. These are directional model baselines, not live-product
promotion results.

The Qwen 9B configuration campaign then screened 50 arms across the same 360
speak-only development situations: 18,000 evaluations total. Its clean
one-worker confirmation promoted **Qwen 3.5 9B God v1** for experimental
preview use only:

| Control | Greedy baseline | God v1 |
| --- | ---: | ---: |
| Temperature | 0 | 0.10 |
| Generated-token budget | 20 | 12 |
| Visible cap | 3 words | 3 words |
| Output Quality | 43 | **44** |
| Human-acceptable suggestions | 158 | **161** |
| Wrong suggestions | 93 | **88** |
| Silent | 109 | 111 |
| Bad-suggestion rate | 25.8% | **24.4%** |
| Net keystroke savings | 11.3% | 11.1% |
| Total p95, one worker | 545 ms | **515 ms** |

Every factual, sensitive-scene, and scene-echo protection remained enabled.
The official Tilde app applies these controls only while its selected model is
Qwen 9B. Gemma 4 E2B remains the lower-resource default with its established
production controls; changing models never changes the app or IME identity.

Two large apparent wins were rejected rather than promoted. One- and two-word
caps fell below the default three-word scene-echo threshold, so their scores
were not comparable safety-preserving wins. Relaxing or disabling scene-echo
rejection produced the same confound. Repeat-penalty variants raised the raw
score by becoming much more aggressive, but also raised wrong interruptions.

The latest checked snapshot—148 model completions, still not a promotion
sample—measured 192 ms p50, 366 ms p95, 416 ms p99, and 458 ms maximum model
latency, with 134 suggestions served and 10 cleaner rejections. It remains below
the 200-completion verdict floor, and p99 currently exceeds the 400 ms budget.
Operational diagnostics remain local, aggregate, and content-free.

The semantic shootout retains the strict answer-path score and adds four
0–100 referee dimensions: intent, usefulness, naturalness, and factuality.
Candidate labels alternate between A and B so the referee is not told which
model produced an answer. Only the synthetic 50-case development slice may use
this network-backed lane. Prompts, candidate text, and individual judgments
remain memory-only; the printed result contains aggregates only. The referee
is still an automated model, so treat one run as directional and calibrate it
against blinded human review before using it as a promotion gate.

## Certified Corpus V2

**Quiz → Certified Corpus V2** is the decision-grade 1,000-situation offline
regression corpus. It has 600 reply opportunities, 400 cases where silence is
correct, 40 behavioral families, 500 fact-changing counterfactual pairs, and a
locked 600/200/200 development/validation/holdout split.

Every reply opportunity has an explicit intent, one recorded continuation,
and seven distinct reviewed alternatives. A short displayed suggestion may be
a prefix of any of those eight full answer paths; it is not required to show
facts that occur later in the full reply. Any fact it does show must remain
grounded, and forbidden counterfactual facts still fail the case.

Tilde Lab does not trust that count by itself. Certification has two gates:

1. deterministic construction checks reject duplicates, unsupported answers,
   malformed pairs, coverage drift, provenance failures, split drift, or a
   stale 100-case structured-review receipt; and
2. a 3,000-completion model test compares all 1,000 targets with correct
   context, typed text alone, and deliberately mismatched context. Correct
   context must win on Exact@1 reply starts and Net Keystrokes Saved overall and on
   development, validation, and holdout separately, with zero errors/timeouts.

The app presents the result as **Offline certified**, **Needs model proof**, or
**Failed**, and blocks autoresearch on this corpus until both gates pass. It
also forces autoresearch to use development only. A certificate is aggregate
only, is bound to the corpus, model, and helper hashes, and lives at:

```text
~/Library/Application Support/Tilde Lab/Corpus Certificates
```

Run the same gates from the CLI:

```bash
swift run tilde-lab-runner --audit-certified-corpus
swift run tilde-lab-runner --print-certified-review-sample
swift run tilde-lab-runner --certify-corpus --workers 1 --slots 8 --repetitions 1 --production-fidelity
```

For a short first learning run, use **Run Quick 8 Test** in the
corpus trust card, or run the equivalent CLI command:

```bash
swift run tilde-lab-runner --certified-corpus --campaign quick-8 --workers 1 --slots 8 --repetitions 1
```

Quick 8 runs eight production-fidelity arms over the 600-case development
split: two controls plus focused prediction-budget, visible-length,
confidence, conversation-depth, intent-future, and combined candidates. It is
4,800 completions per run. Expect roughly 5–10 minutes on current Apple
silicon; actual wall time varies with power and
thermal state. Validation and holdout are not touched.

“Offline certified” means the quiz is safe for controlled development
optimization. It does not mean Tilde is proven in daily use. Temporally valid
private replay and foreground dogfooding remain separate real-world gates.

## Corpus Pilot V1

**Quiz → Corpus Pilot V1** loads exactly 1,000 distinct development situations:

- 600 reply turns normalized from the locally installed Taskmaster-1 written
  self-dialog source; and
- 400 deterministic, project-owned Tilde situations covering grounded replies,
  ambiguity, and sensitive silence.

The public source is not bundled into the repository or app. Tilde Lab performs
no corpus network requests. The reviewed Taskmaster file belongs at:

```text
~/Library/Application Support/Tilde Lab/Corpora/taskmaster-1/self-dialogs.json
```

The registry pins its SHA-256, records `CC-BY-4.0`, and marks the corpus
development-only. The adapter uses only turns before the selected target,
rejects cases whose target already appears in prior context, chooses one target
per conversation, and stores only opaque corpus/root identifiers in aggregate
reports. Raw source and normalized text remain local and in memory.

Validate the installed source and exact distinct-root counts without starting
Gemma:

```bash
swift run tilde-lab-runner --validate-corpus-pilot
```

Run the development pilot explicitly with:

```bash
swift run tilde-lab-runner --corpus-pilot --workers 1 --slots 8 --repetitions 1
```

The UI and report distinguish **distinct situations** from evaluations. More
checkpoints, context variants, or repetitions improve measurement depth, but
they never pretend to create new underlying evidence.

For a broad reproducible screening sweep, the built-in `broad-50` campaign
runs 50 production-fidelity arms through one shared worker pool. It varies
sampling, length, prompt/context, and judgment controls while keeping scoring
locked and sensitive-scene suppression enabled:

```bash
swift run tilde-lab-runner --campaign broad-50 --workers 1 --slots 8 --repetitions 3
```

For an unattended maximum-width Reply Bench sweep, `deep-128` holds the
runtime and locked scorecard constant while testing 128 generation, prompt,
judgment, and combined configurations. It repeats the production control at
the start, middle, and end so a long run can expose thermal or ordering drift.
Every arm uses production streaming and keeps sensitive-scene suppression on.

```bash
swift run tilde-lab-runner --campaign deep-128 --workers 1 --slots 8 --repetitions 10
```

With the V2 validation partition, that command performs 102,400 scored
evaluations: 128 arms × 80 distinct cases × 10 repetitions. Actual duration
depends on the machine and current load, so run a single-repetition smoke pass
before treating any wall-clock estimate as exact. The CLI checkpoints each
completed arm immediately; an interrupted matrix keeps every report completed
before the interruption.

This is a discovery screen, not a release decision. Tune on development,
compare on validation, and run holdout only for a frozen finalist. The learning
runner records the complete suite digest when holdout is consumed and refuses
to run that same protected holdout again; another cycle requires a separately
reviewed, versioned protected suite.

Progress goes to standard error. Human summaries or aggregate-only JSON go to
standard output. Add `--no-save` for an ephemeral run.

By default the app finds:

- helper: `/Applications/Tilde.app/Contents/Helpers/llama-server`
- model: `~/Library/Application Support/Tilde/Models/gemma-4-e2b-q4km/model.gguf`

Both paths may change for local layout differences. Production mode still
requires the exact byte count and SHA-256. Explicit experimental mode accepts a
local GGUF only for fixed Lab runs and fingerprints its bytes into the report.

## Reply execution

Reply Quality launches the pinned `llama-server` helper on `127.0.0.1` with
offline mode. It supports isolated worker processes and multiple continuous-
batching slots per worker. The request may use final-response mode for maximum
bulk throughput or production-streaming mode for first-token evidence.

The runner constructs the selected prompt recipe, scrubs structured secrets,
calls the local helper, cleans and bounds the candidate, applies scene-echo,
factuality, confidence, and sensitive-scene policy, then grades the synthetic
expectation. Prompt and model output exist only in memory.

## Scenario contract

### Protected Slack Reply Gold V1

`slack-reply-gold-v1` is a 300-case hand-curated synthetic gold pack; it is not labeled
as historical Slack data. Eight reply targets are replayed at the caret, first
character, first word, two words, three words, mid-sentence, and near the end.
Each replay runs through typed-only, app-metadata, Accessibility, OCR, and
structured-thread context variants. Development, validation, and holdout
partitions are fixed, and every protected case carries verified temporal
integrity. Sensitive and ambiguous silence cases remain in the pack as gates.

The context ladder isolates where improvement came from instead of attributing
every loss to Gemma. The report records only the source/variant/checkpoint and
aggregate outcomes; evidence text remains in the loaded in-memory suite.

### Private personal replay

**Quiz → Private Personal Replay** reads accepted and typed-instead events from
the owner's local iCloud `Tilde-usage` export. It uses opaque hashes as IDs,
replays the caret/first-word/two-word checkpoints, and optionally attaches a
matching recorded screen-text sample in memory. It never changes or copies the
source files and never persists writing, screen text, file paths, prompts, or
model output into a report.

Historical imports are always development-only with unverified temporal status.
They cannot enter validation or holdout until every leakage condition can be
proved. Real examples measure personal wording and actual behavior; synthetic
cases provide deterministic rare, sensitive, stale-context, OCR-corruption,
and interaction coverage. The target evaluation mix is roughly 60% real and
40% synthetic once enough temporally valid history exists—not a reason to
pretend the current corpus contains Slack history.

Inspect only aggregate replay suitability, without printing or copying private
text, with:

```bash
swift run tilde-lab-runner --audit-private-history
```

### Built-in improved reply quiz

`replying-v2` is a deterministic 400-case synthetic corpus. It contains 160
ordinary reply opportunities, 120 ordinary situations where interruption is
the failure, 40 sensitive situations requiring silence, and 80 difficult reply
cases covering typos, long/stale/irrelevant context, contradictions, multiple
questions, prompt injection, mid-word completion, and sensitive near-misses.

Every case belongs to a two-case counterfactual pair. The paired prompt changes
one name, date, time, item, quantity, or location and the expected answer changes
with it, which exposes models that memorize a reply shape while ignoring the
actual facts. The corpus is split deterministically into 240 development, 80
validation, and 80 holdout cases. The app and built-in campaigns default to
development. **Quiz** in the app can switch back to the explicit 16-case
`replying-v1` legacy baseline.

Scenario suites use schema `tilde-lab.scenario-suite.v1`. The original fields
remain valid. Optional partition/intent/tone/language/tags fields enable the
studio's coverage filters:

```json
{
  "schema": "tilde-lab.scenario-suite.v1",
  "name": "Example replies",
  "scenarios": [
    {
      "id": "reply.confirm.example",
      "category": "reply.confirm",
      "partition": "validation",
      "intent": "accept",
      "tone": "friendly",
      "language": "en",
      "tags": ["word-boundary", "time", "counterfactual"],
      "typedContext": "Yes, ",
      "scene": {
        "mode": "replying",
        "turns": [
          { "speaker": "other", "text": "Does Thursday at three work?" }
        ],
        "references": []
      },
      "expectation": {
        "shouldSuggest": true,
        "goldenContinuation": "Thursday at three works for me.",
        "acceptablePrefixes": ["Thursday at three"],
        "acceptableContinuations": ["Thursday at 3 works for me"],
        "requiredTerms": ["Thursday", "three"],
        "forbiddenTerms": ["Friday"],
        "maximumWords": 8
      }
    }
  ]
}
```

Suites may contain at most 10,000 distinct cases. Repetition and seeded
shuffling remain run settings. At temperature zero, repetition primarily
measures latency; it does not create new behavioral coverage.

## Net keystroke and loss accounting

Each case becomes one fixed outcome:

- `useful`, `wrong`, `silent`, `correct-silence`, or `unwanted`; or
- `timeout` / `error`, which withhold the headline score.

Every case also carries one privacy-safe decision reason such as `shown`,
`sensitive-scene`, `prompt-leak`, `context-replay`, `scene-echo`,
`unsupported-fact`, `low-confidence`, `timeout`, or `protocol-error`.
The run inspector uses these codes to distinguish model failure from policy
suppression. If the matching synthetic suite is currently loaded, its fixture
can be inspected in memory. Raw model output is never written into the report.

An exact suggestion that is a prefix of the recorded future earns all accepted
characters. If only the first word is exact, the case may earn only that word,
matching Tilde's word-accept interaction. A prefix of a different reviewed
answer path earns human-acceptable quality credit, but only characters that
also match the recorded future can earn actual keystroke credit. One
acceptance key is subtracted from every accepted segment; recorded correction
costs and wrong or unwanted dismissal costs are also subtracted. The result is
shown as both a percentage and saved keystrokes per 1,000 baseline characters.

Exact-path-only keystroke credit is one definition, not two. The arm aggregate
and the paired comparator's `oracle-net-keystroke-savings` read the same
per-case ledger, so a recovered acceptable alternative earns identical credit —
quality credit, no keystroke credit — in both. Neither view is the looser
number. A campaign whose displays are mostly accepted alternatives should
expect a small keystroke difference and register a metric that matches what it
changed; it must not read a flat `Δ utility` as a flat keystroke result, since
those are different quantities.

Every loss is also classified as capture, extraction, scene attribution,
intent, wording, display, length, timing, or interaction. These buckets are
diagnostic queues, not extra points in the headline.

A run is research-eligible only when it is complete, bad suggestions are no
more than 1%, sensitive restraint is perfect, temporal integrity is perfect,
privacy passes, and model-response p95 is at most 1,000 ms. Interaction remains
`not-run` in a direct model bench, so release eligibility requires the separate
Interaction Bench. Scorecard V3, the weighted V2 score, and Reply Score remain
decodable diagnostics for old reports.

Accepted alternatives use deterministic exact/prefix matching against the
reviewed paths. Loose bag-of-words overlap is deliberately rejected because it
can hide a changed person, place, date, or intent. No cloud judge sees fixture
text or model output.

Weights are a navigation tool, not permission to ship. Personal-data egress,
raw sensitive text in reports, committed-text corruption, Secure Event Input,
excluded-app capture, redaction failure, and sensitive-scene safety are hard
gates. No score can offset one.

Use separate development, locked validation, holdout, permanent regression,
and adversarial partitions. Do not tune an arm or its score policy against the
holdout.

## Reports and privacy

Reports live in `~/Library/Application Support/Tilde Lab/Runs`, with owner-only
directory and file permissions. Version 5 reports contain:

- suite identity and the complete arm/runtime manifest;
- model/helper hashes;
- stable scenario IDs, outcome/reason labels, boolean grading evidence,
  counts, and timings; and
- aggregate net/gross/overhead accounting, hard-gate status, context/checkpoint
  labels, failure taxonomy, legacy diagnostics, and reason counts.

They contain no fixture text, screen text, prompts, raw model output, model
paths, or helper paths. Quitting or cancelling Tilde Lab terminates every
child worker it owns and never touches production Tilde's helper.

The Interaction Scene Host also keeps typed text and its integrity digest only
in that window's memory. Its event list records fixed event labels, ranges,
and character counts—not text—and disappears when the window closes.

## Parallelism and memory

`workers × slots` is request concurrency. Workers are independent model
processes; slots share one loaded model. Sixty workers is an allowed stress
setting, not a sensible starting point: sixty independent 3.43 GB mappings can
address more than 200 GB before KV caches and runtime buffers.

Start with a few workers and more slots. Increase workers only while cases per
second improves without unacceptable p95/p99 latency or memory pressure.

This is native process isolation, not Docker. A Linux container on macOS would
run inside a VM and would not measure the Apple Metal/unified-memory path that
production uses.

## Interaction evidence boundary

Open **Interaction → Instrumented Scene Host** for a real `NSTextView`. It
observes marked-text changes, commits, selection, focus, Tab, Escape, and an
owner-triggered in-memory committed-text checksum. Select the real Tilde input
source before using it.

A fully unattended compatibility sweep still needs an isolated macOS account,
VM, or dedicated test Mac: real IMKit testing steals focus and can affect input
source state. Tilde Lab therefore does not silently drive the owner's active
desktop from a background Reply run.
