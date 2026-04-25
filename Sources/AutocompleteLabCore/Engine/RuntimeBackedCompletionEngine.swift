import Foundation

public final class RuntimeBackedCompletionEngine: CompletionEngine, @unchecked Sendable {
    private let runtime: any ModelRuntime

    public init(runtime: any ModelRuntime) {
        self.runtime = runtime
    }

    public func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await runtime.complete(request)
    }
}
