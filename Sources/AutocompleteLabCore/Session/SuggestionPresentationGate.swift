import Foundation

public enum SuggestionPresentationPhase: Equatable, Sendable {
    case immediate
    case streamingPartial
    case final
}

public struct StreamingPresentationState: Equatable, Sendable {
    public var presentedCount: Int
    public var lastVisibleText: String
    public var lastPresentedAtMilliseconds: Int?
    public var firstPartialLatencyMilliseconds: Int?
    public var lastPartialLatencyMilliseconds: Int?

    public init(
        presentedCount: Int = 0,
        lastVisibleText: String = "",
        lastPresentedAtMilliseconds: Int? = nil,
        firstPartialLatencyMilliseconds: Int? = nil,
        lastPartialLatencyMilliseconds: Int? = nil
    ) {
        self.presentedCount = presentedCount
        self.lastVisibleText = lastVisibleText
        self.lastPresentedAtMilliseconds = lastPresentedAtMilliseconds
        self.firstPartialLatencyMilliseconds = firstPartialLatencyMilliseconds
        self.lastPartialLatencyMilliseconds = lastPartialLatencyMilliseconds
    }
}

public struct SuggestionPresentationGate: Equatable, Sendable {
    public let minimumStreamingPhraseWords: Int
    public let minimumStreamingSentenceWords: Int
    public let minimumStreamingPhraseCharacterDelta: Int
    public let minimumStreamingIntervalMilliseconds: Int
    public let maximumStreamingPartialLatencyMilliseconds: Int
    public let maximumStreamingPartialPresentations: Int
    public let maximumStreamingSentencePartialPresentations: Int

    public init(
        minimumStreamingPhraseWords: Int = 2,
        minimumStreamingSentenceWords: Int = 3,
        minimumStreamingPhraseCharacterDelta: Int = 6,
        minimumStreamingIntervalMilliseconds: Int = 50,
        maximumStreamingPartialLatencyMilliseconds: Int = 750,
        maximumStreamingPartialPresentations: Int = 2,
        maximumStreamingSentencePartialPresentations: Int = 1
    ) {
        self.minimumStreamingPhraseWords = max(1, minimumStreamingPhraseWords)
        self.minimumStreamingSentenceWords = max(1, minimumStreamingSentenceWords)
        self.minimumStreamingPhraseCharacterDelta = max(1, minimumStreamingPhraseCharacterDelta)
        self.minimumStreamingIntervalMilliseconds = max(0, minimumStreamingIntervalMilliseconds)
        self.maximumStreamingPartialLatencyMilliseconds = max(1, maximumStreamingPartialLatencyMilliseconds)
        self.maximumStreamingPartialPresentations = max(1, maximumStreamingPartialPresentations)
        self.maximumStreamingSentencePartialPresentations = max(1, maximumStreamingSentencePartialPresentations)
    }

    public func shouldPresent(
        _ suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        phase: SuggestionPresentationPhase,
        previousVisibleText: String? = nil,
        minimumVisibleWordsOverride: Int? = nil
    ) -> Bool {
        guard !suggestion.isEmpty else {
            return false
        }

        guard phase == .streamingPartial,
              mode.isContinuation else {
            return true
        }

        let visibleText = normalizedVisibleText(suggestion.visibleText)
        let visibleWords = words(in: visibleText)
        guard visibleWords.count >= minimumStreamingWords(
            for: mode,
            maxVisibleWords: suggestion.maxVisibleWords,
            override: minimumVisibleWordsOverride
        ) else {
            return false
        }

        guard let previousVisibleText,
              !previousVisibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        let previousText = normalizedVisibleText(previousVisibleText)
        guard visibleText != previousText else {
            return false
        }

        let previousWords = words(in: previousText)
        if visibleWords.count == previousWords.count,
           visibleText.count - previousText.count < minimumStreamingPhraseCharacterDelta {
            return false
        }

        return true
    }

    public func shouldPresentStreamingPartial(
        _ suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        state: inout StreamingPresentationState,
        nowMilliseconds: Int,
        latencyMilliseconds: Int = 0,
        minimumVisibleWordsOverride: Int? = nil
    ) -> Bool {
        guard state.presentedCount > 0
            || latencyMilliseconds <= maximumStreamingPartialLatencyMilliseconds else {
            return false
        }

        guard shouldPresent(
            suggestion,
            mode: mode,
            phase: .streamingPartial,
            previousVisibleText: state.lastVisibleText,
            minimumVisibleWordsOverride: minimumVisibleWordsOverride
        ) else {
            return false
        }

        guard state.presentedCount < maximumStreamingPartialPresentations(for: mode) else {
            return false
        }

        if let lastPresentedAtMilliseconds = state.lastPresentedAtMilliseconds,
           nowMilliseconds - lastPresentedAtMilliseconds < minimumStreamingIntervalMilliseconds {
            return false
        }

        if state.presentedCount == 0 {
            state.firstPartialLatencyMilliseconds = latencyMilliseconds
        }
        state.presentedCount += 1
        state.lastVisibleText = suggestion.visibleText
        state.lastPresentedAtMilliseconds = nowMilliseconds
        state.lastPartialLatencyMilliseconds = latencyMilliseconds
        return true
    }

    private func normalizedVisibleText(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func words(in text: String) -> [Substring] {
        text.split(whereSeparator: { $0.isWhitespace })
    }

    private func minimumStreamingWords(
        for mode: CompletionRequestMode,
        maxVisibleWords: Int,
        override: Int?
    ) -> Int {
        if let override {
            return max(1, override)
        }

        let baseMinimum: Int
        switch mode {
        case .sentenceContinuation:
            baseMinimum = minimumStreamingSentenceWords
        case .phraseContinuation, .wordCompletion:
            baseMinimum = minimumStreamingPhraseWords
        }

        guard mode.isContinuation else {
            return baseMinimum
        }

        return max(
            baseMinimum,
            CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: maxVisibleWords)
        )
    }

    private func maximumStreamingPartialPresentations(for mode: CompletionRequestMode) -> Int {
        switch mode {
        case .sentenceContinuation:
            maximumStreamingSentencePartialPresentations
        case .phraseContinuation, .wordCompletion:
            maximumStreamingPartialPresentations
        }
    }
}
