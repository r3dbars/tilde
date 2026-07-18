@testable import AutocompleteLabApp
import Testing

@Suite("Manual suggestion request host")
@MainActor
struct ManualSuggestionRequestHostTests {
    @Test("keeps manual summon intent one-shot")
    func keepsManualSummonIntentOneShot() {
        let host = ManualSuggestionRequestHost()

        host.request()

        #expect(host.isPending)
        #expect(host.consumePendingRequest())
        #expect(!host.isPending)
        #expect(!host.consumePendingRequest())
    }
}
