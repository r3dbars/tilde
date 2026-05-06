import CoreGraphics
import Foundation

public enum AccessibilityCoordinateConverter {
    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    public static func accessibilityRect(fromAppKitRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenHeight - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
