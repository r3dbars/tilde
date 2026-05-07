import Foundation

public enum InsertionVerificationResult: Equatable, Sendable {
    case verified
    case unchanged
    case partial
    case duplicateText
    case literalTab
    case selectionChangedUnexpectedly
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
        currentTextBeforeCursor: String,
        previousTextAfterCursor: String = "",
        currentTextAfterCursor: String = ""
    ) -> InsertionVerificationResult {
        let expectedTextBeforeCursor = previousTextBeforeCursor + acceptedText

        if currentTextBeforeCursor == expectedTextBeforeCursor {
            return .verified
        }

        if currentTextBeforeCursor == previousTextBeforeCursor + "\t"
            || currentTextBeforeCursor.hasPrefix(previousTextBeforeCursor + "\t") {
            return .literalTab
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
            if !previousTextAfterCursor.isEmpty,
               previousTextAfterCursor != currentTextAfterCursor {
                return .selectionChangedUnexpectedly
            }
            return .unchanged
        }

        if expectedTextBeforeCursor.hasPrefix(currentTextBeforeCursor),
           currentTextBeforeCursor.count > previousTextBeforeCursor.count {
            return .partial
        }

        return .changedUnexpectedly
    }
}
