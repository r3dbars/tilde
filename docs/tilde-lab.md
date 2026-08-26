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

## Autoresearch campaigns

The **Autoresearch** screen adapts the experiment loop from
[Andrej Karpathy's autoresearch](https://github.com/karpathy/autoresearch) to
Tilde's native Swift/macOS constraints. It does not import the original
NVIDIA/Python trainer. It preserves the useful protocol:

1. lock one suite, goal contract, model, and baseline;
2. establish the baseline before changing anything;
3. mutate one bounded knob, run the same evaluation, and append a checkpoint;
4. keep the candidate only when gate-first ranking beats the current champion;
5. discard regressions, periodically rerun the control, and confirm the final
   champion with more repetitions.

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
`tilde-lab.experiment-manifest.v1`. It contains every experiment and runtime
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

The app opens on Certified Corpus V2's development partition. For a one-arm
unattended CLI run without a manifest, the improved V2 quiz and its 80-case
validation partition remain the compatibility default:

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
update contract.

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
The consolidated **Tilde Model Preview** applies these controls only while its
selected model is Qwen 9B; production Tilde remains pinned to Gemma 4 E2B and
unchanged.

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
validation. **Quiz** in the app can switch back to the explicit 16-case
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
directory and file permissions. Version 4 reports contain:

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
