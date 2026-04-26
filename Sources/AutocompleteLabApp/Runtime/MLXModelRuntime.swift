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

        let prompt = promptBuilder.prompt(for: request)
        let session = ChatSession(
            container,
            instructions: prompt.system,
            generateParameters: GenerateParameters(
                maxTokens: CompletionModelPolicy.mvp.maxGeneratedTokens,
                temperature: 0
            ),
            additionalContext: ["enable_thinking": false]
        )

        let rawOutput = try await session.respond(to: prompt.user)
        try Task.checkCancellation()

        let cleanedSuggestion = cleaner.clean(rawOutput, after: request.textBeforeCursor, mode: request.mode)
        RawAutocompleteTraceLog.shared.recordModelResult(
            request: request,
            prompt: prompt,
            rawOutput: rawOutput,
            cleanedSuggestion: cleanedSuggestion
        )

        return cleanedSuggestion
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
