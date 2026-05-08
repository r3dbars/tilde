import Foundation
import AutocompleteLabCore

final class UnavailableModelRuntime: ModelRuntime, @unchecked Sendable {
    private let candidate: CompletionRuntimeCandidate
    private let reason: String

    init(candidate: CompletionRuntimeCandidate, reason: String) {
        self.candidate = candidate
        self.reason = reason
    }

    var state: LocalRuntimeState {
        get async {
            .unavailable(reason: reason)
        }
    }

    func warm() async throws {
        throw UnavailableModelRuntimeError(candidate: candidate, reason: reason)
    }

    func cancel() {}

    func unload(reason: String) {}

    func complete(_ request: CompletionRequest) async throws -> CompletionSuggestion? {
        throw UnavailableModelRuntimeError(candidate: candidate, reason: reason)
    }
}

struct UnavailableModelRuntimeError: LocalizedError {
    let candidate: CompletionRuntimeCandidate
    let reason: String

    var errorDescription: String? {
        "\(candidate.displayName) runtime is unavailable: \(reason)"
    }
}
