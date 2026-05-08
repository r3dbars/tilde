import Foundation

public struct SuggestionGeometryChangePolicy: Equatable, Sendable {
    public init() {}

    public func shouldInvalidateSuggestionState(
        hasVisibleSuggestion: Bool,
        hasPendingSuggestionRequest: Bool,
        previousScreenLayoutFingerprint: String?,
        currentScreenLayoutFingerprint: String?
    ) -> Bool {
        guard hasVisibleSuggestion || hasPendingSuggestionRequest else {
            return false
        }

        guard let previous = normalizedFingerprint(previousScreenLayoutFingerprint),
              let current = normalizedFingerprint(currentScreenLayoutFingerprint) else {
            return true
        }

        return previous != current
    }

    private func normalizedFingerprint(_ fingerprint: String?) -> String? {
        guard let fingerprint = fingerprint?.trimmingCharacters(in: .whitespacesAndNewlines),
              !fingerprint.isEmpty else {
            return nil
        }

        return fingerprint
    }
}
