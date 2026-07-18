@testable import AutocompleteLabApp
import Foundation
import Testing

@Suite("Deferred terminal-host acceptance host")
@MainActor
struct DeferredTerminalHostAcceptanceHostTests {
    @Test("replaces and cancels the pending acceptance")
    func replacesAndCancelsPendingAcceptance() {
        let host = DeferredTerminalHostAcceptanceHost()

        host.schedule(afterMilliseconds: 10_000) {}
        #expect(host.hasScheduledAcceptance)

        host.schedule(afterMilliseconds: 10_000) {}
        #expect(host.hasScheduledAcceptance)

        host.cancel()
        #expect(!host.hasScheduledAcceptance)
    }
}
