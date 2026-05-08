import Foundation

public struct SelectedTextRangeReplacement: Equatable, Sendable {
    public let text: String
    public let cursorUTF16Offset: Int
}

public enum SelectedTextRangeReplacer {
    public static func replacingSelectedRange(
        in text: String,
        utf16Location: Int,
        utf16Length: Int,
        with replacement: String
    ) -> SelectedTextRangeReplacement? {
        guard utf16Location >= 0,
              utf16Length >= 0,
              utf16Location + utf16Length <= text.utf16.count else {
            return nil
        }

        let lowerIndex = String.Index(utf16Offset: utf16Location, in: text)
        let upperIndex = String.Index(utf16Offset: utf16Location + utf16Length, in: text)
        let replacedText = String(text[..<lowerIndex]) + replacement + String(text[upperIndex...])

        return SelectedTextRangeReplacement(
            text: replacedText,
            cursorUTF16Offset: utf16Location + replacement.utf16.count
        )
    }
}
