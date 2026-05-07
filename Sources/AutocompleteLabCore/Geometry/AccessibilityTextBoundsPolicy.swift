import CoreGraphics
import Foundation

public enum AccessibilityTextBoundsPolicy {
    public static func usableTextBounds(
        _ rect: CGRect?,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        tolerance: CGFloat = 24
    ) -> CGRect? {
        guard let rect,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.width >= 0,
              rect.height >= 1 else {
            return nil
        }

        if let elementRect,
           !isPlausiblyInside(rect, container: elementRect, tolerance: tolerance) {
            return nil
        }

        if let windowRect,
           !isPlausiblyInside(rect, container: windowRect, tolerance: tolerance) {
            return nil
        }

        return rect
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
