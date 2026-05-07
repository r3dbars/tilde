import Foundation

public struct FocusedTextPollingThrottleSuggestionVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentFieldIdentity: FocusedFieldIdentity?,
        frontmostBundleIdentifier: String?,
        isInvalidatedByUserTyping: Bool
    ) -> Bool {
        if isInvalidatedByUserTyping {
            return true
        }

        guard let currentSuggestionBundleIdentifier,
              !currentSuggestionBundleIdentifier.isEmpty,
              let frontmostBundleIdentifier,
              !frontmostBundleIdentifier.isEmpty else {
            return true
        }

        guard currentSuggestionBundleIdentifier == frontmostBundleIdentifier else {
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
