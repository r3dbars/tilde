# Tilde Learning Ledger

The Tilde Learning Ledger is the repository's curated memory of what experiments
actually taught us. It exists to prevent three expensive mistakes:

1. repeating a failed experiment because its conclusion was trapped in a log;
2. promoting a candidate because two incompatible scores looked comparable;
3. forgetting why a tempting configuration was rejected.

The machine-readable source of truth is
`Sources/TildeLabKit/Fixtures/learning-ledger-v1.json`. Tilde Lab displays it in
**Learning Ledger**, and the CLI reads the same bundled file:

```bash
swift run tilde-lab-runner --learning-ledger
swift run tilde-lab-runner --learning-ledger --json
```

The ledger contains aggregate findings, decisions, limitations, evidence IDs,
the promotion path, and the prioritized research queue. It contains no scenario
text, prompt text, model output, personal writing, private corpus material, or
local file paths. Validation rejects those raw-data keys and paths even though
Swift's normal decoder would ignore unknown JSON fields.

## What the recent work established

### The measuring system

- Tilde Lab is a separate app and CLI; it does not ship in the input method.
- Certified Corpus V2 is the current offline measuring stick: 1,000 distinct
  situations, 600 speak, 400 silence, 40 behavioral families, 500
  counterfactual pairs, and a locked 600/200/200 split.
- Correct scene context produced 33.3% correct starts versus 20.0% with wrong
  context and 14.5% with typed text alone. This proves context signal, not
  product readiness: absolute net keystroke savings remained negative.
- Human-acceptable output includes one recorded continuation and seven reviewed
  alternatives per reply opportunity. Exact path and accepted alternative stay
  separate.
- Net Keystrokes Saved is the product headline. Wrong interruptions, safety,
  privacy, temporal integrity, interaction integrity, and latency are separate
  gates and cannot be averaged away.

The corpus review receipt is a structured Codex review, not independent human
ground truth. The corpus is strong enough for controlled development, while
human calibration and live use remain required.

### Configuration research

- Early narrow tests repeatedly pointed toward a three-word visible cap.
- The 90,000-evaluation Certified V2 campaign confirmed it as the best safe
  display change: human-acceptable output rose from 14.5% to 18.1%, net savings
  moved from -1.0% to +0.4%, and factuality remained 99.3%.
- Removing scene-echo safety looked much better numerically because it allowed
  unsafe aggression. Prompt-minimal variants looked safe by becoming silent.
  Neither was a product winner.
- Temperature and broad sampler changes generally hurt. Generated-token budgets
  from 12 to 36 and larger context budgets were mostly inert in that campaign.
  Production prompt examples were essential.
- The Qwen 9B campaign ran 50 arms and 18,000 evaluations. Its clean confirmation
  selected temperature 0.10, 12 generated tokens, and a three-word cap with all
  protections enabled. Quality rose 43 to 44 and wrong suggestions fell 93 to
  88, while Net Keystrokes Saved slipped from 11.3% to 11.1%. It is an
  experimental preview configuration, not a production promotion.
- One- and two-word “wins” bypassed the three-word scene-echo threshold.
  Repeat-penalty “wins” increased wrong interruptions. Both are permanent
  regression targets, not candidates.

### Model research

The checked-in catalog preserves all exact model revisions, hashes, report IDs,
quality counts, and latency snapshots. Qwen 3.5 9B Q4_K_M is the strongest
observed quality lead at 43/100; Nemotron 9B is close at 42 but much slower;
Gemma 26B peaks at 40; production Gemma E2B scores 17 on this output-only exam.

This is a **directional catalog**, not one perfectly matched tournament. The
historical runs share the same 360 cases, prompt, greedy sampler, three-word cap,
one worker, and one slot, but they used three helper hashes and both 8-token and
20-token budgets. Each entry now records its `comparisonGroupID`, helper hash,
and generation recipe. Strict performance claims require matching those fields.

Other durable model lessons:

- more parameters did not guarantee better autocomplete;
- Gemma 26B Q2 collapsed to 6/100 while Q3/Q4 remained near 40;
- Qwen 35B-A3B scored below Qwen 9B and Qwen 4B;
- the tested MLX-labelled Qwen 4B report did not beat llama.cpp, but its report
  identifies `local-llama` and an external helper, so it is not a clean general
  MLX framework verdict;
- uncompleted Nemotron 30B and Gemma 12B downloads, and untested Qwen 9B lower
  quants, have no result.

### Frontier and live evidence

- The same 50-case semantic shootout measured Gemma E2B at 53/100 and 34%
  useful, versus Sol at 84/100 and 72% useful. It is directional because Sol was
  both contestant and referee, hosted settings were not pinned, and Sol strict
  scores varied across snapshots.
- Production Gemma E2B has a meaningful 1,213-completion latency snapshot:
  91 ms p50, 190 ms p95, and 339 ms p99. Model latency passed; display capture
  p99 narrowly missed its budget and availability failures need separate work.
- The fixed 26B preview reached 339 completions but missed tail-latency budgets
  with 1,061 ms model p99.
- The current selectable Qwen preview has 148 recorded model completions: 192 ms
  p50, 366 ms p95, and 416 ms p99. That remains below the 200-completion verdict
  floor and currently misses the 400 ms p99 budget.
- Served and cleaner-rejected counts are operational evidence, not proof that a
  human liked or accepted the suggestion.

## Evidence that remains incomplete

The local archive contains 598 privacy-safe aggregate Reply reports and more
than one million scored evaluations. That is deep evidence in one lane, not
complete macOS product proof. There is no persisted real Interaction, Scene
Memory, Personalization, Performance, semantic-shootout, or completed protected
Learning Cycle result yet.

Legacy v1-v3 reports also predate the current bad-suggestion, temporal-integrity,
and Net Keystrokes Saved fields. Compatibility defaults keep those files
readable; they do not retroactively create measurements. Old campaign champions
therefore remain archived diagnostics.

Campaign state also needs hardening. Seven local ledgers say `running` while no
runner exists. A healthy run requires a fresh campaign ID, a live child model
server, and increasing progress—not merely a parent process or JSON state.

## Promotion path

Every proposed change moves through:

1. controlled development experiment;
2. protected validation;
3. one sealed holdout evaluation;
4. isolated model preview;
5. meaningful live dogfood at 200, 500, and 1,000-completion checkpoints;
6. real IMKit interaction proof across the host matrix;
7. explicit, reproducible, rollback-ready production approval.

The prioritized next experiments live in the JSON ledger rather than in a
second drifting checklist. The current first three are meaningful Qwen live
evidence, protected Qwen validation, and a permanent sanitized regression
library for every scoring loophole and observed failure.

## Updating the ledger

Add a ledger entry only when there is a decision or reusable lesson. Include the
protocol, aggregate metrics, evidence IDs, limitations, and what changed as a
result. Do not copy local report dumps into Git. Update the research queue and
promotion path only when the evidence changes the order or requirement.

Then run:

```bash
swift test --filter LabLearningLedgerTests
swift run tilde-lab-runner --learning-ledger
./script/proof.sh fast
```
