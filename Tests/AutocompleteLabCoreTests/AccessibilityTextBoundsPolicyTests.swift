import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Accessibility text bounds policy")
struct AccessibilityTextBoundsPolicyTests {
    @Test("Allows zero-width caret rects with real height")
    func allowsZeroWidthCaretRects() {
        let rect = CGRect(x: 80, y: 120, width: 0, height: 18)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(rect) == rect)
    }

    @Test("Rejects zero-height browser caret rects")
    func rejectsZeroHeightCaretRects() {
        let rect = CGRect(x: 703, y: 120, width: 0, height: 0)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(rect) == nil)
    }
}
