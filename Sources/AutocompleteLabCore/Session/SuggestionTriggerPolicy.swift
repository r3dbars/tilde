import Foundation

public enum SuggestionTriggerDecision: Equatable, Sendable {
    case skip
    case request(delayMilliseconds: Int)
}

public struct SuggestionTriggerPolicy: Equatable, Sendable {
    public let charactersBeforePauseRequest: Int
    public let wordCompletionDelayMilliseconds: Int
    public let wordBoundaryDelayMilliseconds: Int
    public let pauseDelayMilliseconds: Int
    public let largeTextChangeCharacterThreshold: Int
    public let largeTextChangeDelayMilliseconds: Int

    public init(
        charactersBeforePauseRequest: Int = 4,
        wordCompletionDelayMilliseconds: Int = 0,
        wordBoundaryDelayMilliseconds: Int = 35,
        pauseDelayMilliseconds: Int = 70,
        largeTextChangeCharacterThreshold: Int = 24,
        largeTextChangeDelayMilliseconds: Int = 250
    ) {
        self.charactersBeforePauseRequest = max(1, charactersBeforePauseRequest)
        self.wordCompletionDelayMilliseconds = max(0, wordCompletionDelayMilliseconds)
        self.wordBoundaryDelayMilliseconds = max(0, wordBoundaryDelayMilliseconds)
        self.pauseDelayMilliseconds = max(0, pauseDelayMilliseconds)
        self.largeTextChangeCharacterThreshold = max(1, largeTextChangeCharacterThreshold)
        self.largeTextChangeDelayMilliseconds = max(pauseDelayMilliseconds, largeTextChangeDelayMilliseconds)
    }

    public func shouldRequestSuggestion(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String
    ) -> Bool {
        switch decision(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor
        ) {
        case .request:
            return true
        case .skip:
            return false
        }
    }

    public func decision(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String
    ) -> SuggestionTriggerDecision {
        guard let previousTextBeforeCursor else {
            return .request(delayMilliseconds: pauseDelayMilliseconds)
        }

        guard previousTextBeforeCursor != currentTextBeforeCursor else {
            return .skip
        }

        if currentTextBeforeCursor.count < previousTextBeforeCursor.count {
            return .skip
        }

        let changedCount = currentTextBeforeCursor.count - previousTextBeforeCursor.count
        if changedCount >= largeTextChangeCharacterThreshold {
            return .request(delayMilliseconds: largeTextChangeDelayMilliseconds)
        }

        if currentTextBeforeCursor.last?.isNaturalBoundary == true {
            return .request(delayMilliseconds: wordBoundaryDelayMilliseconds)
        }

        if shouldRequestWordCompletion(previousTextBeforeCursor: previousTextBeforeCursor, currentTextBeforeCursor: currentTextBeforeCursor) {
            return .request(delayMilliseconds: wordCompletionDelayMilliseconds)
        }

        if changedCount >= charactersBeforePauseRequest {
            return .request(delayMilliseconds: pauseDelayMilliseconds)
        }

        return .skip
    }

    private func shouldRequestWordCompletion(previousTextBeforeCursor: String, currentTextBeforeCursor: String) -> Bool {
        guard let currentFragment = trailingWordFragment(in: currentTextBeforeCursor),
              currentFragment.count >= 2,
              currentFragment.allSatisfy({ $0.isLetter }) else {
            return false
        }

        guard let previousFragment = trailingWordFragment(in: previousTextBeforeCursor) else {
            return previousTextBeforeCursor.last?.isNaturalBoundary == true
        }

        guard currentFragment.hasPrefix(previousFragment) || previousFragment.hasPrefix(currentFragment) else {
            return false
        }

        return currentFragment != previousFragment
    }

    private func trailingWordFragment(in text: String) -> String? {
        guard let last = text.last, !last.isWhitespace else {
            return nil
        }

        return text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }
}

private extension Character {
    var isNaturalBoundary: Bool {
        isWhitespace || [".", ",", "!", "?", ":", ";", ")", "]"].contains(self)
    }
}
