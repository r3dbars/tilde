import Foundation

/// Owns one delayed suggestion request at a time.
///
/// Request execution remains in AppDelegate for now because it still coordinates model
/// streaming, presentation, and field state. This type owns only the lifecycle state that
/// determines whether a request is pending and makes cancellation safe and testable.
@MainActor
final class SuggestionRequestScheduler {
    private var task: Task<Void, Never>?
    private var suggestionID: String?

    var hasPendingRequest: Bool {
        task != nil
    }

    func schedule(
        suggestionID: String,
        delayMilliseconds: Int,
        operation: @escaping @MainActor () async -> Void
    ) {
        _ = cancelPendingRequest()
        self.suggestionID = suggestionID
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else {
                self?.clearCompletedRequest(suggestionID: suggestionID)
                return
            }

            await operation()
            self?.clearCompletedRequest(suggestionID: suggestionID)
        }
    }

    @discardableResult
    func cancelPendingRequest() -> Bool {
        guard let task else {
            return false
        }

        task.cancel()
        self.task = nil
        suggestionID = nil
        return true
    }

    private func clearCompletedRequest(suggestionID: String) {
        guard self.suggestionID == suggestionID else {
            return
        }

        task = nil
        self.suggestionID = nil
    }
}
