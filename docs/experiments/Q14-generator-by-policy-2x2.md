# Q14 — Generator by policy: does the tuned stack help Gemma as much as Qwen

Status: REGISTERED
Experiment class: display-policy
Owner: Tilde research program
Pre-registered: 2026-09-02T14:40:00Z

## Pre-registration

### Hypothesis

The tuned display stack lowers bad-when-shown for the production Gemma 4 E2B
generator by at least as much as it does for Qwen 3.5 9B, while retaining
useful displays — that is, the Q12/Q13 win is a property of the display
policy and not of the 9B generator.

### Why this should work

Q12 and Q13 measured the tuned filters on one generator only. Their stated
mechanism is generator-independent: the three-word cap keeps the reliable
head of a suggestion and hides the tail where generation goes wrong (Q13,
where widening the window to eight words moved bad-when-shown from 18.1% to
48.9%); the 24-character scene-echo floor stops short verbatim answers being
mistaken for echo (Q12, +61.7% useful at unchanged bad displays); grounding
removes unsupported-fact wrongs (Q12, 35 wrongs at zero useful lost). Nothing
in those three mechanisms reads model size.

The question is genuinely two-sided. The checked-in directional catalog puts
Gemma E2B far below Qwen 9B on the output-only exam (17 versus 43), so a
larger share of Gemma's candidates may be junk that a head-only cap cannot
rescue, and names-and-numbers grounding may cost Gemma useful displays it
cannot afford. A stack tuned on a strong generator can be the wrong stack for
a weak one, and today the tuned values are already served for the official
Qwen choice while production Gemma still runs the conservative gates. This
experiment is the fair test that decides whether that split should stay.

### Design: one 2×2, two campaigns

The factorial is generator × policy:

| | conservative policy | tuned policy |
| --- | --- | --- |
| **Gemma 4 E2B** | arm `conservative` | arm `tuned` |
| **Qwen 3.5 9B** | arm `conservative` | arm `tuned` |

A Tilde Lab campaign holds exactly one model, so the 2×2 is two owner-local
two-arm campaigns that share the same suite, partition, seeds, block size,
runtime, prompt, generation, scoring, and scenario coverage. The policy
contrast is paired by root inside each campaign. The generator contrast is
between campaigns and therefore **not** paired; it is read as a
difference-in-differences and carries the weaker claim (see confounders).

### Control

Arm `conservative` — `DecisionPolicy.conservative`, the measured production
Gemma stack, byte for byte:

- maximum visible words 8, maximum visible characters 80 (the derived default
  allowance for eight words);
- scene echo minimum 3 words / 10 characters;
- factual grounding off;
- extended ordinary-silence gate off.

### Treatment

Arm `tuned` — the display filters of `DecisionPolicy.tuned9B`:

- maximum visible words 3, maximum visible characters 42;
- scene echo minimum 3 words / 24 characters;
- factual grounding names-and-numbers;
- extended ordinary-silence gate off.

The two arms differ in exactly four judgment fields and their identifier.
Everything else in the manifest is identical, and both campaigns carry
byte-identical arms.

### What this instrument cannot express

`DecisionPolicy.tuned9B` also sets `replyCueAnchoredToCurrentSentence` and
`includesWindowTitleInScene` true. `LabArmConfiguration` has no field for
either knob today, so both arms in both campaigns hold the Lab default (reply
cue unanchored, no window title in the scene). Q14 therefore measures the
**display-filter half** of the tuned stack. The two scene-composition changes
of 2026-09-01 are untested by this experiment, are not promoted by any result
it produces, and need either their own registered question or a Lab arm field
before they can claim evidence. The registration says so before the run so
the gap cannot be quietly absorbed into a later promotion claim.

### Data, runtime, provenance

Certified Corpus V2, development partition, full suite (1,000 situations,
600 speak roots), seeds 17/41/73, repetitions 1, interleaved root block size
10, 3,600 planned model requests per campaign, 8 workers × 2 slots, AC power
under `caffeinate`, quality-only with no latency claims. Both campaigns are
registered from a clean tree before either runs, and neither uses `--resume`.

### Primary metric

Bad-when-shown, the registered `display-policy` default and the same
accounting Q12 and Q13 used: the paired `tuned` − `conservative` difference
within each campaign, with root-clustered bootstrap intervals (10,000
iterations) and probability of positive effect.

### Guardrail

Useful-display retention: within each campaign the `tuned` arm must keep at
least 95% of the `conservative` arm's useful displays. A harm reduction bought
by going quiet is not a win — the same trap the ledger records for
prompt-minimal variants.

### Supporting metrics

Net keystrokes saved; precision-when-shown; the between-campaign
difference-in-differences on bad-when-shown (the actual generator × policy
interaction); per-category slices with attention to `reply.commit.delivery`,
`reply.clarify.item`, `stress.sensitive-near-miss`, and
`stress.contradiction.latest-fact`; unsupported-fact wrong counts; ordinary
and sensitive silence slices.

### Hard gates

Sensitive-scene suppression perfect in every arm; the block-zero prompt-leak,
sensitive, stale-context, echo/replay, and unsupported-fact sentinels pass;
no gate weakened other than the three registered display knobs; no personal
writing, screen text, prompt, candidate, model output, or local path in any
checked-in artifact; production defaults untouched by either campaign.

### Promotion rule

The tuned arm promotes to the **production Gemma default** only when all of
the following hold, on the **validation** partition, in a clean, complete,
reviewed v6 report:

1. it wins the primary metric — bad-when-shown lower, the 95% root-clustered
   interval excluding zero, probability of positive effect ≥ 0.95;
2. the guardrail holds — useful displays ≥ 95% of the control arm's;
3. no protected slice regresses and no hard gate fires;
4. the review is recorded `supported`.

This development pair promotes nothing. It can only nominate frozen
validation candidates, and the standard path after validation — one sealed
holdout, isolated preview, meaningful live dogfood, real IMKit interaction
proof across the host matrix, and explicit owner approval — is unchanged.
Because the two scene-composition knobs are outside this instrument, a
promotion built on Q14 changes the Gemma display filters only.

### Kill rule

Kill "tuned for Gemma" if bad-when-shown does not fall for Gemma, if it falls
but the useful-display guardrail breaks, or if any silence or sensitive slice
regresses. Kill the broader "the policy is generator-independent" claim if
the Gemma and Qwen effects have opposite signs; in that case the tuned values
stay a Qwen-only configuration and the production split is the correct
answer, not a temporary one.

### Known confounders

- The generator contrast is unpaired: two campaigns, two processes, two model
  loads, possibly different thermal and time conditions. Only the policy
  contrast inside each campaign is paired evidence; the interaction is
  weaker, and a small difference-in-differences should not be over-read.
- Generation is the Q11–Q13 chain (temperature 0.10, 12 generated tokens,
  minimum mean token probability 0.475, production-streaming, production
  prompt recipe), held identical for both models by design. That recipe was
  selected on Qwen, so the Gemma arms run a Qwen-tuned generator: the exam is
  the same for both, but neither model is at its own best. A generator-class
  question for Gemma is a separate experiment.
- Development-partition reuse: the tuned values were selected by replay and
  confirmed on this same partition in Q12/Q13. A development win for the
  tuned arm on Qwen is expected and carries no new information; the Gemma
  column is where the new information is.
- The reply-cue and window-title gap described above.
- Offline synthetic instrument: flicker, reading cost, interruption, and
  retention on real typing are invisible here and remain H01's live question.

### Frozen provenance

- Git commit: `eb4116db34160a3713408648b88e3439c939cbc1` — the clean tree
  this registration was written against, and the parent of the registration
  commit on `audit/promotion-campaign`.
- Dirty state: clean at registration.
- Model revision and SHA-256, both verified locally to be byte-identical to
  the pinned production assets:
  - Gemma 4 E2B Q4_K_M — revision
    `3762686d74ff8db6c98f8d3c389f56fbdf994d5a`, SHA-256
    `389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`;
  - Qwen 3.5 9B Base Q4_K_M — revision
    `ec5c6b42ca313fc71afe4a40b068d3f7026bf4f6`, SHA-256
    `4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2`.
- Helper SHA-256:
  `f6ed54086fabf3b7c81c7a0c2d96b835c451406fccec9b6fad62f8d74754e0ff` — the
  same signed `llama-server` for both campaigns, so the helper cannot explain
  a generator difference.
- Runner SHA-256: recorded by each run in its v6 report.
- Suite and selection SHA-256: Certified Corpus V2 development selection;
  digest recorded by each run.
- Scoring SHA-256: `net-keystrokes-v1`, weights locked during comparison;
  digest recorded by each run.
- Arm SHA-256 values: stamped by the runner. Verified before registration:
  the two arms differ in exactly `id`, `maximumVisibleWords`,
  `maximumVisibleCharacters`, `sceneEchoMinimumCharacters`, and
  `factualGrounding`, and the two campaigns differ only in campaign identity
  and model identity.
- Invocation digest: recorded by each run.
- OS, hardware class, and power state: the owner's Mac on AC under
  `caffeinate`; recorded by each run.
- Campaigns: `854580D7…` (Gemma) and `4F000A58…` (Qwen), both
  `tilde-lab.research-campaign.v2`, validated and not yet run. The manifests
  are owner-local and stay out of Git.

## Result

Status: NOT RUN
Completed: —

### Aggregate evidence

None. Both campaigns are registered and validated; neither has been executed.

### Failures and limitations

Stated in advance: the unpaired generator contrast, the Qwen-tuned generation
recipe applied to both models, development-partition reuse for the Qwen
column, the two `tuned9B` scene knobs this instrument cannot vary, and the
absence of any live feel or interruption evidence.

### Decision

Pending.

### Durable changes

- Learning Ledger entry: none. `docs/learning-ledger.md` admits an entry only
  for a decision or a reusable lesson, and the research queue only when
  evidence changes the order or requirement; a registration is neither. Q11,
  Q12, and Q13 are likewise absent from the bundled ledger. An entry becomes
  due when Q14 has a reviewed result.
- Lab log: appended by the orchestrating session on the day of registration.
- Regression IDs: none yet.
- Implementation pull request: none — this registration changes no product
  behaviour and no Swift.
- Rollback: not applicable; production defaults are untouched.

### Follow-up

If the tuned stack helps Gemma, the next question is whether the two
scene-composition knobs of `DecisionPolicy.tuned9B` (anchored reply cue,
window title in scene) carry any of the effect — which first needs a Lab arm
field so they can be varied at all. If it does not, the next question is
which single filter breaks on the weaker generator: the three-word cap, the
24-character echo floor, or names-and-numbers grounding.
