import Foundation

/// Owns the deferred terminal-host acceptance task used by the opt-in Ghostty probe.
/// Proof validation and insertion remain in AppDelegate.
@MainActor
final class DeferredTerminalHostAcceptanceHost {
    private var acceptanceTask: Task<Void, Never>?
    private var generation = 0

    var hasScheduledAcceptance: Bool {
        acceptanceTask != nil
    }

    func schedule(
        afterMilliseconds delayMilliseconds: Int,
        operation: @escaping @MainActor () -> Void
    ) {
        cancel()
        generation += 1
        let scheduledGeneration = generation
        acceptanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(max(0, delayMilliseconds)))
            guard !Task.isCancelled else {
                return
            }

            operation()
            guard self?.generation == scheduledGeneration else {
                return
            }
            self?.acceptanceTask = nil
        }
    }

    func cancel() {
        generation += 1
        acceptanceTask?.cancel()
        acceptanceTask = nil
    }
}
