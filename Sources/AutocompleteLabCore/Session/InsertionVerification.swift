import Foundation

public enum InsertionVerificationResult: Equatable, Sendable {
    case verified
    case unchanged
    case partial
    case changedUnexpectedly

    public var isVerified: Bool {
        self == .verified
    }
}

public struct InsertionVerification: Equatable, Sendable {
    public init() {}

    public func verify(
        previousTextBeforeCursor: String,
        acceptedText: String,
        currentTextBeforeCursor: String
    ) -> InsertionVerificationResult {
        let expectedTextBeforeCursor = previousTextBeforeCursor + acceptedText

        if currentTextBeforeCursor == expectedTextBeforeCursor {
            return .verified
        }

        if normalizeRichEditorWhitespace(currentTextBeforeCursor) == normalizeRichEditorWhitespace(expectedTextBeforeCursor) {
            return .verified
        }

        if currentTextBeforeCursor == previousTextBeforeCursor {
            return .unchanged
        }

        if expectedTextBeforeCursor.hasPrefix(currentTextBeforeCursor),
           currentTextBeforeCursor.count > previousTextBeforeCursor.count {
            return .partial
        }

        return .changedUnexpectedly
    }

    private func normalizeRichEditorWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
