import Foundation

@MainActor
struct SuggestionRequestCancellationHostDependencies {
    let cancelPendingRequest: () -> Bool
    let clearStreamingPresentations: () -> Void
    let invalidateRequest: () -> Void
}

/// Owns the ordering-sensitive cancellation boundary for one suggestion request.
/// Request execution and presentation remain in AppDelegate until their own seams are
/// extracted; this host keeps scheduler and streaming cleanup together.
@MainActor
final class SuggestionRequestCancellationHost {
    private let dependencies: SuggestionRequestCancellationHostDependencies

    init(dependencies: SuggestionRequestCancellationHostDependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    func cancelPendingRequest(reason: String) -> Bool {
        let cancelledPendingRequest = dependencies.cancelPendingRequest()
        guard cancelledPendingRequest else {
            return false
        }

        dependencies.clearStreamingPresentations()
        DiagnosticsLog.shared.record(
            "suggestion-request-cancelled",
            metadata: ["reason": reason]
        )
        return true
    }

    @discardableResult
    func invalidatePendingRequest() -> Bool {
        let cancelledPendingRequest = cancelPendingRequest(reason: "invalidate")
        dependencies.clearStreamingPresentations()
        dependencies.invalidateRequest()
        return cancelledPendingRequest
    }
}
