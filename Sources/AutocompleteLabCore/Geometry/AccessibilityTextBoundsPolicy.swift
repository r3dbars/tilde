import CoreGraphics
import Foundation

public enum AccessibilityTextBoundsPolicy {
    public enum RejectionReason: String, CaseIterable, Codable, Equatable, Sendable {
        case missingBounds
        case nonfinite
        case zeroHeight
        case outsideElement
        case outsideWindow
        case offScreen
        case stale
        case jumpedTooFar
        case visibleRangeMismatch
    }

    public struct Evaluation: Equatable, Sendable {
        public let bounds: CGRect?
        public let rejectionReason: RejectionReason?

        public var isUsable: Bool {
            bounds != nil && rejectionReason == nil
        }

        public static func usable(_ bounds: CGRect) -> Self {
            Self(bounds: bounds, rejectionReason: nil)
        }

        public static func rejected(_ reason: RejectionReason) -> Self {
            Self(bounds: nil, rejectionReason: reason)
        }
    }

    public static func usableTextBounds(
        _ rect: CGRect?,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        convertedScreenRect: CGRect? = nil,
        screenFrame: CGRect? = nil,
        selectedRange: AccessibilityCharacterRange? = nil,
        visibleCharacterRange: AccessibilityCharacterRange? = nil,
        tolerance: CGFloat = 24
    ) -> CGRect? {
        evaluateTextBounds(
            rect,
            elementRect: elementRect,
            windowRect: windowRect,
            convertedScreenRect: convertedScreenRect,
            screenFrame: screenFrame,
            selectedRange: selectedRange,
            visibleCharacterRange: visibleCharacterRange,
            tolerance: tolerance
        ).bounds
    }

    public static func evaluateTextBounds(
        _ rect: CGRect?,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        convertedScreenRect: CGRect? = nil,
        screenFrame: CGRect? = nil,
        selectedRange: AccessibilityCharacterRange? = nil,
        visibleCharacterRange: AccessibilityCharacterRange? = nil,
        tolerance: CGFloat = 24
    ) -> Evaluation {
        guard let rect else {
            return .rejected(.missingBounds)
        }

        guard
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.width >= 0 else {
            return .rejected(.nonfinite)
        }

        guard rect.height >= 1 else {
            return .rejected(.zeroHeight)
        }

        if let elementRect,
           !isPlausiblyInside(rect, container: elementRect, tolerance: tolerance) {
            return .rejected(.outsideElement)
        }

        if let windowRect,
           !isPlausiblyInside(rect, container: windowRect, tolerance: tolerance) {
            return .rejected(.outsideWindow)
        }

        if let screenFrame {
            let screenRect = convertedScreenRect ?? rect
            if !isPlausiblyInside(screenRect, container: screenFrame, tolerance: tolerance) {
                return .rejected(.offScreen)
            }
        }

        if let selectedRange,
           let visibleCharacterRange,
           !visibleCharacterRange.containsInsertionPoint(selectedRange.insertionLocation) {
            return .rejected(.visibleRangeMismatch)
        }

        return .usable(rect)
    }

    public static func evaluateTextLineBounds(
        _ rect: CGRect?,
        caretRect: CGRect?,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        selectedRange: AccessibilityCharacterRange? = nil,
        visibleCharacterRange: AccessibilityCharacterRange? = nil,
        tolerance: CGFloat = 24
    ) -> Evaluation {
        let evaluation = evaluateTextBounds(
            rect,
            elementRect: elementRect,
            windowRect: windowRect,
            selectedRange: selectedRange,
            visibleCharacterRange: visibleCharacterRange,
            tolerance: tolerance
        )

        guard evaluation.isUsable,
              let lineRect = evaluation.bounds,
              let caretRect else {
            return evaluation
        }

        let maxVerticalDistance = max(8, caretRect.height * 1.5)
        guard abs(lineRect.midY - caretRect.midY) <= maxVerticalDistance else {
            return .rejected(.stale)
        }

        return evaluation
    }

    private static func isPlausiblyInside(
        _ rect: CGRect,
        container: CGRect,
        tolerance: CGFloat
    ) -> Bool {
        guard container.origin.x.isFinite,
              container.origin.y.isFinite,
              container.width.isFinite,
              container.height.isFinite,
              container.width > 0,
              container.height > 0 else {
            return false
        }

        let expandedContainer = container.insetBy(dx: -tolerance, dy: -tolerance)
        let testRect = rect.width == 0 ? rect.insetBy(dx: -1, dy: 0) : rect

        return expandedContainer.intersects(testRect)
            || expandedContainer.contains(CGPoint(x: rect.midX, y: rect.midY))
    }
}
