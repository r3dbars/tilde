# Small Model Blind Quality Audit — 2026-06-14

Wave-2 rerun of the small-model bet, now **measured**. This supersedes the
runnable-but-unmeasured [2026-06-12 skeleton](small-model-blind-quality-audit-2026-06-12.md):
the old run was blocked by a cold-load bug (36 model reloads per audit), since
fixed by the persistent `--batch` runtime.

**Result.** Switching base/small models from a chat wrapper to `raw_completion`
raises overall blind-quality by **+7 to +16 points** on every model tested — the
old **7/100** was largely a prompt-template artifact, not a capability ceiling.
`qwen3-1.7b` at `raw_completion` reaches **76/100 overall** (vs the `qwen35-4b`
reference's 73) at **~2× lower first-token latency** (77 ms vs 150 ms p50) and
**< 1 GiB** of runtime memory. **Decision: the default does not change.** Gemma 4
E4B — the rule's anchor — cannot be loaded by `mlx_lm`, and the proxy evidence
supports *keeping the small-model bet in the draft/speculative lane*, not
promoting it: the only candidate that mechanically clears both proxy bars
(`qwen3-0.6b`) does so by staying silent (relevance 0), and the relevance metric
is near-floor for every model — including the 4B reference — on this open-ended set.

## Why rerun

A prior blind audit scored a 1.7B model **7/100** on relevance. That number was
never enough to retire the small-model bet, because it likely fed an
instruct/chat-templated model a completion-shaped task. The competitor Cotypist
ships a ~1.5B model as a viable default, so the bet deserved a fair test with a
per-model prompt template. The template layer now exists
(`CompletionPromptTemplate` in
[CompletionPromptBuilder.swift](../../Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift)),
routing base/small models to a `raw_completion` shape (no chat wrapper) and
larger instruct models to `chat_instruct`.

## The Gemma-4 baseline constraint (read this first)

The production default is **Gemma 4 E4B IT OptiQ**
([ModelPolicy.swift](../../Sources/AutocompleteLabCore/Configuration/ModelPolicy.swift) `CompletionModelPolicy.mvp`).
The pre-registered decision rule is anchored to Gemma 4 E4B. **But the installed
`mlx_lm` cannot load it:** both `mlx-community/gemma-4-e4b-4bit` and the OptiQ
variant report `"model_type": "gemma4"`, and the `mlx_lm` registry only knows
`gemma / gemma2 / gemma3 / gemma3n`. OptiQ additionally uses a custom per-layer
mixed-bit quantization that needs the Swift `gemma4-optiq-scaled-linear.patch`.
So **this Python harness cannot produce a Gemma 4 E4B number.**

Consequence: the rule's promotion *antecedent* (`blind-quality ≥ Gemma4E4B − 5`)
is **unverifiable in this harness**, so by the rule's own terms a candidate here
can be **at most draft/speculative-lane eligible — the default does not change.**
To still locate candidates against a large-model bar, baselines are:

- **In-harness reference: `qwen3.5-4b`** (same runtime, apples-to-apples latency).
  All decision-rule math below is computed against this row.
- **Gemma-family cross-check: `gemma-3n-E4B-it`** (the nearest *loadable* Gemma
  sibling to the gemma4 default; reported for context, not as the rule anchor).

A true Gemma-4 comparison requires the Swift runtime (OptiQ + the MLX patch) and
is filed as follow-up below.

> Note: the 2026-06-12 doc called `qwen35-4b` "the default." That was wrong — the
> default is and remains `gemma4E4BItOptiQ`. `qwen3.5-4b` is only the in-harness
> *reference* the small models are measured against.

## Method

- **Prompt set:** [`small-model-blind-prompts-2026-06-12.jsonl`](small-model-blind-prompts-2026-06-12.jsonl),
  36 rows, all `source_kind: synthetic-public` — **external** non-dogfood text
  (library newsletters, museum placards, weather bulletins, trail maps, …), 30
  display rows + 6 expected-suppression rows. No private or dogfood text.
- **Quality (blind):** [`local_quality_audit.py --batch`](../../script/local_quality_audit.py).
  *Overall* = `(1 − failed-labels / (rows × 8 labels)) × 100` over the labels
  relevance, literal-continuation, assistant-voice, wrong-topic, too-long,
  structural-breakage, unsafe/sensitive, repetition. *Relevance* = % of display
  rows whose output shares enough meaning terms with the row's `expected_terms`.
  Greedy decoding (temp 0). Chat models' leaked turn markers (`<end_of_turn>` …)
  are truncated so a model is scored on its continuation, not control tokens.
- **First-token latency:** [`first_token_latency.py`](../../script/first_token_latency.py)
  via `mlx_lm.stream_generate` — time from call to the first decoded token
  (tokenize + prefill + first decode), which is when an inline suggestion can
  begin to paint. 1 warmup + 3 timed reps per prompt, per-prompt median, then
  p50/p95/p99 across the 36 prompts. Cold prefill, no shared cache across rows
  (the honest, model-comparable number).
- **Memory:** on-disk 4-bit asset size (install footprint) + peak unified memory
  during the latency pass (`mlx.core.get_peak_memory`).
- **Template fidelity:** the harness `raw_completion` prompt mirrors the Swift
  product template exactly (system + `"Complete only the text requested below.
  Return no label and no copied context."` + user), so the eval predicts
  production rather than a bare system+user join.
- **Environment:** Apple M5 Max, 128 GB, arm64; `mlx_lm` 0.31.2 / `mlx` 0.31.1;
  Python 3.12. 4-bit MLX weights for every model.

## Pre-registered decision rule

> Promote a small model to **default** only if
> `blind-quality ≥ (Gemma 4 E4B − 5)` **and** `first-token p50 ≤ 50% of Gemma's`.
> Otherwise keep it as a **draft/speculative lane**, not default.
> Do **not** change the default without the table.

Applied here against the `qwen3.5-4b` in-harness proxy (Gemma 4 E4B being
unloadable), so a "meets bars" verdict is **draft-lane eligibility**, not an
automatic default switch.

## Results

Reference `qwen35-4b`/`chat_instruct`: overall **73**, first-token p50 **150 ms**
→ proxy quality bar **≥ 68**, proxy latency bar **≤ 75 ms**.

| Model | Template | Quality (overall / relevance) | First-token p50 | p95 | Disk | Peak RAM | Mechanical decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `qwen35-4b` | `chat_instruct` | 73 / 10 | 150 ms | 151 ms | 2.9 GiB | 2.4 GiB | reference (proxy for Gemma 4 E4B) |
| `gemma-3n-e4b-it` | `chat_instruct` | 80 / 17 | 182 ms | 184 ms | 3.6 GiB | 3.7 GiB | baseline (Gemma-family) |
| `qwen3-1.7b` | `raw_completion` | **76** / 13 | **77 ms** | 79 ms | 938 MiB | 994 MiB | quality ✓, latency miss (77 > 75) → no |
| `qwen3-1.7b` | `chat_instruct` | 64 / 10 | 78 ms | 79 ms | 938 MiB | 999 MiB | misses both → no |
| `qwen3-0.6b` | `raw_completion` | 81 / 0 | 72 ms | 76 ms | 335 MiB | 378 MiB | meets proxy bars → draft lane* |
| `qwen3-0.6b` | `chat_instruct` | 65 / 10 | 71 ms | 76 ms | 335 MiB | 381 MiB | latency win, quality miss → draft |
| `gemma-3-1b-it` | `raw_completion` | 69 / 3 | 152 ms | 157 ms | 736 MiB | 730 MiB | quality ✓, latency miss → no |
| `gemma-3-1b-it` | `chat_instruct` | 62 / 7 | 147 ms | 150 ms | 736 MiB | 724 MiB | misses both → no |

Latencies are from a quiet-machine run with interpolated percentiles; absolute
first-token times vary ~5–10% run-to-run (thermal/scheduling), but the *ratio* to
the reference is stable (`qwen3-1.7b`/raw = ~51% across runs). The last column is
the script's mechanical rule output. **Two metric quirks make
those numbers misleading on their own:**

- **Relevance is near-floor for everyone — including the 4B reference and the
  Gemma baseline.** The prompts are open-ended ("The museum placard describes the
  old ferry as …"); `relevance` only passes when the output overlaps the
  fixture's single `expected_terms` set. Sampled `qwen3-1.7b`/raw outputs are
  fluent, usable continuations that simply pick a *different* valid completion
  than the fixture. So on this set `relevance` measures "guessed the fixture's
  exact continuation," not usefulness, and cannot discriminate models.
- **`overall` rewards abstention.** A `<NO_SUGGESTION>` on a display row costs
  only 1 of 8 labels, so a silent model scores high `overall` while being
  useless. `qwen3-0.6b`/raw's 81 is exactly that — it returns `<NO_SUGGESTION>`
  on most rows (hence relevance 0). Its "meets proxy bars" verdict is an
  abstention artifact, **not** a usable default.

## Did the template fix the 7/100?

Yes — clearly, on the failure modes that produced the original 7/100. Holding the
weights fixed and flipping only the template:

| Model | `raw_completion` overall | `chat_instruct` overall | Δ |
| --- | --- | --- | --- |
| `qwen3-1.7b` | 76 | 64 | **+12** |
| `qwen3-0.6b` | 81 | 65 | +16 |
| `gemma-3-1b-it` | 69 | 62 | +7 |

Under `chat_instruct` the instruct models repeat the visible lead-in back before
continuing (an echo/restate of the prompt) and slip into assistant voice — which
the audit flags as repetition / assistant-voice / wrong-topic failures.
`raw_completion` drops the chat wrapper, so the model continues the text directly
and those failure modes disappear. That is the mechanism behind the old 7/100: an
instruct model fed a chat-templated completion task. With the right template,
`qwen3-1.7b` produces clean continuations and matches the `qwen35-4b` reference on
overall quality. (Outputs are described, not quoted — the harness keeps raw model
output in memory only.)

## Decision

**No default change. The small-model bet stays in the draft/speculative lane.**
Two independent reasons:

1. **The rule's anchor is unmeasurable here.** Promotion requires
   `overall ≥ Gemma4E4B − 5`, and Gemma 4 E4B cannot be loaded by `mlx_lm`. The
   `qwen35-4b` proxy is a stand-in, not the real bar. (For context, the nearest
   loadable Gemma sibling, `gemma-3n-e4b-it`, scores 80 overall — so the true
   Gemma-4 bar is plausibly ~75+, right where `qwen3-1.7b`/raw lands. Suggestive,
   not decisive.)
2. **Even against the proxy, the evidence doesn't support promotion.** The one
   model that clears both proxy bars (`qwen3-0.6b`/raw) does so by abstaining
   (relevance 0); the genuinely-best small model, `qwen3-1.7b`/raw, *just misses*
   the proxy latency bar (77 vs 75 ms — it lands at ~51% of the reference p50,
   just over the 50% cutoff, consistently across runs), and the relevance metric
   is too weak to confirm its usefulness against the quality bar.

**What this run does establish:** the template fix is real and large, so the bet
is worth keeping. `qwen3-1.7b`/`raw_completion` is the right draft candidate — it
answers fluently, matches the 4B reference on overall, runs ~2× faster (77 ms vs
150 ms first-token p50), and needs **< 1 GiB** of runtime memory versus the
16 GiB-class default. The existing draft lane
(`CompletionModelPolicy.smallDraftExperiment`, already `qwen3Medium`/1.7B) is the
correct home; this run does **not** justify touching `CompletionModelPolicy.mvp`.

To actually decide promotion, two things are still needed (see follow-up): a true
Gemma 4 E4B measurement via the Swift runtime, and a relevance signal that
survives open-ended prompts (human-judged, or a less open-ended set scored with
an abstention-aware metric).

## Audit proof block

Machine-checked by [`check_small_model_blind_audit_report.sh`](../../script/check_small_model_blind_audit_report.sh):

- Prompt set: `small-model-blind-prompts-2026-06-12.jsonl`
- Prompt rows: 36
- Display rows: 30
- Expected suppression rows: 6
- Source mix: synthetic-public
- No private text: yes
- Default model: gemma4E4BItOptiQ (unchanged)
- In-harness reference: qwen35-4b
- Default switch: no
- Result status: measured-no-default-change
- Promotion gate: default only if blind-audit overall >= (Gemma 4 E4B - 5) and first-token p50 <= 50% of Gemma's.
- Draft/speculative gate: if quality misses but latency wins big, keep it out of default and test only as draft/speculative.

## Reproduce

```bash
# Full table (quality + first-token latency for every model/template):
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
  ~/mlx-env/bin/python script/small_model_blind_audit_report.py --run \
    --json-out /tmp/blind_audit_results.json

# One quality cell (e.g. the chat-vs-raw A/B on the 1.7B):
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
  ~/mlx-env/bin/python script/local_quality_audit.py \
    --input docs/evals/small-model-blind-prompts-2026-06-12.jsonl \
    --generate --batch --model qwen3-1.7b --template raw_completion

# One first-token latency cell:
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
  ~/mlx-env/bin/python script/first_token_latency.py \
    --model qwen3-1.7b --template raw_completion
```

Models download via `script/download_mlx_model.py --model {qwen3-1.7b,qwen3-0.6b,gemma-3-1b-it,gemma-3n-e4b-it,qwen35-4b}`.

## Follow-up to enable a real promotion decision

Build a Swift-runtime blind harness that runs these 36 prompts through the real
`MLXModelRuntime` (Gemma 4 E4B OptiQ + the MLX patch) and emits the same
quality + first-token numbers. Only then is the rule's Gemma-4 antecedent
measurable and a default change defensible. (Cross-runtime latency caveat: Swift
mlx-swift vs Python mlx_lm are not perfectly comparable, so prefer measuring the
candidates through the same Swift path for the final call.)
