@testable import AutocompleteLabApp
import Foundation
import Testing

@Suite("Accepted insertion undo expiration host")
@MainActor
struct AcceptedInsertionUndoExpirationHostTests {
    @Test("replaces and cancels the pending expiration")
    func replacesAndCancelsPendingExpiration() {
        let host = AcceptedInsertionUndoExpirationHost()

        host.schedule(expiresAt: Date().addingTimeInterval(10)) {}
        #expect(host.hasScheduledExpiration)

        host.schedule(expiresAt: Date().addingTimeInterval(10)) {}
        #expect(host.hasScheduledExpiration)

        host.cancel()
        #expect(!host.hasScheduledExpiration)
    }
}
