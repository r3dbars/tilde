import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Field status indicator frame calculator")
struct FieldStatusIndicatorFrameCalculatorTests {
    @Test("Places the badge outside the left edge of the focused field")
    func placesBadgeOutsideLeftEdge() throws {
        let frame = try #require(FieldStatusIndicatorFrameCalculator.frame(
            anchorRect: CGRect(x: 300, y: 400, width: 1, height: 22),
            fieldRect: CGRect(x: 260, y: 360, width: 420, height: 140),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        ))

        #expect(frame.maxX == 254)
        #expect(frame.midY == 411)
    }

    @Test("Falls back to the right edge when the field is near the screen edge")
    func fallsBackRightWhenLeftEdgeIsUnavailable() throws {
        let frame = try #require(FieldStatusIndicatorFrameCalculator.frame(
            anchorRect: CGRect(x: 40, y: 100, width: 1, height: 20),
            fieldRect: CGRect(x: 10, y: 80, width: 180, height: 80),
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 300)
        ))

        #expect(frame.minX == 196)
        #expect(frame.midY == 110)
    }

    @Test("Clamps the badge inside the active screen")
    func clampsBadgeInsideScreen() throws {
        let frame = try #require(FieldStatusIndicatorFrameCalculator.frame(
            anchorRect: CGRect(x: 460, y: 2, width: 1, height: 20),
            fieldRect: CGRect(x: 440, y: 0, width: 52, height: 24),
            screenFrame: CGRect(x: 0, y: 0, width: 500, height: 300)
        ))

        #expect(frame.maxX <= 492)
        #expect(frame.minY >= 8)
    }

    @Test("Uses the top of a large field fallback anchor")
    func usesTopOfLargeFieldFallbackAnchor() throws {
        let frame = try #require(FieldStatusIndicatorFrameCalculator.frame(
            anchorRect: CGRect(x: 200, y: 100, width: 500, height: 420),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
        ))

        #expect(frame.maxY == 514)
    }
}
