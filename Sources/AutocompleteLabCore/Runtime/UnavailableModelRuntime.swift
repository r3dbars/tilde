import Foundation

public struct UnavailableModelRuntimeError: LocalizedError, Equatable, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var errorDescription: String? {
        "Local model runtime is unavailable: \(reason)"
    }
}

public final class UnavailableModelRuntime: ModelRuntime, @unchecked Sendable {
    private let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var state: LocalRuntimeState {
        get async {
            .unavailable(reason: reason)
        }
    }

    public func warm() async throws {
        throw UnavailableModelRuntimeError(reason: reason)
    }

    public func cancel() {}

    public func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        throw UnavailableModelRuntimeError(reason: reason)
    }
}
