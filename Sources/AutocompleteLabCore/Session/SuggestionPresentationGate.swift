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

    public init(
        presentedCount: Int = 0,
        lastVisibleText: String = "",
        lastPresentedAtMilliseconds: Int? = nil
    ) {
        self.presentedCount = presentedCount
        self.lastVisibleText = lastVisibleText
        self.lastPresentedAtMilliseconds = lastPresentedAtMilliseconds
    }
}

public struct SuggestionPresentationGate: Equatable, Sendable {
    public let minimumStreamingPhraseWords: Int
    public let minimumStreamingPhraseCharacterDelta: Int
    public let minimumStreamingIntervalMilliseconds: Int
    public let maximumStreamingPartialPresentations: Int

    public init(
        minimumStreamingPhraseWords: Int = 2,
        minimumStreamingPhraseCharacterDelta: Int = 6,
        minimumStreamingIntervalMilliseconds: Int = 50,
        maximumStreamingPartialPresentations: Int = 2
    ) {
        self.minimumStreamingPhraseWords = max(1, minimumStreamingPhraseWords)
        self.minimumStreamingPhraseCharacterDelta = max(1, minimumStreamingPhraseCharacterDelta)
        self.minimumStreamingIntervalMilliseconds = max(0, minimumStreamingIntervalMilliseconds)
        self.maximumStreamingPartialPresentations = max(1, maximumStreamingPartialPresentations)
    }

    public func shouldPresent(
        _ suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        phase: SuggestionPresentationPhase,
        previousVisibleText: String? = nil
    ) -> Bool {
        guard !suggestion.isEmpty else {
            return false
        }

        guard phase == .streamingPartial,
              mode == .phraseContinuation else {
            return true
        }

        let visibleText = normalizedVisibleText(suggestion.visibleText)
        let visibleWords = words(in: visibleText)
        guard visibleWords.count >= minimumStreamingPhraseWords else {
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
        nowMilliseconds: Int
    ) -> Bool {
        guard shouldPresent(
            suggestion,
            mode: mode,
            phase: .streamingPartial,
            previousVisibleText: state.lastVisibleText
        ) else {
            return false
        }

        guard state.presentedCount < maximumStreamingPartialPresentations else {
            return false
        }

        if let lastPresentedAtMilliseconds = state.lastPresentedAtMilliseconds,
           nowMilliseconds - lastPresentedAtMilliseconds < minimumStreamingIntervalMilliseconds {
            return false
        }

        state.presentedCount += 1
        state.lastVisibleText = suggestion.visibleText
        state.lastPresentedAtMilliseconds = nowMilliseconds
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
}
