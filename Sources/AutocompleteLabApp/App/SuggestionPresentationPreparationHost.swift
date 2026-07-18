import AutocompleteLabCore

enum SuggestionPresentationPreparationResult {
    case ready(SuggestionPresentationPreparedSuggestion)
    case invalid(LateResultContextInvalidationReason)
    case typedThroughVisiblePrefix
}

struct SuggestionPresentationPreparedSuggestion {
    let suggestion: CompletionSuggestion
    let visualTrustContext: CompatibilityLearningVisualTrustContext
    let learningAdjustment: CompatibilityLearningAdjustment
    let placementPlan: PlacementHealthPlan
}

struct SuggestionPresentationPreparationInput {
    let suggestion: CompletionSuggestion
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let renderMode: SuggestionRenderMode
    let latencyMilliseconds: Int
    let screenshotTracingEnabled: Bool
}

@MainActor
struct SuggestionPresentationPreparationHostDependencies {
    let compatibilityLearningStore: CompatibilityLearningStore
    let visualTrustContext: (FocusedTextContext, String) -> CompatibilityLearningVisualTrustContext
    let placementHealthPlan: (
        FocusedTextContext,
        CompatibilityProfile,
        CompatibilityLearningAdjustment,
        Bool
    ) -> PlacementHealthPlan
}

/// Owns late-result validation and presentation preparation while native rendering stays outside.
@MainActor
final class SuggestionPresentationPreparationHost {
    private let dependencies: SuggestionPresentationPreparationHostDependencies

    init(dependencies: SuggestionPresentationPreparationHostDependencies) {
        self.dependencies = dependencies
    }

    func prepare(
        input: SuggestionPresentationPreparationInput
    ) -> SuggestionPresentationPreparationResult {
        let requestSnapshot = FocusedTextSnapshot(
            fieldIdentity: input.fieldIdentity,
            textBeforeCursor: input.request.textBeforeCursor,
            textAfterCursor: input.request.textAfterCursor
        )
        let currentSnapshot = FocusedTextSnapshot(
            fieldIdentity: input.fieldIdentity,
            textBeforeCursor: input.context.textBeforeCursor,
            textAfterCursor: input.context.textAfterCursor
        )
        let validator = LateResultContextValidator()
        let typedSinceRequest: String
        switch validator.validate(
            requestSnapshot: requestSnapshot,
            currentSnapshot: currentSnapshot,
            latencyMilliseconds: input.latencyMilliseconds
        ) {
        case let .stillValid(typedDelta):
            typedSinceRequest = typedDelta
        case let .invalid(reason):
            return .invalid(reason)
        }

        guard let suggestion = validator.trimmedSuggestion(
            input.suggestion,
            typedSinceRequest: typedSinceRequest
        ) else {
            return .typedThroughVisiblePrefix
        }

        let storedLearningAdjustment = dependencies.compatibilityLearningStore.engine().adjustment(
            for: input.profile.bundleIdentifier,
            profileRenderMode: input.renderMode
        )
        let visualTrustContext = dependencies.visualTrustContext(
            input.context,
            input.profile.bundleIdentifier
        )
        let learningAdjustment = storedLearningAdjustment.trustedVisualOffsetOnly(
            context: visualTrustContext
        )
        let placementPlan = dependencies.placementHealthPlan(
            input.context,
            input.profile,
            learningAdjustment,
            input.screenshotTracingEnabled
        )
        return .ready(
            SuggestionPresentationPreparedSuggestion(
                suggestion: suggestion,
                visualTrustContext: visualTrustContext,
                learningAdjustment: learningAdjustment,
                placementPlan: placementPlan
            )
        )
    }
}
