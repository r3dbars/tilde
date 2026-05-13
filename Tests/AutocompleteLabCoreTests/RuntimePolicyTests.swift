import Testing
@testable import AutocompleteLabCore

@Suite("Runtime policy")
struct RuntimePolicyTests {
    @Test("Runtime session cache reuses only same field growing continuations")
    func runtimeSessionCacheReusesSameFieldGrowingContinuations() {
        let policy = RuntimeSessionCachePolicy()
        let previous = cacheRequest(text: "Can we make this")
        let current = cacheRequest(text: "Can we make this feel")
        let expectedKey = RuntimeSessionCacheKey(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentityDescription: "field-1",
            fieldKind: .multilineCompose,
            behaviorProfileID: .notes,
            mode: .phraseContinuation
        )

        let decision = policy.decision(previous: previous, current: current)

        #expect(decision == .reuse(expectedKey))
        #expect(decision.traceMetadata["runtimeSessionCacheEligible"] == "true")
        #expect(decision.traceMetadata["runtimeSessionCacheDecision"] == "reuse")
        #expect(decision.traceMetadata["runtimeSessionCacheKey"] == expectedKey.traceDescription)
    }

    @Test("Runtime session cache blocks risky boundary changes")
    func runtimeSessionCacheBlocksRiskyBoundaryChanges() {
        let policy = RuntimeSessionCachePolicy()
        let previous = cacheRequest(text: "Can we make this")

        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this.", mode: .phraseContinuation)
        ) == .reset(.sentenceChanged))

        #expect(policy.decision(
            previous: cacheRequest(text: "Can we make this", mode: .sentenceContinuation),
            current: cacheRequest(text: "Can we make this\n\nNew paragraph", mode: .sentenceContinuation)
        ) == .reset(.paragraphChanged))
    }

    @Test("Runtime session cache allows sentence mode within the same paragraph")
    func runtimeSessionCacheAllowsSentenceModeInSameParagraph() {
        let policy = RuntimeSessionCachePolicy()
        let previous = cacheRequest(text: "Can we make this.", mode: .sentenceContinuation)
        let current = cacheRequest(text: "Can we make this. It should", mode: .sentenceContinuation)

        #expect(policy.decision(previous: previous, current: current).canReuse)
    }

    @Test("Runtime session cache resets on app field mode and edit changes")
    func runtimeSessionCacheResetsOnScopeAndEditChanges() {
        let policy = RuntimeSessionCachePolicy()
        let previous = cacheRequest(text: "Can we make this")

        #expect(policy.decision(
            previous: nil,
            current: previous
        ) == .reset(.noPriorRequest))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this", mode: .wordCompletion)
        ) == .reset(.wordCompletion))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this feel", app: "com.apple.Notes")
        ) == .reset(.appChanged))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this feel", field: "field-2")
        ) == .reset(.fieldChanged))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this feel", profile: .docsProse)
        ) == .reset(.behaviorProfileChanged))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this feel", mode: .sentenceContinuation)
        ) == .reset(.modeChanged))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make", mode: .phraseContinuation)
        ) == .reset(.textDidNotGrow))
        #expect(policy.decision(
            previous: previous,
            current: cacheRequest(text: "Can we make this feel", after: " existing")
        ) == .reset(.textAfterCursorChanged))

        let reset = policy.decision(previous: previous, current: cacheRequest(text: "Can we make"))
        #expect(reset.traceMetadata["runtimeSessionCacheEligible"] == "false")
        #expect(reset.traceMetadata["runtimeSessionCacheDecision"] == "reset")
        #expect(reset.traceMetadata["runtimeSessionCacheResetReason"] == "text-did-not-grow")
    }

    @Test("MVP runtime is embedded and does not allow user-managed servers")
    func mvpRuntimeIsEmbedded() {
        let decision = EmbeddedRuntimeDecision.mvp

        #expect(decision.preferredCandidate == .mlx)
        #expect(decision.fallbackCandidate == .liteRTLM)
        #expect(decision.allowsUserManagedServer == false)
    }

    @Test("Runtime states have short status summaries")
    func runtimeStatesHaveShortStatusSummaries() {
        #expect(CompletionRuntimeCandidate.mlx.displayName == "MLX")
        #expect(CompletionRuntimeCandidate.unavailable.displayName == "unavailable")
        #expect(LocalRuntimeState.warming(candidate: .mlx).statusSummary == "warming MLX")
        #expect(LocalRuntimeState.ready(candidate: .mock).statusSummary == "ready (mock)")
        #expect(LocalRuntimeState.ready(candidate: .mock).isReady)
        #expect(!LocalRuntimeState.unavailable(reason: "not downloaded").isReady)
    }

    @Test("Runtime bootstrap stays unavailable until native MLX and asset are ready")
    func runtimeBootstrapStaysUnavailableUntilNativeReady() {
        let missingPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(missingPlan.activeCandidate == .unavailable)
        #expect(missingPlan.fallbackReason == "missing model asset at /tmp/gemma")
        #expect(!missingPlan.canWarmPreferredRuntime)

        let unlinkedPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )

        #expect(unlinkedPlan.activeCandidate == .unavailable)
        #expect(unlinkedPlan.fallbackReason == "MLX runtime is not linked yet")
        #expect(!unlinkedPlan.canWarmPreferredRuntime)

        let readyPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(readyPlan.activeCandidate == .mlx)
        #expect(readyPlan.fallbackReason == nil)
        #expect(readyPlan.canWarmPreferredRuntime)
    }

    @Test("Runtime readiness summary stays honest when runtime is unavailable")
    func runtimeReadinessSummaryExplainsUnavailableRuntime() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )

        let report = plan.readinessReport(for: .ready(candidate: .mock))

        #expect(report.stage == .runtimeUnavailable)
        #expect(report.summary == "runtime unavailable (MLX)")
        #expect(report.detail == "This build is missing its local model engine. A separate model server will not fix it.")
        #expect(report.action == .none)
        #expect(!report.isReady)
        #expect(!report.allowsSuggestions)
        #expect(plan.readinessSummary(for: .ready(candidate: .mock)) == report.summary)
    }

    @Test("Runtime readiness report separates download and repair states")
    func runtimeReadinessReportSeparatesAssetStates() {
        let missingPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: false
        )
        let missingReport = missingPlan.readinessReport(for: .ready(candidate: .mock))

        #expect(missingReport.stage == .downloadNeeded)
        #expect(missingReport.summary == "download needed (Qwen3.5 4B)")
        #expect(missingReport.detail == "The local model is not installed yet. Expected folder: /tmp/gemma")
        #expect(missingReport.action == .installModel)

        let invalidPlan = RuntimeBootstrapPlan(
            assetState: .invalid(path: "/tmp/gemma", reason: "missing config.json"),
            nativeRuntimeAvailable: false
        )
        let invalidReport = invalidPlan.readinessReport(for: .ready(candidate: .mock))

        #expect(invalidReport.stage == .repairNeeded)
        #expect(invalidReport.summary == "model folder needs repair")
        #expect(invalidReport.detail == "The local model folder is incomplete: missing config.json. Folder: /tmp/gemma")
        #expect(invalidReport.action == .repairModel)

        let unsupportedSourcePlan = RuntimeBootstrapPlan(
            preferredAsset: .qwen35NineBMLX,
            assetState: .missing(expectedPath: "/tmp/qwen9"),
            nativeRuntimeAvailable: false
        )
        #expect(unsupportedSourcePlan.readinessReport(for: .ready(candidate: .mock)).action == .revealModelFolder)
    }

    @Test("Runtime readiness guidance gives stage-specific setup actions")
    func runtimeReadinessGuidanceGivesStageSpecificSetupActions() {
        #expect(RuntimeReadinessAction.cancelModelInstall.displayName == "Cancel Model Install")
        let missing = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                action: .installModel
            )
        )
        let repair = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .repairNeeded,
                summary: "repair needed",
                action: .repairModel
            )
        )
        let warming = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .warming,
                summary: "warming",
                action: .wait
            )
        )
        let failed = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .failed,
                summary: "failed",
                action: .retry
            )
        )
        let ready = RuntimeReadinessGuidance(
            report: RuntimeReadinessReport(
                stage: .ready,
                summary: "ready",
                action: .none,
                isReady: true
            )
        )

        #expect(missing.actionTitle == "Install Local Model")
        #expect(missing.isActionEnabled)
        #expect(missing.message.contains("pinned Hugging Face revision"))
        #expect(missing.message.contains("You do not need Ollama or a model server"))
        #expect(repair.actionTitle == "Repair Local Model")
        #expect(repair.isActionEnabled)
        #expect(repair.message.contains("local model files look incomplete"))
        #expect(warming.actionTitle == "Warming...")
        #expect(!warming.isActionEnabled)
        #expect(failed.actionTitle == "Retry Model")
        #expect(failed.isActionEnabled)
        #expect(ready.actionTitle == "Ready")
        #expect(!ready.isActionEnabled)
    }

    @Test("Runtime readiness report marks native runtime ready")
    func runtimeReadinessReportMarksNativeReady() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        let report = plan.readinessReport(for: .ready(candidate: .mlx))

        #expect(report.stage == .ready)
        #expect(report.summary == "ready (MLX)")
        #expect(report.action == .none)
        #expect(report.isReady)
        #expect(report.allowsSuggestions)
    }

    @Test("Runtime production readiness requires native preferred runtime")
    func runtimeProductionReadinessRequiresNativePreferredRuntime() {
        let readyPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(readyPlan.isProductionReady(runtimeState: .ready(candidate: .mlx)))

        let mockFallbackPlan = RuntimeBootstrapPlan(
            assetState: .missing(expectedPath: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(!mockFallbackPlan.isProductionReady(runtimeState: .ready(candidate: .mock)))

        let warmingPlan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        #expect(!warmingPlan.isProductionReady(runtimeState: .warming(candidate: .mlx)))
    }

    @Test("Runtime readiness blocks suggestions while warming or failed")
    func runtimeReadinessBlocksSuggestionsUntilReady() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )

        #expect(!plan.readinessReport(for: .warming(candidate: .mlx)).allowsSuggestions)
        #expect(!plan.readinessReport(for: .failed(candidate: .mlx, reason: "boom")).allowsSuggestions)
        #expect(plan.readinessReport(for: .ready(candidate: .mlx)).allowsSuggestions)
    }

    @Test("Runtime integrity failures ask the user to repair the model")
    func runtimeIntegrityFailuresAskUserToRepairModel() {
        let plan = RuntimeBootstrapPlan(
            assetState: .available(path: "/tmp/gemma"),
            nativeRuntimeAvailable: true
        )
        let report = plan.readinessReport(
            for: .failed(
                candidate: .mlx,
                reason: "Model asset integrity failed: integrity receipt checksum mismatch"
            )
        )

        #expect(report.stage == .repairNeeded)
        #expect(report.summary == "model folder needs repair")
        #expect(report.action == .repairModel)
        #expect(!report.allowsSuggestions)
    }

    @Test("Qwen3.5 4B asset manifest is MLX first")
    func qwen35FourBAssetManifestIsMLXFirst() {
        let manifest = LocalModelAssetManifest.preferredMLX

        #expect(manifest.model == .qwen35FourB)
        #expect(manifest.runtimeCandidate == .mlx)
        #expect(manifest.cacheDirectoryName.contains("Qwen35FourB"))
        #expect(manifest.source?.repoID == "mlx-community/Qwen3.5-4B-MLX-4bit")
        #expect(manifest.source?.revision == "32f3e8ecf65426fc3306969496342d504bfa13f3")
        #expect(manifest.source?.allowPatterns.contains("*.safetensors") == true)
        #expect(manifest.source?.estimatedBytes == 3_030_000_000)
        #expect(manifest.source?.expectedFiles.count == 10)
        #expect(manifest.source?.expectedFiles.contains {
            $0.path == "model.safetensors"
                && $0.byteCount == 3_034_300_695
                && $0.sha256 == "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db"
        } == true)
        #expect(manifest.requiredFileNames.contains("config.json"))
        #expect(manifest.requiredModelFileExtension == "safetensors")
        #expect(!manifest.requiresVisionLanguageFactory)
    }

    @Test("Source-backed model manifests require immutable revision pins")
    func sourceBackedModelManifestsRequireImmutableRevisionPins() {
        let validSource = LocalModelAssetSource(
            repoID: "mlx-community/Test",
            revision: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            allowPatterns: ["*.safetensors", "config.json"]
        )
        #expect(validSource.immutableRevisionError == nil)

        let mutableSource = LocalModelAssetSource(
            repoID: "mlx-community/Test",
            revision: "main",
            allowPatterns: ["*.safetensors", "config.json"]
        )
        #expect(mutableSource.immutableRevisionError == LocalModelAssetSource.immutableRevisionRequirement)

        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            source: mutableSource,
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/model",
            isDirectory: true,
            childFileNames: ["config.json", "model.safetensors"],
            modelBytes: 8
        ) == .invalid(path: "/tmp/model", reason: LocalModelAssetSource.immutableRevisionRequirement))
    }

    @Test("Named MLX manifests support local model trials")
    func namedMLXManifestsSupportLocalModelTrials() {
        #expect(LocalModelAssetManifest.mlxManifest(named: nil) == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "") == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "qwen35-4b") == .qwen35FourBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: " Qwen3.5-9B ") == .qwen35NineBMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b") == .gemma4E4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-4bit") == .gemma4E4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-it-optiq") == .gemma4E4BItOptiQMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-e4b-it-optiq-4bit") == .gemma4E4BItOptiQMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "gemma-4-26b") == .gemma4A4BMLX)
        #expect(LocalModelAssetManifest.mlxManifest(named: "unknown") == .qwen35FourBMLX)
    }

    @Test("MLX model asset validation expects a Hugging Face directory")
    func mlxAssetValidationExpectsDirectory() {
        let manifest = LocalModelAssetManifest.preferredMLX

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: false,
            childFileNames: [],
            modelBytes: 0
        ) == .invalid(path: "/tmp/gemma", reason: "expected a model directory"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["tokenizer.json", "model.safetensors"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing config.json"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing tokenizer_config.json"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json"],
            modelBytes: 2_000_000
        ) == .invalid(path: "/tmp/gemma", reason: "missing .safetensors weights"))

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/gemma",
            isDirectory: true,
            childFileNames: ["config.json", "tokenizer.json", "tokenizer_config.json", "model.safetensors"],
            modelBytes: 3 * 1024 * 1024 * 1024
        ) == .available(path: "/tmp/gemma"))
    }

    @Test("MLX source model validation rejects mutable revisions")
    func mlxSourceModelValidationRejectsMutableRevisions() {
        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            source: LocalModelAssetSource(
                repoID: "mlx-community/Test",
                revision: "main",
                allowPatterns: ["*.safetensors", "config.json"]
            ),
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        #expect(manifest.validatedDirectoryState(
            path: "/tmp/test-model",
            isDirectory: true,
            childFileNames: ["config.json", "model.safetensors"],
            modelBytes: 7
        ) == .invalid(
            path: "/tmp/test-model",
            reason: LocalModelAssetSource.immutableRevisionRequirement
        ))
    }

    @Test("Benchmark passes when average latency is under target")
    func benchmarkPassesUnderTarget() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .liteRTLM,
            samples: [
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 40, tokenCount: 3),
                CompletionLatencySample(candidate: .liteRTLM, milliseconds: 50, tokenCount: 4)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 45)
        #expect(benchmark.p95LatencyMilliseconds == 50)
        #expect(benchmark.passesAutocompleteTarget())
    }

    @Test("Benchmark fails when average latency is too slow")
    func benchmarkFailsWhenTooSlow() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .mlx,
            samples: [
                CompletionLatencySample(candidate: .mlx, milliseconds: 1_100, tokenCount: 8),
                CompletionLatencySample(candidate: .mlx, milliseconds: 1_000, tokenCount: 8)
            ]
        )

        #expect(!benchmark.passesAutocompleteTarget())
    }

    @Test("Benchmark fails when p95 latency is too slow")
    func benchmarkFailsWhenP95IsTooSlow() {
        let benchmark = CompletionRuntimeBenchmark(
            candidate: .mlx,
            samples: [
                CompletionLatencySample(candidate: .mlx, milliseconds: 10, tokenCount: 1),
                CompletionLatencySample(candidate: .mlx, milliseconds: 10, tokenCount: 1),
                CompletionLatencySample(candidate: .mlx, milliseconds: 90, tokenCount: 1)
            ]
        )

        #expect(benchmark.averageLatencyMilliseconds == 36)
        #expect(benchmark.p95LatencyMilliseconds == 90)
        #expect(!benchmark.passesAutocompleteTarget())
    }

    @Test("Static prompt cache reports hit miss and redacted key")
    func staticPromptCacheReportsHitMissAndRedactedKey() {
        var cache = RuntimeStaticPromptCache(capacity: 2)

        let first = cache.lookup(systemPrompt: "Inline autocomplete. Return one suffix.")
        let second = cache.lookup(systemPrompt: "Inline autocomplete. Return one suffix.")

        #expect(!first.hit)
        #expect(second.hit)
        #expect(first.key == second.key)
        #expect(first.key != "Inline autocomplete. Return one suffix.")
        #expect(second.systemPrompt == first.systemPrompt)
        #expect(second.traceMetadata["runtimeStaticPromptCacheHit"] == "true")
        #expect(second.traceMetadata["runtimeStaticPromptCacheSize"] == "1")
    }

    @Test("Static prompt cache evicts the oldest prompt")
    func staticPromptCacheEvictsOldestPrompt() {
        var cache = RuntimeStaticPromptCache(capacity: 2)

        let first = cache.lookup(systemPrompt: "prompt one")
        _ = cache.lookup(systemPrompt: "prompt two")
        _ = cache.lookup(systemPrompt: "prompt three")
        let repeatedFirst = cache.lookup(systemPrompt: "prompt one")

        #expect(!first.hit)
        #expect(!repeatedFirst.hit)
        #expect(repeatedFirst.traceMetadata["runtimeStaticPromptCacheSize"] == "2")
    }
}

private func cacheRequest(
    text: String,
    after: String = "",
    app: String? = "com.apple.TextEdit",
    field: String? = "field-1",
    kind: AXFieldKind = .multilineCompose,
    profile: AutocompleteBehaviorProfileID? = .notes,
    mode: CompletionRequestMode = .phraseContinuation
) -> CompletionRequest {
    CompletionRequest(
        textBeforeCursor: text,
        textAfterCursor: after,
        appBundleIdentifier: app,
        fieldIdentityDescription: field,
        fieldKind: kind,
        behaviorProfileID: profile,
        mode: mode
    )
}
