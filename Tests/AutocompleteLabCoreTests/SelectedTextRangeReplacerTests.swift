import Testing
@testable import AutocompleteLabCore

@Suite("Selected text range replacer")
struct SelectedTextRangeReplacerTests {
    @Test("Inserts text at the UTF-16 cursor offset")
    func insertsAtCursor() {
        let replacement = SelectedTextRangeReplacer.replacingSelectedRange(
            in: "Can we",
            utf16Location: 6,
            utf16Length: 0,
            with: " make"
        )

        #expect(replacement?.text == "Can we make")
        #expect(replacement?.cursorUTF16Offset == 11)
    }

    @Test("Replaces selected text without changing surrounding emoji")
    func replacesSelectionWithEmojiNearby() {
        let text = "Hi 👋 friend"
        let replacement = SelectedTextRangeReplacer.replacingSelectedRange(
            in: text,
            utf16Location: 6,
            utf16Length: 6,
            with: "there"
        )

        #expect(replacement?.text == "Hi 👋 there")
        #expect(replacement?.cursorUTF16Offset == 11)
    }

    @Test("Rejects ranges outside the string")
    func rejectsInvalidRanges() {
        #expect(SelectedTextRangeReplacer.replacingSelectedRange(
            in: "Can we",
            utf16Location: 20,
            utf16Length: 0,
            with: " make"
        ) == nil)
    }
}
