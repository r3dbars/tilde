import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionContinuationFailureHostDependencies {
    let suggestionOrchestrator: SuggestionOrchestrator
    let currentSuggestionID: () -> String?
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let hasVisibleSuggestion: () -> Bool
    let setSuggestionDecision: (String) -> Void
    let repositionVisibleSuggestion: (FocusedTextContext, CompatibilityProfile) -> Void
    let updateKeyboardEventTapSnapshot: () -> Void
    let hideSuggestion: (String) -> Void
}

/// Keeps model-continuation failure cleanup together without moving native presentation or
/// latency-result decisions before their dependencies are independently isolated.
@MainActor
final class SuggestionContinuationFailureHost {
    private let dependencies: SuggestionContinuationFailureHostDependencies

    init(dependencies: SuggestionContinuationFailureHostDependencies) {
        self.dependencies = dependencies
    }

    func handle(
        suggestionID: String,
        requestTicket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        dependencies.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
        if dependencies.suggestionOrchestrator.shouldKeepVisibleSuggestionAfterModelContinuationFailure(
            suggestionID: suggestionID,
            currentSuggestionID: dependencies.currentSuggestionID(),
            ticket: requestTicket,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: dependencies.currentFieldIdentity(),
            hasVisibleSuggestion: dependencies.hasVisibleSuggestion()
        ) {
            dependencies.setSuggestionDecision("Shown: kept instant phrase after model error")
            dependencies.repositionVisibleSuggestion(context, profile)
            dependencies.updateKeyboardEventTapSnapshot()
            return
        }

        guard dependencies.suggestionOrchestrator.shouldHideVisibleSuggestionAfterFailure(
            ticket: requestTicket,
            failedRequestFieldIdentity: fieldIdentity,
            currentFieldIdentity: dependencies.currentFieldIdentity()
        ) else {
            return
        }

        dependencies.setSuggestionDecision(SuggestionStatusText.notShown(reason: "engine-error"))
        dependencies.hideSuggestion("engine-error")
    }
}
