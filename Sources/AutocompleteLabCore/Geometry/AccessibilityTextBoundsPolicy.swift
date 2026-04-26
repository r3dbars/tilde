import CoreGraphics
import Foundation

public enum AccessibilityTextBoundsPolicy {
    public static func usableTextBounds(_ rect: CGRect?) -> CGRect? {
        guard let rect,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.width >= 0,
              rect.height >= 1 else {
            return nil
        }

        return rect
    }
}
