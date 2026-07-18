@testable import AutocompleteLabApp
import Foundation
import Testing

@Suite("Prefix cooldown retry host")
@MainActor
struct PrefixCooldownRetryHostTests {
    @Test("replaces and cancels the pending retry task")
    func replacesAndCancelsPendingRetryTask() {
        let host = PrefixCooldownRetryHost()

        host.schedule(until: Date().addingTimeInterval(10)) {}
        #expect(host.hasScheduledRetry)

        host.schedule(until: Date().addingTimeInterval(10)) {}
        #expect(host.hasScheduledRetry)

        host.cancel()
        #expect(!host.hasScheduledRetry)
    }
}
