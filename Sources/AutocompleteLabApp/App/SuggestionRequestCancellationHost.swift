import Foundation

@MainActor
struct SuggestionRequestCancellationHostDependencies {
    let clearCooldownPreservation: () -> Void
    let hasScheduledPresentationRetry: () -> Bool
    let cancelPresentationRetry: () -> Void
    let cancelPendingRequest: () -> Bool
    let clearStreamingPresentations: () -> Void
}

/// Owns the ordering-sensitive cancellation boundary for one suggestion request.
/// Request execution and presentation remain in AppDelegate until their own seams are
/// extracted; this host keeps transient retry, scheduler, and streaming cleanup together.
@MainActor
final class SuggestionRequestCancellationHost {
    private let dependencies: SuggestionRequestCancellationHostDependencies

    init(dependencies: SuggestionRequestCancellationHostDependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    func cancelPendingRequest(reason: String) -> Bool {
        dependencies.clearCooldownPreservation()

        let cancelledPresentationRefreshRetry = dependencies.hasScheduledPresentationRetry()
        dependencies.cancelPresentationRetry()
        if cancelledPresentationRefreshRetry {
            DiagnosticsLog.shared.record(
                "codex-prompt-target-refresh-retry-cancelled",
                metadata: ["reason": reason]
            )
        }

        let cancelledPendingRequest = dependencies.cancelPendingRequest()
        guard cancelledPendingRequest else {
            return cancelledPresentationRefreshRetry
        }

        dependencies.clearStreamingPresentations()
        DiagnosticsLog.shared.record(
            "suggestion-request-cancelled",
            metadata: ["reason": reason]
        )
        return true
    }
}
