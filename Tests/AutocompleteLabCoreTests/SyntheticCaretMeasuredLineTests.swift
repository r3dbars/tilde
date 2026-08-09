import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret measured line placement")
struct SyntheticCaretMeasuredLineTests {
    private let elementRect = CGRect(x: 100, y: 200, width: 320, height: 80)
    private let windowRect = CGRect(x: 80, y: 160, width: 420, height: 220)

    @Test("A measured line rect places the caret at its trailing edge")
    func measuredLineRectPlacesCaretAtTrailingEdge() throws {
        let measured = CGRect(x: 118, y: 208, width: 120, height: 18)
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: elementRect,
            windowRect: windowRect,
            lineHeight: 20,
            measuredCurrentLineRect: measured,
            widthOfText: fixedWidth
        ))

        #expect(caret.origin.x == measured.maxX + 8)
        #expect(caret.origin.y == measured.minY)
        #expect(caret.width == 0)
        #expect(caret.height == 18)
    }

    @Test("The measured caret never leaves the element horizontally")
    func measuredCaretNeverLeavesElementHorizontally() throws {
        let measured = CGRect(x: 118, y: 208, width: 310, height: 18)
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: elementRect,
            windowRect: windowRect,
            lineHeight: 20,
            measuredCurrentLineRect: measured,
            widthOfText: fixedWidth
        ))

        #expect(caret.origin.x <= elementRect.maxX - 18)
    }

    @Test("Implausible measured rects fall back to width estimation")
    func implausibleMeasuredRectsFallBackToWidthEstimation() throws {
        let estimated = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: elementRect,
            windowRect: windowRect,
            lineHeight: 20,
            widthOfText: fixedWidth
        ))

        let implausible: [CGRect] = [
            CGRect(x: 118, y: 208, width: 0.5, height: 18),
            CGRect(x: 118, y: 208, width: 120, height: 200),
            CGRect(x: 118, y: 208, width: 120, height: 4),
            CGRect(x: 5_000, y: 208, width: 120, height: 18),
            CGRect(x: .nan, y: 208, width: 120, height: 18)
        ]
        for rect in implausible {
            let caret = try #require(SyntheticCaretEstimator.caretRect(
                textBeforeCursor: "Can we",
                elementRect: elementRect,
                windowRect: windowRect,
                lineHeight: 20,
                measuredCurrentLineRect: rect,
                widthOfText: fixedWidth
            ))

            #expect(caret == estimated)
        }
    }

    @Test("A tall measured line keeps the caret height near one line")
    func tallMeasuredLineKeepsCaretHeightNearOneLine() throws {
        let measured = CGRect(x: 118, y: 208, width: 120, height: 44)
        let caret = try #require(SyntheticCaretEstimator.caretRect(
            textBeforeCursor: "Can we",
            elementRect: elementRect,
            windowRect: windowRect,
            lineHeight: 20,
            measuredCurrentLineRect: measured,
            widthOfText: fixedWidth
        ))

        #expect(caret.height == 30)
    }

    private func fixedWidth(_ text: String) -> CGFloat {
        CGFloat(text.count) * 10
    }
}
