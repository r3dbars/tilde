# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, or any other model server.

The product should own the model runtime. The user launches one Mac app and autocomplete works.

## First Candidate: LiteRT-LM

MLX is the first practical runtime candidate for this Mac prototype because it is Apple Silicon native and can live behind the app-owned `ModelRuntime` boundary. LiteRT-LM stays tracked as the fallback candidate because it is Google's app/runtime path for Gemma edge models and has Gemma 4 support, including a `gemma-4-E2B-it-litert-lm` package path.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

## Fallback Candidate: MLX

LiteRT-LM should be revisited once the Swift/macOS path is ready enough. If MLX binding work gets too heavy, LiteRT-LM may still become the better packaged embedded route.

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
