import Foundation

public struct CursorTextSlice: Equatable, Sendable {
    public let textBeforeCursor: String
    public let textAfterCursor: String

    public init(textBeforeCursor: String, textAfterCursor: String) {
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
    }
}

public enum CursorTextSplitter {
    public static func split(_ text: String, utf16Offset: Int) -> CursorTextSlice {
        let safeOffset = max(0, min(utf16Offset, text.utf16.count))
        let cursorIndex = String.Index(utf16Offset: safeOffset, in: text)

        return CursorTextSlice(
            textBeforeCursor: String(text[..<cursorIndex]),
            textAfterCursor: String(text[cursorIndex...])
        )
    }
}
