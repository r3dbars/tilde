# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, Python helper scripts, or any other
model server.

The product should own the model runtime. The user launches one Mac app and
autocomplete works.

## Current Preferred Path: MLX + Qwen3.5 4B

MLX is the current runtime path because it is Apple Silicon native and already
lives behind the app-owned `ModelRuntime` boundary. Qwen3.5 4B is the documented
default because it is the current low-latency quality target for short
autocomplete completions. LiteRT-LM stays tracked as a fallback candidate for
future app-owned packaging work.

The preferred beta model asset is Qwen3.5 4B 4-bit:

```text
~/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

The matching development download alias is:

```bash
script/download_mlx_model.py --model qwen35-4b
```

That helper is for local development and packaging prep. It should not be part
of tester onboarding.

In the app, Settings now owns the install path. When the model folder is
missing, use `Install Local Model`. When the folder is incomplete, use `Repair
Local Model`. The app rechecks the asset and retries the MLX runtime after the
download completes.

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
- `qwen3-0.6b`: very small smoke-test baseline.
- `gemma-4-e2b`: historical Gemma E2B candidate.
- `gemma-4-e4b`, `gemma4-e4b`, or `gemma-4-e4b-4bit`: Gemma 4 E4B MLX trial.
- `gemma-4-e4b-it-optiq`, `gemma-4-e4b-it-optiq-4bit`, or `gemma4-e4b-it-optiq`: Gemma 4 E4B OptiQ trial.
- `gemma-4-26b`: larger Gemma 4 trial.

Gemma 4 E2B is no longer the beta target. It remains a historical candidate
because earlier MLX loading did not make it the fastest path to a playable
native build.

## Model Asset Format

Use the MLX/Hugging Face directory format under:

```text
~/Library/Application Support/AutocompleteLab/Models/<ModelName>/MLX/<AssetFolder>
```

The preferred beta asset currently resolves to:

```text
~/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit
```

The directory should contain at least:

- `config.json`
- tokenizer files such as `tokenizer.json` or `tokenizer_config.json`
- one or more `.safetensors` weight files

The default model repo is `mlx-community/Qwen3.5-4B-MLX-4bit`.

## Runtime Readiness Evidence

The beta runtime gate is intentionally tied to the latest app launch, not old
diagnostic strings. Before beta, run:

```bash
AUTOCOMPLETE_LAB_REQUIRE_READY=1 \
AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit \
./script/check_diagnostics_log.sh
```

That gate must find all of this in the latest launch slice:

- `launch accessibility=...`
- `launch-health ... crashOrForceQuitSuspected=...`
- `runtime-bootstrap activeCandidate=mlx ... nativeRuntimeAvailable=true`
- `runtime-warm-succeeded candidate=mlx durationMilliseconds=...`
- `runtime ... readinessAction=none readinessStage=ready state=ready (MLX)`

It also rejects `activeCandidate=mock`, `candidate=mock`,
`state=ready (mock)`, `fallbackReason=...`, user-managed servers, and the wrong
model asset.

## Fallback Candidate: LiteRT-LM

LiteRT-LM stays tracked as a future packaged runtime candidate, especially for
Gemma-family edge models. It is not the current beta path.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

## Product Constraints

- app-owned runtime
- no user-managed server
- Qwen3.5 4B 4-bit preferred beta asset
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
