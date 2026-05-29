import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Ghostty screen copy text")
struct GhosttyScreenCopyTextTests {
    @Test("Keeps inline pasteboard text as screen text")
    func keepsInlinePasteboardTextAsScreenText() {
        let result = AppDelegate.ghosttyScreenCopyPlainText(
            from: "AUTOCOMPLETE_LAB_CLAUDE_PROOF hello"
        )

        #expect(result.text == "AUTOCOMPLETE_LAB_CLAUDE_PROOF hello")
        #expect(result.transport == "pasteboardText")
    }

    @Test("Reads Ghostty temporary screen file paths from the pasteboard")
    func readsGhosttyTemporaryScreenFilePathsFromPasteboard() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let file = directory.appendingPathComponent("ghostty-screen.txt")
        try "AUTOCOMPLETE_LAB_CLAUDE_PROOF accepted".write(to: file, atomically: true, encoding: .utf8)

        let result = AppDelegate.ghosttyScreenCopyPlainText(from: file.path)

        #expect(result.text == "AUTOCOMPLETE_LAB_CLAUDE_PROOF accepted")
        #expect(result.transport == "screenFile")
    }

    @Test("Rejects non-temporary file paths without reading them")
    func rejectsNonTemporaryFilePathsWithoutReadingThem() {
        let result = AppDelegate.ghosttyScreenCopyPlainText(from: "/Users/redbars/private-note.txt")

        #expect(result.text == "/Users/redbars/private-note.txt")
        #expect(result.transport == "filePathRejected")
    }
}
