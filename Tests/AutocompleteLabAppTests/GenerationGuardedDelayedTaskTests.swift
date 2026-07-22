@testable import AutocompleteLabApp
import Foundation
import Testing

@Suite("Generation-guarded delayed task")
@MainActor
struct GenerationGuardedDelayedTaskTests {
    @Test("replaces and cancels scheduled work")
    func replacesAndCancelsScheduledWork() {
        let task = GenerationGuardedDelayedTask()

        task.schedule(at: Date().addingTimeInterval(10)) {}
        #expect(task.isScheduled)

        task.schedule(afterMilliseconds: 10_000) {}
        #expect(task.isScheduled)

        task.cancel()
        #expect(!task.isScheduled)
    }

    @Test("clears completed work")
    func clearsCompletedWork() async throws {
        let task = GenerationGuardedDelayedTask()
        var didRun = false

        task.schedule(afterMilliseconds: 0) {
            didRun = true
        }

        for _ in 0..<100 where !didRun {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(2))
        }

        #expect(didRun)
        #expect(!task.isScheduled)
    }

    @Test("keeps work rescheduled by the completed operation")
    func keepsWorkRescheduledByCompletedOperation() async throws {
        let task = GenerationGuardedDelayedTask()
        var didRun = false

        task.schedule(afterMilliseconds: 0) {
            didRun = true
            task.schedule(afterMilliseconds: 10_000) {}
        }

        for _ in 0..<100 where !didRun {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(2))
        }

        #expect(didRun)
        #expect(task.isScheduled)
        task.cancel()
    }
}
