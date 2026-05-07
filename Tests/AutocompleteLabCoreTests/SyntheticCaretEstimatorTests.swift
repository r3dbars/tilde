import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret estimator")
struct SyntheticCaretEstimatorTests {
    @Test("Places an empty prompt caret inside the editor")
    func placesEmptyPromptCaretInsideEditor() throws {
        let element = CGRect(x: 100, y: 200, width: 360, height: 80)

        let rect = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "",
            elementRect: element,
            windowRect: CGRect(x: 80, y: 160, width: 420, height: 260),
            lineHeight: 22,
            widthOfText: monospaceWidth
        ))

        #expect(rect.minX == 126)
        #expect(rect.minY >= element.minY - 30)
        #expect(rect.height == 22)
    }

    @Test("Moves to the next visual line when text wraps")
    func movesToNextVisualLineWhenTextWraps() throws {
        let element = CGRect(x: 100, y: 200, width: 150, height: 80)

        let shortRect = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "short",
            elementRect: element,
            windowRect: nil,
            lineHeight: 20,
            widthOfText: monospaceWidth
        ))
        let wrappedRect = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "this line is long enough to wrap",
            elementRect: element,
            windowRect: nil,
            lineHeight: 20,
            widthOfText: monospaceWidth
        ))

        #expect(wrappedRect.minY > shortRect.minY)
    }

    @Test("Clamps caret to the window")
    func clampsCaretToWindow() throws {
        let rect = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: String(repeating: "wrap ", count: 30),
            elementRect: CGRect(x: 100, y: 200, width: 160, height: 60),
            windowRect: CGRect(x: 80, y: 160, width: 260, height: 140),
            lineHeight: 20,
            widthOfText: monospaceWidth
        ))

        #expect(rect.maxY <= 292)
    }

    @Test("Rejects unusable editor geometry")
    func rejectsUnusableEditorGeometry() {
        #expect(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "hello",
            elementRect: CGRect(x: 0, y: 0, width: 20, height: 20),
            windowRect: nil,
            lineHeight: 20,
            widthOfText: monospaceWidth
        ) == nil)
    }

    private func monospaceWidth(_ text: String) -> CGFloat {
        CGFloat(text.count * 8)
    }
}
