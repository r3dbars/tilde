import Foundation
import AutocompleteLabCore

public struct SuggestionFocusChangePolicy: Equatable, Sendable {
    public init() {}

    public func shouldHideVisibleSuggestion(
        visibleSuggestionBundleIdentifier: String?,
        activatedBundleIdentifier: String?
    ) -> Bool {
        guard let visibleSuggestionBundleIdentifier = normalizedBundleIdentifier(
            visibleSuggestionBundleIdentifier
        ) else {
            return false
        }

        guard let activatedBundleIdentifier = normalizedBundleIdentifier(activatedBundleIdentifier) else {
            return true
        }

        return activatedBundleIdentifier != visibleSuggestionBundleIdentifier
    }

    private func normalizedBundleIdentifier(_ bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            return nil
        }

        return bundleIdentifier
    }
}
