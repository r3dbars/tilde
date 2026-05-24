import Foundation
import AutocompleteLabCore
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
    private let cleaner: CompletionOutputCleaner
    private let candidateRanker: CompletionCandidateRanker
    private let lengthConfiguration: CompletionLengthConfiguration
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-model-runtime")
    private let cancellationCoordinator = RuntimeCancellationCoordinator()

    private var storedState: LocalRuntimeState
    private var integrityValidationCache: ModelAssetIntegrityValidationCache
    private var container: ModelContainer?
    private var staticPromptCache = RuntimeStaticPromptCache()
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
        candidateRanker: CompletionCandidateRanker = CompletionCandidateRanker()
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
            candidateRanker: candidateRanker
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
        candidateRanker: CompletionCandidateRanker = CompletionCandidateRanker()
    ) {
        self.modelDirectoryURL = modelDirectoryURL
        self.modelManifest = modelManifest
        self.fileManager = fileManager
        self.usesVisionLanguageFactory = usesVisionLanguageFactory
        self.lengthConfiguration = lengthConfiguration
        self.promptBuilder = promptBuilder ?? CompletionPromptBuilder(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.cleaner = cleaner ?? CompletionOutputCleaner(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.candidateRanker = candidateRanker
        self.integrityValidationCache = integrityValidationCache
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
                    from: modelDirectoryURL,
                    using: #huggingFaceTokenizerLoader()
                )
            } else {
                loadedContainer = try await LLMModelFactory.shared.loadContainer(
                    from: modelDirectoryURL,
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
        let promptBuiltAt = Date()
        let requestCleaner = cleaner(for: request)
        let requestMaxGeneratedTokens = maxGeneratedTokens(for: request)
        var generation = try await generateRawCompletion(
            container: container,
            prompt: prompt,
            request: request,
            requestCleaner: requestCleaner,
            requestMaxGeneratedTokens: requestMaxGeneratedTokens,
            cancellationEpoch: cancellationEpoch,
            onPartialSuggestion: onPartialSuggestion
        )
        try cancellationCoordinator.check(epoch: cancellationEpoch)

        var rawOutput = generation.rawOutput
        var cleanedCandidates = requestCleaner.cleanCandidates(
            generation.rawOutput,
            after: request.textBeforeCursor,
            mode: request.mode,
            limit: 3
        )
        var candidateSelection = candidateRanker.selection(
            cleanedCandidates,
            mode: request.mode,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )
        var retryAttempted = false
        var retryUsed = false

        if let retryPrompt = Self.retryPromptForShortHighWordCandidate(
            request: request,
            cleanedCandidates: cleanedCandidates,
            candidateSelection: candidateSelection,
            effectiveMaxVisibleWords: effectiveMaxVisibleWords(for: request)
        ) {
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
                prompt: retryPrompt,
                request: request,
                requestCleaner: requestCleaner,
                requestMaxGeneratedTokens: requestMaxGeneratedTokens,
                cancellationEpoch: cancellationEpoch,
                onPartialSuggestion: onPartialSuggestion
            )
            try cancellationCoordinator.check(epoch: cancellationEpoch)

            let retryCandidates = requestCleaner.cleanCandidates(
                retryGeneration.rawOutput,
                after: request.textBeforeCursor,
                mode: request.mode,
                limit: 3
            )
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
                generation = retryGeneration
                rawOutput = retryGeneration.rawOutput
                cleanedCandidates = retryCandidates
                candidateSelection = retrySelection
            }
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
        timingMetadata["rawChars"] = String(rawOutput.count)
        timingMetadata["cleanedCandidateCount"] = String(cleanedCandidates.count)
        timingMetadata["candidateTopScore"] = Self.formattedCandidateScore(candidateTopScore)
        timingMetadata["candidateScoreMargin"] = Self.formattedCandidateScore(candidateSelection.scoreMargin)
        timingMetadata["candidateSuppressionReason"] = candidateSelection.suppressionReason?.rawValue ?? "none"
        timingMetadata["cleanedChars"] = String(cleanedSuggestion?.visibleText.count ?? 0)
        timingMetadata["retryAttempted"] = String(retryAttempted)
        timingMetadata["retryUsed"] = String(retryUsed)
        timingMetadata.merge(generation.promptCacheTraceMetadata) { current, _ in current }

        DiagnosticsLog.shared.record(
            "mlx-completion-timing",
            metadata: timingMetadata
        )
        RawAutocompleteTraceLog.shared.recordModelResult(
            request: request,
            prompt: prompt,
            rawOutput: rawOutput,
            cleanedSuggestion: cleanedSuggestion,
            cleanedCandidateCount: cleanedCandidates.count,
            candidateTopScore: candidateTopScore,
            candidateScoreMargin: candidateSelection.scoreMargin,
            candidateSuppressionReason: candidateSelection.suppressionReason?.rawValue,
            suggestionID: request.suggestionID,
            latencyMilliseconds: totalMilliseconds,
            firstTokenLatencyMilliseconds: generation.firstChunkMilliseconds
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
        prompt: CompletionPrompt,
        request: CompletionRequest,
        requestCleaner: CompletionOutputCleaner,
        requestMaxGeneratedTokens: Int,
        cancellationEpoch: Int,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> RawCompletionGeneration {
        let sessionStartedAt = Date()
        let promptCacheLookup = cachedStaticPrompt(systemPrompt: prompt.system)
        let session = ChatSession(
            container,
            instructions: promptCacheLookup.systemPrompt,
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
            promptCacheTraceMetadata: promptCacheLookup.traceMetadata
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

    static func retryPromptForShortHighWordCandidate(
        request: CompletionRequest,
        cleanedCandidates: [CompletionSuggestion],
        candidateSelection: CompletionCandidateSelection,
        effectiveMaxVisibleWords: Int
    ) -> CompletionPrompt? {
        guard request.mode.isContinuation,
              effectiveMaxVisibleWords >= 12,
              candidateSelection.suggestion == nil,
              candidateSelection.suppressionReason == .lowTopScore
        else {
            return nil
        }

        let preferredMinimum = CompletionModelPolicy.preferredMinimumVisibleWords(
            forVisibleWords: effectiveMaxVisibleWords
        )
        let shortCandidate = candidateSelection.rankedCandidates.first?.suggestion
            ?? cleanedCandidates.first
        guard let shortCandidate,
              shortCandidate.visibleWordCount < preferredMinimum
        else {
            return nil
        }

        let shortPrefix = shortCandidate.visibleText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortPrefix.isEmpty else {
            return nil
        }

        let context = String(request.textBeforeCursor.suffix(360))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let system = """
        Inline autocomplete retry.
        The previous answer was too short: "\(shortPrefix)".
        Return only one suffix after the Before cursor text.
        The suffix must be \(preferredMinimum)-\(effectiveMaxVisibleWords) words for normal drafting.
        Start with the previous short answer only if it still fits, then keep going.
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
