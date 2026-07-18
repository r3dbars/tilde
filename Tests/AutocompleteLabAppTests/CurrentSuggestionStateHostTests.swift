@testable import AutocompleteLabApp
import AutocompleteLabCore
import Testing

@Suite("Current suggestion state host")
@MainActor
struct CurrentSuggestionStateHostTests {
    @Test("forwards optimistic type-through state and presentation fields")
    func forwardsOptimisticTypeThroughStateAndPresentationFields() {
        let host = CurrentSuggestionStateHost()
        host.id = "suggestion-1"
        host.textBeforeCursor = "This is "
        host.displayedText = "difficult"

        #expect(host.applyOptimisticTypeThrough(
            .matched(
                typedCharacter: "d",
                typedPrefix: "d",
                remainingText: "ifficult"
            )
        ))
        #expect(host.id == "suggestion-1")
        #expect(host.textBeforeCursor == "This is d")
        #expect(host.displayedText == "difficult")
        #expect(host.optimisticOriginalDisplayedText == "difficult")
        #expect(host.optimisticTypedPrefix == "d")
    }

    @Test("keeps invalidation state isolated to the host")
    func keepsInvalidationStateIsolatedToTheHost() {
        let first = CurrentSuggestionStateHost()
        let second = CurrentSuggestionStateHost()

        first.invalidatedByUserKeyDown = true

        #expect(first.invalidatedByUserKeyDown)
        #expect(!second.invalidatedByUserKeyDown)
    }
}
