import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Visible suggestion acceptance coordinator")
struct VisibleSuggestionAcceptanceCoordinatorTests {
    @Test("Next word acceptance keeps the remaining suggestion and advances the baseline")
    func nextWordAcceptanceKeepsRemainingSuggestionAndAdvancesBaseline() {
        let coordinator = VisibleSuggestionAcceptanceCoordinator()
        var state = visibleState(text: " world again")

        let result = coordinator.commit(
            .nextWord,
            acceptedText: " world",
            state: &state,
            context: acceptanceContext()
        )

        #expect(result.action == .acceptNextWord)
        #expect(result.acceptedText == " world")
        #expect(result.appBundleIdentifier == "com.example.Editor")
        #expect(result.requestMode == .phraseContinuation)
        #expect(result.repetitionScope == "com.example.Editor")
        #expect(result.decisionText == "Accepted: next word")
        #expect(result.shouldRefreshVisibleSuggestion)
        #expect(result.hideReason == "accepted-next-word-final")
        #expect(result.updatedLastTextSnapshot?.textBeforeCursor == "hello world")
        #expect(state.hasVisibleSuggestion)
        #expect(state.visibleSuggestion?.visibleText == " again")
        #expect(state.textBeforeCursor == "hello world")
    }

    @Test("All visible acceptance clears the suggestion without asking for refresh")
    func allVisibleAcceptanceClearsSuggestionWithoutRefresh() {
        let coordinator = VisibleSuggestionAcceptanceCoordinator()
        var state = visibleState(text: " world")

        let result = coordinator.commit(
            .allVisible,
            acceptedText: " world",
            state: &state,
            context: acceptanceContext()
        )

        #expect(result.action == .acceptAllVisible)
        #expect(result.decisionText == "Accepted: full suggestion")
        #expect(!result.shouldRefreshVisibleSuggestion)
        #expect(result.hideReason == "accepted-all")
        #expect(result.updatedLastTextSnapshot?.textBeforeCursor == "hello world")
        #expect(!state.hasVisibleSuggestion)
        #expect(state.appBundleIdentifier == "com.example.Editor")
    }

    @Test("Next word acceptance falls back to accepted text when no snapshot matches")
    func nextWordAcceptanceFallsBackToAcceptedTextWithoutSnapshot() {
        let coordinator = VisibleSuggestionAcceptanceCoordinator()
        var state = visibleState(text: " world again")

        let result = coordinator.commit(
            .nextWord,
            acceptedText: " world",
            state: &state,
            context: VisibleSuggestionAcceptanceContext(
                currentFieldIdentity: fieldIdentity(),
                lastTextSnapshot: nil,
                fallbackBundleIdentifier: "com.example.Fallback"
            )
        )

        #expect(result.updatedLastTextSnapshot == nil)
        #expect(state.textBeforeCursor == "hello world")
        #expect(result.repetitionScope == "com.example.Editor")
    }

    private func visibleState(text: String) -> VisibleSuggestionState {
        var state = VisibleSuggestionState()
        state.present(
            CompletionSuggestion(text: text, maxVisibleWords: 3),
            suggestionID: "suggestion-1",
            appBundleIdentifier: "com.example.Editor",
            fieldIdentity: fieldIdentity(),
            requestMode: .phraseContinuation,
            textBeforeCursor: "hello"
        )
        return state
    }

    private func acceptanceContext() -> VisibleSuggestionAcceptanceContext {
        VisibleSuggestionAcceptanceContext(
            currentFieldIdentity: fieldIdentity(),
            lastTextSnapshot: FocusedTextSnapshot(
                fieldIdentity: fieldIdentity(),
                textBeforeCursor: "hello",
                textAfterCursor: ""
            ),
            fallbackBundleIdentifier: "com.example.Fallback"
        )
    }

    private func fieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }
}
