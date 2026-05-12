import Foundation

public enum SuggestionAcceptanceMode: String, Equatable, Sendable {
    case nextWord
    case allVisible
}

public struct SuggestionAcceptancePreview: Equatable, Sendable {
    public let mode: SuggestionAcceptanceMode
    public let acceptedText: String
    public let visibleTextBeforeAccept: String
    public let remainingVisibleTextAfterAccept: String
    public let acceptanceMatchesVisiblePrefix: Bool
    public let acceptanceMatchesFullVisible: Bool

    public init(
        mode: SuggestionAcceptanceMode,
        acceptedText: String,
        visibleTextBeforeAccept: String,
        remainingVisibleTextAfterAccept: String
    ) {
        self.mode = mode
        self.acceptedText = acceptedText
        self.visibleTextBeforeAccept = visibleTextBeforeAccept
        self.remainingVisibleTextAfterAccept = remainingVisibleTextAfterAccept
        acceptanceMatchesVisiblePrefix = visibleTextBeforeAccept.hasPrefix(acceptedText)
        acceptanceMatchesFullVisible = visibleTextBeforeAccept == acceptedText
    }

    public var traceMetadata: [String: String] {
        [
            "acceptanceSource": mode == .nextWord ? "visiblePrefix" : "visibleFull",
            "acceptedChars": String(acceptedText.count),
            "visibleBeforeAcceptChars": String(visibleTextBeforeAccept.count),
            "remainingVisibleAfterAcceptChars": String(remainingVisibleTextAfterAccept.count),
            "acceptanceMatchesVisiblePrefix": String(acceptanceMatchesVisiblePrefix),
            "acceptanceMatchesFullVisible": String(acceptanceMatchesFullVisible)
        ]
    }
}

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
        nextWordAcceptancePreview()?.acceptedText
    }

    public func nextWordAcceptancePreview() -> SuggestionAcceptancePreview? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.acceptedPrefix(wordLimit: 1)
        guard !acceptedText.isEmpty else {
            return nil
        }

        return acceptancePreview(
            mode: .nextWord,
            suggestion: suggestion,
            acceptedText: acceptedText
        )
    }

    public func allVisibleAcceptance() -> String? {
        allVisibleAcceptancePreview()?.acceptedText
    }

    public func allVisibleAcceptancePreview() -> SuggestionAcceptancePreview? {
        guard let suggestion = visibleSuggestion else {
            return nil
        }

        let acceptedText = suggestion.visibleText
        guard !acceptedText.isEmpty else {
            return nil
        }

        return acceptancePreview(
            mode: .allVisible,
            suggestion: suggestion,
            acceptedText: acceptedText
        )
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
                maxVisibleWords: suggestion.maxVisibleWords,
                maxVisibleCharacters: suggestion.maxVisibleCharacters
            )
        }
    }

    public mutating func commitTypedVisiblePrefix(_ typedText: String) -> Bool {
        guard let suggestion = visibleSuggestion,
              !typedText.isEmpty else {
            return false
        }

        let suggestedPrefix = suggestion.text.prefix(typedText.count)
        guard String(suggestedPrefix).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) == typedText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) else {
            return false
        }

        let remainingText = suggestion.text.dropFirst(typedText.count)

        if remainingText.isEmpty {
            visibleSuggestion = nil
        } else {
            visibleSuggestion = CompletionSuggestion(
                text: String(remainingText),
                maxVisibleWords: suggestion.maxVisibleWords,
                maxVisibleCharacters: suggestion.maxVisibleCharacters
            )
        }

        return true
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

    private func acceptancePreview(
        mode: SuggestionAcceptanceMode,
        suggestion: CompletionSuggestion,
        acceptedText: String
    ) -> SuggestionAcceptancePreview {
        SuggestionAcceptancePreview(
            mode: mode,
            acceptedText: acceptedText,
            visibleTextBeforeAccept: suggestion.visibleText,
            remainingVisibleTextAfterAccept: remainingVisibleText(
                afterAccepting: acceptedText,
                from: suggestion
            )
        )
    }

    private func remainingVisibleText(
        afterAccepting acceptedText: String,
        from suggestion: CompletionSuggestion
    ) -> String {
        guard suggestion.text.hasPrefix(acceptedText) else {
            return suggestion.visibleText
        }

        let remainingText = suggestion.text.dropFirst(acceptedText.count)
        guard !remainingText.isEmpty else {
            return ""
        }

        return CompletionSuggestion(
            text: String(remainingText),
            maxVisibleWords: suggestion.maxVisibleWords,
            maxVisibleCharacters: suggestion.maxVisibleCharacters
        ).visibleText
    }
}
