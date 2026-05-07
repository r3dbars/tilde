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

    @Test("Rejects caret bounds when selected range is outside visible range")
    func rejectsCaretBoundsOutsideVisibleRange() {
        let caret = CGRect(x: 80, y: 120, width: 0, height: 18)
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(
            caret,
            selectedRange: AccessibilityCharacterRange(location: 500, length: 0),
            visibleCharacterRange: AccessibilityCharacterRange(location: 100, length: 200)
        )

        #expect(evaluation.bounds == nil)
        #expect(evaluation.rejectionReason == .visibleRangeMismatch)
    }

    @Test("Allows wrapped line bounds when selected range is visible")
    func allowsWrappedLineBoundsWhenSelectedRangeIsVisible() {
        let wrappedLine = CGRect(x: 80, y: 120, width: 360, height: 18)
        let element = CGRect(x: 60, y: 100, width: 420, height: 120)
        let evaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(
            wrappedLine,
            elementRect: element,
            selectedRange: AccessibilityCharacterRange(location: 180, length: 0),
            visibleCharacterRange: AccessibilityCharacterRange(location: 100, length: 120)
        )

        #expect(evaluation.bounds == wrappedLine)
        #expect(evaluation.rejectionReason == nil)
    }

    @Test("Rejects stale caret when visible range changes but geometry does not")
    func rejectsStaleCaretWhenVisibleRangeChangesButGeometryDoesNot() {
        let caret = CGRect(x: 80, y: 120, width: 0, height: 18)
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let previous = AccessibilityGeometrySample(
            fieldIdentity: field,
            textState: AccessibilityGeometryTextState(
                textBeforeCursorUTF16Length: 20,
                textAfterCursorUTF16Length: 10,
                selectedRange: AccessibilityCharacterRange(location: 20, length: 0),
                visibleCharacterRange: AccessibilityCharacterRange(location: 0, length: 120)
            ),
            caretRect: caret,
            insertionPointLineNumber: 3
        )
        let current = AccessibilityGeometrySample(
            fieldIdentity: field,
            textState: AccessibilityGeometryTextState(
                textBeforeCursorUTF16Length: 20,
                textAfterCursorUTF16Length: 10,
                selectedRange: AccessibilityCharacterRange(location: 20, length: 0),
                visibleCharacterRange: AccessibilityCharacterRange(location: 10, length: 120)
            ),
            caretRect: caret,
            insertionPointLineNumber: 3
        )

        let validation = AccessibilityGeometryValidator.validate(
            current,
            previousSample: previous
        )

        #expect(validation.caretEvaluation.bounds == nil)
        #expect(validation.caretEvaluation.rejectionReason == AccessibilityTextBoundsPolicy.RejectionReason.stale)
    }

    @Test("Rejects large caret jumps when text did not change")
    func rejectsLargeCaretJumpsWhenTextDidNotChange() {
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let previous = AccessibilityGeometrySample(
            fieldIdentity: field,
            textState: AccessibilityGeometryTextState(
                textBeforeCursorUTF16Length: 20,
                textAfterCursorUTF16Length: 10,
                selectedRange: AccessibilityCharacterRange(location: 20, length: 0),
                visibleCharacterRange: AccessibilityCharacterRange(location: 0, length: 120)
            ),
            caretRect: CGRect(x: 80, y: 120, width: 0, height: 18),
            insertionPointLineNumber: 3
        )
        let current = AccessibilityGeometrySample(
            fieldIdentity: field,
            textState: AccessibilityGeometryTextState(
                textBeforeCursorUTF16Length: 20,
                textAfterCursorUTF16Length: 10,
                selectedRange: AccessibilityCharacterRange(location: 20, length: 0),
                visibleCharacterRange: AccessibilityCharacterRange(location: 0, length: 120)
            ),
            caretRect: CGRect(x: 520, y: 120, width: 0, height: 18),
            insertionPointLineNumber: 3
        )

        let validation = AccessibilityGeometryValidator.validate(
            current,
            previousSample: previous,
            policy: AccessibilityGeometryValidationPolicy(maxStableTextJumpDistance: 240)
        )

        #expect(validation.caretEvaluation.bounds == nil)
        #expect(validation.caretEvaluation.rejectionReason == AccessibilityTextBoundsPolicy.RejectionReason.jumpedTooFar)
    }

    @Test("Keeps a bounded geometry history per field")
    func keepsBoundedGeometryHistoryPerField() {
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        var history = AccessibilityGeometryHistory(maxSamplesPerField: 2)

        for index in 0..<3 {
            history.record(AccessibilityGeometrySample(
                fieldIdentity: field,
                textState: AccessibilityGeometryTextState(
                    textBeforeCursorUTF16Length: index,
                    textAfterCursorUTF16Length: 0,
                    selectedRange: AccessibilityCharacterRange(location: index, length: 0)
                ),
                caretRect: CGRect(x: index, y: 0, width: 0, height: 18),
                insertionPointLineNumber: nil
            ))
        }

        #expect(history.recentSamples(for: field).count == 2)
        #expect(history.recentSamples(for: field).last?.textState.textBeforeCursorUTF16Length == 2)
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
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.visibleRangeMismatch.rawValue == "visibleRangeMismatch")
        #expect(AccessibilityTextBoundsPolicy.RejectionReason.missingBounds.rawValue == "missingBounds")
    }
}
