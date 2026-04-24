import CoreGraphics
import Foundation

public enum AccessibilityCoordinateConverter {
    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenHeight: CGFloat) -> CGRect {
        appKitRect(
            fromAccessibilityRect: rect,
            screenFrame: CGRect(x: 0, y: 0, width: 0, height: screenHeight)
        )
    }

    public static func appKitRect(fromAccessibilityRect rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.minY - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
