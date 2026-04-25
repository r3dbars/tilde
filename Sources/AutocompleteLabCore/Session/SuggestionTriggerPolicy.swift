import Foundation

public struct SuggestionTriggerPolicy: Equatable, Sendable {
    public let minimumCharactersChanged: Int

    public init(minimumCharactersChanged: Int = 1) {
        self.minimumCharactersChanged = max(1, minimumCharactersChanged)
    }

    public func shouldRequestSuggestion(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String
    ) -> Bool {
        guard let previousTextBeforeCursor else {
            return true
        }

        guard previousTextBeforeCursor != currentTextBeforeCursor else {
            return false
        }

        if currentTextBeforeCursor.count < previousTextBeforeCursor.count {
            return true
        }

        let changedCount = currentTextBeforeCursor.count - previousTextBeforeCursor.count
        if changedCount >= minimumCharactersChanged, currentTextBeforeCursor.last?.isNaturalPause == true {
            return true
        }

        return changedCount >= minimumCharactersChanged
    }
}

private extension Character {
    var isNaturalPause: Bool {
        isWhitespace || [".", ",", "!", "?", ":", ";", ")", "]"].contains(self)
    }
}
