import Testing
@testable import AutocompleteLabCore

@Suite("Partial word shape")
struct PartialWordShapeTests {
    @Test("Builds shape without keeping raw partial text")
    func buildsShapeWithoutKeepingRawPartialText() throws {
        let shape = try #require(PartialWordShape.from(textBeforeCursor: "Please open Transcrip"))

        #expect(shape.characterCount == 9)
        #expect(shape.letterCount == 9)
        #expect(shape.digitCount == 0)
        #expect(shape.casing == .titlecase)
        #expect(shape.traceMetadata["partialWordCharacters"] == "9")
        #expect(shape.traceMetadata["partialWordCasing"] == "titlecase")
        #expect(!shape.traceMetadata.values.joined(separator: " ").contains("Transcrip"))
        #expect(shape.promptGuidance.contains("9 characters"))
        #expect(shape.promptGuidance.contains("titlecase casing"))
    }

    @Test("Ignores completed boundary text")
    func ignoresCompletedBoundaryText() {
        #expect(PartialWordShape.from(textBeforeCursor: "Please open ") == nil)
        #expect(PartialWordShape.from(textBeforeCursor: "Please open,") == nil)
    }
}
