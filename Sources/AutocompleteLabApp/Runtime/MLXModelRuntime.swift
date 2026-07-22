import Foundation
import AutocompleteLabCore
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

public final class MLXModelRuntime: ModelRuntime, @unchecked Sendable {
    private let modelDirectoryURL: URL
    private let modelManifest: LocalModelAssetManifest?
    private let fileManager: FileManager
    private let usesVisionLanguageFactory: Bool
    private let promptBuilder: CompletionPromptBuilder
    private let promptTemplate: CompletionPromptTemplate
    private let cleaner: CompletionOutputCleaner
    private let candidateRanker: CompletionCandidateRanker
    private let lengthConfiguration: CompletionLengthConfiguration
    private let retryBudgetPolicy: RetryBudgetPolicy
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-model-runtime")
    private let cancellationCoordinator = RuntimeCancellationCoordinator()

    private var storedState: LocalRuntimeState
    private var integrityValidationCache: ModelAssetIntegrityValidationCache
    private var container: ModelContainer?
    private var staticPromptCache = RuntimeStaticPromptCache()
    private var promptKVCacheOwner: MLXPromptKVCacheOwner
    /// Token count of the chat template's closing markers after the user content.
    /// Static per model+template; measured once by probe (guarded by stateQueue).
    private var cachedTemplateSuffixTokenCount: Int?
    private var generation = 0
    private var warmTaskID = 0
    private var warmTask: (id: Int, task: Task<Void, Error>, gate: MLXRuntimeWarmGate)?

    public convenience init(
        modelDirectoryURL: URL,
        modelManifest: LocalModelAssetManifest? = nil,
        fileManager: FileManager = .default,
        usesVisionLanguageFactory: Bool = false,
        lengthConfiguration: CompletionLengthConfiguration = .default,
        promptBuilder: CompletionPromptBuilder? = nil,
        cleaner: CompletionOutputCleaner? = nil,
        candidateRanker: CompletionCandidateRanker = CompletionCandidateRanker(),
        retryBudgetPolicy: RetryBudgetPolicy = RetryBudgetPolicy()
    ) {
        self.init(
            modelDirectoryURL: modelDirectoryURL,
            modelManifest: modelManifest,
            fileManager: fileManager,
            usesVisionLanguageFactory: usesVisionLanguageFactory,
            lengthConfiguration: lengthConfiguration,
            integrityValidationCache: ModelAssetIntegrityValidationCache(),
            promptBuilder: promptBuilder,
            cleaner: cleaner,
            candidateRanker: candidateRanker,
            retryBudgetPolicy: retryBudgetPolicy,
            promptKVCacheConfiguration: .fromEnvironment()
        )
    }

    init(
        modelDirectoryURL: URL,
        modelManifest: LocalModelAssetManifest? = nil,
        fileManager: FileManager = .default,
        usesVisionLanguageFactory: Bool = false,
        lengthConfiguration: CompletionLengthConfiguration = .default,
        integrityValidationCache: ModelAssetIntegrityValidationCache,
        promptBuilder: CompletionPromptBuilder? = nil,
        cleaner: CompletionOutputCleaner? = nil,
        candidateRanker: CompletionCandidateRanker = CompletionCandidateRanker(),
        retryBudgetPolicy: RetryBudgetPolicy = RetryBudgetPolicy(),
        promptKVCacheConfiguration: MLXPromptKVCacheConfiguration = .fromEnvironment()
    ) {
        self.modelDirectoryURL = modelDirectoryURL
        self.modelManifest = modelManifest
        self.fileManager = fileManager
        self.usesVisionLanguageFactory = usesVisionLanguageFactory
        self.lengthConfiguration = lengthConfiguration
        self.promptBuilder = promptBuilder ?? CompletionPromptBuilder(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.promptTemplate = CompletionPromptTemplate.template(for: modelManifest?.model ?? CompletionModelPolicy.mvp.model)
        self.cleaner = cleaner ?? CompletionOutputCleaner(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.candidateRanker = candidateRanker
        self.retryBudgetPolicy = retryBudgetPolicy
        self.integrityValidationCache = integrityValidationCache
        self.promptKVCacheOwner = MLXPromptKVCacheOwner(configuration: promptKVCacheConfiguration)
        self.storedState = .unavailable(reason: "MLX runtime has not been warmed.")
    }

    public var state: LocalRuntimeState {
        get async {
            stateQueue.sync {
                storedState
            }
        }
    }

    public func warm() async throws {
        let warmTask = warmTaskSnapshot()
        try await warmTask.task.value
    }

    private func warmTaskSnapshot() -> (task: Task<Void, Error>, gate: MLXRuntimeWarmGate) {
        stateQueue.sync {
            if let warmTask {
                return (warmTask.task, warmTask.gate)
            }

            warmTaskID += 1
            let taskID = warmTaskID
            let gate = MLXRuntimeWarmGate()
            let task = Task { [self] in
                do {
                    try await performWarm()
                    finishWarmTask(id: taskID, gate: gate, result: .success(()))
                } catch {
                    finishWarmTask(id: taskID, gate: gate, result: .failure(error))
                    throw error
                }
            }
            warmTask = (taskID, task, gate)
            return (task, gate)
        }
    }

    private func performWarm() async throws {
        let startedAt = Date()
        let modelLoadDirectoryURL = Self.modelLoadDirectoryURL(for: modelDirectoryURL)
        // Keep integrity receipts and diagnostics anchored to the configured install path.
        // Only the upstream MLX enumerator needs the compatibility symlink resolved.
        var integrityValidationCache = stateQueue.sync {
            self.integrityValidationCache
        }
        defer {
            storeIntegrityValidationCache(integrityValidationCache)
        }
        try verifyModelAssetIntegrity(startedAt: startedAt, cache: &integrityValidationCache)
        var didReuseLoadedContainer = false
        let warmGeneration = stateQueue.sync {
            if container != nil {
                storedState = .ready(candidate: .mlx)
                didReuseLoadedContainer = true
                return generation
            }

            generation += 1
            storedState = .warming(candidate: .mlx)
            return generation
        }

        if didReuseLoadedContainer {
            DiagnosticsLog.shared.record(
                "mlx-model-load-reused",
                metadata: [
                    "assetDirectory": modelDirectoryURL.path,
                    "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                    "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
                ]
            )
            return
        }

        DiagnosticsLog.shared.record(
            "mlx-model-load-start",
            metadata: [
                "assetDirectory": modelDirectoryURL.path,
                "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
            ]
        )

        let loadedContainer: ModelContainer
        do {
            if usesVisionLanguageFactory {
                loadedContainer = try await VLMModelFactory.shared.loadContainer(
                    from: modelLoadDirectoryURL,
                    using: #huggingFaceTokenizerLoader()
                )
            } else {
                loadedContainer = try await LLMModelFactory.shared.loadContainer(
                    from: modelLoadDirectoryURL,
                    using: #huggingFaceTokenizerLoader()
                )
            }
        } catch is CancellationError {
            stateQueue.sync {
                if warmGeneration == generation {
                    storedState = .unavailable(reason: "MLX runtime was canceled.")
                }
            }
            DiagnosticsLog.shared.record(
                "mlx-model-load-cancelled",
                metadata: [
                    "assetDirectory": modelDirectoryURL.path,
                    "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                    "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
                ]
            )
            throw CancellationError()
        } catch {
            stateQueue.sync {
                if warmGeneration == generation {
                    container = nil
                    staticPromptCache = RuntimeStaticPromptCache()
                    storedState = .failed(candidate: .mlx, reason: error.localizedDescription)
                    promptKVCacheOwner.clear()
                }
            }
            DiagnosticsLog.shared.record(
                "mlx-model-load-failed",
                metadata: [
                    "assetDirectory": modelDirectoryURL.path,
                    "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                    "reason": error.localizedDescription,
                    "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
                ]
            )
            throw error
        }

        try Task.checkCancellation()
        try verifyModelAssetIntegrity(startedAt: startedAt, cache: &integrityValidationCache)
        try Task.checkCancellation()

        let wasCancelled = stateQueue.sync {
            warmGeneration != generation
        }

        guard !wasCancelled else {
            DiagnosticsLog.shared.record(
                "mlx-model-load-cancelled",
                metadata: [
                    "assetDirectory": modelDirectoryURL.path,
                    "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                    "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
                ]
            )
            throw CancellationError()
        }

        await warmupCompletionGraph(container: loadedContainer)
        try Task.checkCancellation()

        stateQueue.sync {
            container = loadedContainer
            storedState = .ready(candidate: .mlx)
        }
        DiagnosticsLog.shared.record(
            "mlx-model-load-succeeded",
            metadata: [
                "assetDirectory": modelDirectoryURL.path,
                "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
            ]
        )
    }

    static func modelLoadDirectoryURL(for modelDirectoryURL: URL) -> URL {
        modelDirectoryURL.resolvingSymlinksInPath()
    }

    /// Runs a tiny throwaway generation right after the model loads so the
    /// MLX/Metal compute graph is compiled during background warm instead of on
    /// the user's first real keystroke. This is best-effort: any failure is
    /// recorded and ignored so it can never block readiness. Set
    /// `AUTOCOMPLETE_LAB_MLX_WARMUP` to an off value to skip it.
    private func warmupCompletionGraph(container: ModelContainer) async {
        guard Self.warmupGenerationEnabled() else {
            return
        }

        let startedAt = Date()
        do {
            let session = ChatSession(
                container,
                instructions: "",
                generateParameters: GenerateParameters(maxTokens: 1, temperature: 0),
                additionalContext: ["enable_thinking": false]
            )
            for try await _ in session.streamResponse(to: "Warm up.") {
                break
            }
            DiagnosticsLog.shared.record(
                "mlx-model-warmup-succeeded",
                metadata: [
                    "warmupMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                    "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
                ]
            )
        } catch is CancellationError {
            DiagnosticsLog.shared.record("mlx-model-warmup-cancelled", metadata: [:])
        } catch {
            DiagnosticsLog.shared.record(
                "mlx-model-warmup-skipped",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    static func warmupGenerationEnabled(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let value = environment["AUTOCOMPLETE_LAB_MLX_WARMUP"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return true
        }

        return !["0", "false", "no", "off"].contains(value)
    }

    private func verifyModelAssetIntegrity(
        startedAt: Date,
        cache: inout ModelAssetIntegrityValidationCache
    ) throws {
        guard let modelManifest else {
            return
        }

        guard let integrityError = cache.validate(
            manifest: modelManifest,
            modelDirectoryURL: modelDirectoryURL,
            fileManager: fileManager
        ) else {
            return
        }

        let error = MLXModelRuntimeError.modelAssetIntegrityFailed(reason: integrityError)
        let failureDescription = error.errorDescription ?? "Model asset integrity failed."
        stateQueue.sync {
            generation += 1
            container = nil
            staticPromptCache = RuntimeStaticPromptCache()
            promptKVCacheOwner.clear()
            storedState = .failed(candidate: .mlx, reason: failureDescription)
        }
        DiagnosticsLog.shared.record(
            "mlx-model-integrity-failed",
            metadata: [
                "assetDirectory": modelDirectoryURL.path,
                "integrityCode": Self.integrityFailureCode(for: integrityError),
                "integrityFile": Self.integrityFailureFile(for: integrityError) ?? "unknown",
                "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                "reason": integrityError,
                "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
            ]
        )
        throw error
    }

    static func integrityFailureCode(for reason: String) -> String {
        if reason.contains("checksum mismatch") {
            return "checksum-mismatch"
        }
        if reason.contains("byte count mismatch") {
            return "byte-count-mismatch"
        }
        if reason.contains("missing expected file") ||
            reason.contains("references missing model file") ||
            reason.contains("missing integrity receipt") {
            return "missing-file"
        }
        if reason.contains("unexpected file") ||
            reason.contains("not in integrity receipt") {
            return "unexpected-file"
        }
        if reason.contains("unsafe file path") {
            return "unsafe-path"
        }
        if reason.contains("duplicate file") {
            return "duplicate-file"
        }
        if reason.contains("model mismatch") ||
            reason.contains("repo mismatch") ||
            reason.contains("revision mismatch") {
            return "receipt-mismatch"
        }
        if reason.contains("source revision") ||
            reason.contains("commit SHA") {
            return "mutable-revision"
        }
        if reason.contains("invalid integrity receipt") ||
            reason.contains("unsupported integrity receipt schema") {
            return "invalid-receipt"
        }
        return "unknown"
    }

    static func integrityFailureFile(for reason: String) -> String? {
        let markers = [
            " for ",
            " file ",
            " checksum ",
            " references missing model file: ",
            "not in integrity receipt: "
        ]
        for marker in markers {
            guard let range = reason.range(of: marker) else {
                continue
            }
            let suffix = reason[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,:;"))
            if !suffix.isEmpty && !suffix.contains(" ") {
                return String(suffix)
            }
        }
        return nil
    }

    public func cancel() {
        let taskToCancel = stateQueue.sync {
            let task = warmTask?.task
            warmTask = nil
            generation += 1
            container = nil
            staticPromptCache = RuntimeStaticPromptCache()
            promptKVCacheOwner.clear()
            storedState = .unavailable(reason: "MLX runtime was canceled.")
            return task
        }
        cancellationCoordinator.cancelAll()
        taskToCancel?.cancel()
    }

    public func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await complete(request, onPartialSuggestion: { _ in })
    }

    public func complete(
        _ request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        try await cancellationCoordinator.withRegisteredTask { [self] cancellationEpoch in
            try await performCompletion(
                request,
                cancellationEpoch: cancellationEpoch,
                onPartialSuggestion: onPartialSuggestion
            )
        }
    }

    private func performCompletion(
        _ request: CompletionRequest,
        cancellationEpoch: Int,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let container = try await readyContainer()
        try cancellationCoordinator.check(epoch: cancellationEpoch)

        let startedAt = Date()
        var prompt = promptBuilder.prompt(for: request)
        var formattedPrompt = prompt.formatted(using: promptTemplate)
        let promptBuiltAt = Date()
        let requestCleaner = cleaner(for: request)
        let requestMaxGeneratedTokens = maxGeneratedTokens(for: request)
        var generation = try await generateRawCompletion(
            container: container,
            prompt: formattedPrompt,
            request: request,
            requestCleaner: requestCleaner,
            requestMaxGeneratedTokens: requestMaxGeneratedTokens,
            cancellationEpoch: cancellationEpoch,
            onPartialSuggestion: onPartialSuggestion
        )
        try cancellationCoordinator.check(epoch: cancellationEpoch)

        var rawOutput = generation.rawOutput
        var cleaningResult = requestCleaner.cleanCandidatesWithReasons(
            generation.rawOutput,
            after: request.textBeforeCursor,
            mode: request.mode,
            limit: 3
        )
        var cleanedCandidates = cleaningResult.suggestions
        var candidateSelection = candidateRanker.selection(
            cleanedCandidates,
            mode: request.mode,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )
        var retryAttempted = false
        var retryUsed = false
        var retrySkippedForBudget = false
        var retryElapsedMilliseconds: Int?
        var wordCompletionFallbackUsed = false
        var wordCompletionFallbackSource: String?

        let retryPrompt = Self.retryPromptForEmptyWordCompletionCandidate(
            request: request,
            cleanedCandidates: cleanedCandidates,
            candidateSelection: candidateSelection
        ) ?? Self.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: cleanedCandidates,
            candidateSelection: candidateSelection,
            effectiveMaxVisibleWords: effectiveMaxVisibleWords(for: request)
        )
        if let retryPrompt {
            let elapsedMilliseconds = Self.milliseconds(from: startedAt, to: Date())
            retryElapsedMilliseconds = elapsedMilliseconds
            if !retryBudgetPolicy.shouldRetry(after: elapsedMilliseconds) {
                retrySkippedForBudget = true
                DiagnosticsLog.shared.record(
                    "mlx-completion-retry-skipped-budget",
                    metadata: [
                        "app": request.appBundleIdentifier ?? "unknown",
                        "mode": request.mode.rawValue,
                        "elapsedMilliseconds": String(elapsedMilliseconds),
                        "remainingBudgetMilliseconds": String(
                            retryBudgetPolicy.remainingBudgetMilliseconds(after: elapsedMilliseconds)
                        ),
                        "minimumRetryBudgetMilliseconds": String(
                            retryBudgetPolicy.minimumRetryBudgetMilliseconds
                        )
                    ]
                )
            } else {
                retryAttempted = true
                DiagnosticsLog.shared.record(
                    "mlx-completion-retry-scheduled",
                    metadata: [
                        "app": request.appBundleIdentifier ?? "unknown",
                        "mode": request.mode.rawValue,
                        "maxVisibleWords": String(effectiveMaxVisibleWords(for: request)),
                        "candidateTopScore": Self.formattedCandidateScore(candidateSelection.rankedCandidates.first?.score),
                        "candidateWords": String(candidateSelection.rankedCandidates.first?.suggestion.visibleWordCount ?? 0)
                    ]
                )

                let retryGeneration = try await generateRawCompletion(
                    container: container,
                    prompt: retryPrompt.formatted(using: promptTemplate),
                    request: request,
                    requestCleaner: requestCleaner,
                    requestMaxGeneratedTokens: requestMaxGeneratedTokens,
                    cancellationEpoch: cancellationEpoch,
                    onPartialSuggestion: onPartialSuggestion
                )
                try cancellationCoordinator.check(epoch: cancellationEpoch)

                let retryCleaningResult = requestCleaner.cleanCandidatesWithReasons(
                    retryGeneration.rawOutput,
                    after: request.textBeforeCursor,
                    mode: request.mode,
                    limit: 3
                )
                let retryCandidates = retryCleaningResult.suggestions
                let retrySelection = candidateRanker.selection(
                    retryCandidates,
                    mode: request.mode,
                    textBeforeCursor: request.textBeforeCursor,
                    behaviorProfileID: request.behaviorProfile.id
                )

                if retrySelection.suggestion != nil ||
                    (retrySelection.rankedCandidates.first?.score ?? 0) > (candidateSelection.rankedCandidates.first?.score ?? 0) {
                    retryUsed = true
                    prompt = retryPrompt
                    formattedPrompt = retryPrompt.formatted(using: promptTemplate)
                    generation = retryGeneration
                    rawOutput = retryGeneration.rawOutput
                    cleaningResult = retryCleaningResult
                    cleanedCandidates = retryCandidates
                    candidateSelection = retrySelection
                }
            }
        }

        if candidateSelection.suggestion == nil,
           let fallbackSelection = Self.localWordCompletionFallbackSelection(for: request),
           let fallbackSuggestion = fallbackSelection.suggestion {
            wordCompletionFallbackUsed = true
            wordCompletionFallbackSource = fallbackSelection.selectionSource
            cleanedCandidates = [fallbackSuggestion]
            candidateSelection = candidateRanker.selection(
                cleanedCandidates,
                mode: request.mode == .phraseContinuation ? .wordCompletion : request.mode,
                textBeforeCursor: request.textBeforeCursor,
                behaviorProfileID: request.behaviorProfile.id
            )
            DiagnosticsLog.shared.record(
                "mlx-word-completion-fallback-used",
                metadata: [
                    "app": request.appBundleIdentifier ?? "unknown",
                    "source": fallbackSelection.selectionSource,
                    "candidateCount": String(fallbackSelection.candidateCount),
                    "mode": request.mode.rawValue
                ]
            )
        }

        let cleanedSuggestion = candidateSelection.suggestion
        let candidateTopScore = candidateSelection.rankedCandidates.first?.score
        let cleanedAt = Date()
        let totalMilliseconds = Self.milliseconds(from: startedAt, to: cleanedAt)
        var timingMetadata: [String: String] = [:]
        timingMetadata["app"] = request.appBundleIdentifier ?? "unknown"
        timingMetadata["mode"] = request.mode.rawValue
        timingMetadata["fieldKind"] = request.fieldKind.rawValue
        timingMetadata["behaviorProfile"] = request.behaviorProfile.id.rawValue
        timingMetadata["promptMilliseconds"] = String(Self.milliseconds(from: startedAt, to: promptBuiltAt))
        timingMetadata["sessionMilliseconds"] = String(generation.sessionMilliseconds)
        timingMetadata["firstChunkMilliseconds"] = generation.firstChunkMilliseconds.map(String.init) ?? "none"
        timingMetadata["generationMilliseconds"] = String(generation.generationMilliseconds)
        timingMetadata["cleanupMilliseconds"] = String(Self.milliseconds(from: generation.generatedAt, to: cleanedAt))
        timingMetadata["totalMilliseconds"] = String(totalMilliseconds)
        timingMetadata["maxTokens"] = String(requestMaxGeneratedTokens)
        timingMetadata["maxVisibleWords"] = String(effectiveMaxVisibleWords(for: request))
        timingMetadata["promptTemplate"] = formattedPrompt.templateIdentifier
        // Prompt-size proxies for prefill cost. On the default ChatSession path, prefill +
        // first-token decode are fused inside `firstChunkMilliseconds` (streamResponse is
        // opaque), so correlate first-chunk latency against these counts to estimate prefill.
        timingMetadata["systemPromptChars"] = String(formattedPrompt.system.count)
        timingMetadata["userPromptChars"] = String(formattedPrompt.user.count)
        timingMetadata["rawChars"] = String(rawOutput.count)
        timingMetadata["cleanedCandidateCount"] = String(cleanedCandidates.count)
        timingMetadata.merge(cleaningResult.traceMetadata) { current, _ in current }
        timingMetadata["candidateTopScore"] = Self.formattedCandidateScore(candidateTopScore)
        timingMetadata["candidateScoreMargin"] = Self.formattedCandidateScore(candidateSelection.scoreMargin)
        timingMetadata["candidateSuppressionReason"] = candidateSelection.suppressionReason?.rawValue ?? "none"
        timingMetadata["cleanedChars"] = String(cleanedSuggestion?.visibleText.count ?? 0)
        timingMetadata["retryAttempted"] = String(retryAttempted)
        timingMetadata["retryUsed"] = String(retryUsed)
        timingMetadata["retrySkippedForBudget"] = String(retrySkippedForBudget)
        timingMetadata["retryElapsedMilliseconds"] = retryElapsedMilliseconds.map(String.init) ?? "none"
        timingMetadata["wordCompletionFallbackUsed"] = String(wordCompletionFallbackUsed)
        if let wordCompletionFallbackSource {
            timingMetadata["wordCompletionFallbackSource"] = wordCompletionFallbackSource
        }
        timingMetadata.merge(generation.promptCacheTraceMetadata) { current, _ in current }

        DiagnosticsLog.shared.record(
            "mlx-completion-timing",
            metadata: timingMetadata
        )
        RawAutocompleteTraceLog.shared.recordModelResult(
            request: request,
            prompt: CompletionPrompt(system: formattedPrompt.system, user: formattedPrompt.user),
            rawOutput: rawOutput,
            cleanedSuggestion: cleanedSuggestion,
            cleanedCandidateCount: cleanedCandidates.count,
            candidateTopScore: candidateTopScore,
            candidateScoreMargin: candidateSelection.scoreMargin,
            candidateSuppressionReason: candidateSelection.suppressionReason?.rawValue,
            suggestionID: request.suggestionID,
            latencyMilliseconds: totalMilliseconds,
            firstTokenLatencyMilliseconds: generation.firstChunkMilliseconds,
            extraMetadata: cleaningResult.traceMetadata.merging([
                "retryAttempted": String(retryAttempted),
                "retryUsed": String(retryUsed),
                "retrySkippedForBudget": String(retrySkippedForBudget),
                "retryElapsedMilliseconds": retryElapsedMilliseconds.map(String.init) ?? "none",
                "promptTemplate": formattedPrompt.templateIdentifier,
                "rawPromptChars": String(formattedPrompt.rawPrompt?.count ?? 0),
                "wordCompletionFallbackUsed": String(wordCompletionFallbackUsed),
                "wordCompletionFallbackSource": wordCompletionFallbackSource ?? "none"
            ]) { current, _ in current }
        )

        try cancellationCoordinator.check(epoch: cancellationEpoch)
        return cleanedSuggestion
    }

    private struct RawCompletionGeneration {
        let rawOutput: String
        let firstChunkMilliseconds: Int?
        let sessionMilliseconds: Int
        let generationMilliseconds: Int
        let generatedAt: Date
        let promptCacheTraceMetadata: [String: String]
    }

    private func generateRawCompletion(
        container: ModelContainer,
        prompt: FormattedCompletionPrompt,
        request: CompletionRequest,
        requestCleaner: CompletionOutputCleaner,
        requestMaxGeneratedTokens: Int,
        cancellationEpoch: Int,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> RawCompletionGeneration {
        let promptCacheLookup = cachedStaticPrompt(systemPrompt: prompt.system)
        let promptKVCacheEnabled = stateQueue.sync {
            promptKVCacheOwner.configuration.isEnabled
        }

        guard promptKVCacheEnabled, !usesVisionLanguageFactory else {
            let bypassReason: MLXPromptKVCacheMissReason = usesVisionLanguageFactory
                ? .visionLanguageRuntime
                : .envFlagOff
            let promptCacheTraceMetadata = promptCacheLookup.traceMetadata.merging(
                stateQueue.sync { promptKVCacheOwner.bypassMetadata(reason: bypassReason) }
            ) { current, _ in current }
            return try await generateRawCompletionWithChatSession(
                container: container,
                prompt: prompt,
                request: request,
                requestCleaner: requestCleaner,
                requestMaxGeneratedTokens: requestMaxGeneratedTokens,
                cancellationEpoch: cancellationEpoch,
                onPartialSuggestion: onPartialSuggestion,
                promptCacheTraceMetadata: promptCacheTraceMetadata
            )
        }

        return try await generateRawCompletionWithPromptKVCache(
            container: container,
            prompt: prompt,
            request: request,
            requestCleaner: requestCleaner,
            requestMaxGeneratedTokens: requestMaxGeneratedTokens,
            cancellationEpoch: cancellationEpoch,
            onPartialSuggestion: onPartialSuggestion,
            promptCacheLookup: promptCacheLookup
        )
    }

    private func generateRawCompletionWithChatSession(
        container: ModelContainer,
        prompt: FormattedCompletionPrompt,
        request: CompletionRequest,
        requestCleaner: CompletionOutputCleaner,
        requestMaxGeneratedTokens: Int,
        cancellationEpoch: Int,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void,
        promptCacheTraceMetadata: [String: String]
    ) async throws -> RawCompletionGeneration {
        let sessionStartedAt = Date()
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: GenerateParameters(
                maxTokens: requestMaxGeneratedTokens,
                temperature: 0
            ),
            additionalContext: ["enable_thinking": false]
        )

        let sessionBuiltAt = Date()
        var rawOutput = ""
        var firstChunkMilliseconds: Int?
        var lastPartialVisibleText = ""
        let stream = session.streamResponse(to: prompt.user)
        do {
            for try await chunk in stream {
                try cancellationCoordinator.check(epoch: cancellationEpoch)

                if firstChunkMilliseconds == nil {
                    firstChunkMilliseconds = Self.milliseconds(from: sessionBuiltAt, to: Date())
                }

                rawOutput += chunk

                let partialSuggestion = requestCleaner.clean(
                    rawOutput,
                    after: request.textBeforeCursor,
                    mode: request.mode
                )

                if let partialSuggestion,
                   !partialSuggestion.isEmpty,
                   partialSuggestion.visibleText != lastPartialVisibleText {
                    try cancellationCoordinator.check(epoch: cancellationEpoch)
                    lastPartialVisibleText = partialSuggestion.visibleText
                    onPartialSuggestion(partialSuggestion)
                }

                if shouldStopEarly(partialSuggestion, rawOutput: rawOutput, request: request) {
                    break
                }
            }
        } catch is CancellationError {
            DiagnosticsLog.shared.record(
                "mlx-completion-cancelled",
                metadata: [
                    "app": request.appBundleIdentifier ?? "unknown",
                    "mode": request.mode.rawValue,
                    "generationMilliseconds": String(Self.milliseconds(from: sessionBuiltAt, to: Date())),
                    "rawChars": String(rawOutput.count)
                ]
            )
            throw CancellationError()
        }

        let generatedAt = Date()
        return RawCompletionGeneration(
            rawOutput: rawOutput,
            firstChunkMilliseconds: firstChunkMilliseconds,
            sessionMilliseconds: Self.milliseconds(from: sessionStartedAt, to: sessionBuiltAt),
            generationMilliseconds: Self.milliseconds(from: sessionBuiltAt, to: generatedAt),
            generatedAt: generatedAt,
            promptCacheTraceMetadata: promptCacheTraceMetadata
        )
    }

    /// Number of trailing template tokens after the user content (turn-close +
    /// assistant-open markers). Probe: tokenize the same chat with the user text
    /// extended; the shared token prefix ends where the user content ends, so the
    /// remainder of the real prompt is the template suffix. The estimate can only
    /// overshoot (by a merged boundary token), which merely re-prefills an extra
    /// token per request — it can never under-count and reintroduce trimming.
    private func templateSuffixTokenCount(
        container: ModelContainer,
        systemPrompt: String,
        userPrompt: String,
        fullPromptTokens: [Int]
    ) async -> Int {
        if let cached = stateQueue.sync(execute: { cachedTemplateSuffixTokenCount }) {
            return cached
        }
        guard let probeInput = try? await container.prepare(input: UserInput(
            chat: [
                .system(systemPrompt),
                .user(userPrompt + " qx")
            ],
            additionalContext: ["enable_thinking": false]
        )) else {
            return 0
        }
        let probeTokens = probeInput.text.tokens.asArray(Int.self)
        var shared = 0
        while shared < fullPromptTokens.count,
              shared < probeTokens.count,
              fullPromptTokens[shared] == probeTokens[shared] {
            shared += 1
        }
        let suffix = fullPromptTokens.count - shared
        let usable = suffix > 0 && suffix < fullPromptTokens.count ? suffix : 0
        stateQueue.sync { cachedTemplateSuffixTokenCount = usable }
        return usable
    }

    private func generateRawCompletionWithPromptKVCache(
        container: ModelContainer,
        prompt: FormattedCompletionPrompt,
        request: CompletionRequest,
        requestCleaner: CompletionOutputCleaner,
        requestMaxGeneratedTokens: Int,
        cancellationEpoch: Int,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void,
        promptCacheLookup: RuntimeStaticPromptCacheLookup
    ) async throws -> RawCompletionGeneration {
        let sessionStartedAt = Date()
        let generateParameters = GenerateParameters(
            maxTokens: requestMaxGeneratedTokens,
            temperature: 0
        )
        let preparedInput = try await container.prepare(input: UserInput(
            chat: [
                .system(promptCacheLookup.systemPrompt),
                .user(prompt.user)
            ],
            additionalContext: ["enable_thinking": false]
        ))
        let preparedAt = Date()
        let promptTokens = preparedInput.text.tokens.asArray(Int.self)

        // The chat template closes the user turn and opens the assistant turn AFTER
        // the typed context (the prompt itself is context-terminal since prompt
        // style v12). Cache the PREFIX only — everything before those closing
        // markers — so consecutive keystrokes strictly extend the stored tokens and
        // reuse never needs trimming (hybrid caches like Qwen3.5's recurrent layers
        // are appendable but not trimmable). The short static suffix is re-prefilled
        // every request.
        let templateSuffixCount = await templateSuffixTokenCount(
            container: container,
            systemPrompt: promptCacheLookup.systemPrompt,
            userPrompt: prompt.user,
            fullPromptTokens: promptTokens
        )
        // Keep the last couple of context tokens OUT of the stored prefix: the
        // trailing space/partial word re-tokenizes once the next word arrives
        // ("outputs " + "feel" → the space merges into "Ġfeel"), and a stored
        // cache ending on such a volatile token forces an untrimmable miss.
        // Ending the stored state 2 tokens early costs 2 tokens of re-prefill.
        let boundaryMargin = 2
        let cacheableCount = promptTokens.count - templateSuffixCount - boundaryMargin
        let splitIsUsable = templateSuffixCount > 0 && cacheableCount > 0
        let prefixTokens = splitIsUsable ? Array(promptTokens.prefix(cacheableCount)) : promptTokens
        let suffixTokens = splitIsUsable ? Array(promptTokens.dropFirst(cacheableCount)) : []

        let lookup = stateQueue.sync {
            promptKVCacheOwner.lookup(
                request: request,
                promptTokens: prefixTokens,
                systemPrompt: promptCacheLookup.systemPrompt,
                modelRevision: promptKVCacheModelRevision,
                promptStyleIdentifier: CompletionPromptBuilder.promptStyleIdentifier
            )
        }
        var promptCacheTraceMetadata = promptCacheLookup.traceMetadata.merging(lookup.traceMetadata) { current, _ in current }
        // Decompose the otherwise-lumped session setup so prefill cost is attributable on both
        // cache hit and miss: tokenization (container.prepare) vs cache/iterator setup.
        promptCacheTraceMetadata["preparePromptMilliseconds"] = String(Self.milliseconds(from: sessionStartedAt, to: preparedAt))
        promptCacheTraceMetadata["promptTokenCount"] = String(promptTokens.count)
        promptCacheTraceMetadata["appendTokenCount"] = String(lookup.appendTokens.count)
        promptCacheTraceMetadata["templateSuffixTokenCount"] = String(suffixTokens.count)

        let modelBox = await container.perform { context in
            MLXRuntimeSendableBox(context.model)
        }
        let model = modelBox.consume()
        let modelConfiguration = await container.configuration
        let tokenizer = await container.tokenizer
        let workingCache = lookup.reusableCache ?? model.newCache(parameters: generateParameters)

        let iterator: TokenIterator
        if suffixTokens.isEmpty {
            // Fallback (no usable split): previous single-stage behavior.
            let generationInput = lookup.decision.isHit
                ? LMInput(tokens: MLXArray(lookup.appendTokens))
                : preparedInput
            iterator = try TokenIterator(
                input: generationInput,
                model: model,
                cache: workingCache,
                parameters: generateParameters
            )
            let storeMetadata = stateQueue.sync {
                promptKVCacheOwner.storePreparedPromptCache(
                    workingCache,
                    key: lookup.currentKey,
                    request: request,
                    promptTokens: lookup.promptTokens
                )
            }
            promptCacheTraceMetadata.merge(storeMetadata) { current, _ in current }
        } else {
            // Stage 1: bring the cache to end-of-prefix state (append the typed
            // delta on a hit; prefill the whole prefix on a miss), then store a
            // copy — the state the NEXT keystroke extends without trimming.
            // (TokenIterator prefills its input during init; the sampled token is
            // discarded and never enters the cache.)
            let prefixInput = lookup.decision.isHit
                ? LMInput(tokens: MLXArray(lookup.appendTokens))
                : LMInput(tokens: MLXArray(prefixTokens))
            _ = try TokenIterator(
                input: prefixInput,
                model: model,
                cache: workingCache,
                parameters: generateParameters
            )
            let storeMetadata = stateQueue.sync {
                promptKVCacheOwner.storePreparedPromptCache(
                    workingCache,
                    key: lookup.currentKey,
                    request: request,
                    promptTokens: lookup.promptTokens
                )
            }
            promptCacheTraceMetadata.merge(storeMetadata) { current, _ in current }

            // Stage 2: append the template's closing markers and generate.
            iterator = try TokenIterator(
                input: LMInput(tokens: MLXArray(suffixTokens)),
                model: model,
                cache: workingCache,
                parameters: generateParameters
            )
        }

        let sessionBuiltAt = Date()
        promptCacheTraceMetadata["cacheSetupMilliseconds"] = String(Self.milliseconds(from: preparedAt, to: sessionBuiltAt))

        var rawOutput = ""
        var firstChunkMilliseconds: Int?
        var lastPartialVisibleText = ""
        let (stream, task) = generateTask(
            promptTokenCount: lookup.promptTokens.count,
            modelConfiguration: modelConfiguration,
            tokenizer: tokenizer,
            iterator: iterator
        )

        var stoppedEarly = false
        do {
            for await item in stream {
                try cancellationCoordinator.check(epoch: cancellationEpoch)

                guard case let .chunk(chunk) = item else {
                    continue
                }

                if firstChunkMilliseconds == nil {
                    firstChunkMilliseconds = Self.milliseconds(from: sessionBuiltAt, to: Date())
                }

                rawOutput += chunk

                let partialSuggestion = requestCleaner.clean(
                    rawOutput,
                    after: request.textBeforeCursor,
                    mode: request.mode
                )

                if let partialSuggestion,
                   !partialSuggestion.isEmpty,
                   partialSuggestion.visibleText != lastPartialVisibleText {
                    try cancellationCoordinator.check(epoch: cancellationEpoch)
                    lastPartialVisibleText = partialSuggestion.visibleText
                    onPartialSuggestion(partialSuggestion)
                }

                if shouldStopEarly(partialSuggestion, rawOutput: rawOutput, request: request) {
                    stoppedEarly = true
                    break
                }
            }
        } catch is CancellationError {
            task.cancel()
            await task.value
            DiagnosticsLog.shared.record(
                "mlx-completion-cancelled",
                metadata: [
                    "app": request.appBundleIdentifier ?? "unknown",
                    "mode": request.mode.rawValue,
                    "generationMilliseconds": String(Self.milliseconds(from: sessionBuiltAt, to: Date())),
                    "rawChars": String(rawOutput.count)
                ]
            )
            throw CancellationError()
        } catch {
            task.cancel()
            await task.value
            throw error
        }
        if stoppedEarly {
            task.cancel()
        }
        await task.value

        let latencyMetadata = stateQueue.sync {
            promptKVCacheOwner.recordWarmAppendFirstToken(
                milliseconds: firstChunkMilliseconds,
                wasHit: lookup.decision.isHit
            )
        }
        promptCacheTraceMetadata.merge(latencyMetadata) { current, _ in current }

        let generatedAt = Date()
        return RawCompletionGeneration(
            rawOutput: rawOutput,
            firstChunkMilliseconds: firstChunkMilliseconds,
            sessionMilliseconds: Self.milliseconds(from: sessionStartedAt, to: sessionBuiltAt),
            generationMilliseconds: Self.milliseconds(from: sessionBuiltAt, to: generatedAt),
            generatedAt: generatedAt,
            promptCacheTraceMetadata: promptCacheTraceMetadata
        )
    }

    private func shouldStopEarly(
        _ suggestion: CompletionSuggestion?,
        rawOutput: String,
        request: CompletionRequest
    ) -> Bool {
        Self.shouldStopEarly(
            suggestion,
            rawOutput: rawOutput,
            mode: request.mode,
            effectiveMaxVisibleWords: effectiveMaxVisibleWords(for: request)
        )
    }

    static func retryPromptForEmptyWordCompletionCandidate(
        request: CompletionRequest,
        cleanedCandidates: [CompletionSuggestion],
        candidateSelection: CompletionCandidateSelection
    ) -> CompletionPrompt? {
        guard request.mode == .wordCompletion,
              cleanedCandidates.isEmpty,
              candidateSelection.suppressionReason == .noCandidates,
              let fragment = trailingWordFragment(in: request.textBeforeCursor),
              fragment.count >= 3,
              fragment.allSatisfy(\.isLetter)
        else {
            return nil
        }

        let context = String(request.textBeforeCursor.suffix(220))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else {
            return nil
        }

        let system = """
        Inline word completion retry.
        The previous answer did not produce a usable suffix.
        Return only the missing suffix for the current partially typed word.
        The suffix must be letters only: no spaces, punctuation, quotes, labels, or explanations.
        Do not repeat the partial word or the Before cursor text.
        If the suffix would complete the wrong word, return \(CompletionPromptBuilder.noSuggestionToken).
        Example Before cursor: The privacy note should stay redac
        Example suffix: ted
        Example Before cursor: The setting should be configu
        Example suffix: rable
        """
        let user = """
        Before cursor:
        \(context)

        Suffix only, letters only, or \(CompletionPromptBuilder.noSuggestionToken):
        """
        return CompletionPrompt(system: system, user: user)
    }

    static func localWordCompletionFallbackSelection(for request: CompletionRequest) -> WordCompletionCandidateSelection? {
        guard request.textAfterCursor.first?.isLetter != true,
              request.mode == .wordCompletion || shouldUseWordCompletionFallbackForPhraseContinuation(request) else {
            return nil
        }

        let selection = WordCompletionCandidateRanker(staticWords: wordCompletionFallbackWords).selection(
            for: request.textBeforeCursor,
            recentWords: request.visiblePageContext?.completionCandidateWords ?? []
        )
        guard selection.suggestion != nil else {
            return nil
        }

        return selection
    }

    private static func shouldUseWordCompletionFallbackForPhraseContinuation(_ request: CompletionRequest) -> Bool {
        guard request.mode == .phraseContinuation,
              let fragment = trailingWordFragment(in: request.textBeforeCursor),
              fragment.count >= 3,
              fragment.allSatisfy(\.isLetter) else {
            return false
        }

        return true
    }

    static func retryPromptForShortHighWordCandidate(
        request: CompletionRequest,
        cleanedCandidates: [CompletionSuggestion],
        candidateSelection: CompletionCandidateSelection,
        effectiveMaxVisibleWords: Int
    ) -> CompletionPrompt? {
        guard request.mode.isContinuation,
              effectiveMaxVisibleWords >= 6,
              candidateSelection.suggestion == nil,
              candidateSelection.suppressionReason == .lowTopScore
                || candidateSelection.suppressionReason == .noCandidates
        else {
            return nil
        }

        let preferredMinimum = CompletionModelPolicy.preferredMinimumVisibleWords(
            forVisibleWords: effectiveMaxVisibleWords
        )
        let shortCandidate = candidateSelection.rankedCandidates.first?.suggestion
            ?? cleanedCandidates.first
        let shortPrefix = shortCandidate?.visibleText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if candidateSelection.suppressionReason == .lowTopScore,
           shortPrefix?.isEmpty != false {
            return nil
        }

        let context = String(request.textBeforeCursor.suffix(360))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let repairReason = (shortCandidate?.visibleWordCount ?? 0) < preferredMinimum
            ? "too short"
            : "not useful enough for inline autocomplete"
        let previousAnswerLine = shortPrefix.map {
            "The previous answer was \(repairReason): \"\($0)\"."
        } ?? "The previous answer did not produce a usable suffix."
        let previousAnswerInstruction = shortPrefix == nil
            ? "Choose a fresh continuation that fits the Before cursor text."
            : "Start with the previous short answer only if it still fits, then keep going."
        let system = """
        Inline autocomplete retry.
        \(previousAnswerLine)
        Return only one suffix after the Before cursor text.
        The suffix must be \(preferredMinimum)-\(effectiveMaxVisibleWords) words for normal drafting.
        \(previousAnswerInstruction)
        Do not restart or repeat the Before cursor text.
        Example Before cursor: The onboarding note should make the setup feel clear and
        Example suffix: easy to finish without making the user think about permissions twice before they can keep writing
        Do not include labels, quotes, explanations, multiple choices, or the Before cursor text.
        Return \(CompletionPromptBuilder.noSuggestionToken) only when unsafe or impossible.
        """
        let user = """
        Before cursor:
        \(context)

        Next \(preferredMinimum)-\(effectiveMaxVisibleWords) words, or \(CompletionPromptBuilder.noSuggestionToken):
        """
        return CompletionPrompt(system: system, user: user)
    }

    static func shouldStopEarly(
        _ suggestion: CompletionSuggestion?,
        rawOutput: String,
        mode: CompletionRequestMode,
        effectiveMaxVisibleWords: Int
    ) -> Bool {
        guard let suggestion else {
            return false
        }

        if mode == .wordCompletion {
            return true
        }

        let preferredMinimum = CompletionModelPolicy.preferredMinimumVisibleWords(
            forVisibleWords: effectiveMaxVisibleWords
        )
        guard suggestion.visibleWordCount >= preferredMinimum else {
            return false
        }

        return suggestion.visibleWordCount >= effectiveMaxVisibleWords
            || rawOutput.contains(where: { [".", "!", "?", "\n"].contains($0) })
    }

    private static func trailingWordFragment(in text: String) -> String? {
        guard let last = text.last, last.isLetter else {
            return nil
        }

        return text.split(whereSeparator: { !$0.isLetter }).last.map(String.init)
    }

    private static let wordCompletionFallbackWords = WordCompletionCandidateRanker.defaultWords + [
        "redacted",
        "configurable",
        "visible",
        "quickly",
        "transition",
        "validate",
        "immediate",
        "concise",
        "predictable",
        "helpful",
        "responsive"
    ]

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1000))
    }

    private static func formattedCandidateScore(_ score: Double?) -> String {
        guard let score else {
            return "none"
        }

        return String(format: "%.3f", score)
    }

    private func cachedStaticPrompt(systemPrompt: String) -> RuntimeStaticPromptCacheLookup {
        stateQueue.sync {
            staticPromptCache.lookup(systemPrompt: systemPrompt)
        }
    }

    private var promptKVCacheModelRevision: String {
        if let source = modelManifest?.source {
            return "\(source.repoID)@\(source.revision)"
        }

        if let model = modelManifest?.model {
            return "\(model.rawValue)@local"
        }

        return "local-path@\(modelDirectoryURL.standardizedFileURL.path)"
    }

    private func finishWarmTask(id: Int, gate: MLXRuntimeWarmGate, result: Result<Void, Error>) {
        stateQueue.sync {
            if warmTask?.id == id {
                warmTask = nil
            }
        }
        gate.finish(with: result)
    }

    private func storeIntegrityValidationCache(_ cache: ModelAssetIntegrityValidationCache) {
        stateQueue.sync {
            integrityValidationCache = cache
        }
    }

    private func cleaner(for request: CompletionRequest) -> CompletionOutputCleaner {
        let maxVisibleWords = effectiveMaxVisibleWords(for: request)
        guard maxVisibleWords != cleaner.maxVisibleWords else {
            return cleaner
        }

        return CompletionOutputCleaner(
            minimumVisibleWords: cleaner.minimumVisibleWords,
            maxVisibleWords: maxVisibleWords
        )
    }

    private func effectiveMaxVisibleWords(for request: CompletionRequest) -> Int {
        min(
            request.maxVisibleWords,
            request.behaviorProfile.maxVisibleWords
        )
    }

    private func maxGeneratedTokens(for request: CompletionRequest) -> Int {
        min(
            max(
                lengthConfiguration.maxGeneratedTokens,
                CompletionModelPolicy.generatedTokenBudget(forVisibleWords: request.maxVisibleWords)
            ),
            request.behaviorProfile.maxGeneratedTokens,
            request.mode.generatedTokenCeiling,
            CompletionModelPolicy.generatedTokenBudget(forVisibleWords: request.maxVisibleWords)
        )
    }

    private func readyContainer() async throws -> ModelContainer {
        let initialSnapshot = stateQueue.sync {
            (storedState, container, warmTask?.gate)
        }

        if case let .failed(_, reason) = initialSnapshot.0 {
            throw MLXModelRuntimeError.runtimeFailed(reason: reason)
        }

        if let existing = initialSnapshot.1 {
            return existing
        }

        if let warmGate = initialSnapshot.2 {
            try await warmGate.wait()
            try Task.checkCancellation()
            guard let warmed = stateQueue.sync(execute: { container }) else {
                throw MLXModelRuntimeError.warmCompletedWithoutContainer
            }
            return warmed
        }

        let startedWarmTask = warmTaskSnapshot()
        try await startedWarmTask.gate.wait()

        guard let warmed = stateQueue.sync(execute: { container }) else {
            throw MLXModelRuntimeError.warmCompletedWithoutContainer
        }

        return warmed
    }
}

private final class MLXRuntimeSendableBox<T>: @unchecked Sendable {
    private let value: T

    init(_ value: T) {
        self.value = value
    }

    func consume() -> T {
        value
    }
}

final class MLXRuntimeWarmGate: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-runtime-warm-gate")
    private var nextWaiterID = 0
    private var waiters: [Int: CheckedContinuation<Void, Error>] = [:]
    private var canceledBeforeRegistration = Set<Int>()
    private var completion: Result<Void, Error>?

    func wait() async throws {
        let waiterID = queue.sync {
            nextWaiterID += 1
            return nextWaiterID
        }

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                let immediateResult: Result<Void, Error>? = queue.sync {
                    if let completion {
                        return completion
                    }
                    if canceledBeforeRegistration.remove(waiterID) != nil {
                        return .failure(CancellationError())
                    }

                    waiters[waiterID] = continuation
                    return nil
                }

                if let immediateResult {
                    continuation.resume(with: immediateResult)
                }
            }
        } onCancel: {
            cancelWaiter(id: waiterID)
        }
    }

    func finish(with result: Result<Void, Error>) {
        let continuations = queue.sync {
            guard completion == nil else {
                return [CheckedContinuation<Void, Error>]()
            }

            completion = result
            let continuations = Array(waiters.values)
            waiters.removeAll()
            canceledBeforeRegistration.removeAll()
            return continuations
        }

        for continuation in continuations {
            continuation.resume(with: result)
        }
    }

    private func cancelWaiter(id: Int) {
        let continuation: CheckedContinuation<Void, Error>? = queue.sync {
            if let continuation = waiters.removeValue(forKey: id) {
                return continuation
            }
            if completion == nil {
                canceledBeforeRegistration.insert(id)
            }
            return nil
        }

        continuation?.resume(throwing: CancellationError())
    }
}

public enum MLXModelRuntimeError: LocalizedError, Equatable {
    case warmCompletedWithoutContainer
    case modelAssetIntegrityFailed(reason: String)
    case runtimeFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .warmCompletedWithoutContainer:
            return "MLX warm completed without a loaded model container."
        case let .modelAssetIntegrityFailed(reason):
            return "Model asset integrity failed: \(reason)"
        case let .runtimeFailed(reason):
            return reason
        }
    }
}
