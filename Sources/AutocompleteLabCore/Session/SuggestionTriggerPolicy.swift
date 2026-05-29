import Foundation

public enum SuggestionTriggerDecision: Equatable, Sendable {
    case skip
    case request(delayMilliseconds: Int, lane: SuggestionTimingLane = .pausePhrase)
}

public enum SuggestionTimingLane: String, Codable, Equatable, Sendable {
    case instantWord
    case pausePhrase
    case longPauseThought

    public var traceMetadata: [String: String] {
        ["suggestionTimingLane": rawValue]
    }
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
    public let minimumPhrasePauseDelayMilliseconds: Int
    public let largeTextChangeCharacterThreshold: Int
    public let largeTextChangeDelayMilliseconds: Int
    public let minimumWordCompletionCharacters: Int
    public let minimumPhraseContinuationWords: Int
    public let allowsPlainLineStartWordCompletion: Bool
    public let allowsPlainLineStartPhraseContinuation: Bool
    public let allowsListLabelPhraseContinuation: Bool
    public let allowsSentenceBoundaryRequest: Bool

    public init(
        charactersBeforePauseRequest: Int = 4,
        wordCompletionDelayMilliseconds: Int = 120,
        wordBoundaryDelayMilliseconds: Int = 180,
        softPunctuationDelayMilliseconds: Int = 220,
        structuralPunctuationDelayMilliseconds: Int = 240,
        closingPunctuationDelayMilliseconds: Int = 180,
        sentenceBoundaryDelayMilliseconds: Int = 360,
        pauseDelayMilliseconds: Int = 180,
        minimumPhrasePauseDelayMilliseconds: Int = 0,
        largeTextChangeCharacterThreshold: Int = 24,
        largeTextChangeDelayMilliseconds: Int = 250,
        minimumWordCompletionCharacters: Int = 3,
        minimumPhraseContinuationWords: Int = 4,
        allowsPlainLineStartWordCompletion: Bool = false,
        allowsPlainLineStartPhraseContinuation: Bool = false,
        allowsListLabelPhraseContinuation: Bool = false,
        allowsSentenceBoundaryRequest: Bool = false
    ) {
        self.charactersBeforePauseRequest = max(1, charactersBeforePauseRequest)
        self.wordCompletionDelayMilliseconds = wordCompletionDelayMilliseconds.clamped(to: 20...140)
        self.wordBoundaryDelayMilliseconds = wordBoundaryDelayMilliseconds.clamped(to: 20...240)
        self.softPunctuationDelayMilliseconds = softPunctuationDelayMilliseconds.clamped(to: 40...240)
        self.structuralPunctuationDelayMilliseconds = structuralPunctuationDelayMilliseconds.clamped(to: 40...240)
        self.closingPunctuationDelayMilliseconds = closingPunctuationDelayMilliseconds.clamped(to: 40...240)
        self.sentenceBoundaryDelayMilliseconds = sentenceBoundaryDelayMilliseconds.clamped(to: 60...450)
        self.pauseDelayMilliseconds = pauseDelayMilliseconds.clamped(to: 20...240)
        self.minimumPhrasePauseDelayMilliseconds = minimumPhrasePauseDelayMilliseconds.clamped(to: 0...600)
        self.largeTextChangeCharacterThreshold = max(1, largeTextChangeCharacterThreshold)
        self.largeTextChangeDelayMilliseconds = max(self.pauseDelayMilliseconds, largeTextChangeDelayMilliseconds)
        self.minimumWordCompletionCharacters = max(1, minimumWordCompletionCharacters)
        self.minimumPhraseContinuationWords = max(1, minimumPhraseContinuationWords)
        self.allowsPlainLineStartWordCompletion = allowsPlainLineStartWordCompletion
        self.allowsPlainLineStartPhraseContinuation = allowsPlainLineStartPhraseContinuation
        self.allowsListLabelPhraseContinuation = allowsListLabelPhraseContinuation
        self.allowsSentenceBoundaryRequest = allowsSentenceBoundaryRequest
    }

    public init(pace: SuggestionPace) {
        switch pace {
        case .quiet:
            self.init(
                charactersBeforePauseRequest: 6,
                wordCompletionDelayMilliseconds: 140,
                wordBoundaryDelayMilliseconds: 240,
                softPunctuationDelayMilliseconds: 240,
                structuralPunctuationDelayMilliseconds: 240,
                closingPunctuationDelayMilliseconds: 220,
                sentenceBoundaryDelayMilliseconds: 450,
                pauseDelayMilliseconds: 240,
                minimumPhrasePauseDelayMilliseconds: 360,
                largeTextChangeDelayMilliseconds: 320,
                minimumPhraseContinuationWords: 6
            )
        case .normal:
            self.init(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 70,
                wordBoundaryDelayMilliseconds: 160,
                softPunctuationDelayMilliseconds: 180,
                structuralPunctuationDelayMilliseconds: 200,
                closingPunctuationDelayMilliseconds: 140,
                sentenceBoundaryDelayMilliseconds: 260,
                pauseDelayMilliseconds: 160,
                minimumPhrasePauseDelayMilliseconds: 280,
                minimumPhraseContinuationWords: 4
            )
        case .eager:
            self.init(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 40,
                wordBoundaryDelayMilliseconds: 140,
                softPunctuationDelayMilliseconds: 180,
                structuralPunctuationDelayMilliseconds: 180,
                closingPunctuationDelayMilliseconds: 160,
                sentenceBoundaryDelayMilliseconds: 200,
                pauseDelayMilliseconds: 140,
                minimumPhrasePauseDelayMilliseconds: 260,
                minimumWordCompletionCharacters: 2,
                minimumPhraseContinuationWords: 4,
                allowsPlainLineStartWordCompletion: true,
                allowsPlainLineStartPhraseContinuation: false,
                allowsSentenceBoundaryRequest: false
            )
        }
    }

    public func shouldRequestSuggestion(
        previousTextBeforeCursor: String?,
        currentTextBeforeCursor: String,
        lineStartBehavior: SuggestionLineStartBehavior = .plain,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        requestMode: CompletionRequestMode? = nil
    ) -> Bool {
        switch decision(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor,
            lineStartBehavior: lineStartBehavior,
            behaviorProfileID: behaviorProfileID,
            requestMode: requestMode
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
        lineStartBehavior: SuggestionLineStartBehavior = .plain,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil,
        requestMode: CompletionRequestMode? = nil
    ) -> SuggestionTriggerDecision {
        if shouldSuppressAtLineStart(
            currentTextBeforeCursor,
            behavior: lineStartBehavior,
            behaviorProfileID: behaviorProfileID
        ) {
            return .skip
        }

        if requestMode == .phraseContinuation,
           contentWordCount(in: currentLine(in: currentTextBeforeCursor)) < minimumPhraseContinuationWords {
            return .skip
        }

        guard let previousTextBeforeCursor else {
            return requestDecision(delayMilliseconds: pauseDelayMilliseconds, requestMode: requestMode)
        }

        guard previousTextBeforeCursor != currentTextBeforeCursor else {
            return .skip
        }

        if currentTextBeforeCursor.count < previousTextBeforeCursor.count {
            return .skip
        }

        let changedCount = currentTextBeforeCursor.count - previousTextBeforeCursor.count
        if changedCount >= largeTextChangeCharacterThreshold {
            return requestDecision(
                delayMilliseconds: largeTextChangeDelayMilliseconds,
                requestMode: requestMode,
                laneOverride: .longPauseThought
            )
        }

        if currentTextBeforeCursor.last?.isSentenceBoundary == true {
            if allowsSentenceBoundaryRequest {
                return requestDecision(
                    delayMilliseconds: sentenceBoundaryDelayMilliseconds,
                    requestMode: requestMode,
                    laneOverride: .longPauseThought
                )
            }

            return .skip
        }

        if let punctuationDecision = punctuationBoundaryDecision(
            for: currentTextBeforeCursor,
            lineStartBehavior: lineStartBehavior,
            behaviorProfileID: behaviorProfileID,
            requestMode: requestMode
        ) {
            return punctuationDecision
        }

        if currentTextBeforeCursor.last?.isNaturalBoundary == true {
            return requestDecision(delayMilliseconds: wordBoundaryDelayMilliseconds, requestMode: requestMode)
        }

        if shouldRequestWordCompletion(previousTextBeforeCursor: previousTextBeforeCursor, currentTextBeforeCursor: currentTextBeforeCursor) {
            return .request(delayMilliseconds: wordCompletionDelayMilliseconds, lane: .instantWord)
        }

        if changedCount >= charactersBeforePauseRequest {
            return requestDecision(delayMilliseconds: pauseDelayMilliseconds, requestMode: requestMode)
        }

        return .skip
    }

    private func shouldRequestWordCompletion(previousTextBeforeCursor: String, currentTextBeforeCursor: String) -> Bool {
        guard let currentFragment = trailingWordFragment(in: currentTextBeforeCursor),
              currentFragment.count >= minimumWordCompletionCharacters,
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

    private func punctuationBoundaryDecision(
        for text: String,
        lineStartBehavior: SuggestionLineStartBehavior,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        requestMode: CompletionRequestMode?
    ) -> SuggestionTriggerDecision? {
        guard let character = text.last else {
            return nil
        }

        if behaviorProfileID == .coding, [")", "]", "}"].contains(character) {
            return .skip
        }

        if lineStartBehavior == .email,
           character == ",",
           isLikelyEmailGreetingLine(text) {
            return requestDecision(
                delayMilliseconds: sentenceBoundaryDelayMilliseconds,
                requestMode: requestMode,
                laneOverride: .longPauseThought
            )
        }

        if lineStartBehavior == .listItem,
           character == ":",
           isLikelyShortListLabel(text) {
            return requestDecision(
                delayMilliseconds: sentenceBoundaryDelayMilliseconds,
                requestMode: requestMode,
                laneOverride: .longPauseThought
            )
        }

        switch character {
        case ",", ";":
            return requestDecision(delayMilliseconds: softPunctuationDelayMilliseconds, requestMode: requestMode)
        case ":":
            return requestDecision(delayMilliseconds: structuralPunctuationDelayMilliseconds, requestMode: requestMode)
        case ")", "]", "}":
            return requestDecision(delayMilliseconds: closingPunctuationDelayMilliseconds, requestMode: requestMode)
        default:
            return nil
        }
    }

    private func requestDecision(
        delayMilliseconds: Int,
        requestMode: CompletionRequestMode?,
        laneOverride: SuggestionTimingLane? = nil
    ) -> SuggestionTriggerDecision {
        let lane = laneOverride ?? timingLane(for: requestMode)
        let delay = switch lane {
        case .instantWord:
            delayMilliseconds
        case .pausePhrase:
            max(delayMilliseconds, minimumPhrasePauseDelayMilliseconds)
        case .longPauseThought:
            max(delayMilliseconds, minimumPhrasePauseDelayMilliseconds)
        }
        return .request(delayMilliseconds: delay, lane: lane)
    }

    private func timingLane(for requestMode: CompletionRequestMode?) -> SuggestionTimingLane {
        switch requestMode {
        case .some(.wordCompletion):
            .instantWord
        case .some(.sentenceContinuation):
            .longPauseThought
        case .some(.phraseContinuation), .none:
            .pausePhrase
        }
    }

    private func shouldSuppressAtLineStart(
        _ text: String,
        behavior: SuggestionLineStartBehavior,
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> Bool {
        let currentLine = text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""

        let contentWords = contentWordCount(in: currentLine)
        if suppressesFreshParagraphStart(for: behaviorProfileID),
           isFreshParagraphStart(text),
           contentWords < 3 {
            return true
        }

        guard contentWords < 2 else {
            return false
        }

        switch behavior {
        case .plain:
            if allowsPlainLineStartWordCompletion,
               hasLineStartWordCompletionFragment(in: currentLine) {
                return false
            }

            if allowsPlainLineStartPhraseContinuation,
               hasLineStartPhraseContinuationContext(in: currentLine) {
                return false
            }

            return true
        case .listItem, .email:
            if behavior == .listItem,
               allowsListLabelPhraseContinuation,
               hasListLabelPhraseContinuationContext(in: currentLine) {
                return false
            }

            return !hasLineStartWordCompletionFragment(in: currentLine)
        }
    }

    private func suppressesFreshParagraphStart(for profileID: AutocompleteBehaviorProfileID?) -> Bool {
        guard let profileID else {
            return false
        }

        return AutocompleteBehaviorProfile.profile(profileID)
            .suppressionDefaults
            .suppressesFreshParagraphStart
    }

    private func isFreshParagraphStart(_ text: String) -> Bool {
        let lines = text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).map(String.init)

        guard lines.count >= 3,
              lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return false
        }

        return lines.dropLast().last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == true
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

        return normalized.count >= minimumWordCompletionCharacters
            && normalized.allSatisfy { $0.isLetter }
    }

    private func hasLineStartPhraseContinuationContext(in text: String) -> Bool {
        guard text.last?.isNaturalBoundary == true else {
            return false
        }

        return contentWordCount(in: text) >= 1
    }

    private func hasListLabelPhraseContinuationContext(in text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(":") else {
            return false
        }

        let words = contentWords(in: trimmed)
        return (1...4).contains(words.count)
    }

    private func isLikelyEmailGreetingLine(_ text: String) -> Bool {
        let currentLine = currentLine(in: text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = contentWords(in: currentLine)
        guard (1...3).contains(words.count),
              let firstWord = words.first else {
            return false
        }

        let greetingWords: Set<String> = ["dear", "hello", "hey", "hi", "thanks"]
        return greetingWords.contains(firstWord)
    }

    private func isLikelyShortListLabel(_ text: String) -> Bool {
        contentWords(in: currentLine(in: text)).count <= 4
    }

    private func currentLine(in text: String) -> String {
        text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""
    }

    private func contentWords(in text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
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
