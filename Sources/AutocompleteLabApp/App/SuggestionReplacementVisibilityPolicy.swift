import AutocompleteLabCore

enum SuggestionReplacementVisibilityAction: Equatable {
    case presentProposed
    case keepCurrentVisible
    case hide
}

struct SuggestionReplacementVisibilityPolicy: Equatable {
    func action(
        for decision: SuggestionReplacementDecision,
        hasVisibleSuggestion: Bool,
        currentSuggestionInvalidatedByUserTyping: Bool = false
    ) -> SuggestionReplacementVisibilityAction {
        if decision.shouldPresent {
            return .presentProposed
        }

        if currentSuggestionInvalidatedByUserTyping {
            return .hide
        }

        return hasVisibleSuggestion ? .keepCurrentVisible : .hide
    }
}
