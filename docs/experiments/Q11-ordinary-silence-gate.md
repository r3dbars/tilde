# Q11 — Extended ordinary-silence gate

Status: REGISTERED
Experiment class: display-policy
Owner: Tilde research program
Pre-registered: 2026-08-29T21:30:00Z

## Pre-registration

### Hypothesis

Enabling the three extended ordinary-silence detectors
(`extendedOrdinarySilenceGate`: complete-sentence, multiple-questions,
ambiguous-reference) reduces bad-when-shown on the certified suite by at
least 8 percentage points absolute while retaining at least 99.5% of
useful displays, with no wanted-reply category losing more than 1% of its
useful displays.

### Why this should work

Two independent evidence sources agree. The Q08 label re-read showed the
three target subcategories leak at or near 100% while contributing zero
useful displays, and relabeling that frozen evidence predicts
bad-when-shown falling from 43.29% to ~30%. The 2026-08-29 cross-campaign
mining sweep (~468k observations plus ~1.03M archived report cases) found
`multiple-questions` and `complete-sentence` at 100% bad in all 17
campaign-arm cells and `ambiguous-reference` at 78–100% — chronic display
failures no sampling knob has ever moved. The detectors themselves passed
an offline pre-check (90/90 target scenarios gated, 0/600 wanted
scenarios newly suppressed; PR #438).

### Overfitting disclosure

The detectors were developed while looking at these same development
categories' failures, so a development-partition win is expected and is
NOT promotion-grade on its own. This experiment is the registered
development confirmation. Any promotion requires the standard protected
path afterward: frozen candidate, protected validation, sealed holdout,
live dogfood, interaction proof, owner approval.

### Control

The production judgment configuration with `extendedOrdinarySilenceGate`
absent/false — the exact arm Q08 ran.

### Treatment

The identical arm with `extendedOrdinarySilenceGate` true. Nothing else
changes: same generator, prompt, cleaner, caps, confidence threshold,
grounding, seeds.

### Data and split

Certified V2 development roots, full 40-category suite. The gate is a
deterministic post-generation display decision, so the comparison is
perfectly paired: identical generations judged under both arms. Frozen
assets: the same pinned model, helper, and suite digests as Q08's
campaign record; seeds frozen at registration.

### Primary metric

Bad-when-shown (wrong + unwanted over shown), paired difference with
counterfactual-cluster 95% interval, exactly as Q06/Q08 computed it.

### Supporting metrics

- per-subcategory suppression counts for the three targets;
- useful-display retention overall and per category;
- net keystrokes saved;
- decision-reason distribution (the three new reasons must be
  distinguishable from existing gate reasons);
- sensitive-silence slice (must stay 0.0% bad and fully suppressed).

### Hard gates

- No weakening of any existing suppression, cleaner, or grounding gate.
- Sensitive-scene suppression remains perfect in both arms.
- No private text, prompts, or candidates in any artifact.
- Production defaults remain untouched by the campaign.

### Promotion rule

If bad-when-shown falls by ≥8pp absolute (interval excluding 0) with
useful retention ≥99.5% overall and no wanted-reply category losing >1%,
the flag becomes a frozen validation candidate. Nothing ships from this
run.

### Kill rule

Kill the treatment if any wanted-reply category loses more than 1% of its
useful displays, if overall useful retention falls below 99.5%, or if the
three new reasons cannot be cleanly attributed. A smaller-than-8pp
improvement with intact retention is reviewed as inconclusive, not
promoted.

### Known confounders

- Development-partition reuse (see overfitting disclosure).
- The synthetic corpus over-represents the target subcategories relative
  to live typing; the absolute pp reduction will not transfer 1:1.
- The multi-question detector's stand-down clause (writer names which
  question they answer) is load-bearing for the stress positives; its
  failure mode is measured by the per-category retention gate.

### Frozen runtime controls

Declared before the decisive run, per the runtime-control freeze rule:
8 workers × 2 slots on AC power under caffeinate. Q11 measures quality
only; at temperature 0 the paired outputs are concurrency-invariant, so
parallel workers change wall-clock, never results. No latency claim of
any kind may be made from this campaign.

### Frozen provenance

- Registered from commit `25ad95b2` (post PR #442 merge).
- Detector implementation: PR #438, `SceneSuggestionPolicy.Options`.
- Model, helper, suite digests: frozen to the Q08 campaign values at run
  time; recorded in the campaign before the first evaluation.
- Runner invocation digest: captured by the v6 report at run time.

## Result

Status: SUPPORTED (development confirmation; validation-candidate only)
Campaign: D4DFEA6A-DAE5-4CE5-932E-AABE678DDBFE, completed 2026-08-29,
3,600/3,600 evaluations, 8×2 workers on AC under caffeinate, 0.11 hours.

- Bad-when-shown: 43.35% (362/835) control → 30.13% (204/677) treatment —
  a 13.2pp absolute reduction against the registered 8pp target. Every
  seed's paired reduction exceeded 12pp (worst seed 17: −12.36pp), so the
  effect interval excludes zero by a wide margin.
- Useful displays: 473 = 473, 100% retention. The gate is suppression-only,
  so no wanted-reply category lost a useful display (kill rule not
  triggered). Sensitive-scene suppression unchanged.
- The frozen-label prediction (~30.03%) matched the measured 30.13%.
- Declared pre-run deviation-free amendments: repetitions = 1 (Q08 proved
  repetition labels identical; declared before results existed), and the
  control model is the Q08 Qwen arm exactly as the frozen provenance
  requires — an earlier instruction to substitute production Gemma was
  caught and refused before the run.

### Honest nuance

Net-keystrokes utility was flat (Δ 8.08 chars/1000, 95% interval
[0.00, 25.71], P(>0)=63.1%): the suppressed bad displays were ones the
scripted evaluation mostly typed through, and keystroke accounting cannot
see interruption cost. The generic utility-based nomination gate therefore
does not nominate this treatment on its own; the registered bad-when-shown
rule does. Whether removing 158 wrong interruptions per ~3,600 moments is
worth shipping is exactly what the live three-judges evaluation (metric,
gates, owner experience) must decide after Stage 0.

### Follow-up

Freeze the flag as a validation candidate. Do not enable it anywhere
user-visible. Next in queue per the mining sweep: scene-echo precision +
grounding. The live H01/RNKS instrument, once F03 closes, is where the
interruption-cost question this run cannot answer gets its ruler.
