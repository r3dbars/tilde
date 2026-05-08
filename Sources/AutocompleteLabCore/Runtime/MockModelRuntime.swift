import Foundation

public final class MockModelRuntime: ModelRuntime, @unchecked Sendable {
    private let candidate: CompletionRuntimeCandidate
    private let warmDelayMilliseconds: Int
    private let engine: any CompletionEngine
    private let stateQueue = DispatchQueue(label: "app.transcripted.autocomplete.mock-model-runtime")

    private var storedState: LocalRuntimeState
    private var generation = 0

    public init(
        candidate: CompletionRuntimeCandidate = .mock,
        warmDelayMilliseconds: Int = 0,
        engine: any CompletionEngine = MockCompletionEngine()
    ) {
        self.candidate = candidate
        self.warmDelayMilliseconds = max(0, warmDelayMilliseconds)
        self.engine = engine
        self.storedState = .unavailable(reason: "Runtime has not been warmed.")
    }

    public var state: LocalRuntimeState {
        get async {
            stateQueue.sync {
                storedState
            }
        }
    }

    public func warm() async throws {
        var isAlreadyReady = false
        let warmGeneration = stateQueue.sync {
            if case .ready = storedState {
                isAlreadyReady = true
                return generation
            }

            generation += 1
            storedState = .warming(candidate: candidate)
            return generation
        }

        if isAlreadyReady {
            return
        }

        if warmDelayMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(warmDelayMilliseconds))
        }

        try Task.checkCancellation()

        let wasCancelled = stateQueue.sync {
            warmGeneration != generation
        }

        if wasCancelled {
            throw CancellationError()
        }

        stateQueue.sync {
            storedState = .ready(candidate: candidate)
        }
    }

    public func cancel() {
        stateQueue.sync {
            generation += 1
            storedState = .unavailable(reason: "Runtime was canceled.")
        }
    }

    public func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await complete(request, onPartialSuggestion: { _ in })
    }

    public func complete(
        _ request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let currentState = await state
        if case .ready = currentState {
            try Task.checkCancellation()
        } else {
            try await warm()
        }

        let suggestion = try await engine.suggestion(for: request)
        if let suggestion {
            onPartialSuggestion(suggestion)
        }
        return suggestion
    }
}
