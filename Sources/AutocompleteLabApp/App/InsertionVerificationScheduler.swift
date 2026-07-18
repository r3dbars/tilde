import Foundation

@MainActor
final class InsertionVerificationScheduler {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration = .milliseconds(140)) {
        self.delay = delay
    }

    func schedule(_ operation: @escaping @MainActor () -> Void) {
        schedule(after: delay, operation: operation)
    }

    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor () -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }

            operation()
        }
    }

    func scheduleAsync(
        after delay: Duration,
        operation: @escaping @MainActor () async -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }

            await operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
