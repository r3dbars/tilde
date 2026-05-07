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

    public func nextWordAcceptance() -> String? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.acceptedPrefix(wordLimit: 1)
        return acceptedText.isEmpty ? nil : acceptedText
    }

    public func allVisibleAcceptance() -> String? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.visibleText
        return acceptedText.isEmpty ? nil : acceptedText
    }

    public mutating func commitNextWordAcceptance(
        _ acceptedText: String,
        keepsResidual: Bool = true
    ) {
        guard let suggestion = visibleSuggestion,
              !acceptedText.isEmpty,
              suggestion.text.hasPrefix(acceptedText) else {
            return
        }

        let remainingText = suggestion.text.dropFirst(acceptedText.count)

        if remainingText.isEmpty || !keepsResidual {
            visibleSuggestion = nil
        } else {
            visibleSuggestion = CompletionSuggestion(
                text: String(remainingText),
                maxVisibleWords: suggestion.maxVisibleWords
            )
        }
    }

    public mutating func commitAllVisibleAcceptance(_ acceptedText: String) {
        guard let suggestion = visibleSuggestion,
              !acceptedText.isEmpty,
              suggestion.visibleText == acceptedText else {
            return
        }

        visibleSuggestion = nil
    }

    public mutating func acceptNextWord(keepsResidual: Bool = true) -> String? {
        guard let acceptedText = nextWordAcceptance() else {
            return nil
        }

        commitNextWordAcceptance(acceptedText, keepsResidual: keepsResidual)

        return acceptedText
    }

    public mutating func acceptAllVisible() -> String? {
        guard let acceptedText = allVisibleAcceptance() else {
            return nil
        }

        commitAllVisibleAcceptance(acceptedText)

        return acceptedText
    }
}
