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
        acceptanceMatchesVisiblePrefix = Self.acceptedTextMatchesVisiblePrefix(
            acceptedText,
            visibleText: visibleTextBeforeAccept
        )
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

    private static func acceptedTextMatchesVisiblePrefix(
        _ acceptedText: String,
        visibleText: String
    ) -> Bool {
        visibleText.hasPrefix(acceptedText)
            || syntheticTrailingSpaceBase(in: acceptedText).map { visibleText == $0 } == true
    }

    private static func syntheticTrailingSpaceBase(in acceptedText: String) -> String? {
        guard acceptedText.last == " " else {
            return nil
        }

        let base = acceptedText.dropLast()
        guard !base.isEmpty,
              base.contains(where: { !$0.isWhitespace }) else {
            return nil
        }

        return String(base)
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

        let acceptedText = CompletionSuggestion.nextWordAcceptanceText(in: suggestion.text)
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
              let remainingText = remainingText(
                  afterAccepting: acceptedText,
                  from: suggestion.text
              ) else {
            return
        }

        if remainingText.isEmpty || !keepsResidual {
            visibleSuggestion = nil
        } else {
            visibleSuggestion = CompletionSuggestion(
                text: String(remainingText),
                maxVisibleWords: suggestion.maxVisibleWords
            )
        }
    }

    public mutating func commitTypedVisiblePrefix(_ typedText: String) -> Bool {
        guard let suggestion = visibleSuggestion,
              !typedText.isEmpty else {
            return false
        }

        guard let remainingText = suggestion.remainingTextAfterTypeThroughPrefix(typedText) else {
            return false
        }

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
        guard let remainingText = remainingText(afterAccepting: acceptedText, from: suggestion.text) else {
            return suggestion.visibleText
        }

        guard !remainingText.isEmpty else {
            return ""
        }

        return CompletionSuggestion(
            text: String(remainingText),
            maxVisibleWords: suggestion.maxVisibleWords
        ).visibleText
    }

    private func remainingText(
        afterAccepting acceptedText: String,
        from suggestionText: String
    ) -> Substring? {
        if suggestionText.hasPrefix(acceptedText) {
            return suggestionText.dropFirst(acceptedText.count)
        }

        guard let baseAcceptedText = Self.syntheticTrailingSpaceBase(in: acceptedText),
              suggestionText == baseAcceptedText else {
            return nil
        }

        return suggestionText.dropFirst(baseAcceptedText.count)
    }

    private static func syntheticTrailingSpaceBase(in acceptedText: String) -> String? {
        guard acceptedText.last == " " else {
            return nil
        }

        let base = acceptedText.dropLast()
        guard !base.isEmpty,
              base.contains(where: { !$0.isWhitespace }) else {
            return nil
        }

        return String(base)
    }
}
