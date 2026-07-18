import Foundation

/// Owns the delayed retry task for an expired prefix-family cooldown.
/// The callback remains responsible for validating the current field and resetting state.
@MainActor
final class PrefixCooldownRetryHost {
    private var retryTask: Task<Void, Never>?

    var hasScheduledRetry: Bool {
        retryTask != nil
    }

    func schedule(until: Date, operation: @escaping @MainActor () -> Void) {
        cancel()
        let delayMilliseconds = max(0, Int(until.timeIntervalSinceNow * 1_000) + 25)
        retryTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else {
                return
            }

            operation()
        }
    }

    func cancel() {
        retryTask?.cancel()
        retryTask = nil
    }
}
