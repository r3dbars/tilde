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
        currentSuggestionTextBeforeCursor: String?,
        currentSuggestionAgeMilliseconds: Int?,
        isInvalidatedByUserTyping: Bool,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        guard !isInvalidatedByUserTyping,
              currentSuggestionBundleIdentifier == appBundleIdentifier,
              currentSuggestionFieldIdentity == fieldIdentity,
              let currentSuggestionAgeMilliseconds,
              currentSuggestionAgeMilliseconds <= maximumTransientEmptyContextAgeMilliseconds else {
            return false
        }

        switch blockReason {
        case .tooLittleContext:
            return textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && textAfterCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .middleOfLine:
            return currentSuggestionTextBeforeCursor.map { textBeforeCursor + textAfterCursor == $0 } == true
        default:
            return false
        }
    }
}
