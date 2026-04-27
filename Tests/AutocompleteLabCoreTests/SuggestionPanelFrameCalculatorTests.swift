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

    @Test("Keeps inline ghost text inside the focused editor bounds")
    func keepsInlineGhostTextInsideEditorBounds() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 1265, y: 420, width: 0, height: 22),
            textLineRect: CGRect(x: 20, y: 415, width: 1245, height: 22),
            textSize: CGSize(width: 360, height: 22),
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 900),
            clippingFrame: CGRect(x: 0, y: 80, width: 1312, height: 740)
        )

        #expect(frame.minX >= 1264)
        #expect(frame.maxX <= 1304)
    }

    @Test("Keeps panel valid on narrow screens")
    func keepsPanelValidOnNarrowScreens() {
        let frame = SuggestionPanelFrameCalculator.inlineGhostFrame(
            caretRect: CGRect(x: 88, y: 20, width: 0, height: 18),
            textSize: CGSize(width: 500, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 96, height: 80)
        )

        #expect(frame.minX >= 8)
        #expect(frame.maxX <= 88)
        #expect(frame.width == 40)
    }

    @Test("Mirror fallback anchors in the middle of large focused elements")
    func mirrorFallbackAnchorsInMiddleOfLargeFocusedElements() {
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 80, y: 600, width: 500, height: 220),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 88)
        #expect(frame.minY == 695)
        #expect(frame.width == 190)
    }

    @Test("Mirror fallback still follows small caret-like anchors")
    func mirrorFallbackFollowsSmallAnchors() {
        let frame = SuggestionPanelFrameCalculator.floatingMirrorFrame(
            anchorRect: CGRect(x: 80, y: 600, width: 0, height: 22),
            textSize: CGSize(width: 180, height: 18),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        )

        #expect(frame.minX == 88)
        #expect(frame.maxY == 618)
        #expect(frame.width == 190)
    }

    @Test("Skips refreshing identical panel presentations")
    func skipsIdenticalPanelPresentations() {
        let frame = CGRect(x: 100, y: 600, width: 180, height: 22)

        #expect(!SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make",
            nextFrame: frame.offsetBy(dx: 0.25, dy: -0.25),
            nextRenderMode: .inlineAdjacent
        ))

        #expect(SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make this",
            nextFrame: frame,
            nextRenderMode: .inlineAdjacent
        ))

        #expect(SuggestionPanelFrameCalculator.shouldRefreshPresentation(
            previousText: " make",
            previousFrame: frame,
            previousRenderMode: .inlineAdjacent,
            nextText: " make",
            nextFrame: frame.offsetBy(dx: 2, dy: 0),
            nextRenderMode: .inlineAdjacent
        ))
    }
}
