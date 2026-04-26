import Foundation
import AutocompleteLabCore
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

public final class MLXModelRuntime: ModelRuntime, @unchecked Sendable {
    private let modelDirectoryURL: URL
    private let promptBuilder: CompletionPromptBuilder
    private let cleaner: CompletionOutputCleaner
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mlx-model-runtime")

    private var storedState: LocalRuntimeState
    private var container: ModelContainer?
    private var generation = 0

    public init(
        modelDirectoryURL: URL,
        promptBuilder: CompletionPromptBuilder = CompletionPromptBuilder(),
        cleaner: CompletionOutputCleaner = CompletionOutputCleaner()
    ) {
        self.modelDirectoryURL = modelDirectoryURL
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

        let loadedContainer = try await LLMModelFactory.shared.loadContainer(
            from: modelDirectoryURL,
            using: #huggingFaceTokenizerLoader()
        )

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
            )
        )

        let rawOutput = try await session.respond(to: prompt.user)
        try Task.checkCancellation()

        return cleaner.clean(rawOutput)
    }

    private func readyContainer() async throws -> ModelContainer {
        if let existing = stateQueue.sync(execute: { container }) {
            return existing
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
