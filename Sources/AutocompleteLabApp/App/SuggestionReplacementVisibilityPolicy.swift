import AutocompleteLabCore

enum SuggestionReplacementVisibilityAction: Equatable {
    case presentProposed
    case keepCurrentVisible
    case hide
}

struct SuggestionReplacementVisibilityPolicy: Equatable {
    func action(
        for decision: SuggestionReplacementDecision,
        hasVisibleSuggestion: Bool
    ) -> SuggestionReplacementVisibilityAction {
        if decision.shouldPresent {
            return .presentProposed
        }

        return hasVisibleSuggestion ? .keepCurrentVisible : .hide
    }
}
