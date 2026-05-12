import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Insertion verification scheduler")
struct InsertionVerificationSchedulerTests {
    @Test("Runs the latest scheduled operation")
    func runsLatestScheduledOperation() async throws {
        let scheduler = InsertionVerificationScheduler(delay: .milliseconds(10))
        var values: [String] = []

        await withCheckedContinuation { continuation in
            scheduler.schedule {
                values.append("stale")
            }
            scheduler.schedule {
                values.append("fresh")
                continuation.resume()
            }
        }

        #expect(values == ["fresh"])
    }

    @Test("Cancel prevents pending verification")
    func cancelPreventsPendingVerification() async throws {
        let scheduler = InsertionVerificationScheduler(delay: .milliseconds(25))
        var didRun = false

        scheduler.schedule {
            didRun = true
        }
        scheduler.cancel()

        try await Task.sleep(for: .milliseconds(50))

        #expect(!didRun)
    }
}
