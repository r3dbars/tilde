import AutocompleteLabCore
import Foundation

/// Owns one-shot manual summon intent and the retry task used while a poll is in flight.
/// Accessibility reads and suggestion execution remain in AppDelegate.
@MainActor
final class ManualSuggestionRequestHost {
    private let retryPolicy: ManualSuggestionRetryPolicy
    private var retryTask: Task<Void, Never>?
    private(set) var isPending = false

    init(retryPolicy: ManualSuggestionRetryPolicy = ManualSuggestionRetryPolicy()) {
        self.retryPolicy = retryPolicy
    }

    func request() {
        isPending = true
    }

    @discardableResult
    func consumePendingRequest() -> Bool {
        guard isPending else {
            return false
        }

        isPending = false
        return true
    }

    func clearPendingRequest() {
        isPending = false
    }

    func scheduleRetry(operation: @escaping @MainActor () -> Void) {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(self?.retryPolicy.delayMilliseconds ?? 150))
            guard let self, self.isPending else {
                return
            }
            operation()
        }
    }

    func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
    }
}
