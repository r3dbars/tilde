import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Screenshot capture region")
struct ScreenshotCaptureRegionTests {
    @Test("Includes caret and rendered suggestion frame")
    func includesCaretAndSuggestionFrame() {
        let region = ScreenshotCaptureRegion.enclosing([
            CGRect(x: 120, y: 240, width: 0, height: 22),
            CGRect(x: 126, y: 240, width: 180, height: 22)
        ])

        #expect(region?.minX == 95)
        #expect(region?.minY == 216)
        #expect(region?.maxX == 330)
        #expect(region?.maxY == 286)
    }

    @Test("Normalizes zero-sized caret-only captures")
    func normalizesZeroSizedCaretOnlyCaptures() {
        let region = ScreenshotCaptureRegion.enclosing([
            CGRect(x: 120, y: 240, width: 0, height: 0)
        ])

        #expect(region?.width == 50)
        #expect(region?.height == 50)
    }

    @Test("Drops invalid rectangles")
    func dropsInvalidRectangles() {
        let region = ScreenshotCaptureRegion.enclosing([
            CGRect(x: CGFloat.nan, y: 240, width: 0, height: 22),
            CGRect(x: 200, y: 260, width: 60, height: 20)
        ])

        #expect(region?.minX == 176)
        #expect(region?.minY == 236)
        #expect(region?.maxX == 284)
    }
}
