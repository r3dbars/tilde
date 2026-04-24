import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion panel frame calculator")
struct SuggestionPanelFrameCalculatorTests {
    @Test("Places ghost text immediately after the caret")
    func placesGhostTextAfterCaret() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 100, y: 800, width: 0, height: 20),
            textLineRect: CGRect(x: 80, y: 790, width: 20, height: 20),
            textSize: CGSize(width: 160, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 100)
        #expect(frame.minY == 790)
        #expect(frame.width == 166)
    }

    @Test("Keeps ghost text inside the screen")
    func keepsGhostTextInsideScreen() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1180, y: 10, width: 0, height: 20),
            textSize: CGSize(width: 200, height: 20),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.maxX <= 1192)
        #expect(frame.minY >= 4)
    }

    @Test("Keeps ghost text inside the focused text boundary")
    func keepsGhostTextInsideFocusedTextBoundary() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 900, y: 800, width: 0, height: 28),
            textLineRect: CGRect(x: 80, y: 790, width: 840, height: 28),
            boundaryFrame: CGRect(x: 80, y: 100, width: 940, height: 760),
            textSize: CGSize(width: 300, height: 28),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 900)
        #expect(frame.maxX <= 1016)
    }
}
