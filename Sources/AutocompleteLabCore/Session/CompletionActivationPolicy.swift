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
    case markdownCodeContext
    case selectedText
    case terminalSentenceBoundary
    case tooLittleContext
    case middleOfLine
    case unfinishedWord
}

public enum SuggestionPace: String, CaseIterable, Codable, Equatable, Sendable {
    case quiet
    case normal
    case eager

    public init(persistedRawValue: String?) {
        self = persistedRawValue.flatMap(Self.init(rawValue:)) ?? .normal
    }

    public var displayName: String {
        switch self {
        case .quiet:
            "Quiet"
        case .normal:
            "Normal"
        case .eager:
            "Proactive"
        }
    }

    public var detailText: String {
        switch self {
        case .quiet:
            "Quiet waits for more context before phrase suggestions."
        case .normal:
            "Normal starts suggestions a little sooner."
        case .eager:
            "Proactive predicts partial words quickly and starts phrase suggestions after short pauses."
        }
    }

    public func maxVisibleWords(defaultMaxVisibleWords: Int, requestMode: CompletionRequestMode) -> Int {
        defaultMaxVisibleWords
    }
}

public struct SuggestionAggressivenessPolicy: Equatable, Sendable {
    public init() {}

    public func pace(
        userPace: SuggestionPace,
        supportStatus: CompatibilitySupportStatus
    ) -> SuggestionPace {
        switch supportStatus.supportLevel {
        case .green, .yellow:
            return userPace
        case .diagnosticsOnly, .unsupported:
            return .quiet
        }
    }
}

public struct CompletionActivationPolicy: Equatable, Sendable {
    public let minimumContextCharacters: Int
    public let minimumContextWords: Int
    public let minimumPhraseContinuationWords: Int
    public let minimumWordCompletionCharacters: Int
    public let maximumWordCompletionCharacters: Int
    public let allowsTerminalSentenceBoundary: Bool
    public let allowsUnfinishedWordPhraseContinuation: Bool
    public let prefersPhraseContinuationForWordFragments: Bool

    public init(
        minimumContextCharacters: Int = 3,
        minimumContextWords: Int = 2,
        minimumPhraseContinuationWords: Int = 4,
        minimumWordCompletionCharacters: Int = 3,
        maximumWordCompletionCharacters: Int = 4,
        allowsTerminalSentenceBoundary: Bool = false,
        allowsUnfinishedWordPhraseContinuation: Bool = false,
        prefersPhraseContinuationForWordFragments: Bool = false
    ) {
        self.minimumContextCharacters = max(1, minimumContextCharacters)
        self.minimumContextWords = max(1, minimumContextWords)
        self.minimumPhraseContinuationWords = max(self.minimumContextWords, minimumPhraseContinuationWords)
        self.minimumWordCompletionCharacters = max(1, minimumWordCompletionCharacters)
        self.maximumWordCompletionCharacters = max(self.minimumWordCompletionCharacters, maximumWordCompletionCharacters)
        self.allowsTerminalSentenceBoundary = allowsTerminalSentenceBoundary
        self.allowsUnfinishedWordPhraseContinuation = allowsUnfinishedWordPhraseContinuation
        self.prefersPhraseContinuationForWordFragments = prefersPhraseContinuationForWordFragments
    }

    public init(pace: SuggestionPace) {
        switch pace {
        case .quiet:
            self.init(
                minimumContextCharacters: 6,
                minimumContextWords: 3,
                minimumPhraseContinuationWords: 6,
                minimumWordCompletionCharacters: 3,
                maximumWordCompletionCharacters: 4,
                allowsTerminalSentenceBoundary: false
            )
        case .normal:
            self.init(
                minimumContextCharacters: 2,
                minimumContextWords: 2,
                minimumPhraseContinuationWords: 4,
                minimumWordCompletionCharacters: 2,
                maximumWordCompletionCharacters: 5,
                allowsTerminalSentenceBoundary: false
            )
        case .eager:
            self.init(
                minimumContextCharacters: 1,
                minimumContextWords: 1,
                minimumPhraseContinuationWords: 4,
                minimumWordCompletionCharacters: 2,
                maximumWordCompletionCharacters: 16,
                allowsTerminalSentenceBoundary: false
            )
        }
    }

    public func canSuggest(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        selectedTextLength: Int = 0,
        isFieldSuppressed: Bool,
        fieldKind: AXFieldKind = .multilineCompose,
        allowsUnknownFieldKind: Bool = false,
        allowsTrustedProofSensitiveContent: Bool = false
    ) -> Bool {
        decision(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            isSecure: isSecure,
            selectedTextLength: selectedTextLength,
            isFieldSuppressed: isFieldSuppressed,
            fieldKind: fieldKind,
            allowsUnknownFieldKind: allowsUnknownFieldKind,
            allowsTrustedProofSensitiveContent: allowsTrustedProofSensitiveContent
        ).canSuggest
    }

    public func decision(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        selectedTextLength: Int = 0,
        isFieldSuppressed: Bool,
        fieldKind: AXFieldKind = .multilineCompose,
        allowsUnknownFieldKind: Bool = false,
        allowsTrustedProofSensitiveContent: Bool = false
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

        if fieldKind == .unknown {
            if !allowsUnknownFieldKind {
                return .block(.blockedFieldKind)
            }
        } else if fieldKind.suppressesSuggestionsByDefault {
            return .block(.blockedFieldKind)
        }

        if !allowsTrustedProofSensitiveContent,
           looksSensitive(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .block(.sensitiveContent)
        }

        if isInMarkdownCodeContext(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .block(.markdownCodeContext)
        }

        let trimmedContext = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        if !allowsTerminalSentenceBoundary, endsAtTerminalSentenceBoundary(trimmedContext) {
            return .block(.terminalSentenceBoundary)
        }

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

        if endsInsideWord(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            if isWordCompletionEligible(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
                return .allow(.wordCompletion)
            }

            if prefersPhraseContinuationForWordFragments,
               contextWordCount >= minimumPhraseContinuationWords {
                return .allow(.phraseContinuation)
            }

            if allowsUnfinishedWordPhraseContinuation,
               contextWordCount >= minimumPhraseContinuationWords {
                return .allow(.phraseContinuation)
            }

            return .block(.unfinishedWord)
        }

        if isWordCompletionEligible(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor) {
            return .allow(.wordCompletion)
        }

        guard contextWordCount >= minimumPhraseContinuationWords else {
            return .block(.tooLittleContext)
        }

        return .allow(.phraseContinuation)
    }

    private func endsAtTerminalSentenceBoundary(_ trimmedContext: String) -> Bool {
        guard let last = trimmedContext.last else {
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

        return normalized.count >= 2
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

    private func isInMarkdownCodeContext(textBeforeCursor: String, textAfterCursor: String) -> Bool {
        isInsideFencedCodeBlock(textBeforeCursor)
            || isInsideInlineCodeSpan(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor)
    }

    private func isInsideFencedCodeBlock(_ textBeforeCursor: String) -> Bool {
        let lines = textBeforeCursor.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        )
        let fenceCount = lines.reduce(0) { count, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return count + ((trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")) ? 1 : 0)
        }

        return fenceCount % 2 == 1
    }

    private func isInsideInlineCodeSpan(textBeforeCursor: String, textAfterCursor: String) -> Bool {
        let line = currentLineContext(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("```"), !trimmed.hasPrefix("~~~") else {
            return true
        }

        let before = textBeforeCursor.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""
        let backtickCount = before.reduce(0) { count, character in
            count + (character == "`" ? 1 : 0)
        }

        return backtickCount % 2 == 1
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
        "otp", "one time code", "one time password", "verification code",
        "authenticator", "2fa", "mfa", "expiration",
        "recovery code", "seed phrase", "social security", "ssn", "card number",
        "credit card", "debit card", "security code", "cvv", "cvc", "expiry",
        "routing number", "account number", "street address", "shipping address",
        "mailing address", "home address", "work address", "address line",
        "email address", "phone number", "username", "login", "web address",
        "command line", "terminal command", "shell command", "shell prompt",
        "passport number", "driver license", "drivers license", "government id",
        "date of birth", "birth date", "dob", "tax id", "taxpayer id",
        "tax return", "insurance", "policy number", "member id",
        "medical record", "health record", "patient id", "prescription",
        "diagnosis", "wallet seed", "secret recovery phrase", "mnemonic phrase"
    ]
}
