import Foundation

public enum CompletionActivationDecision: Equatable, Sendable {
    case allow
    case block(CompletionActivationBlockReason)

    public var canSuggest: Bool {
        self == .allow
    }
}

public enum CompletionActivationBlockReason: String, Equatable, Sendable {
    case secureField
    case suppressedField
    case tooLittleContext
    case middleOfLine
}

public struct CompletionActivationPolicy: Equatable, Sendable {
    public let minimumContextCharacters: Int
    public let minimumContextWords: Int

    public init(minimumContextCharacters: Int = 3, minimumContextWords: Int = 2) {
        self.minimumContextCharacters = max(1, minimumContextCharacters)
        self.minimumContextWords = max(1, minimumContextWords)
    }

    public func canSuggest(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        isFieldSuppressed: Bool
    ) -> Bool {
        decision(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            isSecure: isSecure,
            isFieldSuppressed: isFieldSuppressed
        ).canSuggest
    }

    public func decision(
        textBeforeCursor: String,
        textAfterCursor: String,
        isSecure: Bool,
        isFieldSuppressed: Bool
    ) -> CompletionActivationDecision {
        if isSecure {
            return .block(.secureField)
        }

        if isFieldSuppressed {
            return .block(.suppressedField)
        }

        let trimmedContext = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContext.count >= minimumContextCharacters,
              trimmedContext.split(whereSeparator: { $0.isWhitespace }).count >= minimumContextWords else {
            return .block(.tooLittleContext)
        }

        guard isAtEndOfCurrentLine(textAfterCursor: textAfterCursor) else {
            return .block(.middleOfLine)
        }

        return .allow
    }

    private func isAtEndOfCurrentLine(textAfterCursor: String) -> Bool {
        let currentLineSuffix = textAfterCursor.prefix { !$0.isNewline }
        return currentLineSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
