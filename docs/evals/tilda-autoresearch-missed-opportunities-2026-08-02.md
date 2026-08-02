# Tilda autoresearch plan: reduce missed opportunities — 2026-08-02

## Goal

Reduce cases where Tilda should have offered a useful completion but returned
nothing, without making the app noisier, slower, or less safe.

The latest fresh holdout recorded 1,546 missed opportunities out of 10,000
cases with three retrieved examples. In this scorer, a miss means an otherwise
predictable case produced no suggestion. A wrong suggestion is counted
separately as an interruption. This distinction matters: simply speaking more
would lower misses while making the product worse.

## Baseline and gates

Current baseline: `exact_3` from the fresh retrieval holdout.

- Missed opportunities: 1,546 / 10,000
- Safe accepts: 953 / 10,000
- Interruptions: 7,501 / 10,000
- First-word match: 28.03%
- P95 latency: 135 ms
- Protocol errors: 0

A candidate is a meaningful win only if it has at least 50 fewer misses per
10,000 cases (0.5 percentage points), while also meeting all of these gates:

- safe accepts do not fall below 953;
- interruptions do not increase by more than 50 cases (0.5 points);
- p95 latency stays at or below 150 ms;
- protocol errors remain zero;
- no expected-silence or privacy gate regresses;
- no individual app surface has a large quality regression hidden by the total.

The evaluator, case IDs, scoring rules, privacy filters, and holdout splits are
frozen. Only the candidate configuration or one small code path may change.

## What Karpathy-style autoresearch means here

This is not an agent randomly rewriting Tilda. It is a tight loop:

1. The controller chooses one small knob change.
2. Tilda runs the same frozen cases.
3. The scorer records misses, safe accepts, interruptions, and latency.
4. The controller keeps the change only when it beats the gates.
5. Losing changes are reverted; every attempt stays in the ledger.

The model, corpus, scorer, and safety checks are the test lab. The prompt,
retrieval policy, thresholds, and other listed settings are the things we are
allowed to tune.

## First: make the 1,546 misses explainable

Before optimizing, add aggregate-only miss reasons to the local eval output.
Do not save text. Every miss should be assigned one primary reason:

- model returned empty;
- confidence gate suppressed it;
- short-context gate suppressed it;
- cleaner or echo guard rejected it;
- token/word budget ended it;
- timeout or incomplete stream;
- retrieval had no confident match;
- wrong app/register or missing screen context;
- other protocol failure.

Also bucket misses by app, prefix length, field type, punctuation/opening,
retrieval hit count, and latency band. This tells the controller which knob can
actually affect each failure instead of tuning blindly.

## Variables to test

### 1. Coverage and confidence gates

These are the highest-probability levers for lowering empty responses.

- First-token confidence threshold: `0`, `.01`, `.02`, `.04`, `.06`, `.08`.
- Short-context threshold: `30`, `60`, `90`, `120` characters.
- Short-context confidence threshold: `0`, `.01`, `.02`, `.03`, `.04`.
- Mid-generation confidence floor: `0`, `.02`, `.04`, `.06`.
- Generated token budget: `8`, `16`, `24`, `32`.

### 2. Retrieval and memory

These determine whether the model receives useful personal context.

- Retrieved examples: `0`, `1`, `2`, `3`, `4`, `5`.
- Similarity floor: low, medium, high confidence bands.
- Same-app weight: none, light, equal, strong.
- Same-field/register weight: none, light, strong.
- Current-document/current-thread weight: none, equal, dominant.
- Recency decay: none, 7-day, 30-day, 90-day half-life.
- Example length: `40`, `80`, `160`, `320` characters.
- Source policy: accepted-only versus accepted-plus-kept; typed-over and
  quickly deleted text remain negative evidence, never positive training data.
- Deduplication: exact, near-duplicate, semantic cluster.

### 3. Prompt construction

- Raw continuation prompt versus instruct prompt.
- Typed text before retrieved examples versus retrieved examples first.
- One compact examples block versus individually labelled examples.
- Explicit “use only when relevant” instruction on or off.
- Screen context: none, accessibility text, OCR summary, or both.
- Screen-context budget: `0`, `300`, `700`, `1200` characters.
- Typed-context budget: `300`, `700`, `1500`, `3000`, `5000` characters.

### 4. Decoding and generation

- Temperature: `0`, `.05`, `.10`, `.20`.
- Top-p: `.80`, `.90`, `.95`, `1.0`.
- Top-k: `20`, `40`, `80`.
- Min-p: `0`, `.02`, `.05`.
- Repeat penalty: `1.0`, `1.05`, `1.10`.
- Maximum visible words: `4`, `6`, `8`, `10`.
- Stop behavior: newline-only versus newline plus end-of-turn.

### 5. Output and scheduling policy

- Echo-guard minimum run: `2`, `4`, `6`, `8` words.
- Suppress versus shorten when the confidence drops mid-suggestion.
- Per-app chattiness: quieter, default, or more available.
- Request debounce: `0`, `25`, `50`, `100` ms.
- Cache reuse and prompt prewarm on or off.
- One bounded retry on an incomplete stream versus immediate silence.

### 6. Later personalization experiments

Do these only after retrieval and gating have a clean result:

- current-document n-grams;
- phrase memory;
- vector retrieval;
- aggregate style profile;
- per-app preference profile;
- nightly personal adapter/LoRA.

The personal adapter is not allowed to enter the base-model loop until it beats
the frozen retrieval baseline on a separate personal holdout and passes the
same interruption, latency, and privacy gates.

## Test budget

Count one test as one local model request. A configuration run is a batch of
tests.

### Campaign 1: diagnose and screen — about 42,000 requests

- Repeat the baseline twice on the 10,000-case holdout: 20,000 requests.
- Run 32 one-knob candidates on a balanced 1,000-case screen: 32,000
  requests.
- Keep only candidates that beat the screen gates. Do not combine knobs yet.

The 32 candidates should cover the confidence/gate, retrieval, prompt, and
output groups before touching model weights.

### Campaign 2: verify interactions — about 36,000 requests

- Take the six best single-knob candidates.
- Run each on a fresh 3,000-case balanced subset twice: 36,000 requests.
- Test only the pairs that have a plausible dependency, such as retrieval
  count plus similarity floor or confidence threshold plus context length.

### Campaign 3: full confirmation — about 64,000 requests

- Choose the top three configurations.
- Run all 10,000 holdout cases twice: 60,000 requests.
- Run a separate 4,000-case adversarial deck: short prefixes, app switches,
  code-like text, punctuation, stale memory, echo traps, and expected-silence
  cases.

This gives roughly 140,000 new local requests in a disciplined campaign,
without wasting 100,000 requests on every weak combination.

## Keep/revert rules

Each attempt gets a checkpoint, config snapshot, log, aggregate JSON, and one
row in `results.tsv`. The controller must record rejected and crashed attempts,
not only winners.

Keep a candidate when it reduces misses by at least 50/10,000 and passes every
guardrail. Revert it when it only speaks more, increases interruptions, or
helps one app by hurting another. Repeat a likely winner when its quality gain
is small or its latency is noisy.

Do not change the scorer, hide failures, import raw personal bodies, or tune on
the final holdout. The final holdout is opened only for confirmation.

## Expected output

The autoresearch run should return:

- the best configuration and exact checkpoint;
- misses reduced and which miss reasons changed;
- safe-accept, interruption, first-word, keystroke, and latency deltas;
- per-app results;
- rejected configurations and why they lost;
- a recommendation for the next local pilot.

The first implementation target is therefore not “train a new model.” It is a
small, measurable retrieval-plus-gating policy that makes Tilda speak in more
of the right moments while staying quiet in the wrong ones.
