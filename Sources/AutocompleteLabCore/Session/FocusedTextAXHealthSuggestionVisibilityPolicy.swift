import Foundation

public struct FocusedTextAXHealthSuggestionVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        during cooldown: FocusedTextAXHealthCooldown,
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionHostBundleIdentifier: String? = nil,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentFieldIdentity: FocusedFieldIdentity?,
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
              !currentSuggestionBundleIdentifier.isEmpty else {
            return true
        }

        let suggestionOwnsCooldownApp = currentSuggestionBundleIdentifier == cooldown.bundleIdentifier
            || currentSuggestionHostBundleIdentifier == cooldown.bundleIdentifier
        guard suggestionOwnsCooldownApp else {
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
