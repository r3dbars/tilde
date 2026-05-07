import Foundation

public enum InsertionVerificationResult: Equatable, Sendable {
    case verified
    case unchanged
    case partial
    case duplicateText
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

        if !acceptedText.isEmpty,
           currentTextBeforeCursor == expectedTextBeforeCursor + acceptedText {
            return .duplicateText
        }

        if !acceptedText.isEmpty,
           currentTextBeforeCursor.hasPrefix(expectedTextBeforeCursor),
           currentTextBeforeCursor.dropFirst(expectedTextBeforeCursor.count).hasPrefix(acceptedText) {
            return .duplicateText
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
}
