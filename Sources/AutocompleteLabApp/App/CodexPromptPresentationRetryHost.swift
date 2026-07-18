import Foundation

/// Owns one transient Codex prompt presentation retry task.
/// Presentation and AX validation remain in AppDelegate.
@MainActor
final class CodexPromptPresentationRetryHost {
    private var retryTask: Task<Void, Never>?
    private var generation = 0

    var hasScheduledRetry: Bool {
        retryTask != nil
    }

    func schedule(
        afterMilliseconds delayMilliseconds: Int,
        operation: @escaping @MainActor () -> Void
    ) {
        cancel()
        generation += 1
        let scheduledGeneration = generation
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(max(0, delayMilliseconds)))
            guard !Task.isCancelled else {
                return
            }

            operation()
            guard self?.generation == scheduledGeneration else {
                return
            }
            self?.retryTask = nil
        }
    }

    func cancel() {
        generation += 1
        retryTask?.cancel()
        retryTask = nil
    }
}
