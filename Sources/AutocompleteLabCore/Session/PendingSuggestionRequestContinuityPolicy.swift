public struct PendingSuggestionRequestContinuityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldPreserve(
        hasPendingRequest: Bool,
        requestTextBeforeCursor: String?,
        requestTextAfterCursor: String?,
        requestFieldIdentityDescription: String?,
        currentTextBeforeCursor: String,
        currentTextAfterCursor: String,
        currentFieldIdentityDescription: String
    ) -> Bool {
        guard hasPendingRequest,
              let requestTextBeforeCursor,
              let requestTextAfterCursor,
              let requestFieldIdentityDescription else {
            return false
        }

        return currentTextBeforeCursor.hasPrefix(requestTextBeforeCursor)
            && currentTextAfterCursor == requestTextAfterCursor
            && currentFieldIdentityDescription == requestFieldIdentityDescription
    }
}
