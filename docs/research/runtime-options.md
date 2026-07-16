# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, Python helper scripts, or any other
model server.

The product should own the model runtime. The user launches one Mac app and
autocomplete works.

## Current Preferred Path: MLX + Qwen3.5 4B

MLX is the current runtime path because it is Apple Silicon native and already
lives behind the app-owned `ModelRuntime` boundary. Qwen3.5 4B is the current
default (`RuntimeBootstrapPlan.preferredMLX` / `CompletionModelPolicy.mvp.model`)
because its immutable source and local integrity receipt are verified before MLX
warms it. Gemma 4 E4B IT OptiQ remains selectable for explicit trials. LiteRT-LM
stays tracked as a future candidate for app-owned packaging research, but it is
not a runtime fallback in the app or beta UX.

The default beta model asset is Qwen3.5 4B (4-bit):

```text
~/Library/Application Support/SteadyType/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

The matching development download alias is:

```bash
script/download_mlx_model.py --model qwen35-4b
```

Gemma 4 E4B IT OptiQ stays available as a selectable alternative
(`--model gemma-4-e4b-it-optiq`). These helpers are for local development and
packaging prep. They should not be part of tester onboarding.

In the app, Settings now owns the install path. When the model folder is
missing, use `Install Local Model`. When the folder is incomplete, use `Repair
Local Model`. The app rechecks the asset and retries the MLX runtime after the
download completes.

The default model source is pinned to Hugging Face revision
`32f3e8ecf65426fc3306969496342d504bfa13f3`. Install and repair flows write a
local `.steadytype-model-integrity.json` receipt with file sizes and SHA-256
hashes. `./script/check_model_asset.py` verifies that receipt before beta use.

Sources:

- [MLX Swift LM GitHub](https://github.com/ml-explore/mlx-swift-lm)
- [MLX Swift LM package](https://github.com/ml-explore/mlx-swift-lm/blob/main/Package.swift)
- [Qwen3.5 4B MLX model](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit)

## macOS Target

Lower the runtime target to macOS 14.

Evidence: the current app code does not use macOS 26-only APIs, and the pinned
`mlx-swift-lm` dependency declares macOS 14 as its minimum. Keep Apple Silicon
as the hardware target because MLX/Metal is the runtime path.

Build settings:

- `Package.swift`: `.macOS(.v14)`
- app bundle `LSMinimumSystemVersion`: `14.0`

## Other Local Trial Models

These are useful for developer trials, not the default beta promise:

- `qwen35-4b` or `qwen3.5-4b`: preferred Qwen3.5 4B beta asset.
- `qwen35-9b` or `qwen3.5-9b`: Qwen3.5 9B 4-bit, better quality trial with higher cost.
- `qwen3-1.7b`: smaller Qwen3 baseline.
- `small-draft-1b`: named 1B-class draft lane alias for `qwen3-1.7b`.
- `qwen3-0.6b`: very small smoke-test baseline.
- `gemma-4-e2b`: historical Gemma E2B candidate.
- `gemma-4-e4b`, `gemma4-e4b`, or `gemma-4-e4b-4bit`: Gemma 4 E4B MLX trial.
- `gemma-4-e4b-it-optiq`, `gemma-4-e4b-it-optiq-4bit`, or `gemma4-e4b-it-optiq`: Gemma 4 E4B OptiQ trial.
- `gemma-4-26b`: larger Gemma 4 trial.

Gemma 4 E2B is no longer the beta target. It remains a historical candidate
because earlier MLX loading did not make it the fastest path to a playable
native build.

## Small Draft Lane

The small/faster experiment lane is `small-draft-1b`, which resolves to the
pinned Qwen3 1.7B 4-bit MLX asset. This lane exists for speed and draft-quality
experiments only. It must not replace the 4B default unless it wins on both
blind quality and latency.

Download or inspect the asset:

```bash
script/download_mlx_model.py --model small-draft-1b --print-target
script/download_mlx_model.py --model small-draft-1b
```

Run the app with the small model:

```bash
AUTOCOMPLETE_LAB_MODEL=small-draft-1b ./script/build_and_run.sh --verify
```

Compare the small lane against the 4B default from redacted diagnostics:

```bash
./script/compare_local_models.py --small-draft-lane
```

## Prompt KV Cache (First-Token Latency)

The app-owned MLX runtime has two generation paths. The slow path rebuilds a
`ChatSession` per request and re-prefills the entire system prompt every time.
The fast path (`generateRawCompletionWithPromptKVCache`) keeps the prefilled
system-prompt + prior-context KV across keystrokes in the same field, so only
the newly typed tokens are prefilled. Because the autocomplete system prompt is
large and the generation budget is tiny (about 14 phrase tokens), prefill
dominates first-token latency, and the fast path is the single biggest win.

The prompt KV cache is now **on by default**. Set
`AUTOCOMPLETE_LAB_MLX_KV_CACHE` to an explicit off value (`0`, `false`, `no`,
`off`) to fall back to the slower full-re-prefill path. Any other value (or no
value) keeps it on. Cache reuse still requires a byte-stable system prompt and a
strict token-prefix extension within the same field; mid-typing changes to the
system prompt (mode, behavior profile, visible-page guidance) cause a clean miss
and a full re-prefill, so trimming and stabilizing the system prompt remains a
follow-up latency lever to validate with the latency proof.

## Warmup Generation After Load

Loading the model only allocates weights; the MLX/Metal compute graph is not
compiled until the first generation runs. Without a warmup that first
compilation lands on the user's first real keystroke, making the very first
suggestion the slowest one. The runtime now runs a tiny throwaway generation at
the end of background warm (`warmupCompletionGraph`), so the graph is compiled
before the runtime reports ready. It is best-effort and never blocks readiness.
Set `AUTOCOMPLETE_LAB_MLX_WARMUP` to an off value (`0`, `false`, `no`, `off`) to
skip it. Warmup timing is recorded as `mlx-model-warmup-succeeded` in
diagnostics.

## Measuring Models Without a Cold Load Per Row

The quality/latency audit harness used to spawn a fresh `mlx_lm.generate`
subprocess for every prompt row, cold-loading the whole model 36+ times in a
single run. That is why a blind audit could not finish even the first model in
two minutes. `script/local_completion_batch.py` loads the model once and streams
every row through it, and it prefers the installed local asset directory under
`~/Library/Application Support/SteadyType/Models/...` over a Hugging Face repo
id so it never silently re-downloads weights.

The audit scripts use this batch path:

```bash
AUTOCOMPLETE_LAB_LOCAL_QUALITY_AUDIT=1 \
AUTOCOMPLETE_LAB_RUNTIME_BACKEND=mlx \
  ./script/small_model_blind_audit_report.py --run
```

`script/local_quality_audit.py --generate --batch` is the single-model entry
point. The blind-audit report now also enforces an overall wall-clock budget per
model, so a wedged run fails fast with a timeout note instead of hanging.

## Model Asset Format

Use the MLX/Hugging Face directory format under:

```text
~/Library/Application Support/SteadyType/Models/<ModelName>/MLX/<AssetFolder>
```

The preferred beta asset currently resolves to:

```text
~/Library/Application Support/SteadyType/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

The directory should contain at least:

- `config.json`
- tokenizer files such as `tokenizer.json` or `tokenizer_config.json`
- one or more `.safetensors` weight files
- `.steadytype-model-integrity.json`

The default model repo is `mlx-community/gemma-4-e4b-it-OptiQ-4bit`. The
selectable Qwen alternative is `mlx-community/Qwen3.5-4B-MLX-4bit`.

## Future Candidate: LiteRT-LM

LiteRT-LM stays tracked as a future packaged runtime candidate, especially for
Gemma-family edge models. It is not the current beta path.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

## Product Constraints

- app-owned runtime
- no user-managed server
- Gemma 4 E4B IT OptiQ (4-bit) default beta asset; Qwen3.5 4B 4-bit selectable
- macOS 14 or newer on Apple Silicon for the private beta
- Apple Silicon with 16 GB RAM first target
- reasoning off
- 9 generated tokens by default
- 1-3 visible words by default
- p95 first-visible latency at or below 750ms for supported status
- p95 first-visible latency at or below 1000ms for caveated status
- average latency under 700ms as a private beta target
- stretch latency under 300ms after warmup
- no beta if runtime falls back to mock output
- default latency proof: `./script/model_latency_report.py --default-model-proof`
