import Foundation

public enum ClipboardFallbackRestoreDecision: Equatable, Sendable {
    case restoreOriginalPasteboard
    case preserveCurrentPasteboard
}

public struct ClipboardFallbackRestorePolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        insertedText: String,
        currentString: String?,
        fallbackChangeCount: Int,
        currentChangeCount: Int
    ) -> ClipboardFallbackRestoreDecision {
        guard !insertedText.isEmpty,
              currentString == insertedText,
              currentChangeCount == fallbackChangeCount else {
            return .preserveCurrentPasteboard
        }

        return .restoreOriginalPasteboard
    }
}
