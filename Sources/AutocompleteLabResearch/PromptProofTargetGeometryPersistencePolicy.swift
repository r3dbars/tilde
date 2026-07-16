import AutocompleteLabCore
import Foundation

public struct PromptProofTargetGeometryPersistencePolicy: Equatable, Sendable {
    public let maximumAgeMilliseconds: Int

    public init(maximumAgeMilliseconds: Int = 10_000) {
        self.maximumAgeMilliseconds = maximumAgeMilliseconds
    }

    public func shouldPreserve(
        proofModeEnabled: Bool,
        proofBundleIdentifier: String,
        proofMarker: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentSuggestionTextBeforeCursor: String?,
        currentSuggestionAgeMilliseconds: Int,
        isInvalidatedByUserTyping: Bool,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        let marker = proofMarker.trimmingCharacters(in: .whitespacesAndNewlines)
        let proofBundleIdentifier = proofBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        guard proofModeEnabled,
              !isInvalidatedByUserTyping,
              !marker.isEmpty,
              !proofBundleIdentifier.isEmpty,
              appBundleIdentifier == proofBundleIdentifier,
              fieldIdentity.bundleIdentifier == proofBundleIdentifier,
              let currentSuggestionFieldIdentity,
              currentSuggestionFieldIdentity.bundleIdentifier == proofBundleIdentifier,
              currentSuggestionFieldIdentity.processIdentifier == fieldIdentity.processIdentifier,
              currentSuggestionAgeMilliseconds <= maximumAgeMilliseconds,
              let currentSuggestionTextBeforeCursor,
              currentSuggestionTextBeforeCursor.contains(marker),
              currentSuggestionTextBeforeCursor == textBeforeCursor,
              textAfterCursor.isEmpty else {
            return false
        }

        return true
    }
}
