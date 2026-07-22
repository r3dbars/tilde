import Foundation

@MainActor
final class GenerationGuardedDelayedTask {
    private var task: Task<Void, Never>?
    private var generation = 0

    var isScheduled: Bool {
        task != nil
    }

    func schedule(
        at date: Date,
        operation: @escaping @MainActor () -> Void
    ) {
        schedule(
            afterMilliseconds: Int(date.timeIntervalSinceNow * 1_000),
            operation: operation
        )
    }

    func schedule(
        afterMilliseconds delayMilliseconds: Int,
        operation: @escaping @MainActor () -> Void
    ) {
        cancel()
        generation += 1
        let scheduledGeneration = generation
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(max(0, delayMilliseconds)))
            guard !Task.isCancelled else {
                return
            }

            operation()
            guard self?.generation == scheduledGeneration else {
                return
            }
            self?.task = nil
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
    }
}
