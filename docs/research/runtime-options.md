# Local Runtime Decision

Status: current architecture boundary, not a release claim.

SteadyType owns its MLX runtime and model assets. A user should never need to
start Ollama, llama.cpp, Python, or another model server to write with the app.

## Current Boundary

- Normal inference runs locally in the SteadyType process.
- Model install or repair is a user-triggered network path and may contact the
  configured model host.
- Beta assets must use an immutable source revision and pass the integrity
  receipt checks before the runtime is called ready.
- Missing or invalid assets fail closed; production UX must not fall back to a
  mock engine.

The runtime uses the MLX and Hugging Face Swift packages declared in
`Package.swift`. `Sources/AutocompleteLabApp/Runtime/` owns native loading and
installation; pure readiness and asset policy stays in
`Sources/AutocompleteLabCore/Runtime/`.

## Current Release Hold

The app runtime policy and the release scripts currently disagree about which
model asset is preferred. Until that mismatch is resolved in code and the full
private-beta gate passes, do not name a release-ready default model.

Use these checks for current truth:

```bash
./script/check_model_asset.py
./script/package_release.sh --check
./script/beta_readiness.sh --check-only
```

This document intentionally avoids model comparison tables and speculative
fallbacks. A new runtime belongs here only after it has an app-owned install
path, privacy review, deterministic tests, and measured local proof.
