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

    @Test("Rejects caret bounds outside the focused element and window")
    func rejectsCaretBoundsOutsideFocusedElementAndWindow() {
        let caret = CGRect(x: 900, y: 900, width: 0, height: 18)
        let element = CGRect(x: 100, y: 100, width: 320, height: 80)
        let window = CGRect(x: 80, y: 80, width: 420, height: 260)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(
            caret,
            elementRect: element,
            windowRect: window
        ) == nil)
    }

    @Test("Allows zero width caret bounds near the focused element edge")
    func allowsCaretBoundsNearFocusedElementEdge() {
        let caret = CGRect(x: 421, y: 130, width: 0, height: 18)
        let element = CGRect(x: 100, y: 100, width: 320, height: 80)
        let window = CGRect(x: 80, y: 80, width: 420, height: 260)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(
            caret,
            elementRect: element,
            windowRect: window
        ) == caret)
    }
}
