import Foundation

public struct FocusedTextPollingThrottleSuggestionVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionHostBundleIdentifier: String? = nil,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentFieldIdentity: FocusedFieldIdentity?,
        frontmostBundleIdentifier: String?,
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
              let frontmostBundleIdentifier,
              !frontmostBundleIdentifier.isEmpty else {
            return true
        }

        let suggestionOwnsFrontmostApp = currentSuggestionBundleIdentifier == frontmostBundleIdentifier
            || currentSuggestionHostBundleIdentifier == frontmostBundleIdentifier
        guard suggestionOwnsFrontmostApp else {
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
