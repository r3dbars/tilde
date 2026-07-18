@testable import AutocompleteLabApp
import Foundation
import Testing

@Suite("Codex prompt presentation retry host")
@MainActor
struct CodexPromptPresentationRetryHostTests {
    @Test("replaces and cancels the pending retry task")
    func replacesAndCancelsPendingRetryTask() {
        let host = CodexPromptPresentationRetryHost()

        host.schedule(afterMilliseconds: 10_000) {}
        #expect(host.hasScheduledRetry)

        host.schedule(afterMilliseconds: 10_000) {}
        #expect(host.hasScheduledRetry)

        host.cancel()
        #expect(!host.hasScheduledRetry)
    }

    @Test("clears completed retry state")
    func clearsCompletedRetryState() async throws {
        let host = CodexPromptPresentationRetryHost()
        var didRun = false

        host.schedule(afterMilliseconds: 0) {
            didRun = true
        }

        for _ in 0..<100 where !didRun {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(2))
        }

        #expect(didRun)
        #expect(!host.hasScheduledRetry)
    }
}
