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

    private var storedState: LocalRuntimeState
    private var container: ModelContainer?
    private var staticPromptCache = RuntimeStaticPromptCache()
    private var generation = 0

    public init(
        modelDirectoryURL: URL,
        modelManifest: LocalModelAssetManifest? = nil,
        fileManager: FileManager = .default,
        usesVisionLanguageFactory: Bool = false,
        lengthConfiguration: CompletionLengthConfiguration = .default,
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
        let startedAt = Date()
        try verifyModelAssetIntegrity(startedAt: startedAt)
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
        } catch {
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

    private func verifyModelAssetIntegrity(startedAt: Date) throws {
        guard let modelManifest else {
            return
        }

        guard let integrityError = ModelAssetIntegrityReceiptValidator.validate(
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
                "loadMilliseconds": String(Self.milliseconds(from: startedAt, to: Date())),
                "reason": integrityError,
                "usesVisionLanguageFactory": String(usesVisionLanguageFactory)
            ]
        )
        throw error
    }

    public func cancel() {
        stateQueue.sync {
            generation += 1
            storedState = .unavailable(reason: "MLX runtime was canceled.")
        }
    }

    public func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await complete(request, onPartialSuggestion: { _ in })
    }

    public func complete(
        _ request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let container = try await readyContainer()
        try Task.checkCancellation()

        let startedAt = Date()
        let prompt = promptBuilder.prompt(for: request)
        let promptBuiltAt = Date()
        let promptCacheLookup = cachedStaticPrompt(systemPrompt: prompt.system)
        let requestCleaner = cleaner(for: request)
        let requestMaxGeneratedTokens = maxGeneratedTokens(for: request)
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
                try Task.checkCancellation()

                if firstChunkMilliseconds == nil {
                    firstChunkMilliseconds = Self.milliseconds(from: sessionBuiltAt, to: Date())
                }

                rawOutput += chunk

                if let partialSuggestion = requestCleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode),
                   !partialSuggestion.isEmpty,
                   partialSuggestion.visibleText != lastPartialVisibleText {
                    lastPartialVisibleText = partialSuggestion.visibleText
                    onPartialSuggestion(partialSuggestion)
                }

                if shouldStopEarly(rawOutput, request: request, cleaner: requestCleaner) {
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
        try Task.checkCancellation()

        let cleanedCandidates = requestCleaner.cleanCandidates(
            rawOutput,
            after: request.textBeforeCursor,
            mode: request.mode,
            limit: 3
        )
        let candidateSelection = candidateRanker.selection(
            cleanedCandidates,
            mode: request.mode,
            textBeforeCursor: request.textBeforeCursor,
            behaviorProfileID: request.behaviorProfile.id
        )
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
        timingMetadata["sessionMilliseconds"] = String(Self.milliseconds(from: promptBuiltAt, to: sessionBuiltAt))
        timingMetadata["firstChunkMilliseconds"] = firstChunkMilliseconds.map(String.init) ?? "none"
        timingMetadata["generationMilliseconds"] = String(Self.milliseconds(from: sessionBuiltAt, to: generatedAt))
        timingMetadata["cleanupMilliseconds"] = String(Self.milliseconds(from: generatedAt, to: cleanedAt))
        timingMetadata["totalMilliseconds"] = String(totalMilliseconds)
        timingMetadata["maxTokens"] = String(requestMaxGeneratedTokens)
        timingMetadata["maxVisibleWords"] = String(effectiveMaxVisibleWords(for: request))
        timingMetadata["rawChars"] = String(rawOutput.count)
        timingMetadata["cleanedCandidateCount"] = String(cleanedCandidates.count)
        timingMetadata["candidateTopScore"] = Self.formattedCandidateScore(candidateTopScore)
        timingMetadata["candidateScoreMargin"] = Self.formattedCandidateScore(candidateSelection.scoreMargin)
        timingMetadata["candidateSuppressionReason"] = candidateSelection.suppressionReason?.rawValue ?? "none"
        timingMetadata["cleanedChars"] = String(cleanedSuggestion?.visibleText.count ?? 0)
        timingMetadata.merge(promptCacheLookup.traceMetadata) { current, _ in current }

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
            firstTokenLatencyMilliseconds: firstChunkMilliseconds
        )

        return cleanedSuggestion
    }

    private func shouldStopEarly(
        _ rawOutput: String,
        request: CompletionRequest,
        cleaner requestCleaner: CompletionOutputCleaner
    ) -> Bool {
        guard let suggestion = requestCleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode) else {
            return false
        }

        if request.mode == .wordCompletion {
            return true
        }

        return suggestion.visibleWordCount >= CompletionModelPolicy.minimumVisibleWords
            && (suggestion.visibleWordCount >= effectiveMaxVisibleWords(for: request)
                || rawOutput.contains(where: { [".", "!", "?", "\n"].contains($0) }))
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
            lengthConfiguration.maxVisibleWords,
            request.maxVisibleWords,
            request.behaviorProfile.maxVisibleWords
        )
    }

    private func maxGeneratedTokens(for request: CompletionRequest) -> Int {
        min(
            lengthConfiguration.maxGeneratedTokens,
            request.behaviorProfile.maxGeneratedTokens,
            request.mode.generatedTokenCeiling,
            CompletionModelPolicy.clampedGeneratedTokens(request.maxVisibleWords + 6)
        )
    }

    private func readyContainer() async throws -> ModelContainer {
        let initialSnapshot = stateQueue.sync {
            (storedState, container)
        }

        if case let .failed(_, reason) = initialSnapshot.0 {
            throw MLXModelRuntimeError.runtimeFailed(reason: reason)
        }

        if let existing = initialSnapshot.1 {
            return existing
        }

        for _ in 0..<3_000 {
            let isWarming = stateQueue.sync {
                if case .warming = storedState {
                    return true
                }

                return false
            }

            guard isWarming else {
                break
            }

            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(10))

            if let existing = stateQueue.sync(execute: { container }) {
                return existing
            }
        }

        try await warm()

        guard let warmed = stateQueue.sync(execute: { container }) else {
            throw MLXModelRuntimeError.warmCompletedWithoutContainer
        }

        return warmed
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
