import Foundation

public enum SuggestionTypingProgress: Equatable, Sendable {
    case unchanged
    case typedThroughVisiblePrefix(typedSuffix: String)
    case typedOver(typedSuffix: String)
}

public struct SuggestionTypingProgressPolicy: Sendable {
    public init() {}

    public func progress(
        originalTextBeforeCursor: String,
        displayedText: String,
        newTextBeforeCursor: String
    ) -> SuggestionTypingProgress {
        guard newTextBeforeCursor.hasPrefix(originalTextBeforeCursor),
              newTextBeforeCursor != originalTextBeforeCursor else {
            return .unchanged
        }

        let typedSuffix = String(newTextBeforeCursor.dropFirst(originalTextBeforeCursor.count))
        let normalizedTyped = normalized(typedSuffix)
        guard !normalizedTyped.isEmpty else {
            return .unchanged
        }

        if normalized(displayedText).hasPrefix(normalizedTyped) {
            return .typedThroughVisiblePrefix(typedSuffix: typedSuffix)
        }

        return .typedOver(typedSuffix: typedSuffix)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
