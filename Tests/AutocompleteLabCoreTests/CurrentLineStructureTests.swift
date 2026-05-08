import Testing
@testable import AutocompleteLabCore

@Suite("Current line structure")
struct CurrentLineStructureTests {
    @Test("Detects markdown bullet shape without item text")
    func detectsMarkdownBulletShapeWithoutItemText() throws {
        let structure = try #require(CurrentLineStructure.from(textBeforeCursor: "Plan\n  - New pla"))

        #expect(structure.kind == .bullet)
        #expect(structure.markerStyle == .dash)
        #expect(structure.indentationColumns == 2)
        #expect(structure.contentWordCount == 2)
        #expect(structure.traceMetadata["currentLineStructure"] == "bullet")
        #expect(structure.traceMetadata["currentLineMarkerStyle"] == "dash")
        #expect(!structure.traceMetadata.values.joined(separator: " ").contains("New"))
        #expect(!structure.promptGuidance.contains("New pla"))
    }

    @Test("Detects numbered list marker styles")
    func detectsNumberedListMarkerStyles() throws {
        let dot = try #require(CurrentLineStructure.from(textBeforeCursor: "1. First thi"))
        let paren = try #require(CurrentLineStructure.from(textBeforeCursor: "12) First thi"))

        #expect(dot.kind == .numbered)
        #expect(dot.markerStyle == .numberedDot)
        #expect(paren.kind == .numbered)
        #expect(paren.markerStyle == .numberedParen)
    }

    @Test("Detects checklist state with marker style")
    func detectsChecklistStateWithMarkerStyle() throws {
        let unchecked = try #require(CurrentLineStructure.from(textBeforeCursor: "- [ ] Follow u"))
        let checked = try #require(CurrentLineStructure.from(textBeforeCursor: "* [x] Ship i"))
        let numbered = try #require(CurrentLineStructure.from(textBeforeCursor: "1. [X] Ship i"))

        #expect(unchecked.kind == .checklistUnchecked)
        #expect(unchecked.markerStyle == .dash)
        #expect(checked.kind == .checklistChecked)
        #expect(checked.markerStyle == .asterisk)
        #expect(numbered.kind == .checklistChecked)
        #expect(numbered.markerStyle == .numberedDot)
    }

    @Test("Ignores non-list punctuation")
    func ignoresNonListPunctuation() {
        #expect(CurrentLineStructure.from(textBeforeCursor: "I think-this should") == nil)
        #expect(CurrentLineStructure.from(textBeforeCursor: "Version 1.2 is ready") == nil)
        #expect(CurrentLineStructure.from(textBeforeCursor: "[not a checkbox]") == nil)
    }
}
