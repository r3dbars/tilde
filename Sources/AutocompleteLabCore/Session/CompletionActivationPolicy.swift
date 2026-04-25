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

    public init(minimumContextCharacters: Int = 3) {
        self.minimumContextCharacters = max(1, minimumContextCharacters)
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

        guard textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumContextCharacters else {
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
