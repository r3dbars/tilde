# Runtime Options

## Decision

Do not make users start Ollama, llama.cpp, or any other model server.

The product should own the model runtime. The user launches one Mac app and autocomplete works.

## First Candidate: MLX

MLX is the first practical runtime candidate for this Mac prototype because it is Apple Silicon native and can live behind the app-owned `ModelRuntime` boundary. Qwen3.5 4B is the documented default because it is the current low-latency quality target for short autocomplete completions. LiteRT-LM stays tracked as a fallback candidate for future app-owned packaging work.

Sources:

- [MLX Swift LM GitHub](https://github.com/ml-explore/mlx-swift-lm)
- [MLX Swift LM package](https://github.com/ml-explore/mlx-swift-lm/blob/main/Package.swift)

## Model Asset Format

Use the MLX/Hugging Face directory format under:

`~/Library/Application Support/AutocompleteLab/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit`

The directory should contain at least:

- `config.json`
- tokenizer files such as `tokenizer.json` or `tokenizer_config.json`
- one or more `.safetensors` weight files

The default model repo is `mlx-community/Qwen3.5-4B-4bit`.

## Fallback Candidate: LiteRT-LM

LiteRT-LM should be revisited once the Swift/macOS path is ready enough. If MLX binding work gets too heavy, LiteRT-LM may still become the better packaged embedded route.

Sources:

- [LiteRT-LM GitHub](https://github.com/google-ai-edge/LiteRT-LM)
- [LiteRT GenAI overview](https://ai.google.dev/edge/litert/genai/overview)

## Product Constraints

- app-owned runtime
- no user-managed server
- Qwen3.5 4B
- macOS 26 on Apple Silicon for the private beta
- reasoning off
- 8-16 generated tokens
- 2-8 visible words
- average latency under 700ms
- stretch latency under 300ms after warmup
