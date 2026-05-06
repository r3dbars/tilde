import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret estimator")
struct SyntheticCaretEstimatorTests {
    @Test("Returns nil for tiny editor bounds")
    func returnsNilForTinyEditorBounds() {
        #expect(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: CGRect(x: 0, y: 0, width: 60, height: 20),
            windowRect: nil,
            lineHeight: 20,
            widthOfText: fixedWidth
        ) == nil)
    }

    @Test("Places caret after current line text")
    func placesCaretAfterCurrentLineText() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: CGRect(x: 100, y: 200, width: 320, height: 80),
            windowRect: CGRect(x: 80, y: 160, width: 420, height: 220),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.origin.x == 186)
        #expect(caret.origin.y == 204)
        #expect(caret.width == 0)
        #expect(caret.height == 20)
    }

    @Test("Wraps long prompt text to later visual lines")
    func wrapsLongPromptTextToLaterVisualLines() throws {
        let shortCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "short",
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 160),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 300),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))
        let wrappedCaret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "this line should wrap",
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 160),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 300),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(wrappedCaret.origin.y > shortCaret.origin.y)
    }

    @Test("Clamps caret inside containing window")
    func clampsCaretInsideContainingWindow() throws {
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: String(repeating: "w", count: 80),
            elementRect: CGRect(x: 100, y: 200, width: 120, height: 120),
            windowRect: CGRect(x: 80, y: 160, width: 220, height: 180),
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        #expect(caret.maxY <= 332)
    }

    private func fixedWidth(_ text: String) -> CGFloat {
        CGFloat(text.count * 10)
    }
}
