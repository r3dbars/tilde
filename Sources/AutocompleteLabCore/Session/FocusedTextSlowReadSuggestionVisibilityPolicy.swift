import Foundation

/// Whether a visible suggestion should be hidden when the focused-text read path is
/// degraded for some app — either because that app's AX reads are cooling down, or
/// because the shared poll timer just throttled itself after a slow read.
///
/// Both prior call sites asked the identical question ("does the visible suggestion
/// still belong to the app/field that's degraded right now?") differing only in how
/// they identified the degraded app: an AX-health cooldown carries its own
/// `bundleIdentifier`, while the polling throttle looked at whichever app is
/// currently frontmost. This unifies both behind one `degradedBundleIdentifier`
/// input so there is a single decision function instead of two near-identical ones.
public struct FocusedTextSlowReadSuggestionVisibilityPolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        degradedBundleIdentifier: String?,
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
              !currentSuggestionBundleIdentifier.isEmpty,
              let degradedBundleIdentifier,
              !degradedBundleIdentifier.isEmpty else {
            return true
        }

        let suggestionOwnsDegradedApp = currentSuggestionBundleIdentifier == degradedBundleIdentifier
            || currentSuggestionHostBundleIdentifier == degradedBundleIdentifier
        guard suggestionOwnsDegradedApp else {
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
