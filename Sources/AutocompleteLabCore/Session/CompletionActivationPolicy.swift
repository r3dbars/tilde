import Foundation

public struct CompletionActivationPolicy: Equatable, Sendable {
    public let minimumContextCharacters: Int

    public init(minimumContextCharacters: Int = 3) {
        self.minimumContextCharacters = max(1, minimumContextCharacters)
    }

    public func canSuggest(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        isFieldSuppressed: Bool
    ) -> Bool {
        guard !isSecure, !isFieldSuppressed else {
            return false
        }

        guard textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumContextCharacters else {
            return false
        }

        return isAtEndOfCurrentLine(textAfterCursor: textAfterCursor)
    }

    private func isAtEndOfCurrentLine(textAfterCursor: String) -> Bool {
        let currentLineSuffix = textAfterCursor.prefix { !$0.isNewline }
        return currentLineSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
