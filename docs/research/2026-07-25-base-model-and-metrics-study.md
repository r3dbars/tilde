# Can the base model be made smarter, and are we measuring what matters?

**A research report — SteadyType/Tilde project**
Date: 2026-07-24 → 2026-07-25 · Author: owner + Claude (research assistant)
Status: complete · Companion lab notebook: `docs/overnight-exploration.md`

---

## Abstract

We investigated two questions for an on-device inline-autocomplete keyboard:
(1) can the base language model's prediction quality be improved beyond raw
Gemma 2 2B by training or substitution, and (2) do our evaluation metrics
measure what makes the product feel good. Across 20+ controlled runs on a
frozen held-out test of the owner's real messages, **every base-improvement
mechanism failed or tied** — public-corpus drills, short- and long-form
teacher distillation (12k contexts, Sonnet 5 teacher), newer model
generations (Gemma 3: 1B/4B/12B; Gemma 4: E2B base, E2B/E4B instruct in two
prompt framings), and an experimental micro-MoE — while **the personal
fine-tune layer improved every base it was stacked on (+4pts exact-match,
consistently)**. Concurrently, metric analysis flipped one experimental
verdict, exposed a train/test contamination in a prior result, and
established a simplified scorecard with meaning-similarity as the primary
metric. A competitive teardown (Cotypist, open-source cotabby) plus analysis
of the owner's live acceptance data located the remaining felt-quality
headroom in the serving layer, not the model. **Conclusion: the champion is
Gemma 2 2B + personal layer, by exhaustion; the roadmap is personalization
depth and serving polish, with periodic re-evaluation as new base
checkpoints release.**

---

## 1. Research questions

- **RQ1.** Can imitation-style training (drills on public conversations,
  distillation from a frontier teacher) raise the base model's quality on
  the owner-reply prediction task?
- **RQ2.** Do newer/larger/architecturally-novel small models beat Gemma 2
  2B at this task?
- **RQ3.** Were prior instruct-model failures caused by the models or by our
  prompt framing ("holding it wrong")?
- **RQ4.** Are our metrics aligned with felt product quality — and what
  should the primary metric be?
- **RQ5.** Where does the felt quality of a shipping competitor (Cotypist)
  come from, given a measurably weaker engine class?

## 2. Methodology

**Task.** Given the prior message(s) and the first 2 words of the owner's
real reply, predict the continuation. Serving pipeline identical to
production (llama.cpp via the app's socket; same scaffold, budget 16,
temp 0.1, echo-guard 8 unless noted).

**Test set.** 1,500 held-out records sampled (seed 20260724) from the
owner's 32,337-message corpus **before** constructing any training pool;
never trained on by any candidate except where noted as contaminated.
Probes use the first 500; headline comparisons use all 1,500
(CI ≈ ±2.2pts at p≈0.25).

**Metrics (final scorecard, owner-directed).**
1. *Similar-phrase* ★ — suggestion within cosine 0.5 (MiniLM) of the true
   continuation's first ~12 words; primary. Goal: 8.5% → 15–20%.
2. *Word 1 / 1–2 / 1–3* — exact prefix depth.
3. *Keystrokes saved* — value delivered.
4. *Latency p50/p95* — feel.
Rejected as standing metrics: LLM-judge usability (v1 rewarded blandness;
v2 "mind-read" tier retained only as an occasional audit), magic-panel
composites (overcomplication).

**Training recipe (all fine-tunes).** mlx-lm LoRA, 8 layers, batch 4, on
mlx-community/gemma-2-2b unless noted; fuse → convert_hf_to_gguf → Q4_K_M;
identical quiz harness.

## 3. Experiments and results

### E1. Data-vs-accuracy curve (personal data volume)
| trained on | EM@1 | meaning |
|---|---|---|
| 250 | 20.4% | 0.180 |
| 1,000 | 23.6% | 0.208 |
| 4,000 | 26.4% | 0.205 |
| 16,000 | 24.6% | 0.202 |
| 30,637 | 26.0% | 0.207 |

Knee ≈ 4,000 examples; 250 already delivers most of the lift. Full
train-to-quiz cycle ≈ 3–5 min on the owner's hardware → nightly retraining
is computationally trivial. *Caveat: the original 32k "v1" model predates
the test split; its scores are contaminated (see §5) — curve points above
were trained post-split and are clean.*

### E2. Retrain with day-1 corrections (v2)
All data + 751 live corrections ×2 → 25.8% vs v1's (contaminated) 25.4% at
500 cases; at 1,500 cases v2 = 24.9%. One day of corrections ≈ 2% of pool —
no measurable movement. Lever identified: recency/correction-weighted ~4k
sets, not volume.

### E3. Task drills (public corpora, RQ1)
13.8k reply-pairs across 7 registers → task-base 19.0→21.5% (500→1500
cases; the apparent harm at 500 was sampling noise). Stacked with personal
4k: 26.6/25.3% ≈ raw+personal. **Null.**

### E4. Teacher distillation (RQ1)
- v1 (short 2–10-word completions, 590 pairs): 13.0% — *negative*; format
  taught brevity, not judgment. Halted at ⅓ credits.
- v2 (10–30-word full-thought completions, 12,000 contexts, Sonnet 5
  teacher, meaning-refereed vs real human replies, 3,970 kept pairs,
  blended 50/50 with real replies): base 20.8→21.2% EM (tie),
  **meaning 0.202 vs 0.190 (real, +6% rel)**, word-depth 1–2: 5.2% vs 4.2%
  (+24% rel — gains live at continuation depth, as the training format
  predicts). Stacked: 26.2/25.2% ≈ ties.
**Conclusion (RQ1): the 2B base is imitation-saturated.** Pretraining
already covers what imitation teaches; gains appear only on the metric the
training explicitly optimized (meaning/depth) and wash out under the
personal layer.

### E5. Newer and experimental models (RQ2)
| candidate | similar | word-1 | note |
|---|---|---|---|
| **gemma-2-2b (champion)** | **5.3%** | **21.1%** | reference |
| gemma-3-1b-pt | 4.5% | 19.9% | loses |
| gemma-3-4b-pt | 5.4% | 19.7% | loses |
| gemma-3-12b (earlier) | — | 20.2% | loses |
| qwen-2.5-7b base (earlier) | — | 21.3% | not worth 2× latency |
| gemma-4-E2B **base** (converted ourselves) | 3.7% | 20.0% | loses the fair fight |
| LFM2.5-8B-A1B micro-MoE (instruct) | 2.7% | 5.0% | collapse; arch loads fine |
Qwen 3.6 (27B/35B-A3B only) and diffusion LMs: out of scope by size/serving.
**Two-generation pattern: modern pretraining mixes trade away casual-text
intuition.** Chapter closed by exhaustion; re-bakeoff is a periodic chore on
new base releases.

### E6. "Holding it wrong" — instruct framing (RQ3, owner's challenge)
Built STEADYTYPE_PROMPT_MODE=instruct (chat template, task-as-question,
screen context included).
| model | framing | EM@1 | similar | p50 |
|---|---|---|---|---|
| E4B-it | raw | 18.5% | — | 137ms |
| E4B-it | instruct | 13.2% | **6.5%** | 150ms |
| E2B-it | instruct | 11.8% | 3.4% | 68ms |
**Owner was half right, and the half matters:** proper framing fixes
*comprehension* (best base-tier similar score recorded) but the model
*paraphrases rather than channels* (EM falls); the effect requires E4B
scale, whose latency disqualifies it. Corrected claim replaces "instruct
poison": *instructs understand the task when asked properly, but answer in
their own words.* Method retained in the engine for future models.

### E7. Metric integrity findings (RQ4)
- 500-case CIs (±3.9pts) created two false narratives ("drills hurt",
  "v2 beat v1") — both corrected at 1,500.
- **Train/test contamination caught:** v1 trained on the full corpus before
  the split; its 27.1% disqualified.
- LLM-judge v1 (accept-if-plausible) crowned the *raw base* — inspection
  showed it rewarded blandness ("it leave" → "to go to the store"
  accepted). Judge v2 (mind-read tier) built, then demoted per owner: keep
  the scorecard simple.
- **Live-accept analysis (n=17 multi-word accepts): 47% specific /
  53% bland.** The owner's own acceptance bar includes generic-but-useful
  completions — blandness has real value; mind-reading alone is too strict
  a product bar.

### E8. Competitive teardown (RQ5)
Cotypist: gemma-4 E2B + llama.cpp + polished serving + vocabulary-nudge
personalization; engine class measurably weaker than our champion → felt
quality is serving-layer. Open-source cotabby (AGPL; patterns only — never
code; MIT cousin: KeyType) documents that layer: mid-word no-leading-space
constraint, sentence-boundary + argmax-EOG early stop, prewarm-on-focus +
KV-prefix reuse, latency-adaptive debounce, priority-budgeted prompt
sections. Their production negative result — an offline-eval-winning
confidence gate withheld 56% of good completions live — independently
validates our "gates tune on live accepts, not quiz wins" rule.

## 4. Conclusions

1. **The champion is settled:** Gemma 2 2B + personal LoRA — by exhaustion
   of size, generation, flavor, framing, and architecture alternatives.
2. **The only training that reliably works is training on the user**
   (+4pts on every base; knee ≈ 4k examples; minutes per retrain).
3. **Imitation is saturated; judgment is untried** — DPO on preference
   pairs is the remaining base-side lever (process fix required: save
   rejected candidates during generation).
4. **Felt quality's remaining headroom is serving-layer** (five concrete
   techniques identified), consistent with both our own gate/muting gains
   (12→27% live acceptance) and the competitor's success with a weaker
   engine.
5. **Metric discipline paid for itself repeatedly** — bigger samples,
   contamination checks, and metric-vs-product audits each changed a
   conclusion within one day.

## 5. Threats to validity

- Test set is iMessage-casual only; work-register performance is known to
  differ (11.7% vs 17.1% live) and is untested by this quiz.
- Similar-phrase threshold (cosine 0.5) is calibrated only roughly against
  human judgment; the judge audit was demoted before full calibration.
- Live-accept analysis n=17; directional only.
- Single hardware target (owner's M-series); latency numbers don't
  generalize.
- The curve's 32k point shares provenance with the contaminated v1; the
  knee estimate deserves a clean rerun before being treated as exact.

## 6. Future work (priority order)

1. Serving-layer implementation: mid-word constraint (fixes a live bug),
   sentence-boundary/EOG early stop, prewarm + KV-prefix verification,
   adaptive debounce, budgeted prompt sections.
2. Personalization depth: recency/correction-weighted retrains; work-voice
   register conditioning; nightly auto-retrain pipeline.
3. DPO on preference pairs (generation runs must persist rejects).
4. Periodic base re-bakeoff on genuinely new base releases (incl. Gemma 4
   pt GGUF availability, Qwen small bases).
5. Scorecard upkeep: p95 capture, register-split view, live-accept column.
EOF
git add -A && git commit -q -m "Research report: base-model and metrics study (2026-07-24/25)

Formal write-up of the two-day campaign: five experiment families, metric
integrity findings, competitive teardown, conclusions, threats to validity,
prioritized future work.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && git log --oneline -1
---

## Addendum E9 — Teacher-ceiling measurement (the Fable test)

Post-publication, the owner's mega-distillation proposal (100-200k examples,
frontier teacher) was stress-tested by measuring the proposed teacher
directly: Fable 5 answered the identical 500-question quiz (batched CLI,
single-shot, same scoring). Results: similar 12.4%, word-1 24.8%, meaning
0.275 — versus the personal 2B's 8.3% / **28.7%** / 0.256. Conclusions:
(1) the personalized 2B outperforms the frontier teacher at word-1
prediction — specificity beats scale on this task; (2) the distillation
ceiling for similar-phrase is 12.4%, bounding any student far below the
40%+ acceptance target, which must therefore come from personalization +
selective serving; (3) a real but scoped ~4pt teachable gap exists in
continuation depth (bland half) — filed as future polish. This experiment
retires RQ1's scale-up variant conclusively for ~25 CLI calls of cost.
