import Foundation

public struct SuggestionSession: Equatable, Sendable {
    public private(set) var visibleSuggestion: CompletionSuggestion?

    public init(visibleSuggestion: CompletionSuggestion? = nil) {
        self.visibleSuggestion = visibleSuggestion
    }

    public var hasVisibleSuggestion: Bool {
        visibleSuggestion != nil
    }

    public mutating func present(_ suggestion: CompletionSuggestion?) {
        visibleSuggestion = suggestion
    }

    public mutating func dismiss() {
        visibleSuggestion = nil
    }

    public mutating func acceptNextWord() -> String? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.acceptedPrefix(wordLimit: 1)
        let remainingText = suggestion.text.dropFirst(acceptedText.count)

        if remainingText.isEmpty {
            visibleSuggestion = nil
        } else {
            visibleSuggestion = CompletionSuggestion(
                text: String(remainingText),
                maxVisibleWords: suggestion.maxVisibleWords
            )
        }

        return acceptedText.isEmpty ? nil : acceptedText
    }

    public mutating func acceptAllVisible() -> String? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.visibleText
        visibleSuggestion = nil

        return acceptedText.isEmpty ? nil : acceptedText
    }
}
