import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Visible suggestion state")
struct VisibleSuggestionStateTests {
    @Test("Present stores visible suggestion metadata and clears stale-key flag")
    func presentStoresMetadataAndClearsInvalidation() {
        var state = VisibleSuggestionState()
        state.markInvalidatedByUserKeyDown()

        state.present(
            CompletionSuggestion(text: " world again", maxVisibleWords: 2),
            suggestionID: "suggestion-1",
            appBundleIdentifier: "com.example.Editor",
            fieldIdentity: fieldIdentity(),
            requestMode: .phraseContinuation,
            textBeforeCursor: "hello"
        )

        #expect(state.hasVisibleSuggestion)
        #expect(state.suggestionID == "suggestion-1")
        #expect(state.appBundleIdentifier == "com.example.Editor")
        #expect(state.fieldIdentity == fieldIdentity())
        #expect(state.requestMode == .phraseContinuation)
        #expect(state.textBeforeCursor == "hello")
        #expect(state.displayedText == " world again")
        #expect(!state.isInvalidatedByUserKeyDown)
    }

    @Test("Partial accept keeps metadata and updates displayed text from remaining suggestion")
    func partialAcceptKeepsMetadataAndUpdatesDisplayedText() {
        var state = visibleState(text: " world again")

        #expect(state.nextWordAcceptance() == " world")
        state.commitNextWordAcceptance(" world")
        let remaining = state.updateDisplayedTextFromVisibleSuggestion()

        #expect(remaining?.visibleText == " again")
        #expect(state.hasVisibleSuggestion)
        #expect(state.suggestionID == "suggestion-1")
        #expect(state.displayedText == " again")
    }

    @Test("Baseline advances from verified snapshot before falling back to accepted text")
    func baselineAdvancesFromSnapshotOrAcceptedText() {
        var snapshotState = visibleState(text: " world")
        snapshotState.advanceBaseline(afterAccepting: " world", snapshotTextBeforeCursor: "hello world")

        var fallbackState = visibleState(text: " world")
        fallbackState.advanceBaseline(afterAccepting: " world", snapshotTextBeforeCursor: nil)

        #expect(snapshotState.textBeforeCursor == "hello world")
        #expect(fallbackState.textBeforeCursor == "hello world")
    }

    @Test("Dismiss clears suggestion, metadata, and stale-key flag")
    func dismissClearsSuggestionMetadataAndInvalidation() {
        var state = visibleState(text: " world")
        state.markInvalidatedByUserKeyDown()

        state.dismiss()

        #expect(!state.hasVisibleSuggestion)
        #expect(state.suggestionID == nil)
        #expect(state.appBundleIdentifier == nil)
        #expect(state.fieldIdentity == nil)
        #expect(state.requestMode == nil)
        #expect(state.textBeforeCursor == nil)
        #expect(state.displayedText == nil)
        #expect(!state.isInvalidatedByUserKeyDown)
    }

    private func visibleState(text: String) -> VisibleSuggestionState {
        var state = VisibleSuggestionState()
        state.present(
            CompletionSuggestion(text: text, maxVisibleWords: 2),
            suggestionID: "suggestion-1",
            appBundleIdentifier: "com.example.Editor",
            fieldIdentity: fieldIdentity(),
            requestMode: .phraseContinuation,
            textBeforeCursor: "hello"
        )
        return state
    }

    private func fieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }
}
