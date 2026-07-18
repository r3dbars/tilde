import AutocompleteLabCore
import Foundation

struct SuggestionPresentationDeliveryHostInput {
    let presentationDeliveryRequest: SuggestionPresentationDeliveryRequest
    let triggerReason: String
    let traceGeometryMetadata: [String: String]
    let traceRequestMetadata: [String: String]
}

@MainActor
struct SuggestionPresentationDeliveryHostDependencies {
    let presentationDelivery: SuggestionPresentationDelivery
    let suppressionTraceHost: SuggestionPresentationSuppressionTraceHost
    let setSuggestionDecision: (String) -> Void
    let hideSuggestion: (String) -> Void
}

/// Owns panel delivery and the redacted failure handoff after presentation policy has run.
@MainActor
final class SuggestionPresentationDeliveryHost {
    private let dependencies: SuggestionPresentationDeliveryHostDependencies

    init(dependencies: SuggestionPresentationDeliveryHostDependencies) {
        self.dependencies = dependencies
    }

    func deliver(
        input: SuggestionPresentationDeliveryHostInput
    ) -> SuggestionPresentationDeliverySuccess? {
        let request = input.presentationDeliveryRequest
        switch dependencies.presentationDelivery.deliver(request) {
        case let .success(delivery):
            return delivery
        case let .failure(failure):
            let reason = failure.reason
            dependencies.setSuggestionDecision("Blocked: \(reason)")
            let traceMetadata = input.traceGeometryMetadata
                .merging(input.traceRequestMetadata) { current, _ in current }
                .merging(request.learningMetadata) { current, _ in current }
                .merging(request.placement.metadata) { current, _ in current }
                .merging(request.candidateSelectionMetadata) { current, _ in current }
                .merging(request.displayScoreMetadata) { current, _ in current }
                .merging(request.replacementMetadata) { current, _ in current }
            dependencies.suppressionTraceHost.record(
                input: SuggestionPresentationSuppressionTraceInput(
                    suggestion: request.suggestion,
                    suggestionID: request.suggestionID,
                    request: request.completionRequest,
                    context: request.context,
                    profile: request.profile,
                    fieldIdentity: request.fieldIdentity,
                    latencyMilliseconds: request.latencyMilliseconds,
                    triggerReason: input.triggerReason,
                    reason: reason,
                    traceMetadata: traceMetadata,
                    eventMetadata: ["reason": reason]
                        .merging(input.traceRequestMetadata) { current, _ in current }
                        .merging(request.learningMetadata) { current, _ in current }
                        .merging(request.placement.metadata) { current, _ in current }
                        .merging(request.candidateSelectionMetadata) { current, _ in current }
                        .merging(request.displayScoreMetadata) { current, _ in current }
                        .merging(request.replacementMetadata) { current, _ in current }
                )
            )
            dependencies.hideSuggestion(reason)
            return nil
        }
    }
}
