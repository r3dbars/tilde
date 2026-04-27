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
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-model-runtime")

    private var storedState: LocalRuntimeState
    private var container: ModelContainer?
    private var generation = 0

    public init(
        modelDirectoryURL: URL,
        usesVisionLanguageFactory: Bool = false,
        promptBuilder: CompletionPromptBuilder = CompletionPromptBuilder(),
        cleaner: CompletionOutputCleaner = CompletionOutputCleaner()
    ) {
        self.modelDirectoryURL = modelDirectoryURL
        self.usesVisionLanguageFactory = usesVisionLanguageFactory
        self.promptBuilder = promptBuilder
        self.cleaner = cleaner
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
        let container = try await readyContainer()
        try Task.checkCancellation()

        let startedAt = Date()
        let prompt = promptBuilder.prompt(for: request)
        let promptBuiltAt = Date()
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: GenerateParameters(
                maxTokens: Self.maxGeneratedTokens(for: request.mode),
                temperature: 0
            ),
            additionalContext: ["enable_thinking": false]
        )

        let sessionBuiltAt = Date()
        var rawOutput = ""
        var firstChunkMilliseconds: Int?
        let stream = session.streamResponse(to: prompt.user)
        for try await chunk in stream {
            if firstChunkMilliseconds == nil {
                firstChunkMilliseconds = Self.milliseconds(from: sessionBuiltAt, to: Date())
            }

            rawOutput += chunk

            if shouldStopEarly(rawOutput, request: request) {
                break
            }
        }
        let generatedAt = Date()
        try Task.checkCancellation()

        let cleanedSuggestion = cleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode)
        let cleanedAt = Date()
        DiagnosticsLog.shared.record(
            "mlx-completion-timing",
            metadata: [
                "app": request.appBundleIdentifier ?? "unknown",
                "mode": request.mode.rawValue,
                "promptMilliseconds": String(Self.milliseconds(from: startedAt, to: promptBuiltAt)),
                "sessionMilliseconds": String(Self.milliseconds(from: promptBuiltAt, to: sessionBuiltAt)),
                "firstChunkMilliseconds": firstChunkMilliseconds.map(String.init) ?? "none",
                "generationMilliseconds": String(Self.milliseconds(from: sessionBuiltAt, to: generatedAt)),
                "cleanupMilliseconds": String(Self.milliseconds(from: generatedAt, to: cleanedAt)),
                "totalMilliseconds": String(Self.milliseconds(from: startedAt, to: cleanedAt)),
                "maxTokens": String(Self.maxGeneratedTokens(for: request.mode)),
                "rawChars": String(rawOutput.count),
                "cleanedChars": String(cleanedSuggestion?.visibleText.count ?? 0)
            ]
        )
        RawAutocompleteTraceLog.shared.recordModelResult(
            request: request,
            prompt: prompt,
            rawOutput: rawOutput,
            cleanedSuggestion: cleanedSuggestion,
            suggestionID: request.suggestionID
        )

        return cleanedSuggestion
    }

    private func shouldStopEarly(_ rawOutput: String, request: CompletionRequest) -> Bool {
        guard let suggestion = cleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode) else {
            return false
        }

        if request.mode == .wordCompletion {
            return true
        }

        return suggestion.visibleWordCount >= CompletionModelPolicy.minimumVisibleWords
            && (suggestion.visibleWordCount >= CompletionModelPolicy.mvp.maxVisibleWords
                || rawOutput.contains(where: { [".", "!", "?", "\n"].contains($0) }))
    }

    private static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1000))
    }

    private static func maxGeneratedTokens(for mode: CompletionRequestMode) -> Int {
        switch mode {
        case .wordCompletion:
            return 3
        case .phraseContinuation:
            return min(3, CompletionModelPolicy.mvp.maxGeneratedTokens)
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
