import Foundation
import AutocompleteLabCore
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

public final class MLXModelRuntime: ModelRuntime, @unchecked Sendable {
    private let modelDirectoryURL: URL
    private let usesVisionLanguageFactory: Bool
    private let promptBuilder: CompletionPromptBuilder
    private let cleaner: CompletionOutputCleaner
    private let lengthConfiguration: CompletionLengthConfiguration
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-model-runtime")

    private var storedState: LocalRuntimeState
    private var container: ModelContainer?
    private var generation = 0

    public init(
        modelDirectoryURL: URL,
        usesVisionLanguageFactory: Bool = false,
        lengthConfiguration: CompletionLengthConfiguration = .default,
        promptBuilder: CompletionPromptBuilder? = nil,
        cleaner: CompletionOutputCleaner? = nil
    ) {
        self.modelDirectoryURL = modelDirectoryURL
        self.usesVisionLanguageFactory = usesVisionLanguageFactory
        self.lengthConfiguration = lengthConfiguration
        self.promptBuilder = promptBuilder ?? CompletionPromptBuilder(maxVisibleWords: lengthConfiguration.maxVisibleWords)
        self.cleaner = cleaner ?? CompletionOutputCleaner(maxVisibleWords: lengthConfiguration.maxVisibleWords)
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
        let warmGeneration = stateQueue.sync {
            if container != nil {
                storedState = .ready(candidate: .mlx)
                return generation
            }

            generation += 1
            storedState = .warming(candidate: .mlx)
            return generation
        }

        let loadedContainer: ModelContainer
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

        try Task.checkCancellation()

        let wasCancelled = stateQueue.sync {
            warmGeneration != generation
        }

        guard !wasCancelled else {
            throw CancellationError()
        }

        stateQueue.sync {
            container = loadedContainer
            storedState = .ready(candidate: .mlx)
        }
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
        let requestCleaner = cleaner(for: request)
        let requestMaxGeneratedTokens = maxGeneratedTokens(for: request)
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

        let cleanedSuggestion = requestCleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode)
        let cleanedAt = Date()
        let totalMilliseconds = Self.milliseconds(from: startedAt, to: cleanedAt)
        DiagnosticsLog.shared.record(
            "mlx-completion-timing",
            metadata: [
                "app": request.appBundleIdentifier ?? "unknown",
                "mode": request.mode.rawValue,
                "fieldKind": request.fieldKind.rawValue,
                "behaviorProfile": request.behaviorProfile.id.rawValue,
                "promptMilliseconds": String(Self.milliseconds(from: startedAt, to: promptBuiltAt)),
                "sessionMilliseconds": String(Self.milliseconds(from: promptBuiltAt, to: sessionBuiltAt)),
                "firstChunkMilliseconds": firstChunkMilliseconds.map(String.init) ?? "none",
                "generationMilliseconds": String(Self.milliseconds(from: sessionBuiltAt, to: generatedAt)),
                "cleanupMilliseconds": String(Self.milliseconds(from: generatedAt, to: cleanedAt)),
                "totalMilliseconds": String(totalMilliseconds),
                "maxTokens": String(requestMaxGeneratedTokens),
                "maxVisibleWords": String(effectiveMaxVisibleWords(for: request)),
                "rawChars": String(rawOutput.count),
                "cleanedChars": String(cleanedSuggestion?.visibleText.count ?? 0)
            ]
        )
        RawAutocompleteTraceLog.shared.recordModelResult(
            request: request,
            prompt: prompt,
            rawOutput: rawOutput,
            cleanedSuggestion: cleanedSuggestion,
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
        switch request.mode {
        case .wordCompletion:
            return min(3, request.behaviorProfile.maxGeneratedTokens)
        case .phraseContinuation, .sentenceContinuation:
            return min(lengthConfiguration.maxGeneratedTokens, request.behaviorProfile.maxGeneratedTokens)
        }
    }

    private func readyContainer() async throws -> ModelContainer {
        if let existing = stateQueue.sync(execute: { container }) {
            return existing
        }

        for _ in 0..<600 {
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
            try await Task.sleep(for: .milliseconds(50))

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

public enum MLXModelRuntimeError: LocalizedError {
    case warmCompletedWithoutContainer

    public var errorDescription: String? {
        switch self {
        case .warmCompletedWithoutContainer:
            return "MLX warm completed without a loaded model container."
        }
    }
}
