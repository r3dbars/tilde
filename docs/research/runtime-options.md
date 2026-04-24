# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, or any other model server.

The product should own the model runtime. The user launches one Mac app and autocomplete works.

## First Candidate: LiteRT-LM

LiteRT-LM is the first runtime candidate because it is Google's app/runtime path for Gemma edge models. Google says LiteRT-LM supports desktop and has Gemma 4 support, including a `gemma-4-E2B-it-litert-lm` package path. It also exposes stable C++ APIs, while Swift support is still marked as in development.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

## Fallback Candidate: MLX

MLX is the fallback to benchmark because Google lists MLX as a day-one Gemma 4 ecosystem option, and it is Apple Silicon native. If the LiteRT-LM Swift/macOS path is not ready enough, MLX may be the more practical embedded route.

Source:

- [Gemma 4 launch post](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/)

## Product Constraints

- app-owned runtime
- no user-managed server
- Gemma 4 E2B
- M1 / 16 GB first target
- reasoning off
- 8-16 generated tokens
- 2-8 visible words
- average latency under 700ms
- stretch latency under 300ms after warmup

## Benchmark Scaffold

Run the local scaffold with:

```sh
script/gemma_runtime_benchmark.sh
```

It checks LiteRT-LM first and MLX second, runs warmup/sample prompts when a runtime is available, reports average latency, and never starts a user-managed server.

The app bundles `script/local_completion_runtime.py` into `AutocompleteLab.app/Contents/Resources`. That helper tries:

1. LiteRT-LM CLI with `litert-community/gemma-4-E2B-it-litert-lm`
2. MLX with `mlx-community/gemma-4-E2B-it-4bit`
3. Swift mock fallback if neither runtime works

Useful overrides:

- `AUTOCOMPLETE_LAB_RUNTIME_BACKEND=litert|mlx|auto`
- `AUTOCOMPLETE_LAB_LITERT_BIN=/path/to/litert-lm`
- `AUTOCOMPLETE_LAB_LITERT_REPO=litert-community/gemma-4-E2B-it-litert-lm`
- `AUTOCOMPLETE_LAB_LITERT_MODEL=gemma-4-E2B-it.litertlm`
- `AUTOCOMPLETE_LAB_MLX_BIN=/path/to/mlx_lm.generate`
- `AUTOCOMPLETE_LAB_MLX_MODEL=mlx-community/gemma-4-E2B-it-4bit`

Google's current LiteRT-LM CLI docs install the CLI with:

```sh
uv tool install litert-lm
```

And run Gemma 4 E2B with:

```sh
litert-lm run \
  --from-huggingface-repo=litert-community/gemma-4-E2B-it-litert-lm \
  gemma-4-E2B-it.litertlm \
  --prompt="What is the capital of France?"
```
