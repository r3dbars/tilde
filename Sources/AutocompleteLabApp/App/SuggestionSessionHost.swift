import AutocompleteLabCore

/// Owns the mutable visible-suggestion session while core policies decide transitions and acceptance.
@MainActor
final class SuggestionSessionHost {
    private var state = SuggestionSession()

    var visibleSuggestion: CompletionSuggestion? {
        state.visibleSuggestion
    }

    var hasVisibleSuggestion: Bool {
        state.hasVisibleSuggestion
    }

    func present(_ suggestion: CompletionSuggestion?) {
        state.present(suggestion)
    }

    func dismiss() {
        state.dismiss()
    }

    func nextWordAcceptance() -> String? {
        state.nextWordAcceptance()
    }

    func nextWordAcceptancePreview() -> SuggestionAcceptancePreview? {
        state.nextWordAcceptancePreview()
    }

    func allVisibleAcceptance() -> String? {
        state.allVisibleAcceptance()
    }

    func allVisibleAcceptancePreview() -> SuggestionAcceptancePreview? {
        state.allVisibleAcceptancePreview()
    }

    func commitNextWordAcceptance(_ acceptedText: String, keepsResidual: Bool = true) {
        state.commitNextWordAcceptance(acceptedText, keepsResidual: keepsResidual)
    }

    func commitTypedVisiblePrefix(_ typedText: String) -> Bool {
        state.commitTypedVisiblePrefix(typedText)
    }

    func commitAllVisibleAcceptance(_ acceptedText: String) {
        state.commitAllVisibleAcceptance(acceptedText)
    }

    func acceptNextWord(keepsResidual: Bool = true) -> String? {
        state.acceptNextWord(keepsResidual: keepsResidual)
    }

    func acceptAllVisible() -> String? {
        state.acceptAllVisible()
    }

    func applyTypeThrough(
        using stateMachine: TypeThroughPrefixStateMachine,
        input: TypeThroughPrefixInput
    ) -> TypeThroughPrefixTransition {
        stateMachine.apply(to: &state, input: input)
    }
}
