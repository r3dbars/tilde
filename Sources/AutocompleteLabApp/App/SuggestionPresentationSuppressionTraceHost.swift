import AutocompleteLabCore
import Foundation

struct SuggestionPresentationSuppressionTraceInput {
    let suggestion: CompletionSuggestion
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let latencyMilliseconds: Int
    let triggerReason: String
    let reason: String
    let traceMetadata: [String: String]
    let eventMetadata: [String: String]
}

@MainActor
struct SuggestionPresentationSuppressionTraceHostDependencies {
    let recordSuggestionEvent: (
        String,
        FocusedTextContext,
        CompatibilityProfile,
        [String: String]
    ) -> Void
}

/// Owns the repeated redacted trace and diagnostic handoff for presentation suppression.
/// Suppression and replacement decisions remain in their tested policy owners.
@MainActor
final class SuggestionPresentationSuppressionTraceHost {
    private let dependencies: SuggestionPresentationSuppressionTraceHostDependencies

    init(dependencies: SuggestionPresentationSuppressionTraceHostDependencies) {
        self.dependencies = dependencies
    }

    func record(input: SuggestionPresentationSuppressionTraceInput) {
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: input.suggestionID,
            appBundleIdentifier: input.request.appBundleIdentifier ?? input.profile.bundleIdentifier,
            fieldIdentity: input.fieldIdentity.traceDescription,
            requestMode: input.request.mode.rawValue,
            triggerReason: input.triggerReason,
            textBeforeCursor: input.request.textBeforeCursor,
            textAfterCursor: input.request.textAfterCursor,
            displayedText: input.suggestion.visibleText,
            latencyMilliseconds: input.latencyMilliseconds,
            reason: input.reason,
            metadata: input.traceMetadata
        )
        dependencies.recordSuggestionEvent(
            "suggestion-blocked",
            input.context,
            input.profile,
            input.eventMetadata
        )
    }
}
