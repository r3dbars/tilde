import AutocompleteLabCore

struct SuggestionPresentationPlacementSuppressionInput {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let latencyMilliseconds: Int
    let triggerReason: String
    let suppression: PlacementSuppressionResolution
    let traceMetadata: [String: String]
    let eventMetadata: [String: String]
}

@MainActor
struct SuggestionPresentationPlacementHostDependencies {
    let suppressionTraceHost: SuggestionPresentationSuppressionTraceHost
    let recordPlacementUncertainty: (
        SuggestionPresentationPlacementSuppressionInput,
        String,
        [String: String]
    ) -> Void
    let setSuggestionDecision: (String) -> Void
    let hideSuggestion: (String) -> Void
}

/// Owns placement-suppression side effects after the core placement policy has decided.
@MainActor
final class SuggestionPresentationPlacementHost {
    private let dependencies: SuggestionPresentationPlacementHostDependencies

    init(dependencies: SuggestionPresentationPlacementHostDependencies) {
        self.dependencies = dependencies
    }

    func suppress(input: SuggestionPresentationPlacementSuppressionInput) {
        let reason = input.suppression.suppression.reason.rawValue
        dependencies.suppressionTraceHost.record(
            input: SuggestionPresentationSuppressionTraceInput(
                suggestion: input.suggestion,
                suggestionID: input.suggestionID,
                request: input.request,
                context: input.context,
                profile: input.profile,
                fieldIdentity: input.fieldIdentity,
                latencyMilliseconds: input.latencyMilliseconds,
                triggerReason: input.triggerReason,
                reason: reason,
                traceMetadata: input.traceMetadata,
                eventMetadata: input.eventMetadata
            )
        )
        dependencies.recordPlacementUncertainty(input, reason, input.traceMetadata)
        dependencies.setSuggestionDecision(
            "Blocked: placement \(reason)\(input.suppression.fallbackSuffix)"
        )
        dependencies.hideSuggestion("placement-\(reason)")
    }
}
