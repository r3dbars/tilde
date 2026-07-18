import AutocompleteLabCore
import Foundation

@MainActor
struct SuggestionStreamingPartialHostDependencies {
    let suggestionOrchestrator: SuggestionOrchestrator
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let presentSuggestion: (CompletionSuggestion, SuggestionStreamingPartialPresentation) -> Void
}

@MainActor
struct SuggestionStreamingPartialPresentation: Equatable, Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let context: FocusedTextContext
    let profile: CompatibilityProfile
    let fieldIdentity: FocusedFieldIdentity
    let renderMode: SuggestionRenderMode
    let latencyMilliseconds: Int
    let requestTicket: SuggestionRequestTicket
    let candidateSelectionMetadata: [String: String]
}

/// Owns the first-visible streaming-partial gate and keeps native presentation in the app
/// delegate through one injected callback. Final-result suppression and continuation errors
/// remain separate until their native dependencies have their own seams.
@MainActor
final class SuggestionStreamingPartialHost {
    private let dependencies: SuggestionStreamingPartialHostDependencies

    init(dependencies: SuggestionStreamingPartialHostDependencies) {
        self.dependencies = dependencies
    }

    func handle(
        partialSuggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        requestTicket: SuggestionRequestTicket,
        requestStartedAt: Date
    ) {
        let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
        guard dependencies.suggestionOrchestrator.allows(
            requestTicket,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: dependencies.currentFieldIdentity()
        ) else {
            return
        }

        guard !partialSuggestion.isEmpty,
              !dependencies.suggestionOrchestrator.shouldSuppressRepetition(
                  partialSuggestion.visibleText,
                  mode: request.mode,
                  scope: appBundleIdentifier
              ) else {
            return
        }

        guard dependencies.suggestionOrchestrator.shouldPresentStreamingPartial(
            partialSuggestion,
            suggestionID: suggestionID,
            mode: request.mode,
            nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1000),
            latencyMilliseconds: latencyMilliseconds
        ) else {
            return
        }

        dependencies.presentSuggestion(
            partialSuggestion,
            SuggestionStreamingPartialPresentation(
                suggestionID: suggestionID,
                request: request,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                requestTicket: requestTicket,
                candidateSelectionMetadata: dependencies.suggestionOrchestrator
                    .streamingPresentationMetadata(suggestionID: suggestionID)
            )
        )
    }
}
