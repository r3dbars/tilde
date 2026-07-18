import Foundation

/// Owns the expiration timer for the current accepted-insertion undo window.
/// Undo state and rollback validation remain in AppDelegate.
@MainActor
final class AcceptedInsertionUndoExpirationHost {
    private var expirationTask: Task<Void, Never>?
    private var generation = 0

    var hasScheduledExpiration: Bool {
        expirationTask != nil
    }

    func schedule(
        expiresAt: Date,
        operation: @escaping @MainActor () -> Void
    ) {
        cancel()
        generation += 1
        let scheduledGeneration = generation
        let delayMilliseconds = max(0, Int(expiresAt.timeIntervalSinceNow * 1_000))
        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else {
                return
            }

            operation()
            guard self?.generation == scheduledGeneration else {
                return
            }
            self?.expirationTask = nil
        }
    }

    func cancel() {
        generation += 1
        expirationTask?.cancel()
        expirationTask = nil
    }
}
