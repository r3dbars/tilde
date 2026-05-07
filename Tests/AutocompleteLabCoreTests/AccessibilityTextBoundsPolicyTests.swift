import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Accessibility text bounds policy")
struct AccessibilityTextBoundsPolicyTests {
    @Test("Allows zero-width caret rects with real height")
    func allowsZeroWidthCaretRects() {
        let rect = CGRect(x: 80, y: 120, width: 0, height: 18)
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(rect)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(rect) == rect)
        #expect(evaluation.bounds == rect)
        #expect(evaluation.rejectionReason == nil)
        #expect(evaluation.isUsable)
    }

    @Test("Rejects zero-height browser caret rects")
    func rejectsZeroHeightCaretRects() {
        let rect = CGRect(x: 703, y: 120, width: 0, height: 0)
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(rect)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(rect) == nil)
        #expect(evaluation.rejectionReason == .zeroHeight)
        #expect(!evaluation.isUsable)
    }

    @Test("Rejects missing caret bounds with explicit reason")
    func rejectsMissingCaretBoundsWithReason() {
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(nil)

        #expect(evaluation.bounds == nil)
        #expect(evaluation.rejectionReason == .missingBounds)
        #expect(!evaluation.isUsable)
    }

    @Test("Rejects nonfinite caret bounds with explicit reason")
    func rejectsNonfiniteCaretBoundsWithReason() {
        let rect = CGRect(x: CGFloat.infinity, y: 120, width: 0, height: 18)
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(rect)

        #expect(AccessibilityTextBoundsPolicy.usableTextBounds(rect) == nil)
        #expect(evaluation.rejectionReason == AccessibilityTextBoundsPolicy.RejectionReason.nonfinite)
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
        #expect(AccessibilityTextBoundsPolicy.evaluateTextBounds(
            caret,
            elementRect: element,
            windowRect: window
        ).rejectionReason == .outsideElement)
    }

    @Test("Reports outside-window when the element still contains the caret")
    func rejectsCaretBoundsOutsideWindowWithReason() {
        let caret = CGRect(x: 430, y: 170, width: 0, height: 18)
        let element = CGRect(x: 100, y: 100, width: 360, height: 120)
        let window = CGRect(x: 80, y: 80, width: 250, height: 180)

        #expect(AccessibilityTextBoundsPolicy.evaluateTextBounds(
            caret,
            elementRect: element,
            windowRect: window,
            tolerance: 0
        ).rejectionReason == .outsideWindow)
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

    @Test("Rejects caret bounds outside the current screen frame")
    func rejectsCaretBoundsOutsideCurrentScreenFrame() {
        let caret = CGRect(x: 1_500, y: 120, width: 0, height: 18)
        let element = CGRect(x: 1_460, y: 100, width: 120, height: 80)
        let window = CGRect(x: 1_420, y: 80, width: 220, height: 180)
        let convertedCaret = CGRect(x: 1_500, y: 694, width: 0, height: 18)
        let screen = CGRect(x: 0, y: 0, width: 1_280, height: 832)

        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(
            caret,
            elementRect: element,
            windowRect: window,
            convertedScreenRect: convertedCaret,
            screenFrame: screen,
            tolerance: 0
        )

        #expect(evaluation.bounds == nil)
        #expect(evaluation.rejectionReason == .offScreen)
    }

    @Test("Exposes stable trace-safe rejection reason codes")
    func exposesStableTraceSafeRejectionReasonCodes() {
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.zeroHeight.rawValue == "zeroHeight")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.nonfinite.rawValue == "nonfinite")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.outsideElement.rawValue == "outsideElement")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.outsideWindow.rawValue == "outsideWindow")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.offScreen.rawValue == "offScreen")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.stale.rawValue == "stale")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.jumpedTooFar.rawValue == "jumpedTooFar")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.missingBounds.rawValue == "missingBounds")
    }
}
