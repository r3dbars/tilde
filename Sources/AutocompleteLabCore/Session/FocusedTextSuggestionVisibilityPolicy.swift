public struct FocusedTextSuggestionVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionHostBundleIdentifier: String? = nil,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentFieldIdentity: FocusedFieldIdentity?,
        referenceBundleIdentifier: String?,
        isInvalidatedByUserTyping: Bool,
        currentSuggestionAgeMilliseconds: Int? = nil,
        maximumPreservedAgeMilliseconds: Int? = nil
    ) -> Bool {
        if isInvalidatedByUserTyping {
            return true
        }

        if let maximumPreservedAgeMilliseconds {
            guard let currentSuggestionAgeMilliseconds,
                  currentSuggestionAgeMilliseconds <= maximumPreservedAgeMilliseconds else {
                return true
            }
        }

        guard let currentSuggestionBundleIdentifier,
              !currentSuggestionBundleIdentifier.isEmpty,
              let referenceBundleIdentifier,
              !referenceBundleIdentifier.isEmpty else {
            return true
        }

        let suggestionOwnsReferenceApp = currentSuggestionBundleIdentifier == referenceBundleIdentifier
            || currentSuggestionHostBundleIdentifier == referenceBundleIdentifier
        guard suggestionOwnsReferenceApp else {
            return true
        }

        guard let currentSuggestionFieldIdentity,
              let currentFieldIdentity,
              currentSuggestionFieldIdentity == currentFieldIdentity else {
            return true
        }

        return false
    }
}
