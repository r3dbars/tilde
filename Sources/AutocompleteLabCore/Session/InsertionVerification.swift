import Foundation

public enum InsertionVerificationResult: Equatable, Sendable {
    case verified
    case unchanged
    case partial
    case duplicateText
    case literalTab
    case selectionChangedUnexpectedly
    case insertedAtWrongLocation
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
        let textAfterCursorChanged = !previousTextAfterCursor.isEmpty
            && normalizeRichEditorWhitespace(previousTextAfterCursor)
                != normalizeRichEditorWhitespace(currentTextAfterCursor)

        if currentTextBeforeCursor == expectedTextBeforeCursor {
            if textAfterCursorChanged {
                return .selectionChangedUnexpectedly
            }
            return .verified
        }

        if normalizeRichEditorWhitespace(currentTextBeforeCursor) == normalizeRichEditorWhitespace(expectedTextBeforeCursor) {
            if textAfterCursorChanged {
                return .selectionChangedUnexpectedly
            }
            return .verified
        }

        if currentTextBeforeCursor == previousTextBeforeCursor + "\t"
            || currentTextBeforeCursor.hasPrefix(previousTextBeforeCursor + "\t") {
            return .literalTab
        }

        if currentTextBeforeCursor == previousTextBeforeCursor {
            if textAfterCursorChanged {
                return .selectionChangedUnexpectedly
            }
            return .unchanged
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

        if !acceptedText.isEmpty,
           currentTextBeforeCursor.hasPrefix(expectedTextBeforeCursor) {
            if textAfterCursorChanged {
                return .selectionChangedUnexpectedly
            }
            return .verified
        }

        if !acceptedText.isEmpty,
           normalizeRichEditorWhitespace(currentTextBeforeCursor)
               .hasPrefix(normalizeRichEditorWhitespace(expectedTextBeforeCursor)) {
            if textAfterCursorChanged {
                return .selectionChangedUnexpectedly
            }
            return .verified
        }

        if expectedTextBeforeCursor.hasPrefix(currentTextBeforeCursor),
           currentTextBeforeCursor.count > previousTextBeforeCursor.count {
            return .partial
        }

        if !acceptedText.isEmpty,
           currentTextBeforeCursor.hasSuffix(acceptedText) {
            let insertionPrefix = currentTextBeforeCursor.dropLast(acceptedText.count)

            if insertionPrefix != previousTextBeforeCursor,
               previousTextBeforeCursor.hasPrefix(insertionPrefix)
                || insertionPrefix.hasPrefix(previousTextBeforeCursor) {
                return .insertedAtWrongLocation
            }
        }

        return .changedUnexpectedly
    }

    private func normalizeRichEditorWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
