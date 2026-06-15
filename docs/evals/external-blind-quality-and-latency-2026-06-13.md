# External-Text Blind Quality + KV-Cache Latency — 2026-06-13

First measured run of the batch quality harness against **genuinely external**
text (public-domain prose, a real OSS changelog, others' READMEs — none authored
here). This closes the gap left by `small-model-blind-quality-audit-2026-06-12.md`,
which timed out before producing a single number. A fresh KV-cache-on latency
proof was attempted on the same pass but **blocked at model load** (MLX patch +
default-model drift — see Latency); latency stays a measured follow-up, not a
guess.

Reproduce everything below from the commands in the "Reproduce" section. Raw
model output is kept in memory only and is **not** persisted, per the audit
contract; this report describes failure *modes* and counts, not raw text.

## Headline

- Default model `qwen35-4b` (chat_instruct, local MLX 4-bit asset), temperature 0.
- External blind fixture: `docs/evals/external-blind-prompts-2026-06-13.jsonl`,
  40 rows (34 display + 6 expected-suppression).
- **Quality: overall 78/100, relevance 29/100.** Display-eligible 7/34.
  Expected suppressions passed 6/6. Model under test: `qwen35-4b` (the asset the
  batch harness, the strict latency selector, and the scorecard all still pin).
- **Latency (KV cache on): attempted, not measured this run** — the fresh proof
  failed at model load. See the Latency section; this is the headline follow-up.
- **Config drift found:** the current-branch default model
  (`CompletionModelPolicy.mvp.model`) is **Gemma 4 E4B IT OptiQ**, not Qwen — see
  "Model-default drift" below. This audit measured Qwen3.5-4B, the infra default.

The relevance number is the story. On the self-authored synthetic fixtures the
same harness reports 100/100 relevance (`daily-driver-phrase-quality-2026-06-12.md`).
On external text whose ground truth is the *original author's* next words, the
default model reproduces enough of those words only ~29% of the time. That is the
honest blind-quality signal the synthetic fixtures cannot give.

## Harness fix (why this could finally run)

`small-model-blind-quality-audit-2026-06-12.md` recorded the batch audit as
"runnable-not-measured": it "was stopped after more than two minutes without
completing the first model row." Two real causes, both fixed here:

1. **Interpreter.** `mlx_lm` is only installed in `/opt/homebrew/bin/python3`
   (3.14). The default `python3` on PATH (3.9) has no `mlx_lm`, and
   `script/local_completion_batch.py` runs under its own shebang `python3`, so
   the batch cold-failed its model import. Driving the audit with the Homebrew
   interpreter on PATH fixes this (see Reproduce).

2. **Worker-thread GPU stream (the real bug).** The installed MLX (0.31.2)
   binds the Metal GPU stream to the thread that first touches the device during
   `mlx_lm.load`, and raises `There is no Stream(gpu, 0) in current thread.` for
   generation on *any* other thread — even if you load on that thread or wrap the
   call in `mx.stream(mx.gpu)`. The batch runtime ran every generation on a
   `ThreadPoolExecutor` worker, so it could not produce a single row. Fixed in
   `script/local_completion_batch.py` by running generation on the main thread
   with a `SIGALRM` per-row wall-clock timeout, preserving the exit-75-on-timeout
   semantics. Verified: main-thread generation works; all worker-thread variants
   fail. `./script/local_completion_batch_self_test.sh` passes (it was also made
   hermetic — it previously assumed the model asset was *not* installed at the
   default location, which is false on any real dev machine).

Model load is ~1.7 s and per-row generation ~0.3 s, so the full 40-row audit
completes in well under a minute — the earlier two-minute timeout was the bug,
not the model.

## External blind fixture

`docs/evals/external-blind-prompts-2026-06-13.jsonl` — 40 rows, built by
fetching the sources verbatim and extracting `(context → real continuation)`
pairs with a deterministic caret rule (split after the function word nearest the
sentence middle, so the model must produce a content continuation). `expected_terms`
are the **actual** next content words from the source, lower-cased; this grades
"did the model continue toward the original author's words," not toward anything
written here.

| source_kind | rows | sources |
| --- | ---: | --- |
| public-domain-prose | 12 | Gutenberg #84 Frankenstein, #1661 Sherlock Holmes, #1342 Pride and Prejudice |
| oss-changelog | 12 | facebook/react `v18.2.0` CHANGELOG.md (18.1.0 entries) |
| oss-readme | 10 | pallets/flask, olivierlacan/keep-a-changelog, psf/requests README.md |
| sensitive-field (suppression) | 2 | synthetic `Password:` / `API key:` labels |
| sentence-boundary (suppression) | 4 | one verbatim full sentence per non-sensitive source |

Inclusion rule (applied, stated so it is not cherry-picking): keep rows whose
real continuation has ≥2 common content words; drop rows that hinge only on a
proper noun or a garbled token. Text is verbatim apart from unwrapping markdown
link syntax and normalizing unicode quotes/dashes.

## Quality results

Source: current local model (`qwen35-4b`). Rows scored 40, display-eligible 7,
suppressed/no-suggestion 33, expected suppressions passed 6/6.

**Overall 78/100 · Relevance 29/100.**

| label | failure rate |
| --- | ---: |
| relevance | 60% (24/40) |
| wrong topic | 60% (24/40) |
| too long | 30% (12/40) |
| repetition | 22% (9/40) |
| structural breakage | 5% (2/40) |
| literal continuation | 0% |
| assistant voice | 0% |
| unsafe or sensitive content | 0% |

Display-eligible by source: prose 3/12, changelog 1/12, readme 3/10.

Failure modes (from the in-memory raw, described not quoted):

- **Plausible-but-different (relevance/wrong-topic, 60%).** The dominant mode.
  The model writes a clean, on-register continuation that simply isn't the
  original author's wording, so it misses the ground-truth content words. This
  is expected for genuinely open external prose and is the honest cost of a blind
  set — it is *not* a safety or fluency failure.
- **Overshoot (too long, 30%).** The model runs past the 7-word display budget,
  e.g. completing a whole README sentence instead of a short phrase.
- **Prefix echo (repetition, 22%).** On short technical fragments the model
  sometimes parrots the typed prefix back instead of continuing — a real,
  reportable weakness of the default model+template on terse changelog lines.
- **Clean axes.** 0% assistant-voice and 0% unsafe/sensitive: the continuation
  voice and safety filters hold. 6/6 expected suppressions: the "quiet at
  end-of-sentence / sensitive field" gate is correct on external text too.

Interpretation: the 95–100 "suggestion quality" claims on the scorecard are an
artifact of self-authored fixtures whose `expected_terms` were chosen to match
what the model would say. Against external ground truth the default model is
safe and in-voice but only ~29% on-target, overshoots length ~30% of the time,
and echoes the prefix ~22% of the time on short technical text.

## Latency (prompt KV cache ON) — attempted, blocked this run

Facts that did hold up:

- Prompt KV cache default is **on** (`AUTOCOMPLETE_LAB_MLX_KV_CACHE` unset ⇒
  `MLXPromptKVCacheConfiguration.isEnabled = true`,
  `Sources/AutocompleteLabApp/Runtime/MLXPromptKVCache.swift`).
- Orchestrator display budgets
  (`Sources/AutocompleteLabApp/App/SuggestionOrchestrator.swift`): first-visible
  model contribution **450 ms**, refinement/continuation **750 ms**.
- Beta gate (`script/latency_benchmark_report.py --beta-gate`): first-visible
  p95 ≤ 750 ms, first-token p95 ≤ 650 ms, total-generation p95 ≤ 900 ms.

**The fresh `textedit-model-latency` proof produced no samples.** It built the
current branch cleanly, then failed at model load:

```
MLX failed: Key model.per_layer_model_projection.scales not found in
Gemma4TextModel.Gemma4TextModelInner.ScaledLinear
```

Two coupled causes, both real:

1. **MLX patch dropped by fresh resolve.** A clean `swift package resolve` resets
   the `mlx-swift-lm` checkout to unpatched. The runtime needs
   `./script/patch_mlx_swift_lm.sh`
   (`patches/mlx-swift-lm/gemma4-optiq-scaled-linear.patch`) re-applied before the
   build. `fresh_latency_proof.sh` / `real_app_smoke.sh` do **not** auto-apply it,
   so a from-clean latency proof cannot load the model.
2. **Default-model drift (see below).** The fresh build bootstraps the Gemma
   OptiQ asset — the exact model that patch supports — so the missing patch lands
   directly on the default path.

KV-cache-ON latency percentiles are therefore **not measured here.** I did not
substitute older diagnostics samples: today's pre-existing TextEdit samples have
an ambiguous (redacted) KV-cache flag and come from an older build, so they
cannot honestly stand in for a KV-cache-ON proof. This stays unmeasured rather
than guessed.

To unblock (one quiet-machine pass):
`./script/patch_mlx_swift_lm.sh` after resolve → decide the intended default
(Gemma OptiQ vs Qwen) and align `--expected-asset` → rerun
`./script/fresh_latency_proof.sh --target textedit-model-latency` and
`./script/select_latency_window.py`.

### Budgets the model cannot hit

Not assessable without measured numbers. The one structural risk to flag from the
budgets alone: the first-visible **model** ceiling is 450 ms while the gate
allows 750 ms, so a model whose first paint lands in 450–750 ms passes the gate
but is still suppressed as a *first* suggestion (it may only refine an
already-visible one). Whether the default model actually lands under 450 ms is
exactly what the blocked proof needs to answer.

## Model-default drift (finding)

While chasing the latency load failure I found that the current-branch default
model and the proof/scorecard infra disagree:

- Source default: `CompletionModelPolicy.mvp.model == .gemma4E4BItOptiQ`
  ("Gemma 4 E4B IT OptiQ"), `Sources/AutocompleteLabCore/Configuration/ModelPolicy.swift`.
  The fresh build bootstrapped this Gemma OptiQ asset.
- Infra default: `script/local_completion_batch.py` (`--model` default),
  `script/select_latency_window.py`, `script/latency_benchmark_report.py`, and the
  scorecard all pin `Qwen3.5-4B-4bit`. An older running build today also
  bootstrapped `Qwen3.5-4B`.

So this audit measured **Qwen3.5-4B** (what the harness and infra call default),
not the Gemma OptiQ the source now prefers. Re-running the blind quality audit
against the Gemma OptiQ default — and deciding which model is actually intended
for beta — is a follow-up that should precede any scorecard model claim.

## Reproduce

```bash
# Quality (Homebrew mlx python on PATH so the batch runtime can import mlx_lm)
PATH=/opt/homebrew/bin:$PATH \
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
  ./script/local_quality_audit.py --batch \
    --input docs/evals/external-blind-prompts-2026-06-13.jsonl \
    --generate --model qwen35-4b --timeout 45

# Latency (fresh proof + strict window selection)
./script/fresh_latency_proof.sh --target textedit-model-latency
./script/select_latency_window.py \
  --diagnostics-log ~/Library/Logs/SteadyType/diagnostics.log \
  --trace-log ~/Library/Logs/SteadyType/traces.jsonl \
  --expected-asset Qwen3.5-4B-4bit \
  --required-proof-app com.apple.TextEdit \
  --required-proof-scenario textedit-model-latency \
  --required-trace-app com.apple.TextEdit --required-request-mode wordCompletion \
  --require-model-backed-visible --forbid-fast-word-visible \
  --app-binary dist/SteadyType.app/Contents/MacOS/SteadyType
```

## What this is and isn't

- It **is** a deterministic harness score on blind external text (reproducible
  from the command above), plus an honest record of a latency proof that was
  attempted and blocked, with the exact steps to unblock it.
- It is **not** a live writing dogfood with accepted-kept / typed-over /
  annoyance signals, and the relevance metric rewards matching the original
  author's exact words — a low score means "didn't predict the source," not
  "bad suggestion." Treat 29/100 as a floor on a hard blind set, not a verdict
  that the suggestions are unusable.
