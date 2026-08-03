import Foundation

public enum UnavailableEngineError: Error, Equatable, Sendable {
    case unavailable(String)
}

/// Engine stand-in for shutdown/misconfiguration: every request throws.
public final class UnavailableCompletionEngine: CompletionEngine, @unchecked Sendable {
    private let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        throw UnavailableEngineError.unavailable(reason)
    }
}
