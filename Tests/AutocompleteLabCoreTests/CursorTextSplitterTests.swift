import Testing
@testable import AutocompleteLabCore

@Suite("Cursor text splitter")
struct CursorTextSplitterTests {
    @Test("Splits ASCII text at UTF-16 cursor offset")
    func splitsASCIIText() {
        let slice = CursorTextSplitter.split("hello world", utf16Offset: 5)

        #expect(slice.textBeforeCursor == "hello")
        #expect(slice.textAfterCursor == " world")
    }

    @Test("Clamps negative cursor offsets")
    func clampsNegativeOffsets() {
        let slice = CursorTextSplitter.split("hello", utf16Offset: -10)

        #expect(slice.textBeforeCursor == "")
        #expect(slice.textAfterCursor == "hello")
    }

    @Test("Clamps cursor offsets past the end")
    func clampsPastEndOffsets() {
        let slice = CursorTextSplitter.split("hello", utf16Offset: 100)

        #expect(slice.textBeforeCursor == "hello")
        #expect(slice.textAfterCursor == "")
    }

    @Test("Splits text containing emoji using UTF-16 offsets")
    func splitsEmojiText() {
        let text = "hi 👋 there"
        let offsetAfterEmoji = "hi 👋".utf16.count
        let slice = CursorTextSplitter.split(text, utf16Offset: offsetAfterEmoji)

        #expect(slice.textBeforeCursor == "hi 👋")
        #expect(slice.textAfterCursor == " there")
    }
}
