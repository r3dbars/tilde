# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, or any other model server.

The product should own the model runtime. The user launches one Mac app and autocomplete works.

## First Candidate: MLX

MLX is the first practical runtime candidate for this Mac prototype because it is Apple Silicon native and can live behind the app-owned `ModelRuntime` boundary. LiteRT-LM stays tracked as the fallback candidate because it is Google's app/runtime path for Gemma edge models and has Gemma 4 support, including a `gemma-4-E2B-it-litert-lm` package path.

Sources:

- [MLX Swift LM GitHub](https://github.com/ml-explore/mlx-swift-lm)
- [MLX Swift LM package](https://github.com/ml-explore/mlx-swift-lm/blob/main/Package.swift)
- [Gemma 4 launch post](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/)

## Model Asset Format

Use the MLX/Hugging Face directory format under:

`~/Library/Application Support/AutocompleteLab/Models/Gemma4E2B/MLX/gemma-4-e2b-mlx`

The directory should contain at least:

- `config.json`
- tokenizer files such as `tokenizer.json` or `tokenizer_config.json`
- one or more `.safetensors` weight files

The likely first model repo is `mlx-community/gemma-4-e2b-it-4bit`, exposed by MLX Swift LM as `LLMRegistry.gemma4_e2b_it_4bit`.

## Fallback Candidate: LiteRT-LM

LiteRT-LM should be revisited once the Swift/macOS path is ready enough. If MLX binding work gets too heavy, LiteRT-LM may still become the better packaged embedded route.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

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
