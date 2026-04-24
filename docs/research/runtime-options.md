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
