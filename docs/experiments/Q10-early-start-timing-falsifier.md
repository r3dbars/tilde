# Q10 — K=1 early-start timing falsifier

Status: IMPLEMENTING
Experiment class: generator
Owner: Tilde research program
Pre-registered: 2026-08-29T15:55:00Z

## Pre-registration

### Hypothesis

Starting one short continuation after the third typed character of the
current word, instead of at the following space, buys a real readiness lead:
the early candidate is ready by the next useful word boundary for at least
half of opportunities, arrives at least 200 ms before a boundary-started
request, is safely lockable on at least 15% of opportunities, produces fewer
than 2% simulated false locks, and costs no more than 1.5x today's decoding.

### Why this should work

Today Tilde asks for a continuation at the word boundary and then pays the
model's full latency inside the writer's typing window. "Think early, reveal
late" moves the request earlier without moving the reveal: the branch is
started mid-word, kept hidden, and revealed at the boundary only if it is
still prefix-compatible with what the writer actually typed. A branch that
the writer contradicts is destroyed silently, so a wrong hidden branch costs
compute and never a wrong display.

The mechanism only pays if two measured facts hold together. The generation
must finish inside the few hundred milliseconds the writer spends finishing
the word, and the candidate must still agree with the characters the writer
types in that window. Q09 measured K=1 readiness at p50 357 ms on a different
(Qwen 3.5 9B) stack, which is slower than a single typing window but not
obviously slower than three-to-six characters of typing. Nothing in the
program has yet measured whether a mid-word branch survives to the boundary.
That is the falsifiable half, and it is cheap to kill offline.

If the lead or the compatibility rate is too low, the whole prewarm family —
including the shadow-timing follow-up Q09 declined to authorize — dies here
for the price of one offline replay.

The owner explicitly authorized this bounded offline discovery falsifier on
2026-08-29 (issue #434) ahead of Stage 0 closure. It does not unlock roadmap
Stage 4 or H15, does not authorize live precomputation or a live shadow, and
changes nothing in the production or Model Preview applications.

### Control

Today's behaviour: one greedy continuation requested at the word boundary,
that is, after the writer has typed the whole word and the following space.
Production prompt, production scene context, production intent hints, the
production output cleaner capped at three visible words and 48 characters,
12 generated tokens, temperature 0, seed 0, frozen production Gemma 4 E2B.

### Treatment

One bounded difference: the identical request is issued after the third
character of the same word instead of at the following space. Same prompt
shape, same sampler, same token budget, same cleaner, same model, same
machine. Only the cursor position at which the prompt is snapshotted moves.

### Secondary arm (hot/cold pair)

At every early start point a second candidate is generated from the same
mid-word prompt with temperature 0.80 and frozen seed 907, forming a
deliberately opposite pair with the greedy branch.

Q09 already rejected diversity-by-sampling at temperature 0.40: 16 branches
produced a median of 2 distinct first-two-content-word paths and the
diversity gate failed. Q10 does not retry that design. It tests the narrower
untested variant the owner proposed — exactly two opposed decoding policies,
greedy plus one hot branch — and it tests it at the early start point, where
the pair is cheap because both branches are hidden.

### Data and split

- Certified Corpus V2 development partition only;
- all 360 speak-expected development situations, each with a recorded golden
  continuation (selected-suite digest
  `5bbc362c93e4cf1e3383b81dfe56a48a2f7c5160cc492ad4e1a00b99ddd5b46c`, the
  same 360-situation selection Q09 used);
- each situation's golden continuation is replayed character by character;
- a word becomes an opportunity when it has at least four characters, is
  followed by exactly one space, and leaves at least six golden characters
  after that space, capped at the first six opportunities per situation;
- that plan yields 637 opportunities and 1,911 planned generations
  (cold early, hot early, boundary control at each opportunity);
- one pass, no repetitions, project-owned synthetic text only; and
- a 4-situation machinery smoke before the decisive run. The smoke may stop
  the run for machinery, privacy, protocol, or resource failure, never for a
  weak efficacy result, and no smoke number sets a gate.

Validation and holdout remain unopened.

### Timing model

Lead and readiness need a frozen keystroke model, because an offline replay
has no real inter-keystroke timing. Registered before the result:

- inter-character interval: 180 ms (about 66 wpm), applied uniformly;
- time from the early start to the boundary equals the characters still to be
  typed, through and including the boundary space, times that interval;
- reported sensitivity points at 120 ms and 240 ms. The registered decision
  uses 180 ms only; the sensitivity points may qualify a conclusion but may
  not replace it.

### Primary metric

`candidate_ready_by_next_boundary`: percentage of opportunities where the
early greedy request completes within the typing time remaining from the
third character through the boundary space.

### Supporting metrics

- median lead in milliseconds versus the boundary-started request, with p25
  and p75;
- prefix compatibility through the boundary: the early candidate still shares
  every exact character the writer types from the cut through the boundary;
- lockable opportunities: ready, compatible, and carrying at least six exact
  golden characters beyond the boundary;
- simulated false locks, defined below;
- compute multiple in decoded tokens and in summed request latency;
- early and boundary request latency p50 and p95;
- mean exact golden characters available beyond the boundary;
- the rate at which the production cleaner suppresses the mid-word candidate,
  and compatibility measured on the uncleaned continuation, so a cleaner
  artefact cannot be misread as a model miss;
- pair arm: cold-only lockable rate, pair lockable rate, the gain in
  percentage points, hot-only locks, pair compute multiple, the rate at which
  the hot branch duplicates the cold one, and the rate at which the hot
  branch survives the production cleaner; and
- thermal state, power state, and low-power mode at start and finish.

Exact Unicode-normalized character prefixes are the only compatibility and
coverage signal. Semantic similarity cannot count as a match.

### Definitions frozen before the run

- **Opportunity.** One qualifying word inside one golden continuation, as
  defined under *Data and split*.
- **Ready.** The early request's measured latency is no greater than the
  typing time remaining to the boundary.
- **Compatible through the boundary.** After canonical Unicode normalization
  and leading-whitespace trimming, the early candidate's leading characters
  equal every character the writer types from the cut through the boundary
  space.
- **Revealed.** Ready and compatible: the reveal rule fires.
- **Lockable.** Revealed, and at least six exact golden characters remain in
  the candidate beyond the boundary, so there is something worth showing.
- **Simulated false lock.** Revealed, yet the candidate's leading characters
  differ from the typed characters when compared scalar by scalar without
  canonical mapping. This is a soundness check on the reveal rule — it counts
  locks accepted only because normalization hid a real difference — and it is
  expected to be near zero. It is not a measure of suggestion quality.
- **Compute.** The control decodes one boundary request per opportunity. The
  treatment decodes one early request per opportunity, plus a boundary
  request only where the early branch was late or contradicted: a branch that
  arrives in time and still agrees with the typed characters is the answer at
  the boundary, whether or not it is long enough to display. The compute
  multiple is treatment decoded tokens over control decoded tokens.

### Hard gates

- no personal writing, screen text, raw prompt, raw candidate, golden text,
  scenario text, or per-case output may be persisted, printed, logged, or
  checked into Git;
- the model must verify as the pinned production Gemma 4 E2B Q4_K_M
  (revision `3762686d74ff8db6c98f8d3c389f56fbdf994d5a`, SHA-256
  `389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`); an
  experimental model, a manifest, or a campaign is refused at argument
  parsing;
- AC power, normal power mode, and a non-serious thermal state at start; the
  runner refuses to begin otherwise;
- one worker, one slot, no prompt caching, no cache reuse, and strictly
  sequential requests, so a measured latency stands for an idle-machine
  request and request ordering cannot leak timing between the three
  generations of an opportunity;
- no concurrent live dogfood typing during the decisive run (Q07's
  concurrency confound);
- every planned opportunity must receive exactly three terminal generations;
- the running production and Model Preview applications must not be stopped,
  replaced, or reconfigured;
- no validation or holdout data may be opened; and
- any protocol error, timeout, model or helper mismatch, non-loopback
  inference, memory-pressure warning, or serious/critical thermal state makes
  the result `INCONCLUSIVE`, not a pass. Fair thermal state is reported and
  requires a nominal-state sensitivity check before latency can support a
  decision.

### Promotion rule

The early-start mechanism may promote only to a later registered shadow
timing and lock experiment when all five hold:

- candidate ready by the next boundary on at least 50% of opportunities;
- median lead at least 200 ms;
- lockable opportunities at least 15%;
- simulated false locks below 2% of revealed locks; and
- compute multiple at most 1.5x.

The pair arm earns promote-interest — not promotion — when pair lockable
coverage exceeds cold-alone coverage by at least 5 percentage points at a
pair compute multiple of at most 2.0x.

Passing authorizes no live shadow, no precomputation in the IME, and no
production change.

### Kill rule

Reject the early-start family when any of these occurs:

- candidate ready by the next boundary below 50%;
- median lead below 200 ms;
- lockable opportunities below 15%; or
- simulated false locks at or above 2% of revealed locks.

Reject the hot/cold pair when either occurs:

- the hot branch duplicates the cold branch on at least 50% of
  opportunities; or
- fewer than 60% of hot branches survive the production cleaner, the frozen
  proxy for "mostly incoherent."

A compute multiple above 1.5x with every other gate passing revises rather
than kills: retain the mechanism and register a cheaper follow-up, but do not
promote. Do not respond to failure by starting earlier than the third
character or by adding branches.

### Known confounders

- The keystroke model is frozen, uniform, and synthetic. Real typing is
  bursty, so a 180 ms mean will overstate the lead in fast bursts and
  understate it in pauses. That is why 120 ms and 240 ms are reported.
- The golden continuation is a frozen synthetic path, not proof of a writer's
  latent intent or live acceptance. Compatibility with it is an upper bound
  on what a target-blind lock can achieve.
- The production output cleaner was tuned for boundary starts. The
  4-situation machinery smoke showed it suppressing a non-trivial share of
  mid-word candidates, so the run reports the suppression rate and the
  uncleaned compatibility rate alongside the primary metric. A large gap
  between them means Q10 measured the cleaner, not the model.
- The same smoke suggested mid-word requests decode more tokens before their
  stop rule than boundary requests do. If that holds at scale, the compute
  gate is the most likely of the five to fail even when the timing gates
  pass. It is registered at 1.5x anyway, from the owner's product prior.
- Latency measured through the Lab HTTP client on an idle single-slot server
  is not the same as latency inside the IME's live request path.
- Running beside the daily Model Preview can affect timing even when it does
  not affect candidate content.
- The pair arm's coherence proxy is cleaner survival, not a judge. A fluent
  but useless hot branch counts as surviving.

### Frozen provenance

- Source commit: `f609ab6c` (the implementing commit; provenance was frozen
  in the follow-up commit before the decisive run, and is not amended after
  the run starts)
- Dirty state: must be clean at run start
- Model: Gemma 4 E2B Q4_K_M (production pinned)
- Model revision: `3762686d74ff8db6c98f8d3c389f56fbdf994d5a`
- Model SHA-256:
  `389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`
- Helper SHA-256: recorded by the run; the signed in-app `llama-server`
- Runner SHA-256 (`Sources/TildeLabKit/Services/LabEarlyStartRunner.swift`
  at `f609ab6c`):
  `3573e132e64b1068555b1b8d84380ec2dadef2c62cbfe4124950128ff1efdb79`
- Suite and selection SHA-256:
  `5bbc362c93e4cf1e3383b81dfe56a48a2f7c5160cc492ad4e1a00b99ddd5b46c`
- Scoring: production output cleaner, three visible words, 48 visible
  characters; exact Unicode character prefixes only
- Arm values: cold temperature 0 seed 0; hot temperature 0.80 seed 907;
  12 prediction tokens; early character offset 3; minimum word length 4;
  minimum useful characters 6; keystroke interval 180 ms
- Invocation digest (SHA-256 of
  `tilde-lab-runner --early-start-full --helper /Applications/Tilde.app/Contents/Helpers/llama-server`):
  `d1f4f96169a1de880d2ba6b878d118f5cf80abb68fec9477bc9aa19b6a55db30`
- OS, hardware class, and power state: recorded by the run; AC power required

### Overnight invocation

One command, from the repository root, on the Mac, on AC power, with no live
dogfood typing in progress:

```sh
swift build -c release && \
  ./.build/release/tilde-lab-runner --early-start-full \
    --helper "/Applications/Tilde.app/Contents/Helpers/llama-server" \
    --early-start-output ~/Desktop/q10-early-start.json
```

`--early-start-full` freezes the 360-situation development selection, one
worker, one slot, no prompt caching, 12 prediction tokens, a three-word
visible cap, and the production-fidelity prompt. The report is written
atomically and printed to stdout; it contains aggregates only. On this
hardware the smoke measured roughly 100 ms per generation, so 1,911
generations should finish well inside an hour — it is scheduled unattended so
nothing else competes for the machine, not because it is long.

The machinery smoke, if the helper has moved or the corpus has changed, is
the same command with `--early-start-smoke` and no output path.

## Result

Status: NOT RUN
Completed: —

### Aggregate evidence

Pending the decisive run. Nothing may be written here before it completes.

### Failures and limitations

Pending.

### Decision

Pending.

### Durable changes

- Learning Ledger entry: none yet; add one only if the result is reusable
- Lab log: `2026-08-29 — Pre-register the early-start timing falsifier`
- Regression IDs: none
- Implementation pull request: [#435](https://github.com/r3dbars/tilde/pull/435)
- Rollback: delete the development-only runner path and its CLI flags;
  production is unchanged either way

### Follow-up

Pending the result.
