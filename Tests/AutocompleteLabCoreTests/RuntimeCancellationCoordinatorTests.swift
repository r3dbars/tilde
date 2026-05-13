import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Runtime cancellation coordinator")
struct RuntimeCancellationCoordinatorTests {
    @Test("Completed operations unregister")
    func completedOperationsUnregister() async throws {
        let coordinator = RuntimeCancellationCoordinator()

        let value = try await coordinator.withRegisteredTask { epoch in
            try coordinator.check(epoch: epoch)
            return "done"
        }

        #expect(value == "done")
        #expect(coordinator.activeOperationCount == 0)
    }

    @Test("Cancel all cancels registered operations")
    func cancelAllCancelsRegisteredOperations() async {
        let coordinator = RuntimeCancellationCoordinator()
        let latch = AsyncLatch()
        let task = Task {
            try await coordinator.withRegisteredTask { epoch in
                await latch.signal()
                try await Task.sleep(for: .seconds(30))
                try coordinator.check(epoch: epoch)
                return "late"
            }
        }

        await latch.wait()
        #expect(coordinator.activeOperationCount == 1)

        let canceledEpoch = coordinator.cancelAll()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(canceledEpoch > 0)
        #expect(coordinator.activeOperationCount == 0)
    }

    @Test("Check rejects stale epochs")
    func checkRejectsStaleEpochs() {
        let coordinator = RuntimeCancellationCoordinator()
        let epoch = coordinator.snapshot()

        _ = coordinator.cancelAll()

        #expect(throws: CancellationError.self) {
            try coordinator.check(epoch: epoch)
        }
    }
}

private actor AsyncLatch {
    private var isSignaled = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func signal() {
        isSignaled = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    func wait() async {
        if isSignaled {
            return
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}
