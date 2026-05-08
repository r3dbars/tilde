import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Caret rect resolver")
struct CaretRectResolverTests {
    @Test("Keeps a reported caret that agrees with the previous glyph")
    func keepsReliableReportedCaret() {
        let caret = CGRect(x: 128, y: 220, width: 0, height: 18)
        let glyph = CGRect(x: 118, y: 220, width: 10, height: 18)

        let resolved = CaretRectResolver.resolve(
            reportedCaretRect: caret,
            previousGlyphRect: glyph,
            isAfterNewline: false
        )

        #expect(resolved == caret)
    }

    @Test("Moves a stale wrapped caret to the previous glyph row")
    func repairsStaleWrappedCaret() {
        let staleCaret = CGRect(x: 240, y: 180, width: 0, height: 18)
        let wrappedGlyph = CGRect(x: 510, y: 204, width: 9, height: 18)

        let resolved = CaretRectResolver.resolve(
            reportedCaretRect: staleCaret,
            previousGlyphRect: wrappedGlyph,
            isAfterNewline: false
        )

        #expect(resolved == CGRect(x: 519, y: 204, width: 0, height: 18))
    }

    @Test("Moves a same-row caret that is before the previous glyph")
    func repairsSameRowCaretBeforeGlyph() {
        let staleCaret = CGRect(x: 240, y: 180, width: 0, height: 18)
        let glyph = CGRect(x: 300, y: 180, width: 9, height: 18)

        let resolved = CaretRectResolver.resolve(
            reportedCaretRect: staleCaret,
            previousGlyphRect: glyph,
            isAfterNewline: false
        )

        #expect(resolved == CGRect(x: 309, y: 180, width: 0, height: 18))
    }

    @Test("Does not infer from a previous glyph after a newline")
    func avoidsPreviousGlyphAfterNewline() {
        let caret = CGRect(x: 40, y: 220, width: 0, height: 18)
        let previousLineGlyph = CGRect(x: 510, y: 180, width: 9, height: 18)

        let resolved = CaretRectResolver.resolve(
            reportedCaretRect: caret,
            previousGlyphRect: previousLineGlyph,
            isAfterNewline: true
        )

        #expect(resolved == caret)
    }

    @Test("Uses the next glyph when no caret is reported after a newline")
    func usesNextGlyphWhenCaretMissingAfterNewline() {
        let nextGlyph = CGRect(x: 40, y: 220, width: 9, height: 18)

        let resolved = CaretRectResolver.resolve(
            reportedCaretRect: nil,
            previousGlyphRect: nil,
            nextGlyphRect: nextGlyph,
            isAfterNewline: true
        )

        #expect(resolved == CGRect(x: 40, y: 220, width: 0, height: 18))
    }
}
