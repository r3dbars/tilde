import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("MLX runtime warm gate")
struct MLXModelRuntimeWarmGateTests {
    @Test("Warm gate resumes every waiter when warm completes")
    func warmGateResumesEveryWaiterWhenWarmCompletes() async throws {
        let gate = MLXRuntimeWarmGate()

        async let first: Void = gate.wait()
        async let second: Void = gate.wait()
        await Task.yield()

        gate.finish(with: .success(()))

        try await first
        try await second
        try await gate.wait()
    }

    @Test("Canceling one waiter does not finish the warm gate")
    func cancelingOneWaiterDoesNotFinishWarmGate() async throws {
        let gate = MLXRuntimeWarmGate()
        let canceledWaiter = Task {
            try await gate.wait()
        }

        await Task.yield()
        canceledWaiter.cancel()

        await #expect(throws: CancellationError.self) {
            try await canceledWaiter.value
        }

        async let remainingWaiter: Void = gate.wait()
        await Task.yield()

        gate.finish(with: .success(()))

        try await remainingWaiter
        try await gate.wait()
    }

    @Test("Warm gate replays warm failures to current and future waiters")
    func warmGateReplaysWarmFailures() async {
        let gate = MLXRuntimeWarmGate()

        let first = Task {
            try await gate.wait()
        }
        await Task.yield()

        gate.finish(with: .failure(MLXModelRuntimeError.warmCompletedWithoutContainer))

        await #expect(throws: MLXModelRuntimeError.warmCompletedWithoutContainer) {
            try await first.value
        }
        await #expect(throws: MLXModelRuntimeError.warmCompletedWithoutContainer) {
            try await gate.wait()
        }
    }
}
