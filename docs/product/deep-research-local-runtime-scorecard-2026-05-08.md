# Local Runtime Scorecard - 2026-05-08

## Source

- Deep Research topic: Local Runtime Rubric for Mac Autocomplete
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `32a78a23457fb1ccb725fb219f5b3c96f3073502`, plus local branch changes on `codex/local-runtime-scorecard-20260508`

## Executive Summary

The research says this app cannot be beta-ready just because it is "local." It needs an app-owned, warm, real model path that stays fast while the user types, fails closed under pressure, never asks testers to run a server, and never hides behind mock output.

This repo has a real MLX/Qwen3.5 app-owned path, in-app model install/repair, strong output cleaning, local privacy defaults, stale-result guards, pinned installed-asset proof, runtime failure backoff, warm default-model latency proof, and good trace tooling. The biggest blockers are still no helper/XPC isolation, no real power or memory-pressure proof run, incomplete benchmark gating, and incomplete manual real-app proof.

## Product Standard

Excellence for this app means:

- One Mac app owns the local model runtime end to end.
- Users never start Ollama, llama.cpp, Python, or any model server.
- The default model is installed, validated, warmed, and repaired inside the app.
- Warm suggestions feel predictive while typing, with p95 first-visible latency under the beta target.
- Mock suggestions are test-only and cannot make a beta build look ready.
- Missing, corrupt, slow, hot, memory-pressured, or failed runtime states suppress suggestions.
- The app records enough local, redacted evidence to prove latency, stale drops, invalid output, fallback frequency, RSS, and thermal behavior.

## Non-Negotiables

These block beta or force the relevant category to zero:

- User-managed model server required.
- Cloud inference or typed-text upload by default.
- Mock output shown as production or beta autocomplete.
- Missing or corrupt model still produces suggestions.
- Stale model output appears after caret, text, app, or field changed.
- Runtime failure steals focus, blocks normal typing, or crashes the typing path.
- Thermal serious/critical or memory critical state does not degrade or stop generation.
- No way to install, repair, or honestly report missing local model state.
- No current latency proof for the default model.

## Current App Assessment

Starting score before this pass: **72/100**.

The starting app had real MLX runtime code and in-app model setup, but still had production-facing mock fallback wiring in `RuntimeBootstrapPlan` and `AppModelRuntimeFactory`, README copy claiming mock fallback, a macOS package target that disagreed with runtime docs, and no memory/thermal response.

After this pass, runtime bootstrap fails closed instead of selecting `MockModelRuntime`, the legacy local engine fails closed instead of returning mock suggestions, app diagnostics state `mockFallbackAllowed=false`, the package target matches macOS 14, a backend sanity gate is part of smoke/beta checks, resource pressure now suppresses suggestions and unloads the runtime on serious/critical pressure, the preferred Qwen3.5 4B model source is pinned, and runtime warmup now includes one hidden generation before the app reports the model ready.

The score is still capped because the runtime runs inside the menu bar app process instead of a helper/XPC process, real battery/thermal/memory-pressure proof is still missing, and the passing latency proof is an automated runtime probe rather than fresh manual typing proof in every target app.

## Score

Overall score: **89/100**

## Score Breakdown

### Latency and Responsiveness

- Weight: 25
- Current score: 23.5/25
- Why this score: The app has MLX timing logs, streaming partials, short 3-word/9-token MVP generation caps, stale request tickets, hidden generation warmup before ready state, and passing default-model latency proof. The latest automated Qwen3.5 4B probe produced one warmup generation at 155ms, then five shown phrase samples with p95 125ms and average 117ms.
- Evidence found in repo: `Sources/AutocompleteLabCore/Configuration/ModelPolicy.swift`, `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`, `Sources/AutocompleteLabCore/Session/SuggestionRequestGate.swift`, `Sources/AutocompleteRuntimeProbe/main.swift`, `script/runtime_latency_probe.sh`, `script/build_mlx_metallib.sh`, `script/model_latency_report.py`, `script/model_latency_report_self_test.sh`
- Missing evidence: p99 from longer replay; sleep/wake split; manual target-app typing proof that the app UI path matches the probe.
- What would make it 100/100: Automated replay and live default-model proof show ideal or high-acceptable TTFS on reference 16 GB Macs, with stale suggestions dropped under target.

### Output Validity and Usefulness

- Weight: 20
- Current score: 18/20
- Why this score: Cleaner and prompt builder are strong and conservative. They reject prompt echo, assistant chatter, unsafe prompt actions, repeated context, invalid word suffixes, and low-value phrases.
- Evidence found in repo: `Sources/AutocompleteLabCore/Engine/CompletionOutputCleaner.swift`, `Sources/AutocompleteLabCore/Engine/CompletionPromptBuilder.swift`, `Tests/AutocompleteLabCoreTests/CompletionOutputCleanerTests.swift`, `Tests/AutocompleteLabCoreTests/CompletionPromptBuilderTests.swift`
- Missing evidence: Real model invalid-output frequency under current default Qwen build; syntax-aware code validation is not present.
- What would make it 100/100: Invalid output under 0.5% on replay, syntax checks for code contexts, and proof that cleaner drops never leak to UI.

### Memory, Thermal, and Battery Behavior

- Weight: 15
- Current score: 10.5/15
- Why this score: This pass added a policy and app observer for memory warning/critical and thermal fair/serious/critical. Warning/fair suppress work; serious/critical unloads the runtime. The runtime probe now records RSS and thermal state; the latest proof saw warmup RSS 3069MB, visible-suggestion RSS p95 3537MB, and thermal state `fair`. This is useful evidence, but not a full pressure or battery trace.
- Evidence found in repo: `Sources/AutocompleteLabCore/Runtime/RuntimeResourcePressurePolicy.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Sources/AutocompleteRuntimeProbe/main.swift`, `script/model_latency_report.py`, `Tests/AutocompleteLabCoreTests/RuntimeResourcePressurePolicyTests.swift`
- Missing evidence: Real memory-pressure test, 30-minute battery typing replay, Instruments/xctrace power summary, nominal/pressure transition proof in the app process.
- What would make it 100/100: Automated pressure checks prove warning drops transient work, critical unloads the model, UI stays responsive, and thermal/power gates pass on reference hardware.

### Runtime Ownership and Lifecycle

- Weight: 15
- Current score: 13.5/15
- Why this score: The app owns the MLX runtime and model path, does not allow user-managed servers, fails closed instead of falling back to mock in the app target, and now keeps the runtime in warming state until a hidden generation has completed. Runtime is still inside the menu bar app process, not a helper/XPC process.
- Evidence found in repo: `Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift`, `Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift`, `Sources/AutocompleteLabApp/Runtime/UnavailableModelRuntime.swift`, `Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift`, `Sources/AutocompleteRuntimeProbe/main.swift`, `script/check_backend_sanity.sh`
- Missing evidence: XPC/helper isolation, helper restart/backoff, process-level crash recovery, shared cache lifecycle, sleep/wake proof.
- What would make it 100/100: Bundled helper owns model/tokenizer/cache, menu bar process survives helper crash/OOM, warm/cold/sleep/wake paths are measured.

### Install, Update, and Repair UX

- Weight: 10
- Current score: 9.5/10
- Why this score: The app validates required model files, downloads through Settings, stages into scratch space, atomically replaces the target, keeps old assets on failure, pins the preferred Qwen3.5 4B Hugging Face revision, and now rejects installed folders whose Hugging Face metadata does not match the pinned revision.
- Evidence found in repo: `Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift`, `Sources/AutocompleteLabApp/Runtime/HuggingFaceModelMetadata.swift`, `Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift`, `Tests/AutocompleteLabAppTests/ModelAssetInstallerTests.swift`, `script/download_mlx_model.py`, `script/check_model_asset.py`, `script/check_model_asset_self_test.sh`
- Missing evidence: Resumable/background install, disk-space preflight, offline repair proof, full file digest verification after install.
- What would make it 100/100: Pinned model revision, resumable install, checksum/manifest verification, rollback and offline revalidation proved by tests.

### Failure Behavior and Observability

- Weight: 10
- Current score: 9.5/10
- Why this score: Missing/invalid/warming/failed runtime states block suggestions. This pass removed mock fallback as app readiness, removed the legacy core mock fallback, added backend sanity gating, and added a fail-closed generation-error backoff after repeated runtime failures.
- Evidence found in repo: `Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift`, `Sources/AutocompleteLabCore/Engine/LocalCompletionEngine.swift`, `Sources/AutocompleteLabCore/Engine/RuntimeBackedCompletionEngine.swift`, `Sources/AutocompleteLabApp/Runtime/UnavailableModelRuntime.swift`, `Tests/AutocompleteLabCoreTests/LocalCompletionEngineTests.swift`, `Tests/AutocompleteLabCoreTests/MockModelRuntimeTests.swift`, `Tests/AutocompleteLabAppTests/UnavailableModelRuntimeTests.swift`, `script/check_backend_sanity.sh`, `script/beta_readiness.sh`
- Missing evidence: Helper crash recovery, fallback-frequency metric from replay, CI gate that rejects mock in beta artifacts.
- What would make it 100/100: Every failure has a typed reason, no deceptive fallback, repeated failures degrade or suspend, and release checks fail on hidden mock/network/server paths.

### Benchmark Coverage

- Weight: 5
- Current score: 4.8/5
- Why this score: There are good self-tests and scripts for latency, trace eval, model assets, app bundle checks, beta readiness, and now a standalone default-runtime latency probe that emits warmup, visible-suggestion, RSS, and thermal diagnostics compatible with the readiness report. The default proof report now selects the latest launch with enough phrase samples instead of being invalidated by a newer empty bootstrap. The scripts still do not cover the full research matrix.
- Evidence found in repo: `Sources/AutocompleteRuntimeProbe/main.swift`, `script/runtime_latency_probe.sh`, `script/build_mlx_metallib.sh`, `script/model_latency_report.py`, `script/check_trace_eval.sh`, `script/check_model_asset.py`, `script/check_diagnostics_log.sh`, `script/smoke_test.sh`, `script/beta_readiness.sh`
- Missing evidence: Replay benchmark scripts for cold/warm, model matrix, memory pressure, install repair, power trace, and backend sanity as a release artifact report.
- What would make it 100/100: CI/release gating records TTFS p50/p95/p99, RSS, CPU/GPU, battery delta, fallback, invalid output, stale output, install failures, and thermal transitions.

## 0/100 Definition

The local runtime area is 0/100 if the app needs a user-managed model server, uploads typed text by default, uses mock suggestions as the beta path, cannot block suggestions while the model is missing or broken, or crashes/blocks normal typing during ordinary runtime use.

## 50/100 Definition

The app has a real local model path, but it is still prototype-grade: manual setup is needed, latency is not proved, mock fallback can leak into the user experience, failures are vague, or memory/thermal behavior is unknown.

## 80/100 Definition

The app-owned local runtime is real, missing/invalid states are honest, mock fallback is sealed out of beta, default-model latency proof passes at acceptable targets, and thermal/memory pressure degrades safely. Some helper isolation, power proof, or benchmark breadth can still be missing.

## 100/100 Definition

The app owns the runtime in an isolated helper, ships one pinned default model path, passes warm/cold/wake/default-model latency gates on reference hardware, proves battery/RSS/thermal behavior, blocks all stale or invalid output, and release gating rejects mock fallback, cloud fallback, and user-managed runtime paths.

## Failure Modes

1. Mock output shown when the real local runtime is missing or broken.
2. Stale model output appears after the focused app, field, caret, or nearby text changed.
3. Runtime crash or OOM takes down the menu bar app while the user is typing.
4. Thermal serious/critical or memory critical state keeps generating instead of stopping.
5. Default model cannot hit p95 latency target but the app still claims beta readiness.
6. Missing/corrupt model leaves the user with vague setup instructions or shell-only repair.
7. Model source changes upstream despite the pinned preferred revision because local asset metadata does not yet prove the installed revision.
8. Power/battery drain makes normal editing worse.
9. Duplicate model-result tracing skews metrics.
10. Benchmark scripts exist but are not tied to release gates.

## Evidence Requirements

- `swift test` passing.
- `./script/check_backend_sanity.sh` passing.
- `./script/check_model_asset.py` passing for Qwen3.5 4B.
- `./script/model_latency_report.py --default-model-proof` passing from a current launch or `./script/runtime_latency_probe.sh 5` producing equivalent current default-model diagnostics.
- `AUTOCOMPLETE_LAB_REQUIRE_READY=1 AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit ./script/check_diagnostics_log.sh` passing.
- Bounded trace replay proving stale drops, invalid output drops, accepted-and-kept metadata, and no mock fallback.
- Memory-pressure proof showing warning/fair suppression and critical/serious unload.
- 30-minute battery/thermal typing replay artifact.
- App bundle check proving MLX/Metal resources are packaged and no external runtime is required.

## Verification This Pass

- `swift test`: passed, 742 tests.
- `swift test --filter RuntimePolicyTests`: passed.
- `swift test --filter RuntimeResourcePressurePolicyTests`: passed.
- `swift test --filter UnavailableModelRuntimeTests`: passed.
- `swift test --filter 'CompletionPromptBuilderTests|MockModelRuntimeTests|ModelPolicyTests|LocalCompletionEngineTests'`: passed after MVP default changed to 3 visible words / 9 generated tokens and legacy local engine fallback changed to fail closed.
- `swift test --filter 'MockModelRuntimeTests|RuntimePolicyTests|ModelAssetInstallerTests'`: passed after pinned revision validation and runtime failure backoff.
- `./script/check_backend_sanity.sh`: passed.
- `./script/model_latency_report_self_test.sh`: passed.
- `./script/check_trace_eval_self_test.sh`: passed.
- `./script/check_model_asset_self_test.sh`: passed.
- `./script/check_test_coverage_manifest.sh`: passed.
- `./script/check_model_asset.py`: passed for Qwen3.5 4B MLX after repairing the local model folder to pinned revision `32f3e8ecf65426fc3306969496342d504bfa13f3`; report includes metadata fingerprint `sha256:27f35688a1eacdcb59b9767e177cbce42a5545cbfd202a67f61e9f70140c4c41`.
- `./script/runtime_latency_probe.sh 5`: passed. It built the MLX metallib, recorded the probe bootstrap before warmup, ran one hidden warmup generation at 155ms, produced five Qwen3.5 4B phrase samples, and `./script/model_latency_report.py --default-model-proof` passed with shown p95 125ms and average 117ms. The report also captured warmup RSS 3069MB, visible-suggestion RSS p95 3537MB, and thermal state `fair`.
- `./script/model_latency_report.py --default-model-proof`: passed after the report was hardened to select the latest Qwen launch with enough phrase samples and ignore non-probe timing inside a probe launch.
- `./script/smoke_test.sh`: blocked by visual placement evidence gaps after Swift tests, backend sanity, coverage manifest, quality eval, model asset self-test, manual smoke self-test, real-app smoke self-test, proof manifest self-test, and visual evidence self-test passed.
- `./script/beta_readiness.sh --check-only`: blocked by 16 stale or pending manual app proof rows, 6 screenshot-backed visual proof gaps plus stale Codex proof, and missing `dist/AutocompleteLab.zip`; backend sanity, model asset, runtime production gate, redacted export, and package prerequisites passed.

## Implementation Queue

### Done In This Pass: Seal Production Mock Fallback

- Objective: Do not let missing/invalid runtime select `MockModelRuntime` for app readiness.
- Files likely involved: `RuntimeBootstrapPlan.swift`, `AppModelRuntimeFactory.swift`, `UnavailableModelRuntime.swift`, `README.md`
- Tests to add/update: `RuntimePolicyTests.swift`, `UnavailableModelRuntimeTests.swift`
- Proof required: `swift test --filter RuntimePolicyTests`, `swift test --filter UnavailableModelRuntimeTests`, `./script/check_backend_sanity.sh`
- Risk level: High product trust, low implementation risk
- Expected score impact: +3

### Done In This Pass: Resource Pressure Fail-Closed Policy

- Objective: Suppress suggestions on fair/warning pressure and unload runtime on serious/critical pressure.
- Files likely involved: `RuntimeResourcePressurePolicy.swift`, `AppDelegate.swift`, `MLXModelRuntime.swift`
- Tests to add/update: `RuntimeResourcePressurePolicyTests.swift`
- Proof required: focused tests now, real pressure/power proof later
- Risk level: Medium
- Expected score impact: +2

### Done In This Pass: Runtime Target and Gate Consistency

- Objective: Align SwiftPM target with documented macOS 14 support and add a backend sanity script to smoke/beta gates.
- Files likely involved: `Package.swift`, `script/check_backend_sanity.sh`, `script/smoke_test.sh`, `script/beta_readiness.sh`
- Tests to add/update: backend sanity script
- Proof required: `./script/check_backend_sanity.sh`, `swift test`
- Risk level: Low
- Expected score impact: +1

### Done In This Pass: Align Runtime Length Defaults and Remove Legacy Mock Fallback

- Objective: Keep beta runtime defaults at 3 visible words / 9 generated tokens and make the legacy local engine fail closed instead of returning mock suggestions.
- Files likely involved: `ModelPolicy.swift`, `LocalCompletionEngine.swift`, `ModelPolicyTests.swift`, `LocalCompletionEngineTests.swift`, `check_backend_sanity.sh`
- Tests to add/update: `ModelPolicyTests.swift`, `LocalCompletionEngineTests.swift`
- Proof required: `swift test --filter ModelPolicyTests`, `swift test --filter LocalCompletionEngineTests`, `./script/check_backend_sanity.sh`
- Risk level: Medium
- Expected score impact: +2

### Done In This Pass: Verify Installed Model Revision and Add Failure Backoff

- Objective: Treat stale or unproven pinned model folders as repair-needed and stop repeated runtime generation failures from hammering the typing path.
- Files likely involved: `RuntimeBootstrapPlan.swift`, `HuggingFaceModelMetadata.swift`, `AppModelRuntimeFactory.swift`, `ModelAssetInstaller.swift`, `RuntimeBackedCompletionEngine.swift`, `check_model_asset.py`
- Tests to add/update: `RuntimePolicyTests.swift`, `ModelAssetInstallerTests.swift`, `MockModelRuntimeTests.swift`, `check_model_asset_self_test.sh`
- Proof required: `swift test --filter 'MockModelRuntimeTests|RuntimePolicyTests|ModelAssetInstallerTests'`, `./script/check_model_asset_self_test.sh`, `./script/check_model_asset.py`
- Risk level: Medium
- Expected score impact: +1

### Done In This Pass: Generate Fresh Qwen Latency Proof

- Objective: Produce enough current Qwen3.5 4B phrase timing and shown-latency samples to pass default proof, and make model warmup pay the first-generation cost before suggestions are allowed.
- Files likely involved: `MLXModelRuntime.swift`, `AutocompleteRuntimeProbe/main.swift`, `runtime_latency_probe.sh`, `build_mlx_metallib.sh`
- Tests to add/update: build the probe and rerun the default latency report
- Proof required: `./script/runtime_latency_probe.sh 5`
- Risk level: High
- Expected score impact: +5

### Next: Move Runtime Into Helper/XPC

- Objective: Keep MLX memory/crashes out of the menu bar UI process.
- Files likely involved: `Package.swift`, new helper target, app runtime bridge, build/package scripts
- Tests to add/update: helper unavailable, helper crash, restart/backoff, timeout tests
- Proof required: app survives helper kill and suppresses suggestions until helper is ready
- Risk level: High
- Expected score impact: +5 to +8

### Next: Pin Model Revision and Strengthen Install Repair

- Objective: Make model artifact reproducible and repairable.
- Files likely involved: `RuntimeBootstrapPlan.swift`, `ModelAssetInstaller.swift`, `check_model_asset.py`, docs
- Tests to add/update: pinned revision diagnostics, invalid checksum/rollback, offline installed model
- Proof required: model validation report includes revision and local path
- Risk level: Medium
- Expected score impact: +2 to +4

Status: preferred Qwen3.5 4B repo revision is now pinned in code and the developer download script. Installed folders are rejected if Hugging Face metadata does not match the pinned revision, and the local model folder has been repaired to the pinned revision. Remaining work is full file digest verification, resumable repair, and offline repair proof.

### Next: Full Benchmark Matrix

- Objective: Add cold/warm, memory pressure, install repair, model matrix, and power trace scripts or equivalents.
- Files likely involved: `script/`, `Sources/AutocompleteTraceReplay/`, docs
- Tests to add/update: self-tests for each script
- Proof required: artifacts with TTFS, p95, RSS, fallback, invalid/stale, thermal, and battery
- Risk level: Medium
- Expected score impact: +5 to +10

## Codex Execution Goal

Make the local runtime path beta-honest: no mock fallback in app readiness, app-owned Qwen3.5 MLX only, safe suppression/unload under resource pressure, and repeatable proof gates for default-model latency and backend sanity.

## Stop Conditions

This goal is complete when:

- `swift test` passes.
- `./script/check_backend_sanity.sh` passes.
- `./script/check_model_asset.py` passes.
- `./script/model_latency_report.py --default-model-proof` passes from current default-model diagnostics.
- Runtime pressure behavior has automated policy tests and app wiring.
- The scorecard is updated with the final score and remaining proof gaps.
- Changes are committed and pushed.

## Remaining Gaps

- Manual real-app typing proof is still needed to confirm the warmed probe numbers match target-app UI paths.
- Runtime is not isolated into XPC/helper.
- Real memory-pressure, battery, and thermal proof is missing.
- Installed model revision is now verified from local Hugging Face metadata; full file digest verification is still missing.
- Install is not resumable/background-safe.
- Benchmark matrix is not broad enough for 100/100.
- Prompt-app proof is still relevant to beta trust, but it is outside the core local-runtime score.
