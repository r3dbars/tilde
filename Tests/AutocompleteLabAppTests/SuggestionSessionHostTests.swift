@testable import AutocompleteLabApp
import AutocompleteLabCore
import Testing

@Suite("Suggestion session host")
@MainActor
struct SuggestionSessionHostTests {
    @Test("owns presentation and residual next-word acceptance state")
    func ownsPresentationAndResidualNextWordAcceptanceState() {
        let host = SuggestionSessionHost()
        host.present(CompletionSuggestion(text: " make this better", maxVisibleWords: 3))

        #expect(host.hasVisibleSuggestion)
        #expect(host.nextWordAcceptance() == " make ")
        host.commitNextWordAcceptance(" make ")

        #expect(host.visibleSuggestion?.text == "this better")
        #expect(host.hasVisibleSuggestion)
    }

    @Test("keeps session instances isolated and dismissible")
    func keepsSessionInstancesIsolatedAndDismissible() {
        let first = SuggestionSessionHost()
        let second = SuggestionSessionHost()

        first.present(CompletionSuggestion(text: " finish", maxVisibleWords: 2))
        first.dismiss()

        #expect(!first.hasVisibleSuggestion)
        #expect(!second.hasVisibleSuggestion)
    }
}
