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

    func action(
        forDisplaySuppressionReason reason: DisplayScoreSuppressionReason?,
        hasVisibleSuggestion: Bool,
        currentSuggestionInvalidatedByUserTyping: Bool = false,
        sameFieldAsCurrentSuggestion: Bool = true,
        currentSuggestionAgeMilliseconds: Int?,
        maximumPreservedAgeMilliseconds: Int
    ) -> SuggestionReplacementVisibilityAction {
        guard preservesCurrentVisibleSuggestion(forDisplaySuppressionReason: reason),
              hasVisibleSuggestion,
              !currentSuggestionInvalidatedByUserTyping,
              sameFieldAsCurrentSuggestion,
              let currentSuggestionAgeMilliseconds,
              currentSuggestionAgeMilliseconds <= max(0, maximumPreservedAgeMilliseconds) else {
            return .hide
        }

        return .keepCurrentVisible
    }

    private func preservesCurrentVisibleSuggestion(
        forDisplaySuppressionReason reason: DisplayScoreSuppressionReason?
    ) -> Bool {
        switch reason {
        case .tooSlowToDisplay, .lowConfidence, .learnedRestraint, .belowThreshold:
            return true
        case .highRisk, .highRepetition, .highInstability, .lowAcceptedAndKeptProbability, nil:
            return false
        }
    }
}
