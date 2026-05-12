# Claude Code Guide

App-owned runtime bindings live here.

Start with:

- `AppModelRuntimeFactory.swift`
- `MLXModelRuntime.swift`
- `ModelAssetInstaller.swift`
- `LocalModelAssetInstaller.swift`

Rules:

- Keep MLX and Hugging Face dependencies outside `AutocompleteLabCore`.
- Product UX must not require users to start Ollama, llama.cpp, or another server.
- Missing runtime or model assets should produce clear readiness guidance, not silent mock fallback.
- Add tests for installer paths, factory selection, and readiness failures.
