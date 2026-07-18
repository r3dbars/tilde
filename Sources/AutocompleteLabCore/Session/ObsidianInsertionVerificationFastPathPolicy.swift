public struct ObsidianInsertionVerificationFastPathPolicy: Equatable, Sendable {
    public init() {}

    public func canVerifyLengthMatchedSuffix(
        appBundleIdentifier: String,
        previousTextBeforeCursor: String,
        acceptedText: String,
        currentTextBeforeCursor: String,
        previousTextAfterCursor: String,
        currentTextAfterCursor: String,
        verificationResult: InsertionVerificationResult
    ) -> Bool {
        guard appBundleIdentifier == "md.obsidian",
              verificationResult == .changedUnexpectedly,
              !acceptedText.isEmpty,
              acceptedText.utf16.count <= 24,
              previousTextBeforeCursor.utf16.count >= 120,
              previousTextAfterCursor.isEmpty,
              currentTextAfterCursor.isEmpty,
              currentTextBeforeCursor.utf16.count == previousTextBeforeCursor.utf16.count + acceptedText.utf16.count,
              currentTextBeforeCursor.hasSuffix(acceptedText) else {
            return false
        }

        return true
    }
}
