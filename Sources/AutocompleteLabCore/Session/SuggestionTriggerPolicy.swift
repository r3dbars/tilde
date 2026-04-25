import Foundation

public enum SuggestionTriggerDecision: Equatable, Sendable {
    case skip
    case request(delayMilliseconds: Int)
}

public struct SuggestionTriggerPolicy: Equatable, Sendable {
    public let charactersBeforePauseRequest: Int
    public let wordBoundaryDelayMilliseconds: Int
    public let pauseDelayMilliseconds: Int

    public init(
        charactersBeforePauseRequest: Int = 4,
        wordBoundaryDelayMilliseconds: Int = 80,
        pauseDelayMilliseconds: Int = 180
    ) {
        self.charactersBeforePauseRequest = max(1, charactersBeforePauseRequest)
        self.wordBoundaryDelayMilliseconds = max(0, wordBoundaryDelayMilliseconds)
        self.pauseDelayMilliseconds = max(0, pauseDelayMilliseconds)
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
            return .request(delayMilliseconds: pauseDelayMilliseconds)
        }

        let changedCount = currentTextBeforeCursor.count - previousTextBeforeCursor.count
        if currentTextBeforeCursor.last?.isNaturalBoundary == true {
            return .request(delayMilliseconds: wordBoundaryDelayMilliseconds)
        }

        if changedCount >= charactersBeforePauseRequest {
            return .request(delayMilliseconds: pauseDelayMilliseconds)
        }

        return .skip
    }
}

private extension Character {
    var isNaturalBoundary: Bool {
        isWhitespace || [".", ",", "!", "?", ":", ";", ")", "]"].contains(self)
    }
}
