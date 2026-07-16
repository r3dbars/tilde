import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Document title shape")
struct DocumentTitleShapeTests {
    @Test("Builds trace safe title shape without raw title text")
    func buildsTraceSafeTitleShapeWithoutRawTitleText() throws {
        let shape = try #require(DocumentTitleShape.from(windowTitle: "Launch Plan Edited.md *"))

        #expect(shape.wordCount == 4)
        #expect(shape.lengthBucket == .short)
        #expect(shape.fileExtension == "md")
        #expect(!shape.isUntitled)
        #expect(shape.hasUnsavedMarker)
        #expect(shape.promptGuidance.contains("Document/window title shape"))
        #expect(shape.promptGuidance.contains("file extension md"))
        #expect(!shape.promptGuidance.contains("Launch"))
        #expect(!shape.promptGuidance.contains("Plan"))
        #expect(shape.traceMetadata["documentTitleWordCount"] == "4")
        #expect(shape.traceMetadata["documentTitleExtension"] == "md")
        #expect(shape.traceMetadata["documentTitleHasUnsavedMarker"] == "true")
    }

    @Test("Detects untitled and ignores empty titles")
    func detectsUntitledAndIgnoresEmptyTitles() throws {
        let shape = try #require(DocumentTitleShape.from(windowTitle: "Untitled 41"))
        let edited = try #require(DocumentTitleShape.from(windowTitle: "scratch note edited"))

        #expect(shape.isUntitled)
        #expect(shape.fileExtension == nil)
        #expect(edited.hasUnsavedMarker)
        #expect(DocumentTitleShape.from(windowTitle: "   ") == nil)
        #expect(DocumentTitleShape.from(windowTitle: nil) == nil)
    }
}
