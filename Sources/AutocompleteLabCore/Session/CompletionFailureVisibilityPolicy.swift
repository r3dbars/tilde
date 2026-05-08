import Foundation

public struct CompletionFailureVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        requestGate: SuggestionRequestGate,
        ticket: SuggestionRequestTicket,
        currentRequest: CompletionRequest?,
        failedRequestFieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        requestGate.allows(ticket, currentRequest: currentRequest)
            && currentFieldIdentity == failedRequestFieldIdentity
    }
}
