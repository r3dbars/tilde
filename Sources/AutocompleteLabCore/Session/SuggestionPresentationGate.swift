import Foundation

public enum SuggestionPresentationPhase: Equatable, Sendable {
    case immediate
    case streamingPartial
    case final
}

public struct SuggestionPresentationGate: Equatable, Sendable {
    public let minimumStreamingPhraseWords: Int
    public let minimumStreamingPhraseCharacterDelta: Int

    public init(
        minimumStreamingPhraseWords: Int = 2,
        minimumStreamingPhraseCharacterDelta: Int = 3
    ) {
        self.minimumStreamingPhraseWords = max(1, minimumStreamingPhraseWords)
        self.minimumStreamingPhraseCharacterDelta = max(1, minimumStreamingPhraseCharacterDelta)
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
