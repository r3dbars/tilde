import Foundation

public enum CompletionActivationDecision: Equatable, Sendable {
    case allow(CompletionRequestMode = .phraseContinuation)
    case block(CompletionActivationBlockReason)

    public var canSuggest: Bool {
        switch self {
        case .allow:
            return true
        case .block:
            return false
        }
    }

    public var requestMode: CompletionRequestMode? {
        switch self {
        case let .allow(mode):
            return mode
        case .block:
            return nil
        }
    }
}

public enum CompletionActivationBlockReason: String, Equatable, Sendable {
    case secureField
    case suppressedField
    case blockedFieldKind
    case sensitiveContent
    case selectedText
    case tooLittleContext
    case middleOfLine
    case unfinishedWord
}

public struct CompletionActivationPolicy: Equatable, Sendable {
    public let minimumContextCharacters: Int
    public let minimumContextWords: Int
    public let minimumPhraseContinuationWords: Int
    public let minimumWordCompletionCharacters: Int
    public let maximumWordCompletionCharacters: Int

    public init(
        minimumContextCharacters: Int = 3,
        minimumContextWords: Int = 2,
        minimumPhraseContinuationWords: Int = 4,
        minimumWordCompletionCharacters: Int = 2,
        maximumWordCompletionCharacters: Int = 4
    ) {
        self.minimumContextCharacters = max(1, minimumContextCharacters)
        self.minimumContextWords = max(1, minimumContextWords)
        self.minimumPhraseContinuationWords = max(self.minimumContextWords, minimumPhraseContinuationWords)
        self.minimumWordCompletionCharacters = max(1, minimumWordCompletionCharacters)
        self.maximumWordCompletionCharacters = max(self.minimumWordCompletionCharacters, maximumWordCompletionCharacters)
    }

    public func canSuggest(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        selectedTextLength: Int = 0,
        isFieldSuppressed: Bool,
        fieldKind: AXFieldKind = .unknown
    ) -> Bool {
        decision(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            isSecure: isSecure,
            selectedTextLength: selectedTextLength,
            isFieldSuppressed: isFieldSuppressed,
            fieldKind: fieldKind
        ).canSuggest
    }

    public func decision(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        selectedTextLength: Int = 0,
        isFieldSuppressed: Bool,
        fieldKind: AXFieldKind = .unknown
    ) -> CompletionActivationDecision {
        if isSecure || fieldKind == .secure {
            return .block(.secureField)
        }

        if selectedTextLength > 0 {
            return .block(.selectedText)
        }

        if isFieldSuppressed {
            return .block(.suppressedField)
        }

        if fieldKind.suppressesSuggestionsByDefault {
            return .block(.blockedFieldKind)
        }

        if looksSensitive(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .block(.sensitiveContent)
        }

        let trimmedContext = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextWordCount = trimmedContext.split(whereSeparator: { $0.isWhitespace }).count
        guard trimmedContext.count >= minimumContextCharacters,
              contextWordCount >= minimumContextWords else {
            if isWordCompletionEligible(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
                return .allow(.wordCompletion)
            }

            return .block(.tooLittleContext)
        }

        guard isAtEndOfCurrentLine(textAfterCursor: textAfterCursor) else {
            return .block(.middleOfLine)
        }

        if isWordCompletionEligible(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .allow(.wordCompletion)
        }

        if endsInsideWord(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .block(.unfinishedWord)
        }

        guard contextWordCount >= minimumPhraseContinuationWords else {
            return .block(.tooLittleContext)
        }

        if endsAtSentenceBoundary(textBeforeCursor: textBeforeCursor) {
            return .allow(.sentenceContinuation)
        }

        return .allow(.phraseContinuation)
    }

    private func endsAtSentenceBoundary(textBeforeCursor: String) -> Bool {
        guard let last = textBeforeCursor
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .last else {
            return false
        }

        return [".", "!", "?"].contains(last)
    }

    private func isAtEndOfCurrentLine(textAfterCursor: String) -> Bool {
        let currentLineSuffix = textAfterCursor.prefix { !$0.isNewline }
        return currentLineSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isWordCompletionEligible(textBeforeCursor: String, textAfterCursor: String) -> Bool {
        guard isAtEndOfCurrentLine(textAfterCursor: textAfterCursor),
              let last = textBeforeCursor.last,
              last.isLetter,
              let fragment = textBeforeCursor.split(whereSeparator: { $0.isWhitespace }).last else {
            return false
        }

        let normalized = fragment
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()

        guard normalized.count >= minimumWordCompletionCharacters,
              normalized.count <= maximumWordCompletionCharacters,
              normalized.allSatisfy({ $0.isLetter }) else {
            return false
        }

        return !Self.commonCompleteWords.contains(normalized)
    }

    private func endsInsideWord(textBeforeCursor: String, textAfterCursor: String) -> Bool {
        guard let last = textBeforeCursor.last, last.isLetter else {
            return false
        }

        if let next = textAfterCursor.first, next.isWhitespace {
            return false
        }

        guard let fragment = textBeforeCursor.split(whereSeparator: { $0.isWhitespace }).last else {
            return false
        }

        let normalized = fragment
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()

        return normalized.count >= minimumWordCompletionCharacters
            && normalized.allSatisfy { $0.isLetter }
    }

    private func looksSensitive(textBeforeCursor: String, textAfterCursor: String) -> Bool {
        let currentLine = currentLineContext(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor)
        let normalizedLine = currentLine
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        if Self.sensitiveLineHints.contains(where: { normalizedLine.contains($0) }) {
            return true
        }

        if currentLine.range(
            of: #"\b(sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{12,}|xox[baprs]-[A-Za-z0-9-]{12,}|AKIA[0-9A-Z]{12,})\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if currentLine.range(
            of: #"\b(?:\d[ -]*?){13,19}\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        return false
    }

    private func currentLineContext(textBeforeCursor: String, textAfterCursor: String) -> String {
        let before = textBeforeCursor.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""
        let after = textAfterCursor.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).first.map(String.init) ?? ""

        return before + after
    }

    private static let commonCompleteWords: Set<String> = [
        "a", "an", "and", "are", "as", "at",
        "be", "but", "by",
        "can", "do",
        "for", "from",
        "hey", "hi", "hello",
        "i", "if", "in", "is", "it",
        "need", "no", "not",
        "of", "on", "or",
        "so",
        "the", "then", "thing", "this", "to",
        "want", "we", "yes", "you"
    ]

    private static let sensitiveLineHints = [
        "api key", "apikey", "access token", "auth token", "bearer token",
        "client secret", "private key", "secret key", "password", "passcode",
        "recovery code", "seed phrase", "social security", "ssn", "card number",
        "credit card", "debit card", "security code", "cvv", "cvc", "expiry",
        "routing number", "account number"
    ]
}
