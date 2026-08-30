# Q12 — Scene-echo floor retune and names-and-numbers grounding

Status: REGISTERED
Experiment class: display-policy
Owner: Tilde research program
Pre-registered: 2026-08-30T15:05:00Z

## Pre-registration

### Hypothesis

Raising the scene-echo character floor from 10 to 24 recovers a large
share of the fact-carrying suggestions the detector currently kills
(offline replay: +292 useful, zero measured cost on any slice), and
enabling names-and-numbers factual grounding independently removes
unsupported-fact wrongs (offline: −32 wrong, zero useful lost). Together
they reduce bad-when-shown from ~30% to ~18% on the certified suite at
materially higher useful volume.

### Why this should work

The 2026-08-30 offline replay of Q11's 1,110 cached raw candidates showed
66% already satisfy every required term; the scene-echo detector's 304
kills were 100% fact-carriers because its floor (3 words / 10 chars)
coincides with the 3-word display cap — short correct verbatim answers
are indistinguishable from echo. Grounding was the only knob that fixed
stress.contradiction.latest-fact in the earlier knob sweep and cost
nothing in replay.

### Overfitting disclosure

Both settings were selected by replaying the same development-partition
candidates this campaign evaluates. A development win is expected and can
only nominate frozen validation candidates. Promotion still requires the
standard protected path.

### Control

The Q11 treatment arm exactly (silence-gate-on, the standing validation
candidate): echo floor 3 words / 10 chars, grounding off.

### Treatments

- Arm `echo-24`: control with sceneEchoMinimumCharacters 10 → 24. One
  mechanism.
- Arm `echo-24-grounded`: echo-24 plus factualGrounding names-and-numbers.
  Isolates grounding's marginal effect against echo-24.

Nothing else changes: same generator (Q08's Qwen arm per the Q11 chain),
prompt, cleaner, caps, confidence threshold, seeds 17/41/73,
repetitions 1, 8×2 workers on AC under caffeinate.

### Primary metric

Bad-when-shown paired difference per treatment vs control,
counterfactual-cluster 95% intervals, plus useful-display count.

### Supporting metrics

Per-category useful recovery for the eight categories the replay named
(answer.preference, long-context.latest-request, confirm.schedule,
full-reply.deadline, typo.schedule, correct.time, mid-word.delivery,
commit.delivery); unsupported-fact wrong count; sensitive and ordinary
silence slices (must not regress); net keystrokes.

### Hard gates

Sensitive-scene suppression perfect in all arms; no gate weakened other
than the registered echo floor; no private text anywhere; production
defaults untouched by the campaign.

### Promotion rule

echo-24 nominates if useful rises ≥40% with bad-when-shown not increasing
and no slice newly regressing. echo-24-grounded nominates over echo-24 if
it removes ≥20 wrongs with ≤5 useful lost. Nominations are frozen
validation candidates only.

### Kill rule

Kill echo-24 if any silence slice or the echo-protected scenarios regress
at all (the detector must still catch real echoes: the sanitized
regression suite's echo cases must still fail their unsafe arms). Kill
grounding if it costs >5 useful displays.

### Known confounders

Development-partition reuse (disclosed above); the replay's candidate
cache makes generation identical across arms judged post-hoc, but this
campaign re-generates and could see cache-boundary differences; the
persona-sim ~60% floor is a different instrument and this result does not
substitute for it.

### Frozen runtime controls

8 workers × 2 slots, AC, caffeinate, repetitions 1 — declared pre-run,
quality-only, no latency claims.

### Frozen provenance

- Registered from the current main after the 2026-08-30 replay log entry.
- Control arm digests: inherited from the Q11 campaign record chain.

## Result

Status: SUPPORTED (development confirmation; validation candidates only)
Campaigns: 00480136 (first run, flagged dirty-source-tree — an uncommitted
registration file; preserved as non-promotable) and 177E07E5 (clean rerun,
decision-grade, reviewed). Both runs and the offline replay agree to ±1
display.

- echo-24: useful 473 → 765 (+61.7%, target ≥40%), bad displays unchanged
  (205), bad-when-shown 30.2% → 21.1%, no slice regression. NOMINATED.
- echo-24-grounded: 35 wrongs removed at zero useful lost (target ≥20 at
  ≤5), bad-when-shown 18.2%. NOMINATED over echo-24.
- Net keystrokes saved (arm aggregates): 11% → 20%.
- Sensitive and ordinary silence slices: unchanged in all arms.

### Honest nuances

- The generic paired-utility comparator scores Δ utility 0.00 for both
  treatments while Δ bad/show is −8.8 to −11.7 points: its keystroke
  credit does not count the recovered acceptable-alternative displays the
  arm aggregates count. The registered rules govern this experiment; the
  comparator's credit definition deserves its own look before any later
  experiment leans on it.
- Development-partition confirmation of replay-selected settings, per the
  registration's overfitting disclosure. Validation and live proof remain
  ahead; nothing ships from this run.

### Follow-up

Q13 (registered next) measures the visible-word cap 3 vs 8 on the
echo-24-grounded arm. Both nominated arms await protected validation.
