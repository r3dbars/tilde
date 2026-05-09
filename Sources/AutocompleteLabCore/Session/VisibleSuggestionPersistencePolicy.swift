import Foundation

public struct VisibleSuggestionPersistencePolicy: Equatable, Sendable {
    public let maximumTransientEmptyContextAgeMilliseconds: Int

    public init(maximumTransientEmptyContextAgeMilliseconds: Int = 1_200) {
        self.maximumTransientEmptyContextAgeMilliseconds = maximumTransientEmptyContextAgeMilliseconds
    }

    public func shouldPreserveAfterActivationBlock(
        blockReason: CompletionActivationBlockReason,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentSuggestionAgeMilliseconds: Int?,
        isInvalidatedByUserTyping: Bool,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        guard blockReason == .tooLittleContext,
              !isInvalidatedByUserTyping,
              textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              textAfterCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              currentSuggestionBundleIdentifier == appBundleIdentifier,
              currentSuggestionFieldIdentity == fieldIdentity,
              let currentSuggestionAgeMilliseconds,
              currentSuggestionAgeMilliseconds <= maximumTransientEmptyContextAgeMilliseconds else {
            return false
        }

        return true
    }
}
