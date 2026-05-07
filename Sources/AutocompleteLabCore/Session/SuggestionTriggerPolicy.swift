import Foundation

public enum SuggestionTriggerDecision: Equatable, Sendable {
    case skip
    case request(delayMilliseconds: Int)
}

public enum SuggestionLineStartBehavior: Equatable, Sendable {
    case plain
    case listItem
    case email

    public static func behavior(
        for profileID: AutocompleteBehaviorProfileID?,
        currentLineStructure: CurrentLineStructure?
    ) -> SuggestionLineStartBehavior {
        if currentLineStructure?.isListLike == true {
            return .listItem
        }

        if profileID == .email {
            return .email
        }

        return .plain
    }
}

public struct SuggestionTriggerPolicy: Equatable, Sendable {
    public let charactersBeforePauseRequest: Int
    public let wordCompletionDelayMilliseconds: Int
    public let wordBoundaryDelayMilliseconds: Int
    public let softPunctuationDelayMilliseconds: Int
    public let structuralPunctuationDelayMilliseconds: Int
    public let closingPunctuationDelayMilliseconds: Int
    public let sentenceBoundaryDelayMilliseconds: Int
    public let pauseDelayMilliseconds: Int
    public let largeTextChangeCharacterThreshold: Int
    public let largeTextChangeDelayMilliseconds: Int

    public init(
        charactersBeforePauseRequest: Int = 4,
        wordCompletionDelayMilliseconds: Int = 120,
        wordBoundaryDelayMilliseconds: Int = 180,
        softPunctuationDelayMilliseconds: Int = 220,
        structuralPunctuationDelayMilliseconds: Int = 240,
        closingPunctuationDelayMilliseconds: Int = 180,
        sentenceBoundaryDelayMilliseconds: Int = 360,
        pauseDelayMilliseconds: Int = 180,
        largeTextChangeCharacterThreshold: Int = 24,
        largeTextChangeDelayMilliseconds: Int = 250
    ) {
        self.charactersBeforePauseRequest = max(1, charactersBeforePauseRequest)
        self.wordCompletionDelayMilliseconds = wordCompletionDelayMilliseconds.clamped(to: 90...140)
        self.wordBoundaryDelayMilliseconds = wordBoundaryDelayMilliseconds.clamped(to: 140...240)
        self.softPunctuationDelayMilliseconds = softPunctuationDelayMilliseconds.clamped(to: 140...240)
        self.structuralPunctuationDelayMilliseconds = structuralPunctuationDelayMilliseconds.clamped(to: 140...240)
        self.closingPunctuationDelayMilliseconds = closingPunctuationDelayMilliseconds.clamped(to: 140...240)
        self.sentenceBoundaryDelayMilliseconds = sentenceBoundaryDelayMilliseconds.clamped(to: 280...450)
        self.pauseDelayMilliseconds = pauseDelayMilliseconds.clamped(to: 140...240)
        self.largeTextChangeCharacterThreshold = max(1, largeTextChangeCharacterThreshold)
        self.largeTextChangeDelayMilliseconds = max(self.pauseDelayMilliseconds, largeTextChangeDelayMilliseconds)
    }

    public func shouldRequestSuggestion(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        lineStartBehavior: SuggestionLineStartBehavior = .plain
    ) -> Bool {
        switch decision(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor,
            lineStartBehavior: lineStartBehavior
        ) {
        case .request:
            return true
        case .skip:
            return false
        }
    }

    public func decision(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        lineStartBehavior: SuggestionLineStartBehavior = .plain
    ) -> SuggestionTriggerDecision {
        if shouldSuppressAtLineStart(
            currentTextBeforeCursor,
            behavior: lineStartBehavior
        ) {
            return .skip
        }

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

        if currentTextBeforeCursor.last?.isSentenceBoundary == true {
            return .request(delayMilliseconds: sentenceBoundaryDelayMilliseconds)
        }

        if let punctuationDelay = punctuationBoundaryDelay(for: currentTextBeforeCursor.last) {
            return .request(delayMilliseconds: punctuationDelay)
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
              currentFragment.count >= 3,
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

    private func punctuationBoundaryDelay(for character: Character?) -> Int? {
        switch character {
        case ",", ";":
            return softPunctuationDelayMilliseconds
        case ":":
            return structuralPunctuationDelayMilliseconds
        case ")", "]", "}":
            return closingPunctuationDelayMilliseconds
        default:
            return nil
        }
    }

    private func shouldSuppressAtLineStart(
        _ text: String,
        behavior: SuggestionLineStartBehavior
    ) -> Bool {
        let currentLine = text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""

        let contentWords = contentWordCount(in: currentLine)
        guard contentWords < 2 else {
            return false
        }

        switch behavior {
        case .plain:
            return true
        case .listItem, .email:
            return !hasLineStartWordCompletionFragment(in: currentLine)
        }
    }

    private func contentWordCount(in text: String) -> Int {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .map { word in
                word.trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { word in
                word.contains(where: { $0.isLetter })
            }
            .count
    }

    private func trailingWordFragment(in text: String) -> String? {
        guard let last = text.last, !last.isWhitespace else {
            return nil
        }

        return text.split(whereSeparator: { $0.isWhitespace }).last.map(String.init)
    }

    private func hasLineStartWordCompletionFragment(in text: String) -> Bool {
        guard let fragment = trailingWordFragment(in: text),
              text.last?.isLetter == true else {
            return false
        }

        let normalized = fragment
            .trimmingCharacters(in: .punctuationCharacters)

        return normalized.count >= 3
            && normalized.allSatisfy { $0.isLetter }
    }
}

private extension Character {
    var isSentenceBoundary: Bool {
        [".", "!", "?"].contains(self)
    }

    var isNaturalBoundary: Bool {
        isWhitespace || [".", ",", "!", "?", ":", ";", ")", "]", "}"].contains(self)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
